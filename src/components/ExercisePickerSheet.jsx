import { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, ChevronDown, ChevronUp, Check, X, ArrowLeft, Plus } from 'lucide-react';
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

/** Maps each EXERCISE_CATEGORIES label to the muscle value used by resolveMuscle. */
export const CATEGORY_TO_MUSCLE = {
  'Chest':               'chest',
  'Front Shoulders':     'shoulders',
  'Side Shoulders':      'shoulders',
  'Rear Shoulders':      'shoulders',
  'Back Width':          'back',
  'Back Thickness':      'back',
  'Biceps':              'biceps',
  'Triceps':             'triceps',
  'Quads':               'quads',
  'Hamstrings & Glutes': 'hamstrings',
  'Calves':              'calves',
  'Core':                'core',
};

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

/** Convert a display name to a stable custom exercise key. */
function toCustomKey(name) {
  return 'custom_' + name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}

// Equipment abbreviation badge
const EQUIP = { barbell: 'BB', dumbbell: 'DB', cable: 'Cable', machine: 'Machine', bodyweight: 'BW' };

// ── ExRow ─────────────────────────────────────────────────────────────────────
function ExRow({ ex, selected, onPick, indent }) {
  const isCustom = !!ex.isCustom;
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
      <span style={{
        flex: 1, fontSize: 14,
        fontWeight: selected ? 700 : 500,
        color: selected ? C.accent : C.text,
        lineHeight: 1.3,
      }}>
        {ex.name}
      </span>

      {/* Badge: ✦ for custom, equipment abbreviation for built-in */}
      {isCustom ? (
        <span style={{
          fontSize: 10, fontWeight: 700, color: C.accent,
          background: 'rgba(184,255,0,0.12)',
          border: '1px solid rgba(184,255,0,0.3)',
          borderRadius: 4, padding: '2px 6px',
          flexShrink: 0, letterSpacing: '0.02em',
        }}>
          ✦
        </span>
      ) : (
        <span style={{
          fontSize: 10, fontWeight: 600, color: C.mute,
          background: C.surface2, borderRadius: 4,
          padding: '2px 6px', flexShrink: 0,
        }}>
          {EQUIP[ex.equipment] || ex.equipment}
        </span>
      )}

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
  currentKey,      // key of the exercise currently in the slot
  currentName,     // name fallback for unrecognised keys
  onSelect,        // (exerciseObject) => void
  lang = 'en',
  t    = k => k,
  customExercises = [],   // array of user-created exercises
  onAddCustom     = null, // async (exercise) => void  — null = feature disabled
}) {
  const [search,   setSearch]   = useState('');
  const [expanded, setExpanded] = useState(new Set());

  // Create sub-view state
  const [view,       setView]       = useState('list'); // 'list' | 'create'
  const [createName, setCreateName] = useState('');
  const [createCat,  setCreateCat]  = useState(null);  // { label, muscle } | null
  const [creating,   setCreating]   = useState(false);
  const createNameRef = useRef(null);

  const ar = lang === 'ar';

  // On open: reset everything + auto-expand current exercise's category
  useEffect(() => {
    if (!open) return;
    setSearch('');
    setView('list');
    setCreateName('');
    setCreateCat(null);
    setCreating(false);
    const cat = findCategoryLabel(currentKey, currentName);
    setExpanded(cat ? new Set([cat]) : new Set());
  }, [open, currentKey, currentName]);

  // Focus name input when entering create view
  useEffect(() => {
    if (view === 'create') {
      setTimeout(() => createNameRef.current?.focus(), 120);
    }
  }, [view]);

  const q           = search.toLowerCase().trim();
  const isSearching = q.length > 0;

  // Set of custom exercise names (lowercase) for duplicate detection
  const customNameSet = new Set(customExercises.map(e => e.name.toLowerCase()));

  // Flat search results: custom matches first, then built-in
  const customResults   = isSearching
    ? customExercises.filter(e => e.name.toLowerCase().includes(q))
    : [];
  const builtInResults  = isSearching
    ? EXERCISES.filter(e => e.name.toLowerCase().includes(q))
    : [];
  const flatResults     = [
    ...customResults.map(e => ({ ...e, isCustom: true })),
    ...builtInResults,
  ];

  // Show "Create custom" row when searching, no exact match exists yet
  const showCreateRow = isSearching && q.length >= 2 && !!onAddCustom;
  const alreadyExists = isSearching && (
    EXERCISES.some(e => e.name.toLowerCase() === q) || customNameSet.has(q)
  );

  const toggleCat = label => setExpanded(prev => {
    const next = new Set(prev);
    next.has(label) ? next.delete(label) : next.add(label);
    return next;
  });

  const pick = ex => { onSelect(ex); onClose(); };

  // Open the create view, pre-filling name from the current search query
  const openCreate = () => {
    setCreateName(search.trim());
    setCreateCat(null);
    setView('create');
  };

  // Commit the new custom exercise
  const handleCreate = async () => {
    if (!createName.trim() || !createCat || creating) return;
    setCreating(true);
    const exercise = {
      name:      createName.trim(),
      key:       toCustomKey(createName.trim()),
      muscle:    createCat.muscle,
      category:  createCat.label,
      isCustom:  true,
      equipment: 'custom',
      createdAt: new Date().toISOString(),
    };
    try {
      if (onAddCustom) await onAddCustom(exercise);
      pick(exercise);
    } finally {
      setCreating(false);
    }
  };

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
            <div style={{
              display: 'flex', justifyContent: 'center',
              paddingTop: 10, paddingBottom: 6, flexShrink: 0,
            }}>
              <div style={{ width: 40, height: 4, borderRadius: 2, background: C.border }} />
            </div>

            {/* ── Animated view switcher ── */}
            <AnimatePresence mode="wait">

              {/* ════════════ LIST VIEW ════════════ */}
              {view === 'list' && (
                <motion.div
                  key="list"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.14 }}
                  style={{ display: 'flex', flexDirection: 'column', flex: 1, overflow: 'hidden' }}
                >
                  {/* Header + search */}
                  <div style={{
                    padding: '2px 16px 12px', flexShrink: 0,
                    borderBottom: `1px solid ${C.border}`,
                  }}>
                    <p style={{
                      fontSize: 11, fontWeight: 800,
                      letterSpacing: ar ? '0' : '0.1em',
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
                          color: C.text, fontSize: 16, fontFamily: 'inherit',
                          WebkitTapHighlightColor: 'transparent',
                          direction: ar ? 'rtl' : 'ltr',
                        }}
                      />
                      {search.length > 0 && (
                        <button
                          onClick={() => setSearch('')}
                          style={{
                            background: 'none', border: 'none', padding: 2,
                            cursor: 'pointer', display: 'flex', alignItems: 'center',
                            touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                          }}
                        >
                          <X size={14} color={C.mute} />
                        </button>
                      )}
                    </div>
                  </div>

                  {/* Scrollable list */}
                  <div style={{
                    flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch',
                    paddingBottom: 'calc(env(safe-area-inset-bottom, 0px) + 88px)',
                  }}>

                    {isSearching ? (
                      // ── Flat search results ──────────────────────────────
                      <>
                        {flatResults.length === 0 && !showCreateRow && (
                          <p style={{ textAlign: 'center', color: C.mute, fontSize: 13, padding: '32px 20px' }}>
                            {t('No exercises match')} "{search}"
                          </p>
                        )}
                        {flatResults.length === 0 && showCreateRow && (
                          <p style={{ textAlign: 'center', color: C.mute, fontSize: 13, padding: '24px 20px 8px' }}>
                            {t('No exercises match')} "{search}"
                          </p>
                        )}
                        {flatResults.map(ex => (
                          <ExRow
                            key={ex.key}
                            ex={ex}
                            selected={ex.key === currentKey}
                            onPick={() => pick(ex)}
                            indent={false}
                          />
                        ))}

                        {/* ── Create custom exercise row ── */}
                        {showCreateRow && !alreadyExists && (
                          <motion.button
                            whileTap={{ scale: 0.98 }}
                            onClick={openCreate}
                            style={{
                              width: '100%', background: 'none', border: 'none',
                              borderTop: `1px solid ${C.border}`,
                              padding: '14px 16px',
                              display: 'flex', alignItems: 'center', gap: 10,
                              cursor: 'pointer', touchAction: 'manipulation',
                              WebkitTapHighlightColor: 'transparent',
                              textAlign: ar ? 'right' : 'left',
                            }}
                          >
                            <div style={{
                              width: 28, height: 28, borderRadius: 8,
                              background: 'rgba(184,255,0,0.1)',
                              border: '1px solid rgba(184,255,0,0.3)',
                              display: 'flex', alignItems: 'center', justifyContent: 'center',
                              flexShrink: 0,
                            }}>
                              <Plus size={14} color={C.accent} strokeWidth={2.5} />
                            </div>
                            <div style={{ flex: 1 }}>
                              <div style={{ fontSize: 14, fontWeight: 600, color: C.accent }}>
                                {ar
                                  ? `إضافة "${search.trim()}" تمريناً مخصصاً`
                                  : `Create "${search.trim()}" as custom`}
                              </div>
                              <div style={{ fontSize: 11, color: C.mute, marginTop: 2 }}>
                                {ar
                                  ? 'اختر فئة العضلة لتتبع التقدم'
                                  : 'Pick a muscle category to track progress'}
                              </div>
                            </div>
                            <span style={{
                              fontSize: 10, fontWeight: 700, color: C.accent,
                              background: 'rgba(184,255,0,0.12)',
                              border: '1px solid rgba(184,255,0,0.3)',
                              borderRadius: 4, padding: '2px 6px', flexShrink: 0,
                            }}>
                              ✦
                            </span>
                          </motion.button>
                        )}
                      </>
                    ) : (
                      // ── Category accordion ───────────────────────────────
                      <>
                        {/* My Exercises — only if user has any */}
                        {customExercises.length > 0 && (
                          <div style={{ borderBottom: `1px solid ${C.border}` }}>
                            <button
                              onClick={() => toggleCat('__custom__')}
                              style={{
                                width: '100%', background: 'none', border: 'none',
                                padding: '14px 16px',
                                display: 'flex', alignItems: 'center', gap: 8,
                                cursor: 'pointer', touchAction: 'manipulation',
                                WebkitTapHighlightColor: 'transparent',
                                textAlign: 'left', minHeight: 48,
                              }}
                            >
                              <span style={{
                                fontSize: 10, fontWeight: 700, color: C.accent,
                                background: 'rgba(184,255,0,0.12)',
                                border: '1px solid rgba(184,255,0,0.3)',
                                borderRadius: 4, padding: '2px 6px', flexShrink: 0,
                              }}>
                                ✦
                              </span>
                              <span style={{ flex: 1, fontSize: 14, fontWeight: 700, color: C.accent }}>
                                {ar ? 'تمارين مخصصة' : 'My Exercises'}
                              </span>
                              <span style={{ fontSize: 11, color: C.mute, marginRight: 6 }}>
                                {customExercises.length}
                              </span>
                              {expanded.has('__custom__')
                                ? <ChevronUp   size={14} color={C.mute} />
                                : <ChevronDown size={14} color={C.mute} />
                              }
                            </button>
                            <AnimatePresence>
                              {expanded.has('__custom__') && (
                                <motion.div
                                  initial={{ height: 0, opacity: 0 }}
                                  animate={{ height: 'auto', opacity: 1 }}
                                  exit={{ height: 0, opacity: 0 }}
                                  transition={spring}
                                  style={{ overflow: 'hidden' }}
                                >
                                  {customExercises.map(ex => (
                                    <ExRow
                                      key={ex.key}
                                      ex={{ ...ex, isCustom: true }}
                                      selected={ex.key === currentKey}
                                      onPick={() => pick({ ...ex, isCustom: true })}
                                      indent
                                    />
                                  ))}
                                </motion.div>
                              )}
                            </AnimatePresence>
                          </div>
                        )}

                        {/* Built-in categories */}
                        {EXERCISE_CATEGORIES.map(cat => {
                          const catExs     = cat.keys.map(k => EX_BY_KEY[k]).filter(Boolean);
                          const isOpen     = expanded.has(cat.label);
                          const hasCurrent = cat.keys.includes(currentKey);

                          return (
                            <div key={cat.label} style={{ borderBottom: `1px solid ${C.border}` }}>
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
                                  <div style={{
                                    width: 6, height: 6, borderRadius: '50%',
                                    background: C.accent, flexShrink: 0,
                                  }} />
                                )}
                                <span style={{
                                  flex: 1, fontSize: 14, fontWeight: 700,
                                  color: hasCurrent ? C.accent : C.text,
                                }}>
                                  {t(cat.label)}
                                </span>
                                <span style={{ fontSize: 11, color: C.mute, marginRight: 6 }}>
                                  {catExs.length}
                                </span>
                                {isOpen
                                  ? <ChevronUp   size={14} color={C.mute} />
                                  : <ChevronDown size={14} color={C.mute} />
                                }
                              </button>
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
                                      <ExRow
                                        key={ex.key}
                                        ex={ex}
                                        selected={ex.key === currentKey}
                                        onPick={() => pick(ex)}
                                        indent
                                      />
                                    ))}
                                  </motion.div>
                                )}
                              </AnimatePresence>
                            </div>
                          );
                        })}

                        {/* ── Add custom exercise footer button ── */}
                        {onAddCustom && (
                          <motion.button
                            whileTap={{ scale: 0.98 }}
                            onClick={openCreate}
                            style={{
                              width: '100%', background: 'none', border: 'none',
                              padding: '16px 16px',
                              display: 'flex', alignItems: 'center', gap: 10,
                              cursor: 'pointer', touchAction: 'manipulation',
                              WebkitTapHighlightColor: 'transparent',
                              textAlign: ar ? 'right' : 'left',
                            }}
                          >
                            <div style={{
                              width: 28, height: 28, borderRadius: 8,
                              background: 'rgba(184,255,0,0.1)',
                              border: '1px solid rgba(184,255,0,0.3)',
                              display: 'flex', alignItems: 'center', justifyContent: 'center',
                              flexShrink: 0,
                            }}>
                              <Plus size={14} color={C.accent} strokeWidth={2.5} />
                            </div>
                            <span style={{ fontSize: 14, fontWeight: 600, color: C.accent }}>
                              {ar ? 'إضافة تمرين مخصص' : 'Add custom exercise'}
                            </span>
                          </motion.button>
                        )}
                      </>
                    )}
                  </div>
                </motion.div>
              )}

              {/* ════════════ CREATE VIEW ════════════ */}
              {view === 'create' && (
                <motion.div
                  key="create"
                  initial={{ opacity: 0, x: ar ? -20 : 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: ar ? -20 : 20 }}
                  transition={{ duration: 0.18 }}
                  style={{ display: 'flex', flexDirection: 'column', flex: 1, overflow: 'hidden' }}
                >
                  {/* Create header */}
                  <div style={{
                    padding: '4px 16px 14px', flexShrink: 0,
                    borderBottom: `1px solid ${C.border}`,
                  }}>
                    <div style={{
                      display: 'flex', alignItems: 'center', gap: 10,
                      marginBottom: 14, direction: ar ? 'rtl' : 'ltr',
                    }}>
                      <button
                        onClick={() => setView('list')}
                        style={{
                          background: 'none', border: 'none', cursor: 'pointer',
                          padding: 4, display: 'flex', alignItems: 'center',
                          WebkitTapHighlightColor: 'transparent',
                        }}
                      >
                        <ArrowLeft size={18} color={C.dim} style={{ transform: ar ? 'scaleX(-1)' : 'none' }} />
                      </button>
                      <p style={{
                        fontSize: 11, fontWeight: 800,
                        letterSpacing: ar ? '0' : '0.1em',
                        color: C.dim, margin: 0,
                      }}>
                        {ar ? 'تمرين مخصص جديد' : 'NEW CUSTOM EXERCISE'}
                      </p>
                    </div>

                    {/* Name input */}
                    <input
                      ref={createNameRef}
                      value={createName}
                      onChange={e => setCreateName(e.target.value)}
                      onKeyDown={e => { if (e.key === 'Enter') e.target.blur(); }}
                      placeholder={ar ? 'اسم التمرين…' : 'Exercise name…'}
                      autoComplete="off" autoCorrect="off" spellCheck="false"
                      style={{
                        width: '100%', boxSizing: 'border-box',
                        background: C.surface2, border: `1.5px solid ${C.border}`,
                        borderRadius: 10, padding: '11px 13px',
                        color: C.text, fontSize: 16, fontFamily: 'inherit',
                        outline: 'none', WebkitTapHighlightColor: 'transparent',
                        direction: ar ? 'rtl' : 'ltr',
                      }}
                      onFocus={e => { e.target.style.borderColor = C.accent; }}
                      onBlur={e => { e.target.style.borderColor = C.border; }}
                    />
                  </div>

                  {/* Category picker */}
                  <div style={{
                    flex: 1, overflowY: 'auto',
                    WebkitOverflowScrolling: 'touch',
                    padding: '14px 16px',
                  }}>
                    <p style={{
                      fontSize: 11, fontWeight: 700,
                      letterSpacing: ar ? '0' : '0.08em',
                      color: C.dim, marginBottom: 10,
                    }}>
                      {ar ? '* اختر فئة العضلة' : 'MUSCLE CATEGORY *'}
                    </p>

                    <div style={{
                      display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)',
                      gap: 8, marginBottom: 16,
                    }}>
                      {EXERCISE_CATEGORIES.map(cat => {
                        const isSelected = createCat?.label === cat.label;
                        return (
                          <motion.button
                            key={cat.label}
                            whileTap={{ scale: 0.94 }}
                            onClick={() => setCreateCat({ label: cat.label, muscle: CATEGORY_TO_MUSCLE[cat.label] })}
                            style={{
                              background: isSelected ? 'rgba(184,255,0,0.12)' : C.surface2,
                              border: `1.5px solid ${isSelected ? C.accent : C.border}`,
                              borderRadius: 10, padding: '10px 6px',
                              cursor: 'pointer', touchAction: 'manipulation',
                              WebkitTapHighlightColor: 'transparent',
                              textAlign: 'center', transition: 'background 0.1s, border-color 0.1s',
                            }}
                          >
                            <div style={{
                              fontSize: 11, fontWeight: 700, lineHeight: 1.3,
                              color: isSelected ? C.accent : C.text,
                              fontFamily: ar ? "'ThmanyahSans', sans-serif" : undefined,
                            }}>
                              {t(cat.label)}
                            </div>
                            {isSelected && (
                              <div style={{ fontSize: 10, color: C.accent, marginTop: 3 }}>✓</div>
                            )}
                          </motion.button>
                        );
                      })}
                    </div>
                  </div>

                  {/* Create CTA */}
                  <div style={{
                    padding: '12px 16px',
                    paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 12px, 16px)',
                    borderTop: `1px solid ${C.border}`,
                    flexShrink: 0,
                  }}>
                    <motion.button
                      whileTap={{ scale: 0.97 }}
                      onClick={handleCreate}
                      disabled={!createName.trim() || !createCat || creating}
                      style={{
                        width: '100%',
                        background: (createName.trim() && createCat && !creating)
                          ? C.accent : C.surface2,
                        border: 'none', borderRadius: 12,
                        padding: '15px 0',
                        fontSize: 15, fontWeight: 800,
                        color: (createName.trim() && createCat && !creating) ? '#000' : C.mute,
                        cursor: (createName.trim() && createCat && !creating) ? 'pointer' : 'default',
                        transition: 'background 0.15s, color 0.15s',
                        touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                        fontFamily: ar ? "'ThmanyahSans', sans-serif" : undefined,
                      }}
                    >
                      {creating
                        ? (ar ? 'جارٍ الإنشاء…' : 'Creating…')
                        : (ar ? '← إنشاء واختيار' : 'Create & Select →')
                      }
                    </motion.button>
                  </div>
                </motion.div>
              )}

            </AnimatePresence>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
