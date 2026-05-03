import { motion, AnimatePresence } from 'framer-motion';
import { C, spring } from '../../tokens.js';

/**
 * CenteredModal — a modal that is always fully visible in the centre
 * of the screen on any device width ≥ 375 px.
 *
 * Positioning:
 *   position:fixed + top:50% + left:50% + framer-motion x/y:'-50%'
 *   so centering composes correctly with the scale animation.
 *
 * Accepts an optional `footer` prop that is rendered outside the
 * scrollable content area so the action button is always reachable.
 */
export default function CenteredModal({ open, onClose, children, footer }) {
  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Backdrop */}
          <motion.div
            key="cm-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            style={{
              position: 'fixed', inset: 0,
              background: 'rgba(0,0,0,0.78)',
              zIndex: 800,
              backdropFilter: 'blur(4px)',
            }}
          />

          {/* Modal card */}
          <motion.div
            key="cm-modal"
            initial={{ opacity: 0, scale: 0.90 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.90 }}
            transition={spring}
            style={{
              // Viewport-centred positioning
              position: 'fixed',
              top: '50%',
              left: '50%',
              // framer-motion percentage x/y compose with scale correctly
              x: '-50%',
              y: '-50%',
              // Sizing — 16 px gutter each side, never wider than 420 px
              width: 'calc(100% - 32px)',
              maxWidth: 420,
              maxHeight: '85vh',
              // Layout
              background: C.surface,
              borderRadius: 20,
              zIndex: 801,
              display: 'flex',
              flexDirection: 'column',
              overflow: 'hidden',
              boxShadow: '0 32px 80px rgba(0,0,0,0.65)',
            }}
          >
            {/* Scrollable content area */}
            <div style={{
              flex: 1,
              overflowY: 'auto',
              WebkitOverflowScrolling: 'touch',
              padding: '24px 20px',
              paddingBottom: footer ? 8 : 24,
              minHeight: 0,
            }}>
              {children}
            </div>

            {/* Sticky footer — Save / confirm button always reachable */}
            {footer && (
              <div style={{
                flexShrink: 0,
                padding: '12px 20px',
                paddingBottom: 'max(calc(env(safe-area-inset-bottom, 0px) + 12px), 20px)',
                borderTop: `1px solid ${C.border}`,
                background: C.surface,
              }}>
                {footer}
              </div>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
