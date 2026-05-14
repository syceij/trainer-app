import SwiftUI

struct CrewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Friends avatar row placeholder
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(HexTheme.card)
                                .overlay(
                                    Circle().stroke(HexTheme.cardBorder, lineWidth: 1)
                                )
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(HexTheme.textMuted)
                                )
                        }
                    }
                }

                Text("Leaderboard")
                    .font(.system(size: 13, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(HexTheme.textMuted)
                    .padding(.top, 8)

                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { idx in
                        HStack {
                            Text("#\(idx + 1)")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(HexTheme.accent)
                                .frame(width: 32, alignment: .leading)
                            Text("—")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(HexTheme.text)
                            Spacer()
                            Text("0")
                                .font(.system(size: 15, weight: .heavy).monospacedDigit())
                                .foregroundStyle(HexTheme.text)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(HexTheme.card)
                        )
                    }
                }

                Text("Activity feed coming soon.")
                    .font(.system(size: 13))
                    .foregroundStyle(HexTheme.textMuted)
                    .padding(.top, 20)

                Spacer(minLength: 0)
            }
            .padding(HexTheme.padBase)
        }
        .hexBackground()
        .navigationTitle("Crew")
    }
}
