import { useState, useRef, useEffect } from 'react';
import { motion } from 'framer-motion';
import { ChevronLeft, ChevronRight, User, Mail, Calendar, Dumbbell, Globe, LogOut, Trash2, UserX, Check, X, Shield } from 'lucide-react';
import { C, spring, springSoft } from '../tokens.js';
import { upsertProfile, updatePrivacySettings } from '../lib/db.js';
import { headingFont, translateContent } from '../lib/i18n.js';

// ── Privacy toggle row ─────────────────────────────────────────────────────────
function PrivacyRow({ label, description, enabled, onToggle, last }) {
  return (
    <div
      onClick={onToggle}
      style={{
        display: 'flex', alignItems: 'center', gap: 14,
        padding: '13px 16px',
        borderBottom: last ? 'none' : `1px solid ${C.border}`,
        cursor: 'pointer',
        WebkitTapHighlightColor: 'transparent',
      }}
    >
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 600, color: C.text }}>{label}</div>
        {description && (
          <div style={{ fontSize: 12, color: C.mute, marginTop: 2, lineHeight: 1.4 }}>{description}</div>
        )}
      </div>
      <motion.div
        animate={{ background: enabled ? C.accent : C.surface }}
        transition={{ duration: 0.2 }}
        style={{
          width: 44, height: 26, borderRadius: 13,
          border: `1.5px solid ${enabled ? C.accent : C.border}`,
          position: 'relative', flexShrink: 0,
          cursor: 'pointer',
        }}
      >
        <motion.div
          animate={{ x: enabled ? 20 : 2 }}
          transition={{ type: 'spring', stiffness: 500, damping: 35 }}
          style={{
            position: 'absolute', top: 2,
            width: 18, height: 18, borderRadius: '50%',
            background: enabled ? '#000' : C.dim,
          }}
        />
      </motion.div>
    </div>
  );
}

// ── Section wrapper ────────────────────────────────────────────────────────────
function Section({ title, children }) {
  return (
    <div style={{ marginBottom: 24 }}>
      <div style={{
        fontSize: 11, fontWeight: 700, letterSpacing: '0.08em',
        color: C.dim, marginBottom: 10,
      }}>
        {title}
      </div>
      <div style={{
        background: C.surface2, borderRadius: 14,
        border: `1px solid ${C.border}`, overflow: 'hidden',
      }}>
        {children}
      </div>
    </div>
  );
}

// ── Row ────────────────────────────────────────────────────────────────────────
function Row({ icon: Icon, label, value, onEdit, suffix, accent, last }) {
  return (
    <div
      onClick={onEdit}
      style={{
        display: 'flex', alignItems: 'center', gap: 14,
        padding: '14px 16px',
        borderBottom: last ? 'none' : `1px solid ${C.border}`,
        cursor: onEdit ? 'pointer' : 'default',
        WebkitTapHighlightColor: 'transparent',
      }}
    >
      <div style={{
        width: 32, height: 32, borderRadius: 8, flexShrink: 0,
        background: accent ? 'rgba(184,255,0,0.1)' : C.surface,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <Icon size={15} color={accent ? C.accent : C.dim} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 11, color: C.mute, marginBottom: 2 }}>{label}</div>
        <div style={{
          fontSize: 14, fontWeight: 600, color: C.text,
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        }}>
          {value || <span style={{ color: C.mute }}>—</span>}
        </div>
      </div>
      {suffix}
      {onEdit && <ChevronRight size={14} color={C.mute} />}
    </div>
  );
}

// ── Inline name editor ─────────────────────────────────────────────────────────
function NameEditor({ value, onSave, onCancel }) {
  const [draft, setDraft] = useState(value);
  const inputRef = useRef(null);

  useEffect(() => { inputRef.current?.focus(); }, []);

  const commit = () => {
    if (draft.trim()) onSave(draft.trim());
    else onCancel();
  };

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 16px', borderBottom: `1px solid ${C.border}` }}>
      <div style={{ width: 32, height: 32, borderRadius: 8, flexShrink: 0, background: 'rgba(184,255,0,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <User size={15} color={C.accent} />
      </div>
      <input
        ref={inputRef}
        value={draft}
        onChange={e => setDraft(e.target.value)}
        onKeyDown={e => { if (e.key === 'Enter') commit(); if (e.key === 'Escape') onCancel(); }}
        style={{
          flex: 1, background: C.surface, border: `1.5px solid ${C.accent}`,
          borderRadius: 8, padding: '7px 10px', color: C.text, fontSize: 14,
          outline: 'none', fontFamily: 'inherit',
        }}
      />
      <motion.button whileTap={{ scale: 0.9 }} onClick={commit}
        style={{ background: C.accent, border: 'none', borderRadius: 7, width: 30, height: 30, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', flexShrink: 0 }}>
        <Check size={14} color="#000" strokeWidth={3} />
      </motion.button>
      <motion.button whileTap={{ scale: 0.9 }} onClick={onCancel}
        style={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 7, width: 30, height: 30, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', flexShrink: 0 }}>
        <X size={14} color={C.mute} />
      </motion.button>
    </div>
  );
}

// ── AccountPage ────────────────────────────────────────────────────────────────
export default function AccountPage({ state, onBack }) {
  const {
    user, profile, setProfile,
    lang, setLang,
    logout, resetAllData, deleteAccount,
    programmeMode, importedProgramme, programme,
    currentWeek, history,
    showToast, t,
    privacySettings, setPrivacySettings,
  } = state;

  const [editingName,    setEditingName]    = useState(false);
  const [logoutConfirm,  setLogoutConfirm]  = useState(false);
  const [resetConfirm,   setResetConfirm]   = useState(false);
  const [resetting,      setResetting]      = useState(false);
  const [deleteConfirm,  setDeleteConfirm]  = useState(false);
  const [deleting,       setDeleting]       = useState(false);

  // ── Privacy settings (defaults: everything visible to friends) ───────────────
  const privacy = privacySettings || {
    showSessions: true,
    showWeights:  true,
    showProgress: true,
    showOnLeaderboard: true,
  };

  const togglePrivacy = async (key) => {
    const updated = { ...privacy, [key]: !privacy[key] };
    setPrivacySettings?.(updated);
    const uid = user?.id;
    if (uid) {
      try {
        await updatePrivacySettings(uid, updated);
      } catch {
        // revert on error
        setPrivacySettings?.(privacy);
        showToast?.('⚠ Failed to save privacy setting');
      }
    }
  };

  const rtl     = lang === 'ar';
  const BackIcon = rtl ? ChevronRight : ChevronLeft;

  // ── Derived display values ─────────────────────────────────────────────────
  const memberSince = user?.created_at
    ? new Date(user.created_at).toLocaleDateString(lang === 'ar' ? 'ar-SA' : 'en-GB', {
        year: 'numeric', month: 'long', day: 'numeric',
      })
    : '—';

  const programmeName = (() => {
    if (programmeMode === 'imported') {
      return translateContent(importedProgramme?.name, lang) || '—';
    }
    if (programme?.length) return lang === 'ar' ? 'مولّد تلقائياً' : 'Auto-generated';
    return '—';
  })();

  const programmeStart = history.length > 0
    ? new Date(history[0].date).toLocaleDateString(lang === 'ar' ? 'ar-SA' : 'en-GB', {
        year: 'numeric', month: 'short', day: 'numeric',
      })
    : (lang === 'ar' ? 'لم يبدأ بعد' : 'Not started yet');

  // ── Save name ──────────────────────────────────────────────────────────────
  const saveName = async (newName) => {
    setEditingName(false);
    const uid = user?.id;
    if (!uid || !newName) return;
    setProfile(p => ({ ...p, name: newName }));
    await upsertProfile(uid, { name: newName, lang });
    showToast(lang === 'ar' ? 'تم تحديث الاسم ✓' : 'Name updated ✓');
  };

  // ── Logout ─────────────────────────────────────────────────────────────────
  const handleLogout = async () => {
    if (!logoutConfirm) { setLogoutConfirm(true); setResetConfirm(false); return; }
    await logout();
  };

  // ── Reset all data ─────────────────────────────────────────────────────────
  const handleReset = async () => {
    setResetting(true);
    try {
      await resetAllData();
      // resetAllData calls resetAppState which sends the user to welcome —
      // the AccountPage will unmount automatically, no need to call onBack
    } catch {
      // error toast already shown by resetAllData
    } finally {
      setResetting(false);
      setResetConfirm(false);
    }
  };

  // ── Delete account ─────────────────────────────────────────────────────────
  // deleteAccount() in App.jsx never throws — it always cleans up in its
  // finally block and transitions authState → 'unauthenticated', which unmounts
  // this component. setDeleting(true) just shows the spinner while it runs.
  const handleDeleteAccount = async () => {
    setDeleting(true);
    await deleteAccount();
    // Component will unmount via auth state change — no need to reset local state
  };

  return (
    <motion.div
      initial={{ x: rtl ? '-100%' : '100%' }}
      animate={{ x: 0 }}
      exit={{ x: rtl ? '-100%' : '100%' }}
      transition={springSoft}
      style={{
        position: 'absolute', inset: 0, background: C.bg, zIndex: 200,
        display: 'flex', flexDirection: 'column', overflow: 'hidden', willChange: 'transform',
      }}
    >
      {/* ── Top bar ── */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '12px 20px',
        paddingTop: 'max(env(safe-area-inset-top, 0px) + 12px, 20px)',
        borderBottom: `1px solid ${C.border}`, flexShrink: 0, background: C.surface,
      }}>
        <motion.button
          whileTap={{ scale: 0.93 }}
          onClick={onBack}
          style={{
            background: C.surface2, border: `1.5px solid ${C.border}`,
            borderRadius: 8, width: 36, height: 36,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', touchAction: 'manipulation',
            WebkitTapHighlightColor: 'transparent', flexShrink: 0,
          }}
        >
          <BackIcon size={18} color={C.text} />
        </motion.button>

        <div>
          <div style={{
            fontSize: 16, fontWeight: 800, color: C.text,
            letterSpacing: rtl ? '0' : '-0.02em',
            fontFamily: headingFont(lang),
          }}>
            {lang === 'ar' ? 'الحساب' : 'Account'}
          </div>
          <div style={{ fontSize: 11, color: C.mute, marginTop: 1 }}>
            {user?.email}
          </div>
        </div>
      </div>

      {/* ── Scrollable content ── */}
      <div style={{
        flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch',
        padding: '20px 16px',
        paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 20px, 32px)',
      }}>

        {/* ── PROFILE ── */}
        <Section title={lang === 'ar' ? 'الملف الشخصي' : 'PROFILE'}>
          {editingName
            ? <NameEditor value={profile?.name || ''} onSave={saveName} onCancel={() => setEditingName(false)} />
            : (
              <Row
                icon={User} label={lang === 'ar' ? 'الاسم' : 'Name'}
                value={profile?.name || (lang === 'ar' ? 'لم يُحدد' : 'Not set')}
                onEdit={() => setEditingName(true)}
                accent
              />
            )
          }
          <Row
            icon={Mail} label={lang === 'ar' ? 'البريد الإلكتروني' : 'Email'}
            value={user?.email}
          />
          <Row
            icon={Calendar} label={lang === 'ar' ? 'عضو منذ' : 'Member since'}
            value={memberSince}
            last
          />
        </Section>

        {/* ── PROGRAMME ── */}
        <Section title={lang === 'ar' ? 'البرنامج' : 'PROGRAMME'}>
          <Row
            icon={Dumbbell} label={lang === 'ar' ? 'البرنامج النشط' : 'Active programme'}
            value={programmeName}
            accent
          />
          <Row
            icon={Calendar} label={lang === 'ar' ? 'تاريخ البدء' : 'Start date'}
            value={programmeStart}
          />
          <Row
            icon={Calendar} label={lang === 'ar' ? 'الأسبوع الحالي' : 'Current week'}
            value={
              lang === 'ar'
                ? `الأسبوع ${currentWeek} · ${history.length} جلسة`
                : `Week ${currentWeek} · ${history.length} session${history.length !== 1 ? 's' : ''} logged`
            }
            last
          />
        </Section>

        {/* ── PREFERENCES ── */}
        <Section title={lang === 'ar' ? 'التفضيلات' : 'PREFERENCES'}>
          <Row
            icon={Globe}
            label={lang === 'ar' ? 'اللغة' : 'Language'}
            value={lang === 'ar' ? 'العربية' : 'English'}
            accent
            last
            suffix={
              <motion.button
                whileTap={{ scale: 0.95 }}
                onClick={() => setLang(lang === 'ar' ? 'en' : 'ar')}
                style={{
                  background: C.surface, border: `1.5px solid ${C.border}`,
                  borderRadius: 8, padding: '5px 14px',
                  fontSize: 12, fontWeight: 700, color: C.text,
                  cursor: 'pointer', touchAction: 'manipulation',
                  WebkitTapHighlightColor: 'transparent',
                  fontFamily: 'Inter, system-ui, sans-serif',
                  flexShrink: 0,
                }}
              >
                {lang === 'ar' ? 'EN' : 'AR'}
              </motion.button>
            }
          />
        </Section>

        {/* ── PRIVACY ── */}
        <Section title={lang === 'ar' ? 'الخصوصية' : 'PRIVACY (GYM BROS)'}>
          <PrivacyRow
            label="Show sessions to Bros"
            description="Friends can see your recent workouts"
            enabled={privacy.showSessions}
            onToggle={() => togglePrivacy('showSessions')}
          />
          <PrivacyRow
            label="Show working weights to Bros"
            description="Friends can see your current lifting weights"
            enabled={privacy.showWeights}
            onToggle={() => togglePrivacy('showWeights')}
          />
          <PrivacyRow
            label="Show progress to Bros"
            description="Friends can see your muscle improvement chart"
            enabled={privacy.showProgress}
            onToggle={() => togglePrivacy('showProgress')}
          />
          <PrivacyRow
            label="Appear on leaderboard"
            description="Show your session count in the Bros leaderboard"
            enabled={privacy.showOnLeaderboard}
            onToggle={() => togglePrivacy('showOnLeaderboard')}
            last
          />
        </Section>

        {/* ── DANGER ZONE ── */}
        <Section title={lang === 'ar' ? 'منطقة الخطر' : 'DANGER ZONE'}>
          <div style={{ padding: '14px 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>

            {/* ── Sign out ── */}
            {logoutConfirm ? (
              <div>
                <p style={{ fontSize: 13, color: C.dim, marginBottom: 12, lineHeight: 1.5 }}>
                  {lang === 'ar'
                    ? 'هل أنت متأكد؟ ستحتاج إلى تسجيل الدخول مرة أخرى.'
                    : "Are you sure? You'll need to sign in again to access your data."}
                </p>
                <div style={{ display: 'flex', gap: 10 }}>
                  <motion.button whileTap={{ scale: 0.97 }} onClick={handleLogout}
                    style={{
                      flex: 1, background: 'rgba(255,80,80,0.12)',
                      border: '1.5px solid rgba(255,80,80,0.4)',
                      borderRadius: 10, padding: '12px 0',
                      fontSize: 14, fontWeight: 800, color: '#ff6b6b',
                      cursor: 'pointer', touchAction: 'manipulation',
                      WebkitTapHighlightColor: 'transparent',
                    }}>
                    {lang === 'ar' ? 'نعم، اخرج' : 'Yes, sign out'}
                  </motion.button>
                  <motion.button whileTap={{ scale: 0.97 }} onClick={() => setLogoutConfirm(false)}
                    style={{
                      flex: 1, background: C.surface, border: `1.5px solid ${C.border}`,
                      borderRadius: 10, padding: '12px 0',
                      fontSize: 14, fontWeight: 700, color: C.dim,
                      cursor: 'pointer', touchAction: 'manipulation',
                      WebkitTapHighlightColor: 'transparent',
                    }}>
                    {lang === 'ar' ? 'إلغاء' : 'Cancel'}
                  </motion.button>
                </div>
              </div>
            ) : (
              <motion.button whileTap={{ scale: 0.97 }} onClick={handleLogout}
                style={{
                  width: '100%', background: 'rgba(255,80,80,0.08)',
                  border: '1.5px solid rgba(255,80,80,0.3)',
                  borderRadius: 10, padding: '13px 0',
                  fontSize: 14, fontWeight: 700, color: '#ff6b6b',
                  cursor: 'pointer', touchAction: 'manipulation',
                  WebkitTapHighlightColor: 'transparent',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
                }}>
                <LogOut size={15} color="#ff6b6b" />
                {lang === 'ar' ? 'تسجيل الخروج' : 'Sign out'}
              </motion.button>
            )}

            {/* ── Divider ── */}
            <div style={{ borderTop: `1px solid ${C.border}`, margin: '2px 0' }} />

            {/* ── Reset all data ── */}
            {resetConfirm ? (
              <div>
                <p style={{ fontSize: 14, fontWeight: 700, color: '#ff6b6b', marginBottom: 6 }}>
                  {lang === 'ar' ? 'مسح جميع البيانات' : 'Reset all data'}
                </p>
                <p style={{ fontSize: 13, color: C.dim, marginBottom: 14, lineHeight: 1.55 }}>
                  {lang === 'ar'
                    ? 'سيؤدي هذا إلى حذف برنامجك وسجل جلساتك وتقدمك بشكل دائم. لا يمكن التراجع عن هذا.'
                    : 'This will permanently delete your programme, all session history, and progress. This cannot be undone.'}
                </p>
                <div style={{ display: 'flex', gap: 10 }}>
                  <motion.button whileTap={{ scale: 0.97 }} onClick={handleReset}
                    disabled={resetting}
                    style={{
                      flex: 1,
                      background: resetting ? 'rgba(255,80,80,0.06)' : 'rgba(255,80,80,0.18)',
                      border: '1.5px solid rgba(255,80,80,0.5)',
                      borderRadius: 10, padding: '12px 0',
                      fontSize: 14, fontWeight: 800, color: '#ff6b6b',
                      cursor: resetting ? 'default' : 'pointer',
                      touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                      opacity: resetting ? 0.6 : 1,
                    }}>
                    {resetting
                      ? (lang === 'ar' ? 'جارٍ الحذف…' : 'Deleting…')
                      : (lang === 'ar' ? 'حذف كل شيء' : 'Delete everything')}
                  </motion.button>
                  <motion.button whileTap={{ scale: 0.97 }}
                    onClick={() => setResetConfirm(false)}
                    disabled={resetting}
                    style={{
                      flex: 1, background: C.surface, border: `1.5px solid ${C.border}`,
                      borderRadius: 10, padding: '12px 0',
                      fontSize: 14, fontWeight: 700, color: C.dim,
                      cursor: resetting ? 'default' : 'pointer',
                      touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                    }}>
                    {lang === 'ar' ? 'إلغاء' : 'Cancel'}
                  </motion.button>
                </div>
              </div>
            ) : (
              <motion.button whileTap={{ scale: 0.97 }}
                onClick={() => { setResetConfirm(true); setLogoutConfirm(false); setDeleteConfirm(false); }}
                style={{
                  width: '100%', background: 'transparent',
                  border: '1.5px solid rgba(255,80,80,0.3)',
                  borderRadius: 10, padding: '13px 0',
                  fontSize: 14, fontWeight: 700, color: '#ff6b6b',
                  cursor: 'pointer', touchAction: 'manipulation',
                  WebkitTapHighlightColor: 'transparent',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
                }}>
                <Trash2 size={15} color="#ff6b6b" />
                {lang === 'ar' ? 'مسح جميع البيانات' : 'Reset all data'}
              </motion.button>
            )}

            {/* ── Divider ── */}
            <div style={{ borderTop: `1px solid ${C.border}`, margin: '2px 0' }} />

            {/* ── Delete account ── */}
            {deleteConfirm ? (
              <div>
                <p style={{ fontSize: 14, fontWeight: 700, color: '#ff6b6b', marginBottom: 6 }}>
                  Delete account
                </p>
                <p style={{ fontSize: 13, color: C.dim, marginBottom: 14, lineHeight: 1.55 }}>
                  This will permanently delete your account, programme, all session history, and progress.
                  This cannot be undone and you will not be able to recover your data.
                </p>
                <div style={{ display: 'flex', gap: 10 }}>
                  <motion.button whileTap={{ scale: 0.97 }} onClick={handleDeleteAccount}
                    disabled={deleting}
                    style={{
                      flex: 1,
                      background: deleting ? 'rgba(255,80,80,0.06)' : 'rgba(255,80,80,0.18)',
                      border: '1.5px solid rgba(255,80,80,0.5)',
                      borderRadius: 10, padding: '12px 0',
                      fontSize: 14, fontWeight: 800, color: '#ff6b6b',
                      cursor: deleting ? 'default' : 'pointer',
                      touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                      opacity: deleting ? 0.6 : 1,
                    }}>
                    {deleting ? 'Deleting…' : 'Delete my account'}
                  </motion.button>
                  <motion.button whileTap={{ scale: 0.97 }}
                    onClick={() => setDeleteConfirm(false)}
                    disabled={deleting}
                    style={{
                      flex: 1, background: C.surface, border: `1.5px solid ${C.border}`,
                      borderRadius: 10, padding: '12px 0',
                      fontSize: 14, fontWeight: 700, color: C.dim,
                      cursor: deleting ? 'default' : 'pointer',
                      touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                    }}>
                    Cancel
                  </motion.button>
                </div>
              </div>
            ) : (
              <motion.button whileTap={{ scale: 0.97 }}
                onClick={() => { setDeleteConfirm(true); setLogoutConfirm(false); setResetConfirm(false); }}
                style={{
                  width: '100%', background: 'transparent',
                  border: '1.5px solid rgba(255,80,80,0.3)',
                  borderRadius: 10, padding: '13px 0',
                  fontSize: 14, fontWeight: 700, color: '#ff6b6b',
                  cursor: 'pointer', touchAction: 'manipulation',
                  WebkitTapHighlightColor: 'transparent',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
                }}>
                <UserX size={15} color="#ff6b6b" />
                Delete account
              </motion.button>
            )}

          </div>
        </Section>

      </div>
    </motion.div>
  );
}
