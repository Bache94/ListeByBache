import Foundation

enum ViewStyle: String, CaseIterable, Identifiable {
    case grid
    case list
    
    var id: String { rawValue }
}

