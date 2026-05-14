import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState

    @State private var email     = ""
    @State private var password  = ""
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Logo + tagline
                VStack(alignment: .leading, spacing: 8) {
                    Text("HEX")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(HexTheme.accent)
                    Text("Your strength. Tracked.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(HexTheme.textMuted)
                }
                .padding(.top, 32)

                // Form
                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textFieldStyle(HexTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $password)
                        .textFieldStyle(HexTextFieldStyle())
                        .textContentType(.password)
                }

                if let err = errorMsg {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(HexTheme.danger)
                }

                // Sign in button
                Button(action: signIn) {
                    if isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text("Sign in")
                    }
                }
                .buttonStyle(HexPrimaryButton())
                .disabled(isLoading || email.isEmpty || password.isEmpty)

                // Link to signup
                NavigationLink(destination: SignupView()) {
                    HStack(spacing: 4) {
                        Text("New here?")
                            .foregroundStyle(HexTheme.textMuted)
                        Text("Create an account")
                            .foregroundStyle(HexTheme.accent)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, HexTheme.padBase)
        }
        .hexBackground()
        .navigationBarHidden(true)
    }

    private func signIn() {
        Task {
            isLoading = true
            errorMsg  = nil
            defer { isLoading = false }
            do {
                try await app.signIn(email: email, password: password)
            } catch {
                errorMsg = error.localizedDescription
            }
        }
    }
}
