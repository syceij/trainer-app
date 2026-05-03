import { createPortal } from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { C, spring } from '../../tokens.js';

/**
 * BottomSheet — slides up from the bottom of the viewport.
 * Rendered via createPortal at document.body so position:fixed is
 * always relative to the true viewport, never to a transformed
 * ancestor (e.g. framer-motion tab animations).
 * Accepts an optional `footer` prop rendered outside the scroll
 * area so the button is never scrolled off-screen.
 */
export default function BottomSheet({ open, onClose, children, footer }) {
  const sheet = (
    <AnimatePresence>
      {open && (
        <>
          {/* Backdrop */}
          <motion.div
            key="bs-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            style={{
              position: 'fixed', inset: 0,
              background: 'rgba(0,0,0,0.7)',
              zIndex: 800,
              backdropFilter: 'blur(2px)',
            }}
          />

          {/* Sheet */}
          <motion.div
            key="bs-sheet"
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={spring}
            drag="y"
            dragConstraints={{ top: 0, bottom: 0 }}
            dragElastic={{ top: 0, bottom: 0.4 }}
            onDragEnd={(_, info) => { if (info.offset.y > 80) onClose(); }}
            style={{
              position: 'fixed',
              bottom: 0,
              left: 0,
              right: 0,
              maxHeight: '85vh',
              background: C.surface,
              borderRadius: '20px 20px 0 0',
              zIndex: 801,
              display: 'flex',
              flexDirection: 'column',
              overflow: 'hidden',
              willChange: 'transform',
            }}
          >
            {/* Drag handle */}
            <div style={{
              display: 'flex', justifyContent: 'center',
              paddingTop: 12, paddingBottom: 8, flexShrink: 0,
            }}>
              <div style={{ width: 40, height: 4, borderRadius: 2, background: C.border }} />
            </div>

            {/* Scrollable content */}
            <div style={{
              flex: 1,
              overflowY: 'auto',
              WebkitOverflowScrolling: 'touch',
              padding: '0 20px',
              paddingBottom: footer ? 8 : 20,
              minHeight: 0,
            }}>
              {children}
            </div>

            {/* Sticky footer — always visible, never scrolls off */}
            {footer ? (
              <div style={{
                flexShrink: 0,
                padding: '12px 20px',
                paddingBottom: 'max(calc(env(safe-area-inset-bottom, 0px) + 12px), 20px)',
                borderTop: `1px solid ${C.border}`,
                background: C.surface,
              }}>
                {footer}
              </div>
            ) : (
              <div style={{ height: 'env(safe-area-inset-bottom, 0px)', flexShrink: 0 }} />
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );

  return createPortal(sheet, document.body);
}
