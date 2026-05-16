import SwiftUI

/// Signup screen — mirrors SignupView in src/components/AuthScreen.jsx.
/// Real-time username availability check + labelled fields + error banner.
struct SignupView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name           = ""
    @State private var username       = ""
    @State private var email          = ""
    @State private var password       = ""
    @State private var showPassword   = false
    @State private var usernameStatus: UsernameStatus = .idle
    @State private var checkTask: Task<Void, Never>?
    @State private var isLoading      = false
    @State private var errorMsg: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, username, email, password }

    private enum UsernameStatus: Equatable {
        case idle, short, checking, available, taken, invalid
    }

    /// Letters, digits, underscore; 3–20 chars.
    private static let usernamePattern = "^[a-z0-9_]{3,20}$"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                if focusedField == nil {
                    HStack {
                        Spacer()
                        Image("LoginLogo")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(HexTheme.accent)
                            .frame(height: 160)
                        Spacer()
                    }
                    .padding(.bottom, 32)
                    .transition(.opacity)
                }

                Text(app.language == "ar" ? "إنشاء حساب" : "Create account")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(HexTheme.text)
                    .padding(.bottom, 6)

                Text(app.language == "ar"
                     ? "ابدأ رحلتك التدريبية"
                     : "Start your training journey")
                    .font(.system(size: 14))
                    .foregroundStyle(HexTheme.dim)
                    .padding(.bottom, 28)

                if let err = errorMsg {
                    HexErrorBanner(msg: err)
                        .padding(.bottom, 16)
                }

                // ── Name ──────────────────────────────────────────
                fieldGroup(label: app.language == "ar" ? "الاسم" : "Name") {
                    TextField(app.language == "ar" ? "اسمك" : "Your name",
                              text: $name)
                        .textFieldStyle(HexTextFieldStyle(focused: focusedField == .name))
                        .textContentType(.givenName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .username }
                }
                .padding(.bottom, 14)

                // ── Username ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    HexFieldLabel(text: app.language == "ar"
                                  ? "اسم المستخدم" : "Username")
                    ZStack(alignment: .trailing) {
                        TextField("e.g. ahmed_lifts", text: $username)
                            .textFieldStyle(HexTextFieldStyle(
                                focused: focusedField == .username,
                                hasError: usernameStatus == .taken
                                       || usernameStatus == .invalid
                            ))
                            .textContentType(.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onChange(of: username) { newValue in
                                handleUsernameChange(newValue)
                            }
                            .onSubmit { focusedField = .email }

                        usernameStatusIcon
                            .padding(.trailing, 14)
                    }
                    Text(usernameHint)
                        .font(.system(size: 11))
                        .foregroundStyle(usernameHintColor)
                }
                .padding(.bottom, 14)

                // ── Email ─────────────────────────────────────────
                fieldGroup(label: app.language == "ar"
                           ? "البريد الإلكتروني" : "Email") {
                    TextField("you@example.com", text: $email)
                        .textFieldStyle(HexTextFieldStyle(focused: focusedField == .email))
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }
                .padding(.bottom, 14)

                // ── Password ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    HexFieldLabel(text: app.language == "ar"
                                  ? "كلمة المرور" : "Password")
                    ZStack(alignment: .trailing) {
                        Group {
                            if showPassword {
                                TextField(app.language == "ar"
                                          ? "الحد الأدنى ٦ أحرف"
                                          : "Min. 6 characters",
                                          text: $password)
                            } else {
                                SecureField(app.language == "ar"
                                            ? "الحد الأدنى ٦ أحرف"
                                            : "Min. 6 characters",
                                            text: $password)
                            }
                        }
                        .textFieldStyle(HexTextFieldStyle(focused: focusedField == .password))
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { signUp() }

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .font(.system(size: 16))
                                .foregroundStyle(HexTheme.mute)
                                .frame(width: 36, height: 36)
                        }
                        .padding(.trailing, 6)
                    }
                }
                .padding(.bottom, 8)

                // ── Create account button ────────────────────────
                Button(action: signUp) {
                    if isLoading {
                        ProgressView().tint(HexTheme.mute)
                    } else {
                        Text(app.language == "ar" ? "إنشاء حساب" : "Create account")
                    }
                }
                .buttonStyle(HexPrimaryButton(disabled: !canSubmit || isLoading))
                .disabled(!canSubmit || isLoading)
                .padding(.top, 8)

                // ── Switch to login ───────────────────────────────
                HStack(spacing: 4) {
                    Text(app.language == "ar"
                         ? "لديك حساب بالفعل؟" : "Already have an account?")
                        .foregroundStyle(HexTheme.dim)
                    Button(app.language == "ar"
                           ? "تسجيل الدخول" : "Sign in") {
                        dismiss()
                    }
                    .foregroundStyle(HexTheme.accent)
                    .fontWeight(.heavy)
                }
                .font(.system(size: 13))
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
            .padding(.top, focusedField == nil ? 40 : 20)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.22), value: focusedField == nil)
        }
        .scrollDismissesKeyboard(.interactively)
        .hexAuthBackground()
        .navigationBarHidden(true)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func fieldGroup<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HexFieldLabel(text: label)
            content()
        }
    }

    @ViewBuilder
    private var usernameStatusIcon: some View {
        switch usernameStatus {
        case .available:
            Text("✓")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(HexTheme.success)
        case .taken:
            Text("✗")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(HexTheme.danger)
        case .checking:
            ProgressView().scaleEffect(0.7).tint(HexTheme.mute)
        default:
            EmptyView()
        }
    }

    private var usernameHint: String {
        let ar = app.language == "ar"
        switch usernameStatus {
        case .invalid:   return ar ? "أحرف وأرقام و _ فقط" : "Letters, numbers and _ only"
        case .checking:  return ar ? "جارٍ التحقق من التوفر…" : "Checking availability…"
        case .available: return ar ? "✓ متاح" : "✓ Available"
        case .taken:     return ar ? "✗ مأخوذ بالفعل" : "✗ Already taken"
        default:         return ar
                ? "٣-٢٠ حرفاً · أحرف وأرقام و _ فقط"
                : "3–20 chars · letters, numbers and _ only"
        }
    }

    private var usernameHintColor: Color {
        switch usernameStatus {
        case .available:           return HexTheme.success
        case .taken, .invalid:     return HexTheme.danger
        default:                   return HexTheme.mute
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        usernameStatus == .available &&
        !email.isEmpty &&
        password.count >= 6
    }

    private func handleUsernameChange(_ raw: String) {
        // Lowercase + strip whitespace to match React behaviour.
        let cleaned = raw.lowercased().filter { !$0.isWhitespace }
        if cleaned != raw { username = cleaned; return }

        checkTask?.cancel()

        if cleaned.isEmpty { usernameStatus = .idle; return }
        if cleaned.count < 3 { usernameStatus = .short; return }
        if cleaned.range(of: Self.usernamePattern, options: .regularExpression) == nil {
            usernameStatus = .invalid
            return
        }

        usernameStatus = .checking
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // debounce 500ms
            if Task.isCancelled { return }
            do {
                let taken = try await SupabaseManager.shared.isUsernameTaken(cleaned)
                if Task.isCancelled { return }
                await MainActor.run {
                    usernameStatus = taken ? .taken : .available
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run { usernameStatus = .idle }
            }
        }
    }

    // MARK: - Action

    private func signUp() {
        focusedField = nil
        Task {
            isLoading = true
            errorMsg  = nil
            defer { isLoading = false }
            do {
                try await app.signUp(
                    name: name.trimmingCharacters(in: .whitespaces),
                    username: username,
                    email: email,
                    password: password
                )
            } catch {
                let lower = error.localizedDescription.lowercased()
                if lower.contains("already") && lower.contains("registered") {
                    errorMsg = app.language == "ar"
                        ? "يوجد حساب بهذا البريد. جرّب تسجيل الدخول."
                        : "An account with this email already exists. Try signing in."
                } else {
                    errorMsg = error.localizedDescription
                }
            }
        }
    }
}
