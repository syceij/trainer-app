import SwiftUI

/// Workout calendar — port of src/components/CalendarPage.jsx.
/// Month view (Mon-first 7-column grid), prev/next month nav, day cells
/// colored by status (logged / missed / scheduled / rest), legend, and a
/// month-stats card at the bottom.
///
/// Status data comes from `app.workoutHistory` once that's wired to
/// Supabase — for now everything renders as "rest" / no data.
struct CalendarView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var viewYear: Int
    @State private var viewMonth: Int   // 0…11

    init() {
        let now = Date()
        let cal = Calendar.current
        _viewYear  = State(initialValue: cal.component(.year,  from: now))
        _viewMonth = State(initialValue: cal.component(.month, from: now) - 1)
    }

    private var ar: Bool { app.language == "ar" }

    /// JS-day indices (0=Sun … 6=Sat) the user is supposed to train on.
    /// Default to Mon/Tue/Thu/Fri if no programme data is loaded yet.
    private var trainingDayIndices: Set<Int> {
        // TODO: derive from app.activeProgramme schedule
        Set([1, 2, 4, 5])
    }

    /// Dates the user has actually logged a session on. Empty until
    /// `WorkoutSession` history wiring is done.
    private var loggedDates: Set<DateComponents> { [] }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    monthNav.padding(.horizontal, 20).padding(.top, 16)
                    weekdayHeader.padding(.horizontal, 12).padding(.top, 4)
                    gridView.padding(.horizontal, 12).padding(.bottom, 20)
                    legend.padding(.horizontal, 20).padding(.bottom, 20)
                    statsCard.padding(.horizontal, 20).padding(.bottom, 30)
                }
            }
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: ar ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(HexTheme.text)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Text(ar ? "تقويم التمارين" : "Gym Calendar")
                .font(.system(size: 17, weight: .heavy))
                .kerning(ar ? 0 : -0.4)
                .foregroundColor(HexTheme.text)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .overlay(
            Rectangle().fill(HexTheme.border).frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Month nav

    private var monthNav: some View {
        HStack {
            Button { prevMonth() } label: {
                Image(systemName: ar ? "chevron.right" : "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HexTheme.dim)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(monthName(viewMonth)) \(viewYear)")
                .font(.system(size: 16, weight: .heavy))
                .kerning(ar ? 0 : -0.2)
                .foregroundColor(HexTheme.text)

            Spacer()

            Button { nextMonth() } label: {
                Image(systemName: ar ? "chevron.left" : "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HexTheme.dim)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 12)
    }

    private func prevMonth() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if viewMonth == 0 {
                viewMonth = 11
                viewYear -= 1
            } else {
                viewMonth -= 1
            }
        }
    }

    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if viewMonth == 11 {
                viewMonth = 0
                viewYear += 1
            } else {
                viewMonth += 1
            }
        }
    }

    // MARK: - Weekday header

    private var weekdayHeader: some View {
        let labels = ar ? ["إ","ث","أ","خ","ج","س","ح"]
                       : ["M","T","W","T","F","S","S"]
        return HStack(spacing: 3) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(ar ? 0 : 0.5)
                    .foregroundColor(HexTheme.mute)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Grid

    private var gridView: some View {
        let cells = buildMonthGrid(year: viewYear, month: viewMonth)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
                        spacing: 3) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                if let d = date {
                    dayCell(date: d)
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func dayCell(date: Date) -> some View {
        let bucket = dayBucket(date: date)
        let style = bucketStyle(bucket)
        let isToday = Calendar.current.isDateInToday(date)
        let day = Calendar.current.component(.day, from: date)
        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(style.bg)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(style.border, lineWidth: 1)
            if isToday {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(HexTheme.accent, lineWidth: 2)
                    .padding(-2)
            }
            Text("\(day)")
                .font(.system(size: 11, weight: isToday ? .black : .semibold))
                .foregroundColor(isToday ? HexTheme.accent : style.fg)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private enum DayBucket { case logged, missed, scheduled, rest }

    private func dayBucket(date: Date) -> DayBucket {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let d = cal.startOfDay(for: date)
        let comps = cal.dateComponents([.year, .month, .day], from: d)
        let isLogged = loggedDates.contains(comps)
        let weekday  = cal.component(.weekday, from: d) - 1   // 0=Sun..6=Sat
        let isTrain  = trainingDayIndices.contains(weekday)
        if isLogged { return .logged }
        if d < today, isTrain { return .missed }
        if d > today, isTrain { return .scheduled }
        return .rest
    }

    private struct CellStyle { let bg: Color; let border: Color; let fg: Color }
    private func bucketStyle(_ b: DayBucket) -> CellStyle {
        switch b {
        case .logged:
            return .init(bg: Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.25),
                         border: Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.50),
                         fg: Color(red: 0.29, green: 0.87, blue: 0.50))
        case .missed:
            return .init(bg: Color(red: 1.0, green: 0.24, blue: 0.24).opacity(0.20),
                         border: Color(red: 1.0, green: 0.24, blue: 0.24).opacity(0.40),
                         fg: Color(red: 1.0, green: 0.39, blue: 0.39))
        case .scheduled:
            return .init(bg: HexTheme.accent.opacity(0.07),
                         border: HexTheme.accent.opacity(0.18),
                         fg: HexTheme.dim)
        case .rest:
            return .init(bg: .clear, border: .clear, fg: HexTheme.mute)
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 14) {
            legendChip(color: Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.35),
                       label: ar ? "تم التسجيل" : "Session logged")
            legendChip(color: Color(red: 1.0, green: 0.24, blue: 0.24).opacity(0.28),
                       label: ar ? "تمرين فائت" : "Missed training")
            legendChip(color: HexTheme.accent.opacity(0.14),
                       label: ar ? "جلسة قادمة" : "Upcoming")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 11, height: 11)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(HexTheme.dim)
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        let monthCount = monthLogCount()
        let passed = passedTrainingDayCount()
        let pct = passed > 0 ? Int(round(Double(monthCount) / Double(passed) * 100)) : nil

        return VStack(spacing: 0) {
            Text((ar ? "\(monthName(viewMonth)) — إحصائيات" : "\(monthName(viewMonth).uppercased()) STATS"))
                .font(.system(size: 10, weight: .heavy))
                .kerning(ar ? 0 : 1.2)
                .foregroundColor(HexTheme.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            HStack(spacing: 0) {
                stat(value: "\(monthCount)",
                     label: ar ? "جلسات" : "SESSIONS",
                     trailing: true)
                stat(value: "\(passed)",
                     label: ar ? "أيام تدريب" : "TRAINING DAYS",
                     trailing: true)
                stat(value: pct.map { "\($0)%" } ?? "—",
                     label: ar ? "نسبة الإنجاز" : "COMPLETION",
                     trailing: false)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    private func stat(value: String, label: String, trailing: Bool) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(HexTheme.text)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .kerning(ar ? 0 : 0.5)
                .foregroundColor(HexTheme.mute)
        }
        .frame(maxWidth: .infinity)
        .overlay(
            trailing
            ? Rectangle().fill(HexTheme.border)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity, alignment: .trailing)
            : nil
        )
    }

    private func monthLogCount() -> Int {
        // TODO: count sessions from app history whose date falls in viewMonth/viewYear
        0
    }

    private func passedTrainingDayCount() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let range = cal.range(of: .day, in: .month,
                                    for: DateComponents(calendar: cal,
                                                        year: viewYear,
                                                        month: viewMonth + 1).date ?? today)
        else { return 0 }
        var count = 0
        for d in range {
            if let date = cal.date(from: DateComponents(year: viewYear,
                                                        month: viewMonth + 1,
                                                        day: d)) {
                let startOfDay = cal.startOfDay(for: date)
                if startOfDay > today { continue }
                let weekday = cal.component(.weekday, from: startOfDay) - 1
                if trainingDayIndices.contains(weekday) { count += 1 }
            }
        }
        return count
    }

    // MARK: - Helpers

    private func monthName(_ index: Int) -> String {
        let en = ["January","February","March","April","May","June",
                  "July","August","September","October","November","December"]
        let arNames = ["يناير","فبراير","مارس","أبريل","مايو","يونيو",
                       "يوليو","أغسطس","سبتمبر","أكتوبر","نوفمبر","ديسمبر"]
        let names = ar ? arNames : en
        return names[max(0, min(11, index))]
    }

    /// Build a Mon-first 7-column grid. Leading/trailing nils are blank cells.
    private func buildMonthGrid(year: Int, month: Int) -> [Date?] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2  // Monday
        guard let firstOfMonth = cal.date(from: DateComponents(year: year, month: month + 1, day: 1)),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth)
        else { return [] }

        // 0 = Mon … 6 = Sun (offset from JS getDay)
        let weekdaySun1 = cal.component(.weekday, from: firstOfMonth)   // 1=Sun..7=Sat
        let weekdayMon0 = ((weekdaySun1 + 5) % 7)
        var cells: [Date?] = Array(repeating: nil, count: weekdayMon0)
        for day in range {
            if let d = cal.date(from: DateComponents(year: year, month: month + 1, day: day)) {
                cells.append(d)
            }
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}
