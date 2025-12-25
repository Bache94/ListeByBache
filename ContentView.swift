//
//  ContentView.swift
//  ListeByBache
//
//  Created by Christopher Bachmann on 10.12.25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var shoppingListManager = ShoppingListManager()
    @StateObject private var sessionManager = SharedListSessionManager()
    @AppStorage("viewStyle") private var storedViewStyle: String = ViewStyle.grid.rawValue
    @State private var newItemName = ""
    @State private var suggestions: [Suggestion] = []
    @State private var selectedCategoryForNewItem: ShoppingCategory? = nil
    @State private var showingStartAnimation = true
    @State private var selectedCategory: ShoppingCategory? = nil
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var didBindSession = false
    
    @Namespace private var categoryNS
    @State private var showingSettings = false
    @State private var showingConnectSheet = false

    var body: some View {
        Group {
            if showingStartAnimation {
                StartAnimation()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            showingStartAnimation = false
                        }
                    }
            } else {
                mainContentView
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    // MARK: - Main Layout
    private var mainContentView: some View {
        ZStack {
            // Background
            themeManager.background
                .ignoresSafeArea()
            
            NavigationStack {
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            headerView
                            
                            // Content
                            ZStack {
                                if let selectedCategory = selectedCategory {
                                    categoryDetailView(category: selectedCategory)
                                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                removal: .move(edge: .leading).combined(with: .opacity)))
                                } else {
                                    if resolvedViewStyle == .grid {
                                        categoriesGridView
                                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                                                    removal: .move(edge: .trailing).combined(with: .opacity)))
                                    } else {
                                        categoriesListView
                                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                                                    removal: .move(edge: .trailing).combined(with: .opacity)))
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 140) // Platz für InputArea
                    }
                    .scrollIndicators(.hidden)
                    
                    // Floating Input Area
                    inputAreaView
                }
                .navigationBarHidden(true) // Wir bauen unseren eigenen Header
            }
            .tint(themeManager.accentColor)
        }
        .sheet(isPresented: $showingConnectSheet) {
            ConnectView(session: sessionManager)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView(manager: shoppingListManager, session: sessionManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fertig") { showingSettings = false }
                        }
                    }
            }
        }
        .onAppear {
            if !didBindSession {
                sessionManager.bind(to: shoppingListManager)
                didBindSession = true
            }
        }
    }
    
    private var resolvedViewStyle: ViewStyle {
        ViewStyle(rawValue: storedViewStyle) ?? .grid
    }
    
    // MARK: - Modern Header
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ListeByBache")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text("\(shoppingListManager.getUncheckedItems().count) offene Artikel")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .contentTransition(.numericText())
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // Chat / Connect Button
                Button {
                    // Quick Chat Access logic
                     showingConnectSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(themeManager.surfaceColor)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        Image(systemName: sessionManager.connectionState == .connected ? "message.fill" : "person.2.fill")
                            .foregroundColor(themeManager.accentColor)
                        
                        if sessionManager.connectionState == .connected && !sessionManager.chatMessages.isEmpty {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .offset(x: 14, y: -14)
                        }
                    }
                }
                
                // Settings Button
                Button {
                    showingSettings = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(themeManager.surfaceColor)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Categories Grid
    private var categoriesGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 20)], spacing: 20) {
            ForEach(ShoppingCategory.allCases) { category in
                categoryCard(category: category)
            }
        }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: shoppingListManager.items.count)
    }
    
    // MARK: - Categories List
    private var categoriesListView: some View {
        VStack(spacing: 12) {
            ForEach(ShoppingCategory.allCases) { category in
                let itemsInCategory = shoppingListManager.getItemsByCategory()[category] ?? []
                let uncheckedItems = itemsInCategory.filter { !$0.isChecked }
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        selectedCategory = category
                    }
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(colorFromString(category.color).opacity(0.2))
                                .frame(width: 48, height: 48)
                            Image(systemName: category.systemImage)
                                .font(.body)
                                .foregroundColor(colorFromString(category.color))
                        }
                        
                        Text(category.rawValue)
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Spacer()
                        
                        if !itemsInCategory.isEmpty {
                            Text("\(uncheckedItems.count)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.secondaryTextColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(themeManager.selection == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.05))
                                .clipShape(Capsule())
                        }
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(themeManager.secondaryTextColor)
                            .font(.subheadline)
                    }
                    .padding(16)
                    .background(themeManager.surfaceColor)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(themeManager.selection == .dark ? 0.2 : 0.05), radius: 10, x: 0, y: 5)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Modern Category Card
    private func categoryCard(category: ShoppingCategory) -> some View {
        let itemsInCategory = shoppingListManager.getItemsByCategory()[category] ?? []
        let uncheckedItems = itemsInCategory.filter { !$0.isChecked }
        let baseColor = colorFromString(category.color)
        
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                selectedCategory = category
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: category.systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(baseColor)
                        .matchedGeometryEffect(id: "icon-\(category.rawValue)", in: categoryNS)
                    Spacer()
                    if !itemsInCategory.isEmpty {
                        Text("\(uncheckedItems.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(baseColor)
                            .padding(6)
                            .background(baseColor.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
                
                Text(category.rawValue)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(themeManager.primaryTextColor)
                    .lineLimit(1)
            }
            .padding(16)
            .frame(height: 110)
            .background(
                ZStack {
                    themeManager.surfaceColor
                    // Subtiler Farb-Verlauf basierend auf Kategorie
                    LinearGradient(
                        colors: [baseColor.opacity(0.15), baseColor.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: baseColor.opacity(0.15), radius: 10, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(themeManager.selection == .dark ? 0.1 : 0.5), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
    
    // MARK: - Detail View
    private func categoryDetailView(category: ShoppingCategory) -> some View {
        VStack(spacing: 20) {
            // Title Row
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        selectedCategory = nil
                    }
                }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(themeManager.primaryTextColor)
                        .padding(10)
                        .background(themeManager.surfaceColor)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(category.rawValue)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                // Placeholder for symmetry
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 24)
            
            // Items
            let items = shoppingListManager.getItemsByCategory()[category] ?? []
            
            if items.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
                    Text("Noch leer hier...")
                        .font(.headline)
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                }
                .frame(height: 300)
            } else {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        itemRow(item: item)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Item Row (Updated to Cards)
    private func itemRow(item: ShoppingItem) -> some View {
        HStack(spacing: 16) {
            Button(action: {
                shoppingListManager.toggleItem(item)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(item.isChecked ? .green : themeManager.secondaryTextColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(item.isChecked)
                    .foregroundColor(item.isChecked ? themeManager.secondaryTextColor : themeManager.primaryTextColor)
                
                if item.quantity != 1 {
                    Text("\(item.quantity) \(item.unit)")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            
            Spacer()
            
            if item.isChecked {
                Button(role: .destructive) {
                    withAnimation {
                        shoppingListManager.removeItem(item)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding(16)
        .background(themeManager.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Floating Input Area
    private var inputAreaView: some View {
        VStack(spacing: 0) {
            if !suggestions.isEmpty {
                suggestionsListView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            HStack(spacing: 12) {
                // Input Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    TextField("", text: $newItemName, prompt: Text("Neues hinzufügen...").foregroundColor(themeManager.secondaryTextColor))
                        .foregroundColor(themeManager.primaryTextColor)
                        .submitLabel(.done)
                        .onSubmit {
                            addItem()
                        }
                        .onChange(of: newItemName) { _, _ in updateSuggestions() }
                    
                    if !newItemName.isEmpty {
                        Button {
                            newItemName = ""
                            suggestions = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                }
                .padding(16)
                .background(themeManager.surfaceColor)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                // Add Button (FAB Style)
                Button {
                    addItem()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: themeManager.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .padding(.top, 10)
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    }
                }
                .ignoresSafeArea()
        )
    }
    
    private var suggestionsListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    Button {
                        addSuggestedItem(suggestion)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: suggestion.category.systemImage)
                                .foregroundColor(colorFromString(suggestion.category.color))
                            Text(suggestion.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(themeManager.surfaceColor)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }
    
    private func addItem() {
        let trimmedName = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            let newItem = ShoppingItem(name: trimmedName, category: selectedCategoryForNewItem)
            shoppingListManager.addItem(newItem)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            newItemName = ""
            suggestions = []
        }
    }
    
    private func addSuggestedItem(_ suggestion: Suggestion) {
        let item = ShoppingItem(name: suggestion.name, category: suggestion.category)
        shoppingListManager.addItem(item)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        newItemName = ""
        suggestions = []
    }
    
    private func updateSuggestions() {
        suggestions = SuggestionProvider.suggestions(for: newItemName)
    }
    
    private func deleteItems(_ offsets: IndexSet, in items: [ShoppingItem]) {
        let toRemove = offsets.compactMap { index in
            (index >= 0 && index < items.count) ? items[index] : nil
        }
        for item in toRemove {
            shoppingListManager.removeItem(item)
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

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
}
