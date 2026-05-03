import { AnimatePresence, motion } from 'framer-motion';
import { C, spring } from '../../tokens.js';

export default function Toast({ message }) {
  return (
    <AnimatePresence>
      {message && (
        <motion.div
          key={message}
          initial={{ y: -60, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: -60, opacity: 0 }}
          transition={spring}
          style={{
            position: 'fixed',
            top: 'max(env(safe-area-inset-top, 0px) + 12px, 20px)',
            left: '50%',
            transform: 'translateX(-50%)',
            zIndex: 9999,
            background: C.accent,
            color: '#000',
            fontWeight: 700,
            fontSize: 13,
            padding: '10px 20px',
            borderRadius: 100,
            whiteSpace: 'nowrap',
            boxShadow: '0 4px 24px rgba(184,255,0,0.3)',
            willChange: 'transform',
          }}
        >
          {message}
        </motion.div>
      )}
    </AnimatePresence>
  );
}
