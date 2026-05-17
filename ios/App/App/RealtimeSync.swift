import Foundation
import Supabase

/// Owns the Supabase Realtime subscriptions that keep the Bros tab live.
///
/// We listen to two tables:
///   • `friendships` — fires when someone sends/accepts a request involving
///     the current user
///   • `activity_feed` — fires when a friend posts a new activity row
///
/// On any event we just re-run `AppState.loadSocial()`, which is cheap
/// (two tiny queries + a feed join) and keeps the merge logic in one place.
@MainActor
final class RealtimeSync {

    private weak var app: AppState?
    private var channel: RealtimeChannelV2?
    private var listenerTasks: [Task<Void, Never>] = []

    init(app: AppState) {
        self.app = app
    }

    // MARK: - Lifecycle

    /// Start (or restart) the subscription for the current user. Idempotent —
    /// stops the previous channel before opening a new one.
    ///
    /// We only listen for INSERT events (most important: new friend request,
    /// new activity row). Updates/deletes are rare here and can wait for
    /// pull-to-refresh — keeping the surface small makes the subscription
    /// API stable across supabase-swift point releases.
    func start() async {
        guard let uid = SupabaseManager.shared.currentUser?.id else { return }
        await stop()

        let realtime = SupabaseManager.shared.client.realtimeV2
        let ch = realtime.channel("hex-bros-\(uid.uuidString)")
        self.channel = ch

        // Postgres INSERT + DELETE streams — typed payloads not needed;
        // every event simply triggers a `loadSocial()` refresh.
        //
        // Why DELETE matters: when a friend resets their data or
        // deletes their account, `resetUserData()` wipes the
        // friendships row from BOTH directions. Without a DELETE
        // listener, the still-online friend's device kept showing
        // the now-removed user until they manually pulled-to-refresh.
        // Same story for activity_feed rows.
        let friendshipInserts = ch.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "friendships"
        )
        let friendshipDeletes = ch.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "friendships"
        )
        let activityInserts = ch.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "activity_feed"
        )
        let activityDeletes = ch.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "activity_feed"
        )

        do {
            try await ch.subscribeWithError()
            print("[RealtimeSync] subscribed (uid=\(uid))")
        } catch {
            print("[RealtimeSync] subscribe failed:", error)
            return
        }

        listenerTasks = [
            Task { [weak self] in
                for await _ in friendshipInserts {
                    guard !Task.isCancelled, let self else { return }
                    await self.handleEvent(reason: "friendship-insert")
                }
            },
            Task { [weak self] in
                for await _ in friendshipDeletes {
                    guard !Task.isCancelled, let self else { return }
                    await self.handleEvent(reason: "friendship-delete")
                }
            },
            Task { [weak self] in
                for await _ in activityInserts {
                    guard !Task.isCancelled, let self else { return }
                    await self.handleEvent(reason: "activity-insert")
                }
            },
            Task { [weak self] in
                for await _ in activityDeletes {
                    guard !Task.isCancelled, let self else { return }
                    await self.handleEvent(reason: "activity-delete")
                }
            },
        ]
    }

    /// Cancel listeners + unsubscribe from the channel. Safe to call twice.
    func stop() async {
        for t in listenerTasks { t.cancel() }
        listenerTasks = []
        if let ch = channel {
            await ch.unsubscribe()
        }
        channel = nil
    }

    // MARK: - Event handling

    private func handleEvent(reason: String) async {
        guard let app else { return }
        print("[RealtimeSync] event (\(reason)) → reloading social")
        await app.loadSocial()
        app.rebuildLeaderboard()
    }
}
