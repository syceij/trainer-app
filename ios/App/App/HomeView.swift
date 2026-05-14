import SwiftUI

/// Home tab — mirrors src/components/HomeTab.jsx.
/// Greeting + lang toggle, today's session card (or rest-day card), week
/// badge, stats grid, and a "View full programme" link.
struct HomeView: View {
    @EnvironmentObject var app: AppState
    @State private var showProgramme = false

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Greeting + lang toggle ────────────────────────
                HStack(alignment: .top, spacing: 12) {
                    Text(greetingLine)
                        .font(.system(size: 26, weight: .heavy))
                        .kerning(ar ? 0 : -0.5)
                        .foregroundColor(HexTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            app.language = ar ? "en" : "ar"
                        }
                    } label: {
                        Text(ar ? "EN" : "AR")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(HexTheme.dim)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(HexTheme.surface2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(HexTheme.border, lineWidth: 1.5)
                            )
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 20)

                // ── Today / rest card ─────────────────────────────
                restDayCard
                    .padding(.bottom, 14)

                // ── Week badge ────────────────────────────────────
                weekBadge
                    .padding(.bottom, 20)

                // ── Stats grid ────────────────────────────────────
                statsGrid
                    .padding(.bottom, 20)

                // ── Programme link ────────────────────────────────
                programmeLink

                Spacer(minLength: 100) // room for floating tab bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .scrollContentBackground(.hidden)
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showProgramme) {
            ProgrammeModalView()
                .environmentObject(app)
        }
    }

    // MARK: - Pieces

    private var greetingLine: String {
        let h = Calendar.current.component(.hour, from: Date())
        let name = app.currentProfile?.name ?? (ar ? "" : "there")
        if ar {
            let g = h < 12 ? "صــباح الخير" : "مسـاء الخيـر"
            return name.isEmpty ? "\(g) 👋" : "\(g)، \(name) 👋"
        }
        let g = h < 12 ? "Good morning" : (h < 17 ? "Good afternoon" : "Good evening")
        return "\(g), \(name) 👋"
    }

    /// Lime-accent rest-day card. Shown when there's no active session
    /// (the React version flips to a workout button when currentSession is set).
    private var restDayCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ar ? "يوم راحة" : "REST DAY")
                .font(.system(size: 10, weight: .heavy))
                .kerning(ar ? 0 : 1.2)
                .foregroundColor(Color.black.opacity(0.6))

            Text(ar ? "استمتع بيوم إجازتك" : "Enjoy your off day")
                .font(.system(size: 22, weight: .heavy))
                .kerning(ar ? 0 : -0.4)
                .foregroundColor(.black)
                .padding(.top, 2)

            Text(ar ? "التعافي جزء من البرنامج" : "Recovery is part of the programme")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.black.opacity(0.55))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(HexTheme.accent)
        )
    }

    private var weekBadge: some View {
        Text(ar ? "الأسبوع ١ · المرحلة ١" : "Week 1 · Block 1")
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(HexTheme.dim)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(HexTheme.surface2)
            )
            .overlay(
                Capsule().stroke(HexTheme.border, lineWidth: 1.5)
            )
    }

    private var statsGrid: some View {
        HStack(spacing: 8) {
            statCard(value: "\(totalSessions)",
                     label: ar ? "جلسات"    : "SESSIONS")
            statCard(value: "\(streakCount) 🔥",
                     label: ar ? "الإنجاز"   : "STREAK")
            statCard(value: lastVolumeLabel,
                     label: ar ? "آخر حجم"   : "LAST VOL.")
        }
    }

    // MARK: - Stats

    /// Total completed/in-progress sessions in history.
    private var totalSessions: Int {
        app.workoutHistory.count
    }

    /// Current streak — consecutive days (including today or yesterday)
    /// with at least one logged session. Mirrors the React implementation
    /// in src/components/HomeTab.jsx.
    private var streakCount: Int {
        let cal = Calendar.current
        let dayKeys: Set<Date> = Set(
            app.workoutHistory.map { cal.startOfDay(for: $0.date) }
        )
        guard !dayKeys.isEmpty else { return 0 }
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        // Allow the streak to start from "yesterday" if today wasn't logged
        // yet — matches React.
        if !dayKeys.contains(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            if !dayKeys.contains(cursor) { return 0 }
        }
        while dayKeys.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Volume of the most recent session — sum of `weight × sets` across
    /// exercises that have a real working weight. Displays "—" if not
    /// computable. Formats >=1000 kg as e.g. "12t".
    private var lastVolumeLabel: String {
        guard let last = app.workoutHistory.first,
              let exercises = last.data?.exercises
        else { return "—" }
        // Match React's history-volume reducer in App.jsx:
        //   r.data.exercises.reduce((s, ex) =>
        //     (!ex.bodyweight && ex.weight) ? s + ex.weight * (ex.sets || 1) : s, 0)
        let vol = exercises.reduce(0.0) { acc, ex in
            if ex.bodyweight { return acc }
            let w = ex.weight ?? 0
            guard w > 0 else { return acc }
            let setCount = max(ex.sets, 1)
            return acc + w * Double(setCount)
        }
        guard vol > 0 else { return "—" }
        if vol >= 1000 {
            return "\(Int(vol / 1000))t"
        }
        return "\(Int(vol))kg"
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(HexTheme.text)
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .kerning(ar ? 0 : 0.6)
                .foregroundColor(HexTheme.mute)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    private var programmeLink: some View {
        Button {
            showProgramme = true
        } label: {
            HStack {
                Text(ar ? "عرض البرنامج كاملاً" : "View full programme")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HexTheme.text)
                Spacer()
                Image(systemName: ar ? "chevron.left" : "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
