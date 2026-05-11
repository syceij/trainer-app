import { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronLeft, ChevronRight, ChevronDown, ChevronUp, RefreshCw } from 'lucide-react';
import { C, spring, springSoft } from '../tokens.js';
import { headingFont, translateContent, translateDay, toEasternArabic } from '../lib/i18n.js';
import ExercisePickerSheet from './ExercisePickerSheet.jsx';
import { TIMER_PRESETS, getDefaultRestDuration, isCustomDuration } from './shared/RestTimer.jsx';

// ─── EditableField ─────────────────────────────────────────────────────────────
function EditableField({
  value,
  displayValue,   // optional: what to SHOW (translated); edit draft still uses `value`
  onSave, type = 'text', editKey, editedKeys = [],
  placeholder = '—', suffix, style = {}, inputStyle = {}, multiline = false,
  t = k => k,
}) {
  const [editing, setEditing] = useState(false);
  const [draft,   setDraft]   = useState('');
  const inputRef  = useRef(null);
  const isEdited  = editedKeys.includes(editKey);

  const startEdit = () => {
    setDraft(value !== undefined && value !== null ? String(value) : '');
    setEditing(true);
  };
  const commit = () => {
    setEditing(false);
    const parsed = type === 'number' ? (parseFloat(draft) || 0) : draft.trim();
    if (String(parsed) !== String(value)) onSave(parsed);
  };
  const handleKey = (e) => {
    if (e.key === 'Enter' && !multiline) { e.preventDefault(); commit(); }
    if (e.key === 'Escape') setEditing(false);
  };
  useEffect(() => { if (editing) inputRef.current?.focus(); }, [editing]);

  if (editing) {
    const InputTag = multiline ? 'textarea' : 'input';
    return (
      <InputTag
        ref={inputRef}
        type={multiline ? undefined : type}
        inputMode={type === 'number' ? 'decimal' : 'text'}
        value={draft}
        onChange={e => setDraft(e.target.value)}
        onBlur={commit}
        onKeyDown={handleKey}
        rows={multiline ? 2 : undefined}
        style={{
          background: C.surface, border: `1.5px solid ${C.accent}`,
          borderRadius: 7, color: C.text, fontSize: 14,
          padding: '4px 8px', outline: 'none', fontFamily: 'inherit',
          resize: 'none', width: type === 'number' ? 64 : '100%',
          WebkitTapHighlightColor: 'transparent', ...inputStyle,
        }}
      />
    );
  }

  // What to show in display mode (translated if provided, otherwise raw value)
  const shown = displayValue !== undefined ? displayValue : value;

  return (
    <span
      onClick={startEdit}
      title={t('TAP ANY FIELD TO EDIT')}
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 3,
        cursor: 'text',
        borderBottom: `1px dashed ${isEdited ? C.accent : 'rgba(255,255,255,0.12)'}`,
        paddingBottom: 1, color: isEdited ? C.text : undefined, ...style,
      }}
    >
      <span>{shown !== undefined && shown !== null && shown !== '' ? shown : <span style={{ color: C.mute }}>{placeholder}</span>}</span>
      {suffix && <span style={{ fontSize: 11, color: C.dim, marginLeft: 1 }}>{suffix}</span>}
      {isEdited && <span style={{ display: 'inline-block', width: 5, height: 5, borderRadius: '50%', background: C.accent, flexShrink: 0, marginLeft: 2 }} />}
    </span>
  );
}

// ─── ExerciseEditor ────────────────────────────────────────────────────────────
function ExerciseEditor({ ex, exIdx, onSave, onSwap, editedKeys, editKeyPrefix, lang, t, customExercises, onAddCustom }) {
  const [pickerOpen,      setPickerOpen]      = useState(false);
  const [customTimerOpen, setCustomTimerOpen] = useState(false);
  const [customTimerVal,  setCustomTimerVal]  = useState('');
  const field        = (name) => `${editKeyPrefix}_${name}`;
  const isNameEdited = editedKeys.includes(field('name'));
  const restDurVal   = ex.restTimer !== undefined ? ex.restTimer : getDefaultRestDuration(ex);

  return (
    <div style={{ padding: '10px 0', borderBottom: `1px solid ${C.border}` }}>
      {/* Exercise name — tap to open library picker */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
        {ex.tag && (
          <span style={{
            fontSize: 9, fontWeight: 700, padding: '2px 5px', borderRadius: 4,
            background: C.surface, color: ex.tag === 'compound' ? C.accent : C.mute,
            flexShrink: 0,
          }}>
            {t(ex.tag)}
          </span>
        )}
        <button
          onClick={() => setPickerOpen(true)}
          style={{
            flex: 1, background: 'none', border: 'none', padding: 0,
            textAlign: 'left', cursor: 'pointer',
            touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
            display: 'flex', alignItems: 'center', gap: 5, minWidth: 0,
          }}
        >
          <span style={{
            fontSize: 14, fontWeight: 600, color: C.text,
            borderBottom: `1px dashed ${isNameEdited ? C.accent : 'rgba(255,255,255,0.12)'}`,
            paddingBottom: 1,
            whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: '85%',
          }}>
            {ex.name}
          </span>
          {isNameEdited && <span style={{ width: 5, height: 5, borderRadius: '50%', background: C.accent, flexShrink: 0 }} />}
          <RefreshCw size={11} color={C.mute} style={{ flexShrink: 0 }} />
        </button>
      </div>

      {/* Exercise picker — position:fixed, not affected by containing block */}
      <ExercisePickerSheet
        open={pickerOpen}
        onClose={() => setPickerOpen(false)}
        currentKey={ex.key}
        currentName={ex.name}
        onSelect={newEx => { if (onSwap) onSwap(newEx); }}
        lang={lang}
        t={t}
        customExercises={customExercises || []}
        onAddCustom={onAddCustom || null}
      />

      {/* Sets × Reps · RPE · Weight */}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 14, alignItems: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <span style={{ fontSize: 11, color: C.mute }}>{t('Sets')}</span>
          <EditableField value={ex.sets} onSave={v => onSave('sets', v)} type="number"
            editKey={field('sets')} editedKeys={editedKeys}
            style={{ fontSize: 13, fontWeight: 700, color: C.text }} inputStyle={{ width: 44 }} t={t} />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <span style={{ fontSize: 11, color: C.mute }}>{t('Reps')}</span>
          <EditableField value={ex.reps} onSave={v => onSave('reps', v)} type="text"
            editKey={field('reps')} editedKeys={editedKeys}
            style={{ fontSize: 13, fontWeight: 700, color: C.text }} inputStyle={{ width: 60 }} t={t} />
        </div>
        {!ex.bodyweight && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
            <span style={{ fontSize: 11, color: C.mute }}>{t('Weight')}</span>
            <EditableField
              value={ex.weightLabel && ex.weightLabel !== 'undefined' ? ex.weightLabel : ex.weight}
              onSave={v => onSave('weight', isNaN(Number(v)) ? v : Number(v))}
              type={ex.weightLabel ? 'text' : 'number'}
              editKey={field('weight')} editedKeys={editedKeys}
              suffix={!ex.weightLabel ? 'kg' : undefined}
              style={{ fontSize: 13, fontWeight: 700, color: C.accent }} inputStyle={{ width: 60 }} t={t} />
          </div>
        )}
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <span style={{ fontSize: 11, color: C.mute }}>{t('RPE')}</span>
          <EditableField value={ex.rpe} onSave={v => onSave('rpe', v)} type="text"
            editKey={field('rpe')} editedKeys={editedKeys}
            style={{ fontSize: 13, color: C.dim }} inputStyle={{ width: 56 }} t={t} />
        </div>
      </div>

      {/* Notes */}
      <div style={{ marginTop: 6 }}>
        <EditableField
          value={ex.notes || ''}
          displayValue={ex.notes ? translateContent(ex.notes, lang) : undefined}
          onSave={v => onSave('notes', v)} type="text"
          editKey={field('notes')} editedKeys={editedKeys}
          placeholder={t('Add notes…')}
          style={{ fontSize: 11, color: C.mute, fontStyle: 'italic' }}
          inputStyle={{ fontSize: 12, width: '100%' }} t={t} />
      </div>

      {/* Rest timer */}
      <div style={{ marginTop: 10 }}>
        <div style={{
          fontSize: 10, fontWeight: 700,
          letterSpacing: lang === 'ar' ? '0' : '0.08em',
          color: C.mute, marginBottom: 7,
        }}>
          {t('REST TIMER')}
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5 }}>
          {TIMER_PRESETS.map(preset => {
            const isActive = preset.value === -1
              ? isCustomDuration(restDurVal)
              : restDurVal === preset.value;
            return (
              <button
                key={preset.value}
                onClick={() => {
                  if (preset.value === -1) {
                    setCustomTimerOpen(true);
                    setCustomTimerVal(isCustomDuration(restDurVal) ? String(restDurVal) : '');
                  } else {
                    setCustomTimerOpen(false);
                    onSave('restTimer', preset.value);
                  }
                }}
                style={{
                  padding: '4px 9px', borderRadius: 100,
                  background: isActive ? C.accent : C.surface,
                  border: `1.5px solid ${isActive ? C.accent : C.border}`,
                  color: isActive ? '#000' : C.dim,
                  fontSize: 10, fontWeight: 700,
                  cursor: 'pointer', touchAction: 'manipulation',
                  WebkitTapHighlightColor: 'transparent',
                }}
              >
                {preset.label}
              </button>
            );
          })}
        </div>

        {/* Custom duration input */}
        {(customTimerOpen || isCustomDuration(restDurVal)) && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginTop: 7 }}>
            <input
              type="number"
              inputMode="numeric"
              placeholder="e.g. 75"
              value={customTimerOpen ? customTimerVal : (isCustomDuration(restDurVal) ? String(restDurVal) : '')}
              onChange={e => setCustomTimerVal(e.target.value)}
              onFocus={() => {
                if (!customTimerOpen) {
                  setCustomTimerOpen(true);
                  setCustomTimerVal(isCustomDuration(restDurVal) ? String(restDurVal) : '');
                }
              }}
              onBlur={() => {
                const val = parseInt(customTimerVal, 10);
                if (val > 0) {
                  onSave('restTimer', val);
                }
                setCustomTimerOpen(false);
              }}
              style={{
                width: 68, background: C.surface,
                border: `1.5px solid ${C.border}`,
                borderRadius: 6, color: C.text,
                fontSize: 12, padding: '4px 7px',
                outline: 'none', fontFamily: 'inherit',
              }}
            />
            <span style={{ fontSize: 10, color: C.mute }}>sec</span>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── SessionCard ───────────────────────────────────────────────────────────────
function SessionCard({ session, isToday, editKeyPrefix, editedKeys, onSaveSession, onSaveExercise, lang, t, customExercises, onAddCustom }) {
  const [expanded, setExpanded] = useState(isToday);

  return (
    <div style={{
      background: C.surface2, border: `1.5px solid ${isToday ? C.accent : C.border}`,
      borderRadius: 14, overflow: 'hidden', marginBottom: 10,
    }}>
      {/* Header */}
      <div
        onClick={() => setExpanded(e => !e)}
        style={{ padding: '13px 14px', display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer', WebkitTapHighlightColor: 'transparent' }}
      >
        <div style={{
          width: 32, height: 32, borderRadius: 8, flexShrink: 0,
          background: isToday ? C.accent : C.surface,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 12, fontWeight: 800, color: isToday ? '#000' : C.dim,
        }}>
          {session.name?.charAt(0) || '?'}
        </div>

        <div style={{ flex: 1, minWidth: 0 }} onClick={e => e.stopPropagation()}>
          <div style={{ fontSize: 14, fontWeight: 700, marginBottom: 2 }}>
            {onSaveSession ? (
              <EditableField value={session.name}
                displayValue={translateContent(session.name, lang)}
                onSave={v => onSaveSession('name', v)}
                editKey={`${editKeyPrefix}_name`} editedKeys={editedKeys}
                style={{ fontSize: 14, fontWeight: 700, color: C.text }} t={t} />
            ) : (
              <span style={{ color: C.text }}>{translateContent(session.name, lang)}</span>
            )}
          </div>
          <div style={{ fontSize: 11, color: C.dim, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {onSaveSession ? (
              <EditableField value={session.focus || ''}
                displayValue={session.focus ? translateContent(session.focus, lang) : undefined}
                onSave={v => onSaveSession('focus', v)}
                editKey={`${editKeyPrefix}_focus`} editedKeys={editedKeys}
                placeholder={t('Add focus tag…')} style={{ fontSize: 11, color: C.dim }} t={t} />
            ) : (session.focus && <span>{translateContent(session.focus, lang)}</span>)}
            {session.block && onSaveSession ? (
              <>
                <span style={{ color: C.mute }}>·</span>
                <EditableField value={session.block}
                  displayValue={translateContent(session.block, lang)}
                  onSave={v => onSaveSession('block', v)}
                  editKey={`${editKeyPrefix}_block`} editedKeys={editedKeys}
                  style={{ fontSize: 11, color: C.mute }} t={t} />
              </>
            ) : session.block ? (
              <span style={{ color: C.mute }}>· {translateContent(session.block, lang)}</span>
            ) : null}
          </div>
          <div style={{ fontSize: 11, color: C.mute, marginTop: 2 }}>
            {session.exercises?.length || 0} {t('exercises')} · ~{((session.exercises?.length || 5) * 6)} {t('min')}
          </div>
        </div>

        <div onClick={e => { e.stopPropagation(); setExpanded(ex => !ex); }}>
          {expanded ? <ChevronUp size={15} color={C.mute} /> : <ChevronDown size={15} color={C.mute} />}
        </div>
      </div>

      {/* Exercises */}
      <AnimatePresence>
        {expanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={spring}
            style={{ overflow: 'hidden' }}
          >
            <div style={{ padding: '0 14px 14px', borderTop: `1px solid ${C.border}` }}>
              <div style={{ marginTop: 4, marginBottom: 6 }}>
                <span style={{ fontSize: 10, color: C.mute, fontWeight: 600, letterSpacing: lang === 'ar' ? '0' : '0.06em' }}>
                  {t('TAP ANY FIELD TO EDIT')}
                </span>
              </div>
              {session.exercises?.map((ex, exIdx) => (
                <ExerciseEditor
                  key={ex.key || exIdx}
                  ex={ex} exIdx={exIdx}
                  editedKeys={editedKeys}
                  editKeyPrefix={`${editKeyPrefix}_e${exIdx}`}
                  onSave={(field, value) => onSaveExercise && onSaveExercise(exIdx, field, value)}
                  onSwap={onSaveExercise ? (newEx) => {
                    const save = (f, v) => onSaveExercise(exIdx, f, v);
                    save('name', newEx.name);
                    save('key',  newEx.key);
                    save('muscle', newEx.muscle);
                    save('bodyweight', !!newEx.bodyweight);
                    save('tag', newEx.isMain ? 'compound' : (newEx.isCustom ? 'accessory' : 'accessory'));
                    if (!newEx.bodyweight) save('weight', ex.weight ?? 20);
                    const prev = ex.notes ? `${ex.notes} · ` : '';
                    save('notes', `${prev}Swapped from ${ex.name}`);
                    if (newEx.isCustom) save('isCustom', true);
                  } : undefined}
                  lang={lang}
                  t={t}
                  customExercises={customExercises}
                  onAddCustom={onAddCustom}
                />
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// ─── ProgrammePage ─────────────────────────────────────────────────────────────
const DAY_KEYS = ['mon','tue','wed','thu','fri','sat','sun'];

export default function ProgrammePage({ state, onBack }) {
  const {
    programme, programmeMode,
    importedProgramme, currentWeek, setCurrentWeek,
    currentSession, editedKeys,
    updateAutoExerciseField, updateAutoSessionField,
    updateImportedExerciseField, updateImportedSessionField,
    lang, t,
    customExercises = [],
    addCustomExercise,
  } = state;

  const [importedTab, setImportedTab] = useState(currentWeek);
  const isImported = programmeMode === 'imported';
  const rtl        = lang === 'ar';
  const BackIcon   = rtl ? ChevronRight : ChevronLeft;

  return (
    <motion.div
      initial={{ x: rtl ? '-100%' : '100%' }}
      animate={{ x: 0 }}
      exit={{ x: rtl ? '-100%' : '100%' }}
      transition={springSoft}
      style={{
        position: 'absolute', inset: 0, background: C.bg, zIndex: 200,
        display: 'flex', flexDirection: 'column', overflow: 'hidden', willChange: 'transform',
      }}
    >
      {/* ── Top bar ── */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '12px 20px',
        paddingTop: 'max(env(safe-area-inset-top, 0px) + 12px, 20px)',
        borderBottom: `1px solid ${C.border}`, flexShrink: 0, background: C.surface,
      }}>
        <button
          onClick={onBack}
          style={{
            background: C.surface2, border: `1.5px solid ${C.border}`,
            borderRadius: 8, width: 36, height: 36,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: C.text, cursor: 'pointer',
            touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent', flexShrink: 0,
          }}
        >
          <BackIcon size={18} />
        </button>

        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: rtl ? '0' : '0.1em', color: C.accent, marginBottom: 1 }}>
            {isImported ? t('IMPORTED PROGRAMME') : t('YOUR PROGRAMME')}
          </div>
          <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: rtl ? '0' : '-0.02em', color: C.text, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', fontFamily: headingFont(lang) }}>
            {isImported ? translateContent(importedProgramme?.name, lang) : t('Auto-generated')}
          </div>
        </div>

        {editedKeys.length > 0 && (
          <div style={{
            background: 'rgba(184,255,0,0.1)', border: `1px solid rgba(184,255,0,0.3)`,
            borderRadius: 100, padding: '3px 10px',
            fontSize: 10, fontWeight: 700, color: C.accent, flexShrink: 0,
          }}>
            {editedKeys.length} {editedKeys.length !== 1 ? t('edits') : t('edit')}
          </div>
        )}
      </div>

      {/* ── Scrollable content ── */}
      <div style={{
        flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch',
        padding: '16px 16px',
        paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 20px, 28px)',
      }}>
        {isImported
          ? <ImportedContent state={state} importedTab={importedTab} setImportedTab={setImportedTab} />
          : <AutoContent state={state} />
        }
      </div>
    </motion.div>
  );
}

// ─── Auto mode content ─────────────────────────────────────────────────────────
function AutoContent({ state }) {
  const {
    programme, currentSession, editedKeys,
    updateAutoExerciseField, updateAutoSessionField,
    lang, t,
    customExercises = [],
    addCustomExercise,
  } = state;

  const DAY_LETTERS = ['M','T','W','T','F','S','S'];

  return (
    <>
      <div style={{ marginBottom: 20 }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: lang === 'ar' ? '0' : '0.08em', color: C.dim, marginBottom: 10 }}>
          {t('SCHEDULE')}
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 4 }}>
          {DAY_LETTERS.map((letter, i) => {
            const s = programme[i % programme.length];
            const isTraining = !!s;
            return (
              <div key={i} style={{ textAlign: 'center' }}>
                <div style={{ fontSize: 9, color: C.mute, marginBottom: 4 }}>{letter}</div>
                <div style={{
                  height: 32, borderRadius: 6,
                  background: isTraining ? 'rgba(184,255,0,0.12)' : C.surface2,
                  border: `1px solid ${isTraining ? 'rgba(184,255,0,0.25)' : C.border}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 10, fontWeight: 800, color: isTraining ? C.accent : C.mute,
                }}>
                  {isTraining ? s.name?.charAt(0) : '—'}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: lang === 'ar' ? '0' : '0.08em', color: C.dim, marginBottom: 12 }}>
        {t('ALL SESSIONS — TAP TO EXPAND & EDIT')}
      </div>

      {programme.map((session, sessionIdx) => (
        <SessionCard
          key={sessionIdx}
          session={session}
          isToday={session.name === currentSession?.name}
          editKeyPrefix={`auto_s${sessionIdx}`}
          editedKeys={editedKeys}
          onSaveSession={(field, value) => updateAutoSessionField(sessionIdx, field, value)}
          onSaveExercise={(exIdx, field, value) => updateAutoExerciseField(sessionIdx, exIdx, field, value)}
          lang={lang} t={t}
          customExercises={customExercises}
          onAddCustom={addCustomExercise}
        />
      ))}

      <p style={{ fontSize: 11, color: C.mute, textAlign: 'center', marginTop: 8 }}>
        {t('Programme cycles automatically. Edits are saved instantly and persist across sessions.')}
      </p>
    </>
  );
}

// ─── Imported mode content ─────────────────────────────────────────────────────
function ImportedContent({ state, importedTab, setImportedTab }) {
  const {
    importedProgramme, currentWeek, currentSession,
    editedKeys, updateImportedExerciseField, updateImportedSessionField,
    lang, t,
    customExercises = [],
    addCustomExercise,
  } = state;

  const weeks      = importedProgramme?.weeks || [];
  const activeWeek = weeks.find(w => w.weekNumber === importedTab) || weeks[0];

  return (
    <>
      {/* Week tab strip — explicit direction so W1 is on the right in RTL */}
      <div style={{ overflowX: 'auto', WebkitOverflowScrolling: 'touch', marginBottom: 14, direction: lang === 'ar' ? 'rtl' : undefined }}>
        <div style={{ display: 'flex', gap: 6, paddingBottom: 4 }}>
          {weeks.map(w => {
            const active = w.weekNumber === importedTab;
            return (
              <motion.button
                key={w.weekNumber}
                whileTap={{ scale: 0.95 }}
                onClick={() => setImportedTab(w.weekNumber)}
                style={{
                  flexShrink: 0, padding: '6px 14px', borderRadius: 100,
                  background: active ? C.accent : C.surface2,
                  border: `1.5px solid ${active ? C.accent : C.border}`,
                  color: active ? '#000' : C.dim,
                  fontSize: 12, fontWeight: 700,
                  cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                }}
              >
                {lang === 'ar' ? `أ${toEasternArabic(w.weekNumber)}` : `W${w.weekNumber}`}
                {w.weekNumber === currentWeek && <span style={{ marginLeft: 4, fontSize: 8, verticalAlign: 'middle' }}>●</span>}
              </motion.button>
            );
          })}
        </div>
      </div>

      {activeWeek?.label && (
        <div style={{ background: 'rgba(184,255,0,0.07)', border: `1px solid rgba(184,255,0,0.2)`, borderRadius: 8, padding: '8px 12px', marginBottom: 14 }}>
          <span style={{ fontSize: 12, fontWeight: 700, color: C.accent }}>{translateContent(activeWeek.label, lang)}</span>
        </div>
      )}

      {/* Day overview */}
      <div style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: lang === 'ar' ? '0' : '0.08em', color: C.dim, marginBottom: 8 }}>
          {t('Week')} {importedTab} — {t('DAY OVERVIEW')}
        </div>
        {DAY_KEYS.map(day => {
          const s      = activeWeek?.sessions?.find(ss => ss.day === day);
          const isRest = !s || s.isRest;
          return (
            <div key={day} style={{ display: 'flex', gap: 10, padding: '8px 0', borderBottom: `1px solid ${C.border}`, alignItems: 'center' }}>
              <span style={{ width: 38, fontSize: 12, fontWeight: 700, color: isRest ? C.mute : C.accent }}>
                {translateDay(day, lang)}
              </span>
              {isRest ? (
                <span style={{ fontSize: 13, color: C.mute }}>{t('Rest')}</span>
              ) : (
                <span onClick={e => e.stopPropagation()} style={{ flex: 1 }}>
                  <EditableField
                    value={s.name}
                    displayValue={translateContent(s.name, lang)}
                    onSave={v => updateImportedSessionField(activeWeek.weekNumber, day, 'name', v)}
                    editKey={`imp_w${activeWeek.weekNumber}_${day}_name`}
                    editedKeys={editedKeys}
                    style={{ fontSize: 13, fontWeight: 600, color: C.text }}
                    t={t}
                  />
                  {s.focus && (
                    <span style={{ marginLeft: 6, fontSize: 11, color: C.dim }}>
                      · <EditableField
                          value={s.focus}
                          displayValue={translateContent(s.focus, lang)}
                          onSave={v => updateImportedSessionField(activeWeek.weekNumber, day, 'focus', v)}
                          editKey={`imp_w${activeWeek.weekNumber}_${day}_focus`}
                          editedKeys={editedKeys}
                          style={{ fontSize: 11, color: C.dim }}
                          t={t}
                        />
                    </span>
                  )}
                </span>
              )}
            </div>
          );
        })}
      </div>

      {/* Session detail cards */}
      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: lang === 'ar' ? '0' : '0.08em', color: C.dim, marginBottom: 10 }}>
        {t('SESSIONS')} — {t('Week')} {importedTab}
      </div>

      {activeWeek?.sessions
        ?.filter(s => !s.isRest)
        .map((session, si) => {
          const day    = session.day;
          const weekNum = activeWeek.weekNumber;
          const exercises = (session.exercises || []).map((ex, ei) => ({
            ...ex,
            key: `imp_${weekNum}_${day}_${ei}`,
            weight: typeof ex.weight === 'number' ? ex.weight : 0,
            weightLabel: ex.weight === 'BW' ? 'BW' : ex.weight === 'light' ? 'light' : undefined,
            bodyweight: !!ex.bodyweight,
          }));
          const runtimeSession = { ...session, exercises };
          return (
            <SessionCard
              key={`${weekNum}_${day}_${si}`}
              session={runtimeSession}
              isToday={runtimeSession.name === currentSession?.name}
              editKeyPrefix={`imp_w${weekNum}_${day}`}
              editedKeys={editedKeys}
              onSaveSession={(field, value) => updateImportedSessionField(weekNum, day, field, value)}
              onSaveExercise={(exIdx, field, value) => updateImportedExerciseField(weekNum, day, exIdx, field, value)}
              lang={lang} t={t}
              customExercises={customExercises}
              onAddCustom={addCustomExercise}
            />
          );
        })}

      <p style={{ fontSize: 11, color: C.mute, textAlign: 'center', marginTop: 12 }}>
        {t('Edits save instantly and the AI reads your current programme — not the original import.')}
        {currentWeek !== importedTab && ` ${t('Current training week')}: ${lang === 'ar' ? `أ${toEasternArabic(currentWeek)}` : `W${currentWeek}`}.`}
      </p>
    </>
  );
}
