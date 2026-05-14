import Foundation

/// Port of src/lib/muscleUtils.js — shared muscle-group resolver used by
/// the Progress tab bars and the MusclePage detail view. Lives in one
/// place so the name-matching logic stays consistent.
enum MuscleUtils {

    // MARK: - Muscle group definitions

    struct MuscleGroup {
        let id: String
        let label: String         // English label; UI translates as needed
        let muscles: [String]     // primary muscle keys that roll up into this group
    }

    static let groups: [MuscleGroup] = [
        .init(id: "chest",     label: "Chest",     muscles: ["chest"]),
        .init(id: "back",      label: "Back",      muscles: ["back"]),
        .init(id: "shoulders", label: "Shoulders", muscles: ["shoulders"]),
        .init(id: "arms",      label: "Arms",      muscles: ["biceps", "triceps"]),
        .init(id: "legs",      label: "Legs",      muscles: ["quads", "hamstrings", "glutes", "calves"]),
        .init(id: "core",      label: "Core",      muscles: ["core"]),
    ]

    static func group(id: String) -> MuscleGroup? {
        groups.first { $0.id == id }
    }

    // MARK: - Lookup tables built from the EXERCISES library

    private static let keyToMuscle: [String: String] = {
        var m: [String: String] = [:]
        for ex in ProgrammeBuilder.exercises { m[ex.key] = ex.muscle }
        return m
    }()

    private static let nameToMuscle: [String: String] = {
        var m: [String: String] = [:]
        for ex in ProgrammeBuilder.exercises { m[ex.name.lowercased()] = ex.muscle }
        return m
    }()

    /// Manual alias map — known sets-table names → nearest library name.
    /// Mirrors EXERCISE_NAME_MAP in muscleUtils.js.
    private static let exerciseNameMap: [String: String] = [
        "deadlift":                    "deadlift",
        "incline db press":            "incline db press",
        "cable row":                   "cable row",
        "lat pulldown (neutral grip)": "lat pulldown",
        "lateral raise (db)":          "lateral raise",
        "skull crusher":               "tricep pushdown",
        "skull crushers":              "tricep pushdown",
        "tricep pushdown (cable)":     "tricep pushdown",
        "hammer curl":                 "hammer curl",
        "cable fly":                   "cable fly",
        "cable crunch":                "cable crunch",
        "barbell bench press":         "barbell bench press",
    ]

    /// Direct muscle assignments for names not in the EXERCISES library.
    /// Mirrors MANUAL_MUSCLE_MAP in muscleUtils.js.
    private static let manualMuscleMap: [String: String] = [
        "skull crusher":               "triceps",
        "skull crushers":              "triceps",
        "cable crunch":                "core",
        "lat pulldown (neutral grip)": "back",
        "lateral raise (db)":          "shoulders",
        "tricep pushdown (cable)":     "triceps",
        "hammer curl":                 "biceps",
    ]

    // MARK: - Resolution

    /// Same 7-step fall-through as resolveMuscle() in muscleUtils.js.
    /// Returns nil when no muscle can be confidently inferred.
    static func resolveMuscle(name: String?, key: String? = nil) -> String? {
        // 2. Key-based exact lookup
        if let k = key, let m = keyToMuscle[k] { return m }

        guard let raw = name else { return nil }
        let nameLc = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if nameLc.isEmpty { return nil }

        // 3. Direct manual map
        if let m = manualMuscleMap[nameLc] { return m }

        // 4. Alias normalisation then exact lookup
        let normalised = exerciseNameMap[nameLc] ?? nameLc
        if let m = nameToMuscle[normalised] { return m }

        // 5. Case-insensitive exact library lookup
        if let m = nameToMuscle[nameLc] { return m }

        // 6. Partial — library name contains the exercise's first word
        let firstWord = nameLc.split(separator: " ").first.map(String.init) ?? nameLc
        if !firstWord.isEmpty {
            for (lib, muscle) in nameToMuscle where lib.contains(firstWord) {
                return muscle
            }
        }

        // 7. Reverse partial — exercise contains library entry's first word
        for (lib, muscle) in nameToMuscle {
            let libFirst = lib.split(separator: " ").first.map(String.init) ?? lib
            if !libFirst.isEmpty && nameLc.contains(libFirst) { return muscle }
        }

        return nil
    }

    /// Convenience wrapper for sets-table rows that only have a name.
    static func resolveMuscle(fromName name: String) -> String? {
        resolveMuscle(name: name, key: nil)
    }
}
