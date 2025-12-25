import SwiftUI

private struct CategoryGroup: Identifiable {
    let category: ShoppingCategory
    let items: [ShoppingItem]
    var id: String { category.id }
}

struct OpenItemsView: View {
    @ObservedObject var manager: ShoppingListManager
    @EnvironmentObject private var themeManager: ThemeManager

    private var groupedOpenItems: [CategoryGroup] {
        let dict = manager.getItemsByCategory().mapValues { $0.filter { !$0.isChecked } }
        // Keep only non-empty categories and sort by category display name
        return dict
            .filter { !$0.value.isEmpty }
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { CategoryGroup(category: $0.key, items: $0.value) }
    }

    var body: some View {
        List {
            if groupedOpenItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "cart")
                        .font(.system(size: 40))
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text("Keine offenen Artikel")
                        .foregroundColor(themeManager.secondaryTextColor)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowSeparator(.hidden)
            } else {
                ForEach(groupedOpenItems) { group in
                    Section(header: HStack {
                        Image(systemName: group.category.systemImage)
                            .foregroundColor(colorFromString(group.category.color))
                        Text(group.category.rawValue)
                    }
                    .accessibilityAddTraits(.isHeader)
                    ) {
                        ForEach(group.items) { item in
                            Button {
                                manager.toggleItem(item)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack {
                                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(item.isChecked ? .green : .gray)
                                    Image(systemName: item.artworkSymbolName)
                                        .foregroundColor(colorFromString(item.category.color))
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                        Text("\(item.quantity) \(item.unit)")
                                            .font(.caption)
                                            .foregroundColor(themeManager.secondaryTextColor)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Offene Artikel")
        .tint(themeManager.accentColor)
        .preferredColorScheme(themeManager.colorScheme)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Alle abhaken") {
                    // Mark all open items as checked
                    for (_, items) in manager.getItemsByCategory() {
                        for item in items where !item.isChecked {
                            manager.toggleItem(item)
                        }
                    }
                }
                .disabled(groupedOpenItems.isEmpty)
            }
        }
    }

    private func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "yellow": return .yellow
        case "brown": return .brown
        case "gray": return .gray
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        default: return .secondary
        }
    }
}

#Preview {
    let manager = ShoppingListManager()
    manager.addItem(ShoppingItem(name: "Äpfel"))
    manager.addItem(ShoppingItem(name: "Brot"))
    return NavigationStack { OpenItemsView(manager: manager) }
        .environmentObject(ThemeManager())
}

