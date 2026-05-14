import SwiftUI

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
                    importProgrammeRow
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
                Circle()
                    .fill(HexTheme.accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle().stroke(HexTheme.border, lineWidth: 2)
                    )
                    .overlay(
                        Text(initial)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(HexTheme.accent)
                    )

                // Camera button bottom-right
                Button { /* TODO: image picker */ } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(HexTheme.accent))
                        .overlay(
                            Circle().stroke(HexTheme.bg, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
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
            OnboardingView { _ in
                // TODO: persist OnboardingProfile to Supabase + generate
                // a starter programme based on the answers.
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
            Button { showSignOutConfirm = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .heavy))
                    Text(ar ? "تسجيل الخروج" : "Sign out")
                        .font(.system(size: 14, weight: .heavy))
                }
                .foregroundColor(HexTheme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(HexTheme.danger.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(HexTheme.danger.opacity(0.30), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
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
}
