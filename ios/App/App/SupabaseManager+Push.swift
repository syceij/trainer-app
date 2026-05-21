import Foundation
import Supabase

/// Push-notification helpers — read/write push_devices,
/// notification_prefs, and invoke the send-push Edge Function.
extension SupabaseManager {

    // MARK: - Device token registration

    /// Upsert the current device's APNs token into push_devices. Keyed
    /// by device_token (UNIQUE) so re-installs that produce a new token
    /// create a new row, while re-launches with the same token are
    /// no-ops (just bump updated_at).
    func upsertPushDevice(token: String) async throws {
        guard let uid = currentUser?.id else { return }
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        struct DeviceRow: Encodable {
            let user_id: UUID
            let device_token: String
            let platform: String
            let is_sandbox: Bool
            let app_version: String?
            let updated_at: String
        }

        let row = DeviceRow(
            user_id:      uid,
            device_token: token,
            platform:     "ios",
            // We ship aps-environment=production via the entitlement, so
            // tokens are always production-bound. If we ever add Xcode
            // debug builds, flip this based on a build flag.
            is_sandbox:   false,
            app_version:  appVersion,
            updated_at:   ISO8601DateFormatter().string(from: Date())
        )

        _ = try await client
            .from("push_devices")
            .upsert(row, onConflict: "device_token")
            .execute()
    }

    /// Best-effort: drop this device's token. Called on sign-out so we
    /// don't keep notifying a phone whose user just signed out.
    func deletePushDevice(token: String) async {
        do {
            _ = try await client
                .from("push_devices")
                .delete()
                .eq("device_token", value: token)
                .execute()
        } catch {
            print("[SupabaseManager] deletePushDevice failed (non-fatal):", error)
        }
    }

    // MARK: - Notification preferences

    /// All 5 toggle keys persisted to profiles.notification_prefs.
    /// Missing keys are treated as "ON" by the Edge Function, so a brand
    /// new account gets all notifications by default — matches the
    /// "default ON" UX we agreed on.
    enum NotificationPrefKey: String, CaseIterable {
        case friends              // friend requests + acceptances (shared toggle)
        case leagues
        case friend_sessions
        case friend_badges
        case monthly_leaderboard
    }

    /// Fetch the current user's prefs as a dictionary. Returns an empty
    /// dict if the column is unset / null — equivalent to "all on".
    func fetchNotificationPrefs() async throws -> [String: Bool] {
        guard let uid = currentUser?.id else { return [:] }
        struct Row: Decodable {
            let notification_prefs: [String: Bool]?
        }
        let rows: [Row] = try await client
            .from("profiles")
            .select("notification_prefs")
            .eq("id", value: uid)
            .limit(1)
            .execute()
            .value
        return rows.first?.notification_prefs ?? [:]
    }

    /// Update a single toggle and persist. Reads the current blob,
    /// flips the key, writes back. The Edge Function reads this on
    /// every send and skips the user if a key is explicitly `false`.
    func setNotificationPref(_ key: NotificationPrefKey, enabled: Bool) async throws {
        guard let uid = currentUser?.id else { return }
        var prefs = (try? await fetchNotificationPrefs()) ?? [:]
        prefs[key.rawValue] = enabled

        struct Patch: Encodable { let notification_prefs: [String: Bool] }
        _ = try await client
            .from("profiles")
            .update(Patch(notification_prefs: prefs))
            .eq("id", value: uid)
            .execute()
    }

    // MARK: - Invoking the Edge Function

    /// Fire-and-forget call to send-push. The Edge Function does all
    /// the work — JWT signing, APNs POST, dead-token cleanup — so the
    /// app never needs the .p8 key. Failures here are logged but never
    /// surface to the user; a missed notification is recoverable.
    func sendPush(
        toUserIds: [UUID],
        category: String,
        title: String,
        body: String,
        data: [String: String] = [:]
    ) async {
        guard !toUserIds.isEmpty else { return }
        struct Payload: Encodable {
            let user_ids: [String]
            let category: String
            let title: String
            let body: String
            let data: [String: String]
        }
        let payload = Payload(
            user_ids: toUserIds.map { $0.uuidString },
            category: category,
            title:    title,
            body:     body,
            data:     data
        )
        do {
            _ = try await client.functions
                .invoke("send-push", options: .init(body: payload))
        } catch {
            print("[SupabaseManager] sendPush failed (non-fatal):", error)
        }
    }
}
