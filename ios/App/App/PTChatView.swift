import SwiftUI

/// PT chat — mirrors src/components/PTTab.jsx.
/// Header with account button, message bubbles with asymmetric corners,
/// suggestion chips when empty, input bar with square send button.
struct PTChatView: View {
    @EnvironmentObject var app: AppState

    struct Message: Identifiable {
        let id = UUID()
        let role: Role
        let text: String
        enum Role { case user, assistant }
    }

    @State private var messages: [Message] = []
    @State private var input: String = ""
    @State private var isTyping: Bool = false
    @FocusState private var inputFocused: Bool

    private var ar: Bool { app.language == "ar" }

    private var chips: [String] {
        ar
        ? ["ما هي جلستي القادمة؟", "غيّر إلى دمبلز فقط", "أضف تمارين الذراعين", "أشعر بالتعب"]
        : ["What's my next session?", "Change to dumbbells only", "Add more arm work", "I'm feeling fatigued"]
    }

    private var showChips: Bool { messages.count <= 2 && input.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
            if showChips { chipsRow }
            composer
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ar ? "اسأل المدرب" : "Ask PT")
                    .font(.system(size: 22, weight: .heavy))
                    .kerning(ar ? 0 : -0.4)
                    .foregroundColor(HexTheme.text)
                Text(ar
                     ? "تدريب ذكي · تعديلات البرنامج · تعليمات الشكل"
                     : "AI coaching · programme adjustments · form cues")
                    .font(.system(size: 12))
                    .foregroundColor(HexTheme.dim)
            }
            Spacer()

            // Account chip
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 15))
                    .foregroundColor(HexTheme.accent)
                Text(app.currentProfile?.name ?? (ar ? "الحساب" : "Account"))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(HexTheme.dim)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 80)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1.5)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .overlay(
            Rectangle()
                .fill(HexTheme.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    emptyState
                        .padding(.top, 24)
                        .padding(.horizontal, 16)
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { m in
                            bubble(m)
                                .id(m.id)
                        }
                        if isTyping { typingIndicator }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last?.id {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🏋️")
                .font(.system(size: 32))
                .padding(.bottom, 4)
            Text(ar ? "مدرّبك الشخصي" : "Your personal trainer")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(HexTheme.text)
            Text(ar
                 ? "اسأل أي شيء عن تدريبك، عدّل برنامجك، أو احصل على تعليمات الشكل."
                 : "Ask anything about your training, adjust your programme, or get coaching cues.")
                .font(.system(size: 13))
                .foregroundColor(HexTheme.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func bubble(_ m: Message) -> some View {
        HStack {
            if m.role == .user { Spacer(minLength: 40) }
            Text(m.text)
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundColor(m.role == .user ? .black : HexTheme.text)
                .fontWeight(m.role == .user ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    UnevenRoundedRectangle(cornerRadii: bubbleCorners(m.role),
                                           style: .continuous)
                        .fill(m.role == .user ? HexTheme.accent : HexTheme.surface2)
                )
            if m.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private func bubbleCorners(_ role: Message.Role) -> RectangleCornerRadii {
        // user:      14, 14, 4, 14  (small bottom-right corner)
        // assistant: 14, 14, 14, 4  (small bottom-left corner)
        if role == .user {
            return .init(topLeading: 14, bottomLeading: 14,
                         bottomTrailing: 4, topTrailing: 14)
        } else {
            return .init(topLeading: 14, bottomLeading: 4,
                         bottomTrailing: 14, topTrailing: 14)
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(HexTheme.dim)
                    .frame(width: 6, height: 6)
                    .modifier(BounceDot(delay: Double(i) * 0.15))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chips

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        send(chip)
                    } label: {
                        Text(chip)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(HexTheme.dim)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(HexTheme.surface2)
                            )
                            .overlay(
                                Capsule().stroke(HexTheme.border, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: 8) {
            TextField(ar ? "اسأل مدرّبك..." : "Ask your trainer...",
                      text: $input, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 16))
                .foregroundColor(HexTheme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(HexTheme.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(inputFocused ? HexTheme.accent : HexTheme.border,
                                lineWidth: 1.5)
                )
                .focused($inputFocused)

            Button {
                send(input)
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(canSend ? .black : HexTheme.mute)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(canSend ? HexTheme.accent : HexTheme.surface2)
                    )
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(HexTheme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(
            Rectangle()
                .fill(HexTheme.border)
                .frame(height: 1),
            alignment: .top
        )
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Send

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let userMsg = Message(role: .user, text: trimmed)
        messages.append(userMsg)
        input = ""
        isTyping = true

        // Build a Context from AppState — read-only slice the matcher uses.
        let ctx = PTReplies.Context(
            bodyweight:          nil,   // bodyweight isn't persisted yet
            currentSession:      app.currentSession,
            activeProgrammeName: app.activeProgramme?.name,
            programmeWeeks:      app.activeProgramme?.data?.weeks ?? [],
            history:             app.workoutHistory,
            workingWeights:      app.workingWeights
        )
        // Generate reply on a background hop, then apply any mutations.
        Task {
            try? await Task.sleep(nanoseconds: UInt64.random(in: 400_000_000...800_000_000))
            let reply = PTReplies.reply(to: trimmed, ctx: ctx)
            await MainActor.run {
                isTyping = false
                messages.append(.init(role: .assistant, text: reply.text))
                applyMutations(reply.mutations)
                if let toast = reply.toast { app.toast = toast }
            }
        }
    }

    /// Translate PTReplies mutation enums into AppState calls.
    private func applyMutations(_ mutations: [PTReplies.Mutation]) {
        for m in mutations {
            switch m {
            case .lighterToday:
                app.scaleCurrentSessionWeights(by: 0.9)
            case .bumpLift(let name, let deltaKg):
                Task { await app.bumpLiftInCurrentSession(name: name, deltaKg: deltaKg) }
            }
        }
    }
}

/// Small animated bounce modifier for the typing dots.
private struct BounceDot: ViewModifier {
    let delay: Double
    @State private var bouncing = false

    func body(content: Content) -> some View {
        content
            .offset(y: bouncing ? -4 : 0)
            .animation(
                .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: bouncing
            )
            .onAppear { bouncing = true }
    }
}
