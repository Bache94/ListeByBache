import Foundation
import Combine
import CloudKit
import UIKit

/// CloudKit/iCloud Multi-User-Sync + Chat (über Internet).
///
/// - Host erstellt einen Code → intern wird eine CloudKit-Share erzeugt und die Share-URL in der Public DB
///   unter dem Code hinterlegt.
/// - Joiner gibt Code ein → App holt Share-URL aus der Public DB → akzeptiert Share → synchronisiert über Shared DB.
///
/// Wichtig: Das ist ein pragmatischer MVP (Polling statt Push-Subscriptions), dafür sehr zuverlässig und App-Store-freundlich.
final class SharedListSessionManager: ObservableObject {
    enum ConnectionState: String {
        case disconnected
        case hosting
        case joining
        case connected
    }
    
    @Published private(set) var currentCode: String? = nil
    @Published private(set) var connectionState: ConnectionState = .disconnected
    /// CloudKit liefert keine „Live-Geräteliste“ wie Multipeer; wir behalten das Feld für die UI-Compat.
    @Published private(set) var connectedPeers: [String] = []
    @Published private(set) var lastError: String? = nil
    @Published private(set) var isHost: Bool = false
    
    @Published var chatMessages: [ChatMessage] = []
    
    private enum Mode {
        case none
        case hosting(code: String)
        case joining(code: String)
        case connected(code: String, isHost: Bool)
    }
    
    // CloudKit schema (Record Types / Fields)
    private enum Schema {
        static let shareCodeType = "LBShareCode"
        static let shareURLField = "shareURL"
        
        static let listRootType = "LBSharedList"
        static let listCodeField = "code"
        static let listCreatedAtField = "createdAt"
        
        static let itemType = "LBListItem"
        static let itemPayloadField = "payload"
        static let itemUpdatedAtField = "updatedAt"
        
        static let chatType = "LBChatMessage"
        static let chatSenderField = "sender"
        static let chatTextField = "text"
        static let chatTimestampField = "timestamp"
    }
    
    private weak var boundManager: ShoppingListManager?
    private var mode: Mode = .none
    
    private let container: CKContainer
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private var activeDatabase: CKDatabase?
    private var listZoneID: CKRecordZone.ID?
    
    private var listPollTimer: Timer?
    private var chatPollTimer: Timer?
    private var lastChatFetch: Date? = nil
    private var isPullingList = false
    
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    init(container: CKContainer = CKContainer.default()) {
        self.container = container
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        self.encoder = e
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }
    
    // MARK: - Public API
    
    func bind(to manager: ShoppingListManager) {
        boundManager = manager
        manager.onLocalChange = { [weak self] change in
            self?.handleLocalChange(change)
        }
    }
    
    /// Host: neuen Code erstellen und CloudKit Share erzeugen.
    func generateNewCode() {
        stopAll()
        lastError = nil
        
        if isPreview {
            // Preview: fake „connected“
            currentCode = "123456"
            connectionState = .connected
            isHost = true
            mode = .connected(code: "123456", isHost: true)
            return
        }
        
        let code = Self.makeCode(length: 6)
        currentCode = code
        connectionState = .hosting
        isHost = true
        mode = .hosting(code: code)
        
        Task {
            await self.hostCreateShareAndConnect(code: code)
        }
    }
    
    /// Joiner: Code eingeben → Share akzeptieren → Shared DB verbinden.
    func join(code: String) {
        stopAll()
        lastError = nil
        
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        
        if isPreview {
            currentCode = cleaned
            connectionState = .connected
            isHost = false
            mode = .connected(code: cleaned, isHost: false)
            return
        }
        
        currentCode = cleaned
        connectionState = .joining
        isHost = false
        mode = .joining(code: cleaned)
        
        Task {
            await self.joinByCodeAndConnect(code: cleaned)
        }
    }
    
    func leave() {
        stopAll()
    }
    
    func sendChat(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard connectionState == .connected else { return }
        guard let db = activeDatabase, let zoneID = listZoneID else { return }
        
        let msg = ChatMessage(id: UUID(), sender: UIDevice.current.name, text: trimmed, timestamp: Date())
        chatMessages.append(msg)
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: msg.id.uuidString, zoneID: zoneID)
                let record = CKRecord(recordType: Schema.chatType, recordID: recordID)
                record[Schema.chatSenderField] = msg.sender as CKRecordValue
                record[Schema.chatTextField] = msg.text as CKRecordValue
                record[Schema.chatTimestampField] = msg.timestamp as CKRecordValue
                _ = try await self.save(record: record, in: db)
            } catch {
                await self.setErrorAsync("Chat senden fehlgeschlagen: \(Self.userFacing(error))")
            }
        }
    }
    
    // MARK: - Hosting / Joining
    
    private func hostCreateShareAndConnect(code: String) async {
        do {
            try await ensureICloudAvailable()
            
            // Zone anlegen
            let zoneName = "lb-\(code)"
            let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
            try await createZoneIfNeeded(zoneID: zoneID, in: container.privateCloudDatabase)
            
            // Root-Record + Share speichern
            let rootID = CKRecord.ID(recordName: "list", zoneID: zoneID)
            let root = CKRecord(recordType: Schema.listRootType, recordID: rootID)
            root[Schema.listCodeField] = code as CKRecordValue
            root[Schema.listCreatedAtField] = Date() as CKRecordValue
            
            let share = CKShare(rootRecord: root)
            share[CKShare.SystemFieldKey.title] = "ListeByBache" as CKRecordValue
            // Wichtig für „Join per Code“: jeder mit Link/Code darf beitreten (read/write).
            share.publicPermission = .readWrite
            
            _ = try await modify(recordsToSave: [root, share], recordIDsToDelete: [], in: container.privateCloudDatabase)
            
            guard let shareURL = share.url else {
                throw NSError(domain: "ListeByBache.CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Share-URL fehlt."])
            }
            
            // Code → ShareURL in Public DB hinterlegen (RecordName = Code)
            try await upsertShareCodeRecord(code: code, shareURL: shareURL)
            
            // Verbinden als Host (private DB)
            await MainActor.run {
                self.activeDatabase = self.container.privateCloudDatabase
                self.listZoneID = zoneID
                self.connectionState = .connected
                self.isHost = true
                self.mode = .connected(code: code, isHost: true)
            }
            
            startPolling()
            await pushFullSnapshotToCloud()
            await pullListNow()
            await pullChatNow()
            await subscribeToChat(in: container.privateCloudDatabase, zoneID: zoneID)
            
        } catch {
            await setErrorAsync("iCloud Host fehlgeschlagen: \(Self.userFacing(error))")
            await MainActor.run { self.stopAll() }
        }
    }
    
    private func joinByCodeAndConnect(code: String) async {
        do {
            try await ensureICloudAvailable()
            
            let shareURL = try await fetchShareURL(for: code)
            let metadata = try await fetchShareMetadata(for: shareURL)
            try await acceptShare(metadata)
            
            let zoneID = metadata.rootRecordID.zoneID
            
            await MainActor.run {
                self.activeDatabase = self.container.sharedCloudDatabase
                self.listZoneID = zoneID
                self.connectionState = .connected
                self.isHost = false
                self.mode = .connected(code: code, isHost: false)
            }
            
            startPolling()
            await pullListNow()
            await pullChatNow()
            await subscribeToChat(in: container.sharedCloudDatabase, zoneID: zoneID)
            
        } catch {
            await setErrorAsync("iCloud Join fehlgeschlagen: \(Self.userFacing(error))")
            await MainActor.run { self.stopAll() }
        }
    }
    
    // MARK: - Local changes → Cloud
    
    private func handleLocalChange(_ change: ShoppingListChange) {
        guard connectionState == .connected else { return }
        guard let db = activeDatabase, let zoneID = listZoneID else { return }
        
        Task {
            await pushChange(change, in: db, zoneID: zoneID)
        }
    }
    
    private func pushChange(_ change: ShoppingListChange, in db: CKDatabase, zoneID: CKRecordZone.ID) async {
        do {
            switch change.kind {
            case .add:
                guard let item = change.item else { return }
                try await upsertItem(item, in: db, zoneID: zoneID)
                
            case .toggle:
                guard let id = change.id else { return }
                guard let item = boundManager?.items.first(where: { $0.id == id }) else { return }
                try await upsertItem(item, in: db, zoneID: zoneID)
                
            case .remove:
                guard let id = change.id else { return }
                let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
                _ = try await delete(recordID: recordID, in: db)
                
            case .clearChecked:
                // Fallback: Snapshot push
                await pushFullSnapshotToCloud()
                
            case .replaceAll:
                await pushFullSnapshotToCloud()
            }
            
            // Nach Änderungen kurz „pullen“, um Drift zu vermeiden
            await pullListNow()
            
        } catch {
            await setErrorAsync("Sync fehlgeschlagen: \(Self.userFacing(error))")
        }
    }
    
    private func pushFullSnapshotToCloud() async {
        guard connectionState == .connected else { return }
        guard let db = activeDatabase, let zoneID = listZoneID else { return }
        guard let items = boundManager?.items else { return }
        
        do {
            // Bestehende Item-Records holen und als Diff updaten (ohne Konflikte/ChangeTag-Probleme).
            let existing = try await fetchAllRecords(recordType: Schema.itemType, predicate: NSPredicate(value: true), sort: [], zoneID: zoneID, in: db)
            let existingByName = Dictionary(uniqueKeysWithValues: existing.map { ($0.recordID.recordName, $0) })
            
            let desiredNames = Set(items.map { $0.id.uuidString })
            let deleteIDs = existing.filter { !desiredNames.contains($0.recordID.recordName) }.map(\.recordID)
            
            let saveRecords: [CKRecord] = try items.map { item in
                if let record = existingByName[item.id.uuidString] {
                    record[Schema.itemPayloadField] = try encoder.encode(item) as CKRecordValue
                    record[Schema.itemUpdatedAtField] = Date() as CKRecordValue
                    return record
                } else {
                    let recordID = CKRecord.ID(recordName: item.id.uuidString, zoneID: zoneID)
                    let record = CKRecord(recordType: Schema.itemType, recordID: recordID)
                    record[Schema.itemPayloadField] = try encoder.encode(item) as CKRecordValue
                    record[Schema.itemUpdatedAtField] = Date() as CKRecordValue
                    return record
                }
            }
            
            _ = try await modify(recordsToSave: saveRecords, recordIDsToDelete: deleteIDs, in: db)
        } catch {
            await setErrorAsync("Snapshot-Sync fehlgeschlagen: \(Self.userFacing(error))")
        }
    }
    
    private func upsertItem(_ item: ShoppingItem, in db: CKDatabase, zoneID: CKRecordZone.ID) async throws {
        let recordID = CKRecord.ID(recordName: item.id.uuidString, zoneID: zoneID)
        
        let record = try await fetchIfExists(recordID: recordID, in: db) ?? CKRecord(recordType: Schema.itemType, recordID: recordID)
        record[Schema.itemPayloadField] = try encoder.encode(item) as CKRecordValue
        record[Schema.itemUpdatedAtField] = Date() as CKRecordValue
        _ = try await save(record: record, in: db)
    }
    
    // MARK: - Cloud → Local (Polling)
    
    private func startPolling() {
        stopPolling()
        guard !isPreview else { return }
        guard connectionState == .connected else { return }
        
        // Liste (Polling alle 6s)
        listPollTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.pullListNow() }
        }
        
        // Chat (Polling alle 4s)
        chatPollTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.pullChatNow() }
        }
    }
    
    private func stopPolling() {
        listPollTimer?.invalidate()
        listPollTimer = nil
        chatPollTimer?.invalidate()
        chatPollTimer = nil
    }
    
    private func pullListNow() async {
        guard connectionState == .connected else { return }
        guard let db = activeDatabase, let zoneID = listZoneID else { return }
        guard let manager = boundManager else { return }
        guard !isPullingList else { return }
        
        isPullingList = true
        defer { isPullingList = false }
        
        do {
            let records = try await fetchAllRecords(recordType: Schema.itemType, predicate: NSPredicate(value: true), sort: [], zoneID: zoneID, in: db)
            
            var decoded: [ShoppingItem] = []
            decoded.reserveCapacity(records.count)
            
            for r in records {
                guard let data = r[Schema.itemPayloadField] as? Data else { continue }
                if let item = try? decoder.decode(ShoppingItem.self, from: data) {
                    decoded.append(item)
                }
            }
            
            await MainActor.run {
                manager.applyRemoteChange(.replaceAll(decoded))
            }
        } catch {
            await setErrorAsync("Sync Pull fehlgeschlagen: \(Self.userFacing(error))")
        }
    }
    
    private func pullChatNow() async {
        guard connectionState == .connected else { return }
        guard let db = activeDatabase, let zoneID = listZoneID else { return }
        
        do {
            let predicate: NSPredicate
            if let last = lastChatFetch {
                predicate = NSPredicate(format: "%K > %@", Schema.chatTimestampField, last as NSDate)
            } else {
                predicate = NSPredicate(value: true)
            }
            
            let sort = [NSSortDescriptor(key: Schema.chatTimestampField, ascending: true)]
            let records = try await fetchAllRecords(recordType: Schema.chatType, predicate: predicate, sort: sort, zoneID: zoneID, in: db)
            
            if records.isEmpty { return }
            
            var newMessages: [ChatMessage] = []
            newMessages.reserveCapacity(records.count)
            
            for r in records {
                guard
                    let sender = r[Schema.chatSenderField] as? String,
                    let text = r[Schema.chatTextField] as? String,
                    let ts = r[Schema.chatTimestampField] as? Date,
                    let uuid = UUID(uuidString: r.recordID.recordName)
                else { continue }
                
                newMessages.append(ChatMessage(id: uuid, sender: sender, text: text, timestamp: ts))
                lastChatFetch = max(lastChatFetch ?? ts, ts)
            }
            
            await MainActor.run {
                let existing = Set(self.chatMessages.map(\.id))
                for msg in newMessages where !existing.contains(msg.id) {
                    self.chatMessages.append(msg)
                }
            }
        } catch {
            // Chat-Polling darf nicht „hart“ failen
        }
    }
    
    private func subscribeToChat(in db: CKDatabase, zoneID: CKRecordZone.ID) async {
        let subscriptionID = "lb-chat-\(zoneID.zoneName)"
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)
        
        let info = CKSubscription.NotificationInfo()
        info.alertLocalizationKey = "Neue Nachricht von %1$@"
        info.alertLocalizationArgs = [Schema.chatSenderField]
        info.soundName = "default"
        
        subscription.notificationInfo = info
        subscription.recordType = Schema.chatType
        
        do {
            _ = try await modify(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [], in: db)
        } catch {
            // Subscription Fehler sind oft nicht kritisch (z.B. schon vorhanden), wir loggen nur
            print("Subscription Warning: \(error)")
        }
    }
    
    // MARK: - CloudKit helpers
    
    private func ensureICloudAvailable() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            container.accountStatus { status, error in
                if let error { cont.resume(throwing: error); return }
                guard status == .available else {
                    cont.resume(throwing: NSError(domain: "ListeByBache.CloudKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "iCloud ist nicht verfügbar (\(status.rawValue)). Bitte in iOS Einstellungen bei iCloud anmelden."]))
                    return
                }
                cont.resume(returning: ())
            }
        }
    }
    
    private func createZoneIfNeeded(zoneID: CKRecordZone.ID, in db: CKDatabase) async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await modify(zonesToSave: [zone], zoneIDsToDelete: [], in: db)
    }
    
    private func upsertShareCodeRecord(code: String, shareURL: URL) async throws {
        let recordID = CKRecord.ID(recordName: code)
        let record = CKRecord(recordType: Schema.shareCodeType, recordID: recordID)
        record[Schema.shareURLField] = shareURL.absoluteString as CKRecordValue
        _ = try await save(record: record, in: container.publicCloudDatabase)
    }
    
    private func fetchShareURL(for code: String) async throws -> URL {
        let id = CKRecord.ID(recordName: code)
        let record = try await fetch(recordID: id, in: container.publicCloudDatabase)
        guard let urlString = record[Schema.shareURLField] as? String, let url = URL(string: urlString) else {
            throw NSError(domain: "ListeByBache.CloudKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "Ungültiger Code oder Share-Link fehlt."])
        }
        return url
    }
    
    private func fetchShareMetadata(for url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { cont in
            let op = CKFetchShareMetadataOperation(shareURLs: [url])
            var captured: CKShare.Metadata?
            var capturedError: Error?
            op.perShareMetadataBlock = { _, metadata, error in
                if let error { capturedError = error; return }
                captured = metadata
            }
            op.fetchShareMetadataCompletionBlock = { error in
                if let error = capturedError ?? error {
                    cont.resume(throwing: error)
                    return
                }
                guard let metadata = captured else {
                    cont.resume(throwing: NSError(domain: "ListeByBache.CloudKit", code: 4, userInfo: [NSLocalizedDescriptionKey: "Share-Metadaten fehlen."]))
                    return
                }
                cont.resume(returning: metadata)
            }
            self.container.add(op)
        }
    }
    
    private func acceptShare(_ metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
            var capturedError: Error?
            op.perShareCompletionBlock = { _, _, error in
                if let error { capturedError = error }
            }
            op.acceptSharesCompletionBlock = { error in
                if let error = capturedError ?? error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
            self.container.add(op)
        }
    }
    
    private func setErrorAsync(_ msg: String) async {
        await MainActor.run {
            self.lastError = msg
        }
    }
    
    private static func userFacing(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == CKError.errorDomain {
            return ns.localizedDescription
        }
        return ns.localizedDescription
    }
    
    private static func makeCode(length: Int) -> String {
        let digits = Array("0123456789")
        return String((0..<max(1, length)).map { _ in digits.randomElement()! })
    }
    
    private func stopAll() {
        stopPolling()
        
        activeDatabase = nil
        listZoneID = nil
        chatMessages = []
        lastChatFetch = nil
        connectedPeers = []
        
        mode = .none
        currentCode = nil
        connectionState = .disconnected
        isHost = false
    }
}

// MARK: - CKDatabase async wrappers

private extension SharedListSessionManager {
    func fetch(recordID: CKRecord.ID, in db: CKDatabase) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { cont in
            db.fetch(withRecordID: recordID) { record, error in
                if let error { cont.resume(throwing: error); return }
                guard let record else {
                    cont.resume(throwing: NSError(domain: "ListeByBache.CloudKit", code: 10, userInfo: [NSLocalizedDescriptionKey: "Record fehlt."]))
                    return
                }
                cont.resume(returning: record)
            }
        }
    }
    
    func fetchIfExists(recordID: CKRecord.ID, in db: CKDatabase) async throws -> CKRecord? {
        do {
            return try await fetch(recordID: recordID, in: db)
        } catch {
            let ns = error as NSError
            if ns.domain == CKError.errorDomain, ns.code == CKError.unknownItem.rawValue {
                return nil
            }
            throw error
        }
    }
    
    func save(record: CKRecord, in db: CKDatabase) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { cont in
            db.save(record) { saved, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: saved ?? record)
            }
        }
    }
    
    func delete(recordID: CKRecord.ID, in db: CKDatabase) async throws -> CKRecord.ID {
        try await withCheckedThrowingContinuation { cont in
            db.delete(withRecordID: recordID) { deletedID, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: deletedID ?? recordID)
            }
        }
    }
    
    func modify(recordsToSave: [CKRecord], recordIDsToDelete: [CKRecord.ID], in db: CKDatabase) async throws -> ([CKRecord], [CKRecord.ID]) {
        try await withCheckedThrowingContinuation { cont in
            let op = CKModifyRecordsOperation(recordsToSave: recordsToSave.isEmpty ? nil : recordsToSave,
                                              recordIDsToDelete: recordIDsToDelete.isEmpty ? nil : recordIDsToDelete)
            op.savePolicy = .changedKeys
            op.qualityOfService = .userInitiated
            
            op.modifyRecordsCompletionBlock = { saved, deleted, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (saved ?? [], deleted ?? []))
            }
            db.add(op)
        }
    }
    
    func modify(zonesToSave: [CKRecordZone], zoneIDsToDelete: [CKRecordZone.ID], in db: CKDatabase) async throws -> ([CKRecordZone], [CKRecordZone.ID]) {
        try await withCheckedThrowingContinuation { cont in
            let op = CKModifyRecordZonesOperation(recordZonesToSave: zonesToSave.isEmpty ? nil : zonesToSave,
                                                  recordZoneIDsToDelete: zoneIDsToDelete.isEmpty ? nil : zoneIDsToDelete)
            op.qualityOfService = .userInitiated
            op.modifyRecordZonesCompletionBlock = { saved, deleted, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (saved ?? [], deleted ?? []))
            }
            db.add(op)
        }
    }
    
    func modify(subscriptionsToSave: [CKSubscription], subscriptionIDsToDelete: [CKSubscription.ID], in db: CKDatabase) async throws -> ([CKSubscription], [CKSubscription.ID]) {
        try await withCheckedThrowingContinuation { cont in
            let op = CKModifySubscriptionsOperation(subscriptionsToSave: subscriptionsToSave.isEmpty ? nil : subscriptionsToSave,
                                                    subscriptionIDsToDelete: subscriptionIDsToDelete.isEmpty ? nil : subscriptionIDsToDelete)
            op.qualityOfService = .userInitiated
            op.modifySubscriptionsCompletionBlock = { saved, deleted, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (saved ?? [], deleted ?? []))
            }
            db.add(op)
        }
    }
    
    func fetchAllRecords(recordType: String, predicate: NSPredicate, sort: [NSSortDescriptor], zoneID: CKRecordZone.ID, in db: CKDatabase) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { cont in
            let query = CKQuery(recordType: recordType, predicate: predicate)
            query.sortDescriptors = sort
            
            let op = CKQueryOperation(query: query)
            op.zoneID = zoneID
            op.qualityOfService = .utility
            
            var out: [CKRecord] = []
            op.recordFetchedBlock = { record in
                out.append(record)
            }
            op.queryCompletionBlock = { _, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: out)
            }
            
            db.add(op)
        }
    }
}

