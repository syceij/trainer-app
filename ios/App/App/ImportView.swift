import SwiftUI

/// Programme JSON import — port of src/components/ImportScreen.jsx.
/// Back button + title, description, collapsible prompt template (with
/// copy-to-clipboard), JSON paste editor, "Try with sample" link, error /
/// success validation panel, and Validate / Import action buttons.
///
/// Validation + import handlers route through `ImportHelpers` and
/// `AppState.enterAppWithImport` — same data path as React.
struct ImportView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var json: String = ""
    @State private var showPrompt: Bool = false
    @State private var copied: Bool = false
    @State private var errors: [String]? = nil
    @State private var validProgrammeName: String? = nil
    @State private var validWeekCount: Int = 0
    @State private var validSessionsPerWeek: Int = 0
    /// Parsed JSON kept around so the Import button can hand it straight
    /// off to AppState without re-parsing.
    @State private var validatedData: [String: Any]? = nil
    @FocusState private var jsonFocused: Bool

    private var ar: Bool { app.language == "ar" }
    private var hasValidated: Bool { validProgrammeName != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header (back button + title) ─────────────────
                header.padding(.bottom, 28)

                // ── Description ──────────────────────────────────
                Text(ar
                     ? "استخدم الطلب أدناه لتحويل برنامجك إلى JSON، ثم الصقه هنا."
                     : "Use the Claude prompt below to convert your programme to JSON, then paste it here.")
                    .font(.system(size: 14))
                    .foregroundColor(HexTheme.dim)
                    .lineSpacing(4)
                    .padding(.bottom, 20)

                // ── Collapsible prompt template ──────────────────
                collapsiblePrompt
                    .padding(.bottom, 20)

                // ── JSON paste area ──────────────────────────────
                jsonEditor
                    .padding(.bottom, 4)

                // ── Sample programme link ────────────────────────
                Button { loadSample() } label: {
                    Text(ar ? "← جرّب مع برنامج نموذجي" : "Try with sample programme →")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(HexTheme.accent)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: ar ? .trailing : .leading)
                .padding(.bottom, 12)

                // ── Error / success panels ───────────────────────
                if let errors = errors, !errors.isEmpty {
                    errorPanel(errors).padding(.bottom, 12)
                }
                if hasValidated {
                    successPanel.padding(.bottom, 12)
                }

                // ── Action buttons ───────────────────────────────
                actionButtons.padding(.top, 8)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .scrollDismissesKeyboard(.interactively)
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
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            Text(ar ? "الصق برنامجك" : "Paste your programme")
                .font(.system(size: 22, weight: .heavy))
                .kerning(ar ? 0 : -0.4)
                .foregroundColor(HexTheme.text)
        }
    }

    // MARK: - Prompt template (collapsible)

    private var collapsiblePrompt: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showPrompt.toggle()
                }
            } label: {
                HStack {
                    Text(ar ? "عرض قالب الطلب" : "Show prompt template for Claude")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                    Spacer()
                    Image(systemName: showPrompt ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HexTheme.dim)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(HexTheme.surface2)
            }
            .buttonStyle(.plain)

            if showPrompt {
                VStack(alignment: .leading, spacing: 12) {
                    Text(ImportHelpers.promptTemplate)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(HexTheme.dim)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button { copyPrompt() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 13, weight: .heavy))
                            Text(copied
                                 ? (ar ? "تم النسخ!" : "Copied!")
                                 : (ar ? "نسخ الطلب" : "Copy prompt"))
                                .font(.system(size: 13, weight: .heavy))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(HexTheme.accentFill)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HexTheme.surface)
                .transition(.opacity)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - JSON editor

    private var jsonEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HexTheme.surface2)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(jsonFocused ? HexTheme.accent : HexTheme.border, lineWidth: 1.5)

            if json.isEmpty {
                Text("{\n  \"name\": \"My Programme\",\n  \"weeks\": [...]\n}")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(HexTheme.mute)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $json)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(HexTheme.text)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .focused($jsonFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: json) { _ in
                    errors = nil
                    validProgrammeName = nil
                    validatedData = nil
                }
        }
        .frame(minHeight: 220)
    }

    // MARK: - Error / success panels

    private func errorPanel(_ errs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 1.0, green: 0.38, blue: 0.38))
                Text(ar ? "أخطاء التحقق" : "Validation errors")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Color(red: 1.0, green: 0.38, blue: 0.38))
            }
            ForEach(Array(errs.enumerated()), id: \.offset) { _, e in
                Text("• \(e)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 1.0, green: 0.50, blue: 0.50))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 1.0, green: 0.24, blue: 0.24).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 1.0, green: 0.24, blue: 0.24).opacity(0.40), lineWidth: 1.5)
        )
    }

    private var successPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(HexTheme.accent)
                Text(ar ? "برنامج صالح" : "Valid programme")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(HexTheme.accent)
            }
            Text(validProgrammeName ?? "")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(HexTheme.text)
            Text(ar
                 ? "\(validWeekCount) أسبوع · \(validSessionsPerWeek) جلسات/أسبوع"
                 : "\(validWeekCount) week\(validWeekCount == 1 ? "" : "s") · \(validSessionsPerWeek) session\(validSessionsPerWeek == 1 ? "" : "s")/week")
                .font(.system(size: 12))
                .foregroundColor(HexTheme.dim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(HexTheme.accent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HexTheme.accent.opacity(0.35), lineWidth: 1.5)
        )
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Validate (secondary)
            Button { tryValidate() } label: {
                Text(ar ? "التحقق" : "Validate")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            // Import & start (primary, disabled until validated)
            Button { doImport() } label: {
                Text(ar ? "← استيراد والبدء" : "Import & start →")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(hasValidated ? .black : HexTheme.mute)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(hasValidated ? HexTheme.accent : HexTheme.surface2)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!hasValidated)
            // Give the import button slightly more visual weight (~1.5x flex)
            .layoutPriority(1)
        }
    }

    // MARK: - Actions

    private func copyPrompt() {
        UIPasteboard.general.string = ImportHelpers.promptTemplate
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { copied = false }
        }
    }

    private func loadSample() {
        json = ImportHelpers.samplePrettyJSON
        errors = nil
        validProgrammeName = nil
        validatedData = nil
    }

    private func tryValidate() {
        // 1) JSON parse check
        guard let bytes = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        else {
            errors = [ar
                ? "JSON غير صالح — تحقق من الفواصل، الأقواس، أو علامات الاقتباس"
                : "Invalid JSON — check for missing commas, brackets, or quotes"]
            validProgrammeName = nil
            validatedData = nil
            return
        }

        // 2) Full schema check — port of validateImported in importHelpers.js.
        let errs = ImportHelpers.validateImported(parsed)
        if !errs.isEmpty {
            errors = errs
            validProgrammeName = nil
            validatedData = nil
            return
        }

        errors = nil
        validProgrammeName = parsed["name"] as? String
        let weeks = parsed["weeks"] as? [[String: Any]] ?? []
        validWeekCount = weeks.count
        let firstSessions = (weeks.first?["sessions"] as? [[String: Any]]) ?? []
        validSessionsPerWeek = firstSessions.filter { ($0["isRest"] as? Bool) != true }.count
        validatedData = parsed
    }

    private func doImport() {
        guard let data = validatedData else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            await app.enterAppWithImport(data)
            await MainActor.run { dismiss() }
        }
    }
}
