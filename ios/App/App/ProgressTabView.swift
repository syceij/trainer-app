import SwiftUI

struct ProgressTabView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text("Tracked lifts")
                    .font(.system(size: 13, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(HexTheme.textMuted)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        liftCardStub
                    }
                }

                Text("Muscle progress")
                    .font(.system(size: 13, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(HexTheme.textMuted)
                    .padding(.top, 12)

                muscleStub

                Spacer(minLength: 0)
            }
            .padding(HexTheme.padBase)
        }
        .hexBackground()
        .navigationTitle("Progress")
    }

    private var liftCardStub: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("—")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(HexTheme.text)
            Text("Pick a lift")
                .font(.system(size: 12))
                .foregroundStyle(HexTheme.textMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .hexCard()
    }

    private var muscleStub: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chart placeholder")
                .font(.system(size: 14))
                .foregroundStyle(HexTheme.textMuted)
            RoundedRectangle(cornerRadius: 8)
                .fill(HexTheme.cardBorder)
                .frame(height: 140)
        }
        .hexCard()
    }
}
