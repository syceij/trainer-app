import { motion } from 'framer-motion';
import { C, spring } from '../../tokens.js';

export default function ChoiceCard({ label, icon, value, selected, onSelect }) {
  return (
    <motion.button
      onClick={() => onSelect(value)}
      whileTap={{ scale: 0.97 }}
      transition={spring}
      style={{
        background: selected ? 'rgba(184,255,0,0.08)' : C.surface2,
        border: `1.5px solid ${selected ? C.accent : C.border}`,
        borderRadius: 12,
        padding: '18px 12px',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 8,
        cursor: 'pointer',
        touchAction: 'manipulation',
        WebkitTapHighlightColor: 'transparent',
        width: '100%',
      }}
    >
      {icon && <span style={{ fontSize: 22 }}>{icon}</span>}
      <span style={{ fontSize: 14, fontWeight: 600, color: selected ? C.accent : C.text }}>
        {label}
      </span>
    </motion.button>
  );
}
