import Foundation

/// Port of `src/lib/ptReplies.js` — pattern-matches user prompts to
/// canned coaching replies. The React version mutates state via callbacks
/// (`setProfile`, `rebuildProgramme`, ...) — the Swift port keeps everything
/// read-only by default; mutators that are wired through `AppState`
/// (lighter-today, bump-weight) are surfaced via the `mutations` field on
/// the result and applied by `PTChatView` after the reply renders.
enum PTReplies {

    // MARK: - Public API

    /// One canned reply (no async, pure function). `mutations` is the list of
    /// optional follow-up actions for the chat view to apply (e.g. dispatch a
    /// "lighter today" mutation to AppState).
    struct Reply {
        var text: String
        var mutations: [Mutation] = []
        var toast: String? = nil
    }

    enum Mutation {
        /// Scale all weights in `currentSession` by 0.9, round to nearest 0.5.
        case lighterToday
        /// Set the weight on a tracked lift inside the current session.
        case bumpLift(name: String, deltaKg: Double)
    }

    /// Main entry point — mirrors `generateReply` in the JS.
    /// `ctx` carries the read-only slices of AppState the reply functions need.
    static func reply(to input: String, ctx: Context) -> Reply {
        let raw = input.trimmingCharacters(in: .whitespaces)
        let text = raw.lowercased()
        guard !text.isEmpty else { return .init(text: "") }

        // ── Form cues ───────────────────────────────────────────────────────
        if text.contains("how to") || text.contains("form") {
            if let lift = findLift(text), let cues = FORM_CUES[lift] {
                return .init(text: cues)
            }
        }

        // ── Today's session ────────────────────────────────────────────────
        if text.contains("today") || text.contains("current session") || text.contains("what's today") {
            return todaySessionReply(ctx)
        }

        // ── Next session (auto mode only) ──────────────────────────────────
        if text.contains("next session") || text.contains("what's next") || text.contains("whats next") {
            return nextSessionReply(ctx)
        }

        // ── Progress summary ───────────────────────────────────────────────
        if text.contains("progress") || text.contains("how am i doing") {
            return progressReply(ctx)
        }

        // ── Lighter today ──────────────────────────────────────────────────
        if text.contains("lighter") || text.contains("easy day") || text.contains("light day") {
            return Reply(
                text: "Done — all weights reduced by 10% for today's session. Listen to your body and enjoy the active recovery.",
                mutations: [.lighterToday],
                toast: "Session updated ✓"
            )
        }

        // ── Weight bump: "bump my squat 5kg" ───────────────────────────────
        if let bump = matchBump(text) {
            return Reply(
                text: "Done — \(bump.name) bumped by \(formatWeight(bump.deltaKg))kg.",
                mutations: [.bumpLift(name: bump.name, deltaKg: bump.deltaKg)],
                toast: "Session updated ✓"
            )
        }

        // ── Fatigue ─────────────────────────────────────────────────────────
        if text.contains("fatigue") || text.contains("tired")
            || text.contains("worn out") || text.contains("exhausted") {
            let protein = Int((ctx.bodyweight ?? 75) * 2)
            return .init(text:
                "Recovery advice:\n" +
                "• Take an extra rest day if RPE was consistently 9+ this week\n" +
                "• Prioritise 8h sleep — most growth happens at night\n" +
                "• Protein target: ~\(protein)g/day\n" +
                "• De-load every 4–6 weeks: reduce weight 15–20%, keep the movement\n\n" +
                "Want me to make today's session lighter? Just say \"lighter today\"."
            )
        }

        // ── Nutrition ───────────────────────────────────────────────────────
        if text.contains("nutrition") || text.contains("protein")
            || text.contains("eat") || text.contains("diet") {
            let bw = ctx.bodyweight ?? 75
            let protein = Int(bw * 2)
            let water = (bw * 35 / 1000)
            return .init(text:
                "**Nutrition basics:**\n" +
                "• Protein: ~\(protein)g/day (2g per kg bodyweight)\n" +
                "• Calorie surplus for muscle: +200–400 kcal/day\n" +
                "• Calorie deficit for fat loss: −300–500 kcal/day\n" +
                "• Hydration: 35ml/kg/day (~\(String(format: "%.1f", water))L)\n" +
                "• Prioritise whole foods, don't overcomplicate it."
            )
        }

        // ── Help ────────────────────────────────────────────────────────────
        if text == "help" || text.contains("what can you do") || text.contains("commands") {
            return helpReply(ctx)
        }

        // ── Fallback ────────────────────────────────────────────────────────
        let suggestions = [
            "Try: \"What's today?\"",
            "\"How am I progressing?\"",
            "\"Form cues for bench\"",
            "\"Help\" for all commands",
        ]
        return .init(text: "I didn't catch that. \(suggestions.randomElement() ?? suggestions[0])")
    }

    // MARK: - Context

    /// Read-only slice the reply engine needs. `AppState` builds this on
    /// every send. Keeping it small means we don't have to thread the
    /// whole state object through pure-function-style code.
    struct Context {
        var bodyweight: Double?
        var currentSession: WorkoutSession?
        var activeProgrammeName: String?
        var programmeWeeks: [ProgrammeWeek]
        var history: [WorkoutSession]
        /// In-memory working weights used to format the "current lifts" block.
        var workingWeights: [String: Double]
    }

    // MARK: - Form cues

    private static let FORM_CUES: [String: String] = [
        "bench": """
        Bench Press cues:
        • Arch your upper back, not lower
        • Shoulder blades pinched and retracted
        • Bar path: slight diagonal toward lower chest
        • Drive feet into floor, full body tension
        • Wrists stacked over elbows
        """,
        "squat": """
        Back Squat cues:
        • Brace your core 360° before unracking
        • Break at hips and knees simultaneously
        • Track knees over toes throughout
        • Keep chest tall, avoid good-morning lean
        • Drive hips through at lockout
        """,
        "deadlift": """
        Deadlift cues:
        • Bar over mid-foot, hip-width stance
        • Hinge first, then knee bend to grip bar
        • Lat activation: "protect your armpits"
        • Push the floor away, don't pull the bar up
        • Lock out hips completely at top
        """,
        "ohp": """
        Overhead Press cues:
        • Start with bar just above clavicle
        • Elbows slightly in front of bar at bottom
        • Push head through at top (don't hyperextend)
        • Brace core, squeeze glutes throughout
        • Full lockout on every rep
        """,
        "row": """
        Barbell Row cues:
        • Hinge to ~45° torso angle
        • Pull to belly button, not chest
        • Lead with elbows, not biceps
        • Controlled eccentric, don't drop the bar
        • Squeeze shoulder blades at top
        """,
    ]

    private static func findLift(_ text: String) -> String? {
        if text.contains("bench") || text.contains("chest press") { return "bench" }
        if text.contains("squat") { return "squat" }
        if text.contains("deadlift") || text.contains("dead lift") { return "deadlift" }
        if text.contains("overhead") || text.contains("ohp") || text.contains("press") { return "ohp" }
        if text.contains("row") { return "row" }
        return nil
    }

    // MARK: - Today / next session

    private static func todaySessionReply(_ ctx: Context) -> Reply {
        guard let s = ctx.currentSession, let exercises = s.data?.exercises, !exercises.isEmpty
        else {
            return .init(text: "No session scheduled. Complete onboarding or select one from Home.")
        }
        let exList = exercises.map { ex -> String in
            let w = ex.weight.map { "\(formatWeight($0))kg" } ?? "BW"
            return "• \(ex.name) — \(ex.sets)×\(ex.reps) @ \(w)"
        }.joined(separator: "\n")
        return .init(text: "**\(s.name)**\n\(exList)")
    }

    private static func nextSessionReply(_ ctx: Context) -> Reply {
        guard let curr = ctx.currentSession, !ctx.programmeWeeks.isEmpty else {
            return .init(text: "No programme loaded.")
        }
        let allSessions = ctx.programmeWeeks.flatMap(\.sessions)
        guard let idx = allSessions.firstIndex(where: { $0.name == curr.name })
        else { return .init(text: "Couldn't locate the next session.") }
        let next = allSessions[(idx + 1) % allSessions.count]
        let preview = next.exercises.prefix(4).map { ex in
            "• \(ex.name) — \(ex.sets)×\(ex.reps)"
        }.joined(separator: "\n")
        return .init(text: "**Next session: \(next.name)**\n\(preview)")
    }

    // MARK: - Progress

    private static func progressReply(_ ctx: Context) -> Reply {
        let sessionCount = ctx.history.count
        let recentVol = ctx.history.prefix(4).reduce(0.0) { acc, sess in
            acc + (sess.data?.exercises.reduce(0.0) { a, e in
                a + (e.weight ?? 0) * Double(e.sets)
            } ?? 0)
        }
        var lines = [
            "**Your progress:**",
            "• Sessions logged: \(sessionCount)",
            "• Volume last 4 sessions: \(Int(recentVol))kg total",
        ]
        if !ctx.workingWeights.isEmpty {
            lines.append("")
            lines.append("**Current lifts:**")
            let order = ["bench", "squat", "deadlift", "ohp", "row"]
            for k in order {
                if let v = ctx.workingWeights[k] {
                    lines.append("• \(k.capitalized): \(formatWeight(v))kg")
                }
            }
        }
        return .init(text: lines.joined(separator: "\n"))
    }

    // MARK: - Bump match

    private struct Bump {
        let name: String
        let deltaKg: Double
    }

    /// Match patterns like "bump my squat 5kg" / "increase bench by 2.5kg" /
    /// "raise deadlift 10".
    private static func matchBump(_ text: String) -> Bump? {
        // very simple regex: <verb> [my] <lift> [by] <num>[kg]
        let pattern = #"(?:bump|increase|add|raise)\s+(?:my\s+)?(\w+)(?:\s+by)?\s+(\d+(?:\.\d+)?)\s*kg?"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              m.numberOfRanges >= 3,
              let nameRange = Range(m.range(at: 1), in: text),
              let numRange  = Range(m.range(at: 2), in: text)
        else { return nil }
        let liftWord = String(text[nameRange])
        let numStr   = String(text[numRange])
        guard let amount = Double(numStr) else { return nil }
        let key: String = {
            switch liftWord {
            case "ohp", "overhead", "press": return "ohp"
            case "deadlift": return "deadlift"
            case "squat":    return "squat"
            case "bench":    return "bench"
            case "row":      return "row"
            default:         return liftWord
            }
        }()
        return Bump(name: key, deltaKg: amount)
    }

    // MARK: - Help

    private static func helpReply(_ ctx: Context) -> Reply {
        let lines = [
            "**Available commands:**",
            "• \"What's today?\" — current session",
            "• \"Next session\" — upcoming workout",
            "• \"How am I progressing?\"",
            "• \"Form cues for bench/squat/deadlift/ohp/row\"",
            "• \"Lighter today\" — reduce weights 10%",
            "• \"Bump my squat 5kg\"",
            "• \"Nutrition\" — calorie & protein targets",
            "• \"I'm feeling fatigued\" — recovery advice",
        ]
        return .init(text: lines.joined(separator: "\n"))
    }

    // MARK: - Helpers

    private static func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(w))
            : String(format: "%.1f", w)
    }
}
