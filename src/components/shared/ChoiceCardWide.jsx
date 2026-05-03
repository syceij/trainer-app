import { motion } from 'framer-motion';
import { C, spring } from '../../tokens.js';

export default function ChoiceCardWide({ label, sub, value, selected, onSelect }) {
  return (
    <motion.button
      onClick={() => onSelect(value)}
      whileTap={{ scale: 0.98 }}
      transition={spring}
      style={{
        background: selected ? 'rgba(184,255,0,0.08)' : C.surface2,
        border: `1.5px solid ${selected ? C.accent : C.border}`,
        borderRadius: 12,
        padding: '16px 18px',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'flex-start',
        gap: 4,
        cursor: 'pointer',
        touchAction: 'manipulation',
        WebkitTapHighlightColor: 'transparent',
        width: '100%',
        textAlign: 'left',
      }}
    >
      <span style={{ fontSize: 15, fontWeight: 700, color: selected ? C.accent : C.text }}>
        {label}
      </span>
      {sub && (
        <span style={{ fontSize: 12, color: C.dim, lineHeight: 1.4 }}>{sub}</span>
      )}
    </motion.button>
  );
}
