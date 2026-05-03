import { useState } from 'react';
import { C } from '../../tokens.js';

export default function TextArea({ rows = 3, style, ...props }) {
  const [focused, setFocused] = useState(false);
  return (
    <textarea
      rows={rows}
      onFocus={e => { setFocused(true); e.target.scrollIntoView({ behavior: 'smooth', block: 'center' }); }}
      onBlur={() => setFocused(false)}
      style={{
        background: C.surface2,
        border: `1.5px solid ${focused ? C.accent : C.border}`,
        borderRadius: 10,
        color: C.text,
        fontSize: 16,
        padding: '12px 14px',
        outline: 'none',
        width: '100%',
        resize: 'none',
        transition: 'border-color 0.15s',
        WebkitTapHighlightColor: 'transparent',
        lineHeight: 1.5,
        ...style,
      }}
      {...props}
    />
  );
}
