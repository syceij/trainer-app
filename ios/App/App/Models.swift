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

    init(id: UUID, name: String?, username: String?, email: String?,
         language: String?, trackedLifts: [String]?, trackedMuscles: [String]?,
         avatarURL: String?, createdAt: Date?) {
        self.id = id
        self.name = name
        self.username = username
        self.email = email
        self.language = language
        self.trackedLifts = trackedLifts
        self.trackedMuscles = trackedMuscles
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id             = try c.decode(UUID.self, forKey: .id)
        // All other fields use `try?` so a single malformed column doesn't
        // throw the whole decode — the user still gets a partial Profile.
        self.name           = try? c.decode(String.self, forKey: .name)
        self.username       = try? c.decode(String.self, forKey: .username)
        self.email          = try? c.decode(String.self, forKey: .email)
        self.language       = try? c.decode(String.self, forKey: .language)
        self.trackedLifts   = try? c.decode([String].self, forKey: .trackedLifts)
        self.trackedMuscles = try? c.decode([String].self, forKey: .trackedMuscles)
        self.avatarURL      = try? c.decode(String.self, forKey: .avatarURL)
        self.createdAt      = LenientDate.optional(c, .createdAt)
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

    init(id: UUID, userId: UUID, name: String, active: Bool,
         data: ProgrammeData?, createdAt: Date?) {
        self.id = id; self.userId = userId; self.name = name
        self.active = active; self.data = data; self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id        = try c.decode(UUID.self,     forKey: .id)
        self.userId    = try c.decode(UUID.self,     forKey: .userId)
        self.name      = try c.decode(String.self,   forKey: .name)
        self.active    = try c.decodeIfPresent(Bool.self, forKey: .active) ?? false
        self.data      = try c.decodeIfPresent(ProgrammeData.self, forKey: .data)
        self.createdAt = LenientDate.optional(c, .createdAt)
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

    init(id: UUID, userId: UUID, programmeId: UUID?, name: String,
         date: Date, weekNumber: Int?, block: Int?, completed: Bool,
         data: WorkoutSessionData?, createdAt: Date?) {
        self.id = id; self.userId = userId; self.programmeId = programmeId
        self.name = name; self.date = date; self.weekNumber = weekNumber
        self.block = block; self.completed = completed; self.data = data
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id          = try c.decode(UUID.self,   forKey: .id)
        self.userId      = try c.decode(UUID.self,   forKey: .userId)
        self.programmeId = try c.decodeIfPresent(UUID.self, forKey: .programmeId)
        self.name        = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.date        = try LenientDate.required(c, .date)
        self.weekNumber  = try c.decodeIfPresent(Int.self,  forKey: .weekNumber)
        self.block       = try c.decodeIfPresent(Int.self,  forKey: .block)
        self.completed   = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        self.data        = try c.decodeIfPresent(WorkoutSessionData.self, forKey: .data)
        self.createdAt   = LenientDate.optional(c, .createdAt)
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

    init(id: UUID, sessionId: UUID, userId: UUID, exerciseName: String,
         setNumber: Int, reps: Int?, weight: Double?, rpe: Double?,
         completed: Bool, failed: Bool, createdAt: Date?) {
        self.id = id; self.sessionId = sessionId; self.userId = userId
        self.exerciseName = exerciseName; self.setNumber = setNumber
        self.reps = reps; self.weight = weight; self.rpe = rpe
        self.completed = completed; self.failed = failed
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id           = try c.decode(UUID.self,   forKey: .id)
        self.sessionId    = try c.decode(UUID.self,   forKey: .sessionId)
        self.userId       = try c.decode(UUID.self,   forKey: .userId)
        self.exerciseName = try c.decodeIfPresent(String.self, forKey: .exerciseName) ?? ""
        self.setNumber    = try c.decodeIfPresent(Int.self,    forKey: .setNumber) ?? 0
        self.reps         = try c.decodeIfPresent(Int.self,    forKey: .reps)
        self.weight       = try c.decodeIfPresent(Double.self, forKey: .weight)
        self.rpe          = try c.decodeIfPresent(Double.self, forKey: .rpe)
        self.completed    = try c.decodeIfPresent(Bool.self,   forKey: .completed) ?? false
        self.failed       = try c.decodeIfPresent(Bool.self,   forKey: .failed)    ?? false
        self.createdAt    = LenientDate.optional(c, .createdAt)
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

    init(id: UUID, userId: UUID, exerciseName: String, weight: Double, updatedAt: Date?) {
        self.id = id; self.userId = userId; self.exerciseName = exerciseName
        self.weight = weight; self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id           = try c.decode(UUID.self,   forKey: .id)
        self.userId       = try c.decode(UUID.self,   forKey: .userId)
        self.exerciseName = try c.decode(String.self, forKey: .exerciseName)
        self.weight       = try c.decode(Double.self, forKey: .weight)
        self.updatedAt    = LenientDate.optional(c, .updatedAt)
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

    init(id: UUID, userId: UUID, friendId: UUID, status: String, createdAt: Date?) {
        self.id = id; self.userId = userId; self.friendId = friendId
        self.status = status; self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id        = try c.decode(UUID.self,   forKey: .id)
        self.userId    = try c.decode(UUID.self,   forKey: .userId)
        self.friendId  = try c.decode(UUID.self,   forKey: .friendId)
        self.status    = try c.decode(String.self, forKey: .status)
        self.createdAt = LenientDate.optional(c, .createdAt)
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

    init(id: UUID, userId: UUID, trophyKey: String, trophyName: String, earnedAt: Date?) {
        self.id = id; self.userId = userId; self.trophyKey = trophyKey
        self.trophyName = trophyName; self.earnedAt = earnedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id         = try c.decode(UUID.self,   forKey: .id)
        self.userId     = try c.decode(UUID.self,   forKey: .userId)
        self.trophyKey  = try c.decode(String.self, forKey: .trophyKey)
        self.trophyName = try c.decode(String.self, forKey: .trophyName)
        self.earnedAt   = LenientDate.optional(c, .earnedAt)
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

    init(id: UUID, userId: UUID, type: String,
         data: [String: AnyCodable]?, createdAt: Date?) {
        self.id = id; self.userId = userId; self.type = type
        self.data = data; self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id        = try c.decode(UUID.self,   forKey: .id)
        self.userId    = try c.decode(UUID.self,   forKey: .userId)
        self.type      = try c.decode(String.self, forKey: .type)
        self.data      = try c.decodeIfPresent([String: AnyCodable].self, forKey: .data)
        self.createdAt = LenientDate.optional(c, .createdAt)
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
