import SwiftUI

/// Bros tab — visual scaffold matching src/components/GymBrosTab.jsx.
/// Real friend / request / activity data wiring comes in a later pass —
/// this turn matches the layout (header, section labels, empty states).
struct CrewView: View {
    @EnvironmentObject var app: AppState

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ────────────────────────────────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ar ? "أصدقاء الجيم" : "Gym Bros")
                            .font(.system(size: 26, weight: .heavy))
                            .kerning(ar ? 0 : -0.5)
                            .foregroundColor(HexTheme.text)
                        Text(ar
                             ? "تابع أصدقائك · شارك إنجازاتك"
                             : "Follow your bros · share your wins")
                            .font(.system(size: 13))
                            .foregroundColor(HexTheme.dim)
                    }
                    Spacer()
                    Button { /* TODO: invite link */ } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(HexTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(HexTheme.surface2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(HexTheme.border, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 20)

                // ── Search / add row ──────────────────────────────
                searchBar.padding(.bottom, 20)

                // ── Pending section ──────────────────────────────
                sectionLabel(ar ? "الطلبات" : "PENDING").padding(.bottom, 8)
                emptyCard(ar
                          ? "لا توجد طلبات صداقة جديدة"
                          : "No pending requests")
                    .padding(.bottom, 20)

                // ── Bros section ─────────────────────────────────
                sectionLabel(ar ? "الأصدقاء" : "BROS").padding(.bottom, 8)
                emptyCard(ar
                          ? "اعثر على أصدقاء وشارك تقدمك"
                          : "Find bros and share your progress")
                    .padding(.bottom, 20)

                // ── Activity feed section ────────────────────────
                sectionLabel(ar ? "النشاط الأخير" : "ACTIVITY").padding(.bottom, 8)
                emptyCard(ar
                          ? "لا يوجد نشاط بعد"
                          : "No activity yet")

                Spacer(minLength: 100) // room for floating tab bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .kerning(ar ? 0 : 0.9)
            .foregroundColor(HexTheme.dim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(HexTheme.mute)
            Text(ar ? "ابحث عن صديق..." : "Search for a bro...")
                .font(.system(size: 14))
                .foregroundColor(HexTheme.mute)
            Spacer()
            Image(systemName: "person.badge.plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(HexTheme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1.5)
        )
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundColor(HexTheme.mute)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.vertical, 22)
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
