import { motion } from 'framer-motion';
import { Zap, PencilLine, FileJson } from 'lucide-react';
import { supabase } from '../lib/supabase.js';
import { C, spring, springSoft } from '../tokens.js';

export default function WelcomeScreen({ onBuild, onManual, onImport, onSignOut, lang = 'en' }) {
  const ar = lang === 'ar';

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    onSignOut?.();
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={springSoft}
      style={{
        display: 'flex',
        flexDirection: 'column',
        minHeight: '100%',
        width: '100%',
        maxWidth: 390,
        padding: '0 24px',
        paddingTop: 'max(env(safe-area-inset-top, 0px) + 48px, 64px)',
        paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 40px, 48px)',
        direction: ar ? 'rtl' : 'ltr',
      }}
    >
      {/* Logo — centred, with sign-out pinned top-right (start in RTL) */}
      <motion.div
        initial={{ scale: 0.85, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ ...spring, delay: 0.05 }}
        style={{
          position: 'relative',
          display: 'flex',
          justifyContent: 'center',
          marginBottom: 48,
        }}
      >
        <img
          src="/logo.png"
          alt="HEX"
          style={{ height: 120, width: 'auto', objectFit: 'contain' }}
        />

        <button
          onClick={handleSignOut}
          style={{
            position: 'absolute', top: 0, [ar ? 'left' : 'right']: 0,
            background: 'none', border: 'none',
            color: C.mute, fontSize: 13, fontWeight: 600,
            cursor: 'pointer', padding: '4px 0',
            WebkitTapHighlightColor: 'transparent',
          }}
        >
          {ar ? 'تسجيل الخروج' : 'Sign out'}
        </button>
      </motion.div>

      {/* Headline */}
      <motion.div
        initial={{ y: 20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ ...springSoft, delay: 0.1 }}
        style={{ flex: 1 }}
      >
        <h1 style={{
          fontSize: 36,
          fontWeight: 800,
          lineHeight: 1.15,
          letterSpacing: ar ? '0' : '-0.03em',
          color: C.text,
          marginBottom: 16,
          fontFamily: ar ? "'ThmanyahSans', sans-serif" : undefined,
        }}>
          {ar ? (
            <>قوّتك.{' '}<span style={{ color: C.accent }}>موثّقة.</span></>
          ) : (
            <>Your strength.{' '}<span style={{ color: C.accent }}>Tracked.</span></>
          )}
        </h1>
        <p style={{
          fontSize: 16,
          color: C.dim,
          lineHeight: 1.6,
          marginBottom: 36,
        }}>
          {ar
            ? 'ابنِ برنامجك، سجّل تمارينك، تحكّم.'
            : 'Build your programme, log your sessions, dominate.'}
        </p>

        {/* CTAs */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {/* Primary — AI-generated */}
          <motion.button
            whileTap={{ scale: 0.97 }}
            transition={spring}
            onClick={onBuild}
            style={{
              background: C.accent,
              color: '#000',
              border: 'none',
              borderRadius: 14,
              padding: '18px 24px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              cursor: 'pointer',
              touchAction: 'manipulation',
              WebkitTapHighlightColor: 'transparent',
            }}
          >
            <div style={{ textAlign: ar ? 'right' : 'left' }}>
              <div style={{ fontSize: 16, fontWeight: 700 }}>
                {ar ? 'ابنِ برنامجي' : 'Build my programme'}
              </div>
              <div style={{ fontSize: 12, fontWeight: 500, opacity: 0.7 }}>
                {ar ? '٧ خطوات · مولّد تلقائياً' : '7-step setup · auto-generated'}
              </div>
            </div>
            <Zap size={20} color="#000" strokeWidth={2.5} />
          </motion.button>

          {/* Secondary — manual wizard */}
          <motion.button
            whileTap={{ scale: 0.97 }}
            transition={spring}
            onClick={onManual}
            style={{
              background: C.surface2,
              color: C.text,
              border: `1.5px solid ${C.border}`,
              borderRadius: 14,
              padding: '18px 24px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              cursor: 'pointer',
              touchAction: 'manipulation',
              WebkitTapHighlightColor: 'transparent',
            }}
          >
            <div style={{ textAlign: ar ? 'right' : 'left' }}>
              <div style={{ fontSize: 16, fontWeight: 700 }}>
                {ar ? 'بناء يدوي' : 'Build manually'}
              </div>
              <div style={{ fontSize: 12, fontWeight: 500, color: C.dim }}>
                {ar ? '٦ خطوات · قابل للتخصيص' : '6-step wizard · fully customisable'}
              </div>
            </div>
            <PencilLine size={20} color={C.dim} strokeWidth={2} />
          </motion.button>

          {/* Secondary — import */}
          <motion.button
            whileTap={{ scale: 0.97 }}
            transition={spring}
            onClick={onImport}
            style={{
              background: C.surface2,
              color: C.text,
              border: `1.5px solid ${C.border}`,
              borderRadius: 14,
              padding: '18px 24px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              cursor: 'pointer',
              touchAction: 'manipulation',
              WebkitTapHighlightColor: 'transparent',
            }}
          >
            <div style={{ textAlign: ar ? 'right' : 'left' }}>
              <div style={{ fontSize: 16, fontWeight: 700 }}>
                {ar ? 'استيراد برنامج موجود' : 'Import existing programme'}
              </div>
              <div style={{ fontSize: 12, fontWeight: 500, color: C.dim }}>
                {ar ? 'الصق JSON · دعم متعدد الأسابيع' : 'Paste JSON · multi-week support'}
              </div>
            </div>
            <FileJson size={20} color={C.dim} />
          </motion.button>
        </div>
      </motion.div>

      {/* Footer */}
      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.3 }}
        style={{
          marginTop: 40,
          fontSize: 11,
          fontWeight: 600,
          letterSpacing: ar ? '0' : '0.1em',
          color: C.mute,
          textAlign: 'center',
        }}
      >
        {ar ? 'بياناتك تتزامن عبر جميع الأجهزة' : 'YOUR DATA SYNCS ACROSS DEVICES'}
      </motion.p>
    </motion.div>
  );
}
