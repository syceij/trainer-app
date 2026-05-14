import SwiftUI

/// Progress tab — visual scaffold matching src/components/ProgressTab.jsx.
/// Tracked lifts grid, muscle progress chart placeholder, and "add" CTAs.
/// Real history-driven data wiring comes in a later pass.
struct ProgressTabView: View {
    @EnvironmentObject var app: AppState

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 2) {
                    Text(ar ? "تقدمك" : "Progress")
                        .font(.system(size: 26, weight: .heavy))
                        .kerning(ar ? 0 : -0.5)
                        .foregroundColor(HexTheme.text)
                    Text(ar
                         ? "تابع تطورك أسبوعاً بعد أسبوع"
                         : "Track your gains week over week")
                        .font(.system(size: 13))
                        .foregroundColor(HexTheme.dim)
                }
                .padding(.bottom, 24)

                // ── Tracked lifts ────────────────────────────────
                sectionHeader(label: ar ? "أوزانك" : "TRACKED LIFTS",
                              trailingIcon: "plus.circle.fill")
                    .padding(.bottom, 10)

                liftsGrid
                    .padding(.bottom, 24)

                // ── Muscle progress ──────────────────────────────
                sectionHeader(label: ar ? "تقدم العضلات" : "MUSCLE PROGRESS",
                              trailingIcon: nil)
                    .padding(.bottom, 10)

                muscleProgressCard
                    .padding(.bottom, 16)

                // ── Most improved card ───────────────────────────
                mostImprovedCard

                Spacer(minLength: 100) // room for floating tab bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Sections

    private func sectionHeader(label: String, trailingIcon: String?) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .kerning(ar ? 0 : 0.9)
                .foregroundColor(HexTheme.dim)
            Spacer()
            if let icon = trailingIcon {
                Button { /* TODO: open lift picker */ } label: {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(HexTheme.accent)
                }
            }
        }
    }

    private var liftsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)],
                  spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                liftPlaceholder
            }
        }
    }

    private var liftPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ar ? "اختر تمريناً" : "Pick a lift")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(HexTheme.dim)
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
            }

            Text("—")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(HexTheme.text)
                .padding(.top, 2)

            // Sparkline placeholder
            HStack(spacing: 3) {
                ForEach(0..<8, id: \.self) { _ in
                    Capsule()
                        .fill(HexTheme.border)
                        .frame(width: 3, height: 16)
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    private var muscleProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Bar chart placeholder — 6 muscle group bars
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(muscleGroups, id: \.id) { group in
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HexTheme.border)
                            .frame(height: 8)
                        // Label
                        Text(group.label)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(HexTheme.mute)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130)

            // Legend
            HStack {
                Text(ar
                     ? "سجّل تمرينين على الأقل لرؤية تقدمك"
                     : "Log 2+ workouts to see your progress")
                    .font(.system(size: 11))
                    .foregroundColor(HexTheme.mute)
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    private var mostImprovedCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HexTheme.accent.opacity(0.12))
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18))
                    .foregroundColor(HexTheme.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(ar ? "الأكثر تحسناً" : "MOST IMPROVED")
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(ar ? 0 : 0.9)
                    .foregroundColor(HexTheme.dim)
                Text(ar ? "ابدأ بتسجيل تمارينك" : "Start logging to see")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(HexTheme.text)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Muscle group labels

    private struct MuscleGroup { let id: String; let label: String }
    private var muscleGroups: [MuscleGroup] {
        ar
        ? [.init(id: "chest", label: "صدر"),
           .init(id: "back",  label: "ظهر"),
           .init(id: "legs",  label: "أرجل"),
           .init(id: "shldr", label: "كتف"),
           .init(id: "arms",  label: "ذراع"),
           .init(id: "core",  label: "بطن")]
        : [.init(id: "chest", label: "Chest"),
           .init(id: "back",  label: "Back"),
           .init(id: "legs",  label: "Legs"),
           .init(id: "shldr", label: "Shldr"),
           .init(id: "arms",  label: "Arms"),
           .init(id: "core",  label: "Core")]
    }
}
