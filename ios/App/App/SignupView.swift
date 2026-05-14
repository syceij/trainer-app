import SwiftUI

struct SignupView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name      = ""
    @State private var username  = ""
    @State private var email     = ""
    @State private var password  = ""
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Join HEX")
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundStyle(HexTheme.text)
                    Text("Start tracking your strength.")
                        .font(.system(size: 14))
                        .foregroundStyle(HexTheme.textMuted)
                }
                .padding(.top, 16)

                VStack(spacing: 14) {
                    TextField("Name", text: $name)
                        .textFieldStyle(HexTextFieldStyle())
                        .textContentType(.name)

                    TextField("Username", text: $username)
                        .textFieldStyle(HexTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Email", text: $email)
                        .textFieldStyle(HexTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Password (8+ chars)", text: $password)
                        .textFieldStyle(HexTextFieldStyle())
                        .textContentType(.newPassword)
                }

                if let err = errorMsg {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(HexTheme.danger)
                }

                Button(action: signUp) {
                    if isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text("Create account")
                    }
                }
                .buttonStyle(HexPrimaryButton())
                .disabled(isLoading || !canSubmit)

                Button("Back to sign in") { dismiss() }
                    .font(.system(size: 14))
                    .foregroundStyle(HexTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, HexTheme.padBase)
        }
        .hexBackground()
        .navigationBarHidden(true)
    }

    private var canSubmit: Bool {
        !name.isEmpty &&
        !username.isEmpty &&
        !email.isEmpty &&
        password.count >= 8
    }

    private func signUp() {
        Task {
            isLoading = true
            errorMsg  = nil
            defer { isLoading = false }
            do {
                try await app.signUp(
                    name: name,
                    username: username,
                    email: email,
                    password: password
                )
                // AppState will switch authPhase to .awaitingOTP — the root
                // view picks that up and shows OTPView automatically.
            } catch {
                errorMsg = error.localizedDescription
            }
        }
    }
}
