import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, ChevronDown, ChevronUp, Check, X } from 'lucide-react';
import { EXERCISES } from '../lib/programme.js';
import { C, spring } from '../tokens.js';

// ── Category map ─────────────────────────────────────────────────────────────
export const EXERCISE_CATEGORIES = [
  { label: 'Chest',                 keys: ['bench_press','incline_bench','db_press','incline_db_press','db_fly','cable_fly','chest_press_machine','pec_deck','pushup','dip'] },
  { label: 'Front Shoulders',       keys: ['ohp','db_ohp','machine_shoulder','front_raise'] },
  { label: 'Side Shoulders',        keys: ['lateral_raise','cable_lateral'] },
  { label: 'Rear Shoulders',        keys: ['rear_delt_fly','face_pull'] },
  { label: 'Back Width',            keys: ['pullup','chinup','lat_pulldown'] },
  { label: 'Back Thickness',        keys: ['deadlift','barbell_row','db_row','cable_row','machine_row','inverted_row'] },
  { label: 'Biceps',                keys: ['barbell_curl','db_curl','hammer_curl','cable_curl','preacher_curl'] },
  { label: 'Triceps',               keys: ['tricep_pushdown','overhead_tricep','skull_crusher','close_grip_bench','bench_dip'] },
  { label: 'Quads',                 keys: ['squat','front_squat','leg_press','leg_ext','db_lunge','bodyweight_squat','jump_squat'] },
  { label: 'Hamstrings & Glutes',   keys: ['rdl','sumo_deadlift','db_rdl','leg_curl','hip_thrust','glute_bridge'] },
  { label: 'Calves',                keys: ['calf_raise','seated_calf'] },
  { label: 'Core',                  keys: ['plank','ab_wheel','cable_crunch','hanging_leg_raise'] },
];

// Pre-built lookups
const EX_BY_KEY  = Object.fromEntries(EXERCISES.map(e => [e.key, e]));
const KEY_TO_CAT = {};
EXERCISE_CATEGORIES.forEach(c => c.keys.forEach(k => { KEY_TO_CAT[k] = c.label; }));

/** Returns the English category label for an exercise (key or name fallback). */
export function findCategoryLabel(key, name) {
  if (key && KEY_TO_CAT[key]) return KEY_TO_CAT[key];
  const hit = EXERCISES.find(e => e.name?.toLowerCase() === name?.toLowerCase());
  return hit ? KEY_TO_CAT[hit.key] : null;
}

// Equipment abbreviation badge
const EQUIP = { barbell: 'BB', dumbbell: 'DB', cable: 'Cable', machine: 'Machine', bodyweight: 'BW' };

// ── ExRow ─────────────────────────────────────────────────────────────────────
function ExRow({ ex, selected, onPick, indent }) {
  return (
    <motion.button
      whileTap={{ scale: 0.98 }}
      onClick={onPick}
      style={{
        width: '100%',
        background: selected ? 'rgba(184,255,0,0.08)' : 'none',
        border: 'none',
        borderTop: `1px solid ${C.border}`,
        padding: `12px 16px 12px ${indent ? 30 : 16}px`,
        display: 'flex', alignItems: 'center', gap: 10,
        cursor: 'pointer', touchAction: 'manipulation',
        WebkitTapHighlightColor: 'transparent',
        textAlign: 'left', minHeight: 48,
      }}
    >
      <span style={{ flex: 1, fontSize: 14, fontWeight: selected ? 700 : 500, color: selected ? C.accent : C.text, lineHeight: 1.3 }}>
        {ex.name}
      </span>
      <span style={{ fontSize: 10, fontWeight: 600, color: C.mute, background: C.surface2, borderRadius: 4, padding: '2px 6px', flexShrink: 0 }}>
        {EQUIP[ex.equipment] || ex.equipment}
      </span>
      {selected
        ? <Check size={14} color={C.accent} strokeWidth={3} />
        : <div style={{ width: 14 }} />
      }
    </motion.button>
  );
}

// ── ExercisePickerSheet ───────────────────────────────────────────────────────
export default function ExercisePickerSheet({
  open,
  onClose,
  currentKey,   // key of the exercise currently in the slot
  currentName,  // name fallback for unrecognised keys
  onSelect,     // (exerciseObject) => void
  lang = 'en',
  t    = k => k,
}) {
  const [search,   setSearch]   = useState('');
  const [expanded, setExpanded] = useState(new Set());

  // On open: reset search + auto-expand current exercise's category
  useEffect(() => {
    if (!open) return;
    setSearch('');
    const cat = findCategoryLabel(currentKey, currentName);
    setExpanded(cat ? new Set([cat]) : new Set());
  }, [open, currentKey, currentName]);

  const q           = search.toLowerCase().trim();
  const isSearching = q.length > 0;
  const flatResults = isSearching ? EXERCISES.filter(e => e.name.toLowerCase().includes(q)) : [];

  const toggleCat = label => setExpanded(prev => {
    const next = new Set(prev);
    next.has(label) ? next.delete(label) : next.add(label);
    return next;
  });

  const pick = ex => { onSelect(ex); onClose(); };

  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Backdrop */}
          <motion.div
            key="picker-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            style={{
              position: 'fixed', inset: 0,
              background: 'rgba(0,0,0,0.78)',
              zIndex: 1000,
              backdropFilter: 'blur(3px)',
            }}
          />

          {/* Sheet */}
          <motion.div
            key="picker-sheet"
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={spring}
            drag="y"
            dragConstraints={{ top: 0, bottom: 0 }}
            dragElastic={{ top: 0, bottom: 0.45 }}
            onDragEnd={(_, info) => { if (info.offset.y > 80) onClose(); }}
            style={{
              position: 'fixed',
              bottom: 0, left: 0, right: 0,
              height: '76vh', maxHeight: '85vh',
              background: C.surface,
              borderRadius: '20px 20px 0 0',
              zIndex: 1001,
              display: 'flex', flexDirection: 'column',
              overflow: 'hidden', willChange: 'transform',
            }}
          >
            {/* Drag handle */}
            <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 10, paddingBottom: 6, flexShrink: 0 }}>
              <div style={{ width: 40, height: 4, borderRadius: 2, background: C.border }} />
            </div>

            {/* Header + search */}
            <div style={{ padding: '2px 16px 12px', flexShrink: 0, borderBottom: `1px solid ${C.border}` }}>
              <p style={{
                fontSize: 11, fontWeight: 800,
                letterSpacing: lang === 'ar' ? '0' : '0.1em',
                color: C.dim, textAlign: 'center', marginBottom: 10,
              }}>
                {t('SWAP EXERCISE')}
              </p>

              {/* Search bar */}
              <div style={{
                display: 'flex', alignItems: 'center', gap: 8,
                background: C.surface2, border: `1.5px solid ${C.border}`,
                borderRadius: 10, padding: '9px 12px',
              }}>
                <Search size={15} color={C.dim} strokeWidth={2} />
                <input
                  value={search}
                  onChange={e => setSearch(e.target.value)}
                  placeholder={t('Search exercises…')}
                  autoComplete="off" autoCorrect="off" spellCheck="false"
                  style={{
                    flex: 1, background: 'none', border: 'none', outline: 'none',
                    color: C.text,
                    fontSize: 16, // prevents iOS zoom on focus
                    fontFamily: 'inherit',
                    WebkitTapHighlightColor: 'transparent',
                  }}
                />
                {search.length > 0 && (
                  <button
                    onClick={() => setSearch('')}
                    style={{ background: 'none', border: 'none', padding: 2, cursor: 'pointer', display: 'flex', alignItems: 'center', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent' }}
                  >
                    <X size={14} color={C.mute} />
                  </button>
                )}
              </div>
            </div>

            {/* Scrollable list */}
            <div style={{ flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch', paddingBottom: 'max(env(safe-area-inset-bottom, 0px), 12px)' }}>

              {isSearching ? (
                // ── Flat search results ──────────────────────────────────────
                flatResults.length === 0 ? (
                  <p style={{ textAlign: 'center', color: C.mute, fontSize: 13, padding: '32px 20px' }}>
                    {t('No exercises match')} "{search}"
                  </p>
                ) : (
                  flatResults.map(ex => (
                    <ExRow key={ex.key} ex={ex} selected={ex.key === currentKey} onPick={() => pick(ex)} indent={false} />
                  ))
                )
              ) : (
                // ── Category accordion ───────────────────────────────────────
                EXERCISE_CATEGORIES.map(cat => {
                  const catExs    = cat.keys.map(k => EX_BY_KEY[k]).filter(Boolean);
                  const isOpen    = expanded.has(cat.label);
                  const hasCurrent = cat.keys.includes(currentKey);

                  return (
                    <div key={cat.label} style={{ borderBottom: `1px solid ${C.border}` }}>
                      {/* Category header */}
                      <button
                        onClick={() => toggleCat(cat.label)}
                        style={{
                          width: '100%', background: 'none', border: 'none',
                          padding: '14px 16px',
                          display: 'flex', alignItems: 'center', gap: 8,
                          cursor: 'pointer', touchAction: 'manipulation',
                          WebkitTapHighlightColor: 'transparent',
                          textAlign: 'left', minHeight: 48,
                        }}
                      >
                        {hasCurrent && (
                          <div style={{ width: 6, height: 6, borderRadius: '50%', background: C.accent, flexShrink: 0 }} />
                        )}
                        <span style={{ flex: 1, fontSize: 14, fontWeight: 700, color: hasCurrent ? C.accent : C.text }}>
                          {t(cat.label)}
                        </span>
                        <span style={{ fontSize: 11, color: C.mute, marginRight: 6 }}>{catExs.length}</span>
                        {isOpen
                          ? <ChevronUp size={14} color={C.mute} />
                          : <ChevronDown size={14} color={C.mute} />
                        }
                      </button>

                      {/* Exercises (animated collapse) */}
                      <AnimatePresence>
                        {isOpen && (
                          <motion.div
                            initial={{ height: 0, opacity: 0 }}
                            animate={{ height: 'auto', opacity: 1 }}
                            exit={{ height: 0, opacity: 0 }}
                            transition={spring}
                            style={{ overflow: 'hidden' }}
                          >
                            {catExs.map(ex => (
                              <ExRow key={ex.key} ex={ex} selected={ex.key === currentKey} onPick={() => pick(ex)} indent />
                            ))}
                          </motion.div>
                        )}
                      </AnimatePresence>
                    </div>
                  );
                })
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
