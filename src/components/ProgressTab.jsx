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
import { EXERCISES } from '../lib/programme.js';

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

// ── Muscle progress chart ─────────────────────────────────────────────────────

const MUSCLE_GROUPS = [
  { id: 'chest',     label: 'Chest',     muscles: ['chest'] },
  { id: 'back',      label: 'Back',      muscles: ['back'] },
  { id: 'shoulders', label: 'Shoulders', muscles: ['shoulders'] },
  { id: 'arms',      label: 'Arms',      muscles: ['biceps', 'triceps'] },
  { id: 'legs',      label: 'Legs',      muscles: ['quads', 'hamstrings', 'glutes', 'calves'] },
  { id: 'core',      label: 'Core',      muscles: ['core'] },
];

// Build lookup maps from the EXERCISES library so we can resolve muscle
// even when history exercises don't carry the `muscle` field themselves
// (e.g. imported programmes, or older saved sessions).
const _keyToMuscle  = Object.fromEntries(EXERCISES.map(e => [e.key, e.muscle]));
const _nameToMuscle = Object.fromEntries(EXERCISES.map(e => [e.name.toLowerCase(), e.muscle]));

// FIX 3 — Manual mapping for known name mismatches between sets table and library
const EXERCISE_NAME_MAP = {
  'deadlift':                    'deadlift',
  'incline db press':            'incline db press',
  'cable row':                   'cable row',
  'lat pulldown (neutral grip)': 'lat pulldown',
  'lateral raise (db)':          'lateral raise',
  'skull crusher':               'tricep pushdown',   // closest muscle match: triceps
  'skull crushers':              'tricep pushdown',
  'tricep pushdown (cable)':     'tricep pushdown',
  'hammer curl':                 'hammer curl',
  'cable fly':                   'cable fly',
  'cable crunch':                'cable crunch',
  'barbell bench press':         'barbell bench press',
};

// Extra direct muscle assignments for names that don't exist in the library
const MANUAL_MUSCLE_MAP = {
  'skull crusher':               'triceps',
  'skull crushers':              'triceps',
  'cable crunch':                'core',
  'lat pulldown (neutral grip)': 'back',
  'lateral raise (db)':          'shoulders',
  'tricep pushdown (cable)':     'triceps',
  'hammer curl':                 'biceps',
};

function resolveMuscle(ex) {
  // 1. Muscle already on the exercise object (auto-programme exercises)
  if (ex.muscle) return ex.muscle;

  // 2. Key-based exact lookup
  if (ex.key && _keyToMuscle[ex.key]) return _keyToMuscle[ex.key];

  if (!ex.name) return null;
  const nameLc = ex.name.toLowerCase().trim();

  // 3. Manual muscle map for known mismatches (FIX 3)
  if (MANUAL_MUSCLE_MAP[nameLc]) return MANUAL_MUSCLE_MAP[nameLc];

  // 4. Normalise via alias map then do exact library lookup (FIX 1 + 3)
  const normalised = EXERCISE_NAME_MAP[nameLc] || nameLc;
  if (_nameToMuscle[normalised]) return _nameToMuscle[normalised];

  // 5. Case-insensitive exact match against library (FIX 1)
  if (_nameToMuscle[nameLc]) return _nameToMuscle[nameLc];

  // 6. Partial match — library name contains the first word of the exercise name (FIX 2)
  const firstWord = nameLc.split(' ')[0];
  for (const [libName, muscle] of Object.entries(_nameToMuscle)) {
    if (libName.includes(firstWord)) return muscle;
  }

  // 7. Reverse partial — exercise name contains the library name's first word
  for (const [libName, muscle] of Object.entries(_nameToMuscle)) {
    const libFirst = libName.split(' ')[0];
    if (nameLc.includes(libFirst)) return muscle;
  }

  // FIX 4 — Log anything that still doesn't match so we can add it
  console.log('[MuscleChart] No muscle category found for:', ex.name);
  return null;
}

function calcMuscleImprovements(history) {
  // Collect weight entries per exercise, keyed by exercise name (lowercased)
  const exMap = {};
  for (const session of history) {
    for (const ex of (session.exercises || [])) {
      if (ex.bodyweight) continue;
      const w = Number(ex.weight);
      if (!ex.name || !Number.isFinite(w) || w <= 0) continue;
      const muscle = resolveMuscle(ex);
      if (!muscle) continue;
      const k = ex.name.toLowerCase();
      if (!exMap[k]) exMap[k] = { muscle, entries: [] };
      exMap[k].entries.push({ date: new Date(session.date), weight: w });
    }
  }

  // Per muscle group: collect % improvements from exercises with 2+ data points.
  // Also track whether ANY exercise was logged (for showing bars with 0% change).
  const groupPcts  = {};
  const groupSeen  = {};
  MUSCLE_GROUPS.forEach(mg => { groupPcts[mg.id] = []; groupSeen[mg.id] = false; });

  for (const data of Object.values(exMap)) {
    // Mark the muscle group as "seen" even if only 1 session logged
    for (const mg of MUSCLE_GROUPS) {
      if (mg.muscles.includes(data.muscle)) {
        groupSeen[mg.id] = true;
        break;
      }
    }
    if (data.entries.length < 2) continue;
    const sorted = data.entries.slice().sort((a, b) => a.date - b.date);
    const first  = sorted[0].weight;
    const last   = sorted[sorted.length - 1].weight;
    if (first <= 0) continue;
    const pct = ((last - first) / first) * 100; // can be 0 or negative — intentional
    for (const mg of MUSCLE_GROUPS) {
      if (mg.muscles.includes(data.muscle)) {
        groupPcts[mg.id].push(pct);
        break;
      }
    }
  }

  return MUSCLE_GROUPS.map(mg => {
    const vals   = groupPcts[mg.id];
    const seen   = groupSeen[mg.id];
    // avg of improvements; if only 1 session logged (no pairs), show 0%
    const avg    = vals.length
      ? vals.reduce((s, v) => s + v, 0) / vals.length
      : 0;
    return {
      id:      mg.id,
      label:   mg.label,
      pct:     Math.round(Math.max(avg, 0) * 10) / 10, // clamp negatives to 0 for bar height
      rawPct:  Math.round(avg * 10) / 10,              // real value for stats cards
      hasData: seen,
    };
  });
}

function MuscleProgressChart({ history }) {
  const groups   = calcMuscleImprovements(history);
  const maxPct   = Math.max(...groups.map(g => g.pct), 1);
  // Best = highest pct among groups that have data AND have any improvement
  const improved = groups.filter(g => g.hasData && g.pct > 0);
  const bestId   = improved.length
    ? improved.reduce((b, g) => (g.pct > b.pct ? g : b)).id
    : null;
  const withData = groups.filter(g => g.hasData);
  const mostImproved = improved.length
    ? improved.reduce((b, g) => (g.pct > b.pct ? g : b))
    : null;
  const needsWork = withData.length > 1
    ? withData.reduce((w, g) => (g.pct < w.pct ? g : w))
    : null;

  const BAR_AREA = 72;

  return (
    <div style={{ marginBottom: 24 }}>
      <div style={{
        fontSize: 12, fontWeight: 700,
        letterSpacing: '0.08em', color: C.dim, marginBottom: 14,
      }}>
        MUSCLE PROGRESS
      </div>

      {/* 6-bar chart */}
      <div style={{ display: 'flex', gap: 6, alignItems: 'flex-end', marginBottom: 12 }}>
        {groups.map(g => {
          const isB  = g.id === bestId;
          // Groups with data but 0% improvement get a small stub (8px) so the bar is visible
          const barH = g.hasData
            ? (g.pct > 0 ? Math.max((g.pct / maxPct) * BAR_AREA, 8) : 8)
            : 0;
          return (
            <div
              key={g.id}
              style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5 }}
            >
              {/* % label above bar — show for best only (keeps it uncluttered) */}
              <span style={{
                fontSize: 8, fontWeight: 700,
                color: isB ? C.accent : 'transparent',
                height: 10,
              }}>
                {isB && g.pct > 0 ? `+${g.pct}%` : ''}
              </span>

              {/* Bar area — fixed height so labels align */}
              <div style={{ height: BAR_AREA, width: '100%', display: 'flex', alignItems: 'flex-end' }}>
                {g.hasData ? (
                  <motion.div
                    initial={{ height: 0 }}
                    animate={{ height: barH }}
                    transition={{ type: 'spring', stiffness: 220, damping: 26 }}
                    style={{
                      width: '100%',
                      background: isB ? C.accent : 'rgba(255,255,255,0.13)',
                      borderRadius: '4px 4px 0 0',
                      willChange: 'height',
                    }}
                  />
                ) : (
                  <div style={{
                    width: '100%', height: 22,
                    border: `1.5px dashed ${C.border}`,
                    borderBottom: 'none',
                    borderRadius: '4px 4px 0 0',
                    opacity: 0.6,
                  }} />
                )}
              </div>

              {/* Label */}
              <span style={{
                fontSize: 8, fontWeight: 700,
                color: isB ? C.accent : C.mute,
                letterSpacing: '0.02em',
                textAlign: 'center',
                lineHeight: 1.1,
              }}>
                {g.label.toUpperCase()}
              </span>
            </div>
          );
        })}
      </div>

      {/* Stats row */}
      {withData.length > 0 ? (
        <div style={{ display: 'flex', gap: 8 }}>
          {mostImproved ? (
            <div style={{
              flex: 1,
              background: 'rgba(200,255,0,0.07)',
              border: `1px solid rgba(200,255,0,0.22)`,
              borderRadius: 10, padding: '10px 12px',
            }}>
              <div style={{ fontSize: 9, fontWeight: 700, color: C.accent, letterSpacing: '0.06em', marginBottom: 4 }}>
                MOST IMPROVED
              </div>
              <div style={{ fontSize: 15, fontWeight: 800, color: C.text }}>{mostImproved.label}</div>
              <div style={{ fontSize: 11, fontWeight: 600, color: C.accent, marginTop: 2 }}>+{mostImproved.rawPct}%</div>
            </div>
          ) : (
            <div style={{
              flex: 1, background: C.surface2, border: `1px solid ${C.border}`,
              borderRadius: 10, padding: '10px 12px',
            }}>
              <div style={{ fontSize: 9, fontWeight: 700, color: C.mute, letterSpacing: '0.06em', marginBottom: 4 }}>
                PROGRESS
              </div>
              <div style={{ fontSize: 13, fontWeight: 700, color: C.dim }}>Keep training</div>
              <div style={{ fontSize: 11, color: C.mute, marginTop: 2 }}>Improvements show after more sessions</div>
            </div>
          )}
          {needsWork && needsWork.id !== mostImproved?.id && (
            <div style={{
              flex: 1,
              background: C.surface2,
              border: `1px solid ${C.border}`,
              borderRadius: 10, padding: '10px 12px',
            }}>
              <div style={{ fontSize: 9, fontWeight: 700, color: C.mute, letterSpacing: '0.06em', marginBottom: 4 }}>
                NEEDS WORK
              </div>
              <div style={{ fontSize: 15, fontWeight: 800, color: C.text }}>{needsWork.label}</div>
              <div style={{ fontSize: 11, fontWeight: 600, color: C.dim, marginTop: 2 }}>
                {needsWork.rawPct > 0 ? `+${needsWork.rawPct}%` : 'No gains yet'}
              </div>
            </div>
          )}
        </div>
      ) : (
        <div style={{ textAlign: 'center', padding: '6px 0', color: C.mute, fontSize: 12 }}>
          Log your first session to see muscle progress
        </div>
      )}
    </div>
  );
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

      {/* ── Muscle Progress ─────────────────────────────────────────────── */}
      <MuscleProgressChart history={history} />

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
