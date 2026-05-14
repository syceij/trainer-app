import Foundation

/// Port of src/lib/importHelpers.js. Provides:
///   - canonical exercise-name normalisation
///   - the full Claude prompt template (verbatim)
///   - the sample programme JSON
///   - schema validation
///   - a JSON-dict → ProgrammeData parser (so iOS can persist imported
///     programmes via SupabaseManager.upsertProgramme)
enum ImportHelpers {

    // MARK: - Canonical name lookup

    /// Lowercased canonical name → canonical name (for case-insensitive
    /// exact-match against the library).
    private static let canonByLower: [String: String] = {
        var m: [String: String] = [:]
        for ex in ProgrammeBuilder.exercises { m[ex.name.lowercased()] = ex.name }
        return m
    }()

    /// Lowercased raw name → canonical library name.
    /// Mirrors the ALIASES dictionary in importHelpers.js. Do not add
    /// ambiguous single-word aliases like "squat" or "row" here — they have
    /// to live at the bottom of this map where we know the short-key
    /// semantics from old workingWeights schemas.
    private static let aliases: [String: String] = [
        // Deadlift
        "conventional deadlift":      "Deadlift",
        "barbell deadlift":           "Deadlift",
        "conventional dl":            "Deadlift",
        "barbell dl":                 "Deadlift",
        "conv deadlift":              "Deadlift",
        // Overhead Press
        "ohp":                        "Overhead Press",
        "barbell ohp":                "Overhead Press",
        "military press":             "Overhead Press",
        "barbell overhead press":     "Overhead Press",
        "standing overhead press":    "Overhead Press",
        "standing ohp":               "Overhead Press",
        "press":                      "Overhead Press",
        // Lat Pulldown
        "lat pulldown (bar)":         "Lat Pulldown",
        "lat pulldown (cable)":       "Lat Pulldown",
        "lat pulldown bar":           "Lat Pulldown",
        "lat pull-down":              "Lat Pulldown",
        "lat pull down":              "Lat Pulldown",
        "wide grip lat pulldown":     "Lat Pulldown",
        "wide-grip lat pulldown":     "Lat Pulldown",
        "cable pulldown":             "Lat Pulldown",
        "pulldown":                   "Lat Pulldown",
        // Barbell Bench Press
        "bench press":                "Barbell Bench Press",
        "flat bench press":           "Barbell Bench Press",
        "flat bench":                 "Barbell Bench Press",
        "barbell bench":              "Barbell Bench Press",
        "bb bench press":             "Barbell Bench Press",
        // Back Squat
        "barbell squat":              "Back Squat",
        "bb squat":                   "Back Squat",
        "barbell back squat":         "Back Squat",
        // Barbell Row
        "bent over row":              "Barbell Row",
        "bent-over row":              "Barbell Row",
        "bent over barbell row":      "Barbell Row",
        "barbell bent over row":      "Barbell Row",
        "bb row":                     "Barbell Row",
        "bent-over barbell row":      "Barbell Row",
        "barbell bentover row":       "Barbell Row",
        // Romanian Deadlift
        "rdl":                        "Romanian Deadlift",
        "romanian dl":                "Romanian Deadlift",
        "barbell rdl":                "Romanian Deadlift",
        // Pull-Up / Chin-Up plurals
        "pull-ups":                   "Pull-Up",
        "pullups":                    "Pull-Up",
        "pull ups":                   "Pull-Up",
        "chin-ups":                   "Chin-Up",
        "chinups":                    "Chin-Up",
        "chin ups":                   "Chin-Up",
        // Push-Up plurals
        "push-ups":                   "Push-Up",
        "pushups":                    "Push-Up",
        "push ups":                   "Push-Up",
        // Close-Grip Bench Press
        "close grip bench press":     "Close-Grip Bench Press",
        "cgbp":                       "Close-Grip Bench Press",
        "close grip bench":           "Close-Grip Bench Press",
        // Incline Barbell Press
        "incline bench press":        "Incline Barbell Press",
        "incline barbell bench press":"Incline Barbell Press",
        "incline bp":                 "Incline Barbell Press",
        // Incline DB Press
        "incline dumbbell press":     "Incline DB Press",
        "dumbbell incline press":     "Incline DB Press",
        "incline db bench press":     "Incline DB Press",
        // Dumbbell Bench Press
        "dumbbell bench press":       "Dumbbell Bench Press",
        "db bench press":             "Dumbbell Bench Press",
        // Dumbbell Fly
        "dumbbell fly":               "Dumbbell Fly",
        "db fly":                     "Dumbbell Fly",
        "dumbbell flyes":             "Dumbbell Fly",
        "dumbbell flies":             "Dumbbell Fly",
        // Chest Dip
        "dips":                       "Chest Dip",
        "chest dips":                 "Chest Dip",
        "weighted dips":              "Chest Dip",
        // Pec Deck
        "pec fly machine":            "Pec Deck",
        "butterfly machine":          "Pec Deck",
        "pec fly":                    "Pec Deck",
        // DB Shoulder Press
        "dumbbell shoulder press":    "DB Shoulder Press",
        "dumbbell ohp":               "DB Shoulder Press",
        "db ohp":                     "DB Shoulder Press",
        "dumbbell overhead press":    "DB Shoulder Press",
        "seated db press":            "DB Shoulder Press",
        // Lateral Raise
        "lateral raises":             "Lateral Raise",
        "side raises":                "Lateral Raise",
        "db lateral raise":           "Lateral Raise",
        // Front Raise
        "front raises":               "Front Raise",
        "db front raise":             "Front Raise",
        // Cable Lateral Raise
        "cable lateral raises":       "Cable Lateral Raise",
        "cable side raise":           "Cable Lateral Raise",
        // Rear Delt Fly
        "rear delt flyes":            "Rear Delt Fly",
        "rear delt flys":             "Rear Delt Fly",
        "rear delt flies":            "Rear Delt Fly",
        "reverse fly":                "Rear Delt Fly",
        "reverse dumbbell fly":       "Rear Delt Fly",
        // Face Pull
        "face pulls":                 "Face Pull",
        "cable face pull":            "Face Pull",
        // Cable Row
        "seated cable row":           "Cable Row",
        "cable row (seated)":         "Cable Row",
        // Dumbbell Row
        "dumbbell row":               "Dumbbell Row",
        "db row":                     "Dumbbell Row",
        "single arm row":             "Dumbbell Row",
        "one arm dumbbell row":       "Dumbbell Row",
        // Inverted Row
        "inverted rows":              "Inverted Row",
        // Hip Thrust
        "barbell hip thrust":         "Hip Thrust",
        "bb hip thrust":              "Hip Thrust",
        "hip thrusts":                "Hip Thrust",
        // Standing / Seated Calf Raise
        "calf raise":                 "Standing Calf Raise",
        "calf raises":                "Standing Calf Raise",
        "standing calf raises":       "Standing Calf Raise",
        "seated calf raises":         "Seated Calf Raise",
        // Glute Bridge
        "glute bridges":              "Glute Bridge",
        // Sumo Deadlift
        "sumo deadlifts":             "Sumo Deadlift",
        "sumo dl":                    "Sumo Deadlift",
        // Front Squat
        "front squats":               "Front Squat",
        "barbell front squat":        "Front Squat",
        // DB Lunge
        "dumbbell lunge":             "DB Lunge",
        "db lunges":                  "DB Lunge",
        "dumbbell lunges":            "DB Lunge",
        // DB Romanian Deadlift
        "dumbbell rdl":               "DB Romanian Deadlift",
        "dumbbell romanian deadlift": "DB Romanian Deadlift",
        "db rdl":                     "DB Romanian Deadlift",
        // Leg Curl
        "leg curls":                  "Leg Curl",
        "hamstring curl":             "Leg Curl",
        "lying leg curl":             "Leg Curl",
        // Leg Extension
        "leg extensions":             "Leg Extension",
        "quad extension":             "Leg Extension",
        // Barbell Curl
        "barbell curls":              "Barbell Curl",
        "bb curl":                    "Barbell Curl",
        "ez bar curl":                "Barbell Curl",
        // DB Curl
        "dumbbell curl":              "DB Curl",
        "dumbbell curls":             "DB Curl",
        "db bicep curl":              "DB Curl",
        "dumbbell bicep curl":        "DB Curl",
        // Hammer Curl
        "hammer curls":               "Hammer Curl",
        "db hammer curl":             "Hammer Curl",
        // Cable Curl
        "cable curls":                "Cable Curl",
        // Preacher Curl
        "preacher curls":             "Preacher Curl",
        // Tricep Pushdown
        "triceps pushdown":           "Tricep Pushdown",
        "cable tricep pushdown":      "Tricep Pushdown",
        "tricep pulldown":            "Tricep Pushdown",
        "cable pushdown":             "Tricep Pushdown",
        // Overhead Tricep Ext
        "overhead tricep extension":  "Overhead Tricep Ext",
        "overhead triceps extension": "Overhead Tricep Ext",
        "db overhead tricep":         "Overhead Tricep Ext",
        "overhead extension":         "Overhead Tricep Ext",
        // Skull Crusher
        "skull crushers":             "Skull Crusher",
        "lying tricep extension":     "Skull Crusher",
        "ez bar skull crusher":       "Skull Crusher",
        // Bench Dip
        "bench dips":                 "Bench Dip",
        "tricep bench dip":           "Bench Dip",
        // Ab Wheel
        "ab wheel rollout":           "Ab Wheel",
        "ab rollout":                 "Ab Wheel",
        "wheel rollout":              "Ab Wheel",
        // Hanging Leg Raise
        "hanging leg raises":         "Hanging Leg Raise",
        "hanging knee raise":         "Hanging Leg Raise",
        "hanging knee raises":        "Hanging Leg Raise",
        // Cable Crunch
        "cable crunches":             "Cable Crunch",
        // Plank
        "planks":                     "Plank",
        // Bodyweight / Jump Squat
        "bodyweight squats":          "Bodyweight Squat",
        "bw squat":                   "Bodyweight Squat",
        "jump squats":                "Jump Squat",
        // Short-key aliases from old workingWeights schemas
        "bench":                      "Barbell Bench Press",
        "squat":                      "Back Squat",
        "row":                        "Barbell Row",
    ]

    /// Maps any exercise-name string to the canonical library name.
    /// Resolution order matches the JS:
    ///   1. case-insensitive exact match against the library
    ///   2. alias table lookup
    ///   3. unchanged (trimmed) raw value
    static func normalizeToCanonical(_ raw: String?) -> String? {
        guard let raw = raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let lower = trimmed.lowercased()
        if let canon = canonByLower[lower] { return canon }
        if let alias = aliases[lower]      { return alias }
        return trimmed
    }

    // MARK: - Claude prompt template (verbatim from importHelpers.js)

    static let promptTemplate = """
    Convert my training programme to this JSON format. Output ONLY the JSON, no explanation.

    Schema:
    {
      "name": "string",
      "description": "string (optional)",
      "totalWeeks": number,
      "profileSeed": { "name": string, "days": number, "goal": string, "experience": string },
      "workingWeights": { "Barbell Bench Press": kg, "Back Squat": kg, "Deadlift": kg, "Overhead Press": kg, "Barbell Row": kg },
      "weeks": [
        {
          "weekNumber": 1,
          "label": "string (optional)",
          "sessions": [
            {
              "day": "mon|tue|wed|thu|fri|sat|sun",
              "name": "string",
              "focus": "string (optional)",
              "exercises": [
                {
                  "name": "string — use exact name from canonical list below",
                  "tag": "compound|accessory (optional)",
                  "sets": number,
                  "reps": "string e.g. 8-10",
                  "weight": "number in kg OR BW OR light",
                  "rpe": "string e.g. 7-8 (optional)",
                  "notes": "string (optional)",
                  "bodyweight": true (optional)
                }
              ]
            },
            { "day": "tue", "isRest": true }
          ]
        }
      ]
    }

    Rules:
    - Lowercase day names, weights in kg, rest days as isRest: true.
    - For exercise names use EXACT spelling from this canonical list when the exercise matches.
      Any exercise not on this list may keep its original name.

    Canonical exercise names:
    Barbell Bench Press | Incline Barbell Press | Close-Grip Bench Press | Dumbbell Bench Press | Incline DB Press | Dumbbell Fly | Cable Fly | Chest Press Machine | Pec Deck | Push-Up | Chest Dip
    Deadlift | Barbell Row | Romanian Deadlift | Dumbbell Row | Lat Pulldown | Cable Row | Face Pull | Machine Row | Pull-Up | Chin-Up | Inverted Row
    Overhead Press | DB Shoulder Press | Lateral Raise | Front Raise | Cable Lateral Raise | Machine Shoulder Press | Rear Delt Fly
    Back Squat | Front Squat | Sumo Deadlift | DB Lunge | DB Romanian Deadlift | Leg Press | Leg Curl | Leg Extension | Hip Thrust | Glute Bridge | Standing Calf Raise | Seated Calf Raise | Bodyweight Squat | Jump Squat
    Barbell Curl | DB Curl | Hammer Curl | Cable Curl | Preacher Curl | Tricep Pushdown | Overhead Tricep Ext | Skull Crusher | Bench Dip
    Plank | Ab Wheel | Cable Crunch | Hanging Leg Raise

    My programme: [paste here]
    """

    // MARK: - Sample programme (verbatim from importHelpers.js)

    static let samplePrettyJSON: String = """
    {
      "name": "Sample — 5-day PPL",
      "totalWeeks": 1,
      "weeks": [
        {
          "weekNumber": 1,
          "label": "Week 1 — Calibration",
          "sessions": [
            {
              "day": "mon",
              "name": "Push A",
              "focus": "Chest focus",
              "exercises": [
                { "name": "Barbell Bench Press", "tag": "compound", "sets": 4, "reps": "8-10", "weight": 60, "rpe": "7-8", "notes": "Calibrate week 1" },
                { "name": "Incline DB Press", "tag": "compound", "sets": 3, "reps": "10-12", "weight": 22, "rpe": "7-8" },
                { "name": "Cable Fly", "tag": "accessory", "sets": 3, "reps": "12-15", "weight": "light", "rpe": "7", "notes": "Full stretch at bottom" },
                { "name": "Lateral Raise", "tag": "accessory", "sets": 4, "reps": "12-15", "weight": 5, "rpe": "7" },
                { "name": "Tricep Pushdown", "tag": "accessory", "sets": 3, "reps": "12-15", "weight": 25, "rpe": "7" }
              ]
            },
            { "day": "tue", "isRest": true },
            {
              "day": "wed",
              "name": "Pull A",
              "focus": "Back + Biceps",
              "exercises": [
                { "name": "Pull-Up", "tag": "compound", "sets": 4, "reps": "6-10", "weight": "BW", "rpe": "7-8", "bodyweight": true },
                { "name": "Barbell Row", "tag": "compound", "sets": 3, "reps": "8-10", "weight": 65, "rpe": "7-8" },
                { "name": "Lat Pulldown", "tag": "accessory", "sets": 3, "reps": "10-12", "weight": 50, "rpe": "7-8" },
                { "name": "Face Pull", "tag": "accessory", "sets": 3, "reps": "12-15", "weight": 20, "rpe": "7" },
                { "name": "DB Curl", "tag": "accessory", "sets": 3, "reps": "10-12", "weight": 12, "rpe": "7" }
              ]
            },
            {
              "day": "thu",
              "name": "Legs",
              "focus": "Squat + Hinge",
              "exercises": [
                { "name": "Back Squat", "tag": "compound", "sets": 4, "reps": "6-8", "weight": 100, "rpe": "7-8" },
                { "name": "Romanian Deadlift", "tag": "compound", "sets": 3, "reps": "8-10", "weight": 80, "rpe": "7-8" },
                { "name": "Leg Press", "tag": "accessory", "sets": 3, "reps": "12-15", "weight": 140, "rpe": "7-8" },
                { "name": "Leg Curl", "tag": "accessory", "sets": 3, "reps": "10-12", "weight": 35, "rpe": "7" },
                { "name": "Standing Calf Raise", "tag": "accessory", "sets": 4, "reps": "12-15", "weight": 60, "rpe": "7" }
              ]
            },
            {
              "day": "fri",
              "name": "Push B",
              "focus": "Shoulder focus",
              "exercises": [
                { "name": "Overhead Press", "tag": "compound", "sets": 4, "reps": "6-8", "weight": 45, "rpe": "7-8" },
                { "name": "Incline DB Press", "tag": "compound", "sets": 3, "reps": "10-12", "weight": 22, "rpe": "7-8" },
                { "name": "Lateral Raise", "tag": "accessory", "sets": 4, "reps": "12-15", "weight": 5, "rpe": "7" },
                { "name": "Cable Fly", "tag": "accessory", "sets": 3, "reps": "12-15", "weight": "light", "rpe": "7" },
                { "name": "Overhead Tricep Ext", "tag": "accessory", "sets": 3, "reps": "10-12", "weight": 12, "rpe": "7" }
              ]
            },
            {
              "day": "sat",
              "name": "Pull B",
              "focus": "Back + Arms",
              "exercises": [
                { "name": "Cable Row", "tag": "compound", "sets": 4, "reps": "8-10", "weight": 60, "rpe": "7-8" },
                { "name": "Lat Pulldown", "tag": "accessory", "sets": 3, "reps": "10-12", "weight": 50, "rpe": "7-8" },
                { "name": "Hammer Curl", "tag": "accessory", "sets": 4, "reps": "10-12", "weight": 12, "rpe": "7" },
                { "name": "Tricep Pushdown", "tag": "accessory", "sets": 4, "reps": "12-15", "weight": 25, "rpe": "7" },
                { "name": "Face Pull", "tag": "accessory", "sets": 3, "reps": "15-20", "weight": 18, "rpe": "7" }
              ]
            },
            { "day": "sun", "isRest": true }
          ]
        }
      ]
    }
    """

    // MARK: - Validation

    /// Returns an empty array when the dict matches the schema; otherwise
    /// returns one human-readable error per offence. Order matches the JS.
    static func validateImported(_ data: [String: Any]) -> [String] {
        var errors: [String] = []
        if (data["name"] as? String)?.isEmpty != false {
            errors.append("Missing or invalid \"name\" field")
        }
        guard let weeks = data["weeks"] as? [[String: Any]], !weeks.isEmpty else {
            errors.append("Missing or empty \"weeks\" array")
            return errors
        }
        for (wi, week) in weeks.enumerated() {
            if (week["weekNumber"] as? Int) == nil {
                errors.append("Week \(wi + 1): missing weekNumber")
            }
            guard let sessions = week["sessions"] as? [[String: Any]], !sessions.isEmpty else {
                errors.append("Week \(wi + 1): missing sessions array")
                continue
            }
            for (si, session) in sessions.enumerated() {
                if (session["isRest"] as? Bool) == true { continue }
                if (session["name"] as? String)?.isEmpty != false {
                    errors.append("Week \(wi + 1), session \(si + 1): missing name")
                }
                guard let exs = session["exercises"] as? [[String: Any]], !exs.isEmpty else {
                    errors.append("Week \(wi + 1), session \(si + 1): missing exercises")
                    continue
                }
                for (ei, ex) in exs.enumerated() {
                    if (ex["name"] as? String)?.isEmpty != false {
                        errors.append("Week \(wi + 1), session \(si + 1), ex \(ei + 1): missing name")
                    }
                    if (ex["sets"] as? Int) == nil && (ex["sets"] as? Double) == nil {
                        errors.append("Week \(wi + 1), session \(si + 1), ex \(ei + 1): sets must be a number")
                    }
                    if ex["reps"] == nil {
                        errors.append("Week \(wi + 1), session \(si + 1), ex \(ei + 1): missing reps")
                    }
                }
            }
        }
        return errors
    }

    // MARK: - JSON → ProgrammeData

    /// Convert a validated imported-programme dict into the iOS storage
    /// model. Rest-day sessions are dropped — they're a UI concept that we
    /// represent by absence of a `day` in the schedule grid.
    ///
    /// Exercise names go through `normalizeToCanonical` so that whatever the
    /// AI emitted ("Conventional Deadlift", "OHP", …) is stored as the
    /// canonical library spelling.
    static func programmeData(fromImported data: [String: Any]) -> ProgrammeData? {
        guard let name = data["name"] as? String else { return nil }
        let totalWeeks = (data["totalWeeks"] as? Int) ?? (data["totalWeeks"] as? Double).map(Int.init) ?? 1
        guard let rawWeeks = data["weeks"] as? [[String: Any]] else { return nil }

        let weeks: [ProgrammeWeek] = rawWeeks.compactMap { wk in
            let wn = (wk["weekNumber"] as? Int)
                  ?? (wk["weekNumber"] as? Double).map(Int.init)
                  ?? 1
            guard let rawSessions = wk["sessions"] as? [[String: Any]] else { return nil }
            let sessions: [ProgrammeSession] = rawSessions.compactMap { s in
                if (s["isRest"] as? Bool) == true { return nil }
                let day  = (s["day"]  as? String) ?? "mon"
                let name = (s["name"] as? String) ?? "Session"
                let rawExs = (s["exercises"] as? [[String: Any]]) ?? []
                let exs: [Exercise] = rawExs.map { ex in
                    let rawName = (ex["name"] as? String) ?? ""
                    let canonical = normalizeToCanonical(rawName) ?? rawName
                    let sets = (ex["sets"] as? Int) ?? (ex["sets"] as? Double).map(Int.init) ?? 3
                    let reps: String
                    if let r = ex["reps"] as? String { reps = r }
                    else if let r = ex["reps"] as? Int { reps = String(r) }
                    else if let r = ex["reps"] as? Double { reps = String(Int(r)) }
                    else { reps = "8-12" }
                    // weight: number | "BW" | "light"  →  Double? (nil for bodyweight/light)
                    let weight: Double?
                    if let w = ex["weight"] as? Double { weight = w }
                    else if let w = ex["weight"] as? Int { weight = Double(w) }
                    else { weight = nil }
                    return Exercise(
                        name:   canonical,
                        tag:    ex["tag"]   as? String,
                        sets:   sets,
                        reps:   reps,
                        weight: weight,
                        rpe:    ex["rpe"]   as? String,
                        notes:  ex["notes"] as? String
                    )
                }
                return ProgrammeSession(day: day, name: name, exercises: exs)
            }
            return ProgrammeWeek(weekNumber: wn, sessions: sessions)
        }

        return ProgrammeData(name: name, totalWeeks: totalWeeks, weeks: weeks)
    }
}
