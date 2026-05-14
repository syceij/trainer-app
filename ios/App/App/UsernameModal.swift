import SwiftUI

/// Bottom-sheet shown when a signed-in user doesn't have a username yet —
/// port of `src/components/shared/UsernameModal.jsx`. Blocks the rest of
/// the app until they pick one (since friend search and leaderboard rows
/// rely on usernames).
struct UsernameModal: View {

    @EnvironmentObject var app: AppState

    @State private var value = ""
    @State private var status: Status = .idle
    @State private var saving = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    enum Status { case idle, invalid, checking, available, taken }

    private var ar: Bool { app.language == "ar" }

    private static let re = try! NSRegularExpression(
        pattern: "^[A-Za-z0-9_]{3,20}$", options: []
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // grabber
            Capsule()
                .fill(HexTheme.surface2)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .padding(.bottom, 14)

            Text(ar ? "اختر اسم مستخدم" : "Pick a username")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(HexTheme.text)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            Text(ar
                 ? "هذا الاسم سيراه أصدقاؤك. لا يمكن تغييره لاحقاً بسهولة."
                 : "This is what your Bros will see. Choose carefully — it's hard to change later.")
                .font(.system(size: 13))
                .foregroundColor(HexTheme.mute)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Image(systemName: "at")
                    .font(.system(size: 14))
                    .foregroundColor(HexTheme.mute)
                TextField("username", text: $value)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(HexTheme.text)
                    .onChange(of: value) { newValue in
                        handleChange(newValue)
                    }
                statusIcon
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .padding(.horizontal, 20)

            Text(hintText)
                .font(.system(size: 12))
                .foregroundColor(hintColor)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 18)

            Button { Task { await save() } } label: {
                HStack {
                    if saving {
                        ProgressView().tint(.black)
                    } else {
                        Text(ar ? "احفظ" : "Save username")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(canSave ? .black : HexTheme.mute)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(canSave ? HexTheme.accent : HexTheme.surface2)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(HexTheme.surface.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focused = true
            }
        }
    }

    // MARK: - Status helpers

    private var canSave: Bool { status == .available && !saving }

    private var borderColor: Color {
        switch status {
        case .available: return HexTheme.accent
        case .taken, .invalid: return Color(red: 1.0, green: 0.42, blue: 0.42)
        default: return HexTheme.border
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .checking:
            ProgressView().scaleEffect(0.7).tint(HexTheme.mute)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(HexTheme.accent)
        case .taken, .invalid:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
        default:
            EmptyView()
        }
    }

    private var hintText: String {
        switch status {
        case .idle:      return ar ? "٣–٢٠ حرفاً، أحرف/أرقام/_" : "3–20 chars, letters / numbers / _"
        case .invalid:   return ar ? "أحرف، أرقام، أو _ فقط" : "3–20 chars, letters / numbers / _ only"
        case .checking:  return ar ? "جارٍ التحقق…" : "Checking…"
        case .available: return ar ? "✓ متاح" : "✓ Username available!"
        case .taken:     return ar ? "غير متاح — جرّب اسماً آخر" : "Already taken — try another"
        }
    }

    private var hintColor: Color {
        switch status {
        case .available: return HexTheme.accent
        case .taken, .invalid: return Color(red: 1.0, green: 0.42, blue: 0.42)
        default: return HexTheme.mute
        }
    }

    // MARK: - Behaviour

    private func handleChange(_ raw: String) {
        let v = raw.trimmingCharacters(in: .whitespaces)
        status = .idle
        searchTask?.cancel()
        if v.isEmpty { return }
        let range = NSRange(v.startIndex..., in: v)
        if Self.re.firstMatch(in: v, range: range) == nil {
            status = .invalid
            return
        }
        status = .checking
        searchTask = Task { [weak app] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            let taken = (try? await SupabaseManager.shared
                .isUsernameTaken(v)) ?? true
            if Task.isCancelled { return }
            await MainActor.run {
                if app != nil { status = taken ? .taken : .available }
            }
        }
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        guard let uid = SupabaseManager.shared.currentUser?.id else { return }
        saving = true
        let lowered = value.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            // Build a profile-update payload that only writes username.
            struct Patch: Encodable { let username: String }
            _ = try await SupabaseManager.shared.client
                .from("profiles")
                .update(Patch(username: lowered))
                .eq("id", value: uid)
                .execute()
            await app.loadOwnProfile()
            app.needsUsername = false
            app.toast = ar ? "تم حفظ اسم المستخدم ✓" : "Username saved ✓"
        } catch {
            print("[UsernameModal] save failed:", error)
            status = .taken
            saving = false
        }
    }
}
