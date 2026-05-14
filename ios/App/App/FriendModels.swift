import Foundation

// MARK: - Leaderboard data

/// Cached leaderboard score blob stored in `profiles.leaderboard_data` (jsonb).
/// Mirrors the shape `calculateLeaderboardScore` returns in src/lib/db.js.
struct LeaderboardData: Codable, Hashable {
    var score: Int
    var setsCompleted: Int
    var setsProgrammed: Int
    var improvementPct: Int
    var month: String        // "YYYY-MM"
    var updatedAt: String?   // ISO timestamp

    enum CodingKeys: String, CodingKey {
        case score, month, updatedAt = "updatedAt"
        case setsCompleted, setsProgrammed, improvementPct
    }

    // Some legacy rows may have snake_case — accept both.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        func int(_ keys: String...) -> Int {
            for k in keys {
                if let v = try? c.decode(Int.self, forKey: AnyKey(k)) { return v }
                if let d = try? c.decode(Double.self, forKey: AnyKey(k)) { return Int(d) }
            }
            return 0
        }
        func str(_ keys: String...) -> String? {
            for k in keys {
                if let v = try? c.decode(String.self, forKey: AnyKey(k)) { return v }
            }
            return nil
        }
        self.score          = int("score")
        self.setsCompleted  = int("setsCompleted", "sets_completed")
        self.setsProgrammed = int("setsProgrammed", "sets_programmed")
        self.improvementPct = int("improvementPct", "improvement_pct")
        self.month          = str("month") ?? ""
        self.updatedAt      = str("updatedAt", "updated_at")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encode(score,          forKey: AnyKey("score"))
        try c.encode(setsCompleted,  forKey: AnyKey("setsCompleted"))
        try c.encode(setsProgrammed, forKey: AnyKey("setsProgrammed"))
        try c.encode(improvementPct, forKey: AnyKey("improvementPct"))
        try c.encode(month,          forKey: AnyKey("month"))
        if let u = updatedAt { try c.encode(u, forKey: AnyKey("updatedAt")) }
    }

    /// Convenience init for AppState.calculateLeaderboardScore.
    init(score: Int, setsCompleted: Int, setsProgrammed: Int,
         improvementPct: Int, month: String, updatedAt: String?) {
        self.score          = score
        self.setsCompleted  = setsCompleted
        self.setsProgrammed = setsProgrammed
        self.improvementPct = improvementPct
        self.month          = month
        self.updatedAt      = updatedAt
    }

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ s: String) { self.stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
}

// MARK: - Friend list entry

/// Row returned by `loadFriends` in JS. Decoded straight from the `profiles`
/// select that powers the friends list.
struct FriendListEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String?
    var username: String?
    var avatarURL: String?
    var leaderboardData: LeaderboardData?

    enum CodingKeys: String, CodingKey {
        case id, name, username
        case avatarURL        = "avatar_url"
        case leaderboardData  = "leaderboard_data"
    }
}

// MARK: - Pending friend request

/// Friend request someone has sent TO the current user.
struct PendingRequest: Identifiable, Hashable {
    let friendshipId: UUID
    let userId: UUID
    var name: String
    var username: String?
    var avatarURL: String?
    var id: UUID { friendshipId }
}

// MARK: - User search result

struct UserSearchResult: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String?
    var username: String?
    var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, username
        case avatarURL = "avatar_url"
    }
}

// MARK: - Invite link

struct InviteLink: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let code: String
    var expiresAt: Date?
    var used: Bool
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, code, used
        case userId    = "user_id"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

// MARK: - Friend session (truncated view for FriendProfilePage)

/// A small projection of `workout_sessions` rows used by FriendProfilePage.
/// Pulled directly from the JSONB `data.exercises` field so we don't need
/// to read individual set rows for a friend.
struct FriendSession: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var name: String
    var exercises: [Exercise]
    var volume: Double {
        exercises.reduce(0) { acc, ex in
            if let w = ex.weight, w > 0 {
                return acc + w * Double(ex.sets)
            }
            return acc
        }
    }
}

// MARK: - Leaderboard rendering entry

/// Composed in CrewView to render the leaderboard rows. Wraps a friend (or
/// the current user) with their cached score blob + display fields.
struct LeaderboardEntry: Identifiable, Hashable {
    let id: UUID
    var rank: Int
    var name: String?
    var username: String?
    var avatarURL: String?
    var score: Int
    var setsCompleted: Int
    var improvementPct: Int
    var isMe: Bool
}

// MARK: - Custom exercise

/// User-created exercise. Persisted as a JSON array on `profiles.custom_exercises`.
/// Shape mirrors the React `CustomExercise` shape from src/components/ExercisePickerSheet.jsx.
struct CustomExercise: Codable, Identifiable, Hashable {
    var name: String
    var key: String           // generated from name (slug)
    var muscle: String        // primary muscle slug
    var category: String      // category label (matches picker categories)
    var isCustom: Bool        // always true; preserved so JSON roundtrips cleanly
    var equipment: String     // "custom" by default
    var createdAt: String?

    /// Use the slug-style key for SwiftUI identity.
    var id: String { key }

    init(name: String, muscle: String, category: String) {
        self.name = name
        self.key = "custom_" + name
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        self.muscle = muscle
        self.category = category
        self.isCustom = true
        self.equipment = "custom"
        self.createdAt = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Activity feed enriched row

/// `ActivityFeedItem` plus the attached profile data the React app joins
/// in JavaScript. Used directly by CrewView's activity list.
struct ActivityRow: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var type: String
    var createdAt: Date
    var data: [String: AnyCodable]?

    var profileName: String?
    var profileUsername: String?
    var avatarURL: String?

    /// Pull a string field out of the embedded `data` jsonb, if present.
    func stringField(_ key: String) -> String? {
        guard let v = data?[key]?.value as? String else { return nil }
        return v
    }
    func doubleField(_ key: String) -> Double? {
        if let d = data?[key]?.value as? Double { return d }
        if let i = data?[key]?.value as? Int    { return Double(i) }
        return nil
    }
}
