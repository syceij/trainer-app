import { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { AtSign, Check, X, Loader } from 'lucide-react';
import { C, springSoft } from '../../tokens.js';
import { checkUsername, setUsername } from '../../lib/db.js';

const USERNAME_RE = /^[a-zA-Z0-9_]{3,20}$/;

export default function UsernameModal({ userId, onComplete }) {
  const [value,   setValue]   = useState('');
  const [status,  setStatus]  = useState('idle'); // 'idle'|'checking'|'available'|'taken'|'invalid'
  const [saving,  setSaving]  = useState(false);
  const inputRef = useRef(null);
  const debounceRef = useRef(null);

  useEffect(() => { inputRef.current?.focus(); }, []);

  const handleChange = (val) => {
    setValue(val);
    setStatus('idle');
    clearTimeout(debounceRef.current);

    if (!val) return;
    if (!USERNAME_RE.test(val)) { setStatus('invalid'); return; }

    setStatus('checking');
    debounceRef.current = setTimeout(async () => {
      const available = await checkUsername(val);
      setStatus(available ? 'available' : 'taken');
    }, 500);
  };

  const handleSave = async () => {
    if (status !== 'available' || saving) return;
    setSaving(true);
    try {
      await setUsername(userId, value.trim().toLowerCase());
      onComplete(value.trim().toLowerCase());
    } catch {
      setSaving(false);
      setStatus('taken');
    }
  };

  const hint = {
    idle:      { text: '3–20 chars, letters / numbers / _', color: C.mute },
    invalid:   { text: '3–20 chars, letters / numbers / _ only', color: '#ff6b6b' },
    checking:  { text: 'Checking…', color: C.dim },
    available: { text: '✓ Username available!', color: '#ADFF2F' },
    taken:     { text: 'Already taken — try another', color: '#ff6b6b' },
  }[status];

  const canSave = status === 'available' && !saving;

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      style={{
        position: 'fixed', inset: 0, zIndex: 9000,
        background: 'rgba(0,0,0,0.75)',
        display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
      }}
    >
      <motion.div
        initial={{ y: '100%' }}
        animate={{ y: 0 }}
        exit={{ y: '100%' }}
        transition={springSoft}
        style={{
          width: '100%', maxWidth: 390,
          background: C.surface,
          borderRadius: '20px 20px 0 0',
          padding: '24px 20px',
          paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 24px, 36px)',
        }}
      >
        {/* Handle */}
        <div style={{
          width: 36, height: 4, borderRadius: 2,
          background: C.border, margin: '0 auto 20px',
        }} />

        <div style={{ fontSize: 20, fontWeight: 800, color: C.text, marginBottom: 6 }}>
          Choose your username
        </div>
        <div style={{ fontSize: 14, color: C.dim, marginBottom: 24, lineHeight: 1.5 }}>
          Your Bros will find you by this name. You can only set it once.
        </div>

        {/* Input */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          background: C.surface2, borderRadius: 12,
          border: `1.5px solid ${status === 'available' ? C.accent : status === 'invalid' || status === 'taken' ? '#ff6b6b' : C.border}`,
          padding: '12px 14px',
          marginBottom: 8,
          transition: 'border-color 0.2s',
        }}>
          <AtSign size={16} color={C.mute} />
          <input
            ref={inputRef}
            value={value}
            onChange={e => handleChange(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && handleSave()}
            placeholder="your_username"
            maxLength={20}
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            style={{
              flex: 1, background: 'none', border: 'none', outline: 'none',
              color: C.text, fontSize: 16, fontWeight: 600,
              fontFamily: 'inherit',
            }}
          />
          <AnimatePresence mode="wait">
            {status === 'checking' && (
              <motion.div key="spin" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
                <Loader size={16} color={C.mute} style={{ animation: 'spin 1s linear infinite' }} />
              </motion.div>
            )}
            {status === 'available' && (
              <motion.div key="ok" initial={{ scale: 0 }} animate={{ scale: 1 }} exit={{ scale: 0 }}>
                <Check size={16} color={C.accent} strokeWidth={3} />
              </motion.div>
            )}
            {(status === 'taken' || status === 'invalid') && (
              <motion.div key="err" initial={{ scale: 0 }} animate={{ scale: 1 }} exit={{ scale: 0 }}>
                <X size={16} color="#ff6b6b" strokeWidth={3} />
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        <div style={{ fontSize: 12, color: hint.color, marginBottom: 24, minHeight: 16 }}>
          {hint.text}
        </div>

        <motion.button
          whileTap={canSave ? { scale: 0.97 } : {}}
          onClick={handleSave}
          disabled={!canSave}
          style={{
            width: '100%',
            background: canSave ? C.accent : C.surface2,
            border: 'none', borderRadius: 12,
            padding: '15px 0',
            fontSize: 15, fontWeight: 800,
            color: canSave ? '#000' : C.mute,
            cursor: canSave ? 'pointer' : 'default',
            transition: 'background 0.2s, color 0.2s',
          }}
        >
          {saving ? 'Setting username…' : 'Set username'}
        </motion.button>
      </motion.div>
    </motion.div>
  );
}
