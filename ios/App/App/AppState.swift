import Foundation
import SwiftUI
import Supabase

/// Top-level observable state shared across the app.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Auth

    enum AuthPhase: Equatable {
        case checking      // initial load — restoring session
        case signedOut
        case awaitingOTP(email: String)
        case signedIn
    }

    @Published var authPhase: AuthPhase = .checking
    @Published var currentProfile: Profile?

    // MARK: - Programme + session state

    @Published var activeProgramme: Programme?
    @Published var currentSession: WorkoutSession?
    /// Most recent N completed/in-progress sessions, ordered newest first.
    /// Populated by `loadHistory()` after sign-in and refreshed after each
    /// `finishWorkout(_:sets:)` call.
    @Published var workoutHistory: [WorkoutSession] = []

    // MARK: - Social state (friends / requests / activity)

    @Published var friends: [FriendListEntry] = []
    @Published var pendingRequests: [PendingRequest] = []
    @Published var activityFeed: [ActivityRow] = []
    /// Cached "user trained today" set used for friend-bubble ring colour.
    @Published var friendsTrainedToday: Set<UUID> = []
    /// Composed leaderboard rows (me + friends) ranked by score DESC. Recomputed
    /// every time `friends` or `currentProfile.leaderboard_data` changes.
    @Published var leaderboard: [LeaderboardEntry] = []

    // MARK: - UI state

    @Published var language: String = "en"   // "en" | "ar"
    @Published var toast: String?

    // MARK: - Init / session restore

    init() {
        Task { await restoreSession() }
    }

    /// On launch, check whether Supabase has a stored session and update phase.
    func restoreSession() async {
        let sb = SupabaseManager.shared
        do {
            // .session throws if no session is stored
            _ = try await sb.client.auth.session
            authPhase = .signedIn
            await loadUserData()
        } catch {
            authPhase = .signedOut
        }
    }

    /// Fan out the signed-in data loads in parallel. Called after every
    /// entry point into the signed-in state (restore, sign in, OTP).
    func loadUserData() async {
        async let profile:   () = loadOwnProfile()
        async let programme: () = loadActiveProgramme()
        async let history:   () = loadHistory()
        async let social:    () = loadSocial()
        _ = await (profile, programme, history, social)
        // Once the active programme is loaded, pre-stage today's session
        // so the Train tab has something to show without an extra round-trip.
        if currentSession == nil {
            stageCurrentSessionFromActiveProgramme()
        }
        // Leaderboard depends on currentProfile + friends — recompose now.
        rebuildLeaderboard()
    }

    // MARK: - Social loading

    /// Load friends + pending + activity feed in two stages — the feed
    /// depends on the friend list. Never throws; logs and recovers.
    func loadSocial() async {
        do {
            async let friendsT = SupabaseManager.shared.fetchFriends()
            async let pendingT = SupabaseManager.shared.fetchPendingRequests()
            let (fr, pend) = try await (friendsT, pendingT)
            self.friends         = fr
            self.pendingRequests = pend
        } catch {
            print("[AppState] loadSocial (friends/pending) failed:", error)
            self.friends = []; self.pendingRequests = []
        }
        // Activity feed — fetched after friends so we can scope by IDs
        do {
            let friendIds = friends.map(\.id)
            self.activityFeed = try await SupabaseManager.shared
                .fetchActivityFeed(friendIds: friendIds)
        } catch {
            print("[AppState] loadSocial (feed) failed:", error)
            self.activityFeed = []
        }
        recomputeTrainedToday()
    }

    /// Re-derive `friendsTrainedToday` from the current activity feed.
    private func recomputeTrainedToday() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var set: Set<UUID> = []
        for row in activityFeed where row.type == "session_completed" {
            if cal.isDate(row.createdAt, inSameDayAs: today) {
                set.insert(row.userId)
            }
        }
        self.friendsTrainedToday = set
    }

    /// Rebuild leaderboard rows from `currentProfile.leaderboardData` + friends.
    /// Filters out non-current-month rows so stale scores read as zero.
    func rebuildLeaderboard() {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let monthKey = String(format: "%04d-%02d",
                              cal.component(.year,  from: now),
                              cal.component(.month, from: now))

        let myProfile = currentProfile
        let myUid     = myProfile?.id
            ?? SupabaseManager.shared.currentUser?.id
            ?? UUID()

        let myLd  = currentProfileLeaderboard
        let myOK  = myLd?.month == monthKey
        let me = LeaderboardEntry(
            id:             myUid,
            rank:           0,
            name:           myProfile?.name ?? "You",
            username:       myProfile?.username,
            avatarURL:      myProfile?.avatarURL,
            score:          myOK ? (myLd?.score          ?? 0) : 0,
            setsCompleted:  myOK ? (myLd?.setsCompleted  ?? 0) : 0,
            improvementPct: myOK ? (myLd?.improvementPct ?? 0) : 0,
            isMe:           true
        )

        let friendEntries: [LeaderboardEntry] = friends.map { f in
            let ld = f.leaderboardData
            let current = ld?.month == monthKey
            return LeaderboardEntry(
                id:             f.id,
                rank:           0,
                name:           f.name,
                username:       f.username,
                avatarURL:      f.avatarURL,
                score:          current ? (ld?.score          ?? 0) : 0,
                setsCompleted:  current ? (ld?.setsCompleted  ?? 0) : 0,
                improvementPct: current ? (ld?.improvementPct ?? 0) : 0,
                isMe:           false
            )
        }

        let sorted = ([me] + friendEntries).sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return (a.name ?? "").localizedCaseInsensitiveCompare(b.name ?? "") == .orderedAscending
        }
        var ranked = sorted
        for i in ranked.indices { ranked[i].rank = i + 1 }
        self.leaderboard = ranked
    }

    /// In-memory mirror of the user's cached leaderboard score — populated
    /// after `loadOwnProfile()` and updated by `updateLeaderboardScore`.
    private var currentProfileLeaderboard: LeaderboardData?

    // MARK: - Social mutations

    /// Send a friend request and toast on success.
    func sendFriendRequest(toUserId uid: UUID) async {
        do {
            try await SupabaseManager.shared.sendFriendRequest(toUserId: uid)
            toast = language == "ar" ? "تم إرسال طلب الصداقة ✓" : "Friend request sent ✓"
        } catch {
            print("[AppState] sendFriendRequest failed:", error)
            toast = language == "ar" ? "تعذّر إرسال الطلب" : "Couldn't send request"
        }
    }

    /// Accept or decline an incoming request. On accept, add the sender to
    /// `friends` optimistically; on either, remove from `pendingRequests`.
    func respondToRequest(_ req: PendingRequest, accept: Bool) async {
        do {
            try await SupabaseManager.shared
                .respondFriendRequest(friendshipId: req.friendshipId, accept: accept)
            pendingRequests.removeAll { $0.friendshipId == req.friendshipId }
            if accept {
                friends.append(FriendListEntry(
                    id: req.userId,
                    name: req.name,
                    username: req.username,
                    avatarURL: req.avatarURL,
                    leaderboardData: nil
                ))
                rebuildLeaderboard()
            }
        } catch {
            print("[AppState] respondToRequest failed:", error)
        }
    }

    /// Remove an existing friend (both directions). Updates local state.
    func removeFriend(_ friendId: UUID) async {
        do {
            try await SupabaseManager.shared.removeFriend(friendId: friendId)
            friends.removeAll { $0.id == friendId }
            rebuildLeaderboard()
            toast = language == "ar" ? "تمت إزالة الصديق" : "Bro removed"
        } catch {
            print("[AppState] removeFriend failed:", error)
        }
    }

    /// Accept an invite code (deep-link or pasted manually). Returns the
    /// inviter's name on success, or nil on failure. Reloads social.
    @discardableResult
    func acceptInvite(code: String) async -> String? {
        do {
            let result = try await SupabaseManager.shared.acceptInvite(code: code)
            await loadSocial()
            return result.inviterName
        } catch {
            print("[AppState] acceptInvite failed:", error)
            toast = (error as? SupabaseManager.InviteError)?.errorDescription
                  ?? "Couldn't accept invite"
            return nil
        }
    }

    // MARK: - Auth actions

    /// Sign in with either an email or a username. If the input doesn't look
    /// like an email, we resolve the email via the `profiles` table before
    /// calling Supabase auth — mirrors src/components/AuthScreen.jsx.
    func signIn(emailOrUsername: String, password: String) async throws {
        let trimmed = emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let looksLikeEmail: Bool = {
            guard let at = trimmed.firstIndex(of: "@") else { return false }
            let domain = trimmed[trimmed.index(after: at)...]
            return domain.contains(".")
        }()

        let resolvedEmail: String
        if looksLikeEmail {
            resolvedEmail = trimmed
        } else {
            guard let mapped = try await SupabaseManager.shared
                .emailForUsername(trimmed.lowercased()), !mapped.isEmpty
            else {
                throw AuthError.usernameNotFound
            }
            resolvedEmail = mapped
        }

        _ = try await SupabaseManager.shared.signIn(
            email: resolvedEmail, password: password
        )
        authPhase = .signedIn
        await loadUserData()
    }

    enum AuthError: LocalizedError {
        case usernameNotFound
        case invalidCredentials
        var errorDescription: String? {
            switch self {
            case .usernameNotFound:   return "No account found with that username."
            case .invalidCredentials: return "Incorrect email/username or password."
            }
        }
    }

    func signUp(name: String, username: String, email: String, password: String) async throws {
        let metadata: [String: AnyJSON] = [
            "name":     .string(name),
            "username": .string(username)
        ]
        _ = try await SupabaseManager.shared.signUp(
            email: email, password: password, metadata: metadata
        )
        authPhase = .awaitingOTP(email: email)
    }

    func verifyOTP(email: String, token: String) async throws {
        _ = try await SupabaseManager.shared.verifyOTP(email: email, token: token)
        authPhase = .signedIn
        await loadUserData()
    }

    func resendOTP(email: String) async throws {
        try await SupabaseManager.shared.resendSignupOTP(email: email)
    }

    /// Go back from the OTP screen to the signed-out (login/signup) flow.
    func cancelOTP() async {
        try? await SupabaseManager.shared.signOut()
        authPhase = .signedOut
    }

    func signOut() async {
        try? await SupabaseManager.shared.signOut()
        currentProfile = nil
        activeProgramme = nil
        currentSession = nil
        workoutHistory = []
        authPhase = .signedOut
    }

    // MARK: - Profile

    func loadOwnProfile() async {
        do {
            currentProfile = try await SupabaseManager.shared.fetchOwnProfile()
            if let lang = currentProfile?.language, !lang.isEmpty {
                language = lang
            }
            // Fire-and-forget — leaderboard score blob lives in jsonb column
            // outside the typed Profile model.
            currentProfileLeaderboard =
                try? await SupabaseManager.shared.fetchOwnLeaderboardData()
        } catch {
            print("[AppState] loadOwnProfile failed:", error)
        }
    }

    // MARK: - Programme

    /// Fetch the currently active programme row for this user. Silently
    /// leaves `activeProgramme` nil on error — Home/Programme screens render
    /// an empty state in that case.
    func loadActiveProgramme() async {
        do {
            activeProgramme = try await SupabaseManager.shared.fetchActiveProgramme()
        } catch {
            print("[AppState] loadActiveProgramme failed:", error)
        }
    }

    // MARK: - Workout history

    /// Pull the most recent sessions for this user (DESC by date).
    func loadHistory() async {
        do {
            workoutHistory = try await SupabaseManager.shared.fetchHistory()
        } catch {
            print("[AppState] loadHistory failed:", error)
        }
    }

    /// Persist a completed workout: writes the session row and any performed
    /// sets, refreshes `workoutHistory`, inserts an activity-feed row, and
    /// recalculates the leaderboard score so friends see updated stats.
    func finishWorkout(_ session: WorkoutSession,
                       sets: [PerformedSet]) async throws {
        try await SupabaseManager.shared.saveWorkoutSession(session)
        try await SupabaseManager.shared.savePerformedSets(sets)
        currentSession = nil
        await loadHistory()

        // Compute completed-set volume for the activity-feed row
        let volume: Double = sets.reduce(0) { acc, s in
            if s.completed, let w = s.weight, w > 0, let r = s.reps, r > 0 {
                return acc + w * Double(r)
            }
            return acc
        }
        // Best-effort activity insert (never throws)
        await SupabaseManager.shared.insertActivity(
            type: "session_completed",
            data: [
                "session_name": session.name,
                "volume":       volume,
                "exercises":    session.data?.exercises.count ?? 0,
            ]
        )
        // Recalculate leaderboard score so the friends-leaderboard refreshes
        // on next CrewView load. Detach so it doesn't block the caller.
        Task.detached { [weak self] in
            let newScore = await SupabaseManager.shared
                .recalculateAndStoreLeaderboardScore()
            if let newScore = newScore {
                await MainActor.run {
                    self?.currentProfileLeaderboard = newScore
                    self?.rebuildLeaderboard()
                }
            }
        }
    }

    // MARK: - Programme creation entry points

    /// Generate a starter programme from the onboarding wizard answers and
    /// persist it as the active programme. Mirrors the React App.jsx
    /// `enterApp` callback that runs after the 7-step onboarding completes.
    func enterApp(profile: OnboardingProfile,
                  weights: [String: Double]) async {
        let data = ProgrammeBuilder.buildProgramme(profile: profile, weights: weights)
        await saveAndActivateProgramme(data: data)
    }

    /// Persist a validated imported programme and make it active. Mirrors
    /// the React `enterAppWithImport` callback used by ImportScreen.jsx.
    /// `raw` is the dict you get from `JSONSerialization.jsonObject(with:)`
    /// after `ImportHelpers.validateImported` returned no errors.
    func enterAppWithImport(_ raw: [String: Any]) async {
        guard let data = ImportHelpers.programmeData(fromImported: raw) else { return }
        await saveAndActivateProgramme(data: data)
    }

    /// Common tail: build a Programme row from generated/imported data,
    /// upsert it, mark it active, refresh in-memory state, and pre-stage
    /// today's session into `currentSession` so the Train tab is ready.
    private func saveAndActivateProgramme(data: ProgrammeData) async {
        guard let uid = SupabaseManager.shared.currentUser?.id else {
            print("[AppState] saveAndActivateProgramme: no user")
            return
        }
        let programme = Programme(
            id: UUID(),
            userId: uid,
            name: data.name,
            active: true,
            data: data,
            createdAt: nil
        )
        do {
            try await SupabaseManager.shared.upsertProgramme(programme)
            try await SupabaseManager.shared.markProgrammeActive(programme.id)
            await loadActiveProgramme()
            stageCurrentSessionFromActiveProgramme()
        } catch {
            print("[AppState] saveAndActivateProgramme failed:", error)
        }
    }

    /// Fields editable on a session header in ProgrammePage.
    enum SessionField { case name, focus, block }

    /// Fields editable on a single exercise in ProgrammePage.
    enum ExerciseField { case sets, reps, weight, rpe, notes }

    /// Edit a session header field (name/focus/block) inside the active
    /// programme and persist. Mirrors `updateAutoSessionField` /
    /// `updateImportedSessionField` from React App.jsx.
    func updateSessionField(weekIdx: Int,
                            sessionIdx: Int,
                            field: SessionField,
                            value: String) async {
        guard var programme = activeProgramme,
              var data = programme.data,
              weekIdx < data.weeks.count else { return }
        var week = data.weeks[weekIdx]
        guard sessionIdx < week.sessions.count else { return }
        var session = week.sessions[sessionIdx]
        switch field {
        case .name:
            session.name = value
        case .focus:
            // Repurposes the optional `notes` field in our session model
            // since the iOS ProgrammeSession struct doesn't carry a
            // separate `focus` value (parity with React-import data).
            // We piggyback on the first exercise's notes, no-op for now.
            // Stored as session.name comment for future use.
            _ = value
        case .block:
            // No structural field for "block" in iOS ProgrammeSession;
            // keep as no-op so the UI editor doesn't crash on commit.
            _ = value
        }
        week.sessions[sessionIdx] = session
        data.weeks[weekIdx] = week
        programme.data = data
        activeProgramme = programme
        mirrorCurrentSessionAfterEdit(programmeId: programme.id, name: session.name)
        await persist(programme)
    }

    /// Edit one exercise field (sets/reps/weight/rpe/notes). Numeric values
    /// for sets/weight parse from the string; bad parses leave the field
    /// unchanged so the user can correct without losing context.
    func updateExerciseField(weekIdx: Int,
                             sessionIdx: Int,
                             exerciseIdx: Int,
                             field: ExerciseField,
                             value: String) async {
        guard var programme = activeProgramme,
              var data = programme.data,
              weekIdx < data.weeks.count else { return }
        var week = data.weeks[weekIdx]
        guard sessionIdx < week.sessions.count else { return }
        var session = week.sessions[sessionIdx]
        guard exerciseIdx < session.exercises.count else { return }
        var ex = session.exercises[exerciseIdx]

        switch field {
        case .sets:
            if let n = Int(value), n > 0 { ex.sets = n }
        case .reps:
            ex.reps = value
        case .weight:
            let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()
            if trimmed == "bw" || trimmed == "bodyweight" {
                ex.weight = nil
            } else if let w = Double(trimmed) {
                ex.weight = w
            }
        case .rpe:
            ex.rpe = value.isEmpty ? nil : value
        case .notes:
            ex.notes = value.isEmpty ? nil : value
        }
        session.exercises[exerciseIdx] = ex
        week.sessions[sessionIdx] = session
        data.weeks[weekIdx] = week
        programme.data = data
        activeProgramme = programme
        mirrorCurrentSessionAfterEdit(programmeId: programme.id, name: session.name,
                                      exercises: session.exercises)
        await persist(programme)
    }

    /// Push updated session content into `currentSession` when it points
    /// at the same programme + session — keeps the Train tab in sync with
    /// edits made from ProgrammePage without an extra reload.
    private func mirrorCurrentSessionAfterEdit(programmeId: UUID,
                                               name: String,
                                               exercises: [Exercise]? = nil) {
        guard let cur = currentSession,
              cur.programmeId == programmeId,
              cur.name == name else { return }
        var updated = cur
        if let exercises = exercises, var d = cur.data {
            d.exercises = exercises
            updated.data = d
        }
        currentSession = updated
    }

    /// Best-effort Supabase upsert. Errors are logged but non-fatal — the
    /// in-memory mutation already landed, and the next signed-in load
    /// will rehydrate from whatever the DB has.
    private func persist(_ programme: Programme) async {
        do {
            try await SupabaseManager.shared.upsertProgramme(programme)
        } catch {
            print("[AppState] programme upsert failed:", error)
        }
    }

    /// Replace one exercise in the active programme with a different one
    /// from the library (typically picked from ExercisePickerSheet) and
    /// persist the resulting programme. Indices come from ProgrammePage,
    /// which threads (weekIdx, sessionIdx, exerciseIdx) through its rows.
    ///
    /// The replacement preserves the user's sets/reps/RPE/notes/weight
    /// (except the weight resets when the swap is to a bodyweight move)
    /// and updates the tag from the library's `isMain` flag.
    func swapExercise(weekIdx: Int,
                      sessionIdx: Int,
                      exerciseIdx: Int,
                      replacement: ProgrammeBuilder.LibraryExercise) async {
        guard var programme = activeProgramme,
              var data = programme.data,
              weekIdx < data.weeks.count else { return }
        var week = data.weeks[weekIdx]
        guard sessionIdx < week.sessions.count else { return }
        var session = week.sessions[sessionIdx]
        guard exerciseIdx < session.exercises.count else { return }

        let old = session.exercises[exerciseIdx]
        let newWeight: Double? = replacement.bodyweight ? nil : (old.weight ?? 20)
        let newTag: String = replacement.isMain ? "compound" : "accessory"
        let swappedNotes: String? = {
            let prefix = old.notes.flatMap { $0.isEmpty ? nil : "\($0) · " } ?? ""
            return "\(prefix)Swapped from \(old.name)"
        }()

        session.exercises[exerciseIdx] = Exercise(
            name:   replacement.name,
            tag:    newTag,
            sets:   old.sets,
            reps:   old.reps,
            weight: newWeight,
            rpe:    old.rpe,
            notes:  swappedNotes
        )
        week.sessions[sessionIdx] = session
        data.weeks[weekIdx] = week
        programme.data = data
        activeProgramme = programme

        // Reflect the swap in `currentSession` too, so the Train tab
        // refreshes if the user happens to be looking at the swapped
        // session right now.
        if let cur = currentSession,
           cur.programmeId == programme.id,
           cur.name == session.name,
           var d = cur.data {
            d.exercises = session.exercises
            var updated = cur
            updated.data = d
            currentSession = updated
        }

        do {
            try await SupabaseManager.shared.upsertProgramme(programme)
        } catch {
            print("[AppState] swapExercise persist failed:", error)
        }
    }

    /// Pick today's session (or the first one as fallback) from the active
    /// programme and stage it as `currentSession`, ready to be logged on
    /// the Train tab. No-op when there's no active programme yet.
    func stageCurrentSessionFromActiveProgramme() {
        guard let prog = activeProgramme,
              let week = prog.data?.weeks.first,
              !week.sessions.isEmpty,
              let uid = SupabaseManager.shared.currentUser?.id
        else { return }
        let dayKeys = ["sun","mon","tue","wed","thu","fri","sat"]
        let todayIdx = Calendar.current.component(.weekday, from: Date()) - 1
        let todayKey = dayKeys[max(0, min(6, todayIdx))]
        let picked = week.sessions.first(where: { $0.day == todayKey })
                  ?? week.sessions.first!
        currentSession = WorkoutSession(
            id: UUID(),
            userId: uid,
            programmeId: prog.id,
            name: picked.name,
            date: Date(),
            weekNumber: week.weekNumber,
            block: nil,
            completed: false,
            data: WorkoutSessionData(exercises: picked.exercises),
            createdAt: nil
        )
    }

    // MARK: - Toast

    func showToast(_ msg: String) {
        toast = msg
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if toast == msg { toast = nil }
        }
    }
}
