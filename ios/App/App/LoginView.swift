import SwiftUI

/// Login screen — mirrors LoginView in src/components/AuthScreen.jsx.
/// Accepts either email or username. Logo image, labelled fields, error banner.
struct LoginView: View {
    @EnvironmentObject var app: AppState

    @State private var emailOrUsername = ""
    @State private var password        = ""
    @State private var showPassword    = false
    @State private var isLoading       = false
    @State private var errorMsg: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case identifier, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Logo ──────────────────────────────────────────
                if focusedField == nil {
                    HStack {
                        Spacer()
                        Image("LoginLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 160)
                        Spacer()
                    }
                    .padding(.bottom, 32)
                    .transition(.opacity)
                }

                // ── Heading ───────────────────────────────────────
                Text(app.language == "ar" ? "مرحباً بعودتك" : "Welcome back")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(HexTheme.text)
                    .padding(.bottom, 6)

                Text(app.language == "ar" ? "سجّل الدخول للمتابعة" : "Sign in to continue")
                    .font(.system(size: 14))
                    .foregroundStyle(HexTheme.dim)
                    .padding(.bottom, 28)

                if let err = errorMsg {
                    HexErrorBanner(msg: err)
                        .padding(.bottom, 16)
                }

                // ── Email / username field ────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    HexFieldLabel(text: app.language == "ar"
                                  ? "البريد الإلكتروني أو اسم المستخدم"
                                  : "Email or username")
                    TextField(app.language == "ar"
                              ? "البريد الإلكتروني أو @اسم_المستخدم"
                              : "Email or @username",
                              text: $emailOrUsername)
                        .textFieldStyle(HexTextFieldStyle(
                            focused: focusedField == .identifier
                        ))
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .identifier)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }
                .padding(.bottom, 14)

                // ── Password field with show/hide ─────────────────
                VStack(alignment: .leading, spacing: 6) {
                    HexFieldLabel(text: app.language == "ar"
                                  ? "كلمة المرور" : "Password")
                    passwordField
                }
                .padding(.bottom, 8)

                // ── Sign in button ────────────────────────────────
                Button(action: signIn) {
                    if isLoading {
                        ProgressView()
                            .tint(HexTheme.mute)
                    } else {
                        Text(app.language == "ar" ? "تسجيل الدخول" : "Sign in")
                    }
                }
                .buttonStyle(HexPrimaryButton(
                    disabled: emailOrUsername.isEmpty || password.isEmpty || isLoading
                ))
                .disabled(emailOrUsername.isEmpty || password.isEmpty || isLoading)
                .padding(.top, 8)

                // ── Switch to signup ──────────────────────────────
                HStack(spacing: 4) {
                    Text(app.language == "ar"
                         ? "ليس لديك حساب؟" : "Don't have an account?")
                        .foregroundStyle(HexTheme.dim)
                    NavigationLink(destination: SignupView()) {
                        Text(app.language == "ar" ? "إنشاء حساب" : "Sign up")
                            .foregroundStyle(HexTheme.accent)
                            .fontWeight(.heavy)
                    }
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
        .overlay(alignment: .topTrailing) { languageToggle }
        .navigationBarHidden(true)
    }

    // MARK: - Password field with eye toggle

    @ViewBuilder
    private var passwordField: some View {
        ZStack(alignment: .trailing) {
            Group {
                if showPassword {
                    TextField("••••••••", text: $password)
                        .textContentType(.password)
                } else {
                    SecureField("••••••••", text: $password)
                        .textContentType(.password)
                }
            }
            .textFieldStyle(HexTextFieldStyle(focused: focusedField == .password))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit { signIn() }

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

    // MARK: - Language toggle (top-right)

    private var languageToggle: some View {
        Button {
            app.language = app.language == "ar" ? "en" : "ar"
        } label: {
            Text(app.language == "ar" ? "EN" : "AR")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(HexTheme.dim)
                .kerning(0.6)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .padding(.top, 12)
        .padding(.trailing, 20)
    }

    // MARK: - Action

    private func signIn() {
        focusedField = nil
        Task {
            isLoading = true
            errorMsg  = nil
            defer { isLoading = false }
            do {
                try await app.signIn(
                    emailOrUsername: emailOrUsername,
                    password: password
                )
            } catch AppState.AuthError.usernameNotFound {
                errorMsg = app.language == "ar"
                    ? "لا يوجد حساب بهذا الاسم."
                    : "No account found with that username."
            } catch {
                // Deliberately vague for security — matches React behaviour
                errorMsg = app.language == "ar"
                    ? "البريد الإلكتروني/اسم المستخدم أو كلمة المرور غير صحيحة."
                    : "Incorrect email/username or password."
            }
        }
    }
}
