import SwiftUI

struct PTChatView: View {

    struct Message: Identifiable {
        let id = UUID()
        let role: Role
        let text: String
        enum Role { case user, assistant }
    }

    @State private var messages: [Message] = [
        .init(role: .assistant,
              text: "Hey, I'm your HEX PT. Ask me anything about your programme.")
    ]
    @State private var input: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { m in
                            messageBubble(m)
                                .id(m.id)
                        }
                    }
                    .padding(HexTheme.padBase)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            // Composer
            HStack(spacing: 10) {
                TextField("Ask your PT…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(HexTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(HexTheme.cardBorder, lineWidth: 1)
                    )
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(HexTheme.accent))
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, HexTheme.padBase)
            .padding(.vertical, 10)
            .background(HexTheme.bg)
        }
        .hexBackground()
        .navigationTitle("PT")
    }

    @ViewBuilder
    private func messageBubble(_ m: Message) -> some View {
        HStack {
            if m.role == .user { Spacer(minLength: 40) }
            Text(m.text)
                .font(.system(size: 15))
                .foregroundStyle(m.role == .user ? .black : HexTheme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(m.role == .user ? HexTheme.accent : HexTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(m.role == .user ? Color.clear : HexTheme.cardBorder, lineWidth: 1)
                )
            if m.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messages.append(.init(role: .user, text: text))
        input = ""
        // TODO: call Claude API and append assistant reply
        messages.append(.init(role: .assistant,
                              text: "Got it. (PT chat backend coming soon.)"))
    }
}
