import { motion } from 'framer-motion';
import { User } from 'lucide-react';
import { Capacitor } from '@capacitor/core';
import { C, spring } from '../tokens.js';
import { hapticLight } from '../lib/haptics.js';

// Four tabs use the custom PNG icons shipped in /public — same source
// artwork as iOS's `Assets.xcassets/{Home,Train,Progress,Bros}Icon.imageset`
// so the two clients render identical chrome. Profile keeps its Lucide
// `User` glyph because no custom PNG was provided for it.
//
// Paths are prefixed with `import.meta.env.BASE_URL` so they resolve
// correctly regardless of where the app is deployed — root, subpath,
// or inside Capacitor's webview (where root-anchored paths like
// "/home.png" fail because the page is loaded via capacitor://).
const ICON_BASE = import.meta.env.BASE_URL || '/';
const TABS = [
  { key: 'home',     label: 'Home',     iconSrc: `${ICON_BASE}home.png`     },
  { key: 'today',    label: 'Train',    iconSrc: `${ICON_BASE}train.png`    },
  { key: 'progress', label: 'Progress', iconSrc: `${ICON_BASE}progress.png` },
  { key: 'gymbros',  label: 'Bros',     iconSrc: `${ICON_BASE}bros.png`     },
  { key: 'profile',  label: 'Profile',  Icon: User                          },
];

// Single icon renderer that handles both the PNG and Lucide cases —
// keeps the tab-button JSX free of conditional chains.
function TabIcon({ tab, active, size = 21, strokeWidth = 1.8 }) {
  if (tab.iconSrc) {
    return (
      <img
        src={tab.iconSrc}
        alt=""
        width={size}
        height={size}
        style={{
          // PNGs already carry the accent silhouette; we just modulate
          // opacity for the inactive state so all five tabs share the
          // same dim/active feel without per-icon variants.
          opacity: active ? 1 : 0.38,
          filter: active ? 'none' : 'grayscale(1) brightness(1.4)',
          objectFit: 'contain',
          flexShrink: 0,
        }}
      />
    );
  }
  const { Icon } = tab;
  return (
    <Icon
      size={size}
      color={active ? C.accent : 'rgba(255,255,255,0.38)'}
      strokeWidth={active ? 2.5 : strokeWidth}
    />
  );
}

const isNative = Capacitor.isNativePlatform();

export default function BottomNav({ activeTab, setActiveTab, t = k => k, lang = 'en' }) {
  if (isNative) {
    // ── Liquid Glass floating pill (iOS) ──────────────────────────────────────
    return (
      <div style={{
        position: 'absolute',
        bottom: 0, left: 0, right: 0,
        zIndex: 100,
        paddingLeft: 12,
        paddingRight: 12,
        paddingTop: 6,
        paddingBottom: 'max(env(safe-area-inset-bottom), 8px)',
        background: 'transparent',
        pointerEvents: 'none',
      }}>
        {/* Floating glass pill container */}
        <div style={{
          display: 'flex',
          height: 64,
          borderRadius: 32,
          background: 'rgba(22, 22, 22, 0.82)',
          backdropFilter: 'blur(40px) saturate(180%) brightness(1.1)',
          WebkitBackdropFilter: 'blur(40px) saturate(180%) brightness(1.1)',
          border: '1px solid rgba(255, 255, 255, 0.10)',
          boxShadow: '0 0 0 0.5px rgba(0,0,0,0.6), 0 8px 32px rgba(0,0,0,0.45), 0 2px 8px rgba(0,0,0,0.3)',
          position: 'relative',
          overflow: 'hidden',
          pointerEvents: 'auto',
        }}>

          {/* Inner glass sheen — top specular highlight */}
          <div style={{
            position: 'absolute',
            top: 0, left: '10%', right: '10%',
            height: 1,
            background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.22), transparent)',
            pointerEvents: 'none',
          }} />

          {TABS.map((tab) => {
            const { key, label } = tab;
            const active = activeTab === key;
            return (
              <button
                key={key}
                onClick={() => { hapticLight(); setActiveTab(key); }}
                style={{
                  flex: 1,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 3,
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  position: 'relative',
                  padding: '6px 0',
                  touchAction: 'manipulation',
                  WebkitTapHighlightColor: 'transparent',
                  minHeight: 44,
                }}
              >
                {/* Active: large dark glass circle — matches the Apple reference */}
                {active && (
                  <motion.div
                    layoutId="glass-pill"
                    transition={spring}
                    style={{
                      position: 'absolute',
                      inset: '4px 5px',
                      borderRadius: 26,
                      // Darker inset glass for the active state
                      background: 'rgba(184,255,0,0.13)',
                      border: '1px solid rgba(184,255,0,0.28)',
                      // Subtle lime glow behind active tab
                      boxShadow: '0 0 14px rgba(184,255,0,0.12)',
                    }}
                  />
                )}

                <TabIcon tab={tab} active={active} size={21} strokeWidth={1.8} />
                <span style={{
                  fontSize: 10,
                  fontWeight: active ? 700 : 500,
                  color: active ? C.accent : 'rgba(255,255,255,0.38)',
                  letterSpacing: lang === 'ar' ? '0' : '0.03em',
                  fontFamily: lang === 'ar' ? "'ThmanyahSans', sans-serif" : undefined,
                }}>
                  {t(label)}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    );
  }

  // ── Original solid bar (web / non-native) ────────────────────────────────
  return (
    <div style={{
      position: 'relative',
      flexShrink: 0,
      display: 'flex',
      flexDirection: 'column',
      background: C.surface,
      borderTop: `1px solid ${C.border}`,
      willChange: 'transform',
      paddingBottom: 'env(safe-area-inset-bottom)',
    }}>
      <div style={{ display: 'flex', height: 49 }}>
        {TABS.map((tab) => {
          const { key, label } = tab;
          const active = activeTab === key;
          return (
            <button
              key={key}
              onClick={() => { hapticLight(); setActiveTab(key); }}
              style={{
                flex: 1,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 3,
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                position: 'relative',
                padding: '8px 0 6px',
                touchAction: 'manipulation',
                WebkitTapHighlightColor: 'transparent',
                minHeight: 44,
              }}
            >
              {active && (
                <motion.div
                  layoutId="nav-indicator"
                  transition={spring}
                  style={{
                    position: 'absolute',
                    top: 0, left: '15%', right: '15%',
                    height: 2,
                    background: C.accent,
                    borderRadius: '0 0 2px 2px',
                  }}
                />
              )}
              <TabIcon tab={tab} active={active} size={20} strokeWidth={2} />
              <span style={{
                fontSize: 10,
                fontWeight: 600,
                color: active ? C.accent : C.mute,
                letterSpacing: lang === 'ar' ? '0' : '0.04em',
                fontFamily: lang === 'ar' ? "'ThmanyahSans', sans-serif" : undefined,
              }}>
                {t(label)}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
