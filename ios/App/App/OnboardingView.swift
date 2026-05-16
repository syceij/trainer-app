import SwiftUI

// MARK: - Data model

/// Collected during onboarding — handed back via `onComplete` so the
/// caller (eventually post-signup routing in ContentView) can persist
/// it and generate the user's starter programme.
struct OnboardingProfile {
    var name: String = ""
    var age: String = ""
    var sex: String = "Male"           // Male | Female | Other
    var experience: String = ""        // beginner | intermediate | advanced
    var bodyweight: Double = 70
    var goal: String = ""              // muscle | stronger | fat | athletic
    var daysPerWeek: Int = 4           // 3 | 4 | 5
    var cardio: String = "none"        // none | light | moderate | heavy
    var equipment: String = ""         // full_gym | home_gym | dumbbells | bodyweight
    var sessionLength: Int = 60        // 45 | 60 | 90
    var weakPoints: Set<String> = []
    var injuries: String = ""
    var avoid: String = ""
    var startingWeights: [String: Double] = [
        "bench": 60, "squat": 80, "deadlift": 100, "ohp": 40, "row": 60,
    ]
}

// MARK: - Main flow

/// Multi-step build-a-programme wizard — port of src/components/Onboarding.jsx.
/// 7 steps with progress bar at top, sliding step content, and a Continue
/// CTA at the bottom. Final tap calls `onComplete(profile)`.
struct OnboardingView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    let onComplete: (OnboardingProfile) -> Void

    @State private var step: Int = 1
    @State private var slideDir: Int = 1   // +1 forward, -1 back (for transition)
    @State private var profile = OnboardingProfile()

    private let totalSteps = 7
    private var ar: Bool { app.language == "ar" }

    private var canContinue: Bool {
        switch step {
        case 1: return !profile.name.trimmingCharacters(in: .whitespaces).isEmpty
                    && !profile.age.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return !profile.experience.isEmpty
        case 3: return !profile.goal.isEmpty
        case 4: return !profile.equipment.isEmpty
        default: return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                stepContent
                    .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)
            continueButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Button { goBack() } label: {
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

                Text(ar ? "الخطوة \(step) / ٧" : "STEP \(step) / 7")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(ar ? 0 : 0.9)
                    .foregroundColor(HexTheme.dim)

                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i < step ? HexTheme.accent : HexTheme.surface2)
                        .frame(height: 3)
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Step content (with slide transition)

    @ViewBuilder
    private var stepContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch step {
            case 1: step1
            case 2: step2
            case 3: step3
            case 4: step4
            case 5: step5
            case 6: step6
            case 7: step7
            default: EmptyView()
            }
        }
        .id(step)
        .transition(
            .asymmetric(
                insertion: .move(edge: slideDir > 0
                                 ? (ar ? .leading : .trailing)
                                 : (ar ? .trailing : .leading))
                    .combined(with: .opacity),
                removal: .move(edge: slideDir > 0
                               ? (ar ? .trailing : .leading)
                               : (ar ? .leading : .trailing))
                    .combined(with: .opacity)
            )
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
    }

    // MARK: - Continue button

    private var continueButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if step == totalSteps {
                onComplete(profile)
                dismiss()
            } else {
                slideDir = 1
                withAnimation { step += 1 }
            }
        } label: {
            Text(continueLabel)
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(canContinue ? .black : HexTheme.mute)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(canContinue ? HexTheme.accent : HexTheme.surface2)
                )
                .shadow(color: canContinue ? HexTheme.accent.opacity(0.35) : .clear,
                        radius: 16, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
        .padding(.top, 8)
    }

    private var continueLabel: String {
        if step == totalSteps {
            return ar ? "ابنِ برنامجي ←" : "Build my programme →"
        }
        return ar ? "متابعة" : "Continue"
    }

    private func goBack() {
        if step == 1 {
            dismiss()
            return
        }
        slideDir = -1
        withAnimation { step -= 1 }
    }

    // MARK: - Step 1: Name / Age / Sex

    private var step1: some View {
        Group {
            stepHeading(ar ? "أخبرنا عنك" : "Tell us about you")

            field(label: ar ? "الاسم الأول" : "First Name") {
                hexInput(text: $profile.name,
                         placeholder: ar ? "مثال: أحمد" : "e.g. Alex")
            }

            field(label: ar ? "العمر" : "Age") {
                hexInput(text: $profile.age,
                         placeholder: ar ? "مثال: ٢٨" : "e.g. 28",
                         keyboard: .numberPad)
            }

            field(label: ar ? "الجنس" : "Sex") {
                segmented(value: $profile.sex,
                          options: ar
                          ? [("Male", "ذكر"), ("Female", "أنثى"), ("Other", "آخر")]
                          : [("Male", "Male"), ("Female", "Female"), ("Other", "Other")])
            }
        }
    }

    // MARK: - Step 2: Experience + Bodyweight

    private var step2: some View {
        Group {
            stepHeading(ar ? "مستوى الخبرة" : "Experience level")

            wideChoice(
                value: "beginner",
                title: ar ? "مبتدئ" : "Beginner",
                sub: ar ? "أقل من سنة من التدريب المنتظم"
                       : "Less than 1 year of consistent training",
                selected: profile.experience == "beginner",
                onSelect: { profile.experience = "beginner" }
            )
            wideChoice(
                value: "intermediate",
                title: ar ? "متوسط" : "Intermediate",
                sub: ar ? "١-٣ سنوات، مرتاح مع جميع التمارين الأساسية"
                       : "1–3 years, comfortable with all main lifts",
                selected: profile.experience == "intermediate",
                onSelect: { profile.experience = "intermediate" }
            )
            wideChoice(
                value: "advanced",
                title: ar ? "متقدم" : "Advanced",
                sub: ar ? "أكثر من ٣ سنوات، تقنية قوية وتحمل عالٍ"
                       : "3+ years, strong technique and high tolerance",
                selected: profile.experience == "advanced",
                onSelect: { profile.experience = "advanced" }
            )

            field(label: ar ? "وزن الجسم (كجم)" : "Bodyweight (kg)") {
                weightStepper(value: $profile.bodyweight, step: 0.5, min: 30)
            }
        }
    }

    // MARK: - Step 3: Goal / Days / Cardio

    private var step3: some View {
        Group {
            stepHeading(ar ? "هدفك" : "Your goal")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                squareChoice(value: "muscle",
                             title: ar ? "بناء العضلات" : "Build Muscle",
                             emoji: "💪",
                             selected: profile.goal == "muscle") {
                    profile.goal = "muscle"
                }
                squareChoice(value: "stronger",
                             title: ar ? "زيادة القوة" : "Get Stronger",
                             emoji: "🏋️",
                             selected: profile.goal == "stronger") {
                    profile.goal = "stronger"
                }
                squareChoice(value: "fat",
                             title: ar ? "حرق الدهون" : "Lose Fat",
                             emoji: "🔥",
                             selected: profile.goal == "fat") {
                    profile.goal = "fat"
                }
                squareChoice(value: "athletic",
                             title: ar ? "رياضي" : "Athletic",
                             emoji: "⚡",
                             selected: profile.goal == "athletic") {
                    profile.goal = "athletic"
                }
            }

            field(label: ar ? "أيام في الأسبوع" : "Days per week") {
                segmented(value: Binding(get: { String(profile.daysPerWeek) },
                                         set: { profile.daysPerWeek = Int($0) ?? 4 }),
                          options: [("3", "3"), ("4", "4"), ("5", "5")])
            }

            field(label: ar ? "الكارديو" : "Cardio") {
                segmented(value: $profile.cardio,
                          options: ar
                          ? [("none", "لا"), ("light", "خفيف"),
                             ("moderate", "متوسط"), ("heavy", "ثقيل")]
                          : [("none", "None"), ("light", "Light"),
                             ("moderate", "Moderate"), ("heavy", "Heavy")])
            }
        }
    }

    // MARK: - Step 4: Equipment + Session length

    private var step4: some View {
        Group {
            stepHeading(ar ? "إعدادك" : "Your setup")

            wideChoice(
                value: "full_gym",
                title: ar ? "صالة كاملة" : "Full Gym",
                sub: ar ? "أثقال، آلات، كابلات، دمبلز"
                       : "Barbells, machines, cables, dumbbells",
                selected: profile.equipment == "full_gym",
                onSelect: { profile.equipment = "full_gym" }
            )
            wideChoice(
                value: "home_gym",
                title: ar ? "صالة منزلية" : "Home Gym",
                sub: ar ? "بار، حامل، دمبلز (بدون آلات)"
                       : "Barbell, rack, dumbbells (no machines)",
                selected: profile.equipment == "home_gym",
                onSelect: { profile.equipment = "home_gym" }
            )
            wideChoice(
                value: "dumbbells",
                title: ar ? "دمبلز" : "Dumbbells",
                sub: ar ? "زوج دمبلز وبنش"
                       : "A pair of dumbbells + bench",
                selected: profile.equipment == "dumbbells",
                onSelect: { profile.equipment = "dumbbells" }
            )
            wideChoice(
                value: "bodyweight",
                title: ar ? "وزن الجسم فقط" : "Bodyweight",
                sub: ar ? "بدون معدات — أنت فقط وربما قضيب"
                       : "No equipment — just you and a bar maybe",
                selected: profile.equipment == "bodyweight",
                onSelect: { profile.equipment = "bodyweight" }
            )

            field(label: ar ? "مدة الجلسة" : "Session length") {
                segmented(value: Binding(get: { String(profile.sessionLength) },
                                         set: { profile.sessionLength = Int($0) ?? 60 }),
                          options: ar
                          ? [("45", "٤٥ د"), ("60", "٦٠ د"), ("90", "٩٠ د")]
                          : [("45", "45 min"), ("60", "60 min"), ("90", "90 min")])
            }
        }
    }

    // MARK: - Step 5: Weak points

    private var step5: some View {
        Group {
            stepHeading(ar ? "أي مناطق ضعيفة؟" : "Anything lagging?")

            Text(ar
                 ? "اختياري. سنركز التمارين الإضافية على هذه المناطق."
                 : "Optional. We'll bias accessory work toward these areas.")
                .font(.system(size: 14))
                .foregroundColor(HexTheme.dim)

            let groupsEn = ["Chest", "Back", "Shoulders", "Arms",
                            "Quads", "Glutes-Hams", "Core"]
            let groupsAr = ["صدر", "ظهر", "أكتاف", "ذراعان",
                            "فخذ أمامي", "أرداف وفخذ خلفي", "كور"]

            FlowChips {
                ForEach(Array(groupsEn.enumerated()), id: \.offset) { idx, key in
                    let active = profile.weakPoints.contains(key)
                    Button {
                        if active { profile.weakPoints.remove(key) }
                        else      { profile.weakPoints.insert(key) }
                    } label: {
                        Text(ar ? groupsAr[idx] : key)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(active ? HexTheme.accent : HexTheme.dim)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(active
                                               ? HexTheme.accent.opacity(0.12)
                                               : HexTheme.surface2)
                            )
                            .overlay(
                                Capsule().stroke(active ? HexTheme.accent
                                                          : HexTheme.border,
                                                 lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 6: Injuries

    private var step6: some View {
        Group {
            stepHeading(ar ? "أي إصابات؟" : "Any injuries?")

            field(label: ar
                  ? "الإصابات الحالية (أو \"لا شيء\")"
                  : "Current injuries (or 'none')") {
                hexTextArea(text: $profile.injuries,
                            placeholder: ar
                            ? "مثال: ألم في الركبة اليسرى، توتر أسفل الظهر"
                            : "e.g. left knee pain, lower back tightness")
            }

            field(label: ar ? "تمارين يجب تجنبها" : "Exercises to avoid") {
                hexTextArea(text: $profile.avoid,
                            placeholder: ar
                            ? "مثال: سكوات ثقيل، ضغط خلف العنق"
                            : "e.g. heavy squats, behind-neck press")
            }
        }
    }

    // MARK: - Step 7: Starting weights

    private var step7: some View {
        let rows: [(key: String, en: String, ar: String)] = [
            ("bench",    "Bench Press",     "بنش بريس"),
            ("squat",    "Back Squat",      "سكوات خلفي"),
            ("deadlift", "Deadlift",        "رفعة ميتة"),
            ("ohp",      "Overhead Press",  "ضغط فوق الرأس"),
            ("row",      "Barbell Row",     "تجديف بالبار"),
        ]
        return Group {
            stepHeading(ar ? "الأوزان الابتدائية" : "Starting weights")

            Text(ar
                 ? "وزنك الحالي — الوزن الذي ترفعه فعلياً للمجموعات، وليس أقصى وزن."
                 : "Your current working weight — the weight you actually lift for sets, not your max.")
                .font(.system(size: 13))
                .foregroundColor(HexTheme.dim)
                .lineSpacing(3)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text(ar ? row.ar : row.en)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(HexTheme.text)
                            Spacer()
                            weightStepper(
                                value: Binding(
                                    get: { profile.startingWeights[row.key] ?? 0 },
                                    set: { profile.startingWeights[row.key] = $0 }
                                ),
                                step: 2.5,
                                min: 0,
                                compact: true
                            )
                        }
                        .padding(.vertical, 12)
                        if idx < rows.count - 1 {
                            Rectangle()
                                .fill(HexTheme.border)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers (shared by steps)

    private func stepHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .heavy))
            .kerning(ar ? 0 : -0.4)
            .foregroundColor(HexTheme.text)
    }

    @ViewBuilder
    private func field<Content: View>(label: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .kerning(ar ? 0 : 0.7)
                .foregroundColor(HexTheme.dim)
            content()
        }
    }

    private func hexInput(text: Binding<String>,
                         placeholder: String,
                         keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .font(.system(size: 15))
            .foregroundColor(HexTheme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1.5)
            )
    }

    private func hexTextArea(text: Binding<String>,
                             placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(HexTheme.surface2)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1.5)
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundColor(HexTheme.mute)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
            TextEditor(text: text)
                .font(.system(size: 14))
                .foregroundColor(HexTheme.text)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(height: 96)
    }

    /// Segmented control. options are `(value, displayLabel)` pairs.
    private func segmented(value: Binding<String>,
                           options: [(String, String)]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                let active = value.wrappedValue == opt.0
                Button {
                    value.wrappedValue = opt.0
                } label: {
                    Text(opt.1)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(active ? .black : HexTheme.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(active ? HexTheme.accent : Color.clear)
                        )
                        .padding(2)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1.5)
        )
    }

    /// Wide selectable card with title + subtitle. Selected -> accent border + bg.
    private func wideChoice(value: String,
                            title: String,
                            sub: String,
                            selected: Bool,
                            onSelect: @escaping () -> Void) -> some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(selected ? HexTheme.accent : HexTheme.text)
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundColor(HexTheme.dim)
                        .lineLimit(2)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(selected ? HexTheme.accent : HexTheme.border, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if selected {
                        Circle()
                            .fill(HexTheme.accentFill)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? HexTheme.accent.opacity(0.10) : HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? HexTheme.accent : HexTheme.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    /// Square card with emoji + label, for the 2-column goal grid.
    private func squareChoice(value: String,
                              title: String,
                              emoji: String,
                              selected: Bool,
                              onSelect: @escaping () -> Void) -> some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 32))
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(selected ? HexTheme.accent : HexTheme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? HexTheme.accent.opacity(0.10) : HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? HexTheme.accent : HexTheme.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    /// Horizontal weight stepper (- value +). `compact` shrinks for inline use
    /// inside list rows (used by step 7's starting-weight rows).
    private func weightStepper(value: Binding<Double>,
                               step: Double,
                               min: Double,
                               compact: Bool = false) -> some View {
        HStack(spacing: compact ? 6 : 10) {
            stepperBtn(symbol: "minus", compact: compact) {
                value.wrappedValue = Swift.max(min, value.wrappedValue - step)
            }
            VStack(spacing: 0) {
                Text(formatWeight(value.wrappedValue))
                    .font(.system(size: compact ? 17 : 22, weight: .heavy)
                          .monospacedDigit())
                    .foregroundColor(HexTheme.text)
                if !compact {
                    Text("kg")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(HexTheme.mute)
                }
            }
            .frame(minWidth: compact ? 64 : 80)
            stepperBtn(symbol: "plus", compact: compact) {
                value.wrappedValue += step
            }
        }
        .padding(.horizontal, compact ? 4 : 14)
        .padding(.vertical, compact ? 4 : 10)
        .background(
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .fill(compact ? Color.clear : HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .stroke(compact ? Color.clear : HexTheme.border, lineWidth: 1)
        )
    }

    private func stepperBtn(symbol: String,
                            compact: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 12 : 14, weight: .heavy))
                .foregroundColor(HexTheme.accent)
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(HexTheme.accent.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(HexTheme.accent.opacity(0.3), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func formatWeight(_ w: Double) -> String {
        if w == w.rounded() { return "\(Int(w))" }
        return String(format: "%.1f", w)
    }
}

// MARK: - FlowChips (wrap layout)

/// Wraps child views onto multiple rows like flexbox wrap. Used for the
/// weak-points chip grid in step 5.
private struct FlowChips<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        FlowLayout(spacing: spacing) { content() }
    }
}

/// Custom Layout that wraps children onto multiple lines.
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var rowWidth: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            let newWidth = rowWidth + (rows[rows.count - 1].isEmpty ? s.width : spacing + s.width)
            if newWidth > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([s])
                rowWidth = s.width
            } else {
                rows[rows.count - 1].append(s)
                rowWidth = newWidth
            }
        }
        let h = rows.map { $0.map(\.height).max() ?? 0 }.reduce(0, +)
              + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: maxWidth, height: h)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        let maxX = bounds.maxX

        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxX, x > bounds.minX {
                // wrap
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
