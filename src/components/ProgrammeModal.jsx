import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import BottomSheet from './shared/BottomSheet.jsx';
import { C, spring } from '../tokens.js';

const DAY_LETTERS = ['M','T','W','T','F','S','S'];
const DAY_KEYS = ['mon','tue','wed','thu','fri','sat','sun'];

function ExerciseRow({ ex }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 0', borderBottom: `1px solid ${C.border}` }}>
      <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 6px', borderRadius: 4, background: C.surface, color: C.mute }}>{ex.tag || 'acc'}</span>
      <span style={{ flex: 1, fontSize: 13, color: C.text }}>{ex.name}</span>
      <span style={{ fontSize: 11, color: C.dim }}>{ex.sets}×{ex.reps}</span>
      <span style={{ fontSize: 11, color: C.accent, fontWeight: 700 }}>
        {ex.bodyweight ? 'BW' : ex.weightLabel || `${ex.weight}kg`}
      </span>
    </div>
  );
}

function SessionCard({ session, isToday }) {
  const [expanded, setExpanded] = useState(false);
  return (
    <div style={{ background: C.surface2, border: `1.5px solid ${isToday ? C.accent : C.border}`, borderRadius: 12, overflow: 'hidden', marginBottom: 8 }}>
      <button
        onClick={() => setExpanded(e => !e)}
        style={{
          width: '100%', background: 'none', border: 'none', padding: '12px 14px',
          display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer',
          touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
        }}
      >
        <div style={{
          width: 30, height: 30, borderRadius: 8, flexShrink: 0,
          background: isToday ? C.accent : C.surface,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 11, fontWeight: 800, color: isToday ? '#000' : C.dim,
        }}>
          {session.name?.charAt(0) || '?'}
        </div>
        <div style={{ flex: 1, textAlign: 'left' }}>
          <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>{session.name}</div>
          <div style={{ fontSize: 11, color: C.dim }}>
            {session.exercises?.length || 0} exercises · ~{((session.exercises?.length || 5) * 6)} min
          </div>
        </div>
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
              {session.exercises?.map((ex, i) => <ExerciseRow key={i} ex={ex} />)}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export default function ProgrammeModal({ open, onClose, state }) {
  const { programme, programmeMode, importedProgramme, currentWeek, setCurrentWeek, currentSession } = state;
  const [importedTab, setImportedTab] = useState(currentWeek);

  if (!open) return null;

  const isImported = programmeMode === 'imported';

  return (
    <BottomSheet open={open} onClose={onClose} maxHeight="92vh">
      {/* Header */}
      <div style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.1em', color: C.accent, marginBottom: 6 }}>
          {isImported ? 'IMPORTED PROGRAMME' : 'YOUR PROGRAMME'}
        </div>
        <div style={{ fontSize: 20, fontWeight: 800, color: C.text, letterSpacing: '-0.02em' }}>
          {isImported ? importedProgramme?.name : 'Auto-generated'}
        </div>
        {isImported && importedProgramme?.description && (
          <div style={{ fontSize: 13, color: C.dim, marginTop: 4 }}>{importedProgramme.description}</div>
        )}
      </div>

      {/* Auto mode */}
      {!isImported && (
        <>
          {/* 7-day grid */}
          <div style={{ marginBottom: 16 }}>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.08em', color: C.dim, marginBottom: 8 }}>SCHEDULE</div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 4 }}>
              {DAY_LETTERS.map((letter, i) => {
                const sessionForDay = programme[i % programme.length];
                const isTraining = !!sessionForDay;
                return (
                  <div key={i} style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: 9, color: C.mute, marginBottom: 4 }}>{letter}</div>
                    <div style={{
                      height: 32, borderRadius: 6,
                      background: isTraining ? 'rgba(184,255,0,0.15)' : C.surface2,
                      border: `1px solid ${isTraining ? 'rgba(184,255,0,0.3)' : C.border}`,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontSize: 10, fontWeight: 800,
                      color: isTraining ? C.accent : C.mute,
                    }}>
                      {isTraining ? sessionForDay.name?.charAt(0) || 'T' : '—'}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.08em', color: C.dim, marginBottom: 10 }}>ALL SESSIONS</div>
          {programme.map((session, i) => (
            <SessionCard key={i} session={session} isToday={session.name === currentSession?.name} />
          ))}
          <p style={{ fontSize: 11, color: C.mute, textAlign: 'center', marginTop: 12 }}>Programme cycles automatically after completing all sessions.</p>
        </>
      )}

      {/* Imported mode */}
      {isImported && importedProgramme && (
        <>
          {/* Week tabs */}
          <div style={{ overflowX: 'auto', WebkitOverflowScrolling: 'touch', marginBottom: 16 }}>
            <div style={{ display: 'flex', gap: 6, paddingBottom: 4 }}>
              {importedProgramme.weeks.map(w => {
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
                    {w.label ? `W${w.weekNumber}` : `W${w.weekNumber}`}
                    {w.label?.toLowerCase().includes('deload') ? ' · DL' : ''}
                  </motion.button>
                );
              })}
            </div>
          </div>

          {/* Week label */}
          {(() => {
            const wk = importedProgramme.weeks.find(w => w.weekNumber === importedTab);
            if (wk?.label) return (
              <div style={{ background: C.successBg, border: `1px solid ${C.successBorder}`, borderRadius: 8, padding: '8px 12px', marginBottom: 14 }}>
                <span style={{ fontSize: 12, fontWeight: 700, color: C.accent }}>{wk.label}</span>
              </div>
            );
            return null;
          })()}

          {/* Day list */}
          {(() => {
            const wk = importedProgramme.weeks.find(w => w.weekNumber === importedTab);
            if (!wk) return null;
            return (
              <>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4, marginBottom: 14 }}>
                  {DAY_KEYS.map(day => {
                    const s = wk.sessions.find(ss => ss.day === day);
                    const isRest = !s || s.isRest;
                    return (
                      <div key={day} style={{ display: 'flex', gap: 10, padding: '8px 0', borderBottom: `1px solid ${C.border}` }}>
                        <span style={{ width: 40, fontSize: 12, fontWeight: 700, color: isRest ? C.mute : C.accent, textTransform: 'capitalize' }}>
                          {day.charAt(0).toUpperCase() + day.slice(1)}
                        </span>
                        <span style={{ fontSize: 13, color: isRest ? C.mute : C.text }}>
                          {isRest ? 'Rest' : s.name}{s?.focus ? ` · ${s.focus}` : ''}
                        </span>
                      </div>
                    );
                  })}
                </div>

                <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.08em', color: C.dim, marginBottom: 10 }}>
                  SESSIONS — WEEK {importedTab}
                </div>
                {wk.sessions.filter(s => !s.isRest).map((session, i) => {
                  const runtime = { name: session.name, focus: session.focus, exercises: session.exercises?.map((ex, j) => ({ ...ex, key: `modal_${j}`, bodyweight: ex.bodyweight, weightLabel: ex.weight === 'BW' ? 'BW' : ex.weight === 'light' ? 'light' : undefined, weight: typeof ex.weight === 'number' ? ex.weight : 0 })) || [] };
                  return <SessionCard key={i} session={runtime} isToday={false} />;
                })}
              </>
            );
          })()}

          <p style={{ fontSize: 11, color: C.mute, textAlign: 'center', marginTop: 12 }}>
            Tap a week tab to browse — current training week is W{currentWeek}
          </p>
        </>
      )}
    </BottomSheet>
  );
}
