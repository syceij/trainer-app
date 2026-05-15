import SwiftUI

/// Thin wrapper that presents the full `ProgrammePage` editor inside a
/// sheet. Previously this file carried a separate read-only summary
/// implementation (~300 lines) that drifted from the React canonical
/// experience — the user wanted a single, identical programme surface
/// whether they reach it from Home ("View full programme") or Account
/// ("Edit programme"). The wrapper preserves that entry point while
/// delegating every pixel of UI to `ProgrammePage`.
///
/// `ProgrammePage` already uses `@Environment(\.dismiss)` for its back
/// button, so sheet dismissal works without any extra wiring.
struct ProgrammeModalView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            ProgrammePage()
                .environmentObject(app)
        }
    }
}
