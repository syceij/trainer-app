import Foundation

// MARK: - Badge taxonomy
//
// The full catalogue of unlockable trophies. Three families:
//
//   1. **Monthly** — earned for hitting 100% consistency in a given
//      calendar month. Each year-month is a separate instance (so
//      e.g. `monthly_2026_05` and `monthly_2027_05` are both "May"
//      badges that stack). 12 visual variants, one per calendar month.
//
//   2. **Power** — earned for crossing an improvement threshold on
//      a single exercise (volume vs. first-ever-recorded set):
//        • `power_100` — 100%+ improvement
//        • `power_200` — 200%+ improvement
//        • `power_500` — 500%+ improvement
//      Each is per-exercise: hitting 200% on bench and 200% on squat
//      gives you two distinct `power_200` instances.
//
//   3. **Meta tier** — auto-awarded when the user's lifetime count
//      of MONTHLY badges crosses a threshold:
//        • `hero`        — 3 monthly badges
//        • `lebron`      — 6 monthly badges
//        • `invincible`  — 12 monthly badges
//      One-time only: passing 24 monthlies doesn't grant a 2nd INVINCIBLE.
//      These are "milestone" trophies, not stackable.
//
// Each earned instance is stored as an `EarnedBadge` in the user's
// `profiles.badges` jsonb column (added by the migration shipped with
// this commit). The stable `id` field doubles as a dedup key so the
// evaluator never awards the same trophy twice.

/// What kind of trophy this is. Drives which image asset gets
/// loaded and which display copy is used. The raw string is what
/// gets persisted to Supabase — keep it stable.
enum BadgeKind: String, Codable, CaseIterable, Hashable {
    case monthly
    case power100   = "power_100"
    case power200   = "power_200"
    case power500   = "power_500"
    case hero
    case lebron
    case invincible

    /// Display copy in EN / AR — short caption shown under the
    /// badge in the trophy strip and the View All grid.
    func label(ar: Bool) -> String {
        switch self {
        case .monthly:    return ar ? "بطل الشهر"        : "Month King"
        case .power100:   return ar ? "قوة ١٠٠٪"         : "100% Power"
        case .power200:   return ar ? "قوة ٢٠٠٪"         : "200% Power"
        case .power500:   return ar ? "قوة ٥٠٠٪"         : "500% Power"
        case .hero:       return ar ? "بطل"              : "Hero"
        case .lebron:     return ar ? "ليبرون جيمس"      : "Lebron James"
        case .invincible: return ar ? "لا يُقهر"          : "Invincible"
        }
    }

    /// Human-readable unlock criteria, shown in the badge detail
    /// popover and on locked silhouettes in the View All grid.
    func criteria(ar: Bool) -> String {
        switch self {
        case .monthly:    return ar ? "أكمل ١٠٠٪ من برنامج الشهر"        : "Hit 100% of your monthly programme"
        case .power100:   return ar ? "حسّن ١٠٠٪ في تمرين واحد"          : "100% improvement on one exercise"
        case .power200:   return ar ? "حسّن ٢٠٠٪ في تمرين واحد"          : "200% improvement on one exercise"
        case .power500:   return ar ? "حسّن ٥٠٠٪ في تمرين واحد"          : "500% improvement on one exercise"
        case .hero:       return ar ? "اربح ٣ شارات شهرية"               : "Earn 3 monthly badges"
        case .lebron:     return ar ? "اربح ٦ شارات شهرية"               : "Earn 6 monthly badges"
        case .invincible: return ar ? "اربح ١٢ شارة شهرية"               : "Earn 12 monthly badges"
        }
    }
}

// MARK: - Earned badge instance

/// One trophy in the user's collection. `id` uniquely identifies
/// the instance — the evaluator uses it to dedupe (so the same
/// monthly badge for `2026-05` is never awarded twice).
struct EarnedBadge: Codable, Hashable, Identifiable {
    let id: String           // e.g. "monthly_2026_05" / "power_200_bench_press"
    let kind: BadgeKind
    /// `YYYY-MM` for monthly badges, nil otherwise.
    let month: String?
    /// Exercise key for `power_*` badges (lowercased, slugged),
    /// nil otherwise.
    let exercise: String?
    /// Improvement percentage at the moment of awarding (only
    /// populated for `power_*`). Lets the detail popover show
    /// "100 → 215kg (+115%)" instead of just the threshold.
    let value: Int?
    let earnedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, month, exercise, value
        case earnedAt = "earned_at"
    }
}

// MARK: - Asset resolution

extension EarnedBadge {
    /// Asset-catalog image name. Maps each badge to one of the
    /// 18 imagesets shipped under `Assets.xcassets/Badge*.imageset`.
    /// Falls back to `BadgeJan` if the month is malformed (defensive
    /// — should never hit in practice).
    var imageName: String {
        switch kind {
        case .monthly:
            // month is "YYYY-MM"; pull the MM and look it up.
            guard let m = month?.split(separator: "-").last,
                  let n = Int(m), (1...12).contains(n)
            else { return "BadgeJan" }
            return BadgeKind.monthAssetName(for: n)
        case .power100:   return "BadgePower100"
        case .power200:   return "BadgePower200"
        case .power500:   return "BadgePower500"
        case .hero:       return "BadgeHero"
        case .lebron:     return "BadgeLebron"
        case .invincible: return "BadgeInvincible"
        }
    }
}

extension BadgeKind {
    /// Asset name for a specific calendar month (1=Jan … 12=Dec).
    /// Only relevant for `.monthly`.
    static func monthAssetName(for n: Int) -> String {
        switch n {
        case 1:  return "BadgeJan"
        case 2:  return "BadgeFeb"
        case 3:  return "BadgeMar"
        case 4:  return "BadgeApr"
        case 5:  return "BadgeMay"
        case 6:  return "BadgeJun"
        case 7:  return "BadgeJul"
        case 8:  return "BadgeAug"
        case 9:  return "BadgeSep"
        case 10: return "BadgeOct"
        case 11: return "BadgeNov"
        case 12: return "BadgeDec"
        default: return "BadgeJan"
        }
    }

    /// Localised short caption for a calendar month (1=Jan …).
    /// Used by monthly-badge previews so the strip reads
    /// "Jan 2026" / "أبريل ٢٠٢٦" not just "Month King".
    static func monthShortName(for n: Int, ar: Bool) -> String {
        let names = ar
            ? ["يناير","فبراير","مارس","أبريل","مايو","يونيو",
               "يوليو","أغسطس","سبتمبر","أكتوبر","نوفمبر","ديسمبر"]
            : ["Jan","Feb","Mar","Apr","May","Jun",
               "Jul","Aug","Sep","Oct","Nov","Dec"]
        guard (1...12).contains(n) else { return "" }
        return names[n - 1]
    }
}

// MARK: - The full catalogue (for the "View all" sheet)

/// Every kind of badge that exists, in display order. Used by the
/// View All sheet to render locked silhouettes for badges the user
/// hasn't earned yet.
///
/// Monthly badges expand to 12 entries (one per calendar month) so
/// users can see all twelve waiting to be earned.
enum BadgeCatalogue {
    /// One slot in the View All grid. `kind` + optional `month`
    /// identifies the asset; `instanceId` is the dedup key we'd use
    /// when awarding.
    struct Slot: Identifiable, Hashable {
        let id: String      // matches the EarnedBadge.id format
        let kind: BadgeKind
        let month: Int?     // 1...12 for monthly slots
        let imageName: String
        let label: (Bool) -> String

        static func == (a: Slot, b: Slot) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    /// Build the full list of slots — monthly (12) + power (3) +
    /// meta (3). Note: power and meta badges are stackable per
    /// exercise / per threshold, but for the "View All" view we
    /// show ONE slot per kind as a representative (the actual
    /// earned-count appears as a small badge in the corner).
    static let allSlots: [Slot] = {
        var slots: [Slot] = []
        // Monthly — Jan through Dec
        for n in 1...12 {
            slots.append(Slot(
                id: "monthly_template_\(n)",
                kind: .monthly,
                month: n,
                imageName: BadgeKind.monthAssetName(for: n),
                label: { ar in BadgeKind.monthShortName(for: n, ar: ar) }
            ))
        }
        // Power tiers
        for kind in [BadgeKind.power100, .power200, .power500] {
            slots.append(Slot(
                id: kind.rawValue,
                kind: kind,
                month: nil,
                imageName: "Badge\(kind.rawValue.split(separator: "_").map { $0.capitalized }.joined())",
                label: { ar in kind.label(ar: ar) }
            ))
        }
        // Meta tiers
        for kind in [BadgeKind.hero, .lebron, .invincible] {
            slots.append(Slot(
                id: kind.rawValue,
                kind: kind,
                month: nil,
                imageName: "Badge\(kind.rawValue.capitalized)",
                label: { ar in kind.label(ar: ar) }
            ))
        }
        return slots
    }()
}
