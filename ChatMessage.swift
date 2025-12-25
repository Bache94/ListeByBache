import Foundation

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let sender: String
    let text: String
    let timestamp: Date
}

