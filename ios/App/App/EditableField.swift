import SwiftUI
import UIKit

/// Tap-to-edit inline field — port of the React `EditableField` component
/// used throughout ProgrammePage.jsx. Display state shows the value with a
/// dashed underline (accent when edited). Tap to switch to a TextField,
/// then return/blur commits.
///
/// Caller passes the current snapshot value + an `editKey` for tracking
/// which fields have been touched. On commit, `onCommit` fires with the
/// raw string (or trimmed-to-Double when keyboard is `.decimalPad`).
struct EditableField: View {

    enum Kind { case text, number }

    /// Display value (always a snapshot from the source of truth).
    let value: String
    /// Stable identifier the parent uses to mark "edited" status.
    let editKey: String
    @Binding var editedKeys: Set<String>

    var kind: Kind = .text
    /// What to render when value is empty (also acts as the placeholder
    /// inside the TextField during editing).
    var placeholder: String = "—"
    /// Optional trailing suffix (e.g. "kg") shown next to the value.
    var suffix: String? = nil
    /// Font / colour style overrides — defaults match the React text style.
    var font: Font = .system(size: 13, weight: .heavy)
    var foregroundColor: Color = HexTheme.text
    var muteColor: Color = HexTheme.mute
    /// Fired when the user finishes editing with a value distinct from `value`.
    let onCommit: (String) -> Void

    @State private var editing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    private var isEdited: Bool { editedKeys.contains(editKey) }

    var body: some View {
        if editing {
            HStack(spacing: 4) {
                TextField(placeholder, text: $draft)
                    .keyboardType(kind == .number ? .decimalPad : .default)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(font)
                    .foregroundColor(HexTheme.text)
                    .focused($fieldFocused)
                    .onSubmit { commit() }
                    .onChange(of: fieldFocused) { newValue in
                        if !newValue { commit() }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(HexTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(HexTheme.accent, lineWidth: 1.5)
                    )
                    .frame(minWidth: kind == .number ? 64 : 80,
                           maxWidth: kind == .number ? 120 : .infinity)

                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.dim)
                }
            }
            .onAppear {
                draft = value
                // small delay so the field actually grabs focus on first render
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    fieldFocused = true
                }
            }
        } else {
            Button { startEdit() } label: {
                HStack(spacing: 3) {
                    Text(value.isEmpty ? placeholder : value)
                        .font(font)
                        .foregroundColor(value.isEmpty ? muteColor : foregroundColor)
                    if let suffix = suffix, !value.isEmpty {
                        Text(suffix)
                            .font(.system(size: 11))
                            .foregroundColor(HexTheme.dim)
                    }
                    if isEdited {
                        Circle()
                            .fill(HexTheme.accent)
                            .frame(width: 5, height: 5)
                    }
                }
                .overlay(
                    Rectangle()
                        .fill(isEdited ? HexTheme.accent : Color.white.opacity(0.12))
                        .frame(height: 1),
                    alignment: .bottom
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func startEdit() {
        draft = value
        editing = true
    }

    private func commit() {
        editing = false
        let parsed: String = {
            if kind == .number {
                // Drop non-numeric junk; preserve "BW"/"light" if typed.
                let trimmed = draft.trimmingCharacters(in: .whitespaces)
                if let d = Double(trimmed) {
                    // Normalise "12.0" -> "12" to keep the display compact.
                    return d.truncatingRemainder(dividingBy: 1) == 0
                        ? String(Int(d))
                        : String(format: "%.1f", d)
                }
                return trimmed
            }
            return draft.trimmingCharacters(in: .whitespaces)
        }()
        if parsed != value {
            editedKeys.insert(editKey)
            onCommit(parsed)
        }
    }
}
