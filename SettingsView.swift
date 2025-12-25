import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: ShoppingListManager
    @ObservedObject var session: SharedListSessionManager
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("viewStyle") private var storedViewStyle: String = ViewStyle.grid.rawValue
    @State private var showClearAllAlert = false
    @State private var joinCode = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section(header: Text("Gemeinsame Liste")) {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(statusText)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                if let code = session.currentCode {
                    HStack {
                        Text("Code")
                        Spacer()
                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(themeManager.accentColor)
                    }
                    Text("Synchronisation über iCloud/CloudKit. Alle müssen in iOS bei iCloud angemeldet sein.")
                        .font(.footnote)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                if !session.connectedPeers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Teilnehmer")
                            .font(.footnote)
                            .foregroundColor(themeManager.secondaryTextColor)
                        ForEach(session.connectedPeers, id: \.self) { name in
                            Label(name, systemImage: "person.fill")
                                .font(.subheadline)
                        }
                    }
                }
                
                if session.connectionState == .connected {
                    NavigationLink(destination: ChatView(session: session)) {
                        Label("Chat öffnen", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                }
                
                if session.connectionState == .disconnected {
                    Button {
                        session.generateNewCode()
                    } label: {
                        Label("Code erstellen (Host)", systemImage: "qrcode")
                    }
                    
                    HStack {
                        TextField("Code eingeben", text: $joinCode)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        Button("Beitreten") {
                            session.join(code: joinCode)
                            joinCode = ""
                        }
                        .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    Button("Verbindung trennen", role: .destructive) {
                        session.leave()
                    }
                }
                
                if let err = session.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("Daten")) {
                Button("Alle erledigten löschen", role: .destructive) {
                    manager.clearCheckedItems()
                }
                Button("Alle Artikel löschen", role: .destructive) {
                    showClearAllAlert = true
                }
            }
            
            Section(header: Text("Design")) {
                Picker("Erscheinungsbild", selection: $themeManager.selection) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                
                if themeManager.selection == .dark {
                    Label("Nutze die Farben der Start-Animation", systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                Picker("Startansicht", selection: $storedViewStyle) {
                    Text("Kacheln").tag(ViewStyle.grid.rawValue)
                    Text("Liste").tag(ViewStyle.list.rawValue)
                }
                .pickerStyle(.segmented)
                Text("Legt fest, ob Kategorien als Kacheln oder Liste angezeigt werden.")
                    .font(.footnote)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            
            Section(header: Text("Prospekte & Angebote"), footer: Text("Externe Links zu aktuellen Prospekten der Märkte.")) {
                prospektLink(title: "Lidl Prospekte", urlString: "https://www.lidl.de/l/prospekte/")
                prospektLink(title: "Netto Prospekte", urlString: "https://www.netto-online.de/prospekte")
                prospektLink(title: "Kaufland Prospekte", urlString: "https://www.kaufland.de/prospekte/")
                prospektLink(title: "Aldi Nord Prospekte", urlString: "https://www.aldi-nord.de/prospekte.html")
                prospektLink(title: "Aldi Süd Prospekte", urlString: "https://www.aldi-sued.de/de/angebote/prospekte.html")
            }

            Section(header: Text("Feedback")) {
                Button("App im App Store bewerten") {
                    if let url = appStoreURL {
                        openURL(url)
                    }
                }
                if let url = appStoreURL {
                    ShareLink("App weiterempfehlen", item: url)
                } else {
                    Text("App-Link nicht gesetzt")
                        .font(.footnote)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                Text("Bitte bewerte die App im App Store und empfehle sie weiter, danke!")
                    .font(.footnote)
                    .foregroundColor(themeManager.secondaryTextColor)
            }

            Section(header: Text("App")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersionString)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
        .navigationTitle("Einstellungen")
        .alert("Alle Artikel löschen?", isPresented: $showClearAllAlert) {
            Button("Löschen", role: .destructive) {
                manager.replaceAll([])
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Dieser Vorgang kann nicht rückgängig gemacht werden.")
        }
        .tint(themeManager.accentColor)
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
    
    private var appStoreURL: URL? {
        // Bitte eigene App-Store-ID eintragen
        URL(string: "https://apps.apple.com/app/id0000000000")
    }
    
    private var statusText: String {
        switch session.connectionState {
        case .disconnected: return "Nicht verbunden"
        case .hosting: return "Host wird erstellt…"
        case .joining: return "Verbinde…"
        case .connected: return session.isHost ? "Verbunden (Host)" : "Verbunden"
        }
    }

    @ViewBuilder
    private func prospektLink(title: String, urlString: String) -> some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                Label(title, systemImage: "link")
                    .foregroundColor(themeManager.primaryTextColor) // Explizit Theme Farbe nutzen
            }
        }
    }
}

#Preview {
    let m = ShoppingListManager()
    let s = SharedListSessionManager()
    s.bind(to: m)
    return NavigationStack { SettingsView(manager: m, session: s) }
        .environmentObject(ThemeManager())
}

struct ConnectView: View {
    @ObservedObject var session: SharedListSessionManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var joinCode = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Verbinde dich mit Freunden oder Familie, um die Einkaufsliste gemeinsam zu nutzen und zu chatten.")
                            .font(.subheadline)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                
                Section(header: Text("Verbindungsstatus")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(statusText)
                            .foregroundColor(themeManager.accentColor)
                    }
                    
                    if let code = session.currentCode {
                        VStack(spacing: 12) {
                            Text("Dein Code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(code)
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.accentColor)
                                .padding()
                                .background(themeManager.surfaceColor)
                                .cornerRadius(12)
                                .contextMenu {
                                    Button {
                                        UIPasteboard.general.string = code
                                    } label: {
                                        Label("Kopieren", systemImage: "doc.on.doc")
                                    }
                                }
                            
                            Text("Gib diesen Code an andere weiter, damit sie beitreten können.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                }
                
                if session.connectionState == .disconnected {
                    Section(header: Text("Hosten")) {
                        Button {
                            session.generateNewCode()
                        } label: {
                            Label("Neuen Code erstellen", systemImage: "qrcode")
                                .foregroundColor(themeManager.accentColor)
                        }
                    }
                    
                    Section(header: Text("Beitreten")) {
                        HStack {
                            TextField("Code eingeben", text: $joinCode)
                                .keyboardType(.numberPad)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                            
                            Button("Beitreten") {
                                session.join(code: joinCode)
                                joinCode = ""
                            }
                            .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    Section {
                        if !session.connectedPeers.isEmpty {
                            ForEach(session.connectedPeers, id: \.self) { peer in
                                Label(peer, systemImage: "person.fill")
                            }
                        } else {
                            Text("Warte auf Teilnehmer...")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Teilnehmer")
                    }
                    
                    Section {
                        Button("Verbindung trennen", role: .destructive) {
                            session.leave()
                            dismiss()
                        }
                    }
                }
                
                if let err = session.lastError {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Gemeinsam nutzen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
        .tint(themeManager.accentColor)
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    private var statusText: String {
        switch session.connectionState {
        case .disconnected: return "Nicht verbunden"
        case .hosting: return "Host wird erstellt…"
        case .joining: return "Verbinde…"
        case .connected: return session.isHost ? "Verbunden (Host)" : "Verbunden"
        }
    }
}
