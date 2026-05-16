import SwiftUI

/// Bottom sheet exercise picker — port of src/components/ExercisePickerSheet.jsx.
/// Reaches the user via the swap icon in ProgrammePage's exercise rows.
///
/// This commit covers the list + search experience faithfully:
///   • drag-handle sheet style with a centered "SWAP EXERCISE" title
///   • search bar with clear button
///   • when not searching: 12 collapsible category sections (Chest,
///     Front/Side/Rear Shoulders, Back Width/Thickness, Biceps, Triceps,
///     Quads, Hamstrings & Glutes, Calves, Core). The category that
///     contains the currently-selected exercise is expanded on open.
///   • when searching: flat filtered results across the whole library.
///   • per-row equipment badge (BB / DB / Cable / Machine / BW) and a
///     checkmark on the currently-selected exercise.
///
/// Custom-exercise creation: search for a name with no match → a
/// "Create '<name>'" row appears, opens an inline category picker.
/// On save we persist the array to `profiles.custom_exercises` (jsonb).
struct ExercisePickerSheet: View {
    /// Key of the exercise currently in the slot (drives the open-state
    /// auto-expansion + the checkmark). May be nil when the slot was
    /// populated from an import without a library match.
    let currentName: String?
    /// Fires with the picked library exercise; sheet dismisses itself.
    let onSelect: (ProgrammeBuilder.LibraryExercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState

    @State private var search: String = ""
    @State private var expanded: Set<String> = []
    @FocusState private var searchFocused: Bool

    // Custom-exercise creation
    @State private var creatingForName: String? = nil
    @State private var newExerciseCategory: String? = nil
    @State private var savingCustom = false
    // Always-visible "Add new exercise" flow at the bottom of the
    // categories list. When the user taps the button it expands into
    // an inline form (name field + category grid) that mirrors the
    // search-driven "Create '<name>'" flow but without requiring a
    // failed search first. `inlineAddOpen` drives the expand/collapse.
    @State private var inlineAddOpen = false
    @State private var inlineAddName = ""

    private var ar: Bool { app.language == "ar" }

    // MARK: - Category definitions (verbatim from ExercisePickerSheet.jsx)

    private struct Category {
        let label: String
        let muscle: String          // CATEGORY_TO_MUSCLE in the JS
        let keys: [String]          // EXERCISE_CATEGORIES keys
    }

    private static let categories: [Category] = [
        .init(label: "Chest",                 muscle: "chest",      keys: ["bench_press","incline_bench","db_press","incline_db_press","db_fly","cable_fly","chest_press_machine","pec_deck","pushup","dip"]),
        .init(label: "Front Shoulders",       muscle: "shoulders",  keys: ["ohp","db_ohp","machine_shoulder","front_raise"]),
        .init(label: "Side Shoulders",        muscle: "shoulders",  keys: ["lateral_raise","cable_lateral"]),
        .init(label: "Rear Shoulders",        muscle: "shoulders",  keys: ["rear_delt_fly","face_pull"]),
        .init(label: "Back Width",            muscle: "back",       keys: ["pullup","chinup","lat_pulldown"]),
        .init(label: "Back Thickness",        muscle: "back",       keys: ["deadlift","barbell_row","db_row","cable_row","machine_row","inverted_row"]),
        .init(label: "Biceps",                muscle: "biceps",     keys: ["barbell_curl","db_curl","hammer_curl","cable_curl","preacher_curl"]),
        .init(label: "Triceps",               muscle: "triceps",    keys: ["tricep_pushdown","overhead_tricep","skull_crusher","close_grip_bench","bench_dip"]),
        .init(label: "Quads",                 muscle: "quads",      keys: ["squat","front_squat","leg_press","leg_ext","db_lunge","bodyweight_squat","jump_squat"]),
        .init(label: "Hamstrings & Glutes",   muscle: "hamstrings", keys: ["rdl","sumo_deadlift","db_rdl","leg_curl","hip_thrust","glute_bridge"]),
        .init(label: "Calves",                muscle: "calves",     keys: ["calf_raise","seated_calf"]),
        .init(label: "Core",                  muscle: "core",       keys: ["plank","ab_wheel","cable_crunch","hanging_leg_raise"]),
    ]

    /// Reverse lookup: exercise key → category label.
    private static let keyToCategory: [String: String] = {
        var m: [String: String] = [:]
        for c in categories {
            for k in c.keys { m[k] = c.label }
        }
        return m
    }()

    /// Cache the library by key so row rendering doesn't re-scan.
    private static let libraryByKey: [String: ProgrammeBuilder.LibraryExercise] = {
        var m: [String: ProgrammeBuilder.LibraryExercise] = [:]
        for ex in ProgrammeBuilder.exercises { m[ex.key] = ex }
        return m
    }()

    /// Best-effort: given a name (the slot's current exercise) figure
    /// out which library key + category it belongs to. Falls back to nil
    /// when the slot was populated from a custom/imported name.
    private static func resolveCategory(forName name: String?) -> String? {
        guard let n = name?.lowercased() else { return nil }
        if let ex = ProgrammeBuilder.exercises.first(where: { $0.name.lowercased() == n }) {
            return keyToCategory[ex.key]
        }
        return nil
    }

    private static func resolveKey(forName name: String?) -> String? {
        guard let n = name?.lowercased() else { return nil }
        return ProgrammeBuilder.exercises.first(where: { $0.name.lowercased() == n })?.key
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            header
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .overlay(
                    Rectangle().fill(HexTheme.border).frame(height: 1),
                    alignment: .bottom
                )

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    if isSearching {
                        searchResultsList
                    } else {
                        categoriesList
                        // Always-visible button below all categories so
                        // the "create a custom exercise" path doesn't
                        // require the user to search-and-fail first.
                        addNewExerciseRow
                    }
                    Spacer(minLength: 24)
                }
            }
        }
        .background(HexTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            // Auto-expand the category containing the current slot's exercise.
            if let cat = Self.resolveCategory(forName: currentName) {
                expanded.insert(cat)
            }
        }
    }

    private var dragHandle: some View {
        VStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(HexTheme.border)
                .frame(width: 40, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(ar ? "تبديل التمرين" : "SWAP EXERCISE")
                .font(.system(size: 11, weight: .heavy))
                .kerning(ar ? 0 : 1.0)
                .foregroundColor(HexTheme.dim)
                .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HexTheme.dim)
                TextField("", text: $search,
                          prompt: Text(ar ? "ابحث عن تمارين…" : "Search exercises…")
                            .foregroundColor(HexTheme.mute))
                    .font(.system(size: 16))
                    .foregroundColor(HexTheme.text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($searchFocused)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(HexTheme.mute)
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1.5)
            )
        }
    }

    private var isSearching: Bool {
        !search.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Flat search results

    @ViewBuilder
    private var searchResultsList: some View {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        let customMatches = app.customExercises.filter { $0.name.lowercased().contains(q) }
        let builtinResults = ProgrammeBuilder.exercises.filter { $0.name.lowercased().contains(q) }
        let exact = builtinResults.contains { $0.name.lowercased() == q }
            || customMatches.contains { $0.name.lowercased() == q }
        let showCreateRow = q.count >= 2 && !exact

        if customMatches.isEmpty && builtinResults.isEmpty && !showCreateRow {
            Text((ar ? "لا تمارين مطابقة لـ " : "No exercises match ") + "\"\(search)\"")
                .font(.system(size: 13))
                .foregroundColor(HexTheme.mute)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
        } else {
            let currentKey = Self.resolveKey(forName: currentName)
            // Custom matches first
            ForEach(customMatches) { ce in
                customExerciseRow(ce: ce, indent: false)
            }
            // Then built-in matches
            ForEach(builtinResults, id: \.key) { ex in
                exerciseRow(ex: ex,
                            selected: ex.key == currentKey,
                            indent: false)
            }
            // "+ Create custom" row at the bottom
            if showCreateRow {
                createCustomRow(forName: search.trimmingCharacters(in: .whitespaces))
            }
        }
    }

    // MARK: - Custom exercise rows + form

    @ViewBuilder
    private func customExerciseRow(ce: CustomExercise, indent: Bool) -> some View {
        Button {
            // Bridge into a LibraryExercise so the existing onSelect callback works.
            let bridged = ProgrammeBuilder.LibraryExercise(
                ce.key, ce.name, ce.muscle, ce.equipment,
                isMain: false, bodyweight: false
            )
            onSelect(bridged)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(ce.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(HexTheme.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(ar ? "خاص" : "Custom")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(HexTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HexTheme.accent.opacity(0.12))
                    )
            }
            .padding(.leading, indent ? 30 : 16)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay(
                Rectangle().fill(HexTheme.border).frame(height: 1),
                alignment: .top
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func createCustomRow(forName name: String) -> some View {
        if creatingForName == name {
            // Inline category picker
            VStack(alignment: .leading, spacing: 10) {
                Text((ar ? "إنشاء \"" : "Create \"") + name + "\"")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(HexTheme.accent)
                Text(ar ? "اختر العضلة المستهدفة:" : "Pick the target muscle:")
                    .font(.system(size: 12))
                    .foregroundColor(HexTheme.dim)
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 6),
                              GridItem(.flexible(), spacing: 6)],
                    spacing: 6
                ) {
                    ForEach(Self.categories, id: \.label) { cat in
                        Button {
                            newExerciseCategory = cat.label
                        } label: {
                            Text(localizedCategory(cat.label))
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(newExerciseCategory == cat.label
                                                 ? .black : HexTheme.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(newExerciseCategory == cat.label
                                              ? HexTheme.accent
                                              : HexTheme.surface2)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(HexTheme.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(spacing: 8) {
                    Button {
                        creatingForName = nil
                        newExerciseCategory = nil
                    } label: {
                        Text(ar ? "إلغاء" : "Cancel")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(HexTheme.mute)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(HexTheme.surface2)
                            )
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await saveCustom(name: name) }
                    } label: {
                        HStack {
                            if savingCustom {
                                ProgressView().tint(.black).scaleEffect(0.75)
                            } else {
                                Text(ar ? "حفظ" : "Save")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundColor(canSaveCustom ? .black : HexTheme.mute)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(canSaveCustom ? HexTheme.accent : HexTheme.surface2)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSaveCustom)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(HexTheme.accent.opacity(0.04))
            .overlay(
                Rectangle().fill(HexTheme.accent.opacity(0.30)).frame(height: 1),
                alignment: .top
            )
        } else {
            Button {
                creatingForName = name
                newExerciseCategory = nil
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(HexTheme.accent)
                    Text((ar ? "إنشاء \"" : "Create \"") + name + "\"")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(HexTheme.accent)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(HexTheme.accent.opacity(0.06))
                .overlay(
                    Rectangle().fill(HexTheme.accent.opacity(0.30)).frame(height: 1),
                    alignment: .top
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var canSaveCustom: Bool {
        newExerciseCategory != nil && !savingCustom
    }

    @MainActor
    private func saveCustom(name: String) async {
        guard let categoryLabel = newExerciseCategory,
              let cat = Self.categories.first(where: { $0.label == categoryLabel })
        else { return }
        savingCustom = true
        let new = CustomExercise(name: name, muscle: cat.muscle, category: categoryLabel)
        await app.addCustomExercise(new)
        savingCustom = false
        creatingForName = nil
        newExerciseCategory = nil
        // Auto-pick the new exercise (matches React handleCreate behaviour)
        let bridged = ProgrammeBuilder.LibraryExercise(
            new.key, new.name, new.muscle, new.equipment,
            isMain: false, bodyweight: false
        )
        onSelect(bridged)
        dismiss()
    }

    // MARK: - Categories accordion

    @ViewBuilder
    private var categoriesList: some View {
        let currentKey = Self.resolveKey(forName: currentName)
        ForEach(Self.categories, id: \.label) { cat in
            let isExpanded = expanded.contains(cat.label)
            // Category header row
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if isExpanded { expanded.remove(cat.label) }
                    else          { expanded.insert(cat.label) }
                }
            } label: {
                HStack {
                    Text(localizedCategory(cat.label))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(HexTheme.mute)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(HexTheme.surface)
                .overlay(
                    Rectangle().fill(HexTheme.border).frame(height: 1),
                    alignment: .top
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(cat.keys, id: \.self) { key in
                    if let ex = Self.libraryByKey[key] {
                        exerciseRow(ex: ex,
                                    selected: ex.key == currentKey,
                                    indent: true)
                    }
                }
            }
        }
    }

    // MARK: - Always-visible "Add new exercise" row

    /// Bottom-of-list button + inline form for creating a brand-new
    /// custom exercise. Collapsed by default — tapping the button
    /// reveals a name field and the category grid. Save reuses
    /// `saveCustom` (which writes to `profiles.custom_exercises` and
    /// auto-picks the new exercise via `onSelect` + dismiss).
    @ViewBuilder
    private var addNewExerciseRow: some View {
        if inlineAddOpen {
            inlineAddForm
        } else {
            Button {
                inlineAddOpen = true
                inlineAddName = ""
                newExerciseCategory = nil
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(HexTheme.accent)
                    Text(ar ? "إضافة تمرين جديد" : "Add new exercise")
                        .font(HexTheme.font(size: 14, weight: .heavy, ar: ar))
                        .foregroundColor(HexTheme.accent)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(HexTheme.accent.opacity(0.06))
                .overlay(
                    Rectangle().fill(HexTheme.accent.opacity(0.30)).frame(height: 1),
                    alignment: .top
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// Inline name field + category grid + Save/Cancel — same shape as
    /// the search-driven `createCustomRow` but with an editable name
    /// instead of a pre-filled search term.
    private var inlineAddForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ar ? "تمرين جديد" : "New exercise")
                .font(HexTheme.font(size: 13, weight: .heavy, ar: ar))
                .foregroundColor(HexTheme.accent)

            TextField("",
                      text: $inlineAddName,
                      prompt: Text(ar ? "اسم التمرين" : "Exercise name")
                        .foregroundColor(HexTheme.mute))
                .font(HexTheme.font(size: 15, weight: .regular, ar: ar))
                .foregroundColor(HexTheme.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(HexTheme.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(HexTheme.border, lineWidth: 1.5)
                )

            Text(ar ? "اختر العضلة المستهدفة:" : "Pick the target muscle:")
                .font(HexTheme.font(size: 12, weight: .regular, ar: ar))
                .foregroundColor(HexTheme.dim)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 6),
                          GridItem(.flexible(), spacing: 6)],
                spacing: 6
            ) {
                ForEach(Self.categories, id: \.label) { cat in
                    Button {
                        newExerciseCategory = cat.label
                    } label: {
                        Text(localizedCategory(cat.label))
                            .font(HexTheme.font(size: 12, weight: .heavy, ar: ar))
                            .foregroundColor(newExerciseCategory == cat.label
                                             ? .black : HexTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(newExerciseCategory == cat.label
                                          ? HexTheme.accent
                                          : HexTheme.surface2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(HexTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Button {
                    inlineAddOpen = false
                    inlineAddName = ""
                    newExerciseCategory = nil
                } label: {
                    Text(ar ? "إلغاء" : "Cancel")
                        .font(HexTheme.font(size: 13, weight: .heavy, ar: ar))
                        .foregroundColor(HexTheme.mute)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(HexTheme.surface2)
                        )
                }
                .buttonStyle(.plain)
                Button {
                    Task { await saveInlineCustom() }
                } label: {
                    HStack {
                        if savingCustom {
                            ProgressView().tint(.black).scaleEffect(0.75)
                        } else {
                            Text(ar ? "حفظ" : "Save")
                                .font(HexTheme.font(size: 13, weight: .heavy, ar: ar))
                                .foregroundColor(canSaveInline ? .black : HexTheme.mute)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(canSaveInline ? HexTheme.accent : HexTheme.surface2)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSaveInline)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(HexTheme.accent.opacity(0.04))
        .overlay(
            Rectangle().fill(HexTheme.accent.opacity(0.30)).frame(height: 1),
            alignment: .top
        )
    }

    /// Name must be non-empty AND a category must be picked.
    private var canSaveInline: Bool {
        !inlineAddName.trimmingCharacters(in: .whitespaces).isEmpty
            && newExerciseCategory != nil
            && !savingCustom
    }

    @MainActor
    private func saveInlineCustom() async {
        let name = inlineAddName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty,
              let categoryLabel = newExerciseCategory,
              let cat = Self.categories.first(where: { $0.label == categoryLabel })
        else { return }
        savingCustom = true
        let new = CustomExercise(name: name, muscle: cat.muscle, category: categoryLabel)
        await app.addCustomExercise(new)
        savingCustom = false
        inlineAddOpen = false
        inlineAddName = ""
        newExerciseCategory = nil
        let bridged = ProgrammeBuilder.LibraryExercise(
            new.key, new.name, new.muscle, new.equipment,
            isMain: false, bodyweight: false
        )
        onSelect(bridged)
        dismiss()
    }

    // MARK: - Exercise row

    @ViewBuilder
    private func exerciseRow(ex: ProgrammeBuilder.LibraryExercise,
                             selected: Bool,
                             indent: Bool) -> some View {
        Button {
            onSelect(ex)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(ex.name)
                    .font(.system(size: 14,
                                  weight: selected ? .heavy : .medium))
                    .foregroundColor(selected ? HexTheme.accent : HexTheme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Equipment badge
                Text(equipBadge(ex.equipment))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HexTheme.surface2)
                    )

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(HexTheme.accent)
                        .frame(width: 14)
                } else {
                    Spacer().frame(width: 14)
                }
            }
            .padding(.leading, indent ? 30 : 16)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(selected
                        ? HexTheme.accent.opacity(0.08)
                        : Color.clear)
            .overlay(
                Rectangle().fill(HexTheme.border).frame(height: 1),
                alignment: .top
            )
        }
        .buttonStyle(.plain)
    }

    private func equipBadge(_ equipment: String) -> String {
        switch equipment {
        case "barbell":    return "BB"
        case "dumbbell":   return "DB"
        case "cable":      return "Cable"
        case "machine":    return "Machine"
        case "bodyweight": return "BW"
        default:           return equipment
        }
    }

    /// Bilingual category label. We keep the English label as the
    /// dictionary key (matching the JS) and translate only for display.
    private func localizedCategory(_ label: String) -> String {
        if !ar { return label }
        switch label {
        case "Chest":               return "صدر"
        case "Front Shoulders":     return "كتف أمامي"
        case "Side Shoulders":      return "كتف جانبي"
        case "Rear Shoulders":      return "كتف خلفي"
        case "Back Width":          return "عرض الظهر"
        case "Back Thickness":      return "سمك الظهر"
        case "Biceps":              return "بايسبس"
        case "Triceps":             return "ترايسبس"
        case "Quads":               return "أمامية الفخذ"
        case "Hamstrings & Glutes": return "خلفية الفخذ والمؤخرة"
        case "Calves":              return "السمانة"
        case "Core":                return "البطن"
        default:                    return label
        }
    }
}
