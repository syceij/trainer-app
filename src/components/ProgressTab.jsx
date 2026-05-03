import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ChevronDown, ChevronUp, ChevronRight,
  Calendar, TrendingUp, Plus, Pencil,
} from 'lucide-react';
import BottomSheet from './shared/BottomSheet.jsx';
import ExercisePickerSheet from './ExercisePickerSheet.jsx';
import ExerciseLiftPage from './ExerciseLiftPage.jsx';
import { C, spring } from '../tokens.js';
import { headingFont, translateContent } from '../lib/i18n.js';

// ── Sparkline (mini weight-trend inline chart) ─────────────────────────────────

function Sparkline({ data }) {
  if (!data || data.length < 2) {
    return <div style={{ height: 28 }} />;
  }
  const min   = Math.min(...data);
  const max   = Math.max(...data);
  const range = max - min || 1;
  const W = 72, H = 28;
  const pts = data.map((v, i) => {
    const x = (i / (data.length - 1)) * W;
    const y = H - ((v - min) / range) * (H - 4) - 2;
    return `${x},${y}`;
  }).join(' ');
  const last = pts.split(' ').pop().split(',');
  return (
    <svg width={W} height={H} style={{ overflow: 'visible' }}>
      <polyline fill="none" stroke={C.accent} strokeWidth="1.5" strokeLinejoin="round" points={pts} />
      <circle cx={last[0]} cy={last[1]} r="2.5" fill={C.accent} />
    </svg>
  );
}

// ── Weekly volume bar chart ────────────────────────────────────────────────────

function getWeeklyVolumes(history) {
  const weeks = [];
  const now   = Date.now();
  for (let i = 5; i >= 0; i--) {
    const start = now - (i + 1) * 7 * 86400000;
    const end   = now - i * 7 * 86400000;
    const vol = history
      .filter(s => { const t = new Date(s.date).getTime(); return t >= start && t < end; })
      .reduce((sum, s) => sum + (s.volume || 0), 0);
    weeks.push(vol);
  }
  return weeks;
}

// ── Most improved ─────────────────────────────────────────────────────────────

function getMostImproved(history) {
  const exMap = {};
  for (const session of history) {
    for (const ex of (session.exercises || [])) {
      if (ex.bodyweight || !ex.weight || !ex.key) continue;
      if (!exMap[ex.key]) exMap[ex.key] = { name: ex.name, entries: [] };
      exMap[ex.key].entries.push({ date: new Date(session.date), weight: ex.weight });
    }
  }
  const improved = [];
  for (const [key, data] of Object.entries(exMap)) {
    if (data.entries.length < 2) continue;
    const sorted = data.entries.slice().sort((a, b) => a.date - b.date);
    const first  = sorted[0].weight;
    const last   = sorted[sorted.length - 1].weight;
    const delta  = last - first;
    if (delta > 0) {
      improved.push({ key, name: data.name, first, last, delta, pct: Math.round((delta / first) * 100) });
    }
  }
  return improved.sort((a, b) => b.delta - a.delta).slice(0, 4);
}

// ── Fuzzy weight lookup ────────────────────────────────────────────────────────
/**
 * Look up a tracked lift weight from the in-memory weights map using:
 *   1. Exact name match
 *   2. First-2-word case-insensitive prefix match
 *      e.g. "Lateral Raise" → matches "Lateral raise (DB)"
 *           "Tricep Pushdown" → matches "Tricep pushdown (cable)"
 *
 * Returns { weight, canonicalName } — canonicalName is the actual key found in
 * the map, which may differ from liftName when a fuzzy match was used.
 * Returns null when no match is found.
 */
function resolveWeight(liftName, weightsMap) {
  if (!liftName || !weightsMap) return null;
  // 1. Exact match
  if (weightsMap[liftName] != null) {
    return { weight: weightsMap[liftName], canonicalName: liftName };
  }
  // 2. First-2-word prefix, case-insensitive
  const prefix = liftName.split(' ').slice(0, 2).join(' ').toLowerCase();
  for (const [key, weight] of Object.entries(weightsMap)) {
    if (key.toLowerCase().includes(prefix)) {
      return { weight, canonicalName: key };
    }
  }
  return null;
}

// ── ProgressTab ────────────────────────────────────────────────────────────────

export default function ProgressTab({ state }) {
  const {
    weights, history, setCalendarView,
    lang, t,
    trackedLifts, updateTrackedLifts,
    user,
  } = state;

  const [expandedSession, setExpandedSession] = useState(null);

  // Tracked lift card interactions
  const [actionSheet, setActionSheet]       = useState(null);  // slot index | null
  const [pickerSlot,  setPickerSlot]        = useState(null);  // slot index | null
  const [liftPage,    setLiftPage]          = useState(null);  // { name, key } | null

  const weekVols = getWeeklyVolumes(history);
  const maxVol   = Math.max(...weekVols, 1);

  // Sparkline for a given exercise name: last 8 session weights
  const sparkFor = (exerciseName) => {
    if (!exerciseName) return [];
    return history
      .flatMap(s => (s.exercises || []).filter(e =>
        e.name === exerciseName && !e.bodyweight && e.weight
      ))
      .map(e => Number(e.weight))
      .filter(Boolean)
      .slice(-8);
  };

  // Working weight for a tracked lift — uses fuzzy prefix matching as fallback.
  const weightFor = (lift) => {
    if (!lift) return null;
    return resolveWeight(lift.name, weights)?.weight ?? null;
  };

  // Self-heal: when a fuzzy match resolves a different canonical name, update
  // tracked_lifts so future lookups are exact (no fuzzy pass needed).
  // Runs once weights and trackedLifts are both loaded; terminates after one
  // corrective pass because the second run finds all names already exact.
  useEffect(() => {
    if (!trackedLifts || Object.keys(weights).length === 0) return;
    let changed = false;
    const healed = trackedLifts.map(lift => {
      if (!lift?.name) return lift;
      if (weights[lift.name] != null) return lift; // already exact — skip
      const resolved = resolveWeight(lift.name, weights);
      if (resolved && resolved.canonicalName !== lift.name) {
        changed = true;
        return { ...lift, name: resolved.canonicalName };
      }
      return lift;
    });
    if (changed) updateTrackedLifts(healed);
  }, [trackedLifts, weights, updateTrackedLifts]);

  // Handle exercise picked from picker sheet
  const handleExercisePick = (ex) => {
    if (pickerSlot === null) return;
    const newLifts = [...(trackedLifts || [null, null, null, null])];
    newLifts[pickerSlot] = { name: ex.name, key: ex.key || null };
    updateTrackedLifts(newLifts);
    setPickerSlot(null);
  };

  // Four slots — normalise in case state is not yet loaded
  const slots = trackedLifts ?? [null, null, null, null];

  return (
    <div style={{
      padding: '0 20px',
      paddingTop: 'max(env(safe-area-inset-top, 0px) + 16px, 24px)',
      paddingBottom: 20,
    }}>
      <motion.h1
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        style={{
          fontSize: 26, fontWeight: 800,
          letterSpacing: lang === 'ar' ? '0' : '-0.02em',
          color: C.text, marginBottom: 18,
          fontFamily: headingFont(lang),
        }}
      >
        {t('Progress')}
      </motion.h1>

      {/* ── Tracked lifts grid ──────────────────────────────────────────── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 24 }}>
        {slots.map((lift, idx) => {
          const spark  = sparkFor(lift?.name);
          const curWt  = weightFor(lift);

          // ── Empty slot ──
          if (!lift) {
            return (
              <motion.button
                key={idx}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ ...spring, delay: idx * 0.06 }}
                whileTap={{ scale: 0.97 }}
                onClick={() => setPickerSlot(idx)}
                style={{
                  background: 'transparent',
                  border: `1.5px dashed ${C.border}`,
                  borderRadius: 14, padding: '18px 12px',
                  display: 'flex', flexDirection: 'column',
                  alignItems: 'center', justifyContent: 'center',
                  gap: 8, cursor: 'pointer',
                  touchAction: 'manipulation',
                  WebkitTapHighlightColor: 'transparent',
                  minHeight: 100,
                }}
              >
                <div style={{
                  width: 28, height: 28, borderRadius: '50%',
                  background: C.surface2, border: `1px solid ${C.border}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <Plus size={14} color={C.dim} strokeWidth={2.5} />
                </div>
                <span style={{ fontSize: 11, fontWeight: 600, color: C.mute, textAlign: 'center' }}>
                  Tap to add a lift to track
                </span>
              </motion.button>
            );
          }

          // ── Filled slot ──
          return (
            <motion.button
              key={idx}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ ...spring, delay: idx * 0.06 }}
              whileTap={{ scale: 0.97 }}
              onClick={() => setActionSheet(idx)}
              style={{
                background: C.surface2, border: `1px solid ${C.border}`,
                borderRadius: 14, padding: '12px 13px 10px',
                textAlign: 'left', cursor: 'pointer',
                touchAction: 'manipulation',
                WebkitTapHighlightColor: 'transparent',
              }}
            >
              {/* Name + pencil */}
              <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 6 }}>
                <div style={{
                  fontSize: 10, fontWeight: 700, color: C.dim,
                  letterSpacing: '0.06em', lineHeight: 1.3,
                  flex: 1, paddingRight: 4,
                }}>
                  {lift.name.toUpperCase()}
                </div>
                <Pencil size={11} color={C.mute} strokeWidth={2} style={{ flexShrink: 0, marginTop: 1 }} />
              </div>

              {/* Weight */}
              <div style={{ fontSize: 22, fontWeight: 800, color: C.text, marginBottom: 8, lineHeight: 1 }}>
                {curWt !== null ? curWt : '—'}
                {curWt !== null && (
                  <span style={{ fontSize: 11, fontWeight: 500, color: C.dim, marginLeft: 3 }}>kg</span>
                )}
              </div>

              {/* Sparkline */}
              <Sparkline data={spark.length ? spark : (curWt ? [curWt] : [])} />
            </motion.button>
          );
        })}
      </div>

      {/* ── View Calendar ──────────────────────────────────────────────── */}
      <motion.button
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ ...spring, delay: 0.22 }}
        whileTap={{ scale: 0.97 }}
        onClick={() => setCalendarView && setCalendarView(true)}
        style={{
          width: '100%', background: C.surface2, border: `1px solid ${C.border}`,
          borderRadius: 12, padding: '14px 16px', marginBottom: 24,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          cursor: 'pointer', touchAction: 'manipulation',
          WebkitTapHighlightColor: 'transparent',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Calendar size={16} color={C.accent} />
          <span style={{ fontSize: 14, fontWeight: 600, color: C.text }}>{t('View Gym Calendar')}</span>
        </div>
        <ChevronRight size={16} color={C.mute} />
      </motion.button>

      {/* ── Most improved ──────────────────────────────────────────────── */}
      {(() => {
        const improved = getMostImproved(history);
        if (!improved.length) return null;
        return (
          <div style={{ marginBottom: 24 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
              <TrendingUp size={13} color={C.accent} />
              <span style={{
                fontSize: 12, fontWeight: 700,
                letterSpacing: lang === 'ar' ? '0' : '0.08em', color: C.dim,
              }}>
                {t('MOST IMPROVED')}
              </span>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {improved.map((item, i) => (
                <motion.div
                  key={item.key}
                  initial={{ opacity: 0, x: lang === 'ar' ? 8 : -8 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ ...spring, delay: i * 0.05 }}
                  style={{
                    background: C.surface2, borderRadius: 12,
                    border: `1px solid ${C.border}`,
                    padding: '12px 14px',
                    display: 'flex', alignItems: 'center', gap: 12,
                  }}
                >
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13, fontWeight: 700, color: C.text, marginBottom: 3 }}>{item.name}</div>
                    <div style={{ fontSize: 11, color: C.dim }}>{item.first} kg → {item.last} kg</div>
                  </div>
                  <div style={{ textAlign: 'right', flexShrink: 0 }}>
                    <div style={{ fontSize: 16, fontWeight: 800, color: '#4ADE80' }}>+{item.delta} kg</div>
                    <div style={{ fontSize: 11, color: C.dim, marginTop: 2 }}>+{item.pct}%</div>
                  </div>
                </motion.div>
              ))}
            </div>
          </div>
        );
      })()}

      {/* ── Weekly volume ──────────────────────────────────────────────── */}
      <div style={{ marginBottom: 24 }}>
        <div style={{
          fontSize: 12, fontWeight: 700,
          letterSpacing: lang === 'ar' ? '0' : '0.08em', color: C.dim, marginBottom: 12,
        }}>
          {t('WEEKLY VOLUME')}
        </div>
        <div style={{ display: 'flex', gap: 6, alignItems: 'flex-end', height: 80 }}>
          {weekVols.map((vol, i) => {
            const pct = maxVol > 0 ? vol / maxVol : 0;
            return (
              <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                <motion.div
                  initial={{ height: 0 }}
                  animate={{ height: `${Math.max(pct * 64, vol > 0 ? 4 : 0)}px` }}
                  transition={spring}
                  style={{
                    width: '100%', background: C.accent,
                    borderRadius: '3px 3px 0 0', minHeight: 0, willChange: 'height',
                  }}
                />
                <span style={{ fontSize: 9, color: C.mute, fontWeight: 600 }}>W{i + 1}</span>
              </div>
            );
          })}
        </div>
      </div>

      {/* ── Session history ─────────────────────────────────────────────── */}
      <div style={{
        fontSize: 12, fontWeight: 700,
        letterSpacing: lang === 'ar' ? '0' : '0.08em', color: C.dim, marginBottom: 12,
      }}>
        {t('HISTORY')}
      </div>
      {history.length === 0 ? (
        <p style={{ fontSize: 13, color: C.mute, textAlign: 'center', padding: '20px 0' }}>
          {t('Complete your first session to see history.')}
        </p>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[...history].reverse().map((session) => {
            const expanded = expandedSession === session.id;
            return (
              <div
                key={session.id}
                style={{ background: C.surface2, borderRadius: 12, border: `1px solid ${C.border}`, overflow: 'hidden' }}
              >
                <button
                  onClick={() => setExpandedSession(expanded ? null : session.id)}
                  style={{
                    width: '100%', background: 'none', border: 'none',
                    padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10,
                    cursor: 'pointer', touchAction: 'manipulation',
                    WebkitTapHighlightColor: 'transparent',
                  }}
                >
                  <div style={{ flex: 1, textAlign: lang === 'ar' ? 'right' : 'left' }}>
                    <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>
                      {translateContent(session.name, lang)}
                    </div>
                    <div style={{ fontSize: 11, color: C.dim }}>
                      {new Date(session.date).toLocaleDateString()} ·{' '}
                      {session.exercises?.length || 0} {t('exercises')} ·{' '}
                      {Math.round(session.volume || 0)} {t('kg vol.')}
                    </div>
                  </div>
                  {expanded
                    ? <ChevronUp   size={14} color={C.mute} />
                    : <ChevronDown size={14} color={C.mute} />}
                </button>
                <AnimatePresence>
                  {expanded && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={spring}
                      style={{ overflow: 'hidden' }}
                    >
                      <div style={{ padding: '0 14px 12px', borderTop: `1px solid ${C.border}` }}>
                        {session.exercises?.map((ex, ei) => (
                          <div
                            key={ei}
                            style={{
                              display: 'flex', justifyContent: 'space-between',
                              padding: '7px 0',
                              borderBottom: ei < session.exercises.length - 1
                                ? `1px solid ${C.border}` : 'none',
                            }}
                          >
                            <span style={{ fontSize: 13, color: C.text }}>{ex.name}</span>
                            <span style={{ fontSize: 12, color: C.dim }}>
                              {ex.sets}×{ex.reps} @ {ex.bodyweight ? t('BW') : `${ex.weight}kg`}
                            </span>
                          </div>
                        ))}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            );
          })}
        </div>
      )}

      {/* ── Action sheet (filled card tapped) ──────────────────────────── */}
      <BottomSheet open={actionSheet !== null} onClose={() => setActionSheet(null)}>
        {actionSheet !== null && slots[actionSheet] && (
          <div>
            <div style={{ fontSize: 12, fontWeight: 700, color: C.dim, letterSpacing: '0.06em', marginBottom: 4 }}>
              TRACKED LIFT
            </div>
            <div style={{ fontSize: 17, fontWeight: 800, color: C.text, marginBottom: 20 }}>
              {slots[actionSheet].name}
            </div>

            {/* Change exercise */}
            <motion.button
              whileTap={{ scale: 0.97 }}
              onClick={() => { setPickerSlot(actionSheet); setActionSheet(null); }}
              style={{
                width: '100%', background: C.surface2, border: `1px solid ${C.border}`,
                borderRadius: 12, padding: '15px 16px', marginBottom: 10,
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                cursor: 'pointer', touchAction: 'manipulation',
                WebkitTapHighlightColor: 'transparent',
              }}
            >
              <span style={{ fontSize: 15, fontWeight: 700, color: C.text }}>Change exercise</span>
              <Pencil size={16} color={C.dim} />
            </motion.button>

            {/* View progress */}
            <motion.button
              whileTap={{ scale: 0.97 }}
              onClick={() => { setLiftPage(slots[actionSheet]); setActionSheet(null); }}
              style={{
                width: '100%', background: C.accent, border: 'none',
                borderRadius: 12, padding: '15px 16px',
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                cursor: 'pointer', touchAction: 'manipulation',
                WebkitTapHighlightColor: 'transparent',
              }}
            >
              <span style={{ fontSize: 15, fontWeight: 700, color: '#000' }}>View progress</span>
              <TrendingUp size={16} color="#000" />
            </motion.button>
          </div>
        )}
      </BottomSheet>

      {/* ── Exercise picker (empty slot or "Change exercise") ───────────── */}
      <ExercisePickerSheet
        open={pickerSlot !== null}
        onClose={() => setPickerSlot(null)}
        currentKey={pickerSlot !== null ? (slots[pickerSlot]?.key ?? null) : null}
        currentName={pickerSlot !== null ? (slots[pickerSlot]?.name ?? null) : null}
        onSelect={handleExercisePick}
        lang={lang}
        t={t}
      />

      {/* ── Exercise progress page (full-screen slide-over) ─────────────── */}
      <AnimatePresence>
        {liftPage && (
          <ExerciseLiftPage
            key={liftPage.name}
            exercise={liftPage}
            userId={user?.id}
            onBack={() => setLiftPage(null)}
          />
        )}
      </AnimatePresence>
    </div>
  );
}
