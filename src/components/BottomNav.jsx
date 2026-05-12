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
  return (
    <div style={{
      position: 'relative',
      flexShrink: 0,
      display: 'flex',
      flexDirection: 'column',
      // ── Liquid Glass (iOS) ──────────────────────────────────────────────────
      // Semi-transparent dark background so the scrolled list blurs behind it.
      // backdrop-filter is hardware-accelerated in WKWebView — no perf hit.
      background: isNative
        ? 'rgba(10, 10, 10, 0.72)'
        : C.surface,
      backdropFilter:       isNative ? 'blur(24px) saturate(160%)' : undefined,
      WebkitBackdropFilter: isNative ? 'blur(24px) saturate(160%)' : undefined,
      // Glass edge instead of a hard 1px line
      borderTop: isNative ? 'none' : `1px solid ${C.border}`,
      willChange: 'transform',
      paddingBottom: 'env(safe-area-inset-bottom)',
    }}>

      {/* Glass edge — thin gradient bar that simulates light catching the rim */}
      {isNative && (
        <div style={{
          position: 'absolute',
          top: 0, left: 0, right: 0,
          height: 1,
          background: 'linear-gradient(90deg, transparent 0%, rgba(255,255,255,0.20) 25%, rgba(255,255,255,0.20) 75%, transparent 100%)',
          pointerEvents: 'none',
          zIndex: 1,
        }} />
      )}

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
              {/* ── iOS: animated lime glass pill behind active tab ─────────── */}
              {active && isNative && (
                <motion.div
                  layoutId="nav-pill"
                  transition={spring}
                  style={{
                    position: 'absolute',
                    inset: '4px 8px',
                    borderRadius: 12,
                    background: 'rgba(184,255,0,0.09)',
                    backdropFilter:       'blur(10px)',
                    WebkitBackdropFilter: 'blur(10px)',
                    border: '1px solid rgba(184,255,0,0.20)',
                  }}
                />
              )}

              {/* ── Web: keep the original top-line indicator ───────────────── */}
              {active && !isNative && (
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

              <Icon
                size={20}
                color={active ? C.accent : C.mute}
                strokeWidth={active ? 2.5 : 2}
              />
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
