//
//  ShoppingItem.swift
//  ListeByBache
//
//  Created by Christopher Bachmann on 10.12.25.
//

import Foundation
import Combine
import UIKit

enum ShoppingCategory: String, CaseIterable, Identifiable, Codable {
    case fleischWurst = "Fleisch & Wurst"
    case getraenke = "Getränke"
    case obstGemuese = "Obst & Gemüse"
    case drogerie = "Drogerie"
    case backwaren = "Backwaren"
    case milchprodukte = "Molkereiprodukte"
    case trockenprodukte = "Trockenprodukte"
    case fertigprodukte = "Fertigprodukte"
    case suessigkeiten = "Süßigkeiten & Snacks"
    case gewuerze = "Gewürze & Soßen"
    case haushalt = "Haushalt"
    case sonstige = "Sonstige"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .fleischWurst: return "fork.knife"
        case .getraenke: return "wineglass"
        case .obstGemuese: return "leaf"
        case .drogerie: return "bandage.fill"
        case .backwaren: return "bag.fill"
        case .milchprodukte: return "cup.and.saucer.fill"
        case .trockenprodukte: return "cube.box.fill"
        case .fertigprodukte: return "archivebox.fill"
        case .suessigkeiten: return "gift.fill"
        case .gewuerze: return "flame.fill"
        case .haushalt: return "house.fill"
        case .sonstige: return "ellipsis.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .fleischWurst: return "red"
        case .getraenke: return "blue"
        case .obstGemuese: return "green"
        case .drogerie: return "purple"
        case .backwaren: return "orange"
        case .milchprodukte: return "yellow"
        case .trockenprodukte: return "brown"
        case .fertigprodukte: return "gray"
        case .suessigkeiten: return "pink"
        case .gewuerze: return "indigo"
        case .haushalt: return "teal"
        case .sonstige: return "secondary"
        }
    }
}

struct ShoppingItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: ShoppingCategory
    var isChecked: Bool = false
    var quantity: Int = 1
    var unit: String = "Stk"
    var imageURL: URL? = nil
    
    init(name: String, category: ShoppingCategory? = nil, imageURL: URL? = nil) {
        self.id = UUID()
        self.name = name
        self.category = category ?? ShoppingItem.categorizeItem(name: name)
        self.imageURL = imageURL
    }
    
    static func categorizeItem(name: String) -> ShoppingCategory {
        let lowercaseName = name.lowercased()
        
        // Fleisch & Wurst
        if lowercaseName.contains("wurst") || lowercaseName.contains("schinken") || 
           lowercaseName.contains("salami") || lowercaseName.contains("fleisch") ||
           lowercaseName.contains("hack") || lowercaseName.contains("kotelett") ||
           lowercaseName.contains("steak") || lowercaseName.contains("braten") ||
           lowercaseName.contains("wurstwaren") || lowercaseName.contains("mett") {
            return .fleischWurst
        }
        
        // Getränke
        if lowercaseName.contains("bier") || lowercaseName.contains("wein") || 
           lowercaseName.contains("wasser") || lowercaseName.contains("saft") ||
           lowercaseName.contains("getränk") || lowercaseName.contains("cola") ||
           lowercaseName.contains("limo") || lowercaseName.contains("alkohol") ||
            lowercaseName.contains("schorle") || lowercaseName.contains("tee") ||
            lowercaseName.contains("kaffee") || lowercaseName.contains("trank") ||
            lowercaseName.contains("pils") || lowercaseName.contains("helles") ||
            lowercaseName.contains("radler") || lowercaseName.contains("weizen") ||
            lowercaseName.contains("stout") || lowercaseName.contains("ipa") ||
            lowercaseName.contains("lager") || lowercaseName.contains("ale") ||
            lowercaseName.contains("kölsch") || lowercaseName.contains("altbier") ||
            lowercaseName.contains("export") || lowercaseName.contains("malz") ||
            lowercaseName.contains("prosecco") || lowercaseName.contains("sekt") ||
            lowercaseName.contains("champagner") || lowercaseName.contains("spirituose") ||
            lowercaseName.contains("vodka") || lowercaseName.contains("wódka") ||
            lowercaseName.contains("whisky") || lowercaseName.contains("whiskey") ||
            lowercaseName.contains("gin") || lowercaseName.contains("rum") ||
            lowercaseName.contains("tequila") || lowercaseName.contains("brandy") ||
            lowercaseName.contains("cognac") || lowercaseName.contains("likör") ||
            lowercaseName.contains("schnaps") || lowercaseName.contains("cocktail") ||
            lowercaseName.contains("longdrink") || lowercaseName.contains("energy") ||
            lowercaseName.contains("iso") || lowercaseName.contains("smoothie") ||
            lowercaseName.contains("milch") || lowercaseName.contains("kakao") ||
            lowercaseName.contains("cappuccino") || lowercaseName.contains("espresso") ||
            lowercaseName.contains("drink") {
            return .getraenke
        }
        
        // Obst & Gemüse
        if lowercaseName.contains("apfel") || lowercaseName.contains("banane") || 
           lowercaseName.contains("tomate") || lowercaseName.contains("salat") ||
           lowercaseName.contains("kartoffel") || lowercaseName.contains("zwiebel") ||
           lowercaseName.contains("karotte") || lowercaseName.contains("gurke") ||
           lowercaseName.contains("obst") || lowercaseName.contains("gemüse") ||
           lowercaseName.contains("frucht") || lowercaseName.contains("beere") {
            return .obstGemuese
        }
        
        // Drogerie
        if lowercaseName.contains("zahnbürste") || lowercaseName.contains("zahnpasta") || 
           lowercaseName.contains("ohrstäbchen") || lowercaseName.contains("abschmink") ||
           lowercaseName.contains("shampoo") || lowercaseName.contains("duschgel") ||
           lowercaseName.contains("seife") || lowercaseName.contains("creme") ||
           lowercaseName.contains("drogerie") || lowercaseName.contains("kosmetik") ||
           lowercaseName.contains("taschentuch") || lowercaseName.contains("watte") {
            return .drogerie
        }
        
        // Backwaren
        if lowercaseName.contains("brot") || lowercaseName.contains("brötchen") || 
           lowercaseName.contains("gebäck") || lowercaseName.contains("kuchen") ||
           lowercaseName.contains("mehl") || lowercaseName.contains("back") {
            return .backwaren
        }
        
        // Molkereiprodukte
        if lowercaseName.contains("käse") || lowercaseName.contains("milch") || 
           lowercaseName.contains("joghurt") || lowercaseName.contains("butter") ||
           lowercaseName.contains("quark") || lowercaseName.contains("eier") {
            return .milchprodukte
        }
        
        // Trockenprodukte
        if lowercaseName.contains("nudeln") || lowercaseName.contains("reis") || 
           lowercaseName.contains("haferflocken") || lowercaseName.contains("müsli") ||
           lowercaseName.contains("zucker") || lowercaseName.contains("salz") {
            return .trockenprodukte
        }
        
        // Süßigkeiten
        if lowercaseName.contains("schokolade") || lowercaseName.contains("bonbon") || 
           lowercaseName.contains("kekse") || lowercaseName.contains("chips") ||
           lowercaseName.contains("süß") || lowercaseName.contains("snack") {
            return .suessigkeiten
        }
        
        // Gewürze & Soßen
        if lowercaseName.contains("gewürz") || lowercaseName.contains("soße") || 
           lowercaseName.contains("ketchup") || lowercaseName.contains("senf") ||
           lowercaseName.contains("essig") || lowercaseName.contains("öl") {
            return .gewuerze
        }
        
        // Haushalt
        if lowercaseName.contains("spüli") || lowercaseName.contains("putz") || 
           lowercaseName.contains("müll") || lowercaseName.contains("taschen") ||
           lowercaseName.contains("haushalt") {
            return .haushalt
        }
        
        return .sonstige
    }
}

// MARK: - Item artwork (lokal, ohne externe APIs)

extension ShoppingItem {
    /// Ein „passendes Bild“ als SF Symbol – deterministisch „zufällig“ pro Item (stabil über App-Starts).
    var artworkSymbolName: String {
        let n = name.lowercased()
        
        // Keyword-Overrides (wirkt „intelligenter“ als nur Kategorie)
        if n.contains("milch") { return validate("carton.fill") }
        if n.contains("käse") || n.contains("kaese") { return validate("takeoutbag.and.cup.and.straw.fill") }
        if n.contains("brot") || n.contains("bröt") || n.contains("broet") { return validate("bag.fill") }
        if n.contains("apfel") || n.contains("banane") || n.contains("obst") { return validate("leaf.fill") }
        if n.contains("wasser") { return validate("drop.fill") }
        if n.contains("bier") { return validate("mug.fill") }
        if n.contains("wein") { return validate("wineglass.fill") }
        if n.contains("kaffee") { return validate("cup.and.saucer.fill") }
        if n.contains("tee") { return validate("cup.and.saucer") }
        if n.contains("schokolade") { return validate("gift.fill") }
        if n.contains("chips") { return validate("takeoutbag.and.cup.and.straw.fill") }
        
        let options = ShoppingItem.symbolOptions(for: category)
        let idx = ShoppingItem.stableIndex(from: id, modulo: options.count)
        return validate(options[idx])
    }
    
    private func validate(_ systemName: String) -> String {
        UIImage(systemName: systemName) == nil ? category.systemImage : systemName
    }
    
    private static func symbolOptions(for category: ShoppingCategory) -> [String] {
        switch category {
        case .fleischWurst:
            return ["fork.knife", "takeoutbag.and.cup.and.straw.fill", "fish.fill"]
        case .getraenke:
            return ["cup.and.saucer.fill", "wineglass.fill", "drop.fill", "mug.fill"]
        case .obstGemuese:
            return ["leaf.fill", "carrot.fill", "basket.fill", "cart.fill"]
        case .drogerie:
            return ["bandage.fill", "cross.case.fill", "sparkles", "drop.degreesign.fill"]
        case .backwaren:
            return ["bag.fill", "takeoutbag.and.cup.and.straw.fill", "gift.fill", "cart.fill"]
        case .milchprodukte:
            return ["carton.fill", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill", "cart.fill"]
        case .trockenprodukte:
            return ["cube.box.fill", "shippingbox.fill", "takeoutbag.and.cup.and.straw.fill", "cart.fill"]
        case .fertigprodukte:
            return ["archivebox.fill", "takeoutbag.and.cup.and.straw.fill", "cart.fill"]
        case .suessigkeiten:
            return ["gift.fill", "birthday.cake.fill", "takeoutbag.and.cup.and.straw.fill"]
        case .gewuerze:
            return ["flame.fill", "drop.fill", "leaf.fill"]
        case .haushalt:
            return ["house.fill", "trash.fill", "sparkles"]
        case .sonstige:
            return ["cart.fill", "tag.fill", "sparkles", "ellipsis.circle.fill"]
        }
    }
    
    private static func stableIndex(from uuid: UUID, modulo: Int) -> Int {
        guard modulo > 0 else { return 0 }
        let hex = uuid.uuidString.replacingOccurrences(of: "-", with: "")
        let tail = String(hex.suffix(2))
        let seed = Int(tail, radix: 16) ?? 0
        return seed % modulo
    }
}

class ShoppingListManager: ObservableObject {
    @Published var items: [ShoppingItem] = []
    
    // Asynchrone Suche via OpenFoodFacts
    func searchProducts(query: String) async -> [ShoppingItem] {
        return await OpenFoodFactsService.shared.search(query: query)
    }
    
    private let storageKey = "shopping_items_storage"
    /// Wird bei lokalen Änderungen aufgerufen (für Live-Sync). Remote-Änderungen sollen das NICHT triggern.
    var onLocalChange: ((ShoppingListChange) -> Void)?
    private var suppressLocalNotifications = false

    init() {
        load()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([ShoppingItem].self, from: data)
            self.items = decoded
        } catch {
            print("Fehler beim Laden: \(error)")
        }
    }

    // Save on changes
    private func persist() {
        save()
    }

    // Hook persistence into mutations
    func addItem(_ item: ShoppingItem) {
        items.append(item)
        persist()
        notify(.add(item))
    }

    func removeItem(_ item: ShoppingItem) {
        items.removeAll { $0.id == item.id }
        persist()
        notify(.remove(item.id))
    }

    func toggleItem(_ item: ShoppingItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isChecked.toggle()
            persist()
            notify(.toggle(item.id))
        }
    }
    
    func getItemsByCategory() -> [ShoppingCategory: [ShoppingItem]] {
        Dictionary(grouping: items) { $0.category }
    }
    
    func getCheckedItems() -> [ShoppingItem] {
        items.filter { $0.isChecked }
    }
    
    func getUncheckedItems() -> [ShoppingItem] {
        items.filter { !$0.isChecked }
    }
    
    func clearCheckedItems() {
        items.removeAll { $0.isChecked }
        persist()
        notify(.clearChecked)
    }
    
    func replaceAll(_ newItems: [ShoppingItem]) {
        self.items = newItems
        persist()
        notify(.replaceAll(newItems))
    }

    /// Wendet eine Änderung an, die von einem anderen Gerät kam, ohne sie erneut zu „broadcasten“.
    func applyRemoteChange(_ change: ShoppingListChange) {
        suppressLocalNotifications = true
        defer { suppressLocalNotifications = false }
        
        switch change.kind {
        case .add:
            if let item = change.item {
                items.append(item)
                persist()
            }
        case .remove:
            if let id = change.id {
                items.removeAll { $0.id == id }
                persist()
            }
        case .toggle:
            if let id = change.id, let idx = items.firstIndex(where: { $0.id == id }) {
                items[idx].isChecked.toggle()
                persist()
            }
        case .clearChecked:
            items.removeAll { $0.isChecked }
            persist()
        case .replaceAll:
            if let items = change.items {
                self.items = items
                persist()
            }
        }
    }
    
    private func notify(_ change: ShoppingListChange) {
        guard !suppressLocalNotifications else { return }
        onLocalChange?(change)
    }
}

// MARK: - Shared change model

struct ShoppingListChange: Codable {
    enum Kind: String, Codable {
        case add
        case remove
        case toggle
        case clearChecked
        case replaceAll
    }
    
    var kind: Kind
    var item: ShoppingItem?
    var id: UUID?
    var items: [ShoppingItem]?
    
    static func add(_ item: ShoppingItem) -> ShoppingListChange {
        ShoppingListChange(kind: .add, item: item, id: nil, items: nil)
    }
    
    static func remove(_ id: UUID) -> ShoppingListChange {
        ShoppingListChange(kind: .remove, item: nil, id: id, items: nil)
    }
    
    static func toggle(_ id: UUID) -> ShoppingListChange {
        ShoppingListChange(kind: .toggle, item: nil, id: id, items: nil)
    }
    
    static var clearChecked: ShoppingListChange {
        ShoppingListChange(kind: .clearChecked, item: nil, id: nil, items: nil)
    }
    
    static func replaceAll(_ items: [ShoppingItem]) -> ShoppingListChange {
        ShoppingListChange(kind: .replaceAll, item: nil, id: nil, items: items)
    }
}

// MARK: - OpenFoodFacts Service

struct OFFProduct: Codable {
    let product_name: String?
    let image_url: String?
    let image_front_url: String?
    let image_small_url: String?
    let brands: String?
    let categories_tags: [String]?
    
    // Für die spätere Verwendung beim Mapping
    var bestImageURL: URL? {
        if let s = image_url ?? image_front_url ?? image_small_url {
            return URL(string: s)
        }
        return nil
    }
}

struct OFFSearchResponse: Codable {
    let products: [OFFProduct]?
    let count: Int?
}

class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    
    private init() {}
    
    func search(query: String) async -> [ShoppingItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let encodedQuery = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // page_size=20 für mehr Ergebnisse
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encodedQuery)&search_simple=1&action=process&json=1&page_size=20"
        
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(OFFSearchResponse.self, from: data)
            
            guard let products = response.products else { return [] }
            
            return products.compactMap { product in
                guard let name = product.product_name, !name.isEmpty else { return nil }
                
                var displayName = name
                if let brand = product.brands, !brand.isEmpty {
                    displayName = "\(brand) - \(name)"
                }
                
                // Kategorie-Erkennung via API Tags
                var category: ShoppingCategory? = nil
                if let tags = product.categories_tags {
                    // Check auf Getränke
                    if tags.contains(where: { tag in
                        let t = tag.lowercased()
                        return t.contains("beverage") || t.contains("drink") || t.contains("water") ||
                               t.contains("wine") || t.contains("beer") || t.contains("juice") ||
                               t.contains("soda") || t.contains("tea") || t.contains("coffee") ||
                               t.contains("milk") || t.contains("lemonade")
                    }) {
                        category = .getraenke
                    }
                    
                    // Check auf Snacks/Süßigkeiten
                    else if tags.contains(where: { $0.contains("snack") || $0.contains("sweet") || $0.contains("chocolate") || $0.contains("candy") }) {
                        category = .suessigkeiten
                    }
                }
                
                // Wir nutzen den Namen für die Standard-Kategorisierung, falls API nichts lieferte
                let item = ShoppingItem(name: displayName, category: category, imageURL: product.bestImageURL)
                return item
            }
        } catch {
            print("OpenFoodFacts Error: \(error)")
            return []
        }
    }
}

