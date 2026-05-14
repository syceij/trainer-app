import SwiftUI

/// Confetti burst — port of `src/components/shared/ConfettiBurst.jsx`.
/// Renders 30 small lime/white shapes radiating from the screen centre.
///
/// Trigger by binding `AppState.confettiTrigger`: increment it after a
/// session save and the host view (ContentView) re-renders with a fresh
/// set of randomized pieces.
struct ConfettiBurst: View {
    /// Re-keying on this number forces a fresh burst per trigger.
    let trigger: Int

    private static let colors: [Color] = [
        Color(red: 0.722, green: 1.0, blue: 0.0),   // accent
        .white,
        Color(red: 0.42,  green: 0.80, blue: 0.0),  // darker lime
        Color(red: 0.88,  green: 1.0,  blue: 0.50),
        .white,
    ]
    private static let count = 30

    /// Pre-randomised piece definitions for one burst.
    private struct Piece: Identifiable {
        let id = UUID()
        let dx: CGFloat
        let dy: CGFloat
        let size: CGFloat
        let color: Color
        let isCircle: Bool
        let delay: Double
        let rotation: Double
    }

    /// Computed lazily per-trigger so each burst is a different shape.
    private var pieces: [Piece] {
        (0..<Self.count).map { i in
            let angle = (Double(i) / Double(Self.count)) * .pi * 2
                + Double.random(in: -0.3...0.3)
            let dist = CGFloat.random(in: 120...260)
            return Piece(
                dx: cos(angle) * dist,
                dy: sin(angle) * dist,
                size: CGFloat.random(in: 6...12),
                color: Self.colors[i % Self.colors.count],
                isCircle: i % 3 == 0,
                delay: Double.random(in: 0...0.15),
                rotation: Double.random(in: -180...180)
            )
        }
    }

    @State private var animatedKey: Int = -1

    var body: some View {
        ZStack {
            // Render only the currently-active burst — once it ends (~1s),
            // the view goes back to empty until the next trigger.
            if animatedKey == trigger {
                ForEach(pieces) { piece in
                    ConfettiPiece(piece: piece)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onChange(of: trigger) { new in
            animatedKey = new
            // Auto-clear so we don't leak the animated views permanently.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if animatedKey == new { animatedKey = -1 }
            }
        }
    }
}

private struct ConfettiPiece: View {
    let piece: ConfettiBurst.Piece

    @State private var animateOut = false

    var body: some View {
        Group {
            if piece.isCircle {
                Circle().fill(piece.color)
            } else {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(piece.color)
            }
        }
        .frame(width: piece.size, height: piece.size)
        .offset(x: animateOut ? piece.dx : 0,
                y: animateOut ? piece.dy : 0)
        .scaleEffect(animateOut ? 0.3 : 1.0)
        .opacity(animateOut ? 0 : 1)
        .rotationEffect(.degrees(animateOut ? piece.rotation : 0))
        .onAppear {
            withAnimation(
                .spring(response: 0.55, dampingFraction: 0.65)
                    .delay(piece.delay)
            ) { animateOut = true }
        }
    }
}
