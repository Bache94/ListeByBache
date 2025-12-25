import Foundation

struct Suggestion: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let category: ShoppingCategory
}

enum SuggestionProvider {
    private static let all: [Suggestion] = [
        // Obst & Gemüse
        .init(name: "Äpfel", category: .obstGemuese),
        .init(name: "Bananen", category: .obstGemuese),
        .init(name: "Tomaten", category: .obstGemuese),
        .init(name: "Gurken", category: .obstGemuese),
        .init(name: "Paprika", category: .obstGemuese),
        .init(name: "Salat", category: .obstGemuese),
        .init(name: "Kartoffeln", category: .obstGemuese),
        .init(name: "Zwiebeln", category: .obstGemuese),
        .init(name: "Knoblauch", category: .obstGemuese),
        .init(name: "Karotten", category: .obstGemuese),
        .init(name: "Avocado", category: .obstGemuese),
        .init(name: "Zitrone", category: .obstGemuese),
        .init(name: "Beerenmix", category: .obstGemuese),
        
        // Getränke
        .init(name: "Wasser", category: .getraenke),
        .init(name: "Sprudel", category: .getraenke),
        .init(name: "Apfelschorle", category: .getraenke),
        .init(name: "Cola", category: .getraenke),
        .init(name: "Saft", category: .getraenke),
        .init(name: "Bier", category: .getraenke),
        .init(name: "Wein", category: .getraenke),
        .init(name: "Kaffee", category: .getraenke),
        .init(name: "Tee", category: .getraenke),
        
        // Backwaren
        .init(name: "Brot", category: .backwaren),
        .init(name: "Brötchen", category: .backwaren),
        .init(name: "Toast", category: .backwaren),
        .init(name: "Croissants", category: .backwaren),
        .init(name: "Wraps", category: .backwaren),
        
        // Molkereiprodukte
        .init(name: "Milch", category: .milchprodukte),
        .init(name: "Hafermilch", category: .milchprodukte),
        .init(name: "Butter", category: .milchprodukte),
        .init(name: "Joghurt", category: .milchprodukte),
        .init(name: "Käse", category: .milchprodukte),
        .init(name: "Mozzarella", category: .milchprodukte),
        .init(name: "Eier", category: .milchprodukte),
        .init(name: "Quark", category: .milchprodukte),
        
        // Trockenprodukte
        .init(name: "Nudeln", category: .trockenprodukte),
        .init(name: "Spaghetti", category: .trockenprodukte),
        .init(name: "Penne", category: .trockenprodukte),
        .init(name: "Reis", category: .trockenprodukte),
        .init(name: "Couscous", category: .trockenprodukte),
        .init(name: "Haferflocken", category: .trockenprodukte),
        .init(name: "Mehl", category: .trockenprodukte),
        .init(name: "Zucker", category: .trockenprodukte),
        .init(name: "Salz", category: .trockenprodukte),
        .init(name: "Müsli", category: .trockenprodukte),
        
        // Fleisch & Wurst
        .init(name: "Hähnchenbrust", category: .fleischWurst),
        .init(name: "Hackfleisch", category: .fleischWurst),
        .init(name: "Salami", category: .fleischWurst),
        .init(name: "Schinken", category: .fleischWurst),
        .init(name: "Bratwürste", category: .fleischWurst),
        
        // Fertigprodukte
        .init(name: "TK-Pizza", category: .fertigprodukte),
        .init(name: "TK-Gemüse", category: .fertigprodukte),
        .init(name: "Lasagne", category: .fertigprodukte),
        .init(name: "Gnocchi", category: .fertigprodukte),
        
        // Süßigkeiten & Snacks
        .init(name: "Schokolade", category: .suessigkeiten),
        .init(name: "Chips", category: .suessigkeiten),
        .init(name: "Gummibärchen", category: .suessigkeiten),
        .init(name: "Nüsse", category: .suessigkeiten),
        .init(name: "Eis", category: .suessigkeiten),
        
        // Gewürze & Soßen
        .init(name: "Ketchup", category: .gewuerze),
        .init(name: "Senf", category: .gewuerze),
        .init(name: "Mayonnaise", category: .gewuerze),
        .init(name: "Pesto", category: .gewuerze),
        .init(name: "Öl", category: .gewuerze),
        .init(name: "Essig", category: .gewuerze),
        .init(name: "Gewürzmischung", category: .gewuerze),
        .init(name: "Sojasoße", category: .gewuerze),
        
        // Drogerie
        .init(name: "Zahnpasta", category: .drogerie),
        .init(name: "Zahnbürsten", category: .drogerie),
        .init(name: "Duschgel", category: .drogerie),
        .init(name: "Shampoo", category: .drogerie),
        .init(name: "Deo", category: .drogerie),
        .init(name: "Taschentücher", category: .drogerie),
        .init(name: "Abschminktücher", category: .drogerie),
        
        // Haushalt
        .init(name: "Spüli", category: .haushalt),
        .init(name: "Müllbeutel", category: .haushalt),
        .init(name: "Küchenrolle", category: .haushalt),
        .init(name: "Toilettenpapier", category: .haushalt),
        .init(name: "Schwämme", category: .haushalt),
        .init(name: "Waschmittel", category: .haushalt),
        .init(name: "Allzweckreiniger", category: .haushalt),
        
        // Sonstige
        .init(name: "Batterien", category: .sonstige),
        .init(name: "Kerzen", category: .sonstige),
        .init(name: "Geschenkpapier", category: .sonstige)
    ]
    
    static func suggestions(for query: String, limit: Int = 8) -> [Suggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 2 else { return [] }
        
        let matches = all.compactMap { suggestion -> (Suggestion, Int)? in
            let name = suggestion.name.lowercased()
            if name.hasPrefix(trimmed) {
                return (suggestion, 0) // Top priority: prefix
            } else if name.contains(trimmed) {
                return (suggestion, 1) // Secondary: substring
            }
            return nil
        }
        
        return matches
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.name < rhs.0.name
                }
                return lhs.1 < rhs.1
            }
            .prefix(limit)
            .map { $0.0 }
    }
}

