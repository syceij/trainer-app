import Foundation

/// Port of src/lib/programme.js — generates a starter programme from an
/// onboarding profile + starting weights. Kept structurally identical to the
/// JS so the two stay in lockstep.
///
/// Public surface:
///   - `ProgrammeBuilder.exercises` — the 50+ exercise library
///   - `ProgrammeBuilder.buildProgramme(profile:weights:)` — main entry point
///   - `ProgrammeBuilder.accessoryWeight(name:weights:)` — used by manual builder
enum ProgrammeBuilder {

    // MARK: - Exercise library

    /// One row from the canonical exercise library. Mirrors EXERCISES in
    /// programme.js — every name here is the authoritative spelling.
    struct LibraryExercise {
        let key: String           // stable identifier
        let name: String          // canonical display name
        let muscle: String        // primary muscle group
        let equipment: String     // barbell | dumbbell | cable | machine | bodyweight
        let isMain: Bool
        let bodyweight: Bool

        init(_ key: String, _ name: String, _ muscle: String, _ equipment: String,
             isMain: Bool = false, bodyweight: Bool = false) {
            self.key = key; self.name = name; self.muscle = muscle
            self.equipment = equipment; self.isMain = isMain; self.bodyweight = bodyweight
        }
    }

    /// The 50+ canonical exercises. Keep parity with src/lib/programme.js.
    static let exercises: [LibraryExercise] = [
        // Chest - barbell
        .init("bench_press",         "Barbell Bench Press",      "chest",      "barbell", isMain: true),
        .init("incline_bench",       "Incline Barbell Press",    "chest",      "barbell"),
        .init("close_grip_bench",    "Close-Grip Bench Press",   "triceps",    "barbell"),
        // Chest - dumbbell
        .init("db_press",            "Dumbbell Bench Press",     "chest",      "dumbbell"),
        .init("incline_db_press",    "Incline DB Press",         "chest",      "dumbbell"),
        .init("db_fly",              "Dumbbell Fly",             "chest",      "dumbbell"),
        // Chest - cable/machine
        .init("cable_fly",           "Cable Fly",                "chest",      "cable"),
        .init("chest_press_machine", "Chest Press Machine",      "chest",      "machine"),
        .init("pec_deck",            "Pec Deck",                 "chest",      "machine"),
        // Chest - bodyweight
        .init("pushup",              "Push-Up",                  "chest",      "bodyweight", bodyweight: true),
        .init("dip",                 "Chest Dip",                "chest",      "bodyweight", bodyweight: true),

        // Back - barbell
        .init("deadlift",            "Deadlift",                 "back",       "barbell", isMain: true),
        .init("barbell_row",         "Barbell Row",              "back",       "barbell", isMain: true),
        .init("rdl",                 "Romanian Deadlift",        "hamstrings", "barbell"),
        // Back - dumbbell
        .init("db_row",              "Dumbbell Row",             "back",       "dumbbell"),
        // Back - cable/machine
        .init("lat_pulldown",        "Lat Pulldown",             "back",       "machine"),
        .init("cable_row",           "Cable Row",                "back",       "cable"),
        .init("face_pull",           "Face Pull",                "back",       "cable"),
        .init("machine_row",         "Machine Row",              "back",       "machine"),
        // Back - bodyweight
        .init("pullup",              "Pull-Up",                  "back",       "bodyweight", bodyweight: true),
        .init("chinup",              "Chin-Up",                  "back",       "bodyweight", bodyweight: true),
        .init("inverted_row",        "Inverted Row",             "back",       "bodyweight", bodyweight: true),

        // Shoulders
        .init("ohp",                 "Overhead Press",           "shoulders",  "barbell",  isMain: true),
        .init("db_ohp",              "DB Shoulder Press",        "shoulders",  "dumbbell"),
        .init("lateral_raise",       "Lateral Raise",            "shoulders",  "dumbbell"),
        .init("front_raise",         "Front Raise",              "shoulders",  "dumbbell"),
        .init("cable_lateral",       "Cable Lateral Raise",      "shoulders",  "cable"),
        .init("machine_shoulder",    "Machine Shoulder Press",   "shoulders",  "machine"),
        .init("rear_delt_fly",       "Rear Delt Fly",            "shoulders",  "dumbbell"),

        // Legs - barbell
        .init("squat",               "Back Squat",               "quads",      "barbell", isMain: true),
        .init("front_squat",         "Front Squat",              "quads",      "barbell"),
        .init("sumo_deadlift",       "Sumo Deadlift",            "hamstrings", "barbell"),
        // Legs - dumbbell
        .init("db_lunge",            "DB Lunge",                 "quads",      "dumbbell"),
        .init("db_rdl",              "DB Romanian Deadlift",     "hamstrings", "dumbbell"),
        // Legs - machine
        .init("leg_press",           "Leg Press",                "quads",      "machine"),
        .init("leg_curl",            "Leg Curl",                 "hamstrings", "machine"),
        .init("leg_ext",             "Leg Extension",            "quads",      "machine"),
        .init("hip_thrust",          "Hip Thrust",               "glutes",     "barbell"),
        .init("glute_bridge",        "Glute Bridge",             "glutes",     "bodyweight", bodyweight: true),
        .init("calf_raise",          "Standing Calf Raise",      "calves",     "machine"),
        .init("seated_calf",         "Seated Calf Raise",        "calves",     "machine"),
        // Legs - bodyweight
        .init("bodyweight_squat",    "Bodyweight Squat",         "quads",      "bodyweight", bodyweight: true),
        .init("jump_squat",          "Jump Squat",               "quads",      "bodyweight", bodyweight: true),

        // Arms
        .init("barbell_curl",        "Barbell Curl",             "biceps",     "barbell"),
        .init("db_curl",             "DB Curl",                  "biceps",     "dumbbell"),
        .init("hammer_curl",         "Hammer Curl",              "biceps",     "dumbbell"),
        .init("cable_curl",          "Cable Curl",               "biceps",     "cable"),
        .init("preacher_curl",       "Preacher Curl",            "biceps",     "machine"),
        .init("tricep_pushdown",     "Tricep Pushdown",          "triceps",    "cable"),
        .init("overhead_tricep",     "Overhead Tricep Ext",      "triceps",    "dumbbell"),
        .init("skull_crusher",       "Skull Crusher",            "triceps",    "barbell"),
        .init("bench_dip",           "Bench Dip",                "triceps",    "bodyweight", bodyweight: true),

        // Core
        .init("plank",               "Plank",                    "core",       "bodyweight", bodyweight: true),
        .init("ab_wheel",            "Ab Wheel",                 "core",       "bodyweight", bodyweight: true),
        .init("cable_crunch",        "Cable Crunch",             "core",       "cable"),
        .init("hanging_leg_raise",   "Hanging Leg Raise",        "core",       "bodyweight", bodyweight: true),
    ]

    // MARK: - Equipment filter

    /// Returns the equipment-availability predicate matching the React
    /// `equipmentFilter` map.
    private static func equipmentPredicate(_ equipment: String) -> (LibraryExercise) -> Bool {
        switch equipment {
        case "home_gym":   return { $0.equipment != "machine" && $0.equipment != "cable" }
        case "dumbbells":  return { $0.equipment == "dumbbell" || $0.equipment == "bodyweight" }
        case "bodyweight": return { $0.equipment == "bodyweight" }
        default:           return { _ in true }   // full_gym + fallback
        }
    }

    // MARK: - accessoryWeight

    /// Accessory-weight calculator — mirrors `accessoryWeight(key, mains)`.
    /// Returns `nil` when the exercise is bodyweight (label "BW" in React).
    static func accessoryWeight(key: String,
                                mains: [String: Double]) -> Double? {
        guard let ex = exercises.first(where: { $0.key == key }) else { return 20 }
        let ratios: [String: Double] = [
            "chest": 0.4, "back": 0.45, "shoulders": 0.25, "biceps": 0.2,
            "triceps": 0.25, "quads": 0.55, "hamstrings": 0.5, "glutes": 0.45,
            "calves": 0.4, "core": 0,
        ]
        let mainMap: [String: Double] = [
            "chest":      mains["bench"]    ?? 0,
            "back":       mains["row"]      ?? 0,
            "shoulders":  mains["ohp"]      ?? 0,
            "quads":      mains["squat"]    ?? 0,
            "hamstrings": mains["deadlift"] ?? 0,
            "glutes":     mains["squat"]    ?? 0,
            "biceps":     mains["row"]      ?? 0,
            "triceps":    mains["bench"]    ?? 0,
            "calves":     mains["squat"]    ?? 0,
            "core":       0,
        ]
        let base  = mainMap[ex.muscle] ?? 20
        let ratio = ratios[ex.muscle]  ?? 0.3
        if ex.bodyweight { return nil }
        if ex.equipment == "dumbbell" {
            return (base * ratio / 2.0).rounded() * 2
        }
        let r = (base * ratio / 5.0).rounded() * 5
        return r > 0 ? r : 20
    }

    // MARK: - Helpers

    private static func exerciseCount(sessionLength: Int) -> Int {
        if sessionLength == 45 { return 5 }
        if sessionLength == 90 { return 8 }
        return 6
    }

    private struct GoalParams {
        let sets: Int
        let reps: String
        let rpe: String
    }

    private static func goalParams(_ goal: String) -> GoalParams {
        switch goal {
        case "muscle":   return .init(sets: 4, reps: "8-10",  rpe: "7-8")
        case "stronger": return .init(sets: 5, reps: "4-6",   rpe: "8-9")
        case "fat":      return .init(sets: 4, reps: "10-12", rpe: "8-9")
        default:         return .init(sets: 4, reps: "6-8",   rpe: "8-9")
        }
    }

    private static func filterAvailable(_ list: [LibraryExercise],
                                        equipment: String,
                                        dislikes: [String],
                                        avoid: String) -> [LibraryExercise] {
        let predicate = equipmentPredicate(equipment)
        let avoidLower = avoid.lowercased()
        return list.filter { ex in
            if !predicate(ex) { return false }
            let nameLower = ex.name.lowercased()
            for d in dislikes where nameLower.contains(d.lowercased()) { return false }
            if !avoidLower.isEmpty {
                let words = nameLower.split(separator: " ")
                if words.contains(where: { avoidLower.contains($0) }) { return false }
            }
            return true
        }
    }

    private static func pickExercises(muscles: [String],
                                      available: [LibraryExercise],
                                      count: Int,
                                      weakPoints: [String],
                                      favourites: [String]) -> [LibraryExercise] {
        let sorted = available.sorted { a, b in
            let aFav  = favourites.contains(where: { a.name.lowercased().contains($0.lowercased()) }) ? -1 : 0
            let bFav  = favourites.contains(where: { b.name.lowercased().contains($0.lowercased()) }) ? -1 : 0
            let aWeak = weakPoints.contains(where: { a.muscle.lowercased().contains($0.lowercased()) }) ? -1 : 0
            let bWeak = weakPoints.contains(where: { b.muscle.lowercased().contains($0.lowercased()) }) ? -1 : 0
            return (aFav + aWeak) < (bFav + bWeak)
        }

        var result: [LibraryExercise] = []
        var used = Set<String>()
        // Prefer one pick per target muscle first
        for muscle in muscles {
            if result.count >= count { break }
            if let ex = sorted.first(where: { $0.muscle == muscle && !used.contains($0.key) }) {
                result.append(ex)
                used.insert(ex.key)
            }
        }
        // Fill remaining slots
        for ex in sorted {
            if result.count >= count { break }
            if !used.contains(ex.key) {
                result.append(ex)
                used.insert(ex.key)
            }
        }
        return Array(result.prefix(count))
    }

    private static func makeExercise(_ ex: LibraryExercise,
                                     params: GoalParams,
                                     weights: [String: Double]) -> Exercise {
        let w = accessoryWeight(key: ex.key, mains: weights)
        return Exercise(
            name:   ex.name,
            tag:    ex.isMain ? "compound" : "accessory",
            sets:   params.sets,
            reps:   params.reps,
            weight: w,            // nil = bodyweight (renders as "BW" in UI)
            rpe:    params.rpe,
            notes:  nil
        )
    }

    private static func buildSession(name: String,
                                     day: String,
                                     muscles: [String],
                                     available: [LibraryExercise],
                                     weights: [String: Double],
                                     params: GoalParams,
                                     count: Int,
                                     weakPoints: [String],
                                     favourites: [String]) -> ProgrammeSession {
        let picks = pickExercises(muscles: muscles,
                                  available: available,
                                  count: count,
                                  weakPoints: weakPoints,
                                  favourites: favourites)
        return ProgrammeSession(
            day: day,
            name: name,
            exercises: picks.map { makeExercise($0, params: params, weights: weights) }
        )
    }

    // MARK: - Public entry

    /// One-week schedule. The React JS returns a flat array of sessions —
    /// here we attach Mon-first day strings so the iOS storage model (which
    /// requires `day`) stays consistent.
    private static let dayCycle = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    /// Build a one-week starter programme from an onboarding profile and
    /// starting weights. Mirrors `buildProgramme(profile, weights)` in
    /// src/lib/programme.js.
    static func buildProgramme(profile: OnboardingProfile,
                               weights: [String: Double]) -> ProgrammeData {
        let equipment    = profile.equipment.isEmpty ? "full_gym" : profile.equipment
        let dislikes: [String] = []   // not collected by current OnboardingProfile
        let favourites: [String] = [] // not collected by current OnboardingProfile
        let weakPoints   = Array(profile.weakPoints)
        let avoid        = profile.avoid
        let goal         = profile.goal.isEmpty ? "muscle" : profile.goal
        let experience   = profile.experience.isEmpty ? "beginner" : profile.experience
        let days         = profile.daysPerWeek

        let available = filterAvailable(exercises,
                                        equipment: equipment,
                                        dislikes: dislikes,
                                        avoid: avoid)
        let count     = exerciseCount(sessionLength: profile.sessionLength)
        let params    = goalParams(goal)
        let advancedParams = GoalParams(sets: params.sets + 1, reps: params.reps, rpe: params.rpe)

        var sessions: [ProgrammeSession] = []

        if experience == "beginner" {
            let templates: [(String, [String])] = [
                ("Full Body A", ["chest","back","quads","shoulders","biceps","triceps","core"]),
                ("Full Body B", ["back","chest","hamstrings","glutes","shoulders","biceps","core"]),
                ("Full Body C", ["quads","chest","back","shoulders","triceps","calves","core"]),
            ]
            for i in 0..<days {
                let t = templates[i % templates.count]
                sessions.append(buildSession(name: t.0, day: dayCycle[i % dayCycle.count],
                                             muscles: t.1, available: available,
                                             weights: weights, params: params,
                                             count: count, weakPoints: weakPoints,
                                             favourites: favourites))
            }
        } else if experience == "intermediate" && days <= 4 {
            // Upper / Lower split
            let templates: [(String, [String])] = [
                ("Upper A", ["chest","shoulders","back","biceps","triceps"]),
                ("Lower A", ["quads","hamstrings","glutes","calves","core"]),
                ("Upper B", ["back","chest","shoulders","triceps","biceps"]),
                ("Lower B", ["hamstrings","quads","glutes","calves","core"]),
            ]
            let take = min(max(days, 2), templates.count)
            for i in 0..<take {
                let t = templates[i]
                sessions.append(buildSession(name: t.0, day: dayCycle[i % dayCycle.count],
                                             muscles: t.1, available: available,
                                             weights: weights, params: params,
                                             count: count, weakPoints: weakPoints,
                                             favourites: favourites))
            }
        } else {
            // Push / Pull / Legs (with B-day variants past 3)
            let vol = experience == "advanced" ? advancedParams : params
            let templates: [(String, [String])] = [
                ("Push",   ["chest","shoulders","triceps"]),
                ("Pull",   ["back","biceps"]),
                ("Legs",   ["quads","hamstrings","glutes","calves","core"]),
                ("Push B", ["chest","shoulders","triceps"]),
                ("Pull B", ["back","biceps"]),
            ]
            let take = min(max(days, 3), templates.count)
            for i in 0..<take {
                let t = templates[i]
                sessions.append(buildSession(name: t.0, day: dayCycle[i % dayCycle.count],
                                             muscles: t.1, available: available,
                                             weights: weights, params: vol,
                                             count: count, weakPoints: weakPoints,
                                             favourites: favourites))
            }
        }

        let firstName = profile.name.split(separator: " ").first.map(String.init) ?? profile.name
        let progName  = firstName.isEmpty ? "Custom Programme" : "\(firstName)'s programme"
        return ProgrammeData(
            name: progName,
            totalWeeks: 1,
            weeks: [ProgrammeWeek(weekNumber: 1, sessions: sessions)]
        )
    }
}
