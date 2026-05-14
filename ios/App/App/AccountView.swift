import SwiftUI
import PhotosUI
import Supabase

/// Profile tab — visual port of src/components/ProfileTab.jsx.
/// Avatar header with name + username + camera button, then Account /
/// Preferences / Privacy sections with rows, then sign-out CTA.
/// Also exposes a "Talk to PT" link to PTChatView (in React, PT was
/// surfaced via the account view, not a top-level tab).
struct AccountView: View {
    @EnvironmentObject var app: AppState

    @State private var liveActivitiesEnabled = LiveActivityService.shared.isEnabled
    @State private var showSignOutConfirm    = false
    @State private var showDeleteConfirm     = false
    @State private var showResetConfirm      = false
    @State private var resetting             = false
    @State private var deleting              = false

    // Avatar picker state
    @State private var avatarPick: PhotosPickerItem? = nil
    @State private var uploadingAvatar = false

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Avatar header ────────────────────────────────
                avatarHeader.padding(.bottom, 24)

                // ── Account section ──────────────────────────────
                sectionTitle(ar ? "الحساب" : "ACCOUNT").padding(.bottom, 10)
                accountSection.padding(.bottom, 24)

                // ── Preferences section ──────────────────────────
                sectionTitle(ar ? "التفضيلات" : "PREFERENCES").padding(.bottom, 10)
                preferencesSection.padding(.bottom, 24)

                // ── PT shortcut ──────────────────────────────────
                sectionTitle(ar ? "المدرب" : "COACHING").padding(.bottom, 10)
                ptShortcut.padding(.bottom, 24)

                // ── Programme actions ────────────────────────────
                sectionTitle(ar ? "البرنامج" : "PROGRAMME").padding(.bottom, 10)
                VStack(spacing: 10) {
                    buildProgrammeRow
                    manualBuilderRow
                    importProgrammeRow
                    if app.activeProgramme != nil {
                        editProgrammeRow
                    }
                    calendarRow
                }
                .padding(.bottom, 24)

                // ── Sign out / delete ────────────────────────────
                dangerSection

                Spacer(minLength: 100) // room for floating tab bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .confirmationDialog(ar ? "تسجيل الخروج؟" : "Sign out?",
                            isPresented: $showSignOutConfirm,
                            titleVisibility: .visible) {
            Button(ar ? "تسجيل الخروج" : "Sign out", role: .destructive) {
                Task { await app.signOut() }
            }
            Button(ar ? "إلغاء" : "Cancel", role: .cancel) {}
        }
    }

    // MARK: - Avatar header

    private var avatarHeader: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let url = app.currentProfile?.avatarURL,
                       let parsed = URL(string: url) {
                        AsyncImage(url: parsed) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            default:
                                avatarFallback
                            }
                        }
                        .clipShape(Circle())
                    } else {
                        avatarFallback
                    }
                }
                .frame(width: 72, height: 72)
                .overlay(
                    Circle().stroke(HexTheme.border, lineWidth: 2)
                )

                // Camera button bottom-right — opens PhotosPicker, uploads to
                // Supabase Storage, updates profile.avatar_url.
                PhotosPicker(selection: $avatarPick,
                             matching: .images,
                             photoLibrary: .shared()) {
                    Image(systemName: uploadingAvatar ? "arrow.triangle.2.circlepath" : "camera.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(HexTheme.accent))
                        .overlay(
                            Circle().stroke(HexTheme.bg, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .onChange(of: avatarPick) { newItem in
                    guard let item = newItem else { return }
                    Task { await handleAvatarPick(item) }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(app.currentProfile?.name ?? (ar ? "رياضي" : "Athlete"))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                if let u = app.currentProfile?.username {
                    Text("@\(u)")
                        .font(.system(size: 13))
                        .foregroundColor(HexTheme.dim)
                }
            }
            Spacer()
        }
    }

    // MARK: - Account section

    private var accountSection: some View {
        VStack(spacing: 0) {
            infoRow(icon: "person",
                    iconAccent: true,
                    label: ar ? "الاسم" : "Name",
                    value: app.currentProfile?.name,
                    last: false)
            divider
            infoRow(icon: "at",
                    iconAccent: false,
                    label: ar ? "اسم المستخدم" : "Username",
                    value: app.currentProfile?.username.map { "@\($0)" },
                    last: false)
            divider
            infoRow(icon: "envelope",
                    iconAccent: false,
                    label: ar ? "البريد الإلكتروني" : "Email",
                    value: app.currentProfile?.email,
                    last: true)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Preferences section

    private var preferencesSection: some View {
        VStack(spacing: 0) {
            // Language row
            HStack(spacing: 14) {
                iconBox(name: "globe", accent: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ar ? "اللغة" : "Language")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                    Text(ar ? "العربية" : "English")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                }
                Spacer()
                Picker("", selection: $app.language) {
                    Text("EN").tag("en")
                    Text("AR").tag("ar")
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            divider

            // Live activities toggle
            Toggle(isOn: $liveActivitiesEnabled) {
                HStack(spacing: 14) {
                    iconBox(name: "bolt", accent: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ar ? "الأنشطة المباشرة" : "Live Activities")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(HexTheme.text)
                        Text(ar
                             ? "اعرض جلستك على شاشة القفل"
                             : "Show your session on the lock screen")
                            .font(.system(size: 11))
                            .foregroundColor(HexTheme.mute)
                    }
                }
            }
            .tint(HexTheme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    // MARK: - PT shortcut

    private var ptShortcut: some View {
        NavigationLink {
            PTChatView()
        } label: {
            HStack(spacing: 14) {
                iconBox(name: "message.fill", accent: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ar ? "اسأل المدرب" : "Ask PT")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                    Text(ar
                         ? "تدريب ذكي · تعديلات البرنامج"
                         : "AI coaching · programme adjustments")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                }
                Spacer()
                Image(systemName: ar ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Build programme shortcut (onboarding)

    private var buildProgrammeRow: some View {
        NavigationLink {
            OnboardingView { profile in
                // Generate the starter programme via ProgrammeBuilder (port of
                // src/lib/programme.js), persist it, and mark it the active
                // programme. Mirrors enterApp() in src/App.jsx.
                Task { await app.enterApp(profile: profile,
                                          weights: profile.startingWeights) }
            }
        } label: {
            HStack(spacing: 14) {
                iconBox(name: "sparkles", accent: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ar ? "ابنِ برنامجي" : "Build my programme")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                    Text(ar
                         ? "٧ خطوات · مولّد تلقائياً"
                         : "7-step setup · auto-generated")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                }
                Spacer()
                Image(systemName: ar ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Manual builder shortcut

    private var manualBuilderRow: some View {
        NavigationLink {
            ManualProgrammeBuilder()
                .environmentObject(app)
        } label: {
            HStack(spacing: 14) {
                iconBox(name: "pencil.line", accent: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ar ? "بناء يدوي" : "Build manually")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                    Text(ar
                         ? "٦ خطوات · قابل للتخصيص"
                         : "6-step wizard · fully customisable")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                }
                Spacer()
                Image(systemName: ar ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Edit programme shortcut

    private var editProgrammeRow: some View {
        NavigationLink {
            ProgrammePage()
                .environmentObject(app)
        } label: {
            HStack(spacing: 14) {
                iconBox(name: "list.bullet.rectangle", accent: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ar ? "تعديل برنامجك" : "Edit programme")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                    Text(ar
                         ? "اعرض وعدّل كل الجلسات"
                         : "View and edit every session")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                }
                Spacer()
                Image(systemName: ar ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Calendar shortcut

    private var calendarRow: some View {
        NavigationLink {
            CalendarView()
        } label: {
            HStack(spacing: 14) {
                iconBox(name: "calendar", accent: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ar ? "تقويم التمارين" : "Workout calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                    Text(ar
                         ? "اعرض شهرك في لمحة"
                         : "See your month at a glance")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                }
                Spacer()
                Image(systemName: ar ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Import programme shortcut

    private var importProgrammeRow: some View {
        NavigationLink {
            ImportView()
        } label: {
            HStack(spacing: 14) {
                iconBox(name: "tray.and.arrow.down.fill", accent: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ar ? "استيراد برنامج" : "Import a programme")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                    Text(ar
                         ? "الصق JSON · دعم متعدد الأسابيع"
                         : "Paste JSON · multi-week support")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                }
                Spacer()
                Image(systemName: ar ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Danger zone

    private var dangerSection: some View {
        VStack(spacing: 10) {
            // Sign out
            dangerButton(
                icon: "rectangle.portrait.and.arrow.right",
                title: ar ? "تسجيل الخروج" : "Sign out",
                loading: false
            ) { showSignOutConfirm = true }

            // Reset all data
            dangerButton(
                icon: "arrow.counterclockwise",
                title: resetting
                    ? (ar ? "جارٍ إعادة التعيين…" : "Resetting…")
                    : (ar ? "إعادة تعيين كل البيانات" : "Reset all data"),
                loading: resetting
            ) { showResetConfirm = true }

            // Delete account
            dangerButton(
                icon: "trash",
                title: deleting
                    ? (ar ? "جارٍ الحذف…" : "Deleting…")
                    : (ar ? "حذف الحساب" : "Delete account"),
                loading: deleting,
                stronger: true
            ) { showDeleteConfirm = true }
        }
        .confirmationDialog(
            ar ? "إعادة تعيين كل البيانات؟" : "Reset all data?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(ar ? "نعم، احذف كل شيء" : "Yes, wipe everything",
                   role: .destructive) {
                Task { await runReset() }
            }
            Button(ar ? "إلغاء" : "Cancel", role: .cancel) {}
        } message: {
            Text(ar
                 ? "سيتم حذف برنامجك وكل جلساتك ومجموعاتك وأوزانك. لا يمكن التراجع."
                 : "Deletes your programme, all sessions, sets, weights, friends, and activity. Cannot be undone.")
        }
        .confirmationDialog(
            ar ? "حذف الحساب؟" : "Delete account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(ar ? "نعم، احذف حسابي" : "Yes, delete my account",
                   role: .destructive) {
                Task { await runDelete() }
            }
            Button(ar ? "إلغاء" : "Cancel", role: .cancel) {}
        } message: {
            Text(ar
                 ? "سيتم حذف ملفك الشخصي وكل بياناتك وسيتم تسجيل خروجك. للحذف النهائي للحساب من خوادمنا، راسل الدعم."
                 : "Deletes your profile + all data and signs you out. For full removal from our servers, contact support after.")
        }
    }

    @ViewBuilder
    private func dangerButton(
        icon: String,
        title: String,
        loading: Bool,
        stronger: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if loading {
                    ProgressView().tint(HexTheme.danger).scaleEffect(0.75)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .heavy))
                }
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundColor(HexTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(HexTheme.danger.opacity(stronger ? 0.16 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HexTheme.danger.opacity(stronger ? 0.45 : 0.30),
                            lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }

    @MainActor
    private func runReset() async {
        resetting = true
        defer { resetting = false }
        do {
            try await SupabaseManager.shared.resetUserData()
            // Refresh in-memory state so the UI reflects the wipe.
            app.activeProgramme = nil
            app.currentSession = nil
            app.workoutHistory = []
            app.friends = []
            app.pendingRequests = []
            app.activityFeed = []
            app.leaderboard = []
            app.workingWeights = [:]
            app.customExercises = []
            app.toast = ar ? "تم مسح بياناتك ✓" : "All data wiped ✓"
        } catch {
            print("[AccountView] resetUserData failed:", error)
            app.toast = ar ? "تعذّر مسح البيانات" : "Couldn't reset data"
        }
    }

    @MainActor
    private func runDelete() async {
        deleting = true
        defer { deleting = false }
        do {
            try await SupabaseManager.shared.deleteOwnAccount()
            // signOut inside deleteOwnAccount already cleared the session;
            // mirror it in AppState so ContentView swings back to login.
            app.currentProfile = nil
            app.activeProgramme = nil
            app.currentSession = nil
            app.workoutHistory = []
            app.friends = []
            app.pendingRequests = []
            app.activityFeed = []
            app.leaderboard = []
            app.workingWeights = [:]
            app.customExercises = []
            app.needsUsername = false
            app.authPhase = .signedOut
            app.toast = ar ? "تم حذف الحساب" : "Account deleted"
        } catch {
            print("[AccountView] deleteOwnAccount failed:", error)
            app.toast = ar ? "تعذّر حذف الحساب" : "Couldn't delete account"
        }
    }

    // MARK: - Row helpers

    private var divider: some View {
        Rectangle()
            .fill(HexTheme.border)
            .frame(height: 1)
            .padding(.leading, 60)
    }

    private func iconBox(name: String, accent: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent ? HexTheme.accent.opacity(0.10) : HexTheme.surface)
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accent ? HexTheme.accent : HexTheme.dim)
        }
        .frame(width: 32, height: 32)
    }

    @ViewBuilder
    private func infoRow(icon: String,
                         iconAccent: Bool,
                         label: String,
                         value: String?,
                         last: Bool) -> some View {
        HStack(spacing: 14) {
            iconBox(name: icon, accent: iconAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(HexTheme.mute)
                Text(value ?? "—")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(value == nil ? HexTheme.mute : HexTheme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            Image(systemName: "pencil")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(HexTheme.mute)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .kerning(ar ? 0 : 0.8)
            .foregroundColor(HexTheme.dim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Initial

    private var initial: String {
        let s = app.currentProfile?.name ?? app.currentProfile?.username ?? "?"
        return String(s.prefix(1)).uppercased()
    }

    // MARK: - Avatar fallback (initial on tinted circle)

    private var avatarFallback: some View {
        ZStack {
            Circle().fill(HexTheme.accent.opacity(0.12))
            Text(initial)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(HexTheme.accent)
        }
    }

    // MARK: - Avatar upload

    /// Read the picked photo, downscale to ≤ 1024px, upload as a new file
    /// in the `avatars` Supabase Storage bucket, then update
    /// `profile.avatar_url` and refresh the in-memory profile.
    @MainActor
    private func handleAvatarPick(_ item: PhotosPickerItem) async {
        guard let uid = SupabaseManager.shared.currentUser?.id else { return }
        uploadingAvatar = true
        defer { uploadingAvatar = false }

        do {
            // 1) Load image data
            guard let raw = try await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: raw) else {
                app.toast = ar ? "تعذّر قراءة الصورة" : "Couldn't read image"
                return
            }
            // 2) Downscale to ≤ 1024px on longest side, re-encode as JPEG 75%
            let scaled = downscale(img, max: 1024)
            guard let jpeg = scaled.jpegData(compressionQuality: 0.75) else {
                app.toast = ar ? "تعذّر ضغط الصورة" : "Couldn't compress image"
                return
            }
            // 3) Upload to Storage at avatars/<uid>/<timestamp>.jpg
            let path = "\(uid.uuidString)/\(Int(Date().timeIntervalSince1970)).jpg"
            _ = try await SupabaseManager.shared.client.storage
                .from("avatars")
                .upload(path,
                        data: jpeg,
                        options: FileOptions(contentType: "image/jpeg", upsert: true))
            // 4) Build the public URL
            let publicURL = try SupabaseManager.shared.client.storage
                .from("avatars")
                .getPublicURL(path: path)
            // 5) Persist on the profile row + refresh local state
            var profile = app.currentProfile ?? Profile(
                id: uid,
                name: nil, username: nil, email: nil, language: nil,
                trackedLifts: nil, trackedMuscles: nil,
                avatarURL: nil, createdAt: nil
            )
            profile.avatarURL = publicURL.absoluteString
            try await SupabaseManager.shared.upsertOwnProfile(profile)
            await app.loadOwnProfile()
            app.toast = ar ? "تم تحديث الصورة ✓" : "Avatar updated ✓"
        } catch {
            print("[AccountView] avatar upload failed:", error)
            app.toast = ar ? "تعذّر رفع الصورة" : "Upload failed"
        }
        avatarPick = nil
    }

    private func downscale(_ img: UIImage, max maxPx: CGFloat) -> UIImage {
        let w = img.size.width, h = img.size.height
        let longest = Swift.max(w, h)
        guard longest > maxPx else { return img }
        let scale: CGFloat = maxPx / longest
        let size = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
