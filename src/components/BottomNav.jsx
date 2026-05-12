import { motion } from 'framer-motion';
import { Home, Dumbbell, TrendingUp, Users, MessageCircle } from 'lucide-react';
import { Capacitor } from '@capacitor/core';
import { C, spring } from '../tokens.js';
import { hapticLight } from '../lib/haptics.js';

const TABS = [
  { key: 'home',     label: 'Home',     Icon: Home },
  { key: 'today',    label: 'Train',    Icon: Dumbbell },
  { key: 'progress', label: 'Progress', Icon: TrendingUp },
  { key: 'gymbros',  label: 'Bros',     Icon: Users },
  { key: 'pt',       label: 'PT',       Icon: MessageCircle },
];

const isNative = Capacitor.isNativePlatform();

export default function BottomNav({ activeTab, setActiveTab, t = k => k, lang = 'en' }) {
  if (isNative) {
    // ── Liquid Glass floating pill (iOS) ──────────────────────────────────────
    return (
      <div style={{
        flexShrink: 0,
        paddingLeft: 12,
        paddingRight: 12,
        paddingTop: 6,
        // Sit above the home indicator, never flush to screen edge
        paddingBottom: 'max(env(safe-area-inset-bottom), 8px)',
        background: 'transparent',
      }}>
        {/* Floating glass pill container */}
        <div style={{
          display: 'flex',
          height: 64,
          borderRadius: 32,
          // Liquid glass: semi-transparent dark with heavy blur
          background: 'rgba(22, 22, 22, 0.82)',
          backdropFilter: 'blur(40px) saturate(180%) brightness(1.1)',
          WebkitBackdropFilter: 'blur(40px) saturate(180%) brightness(1.1)',
          // Glass perimeter border — catches light all the way around
          border: '1px solid rgba(255, 255, 255, 0.10)',
          // Outer glow from the lime accent
          boxShadow: '0 0 0 0.5px rgba(0,0,0,0.6), 0 8px 32px rgba(0,0,0,0.45), 0 2px 8px rgba(0,0,0,0.3)',
          position: 'relative',
          overflow: 'hidden',
        }}>

          {/* Inner glass sheen — top specular highlight */}
          <div style={{
            position: 'absolute',
            top: 0, left: '10%', right: '10%',
            height: 1,
            background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.22), transparent)',
            pointerEvents: 'none',
          }} />

          {TABS.map(({ key, label, Icon }) => {
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
                      background: 'rgba(184,255,0,0.10)',
                      backdropFilter: 'blur(16px)',
                      WebkitBackdropFilter: 'blur(16px)',
                      border: '1px solid rgba(184,255,0,0.22)',
                      // Subtle lime glow behind active tab
                      boxShadow: '0 0 14px rgba(184,255,0,0.12)',
                    }}
                  />
                )}

                <Icon
                  size={21}
                  color={active ? C.accent : 'rgba(255,255,255,0.38)'}
                  strokeWidth={active ? 2.5 : 1.8}
                />
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
        {TABS.map(({ key, label, Icon }) => {
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
              <Icon size={20} color={active ? C.accent : C.mute} strokeWidth={active ? 2.5 : 2} />
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
