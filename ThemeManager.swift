import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var accentColor: Color {
        switch self {
        case .dark:
            return .white // Strikte Vorgabe: Weiß im Dark Mode
        default:
            return .blue
        }
    }
    
    var backgroundGradient: LinearGradient? {
        switch self {
        case .dark:
            return LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .brandTop, location: 0.0),
                    .init(color: .brandMid, location: 0.55),
                    .init(color: .brandBottom, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            return nil
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .dark:
            return Color.black.opacity(0.9)
        default:
            return Color(.systemBackground)
        }
    }
    
    var surfaceColor: Color {
        switch self {
        case .dark:
            return Color.white.opacity(0.12)
        default:
            return Color.white
        }
    }
}

final class ThemeManager: ObservableObject {
    private let storageKey = "selectedTheme"
    
    @Published var selection: AppTheme {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: storageKey)
        }
    }
    
    init() {
        let stored = UserDefaults.standard.string(forKey: storageKey)
        selection = AppTheme(rawValue: stored ?? "") ?? .system
    }
    
    @ViewBuilder
    var background: some View {
        if let gradient = selection.backgroundGradient {
            gradient
        } else {
            selection.backgroundColor
        }
    }
    
    var colorScheme: ColorScheme? { selection.colorScheme }
    var accentColor: Color { selection.accentColor }
    var surfaceColor: Color { selection.surfaceColor }
    
    var primaryTextColor: Color {
        selection == .dark ? Color.white : Color.primary
    }
    
    var secondaryTextColor: Color {
        selection == .dark ? Color.white.opacity(0.9) : Color.secondary
    }
}

extension Color {
    static let brandTop = Color(red: 18/255, green: 33/255, blue: 103/255)
    static let brandMid = Color(red: 53/255, green: 27/255, blue: 125/255)
    static let brandBottom = Color(red: 94/255, green: 23/255, blue: 111/255)

}

