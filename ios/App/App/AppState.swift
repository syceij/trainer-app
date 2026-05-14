import Foundation
import SwiftUI
import Supabase

/// Top-level observable state shared across the app.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Auth

    enum AuthPhase: Equatable {
        case checking      // initial load — restoring session
        case signedOut
        case awaitingOTP(email: String)
        case signedIn
    }

    @Published var authPhase: AuthPhase = .checking
    @Published var currentProfile: Profile?

    // MARK: - Programme + session state

    @Published var activeProgramme: Programme?
    @Published var currentSession: WorkoutSession?

    // MARK: - UI state

    @Published var language: String = "en"   // "en" | "ar"
    @Published var toast: String?

    // MARK: - Init / session restore

    init() {
        Task { await restoreSession() }
    }

    /// On launch, check whether Supabase has a stored session and update phase.
    func restoreSession() async {
        let sb = SupabaseManager.shared
        do {
            // .session throws if no session is stored
            _ = try await sb.client.auth.session
            authPhase = .signedIn
            await loadOwnProfile()
        } catch {
            authPhase = .signedOut
        }
    }

    // MARK: - Auth actions

    func signIn(email: String, password: String) async throws {
        _ = try await SupabaseManager.shared.signIn(email: email, password: password)
        authPhase = .signedIn
        await loadOwnProfile()
    }

    func signUp(name: String, username: String, email: String, password: String) async throws {
        let metadata: [String: AnyJSON] = [
            "name":     .string(name),
            "username": .string(username)
        ]
        _ = try await SupabaseManager.shared.signUp(
            email: email, password: password, metadata: metadata
        )
        authPhase = .awaitingOTP(email: email)
    }

    func verifyOTP(email: String, token: String) async throws {
        _ = try await SupabaseManager.shared.verifyOTP(email: email, token: token)
        authPhase = .signedIn
        await loadOwnProfile()
    }

    func resendOTP(email: String) async throws {
        try await SupabaseManager.shared.resendSignupOTP(email: email)
    }

    func signOut() async {
        try? await SupabaseManager.shared.signOut()
        currentProfile = nil
        activeProgramme = nil
        currentSession = nil
        authPhase = .signedOut
    }

    // MARK: - Profile

    func loadOwnProfile() async {
        do {
            currentProfile = try await SupabaseManager.shared.fetchOwnProfile()
            if let lang = currentProfile?.language, !lang.isEmpty {
                language = lang
            }
        } catch {
            print("[AppState] loadOwnProfile failed:", error)
        }
    }

    // MARK: - Toast

    func showToast(_ msg: String) {
        toast = msg
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if toast == msg { toast = nil }
        }
    }
}
