import Foundation
import Supabase

/// Owns the Supabase Realtime subscriptions that keep the Bros tab live.
///
/// We listen to two tables:
///   • `friendships` — fires when someone sends/accepts a request involving
///     the current user
///   • `activity_feed` — fires when a friend posts a new activity row
///
/// Two-stage refresh strategy:
///   1. Debounce — coalesce a burst of events (e.g. a friend logging
///      a 20-set workout = 20 INSERTs in 30s) into a single refresh
///      1.5s after the last event.
///   2. Split by class — `friendships` events refetch the whole social
///      tab (friend list incl. leaderboard_data, pending, feed, leagues);
///      `activity_feed` events only refetch the cheap activity feed.
///      Friend leaderboard scores lag until pull-to-refresh, which is
///      a fine trade for not pulling everyone's score jsonb on every set.
///
/// We do NOT recompute the user's own leaderboard score here — that's
/// fired exclusively from `saveSession()` in AppState, since friend
/// events can't change the user's own points.
@MainActor
final class RealtimeSync {

    private weak var app: AppState?
    private var channel: RealtimeChannelV2?
    private var listenerTasks: [Task<Void, Never>] = []

    /// Coalesces a burst of realtime events into a single refresh. When
    /// a friend logs a full workout we can receive 15-30 activity_feed
    /// INSERTs in quick succession; without debouncing each one would
    /// trigger a full `loadSocial()` round-trip. 1.5s gives enough time
    /// for a typical set-save burst to settle without making the feed
    /// feel laggy.
    private var debounceTask: Task<Void, Never>?

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
                    await self.handleEvent(reason: "friendship-insert", kind: .friendship)
                }
            },
            Task { [weak self] in
                for await _ in friendshipDeletes {
                    guard !Task.isCancelled, let self else { return }
                    await self.handleEvent(reason: "friendship-delete", kind: .friendship)
                }
            },
            Task { [weak self] in
                for await _ in activityInserts {
                    guard !Task.isCancelled, let self else { return }
                    await self.handleEvent(reason: "activity-insert", kind: .activity)
                }
            },
            Task { [weak self] in
                for await _ in activityDeletes {
                    guard !Task.isCancelled, let self else { return }
                    await self.handleEvent(reason: "activity-delete", kind: .activity)
                }
            },
        ]
    }

    /// Cancel listeners + unsubscribe from the channel. Safe to call twice.
    func stop() async {
        debounceTask?.cancel()
        debounceTask = nil
        for t in listenerTasks { t.cancel() }
        listenerTasks = []
        if let ch = channel {
            await ch.unsubscribe()
        }
        channel = nil
    }

    // MARK: - Event handling

    /// Event-class — drives which refresh path runs when the debounce fires.
    /// `.friendship` is rare (someone accepts/declines a request) but needs
    /// a full friend-list refetch. `.activity` is the firehose (any friend
    /// logging any set) and only needs the activity feed refreshed.
    private enum EventClass {
        case friendship
        case activity
    }

    /// Tracks the heaviest event class seen during the current debounce
    /// window. Friendship > activity — if even one friendship event
    /// arrives mid-burst, we promote the eventual refresh to a full
    /// loadSocial() so the friend list stays in sync.
    private var pendingClass: EventClass?

    private func handleEvent(reason: String, kind: EventClass) async {
        // Promote pending event class to the heaviest seen this window.
        if pendingClass != .friendship { pendingClass = kind }

        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.fireRefresh(reason: reason)
        }
    }

    private func fireRefresh(reason: String) async {
        guard let app else { return }
        let cls = pendingClass ?? .activity
        pendingClass = nil

        print("[RealtimeSync] firing refresh (\(reason), class=\(cls))")
        switch cls {
        case .friendship:
            // Friendship changed (added/removed/accepted) — refetch
            // everything social including the friend list (their
            // leaderboard_data jsonb). Don't recompute OUR score —
            // friend changes don't affect it. The user's own score is
            // recomputed only in saveSession's detached task.
            await app.loadSocial()
        case .activity:
            // A friend logged a set somewhere. Cheap path: only
            // refresh the activity feed. The friend's score in the
            // bro-leaderboard might lag until the next pull-to-refresh
            // or the user's own save — acceptable trade for not
            // refetching `leaderboard_data` for every friend on every
            // single set save.
            await app.refreshActivityFeed()
        }
    }
}
