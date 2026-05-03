import { motion } from 'framer-motion';
import { C, spring } from '../../tokens.js';

export default function SegmentedPicker({ options, value, onChange }) {
  return (
    <div style={{
      display: 'flex',
      background: C.surface2,
      borderRadius: 10,
      padding: 3,
      gap: 2,
    }}>
      {options.map(opt => {
        const active = opt.value === value;
        const label = opt.label ?? opt.value;
        return (
          <button
            key={opt.value}
            onClick={() => onChange(opt.value)}
            style={{
              flex: 1,
              position: 'relative',
              background: 'none',
              border: 'none',
              borderRadius: 8,
              padding: '8px 4px',
              cursor: 'pointer',
              zIndex: 0,
              touchAction: 'manipulation',
              WebkitTapHighlightColor: 'transparent',
            }}
          >
            {active && (
              <motion.div
                layoutId="seg-pill"
                style={{
                  position: 'absolute',
                  inset: 0,
                  background: C.accent,
                  borderRadius: 8,
                  zIndex: 0,
                }}
                transition={spring}
              />
            )}
            <span style={{
              position: 'relative',
              zIndex: 1,
              fontSize: 13,
              fontWeight: 600,
              color: active ? '#000' : C.dim,
              whiteSpace: 'nowrap',
            }}>
              {label}
            </span>
          </button>
        );
      })}
    </div>
  );
}
