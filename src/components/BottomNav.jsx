import { motion } from 'framer-motion';
import { Home, Dumbbell, TrendingUp, MessageCircle } from 'lucide-react';
import { C, spring } from '../tokens.js';

const TABS = [
  { key: 'home',     label: 'Home',     Icon: Home },
  { key: 'today',    label: 'Train',    Icon: Dumbbell },
  { key: 'progress', label: 'Progress', Icon: TrendingUp },
  { key: 'pt',       label: 'PT',       Icon: MessageCircle },
];

export default function BottomNav({ activeTab, setActiveTab, t = k => k, lang = 'en' }) {
  return (
    <div style={{
      position: 'relative',
      flexShrink: 0,
      display: 'flex',
      background: C.surface,
      borderTop: `1px solid ${C.border}`,
      paddingBottom: 'env(safe-area-inset-bottom, 0px)',
      minHeight: 49,
      willChange: 'transform',
    }}>
      {TABS.map(({ key, label, Icon }) => {
        const active = activeTab === key;
        return (
          <button
            key={key}
            onClick={() => setActiveTab(key)}
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
  );
}
