import { motion } from 'framer-motion';
import { Zap, ChevronLeft, ChevronRight, Flame } from 'lucide-react';
import { C, spring } from '../tokens.js';
import { getWeekSessions, importedSessionToRuntime } from '../lib/importHelpers.js';
import { headingFont, translateContent, translateDay, toEasternArabic } from '../lib/i18n.js';

function greeting(lang) {
  const h = new Date().getHours();
  if (lang === 'ar') {
    return h < 12 ? 'صــباح الخير' : 'مسـاء الخيـر';
  }
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

const DAY_KEYS = ['sun','mon','tue','wed','thu','fri','sat'];

export default function HomeTab({ state }) {
  const {
    profile, programmeMode, importedProgramme, currentWeek, setCurrentWeek,
    currentSession, setCurrentSession, programme, history,
    streak, totalSessions, currentStreakCount, lastWeightAdded,
    setActiveTab, setProgrammeView,
    lang, setLang, t,
  } = state;

  // In RTL, "forward" arrows flip direction
  const FwdIcon = lang === 'ar' ? ChevronLeft : ChevronRight;

  const name       = profile?.name || 'there';
  const totalWeeks = importedProgramme?.totalWeeks || importedProgramme?.weeks?.length || 1;
  const weekNum    = Math.max(1, Math.ceil((history.length + 1) / (programme.length || 1)));

  const weekSessions = programmeMode === 'imported'
    ? getWeekSessions(importedProgramme, currentWeek)
    : [];

  const selectImportedSession = (session) => {
    const runtime = importedSessionToRuntime(session);
    if (runtime) { setCurrentSession(runtime); setActiveTab('today'); }
  };

  const lastVol = lastWeightAdded
    ? history.slice().reverse()
        .find(h => h.exercises?.some(e => e.weight > 0))
        ?.exercises?.reduce((s, e) => s + (e.weight || 0) * e.sets, 0)
    : null;

  // Arabic greeting: comma is ، and skip "there"
  const greetingLine = lang === 'ar'
    ? `${greeting(lang)}${profile?.name ? `، ${profile.name}` : ''} 👋`
    : `${greeting(lang)}, ${name} 👋`;

  return (
    <div style={{ padding: '0 20px', paddingTop: 20, paddingBottom: 20 }}>

      {/* ── Greeting + language toggle ── */}
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 20 }}>
        <motion.h1
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ ...spring, delay: 0.05 }}
          style={{
            fontSize: 26, fontWeight: 800, letterSpacing: '-0.02em', color: C.text,
            fontFamily: headingFont(lang),
            flex: 1,
          }}
        >
          {greetingLine}
        </motion.h1>

        <button
          onClick={() => setLang(lang === 'ar' ? 'en' : 'ar')}
          style={{
            flexShrink: 0, marginTop: 4,
            background: C.surface2, border: `1.5px solid ${C.border}`,
            borderRadius: 8, padding: '6px 12px',
            fontSize: 12, fontWeight: 700, color: C.dim,
            cursor: 'pointer', touchAction: 'manipulation',
            WebkitTapHighlightColor: 'transparent',
            // Always Inter so EN/AR label is always legible
            fontFamily: 'Inter, system-ui, sans-serif',
          }}
        >
          {lang === 'ar' ? 'EN' : 'AR'}
        </button>
      </div>

      {/* ── Today card ── */}
      {currentSession && (
        <motion.button
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ ...spring, delay: 0.08 }}
          whileTap={{ scale: 0.98 }}
          onClick={() => setActiveTab('today')}
          style={{
            width: '100%', background: C.accent, border: 'none',
            borderRadius: 16, padding: '18px 20px', marginBottom: 14,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
            textAlign: lang === 'ar' ? 'right' : 'left',
          }}
        >
          <div>
            <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.1em', color: 'rgba(0,0,0,0.6)', marginBottom: 4, display: 'flex', alignItems: 'center', gap: 4 }}>
              <Zap size={11} color="rgba(0,0,0,0.6)" strokeWidth={2.5} />
              {t("TODAY'S SESSION")}
            </div>
            <div style={{
              fontSize: 22, fontWeight: 800, color: '#000',
              letterSpacing: lang === 'ar' ? '0' : '-0.02em', marginBottom: 4,
              fontFamily: headingFont(lang),
            }}>
              {translateContent(currentSession.name, lang)}
            </div>
            <div style={{ fontSize: 12, color: 'rgba(0,0,0,0.55)', fontWeight: 500 }}>
              {currentSession.exercises?.length || 0} {t('exercises')} · ~{Math.round((currentSession.exercises?.length || 5) * 6)} {t('min')}
            </div>
          </div>
          <FwdIcon size={20} color="rgba(0,0,0,0.6)" />
        </motion.button>
      )}

      {/* ── Week badge ── */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.12 }}
        style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 20 }}
      >
        <span style={{
          background: C.surface2, border: `1.5px solid ${C.border}`,
          borderRadius: 100, padding: '5px 12px',
          fontSize: 12, fontWeight: 700, color: C.dim,
        }}>
          {programmeMode === 'imported'
            ? `${t('Week')} ${currentWeek} / ${totalWeeks}`
            : `${t('Week')} ${weekNum} · ${t('Block')} 1`}
        </span>
      </motion.div>

      {/* ── Imported: week selector + day grid ── */}
      {programmeMode === 'imported' && importedProgramme && (
        <>
          {/* Week pill strip — explicit direction so W1 is on the right in RTL */}
          <div style={{ overflowX: 'auto', WebkitOverflowScrolling: 'touch', marginBottom: 16, direction: lang === 'ar' ? 'rtl' : undefined }}>
            <div style={{ display: 'flex', gap: 6, paddingBottom: 4 }}>
              {importedProgramme.weeks.map(w => {
                const active = w.weekNumber === currentWeek;
                return (
                  <motion.button
                    key={w.weekNumber}
                    whileTap={{ scale: 0.95 }}
                    onClick={() => setCurrentWeek(w.weekNumber)}
                    style={{
                      flexShrink: 0, padding: '6px 14px', borderRadius: 100,
                      background: active ? C.accent : C.surface2,
                      border: `1.5px solid ${active ? C.accent : C.border}`,
                      color: active ? '#000' : C.dim,
                      fontSize: 12, fontWeight: 700,
                      cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                    }}
                  >
                    {lang === 'ar'
                      ? `أ${toEasternArabic(w.weekNumber)}`
                      : (w.label ? w.label.replace('Week ', 'W') : `W${w.weekNumber}`)}
                  </motion.button>
                );
              })}
            </div>
          </div>

          {/* Day grid */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 1, marginBottom: 20 }}>
            {weekSessions.map((s, i) => {
              const isRest  = s.isRest || !s.name;
              const isToday = DAY_KEYS[new Date().getDay()] === s.day;
              return (
                <motion.div
                  key={s.day}
                  initial={{ opacity: 0, x: lang === 'ar' ? 8 : -8 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ ...spring, delay: i * 0.03 }}
                  onClick={!isRest ? () => selectImportedSession(s) : undefined}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    padding: '11px 14px',
                    background: isToday ? 'rgba(184,255,0,0.06)' : C.surface,
                    borderRadius: 10,
                    border: `1px solid ${isToday ? 'rgba(184,255,0,0.2)' : C.border}`,
                    cursor: isRest ? 'default' : 'pointer',
                    touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                  }}
                >
                  <span style={{ width: 36, fontSize: 12, fontWeight: 700, color: isRest ? C.mute : C.accent }}>
                    {translateDay(s.day, lang)}
                  </span>
                  <span style={{ flex: 1, fontSize: 13, fontWeight: 600, color: isRest ? C.mute : C.text }}>
                    {isRest ? t('Rest') : translateContent(s.name, lang)}
                    {s.focus && <span style={{ fontSize: 11, color: C.dim, fontWeight: 400 }}> · {translateContent(s.focus, lang)}</span>}
                  </span>
                  {!isRest && <FwdIcon size={14} color={C.mute} />}
                </motion.div>
              );
            })}
          </div>
        </>
      )}

      {/* ── Auto: streak row ── */}
      {programmeMode === 'auto' && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 20 }}>
          <span style={{ fontSize: 12, fontWeight: 600, color: C.dim }}>{t('Streak')}</span>
          <div style={{ display: 'flex', gap: 5 }}>
            {streak.map((done, i) => (
              <motion.div
                key={i}
                animate={{ background: done ? C.accent : C.surface2 }}
                transition={spring}
                style={{ width: 10, height: 10, borderRadius: '50%', border: `1.5px solid ${done ? C.accent : C.border}` }}
              />
            ))}
          </div>
          {currentStreakCount > 0 && (
            <span style={{ fontSize: 12, color: C.accent, fontWeight: 700 }}>{currentStreakCount} 🔥</span>
          )}
        </div>
      )}

      {/* ── Stats row ── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, marginBottom: 20 }}>
        {[
          { key: 'Sessions', value: totalSessions },
          { key: 'Streak',   value: `${currentStreakCount} 🔥` },
          { key: 'Last vol.', value: lastVol ? `${Math.round(lastVol / 1000)}t` : '—' },
        ].map(stat => (
          <div key={stat.key} style={{
            background: C.surface2, borderRadius: 10,
            border: `1px solid ${C.border}`,
            padding: '12px 10px', textAlign: 'center',
          }}>
            <div style={{ fontSize: 18, fontWeight: 800, color: C.text }}>{stat.value}</div>
            <div style={{
              fontSize: 10, fontWeight: 600, color: C.mute,
              letterSpacing: lang === 'ar' ? '0' : '0.06em', marginTop: 2,
            }}>
              {lang === 'ar' ? t(stat.key) : t(stat.key).toUpperCase()}
            </div>
          </div>
        ))}
      </div>

      {/* ── Auto: Up Next ── */}
      {programmeMode === 'auto' && programme.length > 1 && (
        <div style={{
          background: C.surface2, borderRadius: 12, border: `1px solid ${C.border}`,
          padding: '14px 16px', marginBottom: 14,
        }}>
          <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: lang === 'ar' ? '0' : '0.1em', color: C.dim, marginBottom: 8 }}>
            {t('UP NEXT')}
          </div>
          <div style={{ fontSize: 15, fontWeight: 700, color: C.text, marginBottom: 6 }}>
            {translateContent(programme[1]?.name || programme[0]?.name, lang)}
          </div>
          {programme[1]?.exercises?.slice(0, 3).map(ex => (
            <div key={ex.key} style={{ fontSize: 12, color: C.dim, marginBottom: 2 }}>· {ex.name}</div>
          ))}
        </div>
      )}

      {/* ── Programme link ── */}
      <motion.button
        whileTap={{ scale: 0.97 }}
        onClick={() => setProgrammeView(true)}
        style={{
          width: '100%', background: C.surface2, border: `1px solid ${C.border}`,
          borderRadius: 12, padding: '14px 16px',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
        }}
      >
        <span style={{ fontSize: 14, fontWeight: 600, color: C.text }}>
          {programmeMode === 'imported'
            ? translateContent(importedProgramme?.name, lang)
            : t('View full programme')}
        </span>
        <FwdIcon size={16} color={C.mute} />
      </motion.button>
    </div>
  );
}
