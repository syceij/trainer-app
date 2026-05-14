import Foundation
import Supabase

/// Singleton wrapper around the Supabase Swift client.
///
/// Exposes the raw `client` plus a small set of typed convenience methods
/// for auth + database. Views talk to this via async/await.
final class SupabaseManager {

    // MARK: - Singleton

    static let shared = SupabaseManager()

    // MARK: - Configuration

    /// Project URL.
    private static let supabaseURL = URL(
        string: "https://xfrzdyloocdfipfzmwge.supabase.co"
    )!

    /// Anon (publishable) key — safe to ship in the app.
    private static let supabaseAnonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhmcnpkeWxvb2NkZmlwZnptd2dlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1MTcyMzgsImV4cCI6MjA5MzA5MzIzOH0.fWuwS-QTXszYhFnUqH3GH9p_OhwTwY_0ZBdmMfQ8SAw"

    // MARK: - Client

    /// Raw Supabase client — use this for advanced queries.
    let client: SupabaseClient

    private init() {
        self.client = SupabaseClient(
            supabaseURL: Self.supabaseURL,
            supabaseKey: Self.supabaseAnonKey
        )
    }

    // MARK: - Auth helpers

    /// Currently signed-in user, or nil.
    var currentUser: User? {
        client.auth.currentUser
    }

    /// Sign in with email + password.
    func signIn(email: String, password: String) async throws -> Session {
        try await client.auth.signIn(email: email, password: password)
    }

    /// Look up the email stored on a profile row by username. Returns nil if
    /// no row matches. Used so users can sign in with either email or username.
    func emailForUsername(_ username: String) async throws -> String? {
        struct Row: Decodable { let email: String? }
        let rows: [Row] = try await client
            .from("profiles")
            .select("email")
            .eq("username", value: username.lowercased())
            .limit(1)
            .execute()
            .value
        return rows.first?.email
    }

    /// Check whether a username is already taken. Used for real-time
    /// availability hint on the signup screen.
    func isUsernameTaken(_ username: String) async throws -> Bool {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from("profiles")
            .select("id")
            .eq("username", value: username.lowercased())
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    /// Sign up with email + password. Optionally pass extra metadata
    /// (name, username) that gets stored on the auth user.
    func signUp(
        email: String,
        password: String,
        metadata: [String: AnyJSON] = [:]
    ) async throws -> AuthResponse {
        try await client.auth.signUp(
            email: email,
            password: password,
            data: metadata
        )
    }

    /// Verify a 6-digit OTP code emailed to the user during signup.
    func verifyOTP(email: String, token: String) async throws -> AuthResponse {
        try await client.auth.verifyOTP(
            email: email,
            token: token,
            type: .signup
        )
    }

    /// Resend the signup OTP.
    func resendSignupOTP(email: String) async throws {
        try await client.auth.resend(email: email, type: .signup)
    }

    /// Sign out the current user.
    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Profile helpers

    /// Fetch the current user's profile row. Returns nil if no row exists.
    func fetchOwnProfile() async throws -> Profile? {
        guard let uid = currentUser?.id else { return nil }
        let rows: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: uid)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Upsert (create or update) the current user's profile.
    func upsertOwnProfile(_ profile: Profile) async throws {
        _ = try await client
            .from("profiles")
            .upsert(profile)
            .execute()
    }

    // MARK: - Programme helpers

    /// Fetch the user's currently active programme (one row, `active = true`).
    /// Returns nil if no row matches.
    func fetchActiveProgramme() async throws -> Programme? {
        guard let uid = currentUser?.id else { return nil }
        let rows: [Programme] = try await client
            .from("programmes")
            .select()
            .eq("user_id", value: uid)
            .eq("active", value: true)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Upsert a programme row. Caller is responsible for setting `userId`
    /// and `active` correctly. To switch the active programme, call
    /// `markProgrammeActive(_:)` afterwards which clears `active` on all
    /// other rows.
    func upsertProgramme(_ programme: Programme) async throws {
        _ = try await client
            .from("programmes")
            .upsert(programme)
            .execute()
    }

    /// Make exactly one programme row active for the current user, clearing
    /// `active` on all others. Two-step update so the user always has at
    /// most one active programme.
    func markProgrammeActive(_ programmeId: UUID) async throws {
        guard let uid = currentUser?.id else { return }
        // 1) Deactivate all of the user's other programmes.
        _ = try await client
            .from("programmes")
            .update(["active": false])
            .eq("user_id", value: uid)
            .neq("id", value: programmeId)
            .execute()
        // 2) Activate this one.
        _ = try await client
            .from("programmes")
            .update(["active": true])
            .eq("id", value: programmeId)
            .execute()
    }

    // MARK: - Workout history helpers

    /// Fetch the user's most recent N completed/in-progress sessions,
    /// ordered most-recent first.
    func fetchHistory(limit: Int = 200) async throws -> [WorkoutSession] {
        guard let uid = currentUser?.id else { return [] }
        let rows: [WorkoutSession] = try await client
            .from("workout_sessions")
            .select()
            .eq("user_id", value: uid)
            .order("date", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows
    }

    /// Insert (or upsert by id) a workout session row.
    func saveWorkoutSession(_ session: WorkoutSession) async throws {
        _ = try await client
            .from("workout_sessions")
            .upsert(session)
            .execute()
    }

    /// Bulk-insert performed sets. Caller passes in pre-built `PerformedSet`
    /// values with valid `sessionId` and `userId`.
    func savePerformedSets(_ sets: [PerformedSet]) async throws {
        guard !sets.isEmpty else { return }
        _ = try await client
            .from("sets")
            .insert(sets)
            .execute()
    }

    /// Fetch all performed sets for the current user — used by Progress tab
    /// lift cards and the muscle-page detail view. Optionally limit by
    /// exercise name for the single-lift drill-down.
    func fetchAllSets(exerciseName: String? = nil,
                      limit: Int = 1000) async throws -> [PerformedSet] {
        guard let uid = currentUser?.id else { return [] }
        var query = client
            .from("sets")
            .select()
            .eq("user_id", value: uid)
        if let name = exerciseName {
            query = query.eq("exercise_name", value: name)
        }
        let rows: [PerformedSet] = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows
    }
}
