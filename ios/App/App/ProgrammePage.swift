import SwiftUI

/// Full-screen programme view — port of src/components/ProgrammePage.jsx.
/// Distinct from ProgrammeModalView (the sheet summary): this one is the
/// editor surface — top bar with edits-count pill, weekly schedule grid
/// (auto mode) or week tabs + day overview (imported mode), and
/// expandable session cards with per-exercise rows.
///
/// This is the visual port; per-field inline editing + exercise swap
/// will be wired in a follow-up commit (along with ExercisePickerSheet).
struct ProgrammePage: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    /// Programme-day expansion state, keyed by `weekNumber_day` (auto uses
    /// week 1 always; imported uses the selected week's day).
    @State private var expanded: Set<String> = []
    /// Selected week tab in imported mode (defaults to week 1).
    @State private var importedTab: Int = 1
    /// Set when the user taps an exercise's swap chevron. Drives the
    /// ExercisePickerSheet via .sheet(item:).
    @State private var swapContext: SwapContext?

    /// Identifies a single exercise slot in the active programme so the
    /// picker callback knows where to write the replacement.
    private struct SwapContext: Identifiable {
        let id = UUID()
        let weekIdx: Int
        let sessionIdx: Int
        let exerciseIdx: Int
        let currentName: String
    }

    private var ar: Bool { app.language == "ar" }

    private var programmeData: ProgrammeData? {
        app.activeProgramme?.data
    }
    private var isImported: Bool {
        (programmeData?.weeks.count ?? 0) > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let data = programmeData, !data.weeks.isEmpty {
                        if isImported {
                            importedContent(data: data)
                        } else {
                            autoContent(week: data.weeks.first!)
                        }
                    } else {
                        emptyState
                    }
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $swapContext) { ctx in
            ExercisePickerSheet(currentName: ctx.currentName) { picked in
                Task {
                    await app.swapExercise(
                        weekIdx: ctx.weekIdx,
                        sessionIdx: ctx.sessionIdx,
                        exerciseIdx: ctx.exerciseIdx,
                        replacement: picked
                    )
                }
            }
            .environmentObject(app)
            .presentationDetents([.fraction(0.82), .large])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: ar ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(HexTheme.text)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(isImported
                     ? (ar ? "برنامج مستورد" : "IMPORTED PROGRAMME")
                     : (ar ? "برنامجك" : "YOUR PROGRAMME"))
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(ar ? 0 : 0.9)
                    .foregroundColor(HexTheme.accent)
                Text(programmeData?.name ?? (ar ? "تلقائي" : "Auto-generated"))
                    .font(.system(size: 16, weight: .heavy))
                    .kerning(ar ? 0 : -0.4)
                    .foregroundColor(HexTheme.text)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(HexTheme.surface)
        .overlay(
            Rectangle().fill(HexTheme.border).frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundColor(HexTheme.mute)
            Text(ar ? "لا يوجد برنامج بعد" : "No programme yet")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(HexTheme.text)
            Text(ar
                 ? "ابنِ برنامجك أو استورد واحداً من شاشة الحساب."
                 : "Build a programme or import one from the Profile tab.")
                .font(.system(size: 13))
                .foregroundColor(HexTheme.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Auto mode

    @ViewBuilder
    private func autoContent(week: ProgrammeWeek) -> some View {
        let dayLetters = ar
            ? ["إ","ث","أ","خ","ج","س","ح"]
            : ["M","T","W","T","F","S","S"]

        // Schedule grid
        VStack(alignment: .leading, spacing: 10) {
            Text(ar ? "الجدول" : "SCHEDULE")
                .font(.system(size: 11, weight: .heavy))
                .kerning(ar ? 0 : 0.6)
                .foregroundColor(HexTheme.dim)

            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let s = i < week.sessions.count ? week.sessions[i] : nil
                    let isTraining = s != nil
                    VStack(spacing: 4) {
                        Text(dayLetters[i])
                            .font(.system(size: 9))
                            .foregroundColor(HexTheme.mute)
                        Text(isTraining
                             ? String(s?.name.prefix(1) ?? "T")
                             : "—")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(isTraining ? HexTheme.accent : HexTheme.mute)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isTraining
                                          ? HexTheme.accent.opacity(0.12)
                                          : HexTheme.surface2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(isTraining
                                            ? HexTheme.accent.opacity(0.25)
                                            : HexTheme.border, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(.bottom, 20)

        Text(ar
             ? "كل الجلسات — اضغط للتوسيع"
             : "ALL SESSIONS — TAP TO EXPAND & EDIT")
            .font(.system(size: 11, weight: .heavy))
            .kerning(ar ? 0 : 0.6)
            .foregroundColor(HexTheme.dim)
            .padding(.bottom, 12)

        VStack(spacing: 10) {
            ForEach(Array(week.sessions.enumerated()), id: \.offset) { idx, session in
                sessionCard(session: session,
                            keyPrefix: "auto_\(idx)",
                            isToday: session.name == app.currentSession?.name,
                            weekIdx: 0,
                            sessionIdx: idx)
            }
        }

        Text(ar
             ? "يدور البرنامج تلقائياً. تُحفظ التعديلات فوراً وتستمر بين الجلسات."
             : "Programme cycles automatically. Edits are saved instantly and persist across sessions.")
            .font(.system(size: 11))
            .foregroundColor(HexTheme.mute)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    // MARK: - Imported mode

    @ViewBuilder
    private func importedContent(data: ProgrammeData) -> some View {
        let weeks = data.weeks
        let activeWeek = weeks.first(where: { $0.weekNumber == importedTab }) ?? weeks.first!

        // Week tab strip
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(weeks, id: \.weekNumber) { w in
                    let active = w.weekNumber == importedTab
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            importedTab = w.weekNumber
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(ar ? "أ\(arabicNumber(w.weekNumber))" : "W\(w.weekNumber)")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(active ? .black : HexTheme.dim)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(active ? HexTheme.accent : HexTheme.surface2)
                        )
                        .overlay(
                            Capsule().stroke(active ? HexTheme.accent : HexTheme.border,
                                             lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.bottom, 10)

        // Day overview
        Text((ar ? "الأسبوع " : "Week ") + "\(importedTab) — " +
             (ar ? "نظرة اليوم" : "DAY OVERVIEW"))
            .font(.system(size: 11, weight: .heavy))
            .kerning(ar ? 0 : 0.6)
            .foregroundColor(HexTheme.dim)
            .padding(.bottom, 6)

        VStack(spacing: 0) {
            ForEach(["mon","tue","wed","thu","fri","sat","sun"], id: \.self) { dayKey in
                let s = activeWeek.sessions.first(where: { $0.day == dayKey })
                let isRest = s == nil
                HStack(spacing: 10) {
                    Text(dayLabel(dayKey))
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(isRest ? HexTheme.mute : HexTheme.accent)
                        .frame(width: 50, alignment: .leading)
                    if let s = s {
                        Text(s.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(HexTheme.text)
                        Spacer()
                    } else {
                        Text(ar ? "راحة" : "Rest")
                            .font(.system(size: 13))
                            .foregroundColor(HexTheme.mute)
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
                .overlay(
                    Rectangle().fill(HexTheme.border).frame(height: 1),
                    alignment: .bottom
                )
            }
        }
        .padding(.bottom, 16)

        // Session detail cards
        Text((ar ? "الجلسات — الأسبوع " : "SESSIONS — Week ") + "\(importedTab)")
            .font(.system(size: 11, weight: .heavy))
            .kerning(ar ? 0 : 0.6)
            .foregroundColor(HexTheme.dim)
            .padding(.bottom, 10)

        let activeWeekIdx = weeks.firstIndex(where: { $0.weekNumber == activeWeek.weekNumber }) ?? 0
        VStack(spacing: 10) {
            ForEach(Array(activeWeek.sessions.enumerated()), id: \.offset) { idx, session in
                sessionCard(session: session,
                            keyPrefix: "imp_w\(activeWeek.weekNumber)_\(session.day)",
                            isToday: session.name == app.currentSession?.name,
                            weekIdx: activeWeekIdx,
                            sessionIdx: idx)
            }
        }

        Text(ar
             ? "تُحفظ التعديلات فوراً، والذكاء الاصطناعي يقرأ برنامجك الحالي — لا الاستيراد الأصلي."
             : "Edits save instantly and the AI reads your current programme — not the original import.")
            .font(.system(size: 11))
            .foregroundColor(HexTheme.mute)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
    }

    private func dayLabel(_ key: String) -> String {
        switch key {
        case "mon": return ar ? "اثنين"  : "Mon"
        case "tue": return ar ? "ثلاثاء"  : "Tue"
        case "wed": return ar ? "أربعاء"  : "Wed"
        case "thu": return ar ? "خميس"   : "Thu"
        case "fri": return ar ? "جمعة"    : "Fri"
        case "sat": return ar ? "سبت"     : "Sat"
        case "sun": return ar ? "أحد"     : "Sun"
        default:    return key
        }
    }

    // MARK: - Session card

    private func sessionCard(session: ProgrammeSession,
                             keyPrefix: String,
                             isToday: Bool,
                             weekIdx: Int,
                             sessionIdx: Int) -> some View {
        let isExpanded = expanded.contains(keyPrefix) || isToday
        return VStack(spacing: 0) {
            // Header (tap to expand/collapse)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if expanded.contains(keyPrefix) {
                        expanded.remove(keyPrefix)
                    } else {
                        expanded.insert(keyPrefix)
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Text(String(session.name.prefix(1)))
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(isToday ? .black : HexTheme.dim)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isToday ? HexTheme.accent : HexTheme.surface)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(HexTheme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        Text(sessionSubtitle(session: session))
                            .font(.system(size: 11))
                            .foregroundColor(HexTheme.mute)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(HexTheme.mute)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)

            // Exercises (when expanded)
            if isExpanded {
                Divider().background(HexTheme.border)
                VStack(spacing: 0) {
                    Text(ar
                         ? "اضغط على أي حقل للتعديل"
                         : "TAP ANY FIELD TO EDIT")
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(ar ? 0 : 0.5)
                        .foregroundColor(HexTheme.mute)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    ForEach(Array(session.exercises.enumerated()), id: \.offset) { exIdx, ex in
                        exerciseRow(ex,
                                    weekIdx: weekIdx,
                                    sessionIdx: sessionIdx,
                                    exerciseIdx: exIdx)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isToday ? HexTheme.accent : HexTheme.border, lineWidth: 1.5)
        )
    }

    private func sessionSubtitle(session: ProgrammeSession) -> String {
        let n = session.exercises.count
        let minutes = n * 6
        if ar {
            return "\(n) تمارين · ~\(minutes) د"
        }
        return "\(n) exercises · ~\(minutes) min"
    }

    // MARK: - Exercise row

    private func exerciseRow(_ ex: Exercise,
                             weekIdx: Int,
                             sessionIdx: Int,
                             exerciseIdx: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Name row — tapping anywhere on it opens the swap picker.
            Button {
                swapContext = SwapContext(
                    weekIdx: weekIdx,
                    sessionIdx: sessionIdx,
                    exerciseIdx: exerciseIdx,
                    currentName: ex.name
                )
            } label: {
                HStack(spacing: 6) {
                    if let tag = ex.tag {
                        Text(tag.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(tag == "compound" ? HexTheme.accent : HexTheme.mute)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(HexTheme.surface)
                            )
                    }
                    Text(ex.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                        .lineLimit(1)
                        .underlineDashed()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(HexTheme.mute)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Sets · Reps · Weight · RPE
            HStack(spacing: 14) {
                stat(label: ar ? "مج" : "Sets",
                     value: "\(ex.sets)", accent: false)
                stat(label: ar ? "عد" : "Reps",
                     value: ex.reps, accent: false)
                if let w = ex.weight, w > 0 {
                    stat(label: ar ? "وزن" : "Weight",
                         value: formatWeight(w),
                         suffix: "kg",
                         accent: true)
                } else if ex.weight == nil {
                    stat(label: ar ? "وزن" : "Weight",
                         value: "BW",
                         accent: true)
                }
                if let rpe = ex.rpe, !rpe.isEmpty {
                    stat(label: "RPE", value: rpe, accent: false, dim: true)
                }
                Spacer()
            }

            // Notes
            if let notes = ex.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 11))
                    .foregroundColor(HexTheme.mute)
                    .italic()
            } else {
                Text(ar ? "أضف ملاحظات…" : "Add notes…")
                    .font(.system(size: 11))
                    .foregroundColor(HexTheme.mute)
                    .italic()
                    .underlineDashed()
            }

            // Rest timer presets
            VStack(alignment: .leading, spacing: 7) {
                Text(ar ? "مؤقت الراحة" : "REST TIMER")
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(ar ? 0 : 0.7)
                    .foregroundColor(HexTheme.mute)
                HStack(spacing: 5) {
                    ForEach(["30s","60s","90s","2m","Custom"], id: \.self) { preset in
                        Text(preset)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(HexTheme.dim)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(HexTheme.surface))
                            .overlay(
                                Capsule().stroke(HexTheme.border, lineWidth: 1.5)
                            )
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 10)
        .overlay(
            Rectangle().fill(HexTheme.border).frame(height: 1),
            alignment: .bottom
        )
    }

    private func stat(label: String, value: String,
                      suffix: String? = nil, accent: Bool, dim: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(HexTheme.mute)
            Text(value)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(accent ? HexTheme.accent : (dim ? HexTheme.dim : HexTheme.text))
                .underlineDashed()
            if let suffix = suffix {
                Text(suffix)
                    .font(.system(size: 11))
                    .foregroundColor(HexTheme.dim)
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(w))
            : String(format: "%.1f", w)
    }

    private func arabicNumber(_ n: Int) -> String {
        // ASCII digit → Eastern Arabic numeral
        let map: [Character: Character] = [
            "0":"٠","1":"١","2":"٢","3":"٣","4":"٤",
            "5":"٥","6":"٦","7":"٧","8":"٨","9":"٩",
        ]
        return String(String(n).map { map[$0] ?? $0 })
    }
}

// MARK: - Dashed underline modifier

/// Renders a subtle dashed underline beneath any view — matches the React
/// "tap to edit" affordance. Visual only; the page is read-only for now.
private struct DashedUnderline: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.top, 1),
                alignment: .bottom
            )
    }
}
private extension View {
    func underlineDashed() -> some View { modifier(DashedUnderline()) }
}
