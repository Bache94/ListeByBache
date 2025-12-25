import SwiftUI

struct ChatView: View {
    @ObservedObject var session: SharedListSessionManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var draft = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(session.chatMessages) { msg in
                            messageRow(msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: session.chatMessages.count) { _, _ in
                    if let last = session.chatMessages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            HStack(spacing: 10) {
                TextField("Nachricht…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                
                Button("Senden", action: send)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(themeManager.surfaceColor)
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeManager.accentColor)
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    @ViewBuilder
    private func messageRow(_ msg: ChatMessage) -> some View {
        let isMine = msg.sender == UIDevice.current.name
        
        HStack {
            if isMine { Spacer(minLength: 0) }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(msg.sender)
                    .font(.caption)
                    .foregroundColor(themeManager.selection == .dark ? .white.opacity(0.75) : .secondary)
                
                Text(msg.text)
                    .foregroundColor(themeManager.selection == .dark ? .white : .primary)
            }
            .padding(10)
            .background(isMine ? themeManager.accentColor.opacity(themeManager.selection == .dark ? 0.25 : 0.15) : themeManager.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            if !isMine { Spacer(minLength: 0) }
        }
    }
    
    private func send() {
        let text = draft
        draft = ""
        session.sendChat(text: text)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}


