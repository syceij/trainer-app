import SwiftUI

/// 6-digit OTP verification screen. Individual boxes with auto-advance.
struct OTPView: View {
    @EnvironmentObject var app: AppState

    let email: String

    @State private var digits: [String] = Array(repeating: "", count: 6)
    @State private var isLoading = false
    @State private var isResending = false
    @State private var errorMsg: String?
    @FocusState private var focusedIndex: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                VStack(spacing: 8) {
                    Text("Check your email")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(HexTheme.text)
                    Text("We sent a 6-digit code to")
                        .font(.system(size: 14))
                        .foregroundStyle(HexTheme.textMuted)
                    Text(email)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HexTheme.accent)
                }
                .padding(.top, 32)
                .padding(.horizontal, HexTheme.padBase)

                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { i in
                        otpBox(at: i)
                    }
                }
                .padding(.horizontal, HexTheme.padBase)

                if let err = errorMsg {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(HexTheme.danger)
                        .padding(.horizontal, HexTheme.padBase)
                }

                Button(action: verify) {
                    if isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text("Verify")
                    }
                }
                .buttonStyle(HexPrimaryButton())
                .disabled(isLoading || code.count != 6)
                .padding(.horizontal, HexTheme.padBase)

                Button(action: resend) {
                    if isResending {
                        ProgressView().tint(HexTheme.accent)
                    } else {
                        Text("Resend code")
                            .foregroundStyle(HexTheme.accent)
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .disabled(isResending)

                Spacer(minLength: 40)
            }
        }
        .hexBackground()
        .navigationBarHidden(true)
        .onAppear { focusedIndex = 0 }
    }

    // MARK: - One digit box

    private func otpBox(at i: Int) -> some View {
        TextField("", text: Binding(
            get: { digits[i] },
            set: { newValue in
                let filtered = newValue.filter(\.isNumber)
                if filtered.count <= 1 {
                    digits[i] = filtered
                    if !filtered.isEmpty && i < 5 {
                        focusedIndex = i + 1
                    } else if filtered.isEmpty && i > 0 {
                        // user deleted — go back
                        focusedIndex = i - 1
                    }
                } else if filtered.count == 6 {
                    // user pasted full code
                    for (j, ch) in filtered.enumerated() where j < 6 {
                        digits[j] = String(ch)
                    }
                    focusedIndex = nil
                }
            }
        ))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.center)
        .font(.system(size: 22, weight: .bold).monospacedDigit())
        .foregroundStyle(HexTheme.text)
        .frame(width: 48, height: 56)
        .background(
            RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                .fill(HexTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                .stroke(focusedIndex == i ? HexTheme.accent : HexTheme.cardBorder,
                        lineWidth: focusedIndex == i ? 2 : 1)
        )
        .focused($focusedIndex, equals: i)
    }

    private var code: String { digits.joined() }

    // MARK: - Actions

    private func verify() {
        Task {
            isLoading = true
            errorMsg  = nil
            defer { isLoading = false }
            do {
                try await app.verifyOTP(email: email, token: code)
            } catch {
                errorMsg = error.localizedDescription
            }
        }
    }

    private func resend() {
        Task {
            isResending = true
            errorMsg = nil
            defer { isResending = false }
            do {
                try await app.resendOTP(email: email)
                app.showToast("Code resent")
            } catch {
                errorMsg = error.localizedDescription
            }
        }
    }
}
