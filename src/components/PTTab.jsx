import { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Send, UserCircle } from 'lucide-react';
import { C, spring, springSoft } from '../tokens.js';
import { generateReply } from '../lib/ptReplies.js';

const AUTO_CHIPS_EN   = ["What's my next session?", "Change to dumbbells only", "Add more arm work", "I'm feeling fatigued"];
const IMPORT_CHIPS_EN = ["What's today's session?", "Jump to week 2", "Show me week 1", "I'm feeling fatigued"];
const AUTO_CHIPS_AR   = ["ما هي جلستي القادمة؟", "غيّر إلى دمبلز فقط", "أضف تمارين الذراعين", "أشعر بالتعب"];
const IMPORT_CHIPS_AR = ["ما هي جلسة اليوم؟", "انتقل إلى الأسبوع ٢", "أظهر لي الأسبوع ١", "أشعر بالتعب"];

function TypingIndicator() {
  return (
    <div style={{ display: 'flex', gap: 4, padding: '12px 14px', background: C.surface2, borderRadius: 14, alignSelf: 'flex-start', maxWidth: 70 }}>
      {[0,1,2].map(i => (
        <motion.div
          key={i}
          animate={{ y: [0, -4, 0] }}
          transition={{ repeat: Infinity, duration: 0.8, delay: i * 0.15 }}
          style={{ width: 6, height: 6, borderRadius: '50%', background: C.dim }}
        />
      ))}
    </div>
  );
}

export default function PTTab({ state }) {
  const { chatMessages, setChatMessages, programmeMode, setAccountView, profile, lang = 'en' } = state;
  const ar = lang === 'ar';
  const [input, setInput] = useState('');
  const [typing, setTyping] = useState(false);
  const bottomRef = useRef(null);
  const inputRef = useRef(null);

  const AUTO_CHIPS   = ar ? AUTO_CHIPS_AR   : AUTO_CHIPS_EN;
  const IMPORT_CHIPS = ar ? IMPORT_CHIPS_AR : IMPORT_CHIPS_EN;
  const chips = programmeMode === 'imported' ? IMPORT_CHIPS : AUTO_CHIPS;
  const showChips = chatMessages.length <= 2 && !input;

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chatMessages, typing]);

  const sendMessage = async (text) => {
    if (!text.trim()) return;
    const userMsg = { id: Date.now(), role: 'user', text: text.trim() };
    setChatMessages(m => [...m, userMsg]);
    setInput('');
    setTyping(true);

    // Simulate typing delay
    await new Promise(r => setTimeout(r, 600 + Math.random() * 600));

    const reply = generateReply(text.trim(), state);
    setTyping(false);
    setChatMessages(m => [...m, { id: Date.now() + 1, role: 'assistant', text: reply }]);
  };

  const handleKey = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(input); }
  };

  const formatText = (text) => {
    return text.split('\n').map((line, i) => (
      <span key={i}>
        {line.split(/(\*\*[^*]+\*\*)/).map((part, j) =>
          part.startsWith('**') ? <strong key={j}>{part.slice(2,-2)}</strong> : part
        )}
        {i < text.split('\n').length - 1 && <br />}
      </span>
    ));
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* Header */}
      <div style={{
        padding: '16px 20px 12px',
        paddingTop: 'max(env(safe-area-inset-top, 0px) + 12px, 20px)',
        borderBottom: `1px solid ${C.border}`,
        flexShrink: 0,
      }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
          <div>
            <h1 style={{ fontSize: 22, fontWeight: 800, letterSpacing: ar ? '0' : '-0.02em', color: C.text, fontFamily: ar ? "'ThmanyahSans', sans-serif" : undefined }}>
              {ar ? 'اسأل المدرب' : 'Ask PT'}
            </h1>
            <p style={{ fontSize: 12, color: C.dim, marginTop: 2 }}>
              {ar ? 'تدريب ذكي · تعديلات البرنامج · تعليمات الشكل' : 'AI coaching · programme adjustments · form cues'}
            </p>
          </div>
          <motion.button
            whileTap={{ scale: 0.93 }}
            onClick={() => setAccountView && setAccountView(true)}
            title="Account"
            style={{
              background: C.surface2, border: `1.5px solid ${C.border}`,
              borderRadius: 10, padding: '6px 10px',
              display: 'flex', alignItems: 'center', gap: 6,
              cursor: 'pointer', touchAction: 'manipulation',
              WebkitTapHighlightColor: 'transparent', flexShrink: 0,
            }}
          >
            <UserCircle size={15} color={C.accent} />
            <span style={{ fontSize: 12, fontWeight: 700, color: C.dim, maxWidth: 80, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {profile?.name || (ar ? 'الحساب' : 'Account')}
            </span>
          </motion.button>
        </div>
      </div>

      {/* Messages */}
      <div style={{ flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch', padding: '16px 16px 8px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {chatMessages.length === 0 && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={springSoft}
            style={{ textAlign: 'center', padding: '24px 16px' }}
          >
            <div style={{ fontSize: 32, marginBottom: 12 }}>🏋️</div>
            <p style={{ fontSize: 15, fontWeight: 700, color: C.text, marginBottom: 6 }}>
              {ar ? 'مدرّبك الشخصي' : 'Your personal trainer'}
            </p>
            <p style={{ fontSize: 13, color: C.dim }}>
              {ar
                ? 'اسأل أي شيء عن تدريبك، عدّل برنامجك، أو احصل على تعليمات الشكل.'
                : 'Ask anything about your training, adjust your programme, or get coaching cues.'}
            </p>
          </motion.div>
        )}

        {chatMessages.map((msg) => (
          <motion.div
            key={msg.id}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={spring}
            style={{ display: 'flex', justifyContent: msg.role === 'user' ? 'flex-end' : 'flex-start' }}
          >
            <div style={{
              maxWidth: '82%',
              padding: '10px 14px',
              borderRadius: msg.role === 'user' ? '14px 14px 4px 14px' : '14px 14px 14px 4px',
              background: msg.role === 'user' ? C.accent : C.surface2,
              color: msg.role === 'user' ? '#000' : C.text,
              fontSize: 14,
              lineHeight: 1.55,
              fontWeight: msg.role === 'user' ? 600 : 400,
            }}>
              {formatText(msg.text)}
            </div>
          </motion.div>
        ))}

        {typing && (
          <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
            <TypingIndicator />
          </motion.div>
        )}

        <div ref={bottomRef} />
      </div>

      {/* Suggestion chips */}
      <AnimatePresence>
        {showChips && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 8 }}
            transition={springSoft}
            style={{ padding: '6px 16px 8px', display: 'flex', gap: 8, overflowX: 'auto', WebkitOverflowScrolling: 'touch', flexShrink: 0 }}
          >
            {chips.map(chip => (
              <motion.button
                key={chip}
                whileTap={{ scale: 0.95 }}
                onClick={() => sendMessage(chip)}
                style={{
                  flexShrink: 0, padding: '7px 14px', borderRadius: 100,
                  background: C.surface2, border: `1.5px solid ${C.border}`,
                  color: C.dim, fontSize: 12, fontWeight: 600,
                  cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                  whiteSpace: 'nowrap',
                }}
              >
                {chip}
              </motion.button>
            ))}
          </motion.div>
        )}
      </AnimatePresence>

      {/* Input bar */}
      <div style={{
        padding: '8px 12px',
        paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 8px, 12px)',
        borderTop: `1px solid ${C.border}`,
        background: C.surface,
        display: 'flex', gap: 8, alignItems: 'flex-end',
        flexShrink: 0,
      }}>
        <textarea
          ref={inputRef}
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={handleKey}
          placeholder={ar ? 'اسأل مدرّبك...' : 'Ask your trainer...'}
          rows={1}
          style={{
            flex: 1,
            background: C.surface2, border: `1.5px solid ${C.border}`,
            borderRadius: 12, padding: '10px 12px',
            color: C.text, fontSize: 16, outline: 'none',
            resize: 'none', lineHeight: 1.4,
            fontFamily: 'inherit',
            WebkitTapHighlightColor: 'transparent',
            maxHeight: 100,
          }}
          onFocus={e => {
            e.target.style.borderColor = C.accent;
            e.target.scrollIntoView({ behavior: 'smooth', block: 'center' });
          }}
          onBlur={e => { e.target.style.borderColor = C.border; }}
        />
        <motion.button
          whileTap={{ scale: 0.9 }}
          transition={spring}
          onClick={() => sendMessage(input)}
          disabled={!input.trim()}
          style={{
            width: 44, height: 44, borderRadius: 12, flexShrink: 0,
            background: input.trim() ? C.accent : C.surface2,
            border: 'none', cursor: input.trim() ? 'pointer' : 'default',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            transition: 'background 0.15s',
            touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
          }}
        >
          <Send size={18} color={input.trim() ? '#000' : C.mute} strokeWidth={2.5} />
        </motion.button>
      </div>
    </div>
  );
}
