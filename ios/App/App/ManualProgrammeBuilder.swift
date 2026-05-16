import SwiftUI

/// 6-step wizard for building a programme by hand — port of
/// `src/components/ManualProgrammeBuilder.jsx`.
/// Output is fed to `AppState.enterAppWithImport(_:)` (same data path as
/// imported programmes), so the wizard produces a `[String: Any]` payload
/// matching the imported-programme JSON shape.
struct ManualProgrammeBuilder: View {

    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    // MARK: - Constants (mirror the JS arrays)

    fileprivate struct DayDef: Identifiable {
        let key: String
        let label: String
        let full: String
        var id: String { key }
    }
    fileprivate static let DAYS: [DayDef] = [
        .init(key: "mon", label: "Mon", full: "Monday"),
        .init(key: "tue", label: "Tue", full: "Tuesday"),
        .init(key: "wed", label: "Wed", full: "Wednesday"),
        .init(key: "thu", label: "Thu", full: "Thursday"),
        .init(key: "fri", label: "Fri", full: "Friday"),
        .init(key: "sat", label: "Sat", full: "Saturday"),
        .init(key: "sun", label: "Sun", full: "Sunday"),
    ]

    fileprivate struct GoalDef: Identifiable {
        let key: String
        let label: String
        let icon: String
        var id: String { key }
    }
    fileprivate static let GOALS: [GoalDef] = [
        .init(key: "muscle",   label: "Build muscle",        icon: "💪"),
        .init(key: "strength", label: "Get stronger",        icon: "🏋️"),
        .init(key: "fat",      label: "Lose fat",            icon: "🔥"),
        .init(key: "athletic", label: "Athletic performance", icon: "⚡"),
    ]

    fileprivate struct SplitDef: Identifiable {
        let key: String
        let label: String
        let description: String
        let names: [String: String]
        var id: String { key }
    }
    fileprivate static let SPLITS: [SplitDef] = [
        .init(key: "ppl", label: "Push / Pull / Legs",
              description: "Classic 6-day split for muscle building",
              names: ["mon": "Push", "tue": "Pull", "wed": "Legs",
                      "thu": "Push", "fri": "Pull", "sat": "Legs", "sun": "Push"]),
        .init(key: "upper_lower", label: "Upper / Lower",
              description: "4-day split, great for strength",
              names: ["mon": "Upper", "tue": "Lower", "wed": "Upper",
                      "thu": "Lower", "fri": "Upper", "sat": "Lower", "sun": "Upper"]),
        .init(key: "full_body", label: "Full Body",
              description: "Each session hits every muscle group",
              names: ["mon": "Full Body", "tue": "Full Body", "wed": "Full Body",
                      "thu": "Full Body", "fri": "Full Body", "sat": "Full Body",
                      "sun": "Full Body"]),
        .init(key: "body_part", label: "Body Part Split",
              description: "Dedicated day per muscle group",
              names: ["mon": "Chest", "tue": "Back", "wed": "Legs",
                      "thu": "Shoulders", "fri": "Arms", "sat": "Core",
                      "sun": "Chest"]),
        .init(key: "custom", label: "Custom",
              description: "Name each session yourself",
              names: [:]),
    ]

    fileprivate struct DurationDef: Identifiable {
        let value: Int
        let label: String
        let description: String?
        var id: Int { value }
    }
    fileprivate static let DURATIONS: [DurationDef] = [
        .init(value: 4,  label: "4 weeks",  description: nil),
        .init(value: 8,  label: "8 weeks",  description: nil),
        .init(value: 12, label: "12 weeks", description: nil),
        .init(value: 0,  label: "Ongoing",  description: "Repeating weekly schedule, no fixed end"),
    ]

    fileprivate struct StepMeta {
        let title: String
        let subtitle: String
    }
    fileprivate static let STEP_META: [StepMeta] = [
        .init(title: "Programme basics", subtitle: "Name your programme and set your goal"),
        .init(title: "Training days",    subtitle: "Which days will you train?"),
        .init(title: "Session split",    subtitle: "How will you structure your sessions?"),
        .init(title: "Add exercises",    subtitle: "Build each session — you can always edit later"),
        .init(title: "Duration",         subtitle: "How long is the programme?"),
        .init(title: "Review & save",    subtitle: "Everything look good?"),
    ]
    fileprivate static let STEP_COUNT = 6

    // MARK: - In-flight exercise (per-day list)

    /// Mutable per-day exercise snapshot used inside Step 4. Maps to one
    /// entry in `sessionExercises[day]` from the React state.
    struct DraftExercise: Identifiable, Hashable {
        let id = UUID()
        var name: String
        var key: String?
        var sets: Int = 3
        var reps: String = "8-10"
        var weight: Double? = nil
        var rpe: String? = nil
        var tag: String? = nil
        var bodyweight: Bool = false
    }

    // MARK: - State

    @State private var step: Int = 0

    // Step 1
    @State private var progName: String = ""
    @State private var goal: String = "muscle"

    // Step 2
    @State private var selectedDays: [String] = ["mon", "tue", "wed", "thu", "fri"]

    // Step 3
    @State private var split: String? = nil
    @State private var sessionNames: [String: String] = [:]

    // Step 4
    @State private var sessionExercises: [String: [DraftExercise]] = [:]

    // Step 5
    @State private var duration: Int = 8
    @State private var useBlocks: Bool = false
    @State private var blockLabels: [String] = ["Block 1", "Block 2"]

    // Step 6 (save state)
    @State private var saving: Bool = false

    private var canProceed: Bool {
        switch step {
        case 0: return !progName.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return selectedDays.count >= 1
        case 2:
            guard split != nil else { return false }
            return selectedDays.allSatisfy { (sessionNames[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty == false }
        default: return true
        }
    }

    private var isLast: Bool { step == Self.STEP_COUNT - 1 }
    private var ar: Bool { app.language == "ar" }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            // Scrollable content
            ScrollView {
                Group {
                    switch step {
                    case 0: Step1(progName: $progName, goal: $goal)
                    case 1: Step2(selectedDays: $selectedDays)
                    case 2: Step3(split: $split,
                                  selectedDays: selectedDays,
                                  sessionNames: $sessionNames)
                    case 3: Step4(selectedDays: selectedDays,
                                  sessionNames: sessionNames,
                                  sessionExercises: $sessionExercises)
                    case 4: Step5(duration: $duration,
                                  useBlocks: $useBlocks,
                                  blockLabels: $blockLabels)
                    default: Step6(progName: progName, goal: goal,
                                   selectedDays: selectedDays,
                                   sessionNames: sessionNames,
                                   sessionExercises: sessionExercises,
                                   duration: duration,
                                   useBlocks: useBlocks,
                                   blockLabels: blockLabels,
                                   onEditStep: { step = $0 })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            bottomCTA
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Button { handleBack() } label: {
                    Image(systemName: ar ? "chevron.right" : "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(HexTheme.surface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(HexTheme.border, lineWidth: 1)
                        )
                }

                GeometryReader { geo in
                    let pct = CGFloat(step + 1) / CGFloat(Self.STEP_COUNT)
                    ZStack(alignment: .leading) {
                        Capsule().fill(HexTheme.surface2)
                        Capsule().fill(HexTheme.accentFill)
                            .frame(width: geo.size.width * pct)
                    }
                }
                .frame(height: 3)

                Text("\(step + 1)/\(Self.STEP_COUNT)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(HexTheme.dim)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(Self.STEP_META[step].title)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                Text(Self.STEP_META[step].subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(HexTheme.dim)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 14)
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 0) {
            Divider().background(HexTheme.border)
            Button {
                if isLast { Task { await handleSave() } }
                else { step = min(step + 1, Self.STEP_COUNT - 1) }
            } label: {
                HStack {
                    if saving {
                        ProgressView().tint(.black)
                    } else {
                        Text(isLast
                             ? (ar ? "احفظ البرنامج" : "Save programme")
                             : (ar ? "متابعة ←" : "Continue →"))
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor((canProceed && !saving) ? .black : HexTheme.mute)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill((canProceed && !saving) ? HexTheme.accent : HexTheme.surface2)
                )
            }
            .disabled(!canProceed || saving)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(HexTheme.bg)
    }

    // MARK: - Navigation handlers

    private func handleBack() {
        if step == 0 { dismiss() }
        else { step -= 1 }
    }

    @MainActor
    private func handleSave() async {
        saving = true
        let output = Self.buildOutput(
            progName: progName, goal: goal,
            selectedDays: selectedDays,
            sessionNames: sessionNames,
            sessionExercises: sessionExercises,
            duration: duration,
            useBlocks: useBlocks,
            blockLabels: blockLabels)
        await app.enterAppWithImport(output)
        // Pop back to the calling screen (AccountView Programme list).
        // The active programme is now live and an edit-programme row will
        // appear there.
        saving = false
        dismiss()
    }

    // MARK: - Output builder (mirror buildOutput in the JS)

    /// Produces a payload identical in shape to what `enterAppWithImport`
    /// expects (matches src/lib/importHelpers.js — the React app already
    /// validates with `validateImported`).
    fileprivate static func buildOutput(
        progName: String,
        goal: String,
        selectedDays: [String],
        sessionNames: [String: String],
        sessionExercises: [String: [DraftExercise]],
        duration: Int,
        useBlocks: Bool,
        blockLabels: [String]
    ) -> [String: Any] {
        let weekCount = duration == 0 ? 1 : duration
        let blocksCount = (useBlocks && duration != 0) ? blockLabels.count : 0
        let weeksPerBlock: Int = blocksCount > 0
            ? Int(ceil(Double(weekCount) / Double(blocksCount)))
            : weekCount

        var weeks: [[String: Any]] = []
        weeks.reserveCapacity(weekCount)
        for wi in 0..<weekCount {
            let weekNumber = wi + 1
            let blockIdx   = weeksPerBlock > 0 ? wi / weeksPerBlock : 0
            let block: String? = (blocksCount > 0)
                ? blockLabels[min(blockIdx, blocksCount - 1)]
                : nil

            // All 7 days: selected -> session, unselected -> rest
            var sessions: [[String: Any]] = []
            sessions.reserveCapacity(7)
            for d in DAYS {
                if !selectedDays.contains(d.key) {
                    sessions.append(["day": d.key, "isRest": true])
                    continue
                }
                let sessionName = sessionNames[d.key] ?? d.label
                let drafts = sessionExercises[d.key] ?? []
                let exerciseDicts: [[String: Any]] = drafts.map { ex in
                    var dict: [String: Any] = [
                        "name":       ex.name,
                        "key":        ex.key as Any? ?? NSNull(),
                        "sets":       ex.sets,
                        "reps":       ex.reps.isEmpty ? "8-10" : ex.reps,
                        "weight":     ex.weight as Any? ?? NSNull(),
                        "rpe":        ex.rpe as Any? ?? NSNull(),
                        "tag":        ex.tag as Any? ?? NSNull(),
                        "bodyweight": ex.bodyweight,
                    ]
                    // Strip explicit NSNulls so the payload matches the
                    // React shape (keys with null are fine but tag often
                    // doesn't appear at all when unused).
                    if ex.tag == nil  { dict["tag"]    = NSNull() }
                    if ex.key == nil  { dict["key"]    = NSNull() }
                    if ex.rpe == nil  { dict["rpe"]    = NSNull() }
                    if ex.weight == nil { dict["weight"] = NSNull() }
                    return dict
                }
                sessions.append([
                    "day":       d.key,
                    "name":      sessionName,
                    "exercises": exerciseDicts,
                ])
            }

            var week: [String: Any] = ["weekNumber": weekNumber, "sessions": sessions]
            if let block = block { week["block"] = block }
            weeks.append(week)
        }

        return [
            "name":  progName,
            "goal":  goal,
            "weeks": weeks,
        ]
    }
}

// MARK: - Shared step primitives

private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .kerning(0.66)
            .foregroundColor(HexTheme.dim)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Inline-styled rectangular text input matching `inputStyle` in the JS.
private struct ManualInput: View {
    @Binding var text: String
    var placeholder: String
    var maxLength: Int? = nil
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 15))
            .foregroundColor(HexTheme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .focused($focused)
            .onChange(of: text) { newValue in
                if let max = maxLength, newValue.count > max {
                    text = String(newValue.prefix(max))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(focused ? HexTheme.accent : HexTheme.border, lineWidth: 1.5)
            )
    }
}

/// Tall pill-shaped selectable row used by Step 1, 3, 5 — ChoiceButton in JS.
private struct ChoiceButton<Trailing: View>: View {
    let title: String
    let description: String?
    let active: Bool
    let action: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    init(title: String,
         description: String? = nil,
         active: Bool,
         action: @escaping () -> Void,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.description = description
        self.active = active
        self.action = action
        self.trailing = trailing
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                trailing()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(active ? HexTheme.accent : HexTheme.text)
                    if let description = description {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(HexTheme.dim)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if active {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(HexTheme.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? HexTheme.accent.opacity(0.09) : HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(active ? HexTheme.accent : HexTheme.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 1 — Name + Goal

private struct Step1: View {
    @Binding var progName: String
    @Binding var goal: String

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "PROGRAMME NAME")
                ManualInput(text: $progName,
                            placeholder: "e.g. Summer Strength Block",
                            maxLength: 60)
            }

            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "PRIMARY GOAL")
                VStack(spacing: 8) {
                    ForEach(ManualProgrammeBuilder.GOALS) { g in
                        ChoiceButton(
                            title: g.label,
                            description: nil,
                            active: goal == g.key,
                            action: { goal = g.key }
                        ) {
                            Text(g.icon).font(.system(size: 18))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Step 2 — Training days

private struct Step2: View {
    @Binding var selectedDays: [String]

    private func toggle(_ key: String) {
        if selectedDays.contains(key) {
            // Don't allow zero days
            if selectedDays.count > 1 {
                selectedDays.removeAll { $0 == key }
            }
        } else {
            // Preserve canonical DAYS order
            let all = ManualProgrammeBuilder.DAYS.map(\.key)
            selectedDays = all.filter { selectedDays.contains($0) || $0 == key }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("\(selectedDays.count) training \(selectedDays.count == 1 ? "day" : "days") per week selected")
                .font(.system(size: 13))
                .foregroundColor(HexTheme.dim)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(ManualProgrammeBuilder.DAYS) { d in
                ChoiceButton(
                    title: d.full,
                    description: nil,
                    active: selectedDays.contains(d.key),
                    action: { toggle(d.key) }
                )
            }
        }
    }
}

// MARK: - Step 3 — Split + Session names

private struct Step3: View {
    @Binding var split: String?
    let selectedDays: [String]
    @Binding var sessionNames: [String: String]

    private func applySplit(_ key: String) {
        split = key
        if key == "custom" { return }
        guard let preset = ManualProgrammeBuilder.SPLITS.first(where: { $0.key == key })
        else { return }
        // assign in preset.values order (matches the JS Object.values)
        let presetValues = ManualProgrammeBuilder.DAYS.compactMap { preset.names[$0.key] }
        var updated: [String: String] = [:]
        for (i, dayKey) in selectedDays.enumerated() {
            let v = !presetValues.isEmpty
                ? presetValues[i % presetValues.count]
                : (ManualProgrammeBuilder.DAYS.first(where: { $0.key == dayKey })?.label ?? dayKey)
            updated[dayKey] = v
        }
        sessionNames = updated
    }

    private var allNamed: Bool {
        selectedDays.allSatisfy {
            (sessionNames[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty == false
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                ForEach(ManualProgrammeBuilder.SPLITS) { s in
                    ChoiceButton(
                        title: s.label,
                        description: s.description,
                        active: split == s.key,
                        action: { applySplit(s.key) }
                    )
                }
            }

            if split != nil {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: "SESSION NAMES")
                    VStack(spacing: 8) {
                        ForEach(selectedDays, id: \.self) { dayKey in
                            let dayInfo = ManualProgrammeBuilder.DAYS.first(where: { $0.key == dayKey })
                            HStack(spacing: 10) {
                                Text(dayInfo?.label ?? dayKey)
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundColor(HexTheme.dim)
                                    .frame(width: 34, alignment: .trailing)

                                ManualInput(
                                    text: Binding(
                                        get: { sessionNames[dayKey] ?? "" },
                                        set: { sessionNames[dayKey] = $0 }
                                    ),
                                    placeholder: dayInfo?.full ?? dayKey,
                                    maxLength: 40
                                )
                            }
                        }
                    }
                    if !allNamed {
                        Text(ar ? "أعطِ كل جلسة اسماً للمتابعة." : "Give each session a name to continue.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                            .padding(.top, 8)
                    }
                }
            }
        }
    }
}

// MARK: - Step 4 — Per-day exercises (uses ExercisePickerSheet)

private struct Step4: View {
    @EnvironmentObject var app: AppState
    let selectedDays: [String]
    let sessionNames: [String: String]
    @Binding var sessionExercises: [String: [ManualProgrammeBuilder.DraftExercise]]

    /// While `pickerDay` is non-nil, the picker sheet is presented.
    @State private var pickerDay: String? = nil
    /// After picking, we hold the choice here until the inline form is saved.
    @State private var pendingPick: (day: String, exercise: ProgrammeBuilder.LibraryExercise)? = nil
    /// While editing an existing row, `editingIndex` is set per-day.
    @State private var editingIndex: (day: String, idx: Int)? = nil

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        VStack(spacing: 16) {
            Text(ar
                 ? "أضف التمارين لكل جلسة. يمكنك تخطّي أي جلسة وإضافتها لاحقاً."
                 : "Add exercises to each session. You can skip any session and add them later.")
                .font(.system(size: 13))
                .foregroundColor(HexTheme.dim)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(selectedDays, id: \.self) { dayKey in
                dayCard(dayKey: dayKey)
            }
        }
        .sheet(isPresented: Binding(
            get: { pickerDay != nil },
            set: { if !$0 { pickerDay = nil } }
        )) {
            if let dayKey = pickerDay {
                ExercisePickerSheet(
                    currentName: nil,
                    onSelect: { lib in
                        pendingPick = (day: dayKey, exercise: lib)
                        pickerDay = nil
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func dayCard(dayKey: String) -> some View {
        let dayInfo = ManualProgrammeBuilder.DAYS.first(where: { $0.key == dayKey })
        let sessionName = sessionNames[dayKey] ?? dayInfo?.label ?? dayKey
        let exercises = sessionExercises[dayKey] ?? []
        let isPending = pendingPick?.day == dayKey

        VStack(spacing: 0) {
            // Day header
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text((dayInfo?.label ?? dayKey).uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(0.7)
                        .foregroundColor(HexTheme.dim)
                    Text(sessionName)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                }
                Spacer()
                Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(HexTheme.mute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(HexTheme.surface2)

            // Exercise rows
            ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, ex in
                let isEditing = editingIndex?.day == dayKey && editingIndex?.idx == idx
                Divider().background(HexTheme.border)
                if isEditing {
                    ExerciseFormRow(
                        exerciseName: ex.name,
                        initialSets: String(ex.sets),
                        initialReps: ex.reps,
                        initialWeight: ex.weight.map { trimWeight($0) } ?? "",
                        initialRpe: ex.rpe ?? "",
                        saveLabel: "Save changes",
                        cancelLabel: "Cancel",
                        onSave: { sets, reps, weight, rpe in
                            updateExercise(dayKey: dayKey, idx: idx,
                                           sets: sets, reps: reps,
                                           weight: weight, rpe: rpe)
                            editingIndex = nil
                        },
                        onCancel: { editingIndex = nil }
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                } else {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(HexTheme.text)
                            Text(exerciseSubtitle(ex))
                                .font(.system(size: 12))
                                .foregroundColor(HexTheme.dim)
                        }
                        Spacer()
                        Button {
                            editingIndex = (day: dayKey, idx: idx)
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 13))
                                .foregroundColor(HexTheme.dim)
                                .padding(6)
                        }
                        .buttonStyle(.plain)
                        Button {
                            deleteExercise(dayKey: dayKey, idx: idx)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                                .padding(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                }
            }

            // Pending inline form (after picker)
            if isPending, let pp = pendingPick {
                if !exercises.isEmpty {
                    Divider().background(HexTheme.border)
                }
                ExerciseFormRow(
                    exerciseName: pp.exercise.name,
                    initialSets: "3",
                    initialReps: "8-10",
                    initialWeight: "",
                    initialRpe: "",
                    saveLabel: "Add to session",
                    cancelLabel: "Cancel",
                    onSave: { sets, reps, weight, rpe in
                        appendExercise(
                            dayKey: pp.day, lib: pp.exercise,
                            sets: sets, reps: reps, weight: weight, rpe: rpe
                        )
                        pendingPick = nil
                    },
                    onCancel: { pendingPick = nil }
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            // Add-exercise button
            if !isPending {
                if !exercises.isEmpty || (editingIndex?.day == dayKey) {
                    Divider().background(HexTheme.border)
                }
                Button {
                    editingIndex = nil
                    pendingPick = nil
                    pickerDay = dayKey
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(HexTheme.accent)
                        Text(ar ? "إضافة تمرين" : "Add exercise")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(HexTheme.accent)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Mutation helpers

    private func appendExercise(
        dayKey: String,
        lib: ProgrammeBuilder.LibraryExercise,
        sets: Int, reps: String, weight: Double?, rpe: String?
    ) {
        var arr = sessionExercises[dayKey] ?? []
        arr.append(.init(
            name: lib.name,
            key: lib.key,
            sets: sets,
            reps: reps,
            weight: weight,
            rpe: rpe,
            bodyweight: lib.bodyweight
        ))
        sessionExercises[dayKey] = arr
    }

    private func updateExercise(
        dayKey: String, idx: Int,
        sets: Int, reps: String, weight: Double?, rpe: String?
    ) {
        guard var arr = sessionExercises[dayKey], arr.indices.contains(idx)
        else { return }
        arr[idx].sets   = sets
        arr[idx].reps   = reps
        arr[idx].weight = weight
        arr[idx].rpe    = rpe
        sessionExercises[dayKey] = arr
    }

    private func deleteExercise(dayKey: String, idx: Int) {
        guard var arr = sessionExercises[dayKey], arr.indices.contains(idx)
        else { return }
        arr.remove(at: idx)
        sessionExercises[dayKey] = arr
        if editingIndex?.day == dayKey && editingIndex?.idx == idx {
            editingIndex = nil
        }
    }

    // MARK: - Formatting helpers

    private func exerciseSubtitle(_ ex: ManualProgrammeBuilder.DraftExercise) -> String {
        var parts: [String] = ["\(ex.sets) × \(ex.reps)"]
        if let w = ex.weight { parts.append("\(trimWeight(w))kg") }
        if let r = ex.rpe, !r.isEmpty { parts.append("RPE \(r)") }
        return parts.joined(separator: " · ")
    }

    private func trimWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(w))
            : String(format: "%.1f", w)
    }
}

// MARK: - ExerciseFormRow (used twice in Step 4)

private struct ExerciseFormRow: View {
    let exerciseName: String
    let initialSets: String
    let initialReps: String
    let initialWeight: String
    let initialRpe: String
    let saveLabel: String
    let cancelLabel: String
    let onSave: (_ sets: Int, _ reps: String, _ weight: Double?, _ rpe: String?) -> Void
    let onCancel: () -> Void

    @State private var sets: String = ""
    @State private var reps: String = ""
    @State private var weight: String = ""
    @State private var rpe: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exerciseName)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(HexTheme.accent)

            HStack(spacing: 8) {
                miniField(label: "SETS", text: $sets, placeholder: "3", keyboard: .numberPad)
                miniField(label: "REPS", text: $reps, placeholder: "8-10", keyboard: .default)
                miniField(label: "KG",   text: $weight, placeholder: "—",  keyboard: .decimalPad)
                miniField(label: "RPE",  text: $rpe,   placeholder: "—",  keyboard: .decimalPad)
            }

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text(cancelLabel)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(HexTheme.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(HexTheme.surface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(HexTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    let parsedSets   = max(1, Int(sets.trimmingCharacters(in: .whitespaces)) ?? 3)
                    let parsedWeight: Double? = {
                        let t = weight.trimmingCharacters(in: .whitespaces)
                        return t.isEmpty ? nil : Double(t)
                    }()
                    let parsedRpe: String? = {
                        let t = rpe.trimmingCharacters(in: .whitespaces)
                        return t.isEmpty ? nil : t
                    }()
                    let parsedReps = reps.trimmingCharacters(in: .whitespaces).isEmpty
                        ? "8-10"
                        : reps.trimmingCharacters(in: .whitespaces)
                    onSave(parsedSets, parsedReps, parsedWeight, parsedRpe)
                } label: {
                    Text(saveLabel)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(HexTheme.accentFill)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .layoutPriority(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HexTheme.accent.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HexTheme.accent.opacity(0.30), lineWidth: 1.5)
        )
        .onAppear {
            sets   = initialSets
            reps   = initialReps
            weight = initialWeight
            rpe    = initialRpe
        }
    }

    @ViewBuilder
    private func miniField(
        label: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .kerning(0.55)
                .foregroundColor(HexTheme.dim)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.center)
                .font(.system(size: 14))
                .foregroundColor(HexTheme.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(HexTheme.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(HexTheme.border, lineWidth: 1.5)
                )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Step 5 — Duration + blocks

private struct Step5: View {
    @EnvironmentObject var app: AppState
    @Binding var duration: Int
    @Binding var useBlocks: Bool
    @Binding var blockLabels: [String]

    private var ar: Bool { app.language == "ar" }

    private func handleDurationChange(_ value: Int) {
        duration = value
        if value == 0 {
            blockLabels = ["Block 1"]
            useBlocks = false
        } else {
            let count = max(1, value / 4)
            blockLabels = (0..<count).map { "Block \($0 + 1)" }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "PROGRAMME DURATION")
                VStack(spacing: 8) {
                    ForEach(ManualProgrammeBuilder.DURATIONS) { d in
                        ChoiceButton(
                            title: d.label,
                            description: d.description,
                            active: duration == d.value,
                            action: { handleDurationChange(d.value) }
                        )
                    }
                }
            }

            if duration != 0 {
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ar ? "تقسيم البرنامج لمراحل" : "Block periodisation")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(HexTheme.text)
                            Text(ar ? "سمِّ كل مرحلة تدريبية مدتها 4 أسابيع" : "Name each 4-week training phase")
                                .font(.system(size: 12))
                                .foregroundColor(HexTheme.dim)
                        }
                        Spacer()
                        Toggle("", isOn: $useBlocks)
                            .labelsHidden()
                            .tint(HexTheme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1.5)
                    )

                    if useBlocks && !blockLabels.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(Array(blockLabels.enumerated()), id: \.offset) { i, _ in
                                HStack(spacing: 10) {
                                    Text((ar ? "أس " : "Wk ") + "\(i * 4 + 1)–\(min((i + 1) * 4, duration))")
                                        .font(.system(size: 11, weight: .heavy))
                                        .foregroundColor(HexTheme.dim)
                                        .frame(width: 56, alignment: .trailing)

                                    ManualInput(
                                        text: Binding(
                                            get: { i < blockLabels.count ? blockLabels[i] : "" },
                                            set: { newValue in
                                                guard i < blockLabels.count else { return }
                                                blockLabels[i] = newValue
                                            }
                                        ),
                                        placeholder: "Block \(i + 1)",
                                        maxLength: 40
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Step 6 — Review

private struct Step6: View {
    @EnvironmentObject var app: AppState
    let progName: String
    let goal: String
    let selectedDays: [String]
    let sessionNames: [String: String]
    let sessionExercises: [String: [ManualProgrammeBuilder.DraftExercise]]
    let duration: Int
    let useBlocks: Bool
    let blockLabels: [String]
    let onEditStep: (Int) -> Void

    private var ar: Bool { app.language == "ar" }

    private var goalLabel: String {
        ManualProgrammeBuilder.GOALS.first(where: { $0.key == goal })?.label ?? goal
    }
    private var durationLabel: String {
        ManualProgrammeBuilder.DURATIONS.first(where: { $0.value == duration })?.label ?? "—"
    }
    private var totalExercises: Int {
        selectedDays.reduce(0) { $0 + (sessionExercises[$1]?.count ?? 0) }
    }

    private struct SummaryRow {
        let label: String
        let value: String
        let step: Int
    }
    private var rows: [SummaryRow] {
        var r: [SummaryRow] = [
            .init(label: "Name",          value: progName,                       step: 0),
            .init(label: "Goal",          value: goalLabel,                      step: 0),
            .init(label: "Training days", value: "\(selectedDays.count) per week", step: 1),
            .init(label: "Duration",      value: durationLabel,                  step: 4),
            .init(label: "Exercises",     value: "\(totalExercises) total",      step: 3),
        ]
        if useBlocks && !blockLabels.isEmpty && duration != 0 {
            r.append(.init(label: "Blocks",
                           value: blockLabels.joined(separator: " → "),
                           step: 4))
        }
        return r
    }

    var body: some View {
        VStack(spacing: 16) {
            // Summary block
            VStack(spacing: 0) {
                HStack {
                    SectionLabel(text: "SUMMARY")
                        .padding(.bottom, 0)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(HexTheme.surface2)

                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    HStack {
                        Text(row.label)
                            .font(.system(size: 13))
                            .foregroundColor(HexTheme.dim)
                        Spacer()
                        Text(row.value)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(HexTheme.text)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 180, alignment: .trailing)
                        Button { onEditStep(row.step) } label: {
                            Text(ar ? "تعديل" : "Edit")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(HexTheme.accent)
                                .padding(.leading, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)

                    if idx < rows.count - 1 {
                        Divider().background(HexTheme.border)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Sessions breakdown
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "SESSIONS")
                ForEach(selectedDays, id: \.self) { dayKey in
                    let dayInfo = ManualProgrammeBuilder.DAYS.first(where: { $0.key == dayKey })
                    let sesName = sessionNames[dayKey] ?? dayInfo?.label ?? dayKey
                    let exCount = sessionExercises[dayKey]?.count ?? 0
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sesName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(HexTheme.text)
                            Text("\(dayInfo?.full ?? dayKey) · "
                                 + (ar ? "\(exCount) تمرين" : "\(exCount) exercise\(exCount == 1 ? "" : "s")"))
                                .font(.system(size: 12))
                                .foregroundColor(HexTheme.dim)
                        }
                        Spacer()
                        Button { onEditStep(3) } label: {
                            Text(ar ? "تعديل" : "Edit")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(HexTheme.accent)
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1)
                    )
                }
            }
        }
    }
}
