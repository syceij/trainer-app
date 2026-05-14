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
}
