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
    /// Most recent N completed/in-progress sessions, ordered newest first.
    /// Populated by `loadHistory()` after sign-in and refreshed after each
    /// `finishWorkout(_:sets:)` call.
    @Published var workoutHistory: [WorkoutSession] = []

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
            await loadUserData()
        } catch {
            authPhase = .signedOut
        }
    }

    /// Fan out the three signed-in data loads in parallel. Called after
    /// every entry point into the signed-in state (restore, sign in, OTP).
    func loadUserData() async {
        async let profile: () = loadOwnProfile()
        async let programme: () = loadActiveProgramme()
        async let history: () = loadHistory()
        _ = await (profile, programme, history)
        // Once the active programme is loaded, pre-stage today's session
        // so the Train tab has something to show without an extra round-trip.
        if currentSession == nil {
            stageCurrentSessionFromActiveProgramme()
        }
    }

    // MARK: - Auth actions

    /// Sign in with either an email or a username. If the input doesn't look
    /// like an email, we resolve the email via the `profiles` table before
    /// calling Supabase auth — mirrors src/components/AuthScreen.jsx.
    func signIn(emailOrUsername: String, password: String) async throws {
        let trimmed = emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let looksLikeEmail: Bool = {
            guard let at = trimmed.firstIndex(of: "@") else { return false }
            let domain = trimmed[trimmed.index(after: at)...]
            return domain.contains(".")
        }()

        let resolvedEmail: String
        if looksLikeEmail {
            resolvedEmail = trimmed
        } else {
            guard let mapped = try await SupabaseManager.shared
                .emailForUsername(trimmed.lowercased()), !mapped.isEmpty
            else {
                throw AuthError.usernameNotFound
            }
            resolvedEmail = mapped
        }

        _ = try await SupabaseManager.shared.signIn(
            email: resolvedEmail, password: password
        )
        authPhase = .signedIn
        await loadUserData()
    }

    enum AuthError: LocalizedError {
        case usernameNotFound
        case invalidCredentials
        var errorDescription: String? {
            switch self {
            case .usernameNotFound:   return "No account found with that username."
            case .invalidCredentials: return "Incorrect email/username or password."
            }
        }
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
        await loadUserData()
    }

    func resendOTP(email: String) async throws {
        try await SupabaseManager.shared.resendSignupOTP(email: email)
    }

    /// Go back from the OTP screen to the signed-out (login/signup) flow.
    func cancelOTP() async {
        try? await SupabaseManager.shared.signOut()
        authPhase = .signedOut
    }

    func signOut() async {
        try? await SupabaseManager.shared.signOut()
        currentProfile = nil
        activeProgramme = nil
        currentSession = nil
        workoutHistory = []
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

    // MARK: - Programme

    /// Fetch the currently active programme row for this user. Silently
    /// leaves `activeProgramme` nil on error — Home/Programme screens render
    /// an empty state in that case.
    func loadActiveProgramme() async {
        do {
            activeProgramme = try await SupabaseManager.shared.fetchActiveProgramme()
        } catch {
            print("[AppState] loadActiveProgramme failed:", error)
        }
    }

    // MARK: - Workout history

    /// Pull the most recent sessions for this user (DESC by date).
    func loadHistory() async {
        do {
            workoutHistory = try await SupabaseManager.shared.fetchHistory()
        } catch {
            print("[AppState] loadHistory failed:", error)
        }
    }

    /// Persist a completed workout: writes the session row and any performed
    /// sets, then refreshes `workoutHistory` so Home stats update.
    func finishWorkout(_ session: WorkoutSession,
                       sets: [PerformedSet]) async throws {
        try await SupabaseManager.shared.saveWorkoutSession(session)
        try await SupabaseManager.shared.savePerformedSets(sets)
        currentSession = nil
        await loadHistory()
    }

    // MARK: - Programme creation entry points

    /// Generate a starter programme from the onboarding wizard answers and
    /// persist it as the active programme. Mirrors the React App.jsx
    /// `enterApp` callback that runs after the 7-step onboarding completes.
    func enterApp(profile: OnboardingProfile,
                  weights: [String: Double]) async {
        let data = ProgrammeBuilder.buildProgramme(profile: profile, weights: weights)
        await saveAndActivateProgramme(data: data)
    }

    /// Persist a validated imported programme and make it active. Mirrors
    /// the React `enterAppWithImport` callback used by ImportScreen.jsx.
    /// `raw` is the dict you get from `JSONSerialization.jsonObject(with:)`
    /// after `ImportHelpers.validateImported` returned no errors.
    func enterAppWithImport(_ raw: [String: Any]) async {
        guard let data = ImportHelpers.programmeData(fromImported: raw) else { return }
        await saveAndActivateProgramme(data: data)
    }

    /// Common tail: build a Programme row from generated/imported data,
    /// upsert it, mark it active, refresh in-memory state, and pre-stage
    /// today's session into `currentSession` so the Train tab is ready.
    private func saveAndActivateProgramme(data: ProgrammeData) async {
        guard let uid = SupabaseManager.shared.currentUser?.id else {
            print("[AppState] saveAndActivateProgramme: no user")
            return
        }
        let programme = Programme(
            id: UUID(),
            userId: uid,
            name: data.name,
            active: true,
            data: data,
            createdAt: nil
        )
        do {
            try await SupabaseManager.shared.upsertProgramme(programme)
            try await SupabaseManager.shared.markProgrammeActive(programme.id)
            await loadActiveProgramme()
            stageCurrentSessionFromActiveProgramme()
        } catch {
            print("[AppState] saveAndActivateProgramme failed:", error)
        }
    }

    /// Pick today's session (or the first one as fallback) from the active
    /// programme and stage it as `currentSession`, ready to be logged on
    /// the Train tab. No-op when there's no active programme yet.
    func stageCurrentSessionFromActiveProgramme() {
        guard let prog = activeProgramme,
              let week = prog.data?.weeks.first,
              !week.sessions.isEmpty,
              let uid = SupabaseManager.shared.currentUser?.id
        else { return }
        let dayKeys = ["sun","mon","tue","wed","thu","fri","sat"]
        let todayIdx = Calendar.current.component(.weekday, from: Date()) - 1
        let todayKey = dayKeys[max(0, min(6, todayIdx))]
        let picked = week.sessions.first(where: { $0.day == todayKey })
                  ?? week.sessions.first!
        currentSession = WorkoutSession(
            id: UUID(),
            userId: uid,
            programmeId: prog.id,
            name: picked.name,
            date: Date(),
            weekNumber: week.weekNumber,
            block: nil,
            completed: false,
            data: WorkoutSessionData(exercises: picked.exercises),
            createdAt: nil
        )
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
