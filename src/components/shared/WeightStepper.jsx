import { C } from '../../tokens.js';

export default function WeightStepper({ label, value, onChange, step = 2.5, min = 0 }) {
  const dec = () => onChange(Math.max(min, Math.round((value - step) * 100) / 100));
  const inc = () => onChange(Math.round((value + step) * 100) / 100);
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 0 }}>
      {label && (
        <span style={{ flex: 1, fontSize: 14, color: C.text, fontWeight: 500 }}>{label}</span>
      )}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        background: C.surface2,
        borderRadius: 10,
        border: `1.5px solid ${C.border}`,
        overflow: 'hidden',
      }}>
        <button
          onClick={dec}
          style={{
            width: 44, height: 44,
            background: 'none', border: 'none',
            color: C.dim, fontSize: 20, fontWeight: 700,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', touchAction: 'manipulation',
            WebkitTapHighlightColor: 'transparent',
          }}
        >−</button>
        <span style={{
          minWidth: 72, textAlign: 'center',
          fontSize: 15, fontWeight: 700, color: C.text, padding: '0 4px',
        }}>
          {value} kg
        </span>
        <button
          onClick={inc}
          style={{
            width: 44, height: 44,
            background: 'none', border: 'none',
            color: C.dim, fontSize: 20, fontWeight: 700,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', touchAction: 'manipulation',
            WebkitTapHighlightColor: 'transparent',
          }}
        >+</button>
      </div>
    </div>
  );
}
