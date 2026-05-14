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
                // Mirrors React HomeTab.jsx:101-163: if today's programme
                // session exists, render a tap-to-train CTA; otherwise
                // render the lime rest-day card.
                todayOrRestCard
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

    // MARK: - Today / rest day

    /// Renders either the lime "TODAY'S SESSION" CTA (tap → Train tab) or
    /// the lime REST DAY card. Mirrors React's HomeTab ternary at
    /// HomeTab.jsx:101-163. The data source is `app.currentSession`, which
    /// `AppState.stageCurrentSessionFromActiveProgramme()` populates with
    /// today's matching day-key session or leaves nil for a real rest day.
    @ViewBuilder
    private var todayOrRestCard: some View {
        if let session = app.currentSession,
           let exercises = session.data?.exercises,
           !exercises.isEmpty {
            Button {
                app.activeTab = .train
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                todaySessionCardBody(name: session.name, exerciseCount: exercises.count)
            }
            .buttonStyle(.plain)
        } else {
            restDayCardBody
        }
    }

    /// "TODAY'S SESSION" lime card body. Shows the session name plus an
    /// `N exercises · ~M min` line, matching HomeTab.jsx:147-159.
    private func todaySessionCardBody(name: String, exerciseCount n: Int) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.black.opacity(0.6))
                    Text(ar ? "جلسة اليوم" : "TODAY'S SESSION")
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(ar ? 0 : 1.2)
                        .foregroundColor(Color.black.opacity(0.6))
                }

                Text(name)
                    .font(.system(size: 22, weight: .heavy))
                    .kerning(ar ? 0 : -0.4)
                    .foregroundColor(.black)
                    .padding(.top, 2)

                let mins = Int((Double(max(n, 5)) * 6).rounded())
                Text(ar
                     ? "\(n) تمارين · ≈ \(mins) دقيقة"
                     : "\(n) exercises · ~\(mins) min")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.55))
            }
            Spacer()
            Image(systemName: ar ? "chevron.left" : "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(HexTheme.accent)
        )
    }

    /// Lime REST DAY card — same copy + styling as before, isolated so the
    /// tap-vs-static branching in `todayOrRestCard` stays readable.
    private var restDayCardBody: some View {
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

    // MARK: - Week badge

    /// Week badge. For auto programmes shows `Week N · Block 1` where N is
    /// derived from history count divided by sessions-per-week, matching
    /// `HomeTab.jsx:43`. For imported programmes (multi-week) shows
    /// `Week N / total` instead.
    private var weekBadge: some View {
        Text(weekBadgeText)
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

    private var weekBadgeText: String {
        let weeks = app.activeProgramme?.data?.weeks ?? []
        let totalWeeks = app.activeProgramme?.data?.totalWeeks ?? max(weeks.count, 1)
        if totalWeeks > 1 {
            // Imported programme — pick the active week if known, else 1.
            let curWeek = max(1, min(totalWeeks, weeks.first?.weekNumber ?? 1))
            return ar
                ? "الأسبوع \(curWeek) / \(totalWeeks)"
                : "Week \(curWeek) / \(totalWeeks)"
        }
        // Auto programme — derive an ever-incrementing week number from
        // completed-session count, like React's `Math.ceil((history+1)/sessionsPerWeek)`.
        let sessionsPerWeek = max(1, weeks.first?.sessions.count ?? 1)
        let weekNum = max(1, Int(ceil(Double(app.workoutHistory.count + 1) / Double(sessionsPerWeek))))
        return ar
            ? "الأسبوع \(weekNum) · المرحلة ١"
            : "Week \(weekNum) · Block 1"
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
