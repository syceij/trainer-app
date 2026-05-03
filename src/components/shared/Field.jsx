import { C } from '../../tokens.js';

export default function Field({ label, children }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      {label && (
        <span style={{
          fontSize: 11,
          fontWeight: 600,
          letterSpacing: '0.08em',
          textTransform: 'uppercase',
          color: C.dim,
        }}>
          {label}
        </span>
      )}
      {children}
    </div>
  );
}
