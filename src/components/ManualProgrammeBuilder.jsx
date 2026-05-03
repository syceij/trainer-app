/**
 * ManualProgrammeBuilder.jsx
 * 6-step wizard for building a weekly programme by hand.
 * Output is passed to enterAppWithImport (importedProgramme format).
 */

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronLeft, Plus, Trash2, Edit3, Check } from 'lucide-react';
import ExercisePickerSheet from './ExercisePickerSheet.jsx';
import { C, spring, springSoft } from '../tokens.js';

// ── Constants ─────────────────────────────────────────────────────────────────

const DAYS = [
  { key: 'mon', label: 'Mon', full: 'Monday' },
  { key: 'tue', label: 'Tue', full: 'Tuesday' },
  { key: 'wed', label: 'Wed', full: 'Wednesday' },
  { key: 'thu', label: 'Thu', full: 'Thursday' },
  { key: 'fri', label: 'Fri', full: 'Friday' },
  { key: 'sat', label: 'Sat', full: 'Saturday' },
  { key: 'sun', label: 'Sun', full: 'Sunday' },
];

const GOALS = [
  { key: 'muscle',   label: 'Build muscle',        icon: '💪' },
  { key: 'strength', label: 'Get stronger',         icon: '🏋️' },
  { key: 'fat',      label: 'Lose fat',             icon: '🔥' },
  { key: 'athletic', label: 'Athletic performance', icon: '⚡' },
];

const SPLITS = [
  {
    key: 'ppl', label: 'Push / Pull / Legs',
    description: 'Classic 6-day split for muscle building',
    names: { mon: 'Push', tue: 'Pull', wed: 'Legs', thu: 'Push', fri: 'Pull', sat: 'Legs', sun: 'Push' },
  },
  {
    key: 'upper_lower', label: 'Upper / Lower',
    description: '4-day split, great for strength',
    names: { mon: 'Upper', tue: 'Lower', wed: 'Upper', thu: 'Lower', fri: 'Upper', sat: 'Lower', sun: 'Upper' },
  },
  {
    key: 'full_body', label: 'Full Body',
    description: 'Each session hits every muscle group',
    names: { mon: 'Full Body', tue: 'Full Body', wed: 'Full Body', thu: 'Full Body', fri: 'Full Body', sat: 'Full Body', sun: 'Full Body' },
  },
  {
    key: 'body_part', label: 'Body Part Split',
    description: 'Dedicated day per muscle group',
    names: { mon: 'Chest', tue: 'Back', wed: 'Legs', thu: 'Shoulders', fri: 'Arms', sat: 'Core', sun: 'Chest' },
  },
  {
    key: 'custom', label: 'Custom',
    description: 'Name each session yourself',
    names: {},
  },
];

const DURATIONS = [
  { value: 4,  label: '4 weeks' },
  { value: 8,  label: '8 weeks' },
  { value: 12, label: '12 weeks' },
  { value: 0,  label: 'Ongoing', description: 'Repeating weekly schedule, no fixed end' },
];

// ── Output builder ────────────────────────────────────────────────────────────

function buildOutput({ progName, goal, selectedDays, sessionNames, sessionExercises, duration, useBlocks, blockLabels }) {
  const weekCount = duration === 0 ? 1 : duration;
  const blocksCount = (useBlocks && duration !== 0) ? blockLabels.length : 0;
  const weeksPerBlock = blocksCount > 0 ? Math.ceil(weekCount / blocksCount) : weekCount;

  const weeks = Array.from({ length: weekCount }, (_, wi) => {
    const weekNumber = wi + 1;
    const blockIdx = Math.floor(wi / weeksPerBlock);
    const block = blocksCount > 0 ? (blockLabels[Math.min(blockIdx, blocksCount - 1)] || null) : null;

    // All 7 days: selected days get sessions, unselected days get isRest
    const sessions = DAYS.map(d => {
      if (!selectedDays.includes(d.key)) {
        return { day: d.key, isRest: true };
      }
      return {
        day:       d.key,
        name:      sessionNames[d.key] || d.label,
        exercises: (sessionExercises[d.key] || []).map(ex => ({
          name:       ex.name,
          key:        ex.key   || null,
          sets:       ex.sets  || 3,
          reps:       ex.reps  != null ? String(ex.reps) : '8-10',
          weight:     ex.weight != null ? ex.weight : null,
          rpe:        ex.rpe   != null ? String(ex.rpe)  : null,
          tag:        ex.tag   || null,
          bodyweight: ex.bodyweight || false,
        })),
      };
    });

    return { weekNumber, ...(block ? { block } : {}), sessions };
  });

  return { name: progName, goal, weeks };
}

// ── Shared primitives ─────────────────────────────────────────────────────────

const inputStyle = {
  width: '100%', boxSizing: 'border-box',
  background: C.surface2, border: `1.5px solid ${C.border}`,
  borderRadius: 10, padding: '11px 14px',
  color: C.text, fontSize: 15, outline: 'none',
  fontFamily: 'Inter, system-ui, sans-serif',
};

function ChoiceButton({ active, onClick, children, description }) {
  return (
    <motion.button
      whileTap={{ scale: 0.98 }}
      onClick={onClick}
      style={{
        width: '100%', background: active ? 'rgba(184,255,0,0.09)' : C.surface2,
        border: `1.5px solid ${active ? C.accent : C.border}`,
        borderRadius: 12, padding: '13px 16px',
        display: 'flex', alignItems: 'center', gap: 12,
        cursor: 'pointer', touchAction: 'manipulation',
        WebkitTapHighlightColor: 'transparent', textAlign: 'left',
      }}
    >
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 15, fontWeight: 600, color: active ? C.accent : C.text }}>
          {children}
        </div>
        {description && (
          <div style={{ fontSize: 12, color: C.dim, marginTop: 2 }}>{description}</div>
        )}
      </div>
      {active && <Check size={16} color={C.accent} strokeWidth={3} style={{ flexShrink: 0 }} />}
    </motion.button>
  );
}

function SectionLabel({ children }) {
  return (
    <div style={{
      fontSize: 11, fontWeight: 700, color: C.dim,
      letterSpacing: '0.06em', marginBottom: 10,
    }}>
      {children}
    </div>
  );
}

// ── Exercise inline form ───────────────────────────────────────────────────────

function ExerciseFormRow({ exerciseName, initialSets = 3, initialReps = '8-10', initialWeight = '', initialRpe = '', onSave, onCancel, saveLabel = 'Add to session' }) {
  const [sets,   setSets]   = useState(String(initialSets || 3));
  const [reps,   setReps]   = useState(String(initialReps || '8-10'));
  const [weight, setWeight] = useState(initialWeight != null ? String(initialWeight) : '');
  const [rpe,    setRpe]    = useState(initialRpe   != null ? String(initialRpe)    : '');

  const miniInput = {
    width: '100%', boxSizing: 'border-box',
    background: C.surface2, border: `1.5px solid ${C.border}`,
    borderRadius: 8, padding: '9px 10px',
    color: C.text, fontSize: 14, outline: 'none',
    fontFamily: 'Inter, system-ui, sans-serif', textAlign: 'center',
  };

  return (
    <div style={{
      background: 'rgba(184,255,0,0.04)', border: `1.5px solid rgba(184,255,0,0.3)`,
      borderRadius: 12, padding: '12px 14px', marginTop: 6,
    }}>
      <div style={{ fontSize: 13, fontWeight: 700, color: C.accent, marginBottom: 10 }}>
        {exerciseName}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 8, marginBottom: 12 }}>
        {[
          { label: 'SETS',   value: sets,   onChange: setSets,   placeholder: '3'    },
          { label: 'REPS',   value: reps,   onChange: setReps,   placeholder: '8-10' },
          { label: 'KG',     value: weight, onChange: setWeight, placeholder: '—'    },
          { label: 'RPE',    value: rpe,    onChange: setRpe,    placeholder: '—'    },
        ].map(f => (
          <div key={f.label}>
            <div style={{ fontSize: 9, fontWeight: 700, color: C.dim, marginBottom: 4, letterSpacing: '0.06em', textAlign: 'center' }}>
              {f.label}
            </div>
            <input
              type="text"
              inputMode="decimal"
              value={f.value}
              onChange={e => f.onChange(e.target.value)}
              placeholder={f.placeholder}
              style={miniInput}
              onFocus={e => { e.target.style.borderColor = C.accent; }}
              onBlur={e => { e.target.style.borderColor = C.border; }}
            />
          </div>
        ))}
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <button
          onClick={onCancel}
          style={{
            flex: 1, background: C.surface2, border: `1px solid ${C.border}`,
            borderRadius: 9, padding: '9px 0', fontSize: 13, fontWeight: 700,
            color: C.dim, cursor: 'pointer',
          }}
        >
          Cancel
        </button>
        <button
          onClick={() => {
            const parsedSets   = Math.max(1, parseInt(sets)   || 3);
            const parsedWeight = weight.trim() ? parseFloat(weight) || null : null;
            const parsedRpe    = rpe.trim()    ? rpe.trim()                 : null;
            onSave({ sets: parsedSets, reps: reps.trim() || '8-10', weight: parsedWeight, rpe: parsedRpe });
          }}
          style={{
            flex: 2, background: C.accent, border: 'none',
            borderRadius: 9, padding: '9px 0', fontSize: 13, fontWeight: 800,
            color: '#000', cursor: 'pointer',
          }}
        >
          {saveLabel}
        </button>
      </div>
    </div>
  );
}

// ── Step 1 — Name + Goal ───────────────────────────────────────────────────────

function Step1({ progName, setProgName, goal, setGoal }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      <div>
        <SectionLabel>PROGRAMME NAME</SectionLabel>
        <input
          type="text"
          value={progName}
          onChange={e => setProgName(e.target.value)}
          placeholder="e.g. Summer Strength Block"
          maxLength={60}
          style={inputStyle}
          onFocus={e => { e.target.style.borderColor = C.accent; }}
          onBlur={e => { e.target.style.borderColor = C.border; }}
        />
      </div>

      <div>
        <SectionLabel>PRIMARY GOAL</SectionLabel>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {GOALS.map(g => (
            <motion.button
              key={g.key}
              whileTap={{ scale: 0.98 }}
              onClick={() => setGoal(g.key)}
              style={{
                width: '100%', background: goal === g.key ? 'rgba(184,255,0,0.09)' : C.surface2,
                border: `1.5px solid ${goal === g.key ? C.accent : C.border}`,
                borderRadius: 12, padding: '13px 16px',
                display: 'flex', alignItems: 'center', gap: 12,
                cursor: 'pointer', touchAction: 'manipulation',
                WebkitTapHighlightColor: 'transparent', textAlign: 'left',
              }}
            >
              <span style={{ fontSize: 18 }}>{g.icon}</span>
              <span style={{ flex: 1, fontSize: 15, fontWeight: 600, color: goal === g.key ? C.accent : C.text }}>
                {g.label}
              </span>
              {goal === g.key && <Check size={16} color={C.accent} strokeWidth={3} />}
            </motion.button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ── Step 2 — Training days ─────────────────────────────────────────────────────

function Step2({ selectedDays, setSelectedDays }) {
  const toggle = (key) => {
    setSelectedDays(prev => {
      if (prev.includes(key)) {
        return prev.length === 1 ? prev : prev.filter(d => d !== key);
      }
      // keep original DAYS order
      const all = DAYS.map(d => d.key);
      return all.filter(d => prev.includes(d) || d === key);
    });
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <p style={{ fontSize: 13, color: C.dim, margin: 0 }}>
        {selectedDays.length} training {selectedDays.length === 1 ? 'day' : 'days'} per week selected
      </p>
      {DAYS.map(d => {
        const active = selectedDays.includes(d.key);
        return (
          <motion.button
            key={d.key}
            whileTap={{ scale: 0.98 }}
            onClick={() => toggle(d.key)}
            style={{
              width: '100%', background: active ? 'rgba(184,255,0,0.09)' : C.surface2,
              border: `1.5px solid ${active ? C.accent : C.border}`,
              borderRadius: 12, padding: '14px 16px',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              cursor: 'pointer', touchAction: 'manipulation',
              WebkitTapHighlightColor: 'transparent',
            }}
          >
            <span style={{ fontSize: 15, fontWeight: 600, color: active ? C.accent : C.text }}>
              {d.full}
            </span>
            {active && <Check size={16} color={C.accent} strokeWidth={3} />}
          </motion.button>
        );
      })}
    </div>
  );
}

// ── Step 3 — Split + Session names ────────────────────────────────────────────

function Step3({ split, setSplit, selectedDays, sessionNames, setSessionNames }) {
  const applySplit = (key) => {
    setSplit(key);
    if (key === 'custom') return; // keep existing names, user edits manually
    const preset = SPLITS.find(s => s.key === key);
    if (!preset) return;
    const updated = {};
    selectedDays.forEach((dayKey, i) => {
      // assign names in preset order; if preset doesn't have an entry for this day
      // position, fall back to a cycling pattern
      const presetValues = Object.values(preset.names);
      updated[dayKey] = presetValues[i % presetValues.length] || DAYS.find(d => d.key === dayKey)?.label || dayKey;
    });
    setSessionNames(updated);
  };

  const allNamed = selectedDays.every(d => (sessionNames[d] || '').trim());

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {SPLITS.map(s => (
          <ChoiceButton
            key={s.key}
            active={split === s.key}
            onClick={() => applySplit(s.key)}
            description={s.description}
          >
            {s.label}
          </ChoiceButton>
        ))}
      </div>

      {split && (
        <div>
          <SectionLabel>SESSION NAMES</SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {selectedDays.map(dayKey => {
              const dayInfo = DAYS.find(d => d.key === dayKey);
              return (
                <div key={dayKey} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span style={{
                    fontSize: 12, fontWeight: 700, color: C.dim,
                    width: 34, flexShrink: 0, textAlign: 'right',
                  }}>
                    {dayInfo?.label}
                  </span>
                  <input
                    type="text"
                    value={sessionNames[dayKey] || ''}
                    onChange={e => setSessionNames(prev => ({ ...prev, [dayKey]: e.target.value }))}
                    placeholder={dayInfo?.full || dayKey}
                    maxLength={40}
                    style={{ ...inputStyle, flex: 1 }}
                    onFocus={e => { e.target.style.borderColor = C.accent; }}
                    onBlur={e => { e.target.style.borderColor = C.border; }}
                  />
                </div>
              );
            })}
          </div>
          {!allNamed && (
            <p style={{ fontSize: 12, color: '#ff6b6b', marginTop: 8 }}>
              Give each session a name to continue.
            </p>
          )}
        </div>
      )}
    </div>
  );
}

// ── Step 4 — Exercises ────────────────────────────────────────────────────────

function Step4({ selectedDays, sessionNames, sessionExercises, setSessionExercises, lang, t }) {
  const [pickerDayOpen,    setPickerDayOpen]    = useState(null);
  const [pendingPick,      setPendingPick]      = useState(null); // { day, exercise }
  const [editingExercise,  setEditingExercise]  = useState(null); // { day, idx }

  const openPicker = (dayKey) => {
    setEditingExercise(null);
    setPendingPick(null);
    setPickerDayOpen(dayKey);
  };

  const handlePickExercise = (exercise) => {
    const day = pickerDayOpen;
    setPickerDayOpen(null);
    setPendingPick({ day, exercise });
  };

  const handleSaveAdd = ({ sets, reps, weight, rpe }) => {
    if (!pendingPick) return;
    const { day, exercise } = pendingPick;
    setSessionExercises(prev => ({
      ...prev,
      [day]: [...(prev[day] || []), { ...exercise, sets, reps, weight, rpe }],
    }));
    setPendingPick(null);
  };

  const handleSaveEdit = (day, idx, params) => {
    setSessionExercises(prev => ({
      ...prev,
      [day]: prev[day].map((ex, i) => i === idx ? { ...ex, ...params } : ex),
    }));
    setEditingExercise(null);
  };

  const handleDelete = (day, idx) => {
    setSessionExercises(prev => ({
      ...prev,
      [day]: prev[day].filter((_, i) => i !== idx),
    }));
    if (editingExercise?.day === day && editingExercise?.idx === idx) {
      setEditingExercise(null);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <p style={{ fontSize: 13, color: C.dim, margin: 0 }}>
        Add exercises to each session. You can skip any session and add them later.
      </p>

      {selectedDays.map(dayKey => {
        const dayInfo = DAYS.find(d => d.key === dayKey);
        const sessionName = sessionNames[dayKey] || dayInfo?.label || dayKey;
        const exercises   = sessionExercises[dayKey] || [];
        const isPending   = pendingPick?.day === dayKey;

        return (
          <div
            key={dayKey}
            style={{
              background: C.surface,
              borderRadius: 14,
              border: `1px solid ${C.border}`,
              overflow: 'hidden',
            }}
          >
            {/* Day header */}
            <div style={{
              padding: '11px 16px',
              background: C.surface2,
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            }}>
              <div>
                <div style={{ fontSize: 10, fontWeight: 700, color: C.dim, letterSpacing: '0.07em' }}>
                  {(dayInfo?.label || dayKey).toUpperCase()}
                </div>
                <div style={{ fontSize: 15, fontWeight: 700, color: C.text, marginTop: 1 }}>
                  {sessionName}
                </div>
              </div>
              <div style={{ fontSize: 12, color: C.mute }}>
                {exercises.length} exercise{exercises.length !== 1 ? 's' : ''}
              </div>
            </div>

            {/* Exercise rows */}
            {exercises.map((ex, idx) => {
              const isEditing = editingExercise?.day === dayKey && editingExercise?.idx === idx;
              return (
                <div key={idx} style={{ borderTop: `1px solid ${C.border}` }}>
                  {!isEditing ? (
                    <div style={{ padding: '11px 16px', display: 'flex', alignItems: 'center', gap: 8 }}>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: 14, fontWeight: 600, color: C.text }}>{ex.name}</div>
                        <div style={{ fontSize: 12, color: C.dim, marginTop: 2 }}>
                          {ex.sets} × {ex.reps}
                          {ex.weight  ? ` · ${ex.weight}kg` : ''}
                          {ex.rpe     ? ` · RPE ${ex.rpe}`  : ''}
                        </div>
                      </div>
                      <button
                        onClick={() => setEditingExercise({ day: dayKey, idx })}
                        style={{ background: 'none', border: 'none', padding: 6, color: C.dim, cursor: 'pointer', display: 'flex' }}
                      >
                        <Edit3 size={14} />
                      </button>
                      <button
                        onClick={() => handleDelete(dayKey, idx)}
                        style={{ background: 'none', border: 'none', padding: 6, color: '#ff6b6b', cursor: 'pointer', display: 'flex' }}
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  ) : (
                    <div style={{ padding: '4px 12px 12px' }}>
                      <ExerciseFormRow
                        exerciseName={ex.name}
                        initialSets={ex.sets}
                        initialReps={ex.reps}
                        initialWeight={ex.weight}
                        initialRpe={ex.rpe}
                        saveLabel="Save changes"
                        onSave={(params) => handleSaveEdit(dayKey, idx, params)}
                        onCancel={() => setEditingExercise(null)}
                      />
                    </div>
                  )}
                </div>
              );
            })}

            {/* Pending exercise inline form */}
            {isPending && (
              <div style={{ borderTop: exercises.length > 0 ? `1px solid ${C.border}` : 'none', padding: '4px 12px 12px' }}>
                <ExerciseFormRow
                  exerciseName={pendingPick.exercise.name}
                  onSave={handleSaveAdd}
                  onCancel={() => setPendingPick(null)}
                />
              </div>
            )}

            {/* Add exercise button */}
            {!isPending && (
              <motion.button
                whileTap={{ scale: 0.98 }}
                onClick={() => openPicker(dayKey)}
                style={{
                  width: '100%', background: 'none', border: 'none',
                  borderTop: exercises.length > 0 || isAnyEditing(editingExercise, dayKey) ? `1px solid ${C.border}` : 'none',
                  padding: '13px 16px',
                  display: 'flex', alignItems: 'center', gap: 8,
                  cursor: 'pointer', touchAction: 'manipulation',
                  WebkitTapHighlightColor: 'transparent',
                }}
              >
                <Plus size={15} color={C.accent} strokeWidth={2.5} />
                <span style={{ fontSize: 14, fontWeight: 700, color: C.accent }}>Add exercise</span>
              </motion.button>
            )}
          </div>
        );
      })}

      {/* Exercise picker sheet — single instance controlled by pickerDayOpen */}
      <ExercisePickerSheet
        open={pickerDayOpen !== null}
        onClose={() => setPickerDayOpen(null)}
        currentKey={null}
        currentName={null}
        onSelect={handlePickExercise}
        lang={lang}
        t={t}
      />
    </div>
  );
}

function isAnyEditing(editingExercise, dayKey) {
  return editingExercise?.day === dayKey;
}

// ── Step 5 — Duration + Blocks ────────────────────────────────────────────────

function Step5({ duration, setDuration, useBlocks, setUseBlocks, blockLabels, setBlockLabels }) {
  const handleDurationChange = (value) => {
    setDuration(value);
    if (value === 0) {
      setBlockLabels(['Block 1']);
      setUseBlocks(false);
    } else {
      const count = value / 4;
      setBlockLabels(Array.from({ length: count }, (_, i) => `Block ${i + 1}`));
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      <div>
        <SectionLabel>PROGRAMME DURATION</SectionLabel>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {DURATIONS.map(d => (
            <ChoiceButton
              key={d.value}
              active={duration === d.value}
              onClick={() => handleDurationChange(d.value)}
              description={d.description}
            >
              {d.label}
            </ChoiceButton>
          ))}
        </div>
      </div>

      {/* Block periodisation — only relevant for fixed-duration programmes */}
      {duration !== 0 && (
        <div>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            background: C.surface2, borderRadius: 12, padding: '13px 16px',
            border: `1.5px solid ${C.border}`,
          }}>
            <div>
              <div style={{ fontSize: 15, fontWeight: 600, color: C.text }}>Block periodisation</div>
              <div style={{ fontSize: 12, color: C.dim, marginTop: 2 }}>Name each 4-week training phase</div>
            </div>
            {/* Toggle */}
            <motion.button
              whileTap={{ scale: 0.95 }}
              onClick={() => setUseBlocks(b => !b)}
              style={{
                width: 46, height: 26, flexShrink: 0,
                background: useBlocks ? C.accent : C.surface,
                border: `1.5px solid ${useBlocks ? C.accent : C.border}`,
                borderRadius: 13, cursor: 'pointer',
                display: 'flex', alignItems: 'center', padding: '0 4px',
                transition: 'background 0.2s, border-color 0.2s',
              }}
            >
              <motion.div
                animate={{ x: useBlocks ? 18 : 0 }}
                transition={spring}
                style={{
                  width: 16, height: 16, borderRadius: '50%',
                  background: useBlocks ? '#000' : C.dim,
                }}
              />
            </motion.button>
          </div>

          {/* Block label editors */}
          {useBlocks && blockLabels.length > 0 && (
            <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
              {blockLabels.map((label, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span style={{
                    fontSize: 11, fontWeight: 700, color: C.dim,
                    width: 56, flexShrink: 0, textAlign: 'right',
                  }}>
                    Wk {i * 4 + 1}–{Math.min((i + 1) * 4, duration)}
                  </span>
                  <input
                    type="text"
                    value={label}
                    onChange={e => {
                      const updated = [...blockLabels];
                      updated[i] = e.target.value;
                      setBlockLabels(updated);
                    }}
                    placeholder={`Block ${i + 1}`}
                    maxLength={40}
                    style={{ ...inputStyle, flex: 1 }}
                    onFocus={e => { e.target.style.borderColor = C.accent; }}
                    onBlur={e => { e.target.style.borderColor = C.border; }}
                  />
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ── Step 6 — Review ───────────────────────────────────────────────────────────

function Step6({ progName, goal, selectedDays, sessionNames, sessionExercises, duration, useBlocks, blockLabels, onEditStep }) {
  const goalLabel     = GOALS.find(g => g.key === goal)?.label || goal;
  const durationLabel = DURATIONS.find(d => d.value === duration)?.label || '—';
  const totalEx       = selectedDays.reduce((s, d) => s + (sessionExercises[d]?.length || 0), 0);

  const summaryRows = [
    { label: 'Name',          value: progName,                        step: 0 },
    { label: 'Goal',          value: goalLabel,                       step: 0 },
    { label: 'Training days', value: `${selectedDays.length} per week`, step: 1 },
    { label: 'Duration',      value: durationLabel,                   step: 4 },
    { label: 'Exercises',     value: `${totalEx} total`,              step: 3 },
    ...(useBlocks && blockLabels.length > 0 && duration !== 0
      ? [{ label: 'Blocks', value: blockLabels.join(' → '), step: 4 }]
      : []),
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      {/* Summary */}
      <div style={{ background: C.surface2, borderRadius: 14, border: `1px solid ${C.border}`, overflow: 'hidden' }}>
        <div style={{ padding: '12px 16px', borderBottom: `1px solid ${C.border}` }}>
          <SectionLabel>SUMMARY</SectionLabel>
        </div>
        {summaryRows.map(row => (
          <div key={row.label} style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '11px 16px', borderBottom: `1px solid ${C.border}`,
          }}>
            <span style={{ fontSize: 13, color: C.dim }}>{row.label}</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ fontSize: 13, fontWeight: 600, color: C.text, textAlign: 'right', maxWidth: 180 }}>
                {row.value}
              </span>
              <button
                onClick={() => onEditStep(row.step)}
                style={{ background: 'none', border: 'none', color: C.accent, fontSize: 12, fontWeight: 700, cursor: 'pointer', padding: '2px 0' }}
              >
                Edit
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Sessions breakdown */}
      <div>
        <SectionLabel>SESSIONS</SectionLabel>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {selectedDays.map(dayKey => {
            const dayInfo   = DAYS.find(d => d.key === dayKey);
            const sesName   = sessionNames[dayKey] || dayInfo?.label || dayKey;
            const exercises = sessionExercises[dayKey] || [];
            return (
              <div key={dayKey} style={{
                background: C.surface2, borderRadius: 12, padding: '11px 14px',
                border: `1px solid ${C.border}`,
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              }}>
                <div>
                  <div style={{ fontSize: 14, fontWeight: 600, color: C.text }}>{sesName}</div>
                  <div style={{ fontSize: 12, color: C.dim, marginTop: 2 }}>
                    {dayInfo?.full} · {exercises.length} exercise{exercises.length !== 1 ? 's' : ''}
                  </div>
                </div>
                <button
                  onClick={() => onEditStep(3)}
                  style={{ background: 'none', border: 'none', color: C.accent, fontSize: 12, fontWeight: 700, cursor: 'pointer', padding: '4px 8px' }}
                >
                  Edit
                </button>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ── Root component ────────────────────────────────────────────────────────────

const STEP_META = [
  { title: 'Programme basics', subtitle: 'Name your programme and set your goal' },
  { title: 'Training days',    subtitle: 'Which days will you train?' },
  { title: 'Session split',    subtitle: 'How will you structure your sessions?' },
  { title: 'Add exercises',    subtitle: 'Build each session — you can always edit later' },
  { title: 'Duration',         subtitle: 'How long is the programme?' },
  { title: 'Review & save',    subtitle: 'Everything look good?' },
];
const STEP_COUNT = STEP_META.length;

export default function ManualProgrammeBuilder({ onComplete, onBack, lang = 'en', t = k => k }) {
  const [step, setStep] = useState(0);

  // Step 1
  const [progName, setProgName] = useState('');
  const [goal,     setGoal]     = useState('muscle');

  // Step 2
  const [selectedDays, setSelectedDays] = useState(['mon', 'tue', 'wed', 'thu', 'fri']);

  // Step 3
  const [split,        setSplit]        = useState(null);
  const [sessionNames, setSessionNames] = useState({});

  // Step 4
  const [sessionExercises, setSessionExercises] = useState({});

  // Step 5
  const [duration,    setDuration]    = useState(8);
  const [useBlocks,   setUseBlocks]   = useState(false);
  const [blockLabels, setBlockLabels] = useState(['Block 1', 'Block 2']);

  // Step 6
  const [saving, setSaving] = useState(false);

  const canProceed = () => {
    switch (step) {
      case 0: return progName.trim().length > 0;
      case 1: return selectedDays.length >= 1;
      case 2: return split !== null && selectedDays.every(d => (sessionNames[d] || '').trim());
      case 3: return true; // exercises are optional
      case 4: return true;
      case 5: return true;
      default: return false;
    }
  };

  const handleBack = () => {
    if (step === 0) onBack();
    else setStep(s => s - 1);
  };

  const handleNext = () => {
    if (step < STEP_COUNT - 1) setStep(s => s + 1);
  };

  const handleSave = async () => {
    setSaving(true);
    const output = buildOutput({ progName, goal, selectedDays, sessionNames, sessionExercises, duration, useBlocks, blockLabels });
    try {
      await onComplete(output);
    } catch {
      setSaving(false);
    }
    // Don't reset saving=false on success — the phase change unmounts this component
  };

  const isLast = step === STEP_COUNT - 1;
  const proceed = canProceed();

  return (
    <div style={{
      width: '100%', height: '100%',
      display: 'flex', flexDirection: 'column',
      background: C.bg, overflow: 'hidden',
    }}>
      {/* ── Header ─────────────────────────────────────────────────────── */}
      <div style={{
        paddingTop: 'max(env(safe-area-inset-top, 0px) + 14px, 26px)',
        paddingLeft: 20, paddingRight: 20, paddingBottom: 14,
        flexShrink: 0,
      }}>
        {/* Back + progress bar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18 }}>
          <motion.button
            whileTap={{ scale: 0.92 }}
            onClick={handleBack}
            style={{
              background: C.surface2, border: `1px solid ${C.border}`,
              borderRadius: 10, padding: 8, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <ChevronLeft size={18} color={C.text} />
          </motion.button>

          <div style={{ flex: 1, height: 3, background: C.surface2, borderRadius: 2, overflow: 'hidden' }}>
            <motion.div
              animate={{ width: `${((step + 1) / STEP_COUNT) * 100}%` }}
              transition={springSoft}
              style={{ height: '100%', background: C.accent, borderRadius: 2 }}
            />
          </div>

          <span style={{ fontSize: 12, fontWeight: 700, color: C.dim, flexShrink: 0 }}>
            {step + 1}/{STEP_COUNT}
          </span>
        </div>

        {/* Step title — animates on step change */}
        <AnimatePresence mode="wait">
          <motion.div
            key={step}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -6 }}
            transition={{ duration: 0.14 }}
          >
            <h2 style={{
              fontSize: 22, fontWeight: 800, letterSpacing: '-0.02em',
              color: C.text, margin: 0, marginBottom: 3,
            }}>
              {STEP_META[step].title}
            </h2>
            <p style={{ fontSize: 13, color: C.dim, margin: 0 }}>
              {STEP_META[step].subtitle}
            </p>
          </motion.div>
        </AnimatePresence>
      </div>

      {/* ── Scrollable step content ─────────────────────────────────────── */}
      <div style={{
        flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch',
        padding: '4px 20px 24px',
      }}>
        <AnimatePresence mode="wait">
          <motion.div
            key={step}
            initial={{ opacity: 0, x: 24 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -16 }}
            transition={{ duration: 0.16 }}
          >
            {step === 0 && (
              <Step1 progName={progName} setProgName={setProgName} goal={goal} setGoal={setGoal} />
            )}
            {step === 1 && (
              <Step2 selectedDays={selectedDays} setSelectedDays={setSelectedDays} />
            )}
            {step === 2 && (
              <Step3
                split={split} setSplit={setSplit}
                selectedDays={selectedDays}
                sessionNames={sessionNames} setSessionNames={setSessionNames}
              />
            )}
            {step === 3 && (
              <Step4
                selectedDays={selectedDays}
                sessionNames={sessionNames}
                sessionExercises={sessionExercises}
                setSessionExercises={setSessionExercises}
                lang={lang} t={t}
              />
            )}
            {step === 4 && (
              <Step5
                duration={duration} setDuration={setDuration}
                useBlocks={useBlocks} setUseBlocks={setUseBlocks}
                blockLabels={blockLabels} setBlockLabels={setBlockLabels}
              />
            )}
            {step === 5 && (
              <Step6
                progName={progName} goal={goal}
                selectedDays={selectedDays} sessionNames={sessionNames}
                sessionExercises={sessionExercises}
                duration={duration} useBlocks={useBlocks} blockLabels={blockLabels}
                onEditStep={setStep}
              />
            )}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* ── Bottom CTA ──────────────────────────────────────────────────── */}
      <div style={{
        padding: '12px 20px',
        paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 12px, 24px)',
        borderTop: `1px solid ${C.border}`,
        background: C.bg, flexShrink: 0,
      }}>
        <motion.button
          whileTap={{ scale: (proceed && !saving) ? 0.97 : 1 }}
          onClick={isLast ? handleSave : handleNext}
          disabled={!proceed || saving}
          style={{
            width: '100%', border: 'none', borderRadius: 14,
            padding: '17px 0', fontSize: 15, fontWeight: 800,
            background: (proceed && !saving) ? C.accent : C.surface2,
            color:      (proceed && !saving) ? '#000'   : C.mute,
            cursor: (!proceed || saving) ? 'default' : 'pointer',
            touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            transition: 'background 0.15s',
          }}
        >
          {saving ? (
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ repeat: Infinity, duration: 0.8, ease: 'linear' }}
              style={{
                width: 18, height: 18, borderRadius: '50%',
                border: `2.5px solid ${C.mute}`, borderTopColor: C.bg,
              }}
            />
          ) : isLast ? 'Save programme' : 'Continue →'}
        </motion.button>
      </div>
    </div>
  );
}
