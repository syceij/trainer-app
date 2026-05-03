import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronLeft, ChevronDown, ChevronUp, Copy, CheckCircle, AlertCircle } from 'lucide-react';
import TextArea from './shared/TextArea.jsx';
import { C, spring, springSoft } from '../tokens.js';
import { PROMPT_TEMPLATE, SAMPLE_PROGRAMME, validateImported, importedSessionToRuntime } from '../lib/importHelpers.js';

export default function ImportScreen({ onImport, onBack }) {
  const [json, setJson] = useState('');
  const [showPrompt, setShowPrompt] = useState(false);
  const [copied, setCopied] = useState(false);
  const [errors, setErrors] = useState(null);
  const [valid, setValid] = useState(null);

  const copyPrompt = async () => {
    await navigator.clipboard.writeText(PROMPT_TEMPLATE).catch(() => {});
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const tryValidate = () => {
    let data;
    try { data = JSON.parse(json); } catch { setErrors(['Invalid JSON — check for missing commas, brackets, or quotes']); setValid(null); return; }
    const errs = validateImported(data);
    if (errs.length) { setErrors(errs); setValid(null); }
    else { setErrors(null); setValid(data); }
  };

  const loadSample = () => {
    setJson(JSON.stringify(SAMPLE_PROGRAMME, null, 2));
    setErrors(null);
    setValid(null);
  };

  const doImport = () => {
    if (!valid) return;
    onImport(valid);
  };

  return (
    <motion.div
      initial={{ x: 24, opacity: 0 }}
      animate={{ x: 0, opacity: 1 }}
      exit={{ x: 24, opacity: 0 }}
      transition={springSoft}
      style={{
        display: 'flex', flexDirection: 'column',
        height: '100%', width: '100%', maxWidth: 390,
        padding: '0 20px',
        paddingTop: 'max(env(safe-area-inset-top, 0px) + 16px, 24px)',
        paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 16px, 24px)',
        overflowY: 'auto', WebkitOverflowScrolling: 'touch',
      }}
    >
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 28, flexShrink: 0 }}>
        <button
          onClick={onBack}
          style={{
            background: C.surface2, border: `1.5px solid ${C.border}`,
            borderRadius: 8, width: 36, height: 36,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: C.text, cursor: 'pointer',
            touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
          }}
        >
          <ChevronLeft size={18} />
        </button>
        <h1 style={{ fontSize: 22, fontWeight: 800, letterSpacing: '-0.02em', color: C.text }}>
          Paste your programme
        </h1>
      </div>

      <p style={{ fontSize: 14, color: C.dim, lineHeight: 1.6, marginBottom: 20 }}>
        Use the Claude prompt below to convert your programme to JSON, then paste it here.
      </p>

      {/* Collapsible prompt */}
      <div style={{ marginBottom: 20, border: `1.5px solid ${C.border}`, borderRadius: 12, overflow: 'hidden' }}>
        <button
          onClick={() => setShowPrompt(p => !p)}
          style={{
            width: '100%', background: C.surface2, border: 'none',
            padding: '14px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            color: C.text, fontSize: 14, fontWeight: 600, cursor: 'pointer',
            touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
          }}
        >
          <span>Show prompt template for Claude</span>
          {showPrompt ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
        </button>
        <AnimatePresence>
          {showPrompt && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              transition={spring}
              style={{ overflow: 'hidden' }}
            >
              <div style={{ padding: '0 16px 16px', background: C.surface }}>
                <pre style={{
                  fontFamily: 'ui-monospace, monospace', fontSize: 11,
                  color: C.dim, whiteSpace: 'pre-wrap', wordBreak: 'break-word',
                  lineHeight: 1.6, marginBottom: 12,
                }}>
                  {PROMPT_TEMPLATE}
                </pre>
                <button
                  onClick={copyPrompt}
                  style={{
                    background: C.accent, color: '#000', border: 'none',
                    borderRadius: 8, padding: '9px 16px', fontSize: 13, fontWeight: 700,
                    display: 'flex', alignItems: 'center', gap: 6,
                    cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                  }}
                >
                  {copied ? <CheckCircle size={14} /> : <Copy size={14} />}
                  {copied ? 'Copied!' : 'Copy prompt'}
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* JSON paste area */}
      <TextArea
        value={json}
        onChange={e => { setJson(e.target.value); setErrors(null); setValid(null); }}
        rows={10}
        placeholder={'{\n  "name": "My Programme",\n  "weeks": [...]\n}'}
        style={{ fontFamily: 'ui-monospace, monospace', fontSize: 12, marginBottom: 12 }}
      />

      <button
        onClick={loadSample}
        style={{
          background: 'none', border: 'none', color: C.accent,
          fontSize: 13, fontWeight: 600, padding: '4px 0 12px',
          cursor: 'pointer', textAlign: 'left',
          touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
        }}
      >
        Try with sample programme →
      </button>

      {/* Error panel */}
      {errors && (
        <motion.div
          initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={spring}
          style={{
            background: C.errorBg, border: `1.5px solid ${C.errorBorder}`,
            borderRadius: 10, padding: '12px 14px', marginBottom: 12,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
            <AlertCircle size={14} color="#FF6060" />
            <span style={{ fontSize: 12, fontWeight: 700, color: '#FF6060' }}>Validation errors</span>
          </div>
          <ul style={{ paddingLeft: 16, margin: 0 }}>
            {errors.map((e, i) => (
              <li key={i} style={{ fontSize: 12, color: '#FF8080', marginBottom: 4 }}>{e}</li>
            ))}
          </ul>
        </motion.div>
      )}

      {/* Success panel */}
      {valid && (
        <motion.div
          initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={spring}
          style={{
            background: C.successBg, border: `1.5px solid ${C.successBorder}`,
            borderRadius: 10, padding: '12px 14px', marginBottom: 12,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
            <CheckCircle size={14} color={C.accent} />
            <span style={{ fontSize: 12, fontWeight: 700, color: C.accent }}>Valid programme</span>
          </div>
          <p style={{ fontSize: 13, color: C.text, fontWeight: 600 }}>{valid.name}</p>
          <p style={{ fontSize: 12, color: C.dim }}>
            {valid.weeks?.length || 1} week{valid.weeks?.length !== 1 ? 's' : ''} ·{' '}
            {valid.weeks?.[0]?.sessions?.filter(s => !s.isRest).length || 0} sessions/week
          </p>
        </motion.div>
      )}

      <div style={{ display: 'flex', gap: 10, marginTop: 8 }}>
        <button
          onClick={tryValidate}
          style={{
            flex: 1, background: C.surface2, border: `1.5px solid ${C.border}`,
            borderRadius: 12, padding: '14px 0', fontSize: 14, fontWeight: 700,
            color: C.text, cursor: 'pointer',
            touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
          }}
        >
          Validate
        </button>
        <motion.button
          whileTap={{ scale: 0.97 }}
          transition={spring}
          onClick={doImport}
          disabled={!valid}
          style={{
            flex: 1.5, background: valid ? C.accent : C.surface2,
            border: 'none', borderRadius: 12, padding: '14px 0',
            fontSize: 14, fontWeight: 700,
            color: valid ? '#000' : C.mute,
            cursor: valid ? 'pointer' : 'default',
            touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
            transition: 'background 0.2s, color 0.2s',
          }}
        >
          Import &amp; start →
        </motion.button>
      </div>
    </motion.div>
  );
}
