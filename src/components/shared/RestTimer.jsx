import { motion } from 'framer-motion';
import { C } from '../../tokens.js';

// ── Presets ────────────────────────────────────────────────────────────────────
export const TIMER_PRESETS = [
  { label: 'Off',   value: 0   },
  { label: '30s',   value: 30  },
  { label: '45s',   value: 45  },
  { label: '1 min', value: 60  },
  { label: '90s',   value: 90  },
  { label: '2 min', value: 120 },
  { label: 'Custom',value: -1  },
];

// ── Helpers ────────────────────────────────────────────────────────────────────
export function getDefaultRestDuration(ex) {
  if (!ex) return 60;
  if (ex.bodyweight) return 60;
  return ex.tag === 'compound' ? 90 : 60;
}

export function fmtTime(secs) {
  if (!secs || secs < 0) return '0:00';
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

export function isCustomDuration(v) {
  if (!v || v <= 0) return false;
  return ![30, 45, 60, 90, 120].includes(Number(v));
}

// ── SVG constants — 52 px diameter ────────────────────────────────────────────
const RADIUS = 22;
const STROKE = 3;
const SIZE   = 52;
const CIRC   = 2 * Math.PI * RADIUS;

// ── Component ──────────────────────────────────────────────────────────────────
/**
 * Circular countdown ring.
 *
 * The component ALWAYS occupies SIZE × SIZE pixels in the layout — it never
 * mounts/unmounts. Visibility is controlled purely through opacity + scale so
 * the surrounding card height is identical whether the timer is running or not.
 *
 * Props:
 *   duration  — total duration in seconds (ring fill calculation)
 *   remaining — current remaining seconds; 0 means inactive (fade out)
 *   paused    — timer is paused
 *   onTap     — tap handler (toggle pause)
 */
export default function RestTimer({ duration, remaining, paused, onTap }) {
  const active     = remaining > 0;
  const progress   = active && duration > 0 ? remaining / duration : 0;
  const dashOffset = CIRC * (1 - progress);

  return (
    <motion.div
      animate={{ opacity: active ? 1 : 0, scale: active ? 1 : 0.6 }}
      transition={{ type: 'spring', stiffness: 420, damping: 28 }}
      onClick={active ? onTap : undefined}
      style={{
        // Fixed footprint — never causes layout reflow
        width: SIZE, height: SIZE,
        flexShrink: 0,
        position: 'relative',
        cursor: active ? 'pointer' : 'default',
        pointerEvents: active ? 'auto' : 'none',
        touchAction: 'manipulation',
        WebkitTapHighlightColor: 'transparent',
        userSelect: 'none',
      }}
    >
      <svg width={SIZE} height={SIZE} style={{ display: 'block' }}>
        {/* Track */}
        <circle
          cx={SIZE / 2} cy={SIZE / 2} r={RADIUS}
          fill="none"
          stroke="rgba(255,255,255,0.1)"
          strokeWidth={STROKE}
        />
        {/* Progress arc — clockwise depletion */}
        <circle
          cx={SIZE / 2} cy={SIZE / 2} r={RADIUS}
          fill="none"
          stroke={paused ? 'rgba(184,255,0,0.5)' : C.accent}
          strokeWidth={STROKE}
          strokeLinecap="round"
          strokeDasharray={`${CIRC}`}
          strokeDashoffset={dashOffset}
          transform={`rotate(-90 ${SIZE / 2} ${SIZE / 2})`}
          style={{
            transition: paused ? 'none' : 'stroke-dashoffset 1s linear',
            willChange: 'stroke-dashoffset',
          }}
        />
      </svg>

      {/* Center label */}
      <div style={{
        position: 'absolute', inset: 0,
        display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
        gap: 1, pointerEvents: 'none',
      }}>
        <span style={{ fontSize: 13, fontWeight: 800, color: C.text, lineHeight: 1 }}>
          {fmtTime(remaining)}
        </span>
        {paused && (
          <span style={{ fontSize: 7, fontWeight: 700, color: C.mute, letterSpacing: '0.05em' }}>
            PAUSED
          </span>
        )}
      </div>
    </motion.div>
  );
}
