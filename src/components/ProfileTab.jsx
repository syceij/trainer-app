import { useState, useRef, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  Camera, User, Mail, Calendar, Dumbbell, Globe,
  LogOut, Trash2, UserX, Check, X, Shield, AtSign, Lock,
} from 'lucide-react';
import { C, springSoft } from '../tokens.js';
import { upsertProfile, updatePrivacySettings } from '../lib/db.js';
import { headingFont, translateContent } from '../lib/i18n.js';
import { hapticHeavy, hapticLight } from '../lib/haptics.js';

// ── Image compressor (canvas) ─────────────────────────────────────────────────
function compressImage(file, maxPx = 220) {
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        const scale = Math.min(maxPx / img.width, maxPx / img.height, 1);
        const canvas = document.createElement('canvas');
        canvas.width  = Math.round(img.width  * scale);
        canvas.height = Math.round(img.height * scale);
        const ctx = canvas.getContext('2d');
        // Draw a circular clip so the base64 is a circle crop
        ctx.beginPath();
        ctx.arc(canvas.width / 2, canvas.height / 2, Math.min(canvas.width, canvas.height) / 2, 0, Math.PI * 2);
        ctx.clip();
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        resolve(canvas.toDataURL('image/jpeg', 0.80));
      };
      img.src = e.target.result;
    };
    reader.readAsDataURL(file);
  });
}

// ── Privacy toggle row ────────────────────────────────────────────────────────
function PrivacyRow({ label, description, enabled, onToggle, last }) {
  return (
    <div
      onClick={onToggle}
      style={{
        display: 'flex', alignItems: 'center', gap: 14,
        padding: '13px 16px',
        borderBottom: last ? 'none' : `1px solid ${C.border}`,
        cursor: 'pointer', WebkitTapHighlightColor: 'transparent',
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
          position: 'relative', flexShrink: 0, cursor: 'pointer',
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

// ── Section wrapper ───────────────────────────────────────────────────────────
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

// ── Info row ──────────────────────────────────────────────────────────────────
function Row({ icon: Icon, label, value, onEdit, suffix, accent, last, note }) {
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
        {note && <div style={{ fontSize: 11, color: C.mute, marginTop: 2 }}>{note}</div>}
      </div>
      {suffix}
      {onEdit && !suffix && <div style={{ width: 14 }} />}
    </div>
  );
}

// ── Inline name editor ────────────────────────────────────────────────────────
function NameEditor({ value, onSave, onCancel }) {
  const [draft, setDraft] = useState(value);
  const inputRef = useRef(null);
  useEffect(() => { inputRef.current?.focus(); }, []);
  const commit = () => { if (draft.trim()) onSave(draft.trim()); else onCancel(); };
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

// ── ProfileTab ────────────────────────────────────────────────────────────────
export default function ProfileTab({ state }) {
  const {
    user, profile, setProfile,
    lang, setLang,
    logout, resetAllData, deleteAccount,
    programmeMode, importedProgramme, programme,
    currentWeek, history,
    showToast, t,
    privacySettings, setPrivacySettings,
    username,
    avatarUrl, saveAvatarUrl,
  } = state;

  const ar = lang === 'ar';

  const [editingName,   setEditingName]   = useState(false);
  const [logoutConfirm, setLogoutConfirm] = useState(false);
  const [resetConfirm,  setResetConfirm]  = useState(false);
  const [resetting,     setResetting]     = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState(false);
  const [deleting,      setDeleting]      = useState(false);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);

  const fileInputRef = useRef(null);

  // ── Privacy defaults ──────────────────────────────────────────────────────
  const privacy = privacySettings || {
    showSessions: true, showWeights: true,
    showProgress: true, showOnLeaderboard: true,
  };

  const togglePrivacy = async (key) => {
    const updated = { ...privacy, [key]: !privacy[key] };
    setPrivacySettings?.(updated);
    const uid = user?.id;
    if (uid) {
      try { await updatePrivacySettings(uid, updated); }
      catch { setPrivacySettings?.(privacy); showToast?.('⚠ Failed to save privacy setting'); }
    }
  };

  // ── Derived display values ────────────────────────────────────────────────
  const memberSince = user?.created_at
    ? new Date(user.created_at).toLocaleDateString(ar ? 'ar-SA' : 'en-GB', {
        year: 'numeric', month: 'long', day: 'numeric',
      })
    : '—';

  const programmeName = (() => {
    if (programmeMode === 'imported') return translateContent(importedProgramme?.name, lang) || '—';
    if (programme?.length) return ar ? 'مولّد تلقائياً' : 'Auto-generated';
    return '—';
  })();

  const programmeStart = history.length > 0
    ? new Date(history[0].date).toLocaleDateString(ar ? 'ar-SA' : 'en-GB', {
        year: 'numeric', month: 'short', day: 'numeric',
      })
    : (ar ? 'لم يبدأ بعد' : 'Not started yet');

  // ── Handlers ──────────────────────────────────────────────────────────────
  const saveName = async (newName) => {
    setEditingName(false);
    const uid = user?.id;
    if (!uid || !newName) return;
    setProfile(p => ({ ...p, name: newName }));
    await upsertProfile(uid, { name: newName, lang });
    showToast(ar ? 'تم تحديث الاسم ✓' : 'Name updated ✓');
  };

  const handlePhotoChange = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingPhoto(true);
    hapticLight();
    try {
      const compressed = await compressImage(file, 220);
      await saveAvatarUrl(compressed);
      showToast(ar ? 'تم تحديث الصورة ✓' : 'Photo updated ✓');
    } catch {
      showToast(ar ? '⚠ فشل تحديث الصورة' : '⚠ Photo upload failed');
    } finally {
      setUploadingPhoto(false);
      // Reset file input so the same file can be picked again
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handleLogout = async () => {
    if (!logoutConfirm) { setLogoutConfirm(true); setResetConfirm(false); return; }
    hapticHeavy();
    await logout();
  };

  const handleReset = async () => {
    hapticHeavy();
    setResetting(true);
    try { await resetAllData(); }
    catch { /* toast already shown */ }
    finally { setResetting(false); setResetConfirm(false); }
  };

  const handleDeleteAccount = async () => {
    hapticHeavy();
    setDeleting(true);
    await deleteAccount();
  };

  const displayName = profile?.name || (ar ? 'لاعب' : 'Athlete');

  return (
    <div style={{
      padding: '0 16px',
      paddingTop: 'max(env(safe-area-inset-top, 0px) + 16px, 24px)',
    }}>

      {/* ── Page title ── */}
      <h1 style={{
        fontSize: 26, fontWeight: 800, letterSpacing: ar ? '0' : '-0.02em',
        color: C.text, marginBottom: 20,
        fontFamily: headingFont(lang),
      }}>
        {ar ? 'الملف الشخصي' : 'Profile'}
      </h1>

      {/* ── Avatar hero ── */}
      <div style={{
        display: 'flex', flexDirection: 'column', alignItems: 'center',
        marginBottom: 28, gap: 12,
      }}>
        {/* Avatar circle with camera overlay */}
        <div style={{ position: 'relative', cursor: 'pointer' }}
          onClick={() => fileInputRef.current?.click()}
        >
          {/* Photo or initial */}
          <div style={{
            width: 90, height: 90, borderRadius: '50%',
            border: `3px solid ${C.accent}`,
            overflow: 'hidden',
            background: avatarUrl ? 'transparent' : 'rgba(184,255,0,0.1)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 0 24px rgba(184,255,0,0.18)',
          }}>
            {avatarUrl ? (
              <img src={avatarUrl} alt="avatar"
                style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            ) : (
              <span style={{ fontSize: 36, fontWeight: 800, color: C.accent }}>
                {displayName[0]?.toUpperCase() || '?'}
              </span>
            )}
          </div>

          {/* Camera badge */}
          <motion.div
            animate={{ scale: uploadingPhoto ? [1, 0.9, 1] : 1 }}
            transition={{ repeat: uploadingPhoto ? Infinity : 0, duration: 0.6 }}
            style={{
              position: 'absolute', bottom: 0, right: 0,
              width: 28, height: 28, borderRadius: '50%',
              background: C.accent,
              border: `2px solid ${C.bg}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}
          >
            <Camera size={13} color="#000" strokeWidth={2.5} />
          </motion.div>
        </div>

        {/* Hidden file input */}
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handlePhotoChange}
          style={{ display: 'none' }}
        />

        {/* Name + @username */}
        <div style={{ textAlign: 'center' }}>
          <div style={{
            fontSize: 20, fontWeight: 800, color: C.text,
            letterSpacing: ar ? '0' : '-0.01em',
            fontFamily: headingFont(lang),
          }}>
            {displayName}
          </div>
          {username && (
            <div style={{ fontSize: 13, color: C.dim, marginTop: 2 }}>@{username}</div>
          )}
          <div style={{ fontSize: 12, color: C.mute, marginTop: 2 }}>{user?.email}</div>
        </div>

        {/* Tap hint */}
        <div style={{ fontSize: 11, color: C.mute }}>
          {ar ? 'اضغط على الصورة لتغييرها' : 'Tap photo to change'}
        </div>
      </div>

      {/* ── PROFILE section ── */}
      <Section title={ar ? 'الملف الشخصي' : 'PROFILE'}>
        {editingName
          ? <NameEditor value={profile?.name || ''} onSave={saveName} onCancel={() => setEditingName(false)} />
          : (
            <Row
              icon={User} label={ar ? 'الاسم' : 'Name'}
              value={profile?.name || (ar ? 'لم يُحدد' : 'Not set')}
              onEdit={() => setEditingName(true)}
              accent
            />
          )
        }
        <Row
          icon={AtSign}
          label={ar ? 'اسم المستخدم' : 'Username'}
          value={username ? `@${username}` : (ar ? 'لم يُحدد' : 'Not set')}
          suffix={<Lock size={14} color={C.mute} style={{ flexShrink: 0 }} />}
          note={ar ? 'لا يمكن تغيير اسم المستخدم' : 'Username cannot be changed'}
        />
        <Row
          icon={Mail} label={ar ? 'البريد الإلكتروني' : 'Email'}
          value={user?.email}
        />
        <Row
          icon={Calendar} label={ar ? 'عضو منذ' : 'Member since'}
          value={memberSince}
          last
        />
      </Section>

      {/* ── PROGRAMME ── */}
      <Section title={ar ? 'البرنامج' : 'PROGRAMME'}>
        <Row
          icon={Dumbbell} label={ar ? 'البرنامج النشط' : 'Active programme'}
          value={programmeName}
          accent
        />
        <Row
          icon={Calendar} label={ar ? 'تاريخ البدء' : 'Start date'}
          value={programmeStart}
        />
        <Row
          icon={Calendar} label={ar ? 'الأسبوع الحالي' : 'Current week'}
          value={
            ar
              ? `الأسبوع ${currentWeek} · ${history.length} جلسة`
              : `Week ${currentWeek} · ${history.length} session${history.length !== 1 ? 's' : ''} logged`
          }
          last
        />
      </Section>

      {/* ── PREFERENCES ── */}
      <Section title={ar ? 'التفضيلات' : 'PREFERENCES'}>
        <Row
          icon={Globe}
          label={ar ? 'اللغة' : 'Language'}
          value={ar ? 'العربية' : 'English'}
          accent
          last
          suffix={
            <motion.button
              whileTap={{ scale: 0.95 }}
              onClick={() => setLang(ar ? 'en' : 'ar')}
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
              {ar ? 'EN' : 'AR'}
            </motion.button>
          }
        />
      </Section>

      {/* ── PRIVACY ── */}
      <Section title={ar ? 'الخصوصية (أصدقاء الصالة)' : 'PRIVACY (GYM BROS)'}>
        <PrivacyRow
          label={ar ? 'إظهار الجلسات للأصدقاء' : 'Show sessions to Bros'}
          description={ar ? 'يمكن لأصدقائك رؤية تمارينك الأخيرة' : 'Friends can see your recent workouts'}
          enabled={privacy.showSessions}
          onToggle={() => togglePrivacy('showSessions')}
        />
        <PrivacyRow
          label={ar ? 'إظهار الأوزان للأصدقاء' : 'Show working weights to Bros'}
          description={ar ? 'يمكن لأصدقائك رؤية أوزانك الحالية' : 'Friends can see your current lifting weights'}
          enabled={privacy.showWeights}
          onToggle={() => togglePrivacy('showWeights')}
        />
        <PrivacyRow
          label={ar ? 'إظهار التقدم للأصدقاء' : 'Show progress to Bros'}
          description={ar ? 'يمكن لأصدقائك رؤية مخطط تقدمك' : 'Friends can see your muscle improvement chart'}
          enabled={privacy.showProgress}
          onToggle={() => togglePrivacy('showProgress')}
        />
        <PrivacyRow
          label={ar ? 'الظهور في قائمة المتصدرين' : 'Appear on leaderboard'}
          description={ar ? 'أظهر نقاطك في قائمة متصدري الأصدقاء' : 'Show your session count in the Bros leaderboard'}
          enabled={privacy.showOnLeaderboard}
          onToggle={() => togglePrivacy('showOnLeaderboard')}
          last
        />
      </Section>

      {/* ── DANGER ZONE ── */}
      <Section title={ar ? 'منطقة الخطر' : 'DANGER ZONE'}>
        <div style={{ padding: '14px 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>

          {/* Sign out */}
          {logoutConfirm ? (
            <div>
              <p style={{ fontSize: 13, color: C.dim, marginBottom: 12, lineHeight: 1.5 }}>
                {ar ? 'هل أنت متأكد؟ ستحتاج إلى تسجيل الدخول مرة أخرى.' : "Are you sure? You'll need to sign in again."}
              </p>
              <div style={{ display: 'flex', gap: 10 }}>
                <motion.button whileTap={{ scale: 0.97 }} onClick={handleLogout}
                  style={{ flex: 1, background: 'rgba(255,80,80,0.12)', border: '1.5px solid rgba(255,80,80,0.4)', borderRadius: 10, padding: '12px 0', fontSize: 14, fontWeight: 800, color: '#ff6b6b', cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent' }}>
                  {ar ? 'نعم، اخرج' : 'Yes, sign out'}
                </motion.button>
                <motion.button whileTap={{ scale: 0.97 }} onClick={() => setLogoutConfirm(false)}
                  style={{ flex: 1, background: C.surface, border: `1.5px solid ${C.border}`, borderRadius: 10, padding: '12px 0', fontSize: 14, fontWeight: 700, color: C.dim, cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent' }}>
                  {ar ? 'إلغاء' : 'Cancel'}
                </motion.button>
              </div>
            </div>
          ) : (
            <motion.button whileTap={{ scale: 0.97 }} onClick={handleLogout}
              style={{ width: '100%', background: 'rgba(255,80,80,0.08)', border: '1.5px solid rgba(255,80,80,0.3)', borderRadius: 10, padding: '13px 0', fontSize: 14, fontWeight: 700, color: '#ff6b6b', cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
              <LogOut size={15} color="#ff6b6b" />
              {ar ? 'تسجيل الخروج' : 'Sign out'}
            </motion.button>
          )}

          <div style={{ borderTop: `1px solid ${C.border}`, margin: '2px 0' }} />

          {/* Reset all data */}
          {resetConfirm ? (
            <div>
              <p style={{ fontSize: 14, fontWeight: 700, color: '#ff6b6b', marginBottom: 6 }}>
                {ar ? 'مسح جميع البيانات' : 'Reset all data'}
              </p>
              <p style={{ fontSize: 13, color: C.dim, marginBottom: 14, lineHeight: 1.55 }}>
                {ar ? 'سيؤدي هذا إلى حذف برنامجك وسجل جلساتك وتقدمك بشكل دائم. لا يمكن التراجع عن هذا.' : 'This will permanently delete your programme, all session history, and progress. This cannot be undone.'}
              </p>
              <div style={{ display: 'flex', gap: 10 }}>
                <motion.button whileTap={{ scale: 0.97 }} onClick={handleReset} disabled={resetting}
                  style={{ flex: 1, background: resetting ? 'rgba(255,80,80,0.06)' : 'rgba(255,80,80,0.18)', border: '1.5px solid rgba(255,80,80,0.5)', borderRadius: 10, padding: '12px 0', fontSize: 14, fontWeight: 800, color: '#ff6b6b', cursor: resetting ? 'default' : 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent', opacity: resetting ? 0.6 : 1 }}>
                  {resetting ? (ar ? 'جارٍ الحذف…' : 'Deleting…') : (ar ? 'حذف كل شيء' : 'Delete everything')}
                </motion.button>
                <motion.button whileTap={{ scale: 0.97 }} onClick={() => setResetConfirm(false)} disabled={resetting}
                  style={{ flex: 1, background: C.surface, border: `1.5px solid ${C.border}`, borderRadius: 10, padding: '12px 0', fontSize: 14, fontWeight: 700, color: C.dim, cursor: resetting ? 'default' : 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent' }}>
                  {ar ? 'إلغاء' : 'Cancel'}
                </motion.button>
              </div>
            </div>
          ) : (
            <motion.button whileTap={{ scale: 0.97 }}
              onClick={() => { setResetConfirm(true); setLogoutConfirm(false); setDeleteConfirm(false); }}
              style={{ width: '100%', background: 'transparent', border: '1.5px solid rgba(255,80,80,0.3)', borderRadius: 10, padding: '13px 0', fontSize: 14, fontWeight: 700, color: '#ff6b6b', cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
              <Trash2 size={15} color="#ff6b6b" />
              {ar ? 'مسح جميع البيانات' : 'Reset all data'}
            </motion.button>
          )}

          <div style={{ borderTop: `1px solid ${C.border}`, margin: '2px 0' }} />

          {/* Delete account */}
          {deleteConfirm ? (
            <div>
              <p style={{ fontSize: 14, fontWeight: 700, color: '#ff6b6b', marginBottom: 6 }}>
                {ar ? 'حذف الحساب' : 'Delete account'}
              </p>
              <p style={{ fontSize: 13, color: C.dim, marginBottom: 14, lineHeight: 1.55 }}>
                {ar ? 'سيؤدي هذا إلى حذف حسابك وبرنامجك وسجل جلساتك وتقدمك بشكل دائم. لا يمكن التراجع عن ذلك.' : 'This will permanently delete your account, programme, all session history, and progress. This cannot be undone.'}
              </p>
              <div style={{ display: 'flex', gap: 10 }}>
                <motion.button whileTap={{ scale: 0.97 }} onClick={handleDeleteAccount} disabled={deleting}
                  style={{ flex: 1, background: deleting ? 'rgba(255,80,80,0.06)' : 'rgba(255,80,80,0.18)', border: '1.5px solid rgba(255,80,80,0.5)', borderRadius: 10, padding: '12px 0', fontSize: 14, fontWeight: 800, color: '#ff6b6b', cursor: deleting ? 'default' : 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent', opacity: deleting ? 0.6 : 1 }}>
                  {deleting ? (ar ? 'جارٍ الحذف…' : 'Deleting…') : (ar ? 'حذف حسابي' : 'Delete my account')}
                </motion.button>
                <motion.button whileTap={{ scale: 0.97 }} onClick={() => setDeleteConfirm(false)} disabled={deleting}
                  style={{ flex: 1, background: C.surface, border: `1.5px solid ${C.border}`, borderRadius: 10, padding: '12px 0', fontSize: 14, fontWeight: 700, color: C.dim, cursor: deleting ? 'default' : 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent' }}>
                  {ar ? 'إلغاء' : 'Cancel'}
                </motion.button>
              </div>
            </div>
          ) : (
            <motion.button whileTap={{ scale: 0.97 }}
              onClick={() => { setDeleteConfirm(true); setLogoutConfirm(false); setResetConfirm(false); }}
              style={{ width: '100%', background: 'transparent', border: '1.5px solid rgba(255,80,80,0.3)', borderRadius: 10, padding: '13px 0', fontSize: 14, fontWeight: 700, color: '#ff6b6b', cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
              <UserX size={15} color="#ff6b6b" />
              {ar ? 'حذف الحساب' : 'Delete account'}
            </motion.button>
          )}
        </div>
      </Section>

    </div>
  );
}
