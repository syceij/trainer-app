import SwiftUI

/// Quick lift picker — used by ProgressTabView's "+" button to choose
/// which lift to drill down on. Lists every exercise the user has ever
/// logged (deduped, in first-seen order), with a search filter.
struct LiftPickerSheet: View {
    let allExerciseNames: [String]
    let onPick: (String) -> Void

    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var ar: Bool { app.language == "ar" }

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return allExerciseNames }
        return allExerciseNames.filter { $0.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Grabber
            Capsule()
                .fill(HexTheme.surface2)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Text(ar ? "اختر تمريناً" : "Pick a lift")
                .font(.system(size: 17, weight: .heavy))
                .foregroundColor(HexTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            // Search
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(HexTheme.mute)
                TextField(ar ? "ابحث" : "Search",
                          text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16))
                    .foregroundColor(HexTheme.text)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(HexTheme.mute)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // List
            if filtered.isEmpty {
                VStack(spacing: 6) {
                    Text(ar ? "لا توجد تمارين مطابقة" : "No matching lifts")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                    Text(ar
                         ? "سجّل جلسة لرؤية رفعاتك هنا"
                         : "Log a session to see your lifts here.")
                        .font(.system(size: 12))
                        .foregroundColor(HexTheme.mute)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered, id: \.self) { name in
                            Button { onPick(name) } label: {
                                HStack {
                                    Text(name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(HexTheme.text)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(HexTheme.mute)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                                .overlay(
                                    Rectangle()
                                        .fill(HexTheme.border)
                                        .frame(height: 1),
                                    alignment: .bottom
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .background(HexTheme.bg.ignoresSafeArea())
    }
}
