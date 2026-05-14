import Foundation

// MARK: - Profile

/// Mirrors the `profiles` table in Supabase.
struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String?
    var username: String?
    var email: String?
    var language: String?           // "en" | "ar"
    var trackedLifts: [String]?     // up to 4
    var trackedMuscles: [String]?   // 6 muscle groups
    var avatarURL: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case username
        case email
        case language
        case trackedLifts   = "tracked_lifts"
        case trackedMuscles = "tracked_muscles"
        case avatarURL      = "avatar_url"
        case createdAt      = "created_at"
    }
}

// MARK: - Programme

/// Programme metadata row in `programmes` table.
struct Programme: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var name: String
    var active: Bool
    var data: ProgrammeData?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case name
        case active
        case data
        case createdAt = "created_at"
    }
}

/// Programme content (stored as JSONB in `programmes.data`).
struct ProgrammeData: Codable, Hashable {
    var name: String
    var totalWeeks: Int
    var weeks: [ProgrammeWeek]
}

struct ProgrammeWeek: Codable, Hashable {
    var weekNumber: Int
    var sessions: [ProgrammeSession]
}

struct ProgrammeSession: Codable, Hashable, Identifiable {
    var id: UUID { UUID() }
    var day: String           // "mon" | "tue" | ...
    var name: String
    var exercises: [Exercise]
    /// Optional sub-header (e.g. "Power" / "Hypertrophy" / "Recovery").
    /// Mirrors the JS `session.focus` field. Edited via ProgrammePage.
    var focus: String?
    /// Optional block label this session falls under (e.g. "Block 1" or
    /// "Week 1-4 — Volume"). Mirrors the JS `session.block` field.
    var block: String?
}

struct Exercise: Codable, Hashable, Identifiable {
    var id: UUID { UUID() }
    var name: String
    var tag: String?          // "compound" | "isolation" | "accessory" | ...
    var sets: Int
    var reps: String          // e.g. "8-10"
    var weight: Double?       // working weight in kg
    var rpe: String?          // e.g. "7-8"
    var notes: String?
}

// MARK: - Session (workout instance)

struct WorkoutSession: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let programmeId: UUID?
    var name: String
    var date: Date
    var weekNumber: Int?
    var block: Int?
    var completed: Bool
    var data: WorkoutSessionData?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case programmeId = "programme_id"
        case name
        case date
        case weekNumber  = "week_number"
        case block
        case completed
        case data
        case createdAt   = "created_at"
    }
}

/// Snapshot of exercises/sets attached to a session (JSONB).
struct WorkoutSessionData: Codable, Hashable {
    var exercises: [Exercise]
}

// MARK: - Set

/// One performed set in the `sets` table.
struct PerformedSet: Codable, Identifiable, Hashable {
    let id: UUID
    let sessionId: UUID
    let userId: UUID
    var exerciseName: String
    var setNumber: Int
    var reps: Int?
    var weight: Double?
    var rpe: Double?
    var completed: Bool
    var failed: Bool
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId    = "session_id"
        case userId       = "user_id"
        case exerciseName = "exercise_name"
        case setNumber    = "set_number"
        case reps
        case weight
        case rpe
        case completed
        case failed
        case createdAt    = "created_at"
    }
}

// MARK: - Working weight

struct WorkingWeight: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var exerciseName: String
    var weight: Double
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case exerciseName = "exercise_name"
        case weight
        case updatedAt    = "updated_at"
    }
}

// MARK: - Friendship

struct Friendship: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let friendId: UUID
    var status: String         // "pending" | "accepted" | "blocked"
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case friendId  = "friend_id"
        case status
        case createdAt = "created_at"
    }
}

// MARK: - Trophy

struct Trophy: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var trophyKey: String      // "DAY_ONE" | "CENTURY" | etc.
    var trophyName: String
    var earnedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case trophyKey   = "trophy_key"
        case trophyName  = "trophy_name"
        case earnedAt    = "earned_at"
    }
}

// MARK: - Activity feed

struct ActivityFeedItem: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var type: String           // "session_completed" | "trophy_earned" | "pr" | ...
    var data: [String: AnyCodable]?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case type
        case data
        case createdAt = "created_at"
    }
}

// MARK: - AnyCodable (for free-form JSON columns)

/// Type-erased Codable wrapper so we can decode JSONB columns with mixed
/// value types without defining a struct for every shape.
struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self.value = NSNull()
        } else if let b = try? c.decode(Bool.self) {
            self.value = b
        } else if let i = try? c.decode(Int.self) {
            self.value = i
        } else if let d = try? c.decode(Double.self) {
            self.value = d
        } else if let s = try? c.decode(String.self) {
            self.value = s
        } else if let arr = try? c.decode([AnyCodable].self) {
            self.value = arr.map(\.value)
        } else if let dict = try? c.decode([String: AnyCodable].self) {
            self.value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "AnyCodable: unsupported value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull:                  try c.encodeNil()
        case let b as Bool:              try c.encode(b)
        case let i as Int:               try c.encode(i)
        case let d as Double:            try c.encode(d)
        case let s as String:            try c.encode(s)
        case let arr as [Any]:           try c.encode(arr.map(AnyCodable.init))
        case let dict as [String: Any]:  try c.encode(dict.mapValues(AnyCodable.init))
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: c.codingPath,
                                      debugDescription: "AnyCodable: cannot encode \(value)"))
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Encode-based equality — good enough for use in Hashable contexts.
        let enc = JSONEncoder()
        return (try? enc.encode(lhs)) == (try? enc.encode(rhs))
    }

    func hash(into hasher: inout Hasher) {
        if let data = try? JSONEncoder().encode(self) {
            hasher.combine(data)
        }
    }
}
