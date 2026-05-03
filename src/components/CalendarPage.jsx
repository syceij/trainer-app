import { useState } from 'react';
import { motion } from 'framer-motion';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { C, spring, springSoft } from '../tokens.js';
import {
  MONTH_NAMES_EN, MONTH_NAMES_AR,
  DAY_LABELS_EN, DAY_LABELS_AR,
  headingFont,
} from '../lib/i18n.js';

// Returns array of JS day-of-week indices (0=Sun … 6=Sat) that are training days
function getTrainingDayIndices(profile, importedProgramme, programmeMode) {
  if (programmeMode === 'imported' && importedProgramme) {
    const DAY_TO_IDX = { sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6 };
    const firstWeek  = importedProgramme.weeks?.[0];
    return (firstWeek?.sessions || [])
      .filter(s => !s.isRest && s.day)
      .map(s => DAY_TO_IDX[s.day.toLowerCase().slice(0, 3)])
      .filter(i => i !== undefined);
  }
  const days = profile?.days || 4;
  if (days <= 2) return [1, 4];
  if (days === 3) return [1, 3, 5];
  if (days === 4) return [1, 2, 4, 5];
  if (days === 5) return [1, 2, 3, 4, 5];
  if (days === 6) return [1, 2, 3, 4, 5, 6];
  return [0, 1, 2, 3, 4, 5, 6];
}

// Build a flat array of Date|null for a Mon-first 7-column grid
function buildCalendarGrid(year, month) {
  const firstDay    = new Date(year, month, 1);
  const lastDay     = new Date(year, month + 1, 0);
  const startOffset = (firstDay.getDay() + 6) % 7; // Mon = 0
  const cells = [];
  for (let i = 0; i < startOffset; i++) cells.push(null);
  for (let d = 1; d <= lastDay.getDate(); d++) cells.push(new Date(year, month, d));
  while (cells.length % 7 !== 0) cells.push(null);
  return cells;
}

export default function CalendarPage({ state, onBack }) {
  const { history, profile, importedProgramme, programmeMode, lang, t } = state;

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const [viewYear,  setViewYear]  = useState(today.getFullYear());
  const [viewMonth, setViewMonth] = useState(today.getMonth());

  const trainingDayIdxs = getTrainingDayIndices(profile, importedProgramme, programmeMode);
  const loggedSet       = new Set(history.map(s => new Date(s.date).toDateString()));
  const cells           = buildCalendarGrid(viewYear, viewMonth);

  // In RTL, prev/next arrows flip direction (month nav flips too)
  const rtl      = lang === 'ar';
  const PrevIcon = rtl ? ChevronRight : ChevronLeft;
  const NextIcon = rtl ? ChevronLeft  : ChevronRight;
  const BackIcon = rtl ? ChevronRight : ChevronLeft;

  const MONTH_NAMES = rtl ? MONTH_NAMES_AR : MONTH_NAMES_EN;
  const DAY_LABELS  = rtl ? DAY_LABELS_AR  : DAY_LABELS_EN;

  const prevMonth = () => {
    if (viewMonth === 0) { setViewMonth(11); setViewYear(y => y - 1); }
    else setViewMonth(m => m - 1);
  };
  const nextMonth = () => {
    if (viewMonth === 11) { setViewMonth(0); setViewYear(y => y + 1); }
    else setViewMonth(m => m + 1);
  };

  const getDayBucket = (date) => {
    if (!date) return 'empty';
    const d = new Date(date); d.setHours(0, 0, 0, 0);
    const isLogged   = loggedSet.has(d.toDateString());
    const isTraining = trainingDayIdxs.includes(d.getDay());
    const isPast     = d < today;
    const isFuture   = d > today;
    if (isLogged)               return 'logged';
    if (isPast && isTraining)   return 'missed';
    if (isFuture && isTraining) return 'scheduled';
    return 'rest';
  };

  const BUCKET_STYLES = {
    logged:    { bg: 'rgba(74,222,128,0.25)',  border: 'rgba(74,222,128,0.5)',  color: '#4ADE80' },
    missed:    { bg: 'rgba(255,60,60,0.20)',   border: 'rgba(255,60,60,0.40)',  color: 'rgba(255,100,100,0.9)' },
    scheduled: { bg: 'rgba(184,255,0,0.07)',   border: 'rgba(184,255,0,0.18)', color: C.dim },
    rest:      { bg: 'transparent',            border: 'transparent',           color: C.mute },
    empty:     {},
  };

  // Month stats
  const daysInMonth         = new Date(viewYear, viewMonth + 1, 0).getDate();
  const monthLogs           = history.filter(s => {
    const d = new Date(s.date);
    return d.getMonth() === viewMonth && d.getFullYear() === viewYear;
  });
  const passedTrainingDays  = Array.from({ length: daysInMonth }, (_, i) => new Date(viewYear, viewMonth, i + 1))
    .filter(d => { d.setHours(0, 0, 0, 0); return trainingDayIdxs.includes(d.getDay()) && d <= today; })
    .length;
  const completionPct = passedTrainingDays > 0
    ? Math.round((monthLogs.length / passedTrainingDays) * 100)
    : null;

  return (
    <motion.div
      initial={{ x: rtl ? '-100%' : '100%' }}
      animate={{ x: 0 }}
      exit={{ x: rtl ? '-100%' : '100%' }}
      transition={springSoft}
      style={{ position: 'absolute', inset: 0, background: C.bg, zIndex: 500, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}
    >
      {/* ── Header ── */}
      <div style={{
        paddingTop: 'max(calc(env(safe-area-inset-top, 0px) + 12px), 20px)',
        paddingBottom: 12, paddingLeft: 16, paddingRight: 16,
        display: 'flex', alignItems: 'center', gap: 12,
        borderBottom: `1px solid ${C.border}`, flexShrink: 0, background: C.bg,
      }}>
        <motion.button
          whileTap={{ scale: 0.9 }}
          onClick={onBack}
          style={{
            background: C.surface2, border: `1px solid ${C.border}`,
            borderRadius: 10, padding: '8px 10px',
            cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
            display: 'flex', alignItems: 'center',
          }}
        >
          <BackIcon size={18} color={C.text} />
        </motion.button>
        <span style={{ flex: 1, fontSize: 17, fontWeight: 800, color: C.text, letterSpacing: rtl ? '0' : '-0.02em', fontFamily: headingFont(lang) }}>
          {t('Gym Calendar')}
        </span>
      </div>

      {/* ── Scrollable body ── */}
      <div style={{ flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch' }}>

        {/* Month navigation */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 20px 12px' }}>
          <motion.button
            whileTap={{ scale: 0.9 }}
            onClick={prevMonth}
            style={{
              background: C.surface2, border: `1px solid ${C.border}`,
              borderRadius: 8, padding: '7px 11px',
              cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
              display: 'flex', alignItems: 'center',
            }}
          >
            <PrevIcon size={16} color={C.dim} />
          </motion.button>

          <span style={{ fontSize: 16, fontWeight: 800, color: C.text, letterSpacing: rtl ? '0' : '-0.01em', fontFamily: headingFont(lang) }}>
            {MONTH_NAMES[viewMonth]} {viewYear}
          </span>

          <motion.button
            whileTap={{ scale: 0.9 }}
            onClick={nextMonth}
            style={{
              background: C.surface2, border: `1px solid ${C.border}`,
              borderRadius: 8, padding: '7px 11px',
              cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
              display: 'flex', alignItems: 'center',
            }}
          >
            <NextIcon size={16} color={C.dim} />
          </motion.button>
        </div>

        {/* Day-of-week column labels */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 3, padding: '0 12px 4px' }}>
          {DAY_LABELS.map(d => (
            <div key={d} style={{ textAlign: 'center', fontSize: 10, fontWeight: 700, color: C.mute, letterSpacing: '0.04em', padding: '3px 0' }}>
              {d}
            </div>
          ))}
        </div>

        {/* Calendar grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 3, padding: '0 12px 20px' }}>
          {cells.map((date, i) => {
            if (!date) return <div key={`e${i}`} style={{ aspectRatio: '1' }} />;
            const bucket  = getDayBucket(date);
            const bStyle  = BUCKET_STYLES[bucket];
            const isToday = date.toDateString() === today.toDateString();
            return (
              <motion.div
                key={date.toISOString()}
                initial={{ opacity: 0, scale: 0.85 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ ...spring, delay: Math.min(i * 0.006, 0.18) }}
                style={{
                  aspectRatio: '1', borderRadius: 7,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  background: bStyle.bg, border: `1px solid ${bStyle.border}`,
                  outline: isToday ? `2px solid ${C.accent}` : 'none',
                  outlineOffset: 1, position: 'relative',
                }}
              >
                <span style={{ fontSize: 11, fontWeight: isToday ? 900 : 600, color: isToday ? C.accent : (bStyle.color || C.mute) }}>
                  {date.getDate()}
                </span>
              </motion.div>
            );
          })}
        </div>

        {/* Legend */}
        <div style={{ padding: '0 20px 20px', display: 'flex', gap: 14, flexWrap: 'wrap' }}>
          {[
            { color: 'rgba(74,222,128,0.35)', labelKey: 'Session logged' },
            { color: 'rgba(255,60,60,0.28)',  labelKey: 'Missed training' },
            { color: 'rgba(184,255,0,0.14)',  labelKey: 'Upcoming session' },
          ].map(item => (
            <div key={item.labelKey} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <div style={{ width: 11, height: 11, borderRadius: 3, background: item.color, flexShrink: 0 }} />
              <span style={{ fontSize: 11, color: C.dim }}>{t(item.labelKey)}</span>
            </div>
          ))}
        </div>

        {/* Month stats card */}
        <div style={{
          margin: '0 20px',
          marginBottom: 'max(calc(env(safe-area-inset-bottom, 0px) + 20px), 30px)',
          background: C.surface2, borderRadius: 14,
          border: `1px solid ${C.border}`, padding: '16px 18px',
        }}>
          <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: rtl ? '0' : '0.1em', color: C.dim, marginBottom: 12 }}>
            {rtl ? `${MONTH_NAMES[viewMonth]} — ${t('STATS')}` : `${MONTH_NAMES[viewMonth].toUpperCase()} ${t('STATS')}`}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 0 }}>
            {[
              { labelKey: 'Sessions',      value: monthLogs.length },
              { labelKey: 'Training days', value: passedTrainingDays },
              { labelKey: 'Completion',    value: completionPct !== null ? `${completionPct}%` : '—' },
            ].map((stat, i, arr) => (
              <div key={stat.labelKey} style={{
                textAlign: 'center',
                borderRight: i < arr.length - 1 ? `1px solid ${C.border}` : 'none',
                padding: '0 8px',
              }}>
                <div style={{ fontSize: 22, fontWeight: 800, color: C.text }}>{stat.value}</div>
                <div style={{ fontSize: 10, fontWeight: 600, color: C.mute, marginTop: 3, letterSpacing: '0.04em' }}>
                  {rtl ? t(stat.labelKey) : t(stat.labelKey).toUpperCase()}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </motion.div>
  );
}
