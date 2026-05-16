import SwiftUI

/// Profile tab — surfaces the user's stats prominently and pushes
/// the Account/Settings stuff behind a gear button in the corner.
///
/// Layout (top to bottom):
///   • Header: avatar + name + username, with a settings gear on
///     the trailing side that pushes into the existing AccountView.
///   • Score hero card: this month's leaderboard score with the
///     consistency + improvement breakdown, plus a "See older
///     months" button that opens a history sheet.
///   • Stats grid: friend count + programme name.
///   • Top exercises: 3 most-trained lifts this month (by set count).
///   • Top muscles: 3 most-trained muscle groups this month.
///
/// This file is the foundation for the future badges / trophies
/// system — once monthly score snapshots are accumulating in
/// Supabase, the history sheet will be the entry point for past
/// month / badge browsing.
struct ProfileView: View {
    @EnvironmentObject var app: AppState

    /// Drives the "See older months" sheet (foundation for the
    /// future badges/trophies system).
    @State private var showHistory = false

    /// Drives the Settings (AccountView) sheet. Opens as a modal
    /// rather than a navigation push so it doesn't persist on the
    /// tab's NavigationStack — previously, tapping the gear once
    /// then switching tabs left the user "stuck" on AccountView
    /// when they returned to the Profile tab (NavigationStack
    /// remembers its path across tab switches).
    @State private var showSettings = false

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                    .padding(.top, 4)
                scoreCard
                statsGrid
                topExercisesSection
                topMusclesSection
                Spacer(minLength: 60) // room for the floating tab bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showHistory) {
            historySheet
        }
        .sheet(isPresented: $showSettings) {
            // Wrap AccountView in its own NavigationStack so its
            // sub-pages (Build Programme, Manual Builder, Calendar
            // etc.) push correctly inside the sheet without
            // polluting the tab's stack. Dismissing the sheet
            // returns the user cleanly to the Profile tab.
            NavigationStack { AccountView() }
                .environmentObject(app)
        }
        .environment(\.layoutDirection, ar ? .rightToLeft : .leftToRight)
    }

    // MARK: - Header (avatar + name + settings gear)

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            avatarCircle
            VStack(alignment: .leading, spacing: 2) {
                Text(app.currentProfile?.name ?? "—")
                    .font(HexTheme.font(size: 20, weight: .heavy, ar: ar))
                    .foregroundColor(HexTheme.text)
                    .lineLimit(1)
                if let uname = app.currentProfile?.username, !uname.isEmpty {
                    Text("@" + uname)
                        .font(HexTheme.font(size: 13, weight: .regular, ar: ar))
                        .foregroundColor(HexTheme.dim)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(HexTheme.surface2)
                    )
                    .overlay(
                        Circle().stroke(HexTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    /// Avatar — uses AsyncImage when the user has a URL, falls back
    /// to a lime-tinted initial circle when they don't (same shape
    /// the React ProfileTab renders).
    private var avatarCircle: some View {
        Group {
            if let urlString = app.currentProfile?.avatarURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    initialFallback
                }
            } else {
                initialFallback
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay(Circle().stroke(HexTheme.border, lineWidth: 1.5))
    }

    private var initialFallback: some View {
        ZStack {
            Circle().fill(HexTheme.surface2)
            Text(String((app.currentProfile?.name ?? "?").prefix(1)).uppercased())
                .font(HexTheme.font(size: 24, weight: .heavy, ar: ar))
                .foregroundColor(HexTheme.accent)
        }
    }

    // MARK: - Score hero card

    /// Pulls the cached current-month leaderboard from
    /// `currentProfile.leaderboard_data`. If absent or stale (wrong
    /// month), shows zeros — same defensive treatment the leaderboard
    /// in CrewView uses.
    private var currentMonthData: LeaderboardData? {
        let monthKey = Self.currentMonthKey()
        guard let ld = app.currentProfileLeaderboard else { return nil }
        return ld.month == monthKey ? ld : nil
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(ar ? "هذا الشهر" : "THIS MONTH")
                    .font(HexTheme.font(size: 10, weight: .heavy, ar: ar))
                    .kerning(ar ? 0 : 0.8)
                    .foregroundColor(HexTheme.accent)
                Spacer()
                Text(Self.formattedMonthYear(for: Date(), ar: ar))
                    .font(HexTheme.font(size: 11, weight: .heavy, ar: ar))
                    .foregroundColor(HexTheme.mute)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(currentMonthData?.score ?? 0)")
                    .font(HexTheme.font(size: 56, weight: .heavy, ar: ar))
                    .foregroundColor(HexTheme.accent)
                    .monospacedDigit()
                Text(ar ? "نقطة" : "pts")
                    .font(HexTheme.font(size: 14, weight: .heavy, ar: ar))
                    .foregroundColor(HexTheme.dim)
                Spacer()
            }

            // Breakdown row — consistency / improvement
            HStack(spacing: 0) {
                breakdownPill(
                    label: ar ? "الالتزام" : "Consistency",
                    value: consistencyText,
                    accent: HexTheme.accent
                )
                Rectangle()
                    .fill(HexTheme.border)
                    .frame(width: 1, height: 28)
                breakdownPill(
                    label: ar ? "التحسن" : "Improvement",
                    value: improvementText,
                    accent: HexTheme.accent.opacity(0.55)
                )
            }
            .padding(.top, 4)

            // History entry point
            Button {
                showHistory = true
            } label: {
                HStack(spacing: 6) {
                    Text(ar ? "عرض الأشهر السابقة" : "See older months")
                        .font(HexTheme.font(size: 13, weight: .heavy, ar: ar))
                    Image(systemName: ar ? "chevron.left" : "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                }
                .foregroundColor(HexTheme.accent)
                .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(HexTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(HexTheme.accent.opacity(0.20), lineWidth: 1.5)
        )
    }

    private var consistencyText: String {
        guard let ld = currentMonthData, ld.setsProgrammed > 0 else {
            return ar ? "—" : "—"
        }
        let pct = Int((Double(ld.setsCompleted) / Double(ld.setsProgrammed) * 100).rounded())
        return "\(ld.setsCompleted)/\(ld.setsProgrammed) (\(pct)%)"
    }
    private var improvementText: String {
        guard let ld = currentMonthData else { return ar ? "—" : "—" }
        return "+\(ld.improvementPct)%"
    }

    private func breakdownPill(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(HexTheme.font(size: 10, weight: .heavy, ar: ar))
                .foregroundColor(HexTheme.dim)
            Text(value)
                .font(HexTheme.font(size: 13, weight: .heavy, ar: ar))
                .foregroundColor(accent)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats grid (friends + programme)

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCard(
                label: ar ? "الأصدقاء" : "Friends",
                value: "\(app.friends.count)",
                icon: "person.2.fill"
            )
            statCard(
                label: ar ? "البرنامج" : "Programme",
                value: app.activeProgramme?.name
                    ?? (ar ? "لا يوجد" : "None"),
                icon: "list.bullet.rectangle.fill"
            )
        }
    }

    private func statCard(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(HexTheme.accent)
                Text(label)
                    .font(HexTheme.font(size: 11, weight: .heavy, ar: ar))
                    .foregroundColor(HexTheme.dim)
            }
            Text(value)
                .font(HexTheme.font(size: 16, weight: .heavy, ar: ar))
                .foregroundColor(HexTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Top exercises (this month)

    /// Map of exercise-name → set count, restricted to sessions in
    /// the current calendar month. We use the saved
    /// `WorkoutSession.data.exercises[].sets` rather than the raw
    /// `sets` table because the history is already local and
    /// querying Supabase from inside a SwiftUI view is awkward.
    /// Future iteration: derive from a cached SetsRow query for
    /// accuracy.
    private var topExercisesThisMonth: [(name: String, sets: Int)] {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))
            ?? now
        var counts: [String: Int] = [:]
        for s in app.workoutHistory where s.date >= monthStart {
            for ex in s.data?.exercises ?? [] {
                counts[ex.name, default: 0] += max(ex.sets, 1)
            }
        }
        return counts
            .map { (name: $0.key, sets: $0.value) }
            .sorted { $0.sets > $1.sets }
            .prefix(3)
            .map { $0 }
    }

    @ViewBuilder
    private var topExercisesSection: some View {
        let rows = topExercisesThisMonth
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(ar ? "أكثر التمارين هذا الشهر" : "TOP EXERCISES THIS MONTH")
                    .font(HexTheme.font(size: 10, weight: .heavy, ar: ar))
                    .kerning(ar ? 0 : 0.8)
                    .foregroundColor(HexTheme.dim)
                    .padding(.bottom, 2)
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                        topRowView(rank: idx + 1,
                                   title: row.name,
                                   value: "\(row.sets) " + (ar ? "مجموعة" : "sets"))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(HexTheme.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(HexTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: - Top muscles (this month)

    /// Resolve a muscle group for an exercise by looking it up in the
    /// shipped library. Falls back to "other" so an unmatched custom
    /// exercise doesn't disappear from the chart entirely.
    private func muscleFor(_ exerciseName: String) -> String {
        let lower = exerciseName.lowercased().trimmingCharacters(in: .whitespaces)
        if let match = ProgrammeBuilder.exercises.first(where: { $0.name.lowercased() == lower }) {
            return match.muscle
        }
        return "other"
    }

    private var topMusclesThisMonth: [(muscle: String, sets: Int)] {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))
            ?? now
        var counts: [String: Int] = [:]
        for s in app.workoutHistory where s.date >= monthStart {
            for ex in s.data?.exercises ?? [] {
                counts[muscleFor(ex.name), default: 0] += max(ex.sets, 1)
            }
        }
        return counts
            .map { (muscle: $0.key, sets: $0.value) }
            .sorted { $0.sets > $1.sets }
            .prefix(3)
            .map { $0 }
    }

    /// Bilingual + capitalised muscle name.
    private func muscleDisplayName(_ key: String) -> String {
        if ar {
            switch key {
            case "chest":      return "الصدر"
            case "shoulders":  return "الأكتاف"
            case "back":       return "الظهر"
            case "biceps":     return "البايسبس"
            case "triceps":    return "الترايسبس"
            case "quads":      return "الفخذ الأمامي"
            case "hamstrings": return "الفخذ الخلفي"
            case "calves":     return "السمانة"
            case "core":       return "البطن"
            case "other":      return "أخرى"
            default:           return key
            }
        }
        return key.prefix(1).uppercased() + key.dropFirst()
    }

    @ViewBuilder
    private var topMusclesSection: some View {
        let rows = topMusclesThisMonth
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(ar ? "أكثر العضلات هذا الشهر" : "TOP MUSCLES THIS MONTH")
                    .font(HexTheme.font(size: 10, weight: .heavy, ar: ar))
                    .kerning(ar ? 0 : 0.8)
                    .foregroundColor(HexTheme.dim)
                    .padding(.bottom, 2)
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                        topRowView(rank: idx + 1,
                                   title: muscleDisplayName(row.muscle),
                                   value: "\(row.sets) " + (ar ? "مجموعة" : "sets"))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(HexTheme.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(HexTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: - Top-row cell

    private func topRowView(rank: Int, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(HexTheme.font(size: 12, weight: .heavy, ar: ar))
                .foregroundColor(rank == 1 ? HexTheme.accent : HexTheme.dim)
                .frame(width: 20, alignment: .center)
            Text(title)
                .font(HexTheme.font(size: 14, weight: .heavy, ar: ar))
                .foregroundColor(HexTheme.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .font(HexTheme.font(size: 12, weight: .heavy, ar: ar))
                .foregroundColor(HexTheme.dim)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(
            Rectangle()
                .fill(HexTheme.border.opacity(rank == 1 ? 0 : 0.7))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - History sheet (older months)

    /// Foundation for the badges/trophies system — for now it's a
    /// placeholder explaining that history will populate as the user
    /// completes more months. Future iteration: query historical
    /// snapshots from a dedicated table once we start writing them.
    private var historySheet: some View {
        VStack(spacing: 16) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(HexTheme.border)
                .frame(width: 40, height: 4)
                .padding(.top, 10)

            Text(ar ? "السجل الشهري" : "Monthly History")
                .font(HexTheme.font(size: 18, weight: .heavy, ar: ar))
                .foregroundColor(HexTheme.text)
                .padding(.top, 6)

            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 36))
                    .foregroundColor(HexTheme.accent.opacity(0.45))
                Text(ar
                     ? "السجل سيظهر هنا في نهاية كل شهر"
                     : "Past months appear here as you complete them")
                    .font(HexTheme.font(size: 14, weight: .heavy, ar: ar))
                    .foregroundColor(HexTheme.dim)
                    .multilineTextAlignment(.center)
                Text(ar
                     ? "هذه الأساسات الجديدة لنظام الأوسمة القادم"
                     : "Foundation for the upcoming badges & trophies system")
                    .font(HexTheme.font(size: 12, weight: .regular, ar: ar))
                    .foregroundColor(HexTheme.mute)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 28)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HexTheme.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Helpers

    private static func currentMonthKey() -> String {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month], from: Date())
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }

    private static func formattedMonthYear(for date: Date, ar: Bool) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: ar ? "ar" : "en")
        df.dateFormat = "MMMM yyyy"
        return df.string(from: date).uppercased()
    }
}
