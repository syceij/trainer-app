import { useState, useRef, useCallback, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Check, Sparkles, Zap, ChevronDown, ChevronUp } from 'lucide-react';
import CenteredModal from './shared/CenteredModal.jsx';
import WeightStepper from './shared/WeightStepper.jsx';
import RestTimer, { TIMER_PRESETS, getDefaultRestDuration, isCustomDuration } from './shared/RestTimer.jsx';
import { C, spring, springSoft } from '../tokens.js';
import { headingFont, translateContent } from '../lib/i18n.js';

export default function TodayTab({ state }) {
  const {
    currentSession, completedSets, setCompletedSets,
    history, finishSession, showToast,
    lang, t,
    programmeMode, programme, currentWeek,
    updateAutoExerciseField, updateImportedExerciseField,
  } = state;

  const [showSummary,        setShowSummary]        = useState(false);
  const [editWeights,        setEditWeights]        = useState({});
  const [inlineWeight,       setInlineWeight]       = useState(null);
  const [customTimerInput,   setCustomTimerInput]   = useState({}); // exKey → string draft
  // Local mirror of rest-timer choices so chips respond immediately without
  // waiting for the App.jsx state propagation chain (which can silently no-op
  // if sessionIdx lookup fails for imported programmes).
  const [restTimerLocal,     setRestTimerLocal]     = useState({}); // exKey → seconds
  // Long-press set logging
  const [setLogs,  setSetLogs]  = useState({}); // { [exKey_si]: { reps, rpe, failed } }
  const [popup,    setPopup]    = useState(null);
  const lpTimerRef  = useRef(null); // long-press timeout
  const lpStartRef  = useRef({ x: 0, y: 0 }); // touch origin to cancel on scroll
  const lpFiredRef  = useRef(false); // swallows the click that follows a touch long-press

  // ── Timer ──────────────────────────────────────────────────────────────────
  const [activeTimerKey, setActiveTimerKey] = useState(null);
  const [timerRemaining,  setTimerRemaining]  = useState(0);
  const [timerDuration,   setTimerDuration]   = useState(0);
  const [timerPaused,     setTimerPaused]     = useState(false);
  const timerIntervalRef  = useRef(null);
  const timerRemainingRef = useRef(0);

  // Cleanup on unmount
  useEffect(() => () => {
    if (timerIntervalRef.current) clearInterval(timerIntervalRef.current);
    clearTimeout(lpTimerRef.current);
  }, []);

  // Start the raw setInterval tick (call after setting up refs/state)
  const startTimerInterval = useCallback(() => {
    if (timerIntervalRef.current) { clearInterval(timerIntervalRef.current); timerIntervalRef.current = null; }
    timerIntervalRef.current = setInterval(() => {
      timerRemainingRef.current -= 1;
      if (timerRemainingRef.current <= 0) {
        clearInterval(timerIntervalRef.current);
        timerIntervalRef.current = null;
        setActiveTimerKey(null);
        setTimerRemaining(0);
        setTimerDuration(0);
        setTimerPaused(false);
      } else {
        setTimerRemaining(timerRemainingRef.current);
      }
    }, 1000);
  }, []);

  const stopTimer = useCallback(() => {
    if (timerIntervalRef.current) { clearInterval(timerIntervalRef.current); timerIntervalRef.current = null; }
    timerRemainingRef.current = 0;
    setActiveTimerKey(null);
    setTimerRemaining(0);
    setTimerDuration(0);
    setTimerPaused(false);
  }, []);

  const startTimer = useCallback((exKey, duration) => {
    if (!duration || duration <= 0) return;
    if (timerIntervalRef.current) { clearInterval(timerIntervalRef.current); timerIntervalRef.current = null; }
    timerRemainingRef.current = duration;
    setActiveTimerKey(exKey);
    setTimerRemaining(duration);
    setTimerDuration(duration);
    setTimerPaused(false);
    startTimerInterval();
  }, [startTimerInterval]);

  const togglePause = useCallback(() => {
    setTimerPaused(paused => {
      if (!paused) {
        // Pause: kill interval
        if (timerIntervalRef.current) { clearInterval(timerIntervalRef.current); timerIntervalRef.current = null; }
        return true;
      } else {
        // Resume: restart interval
        startTimerInterval();
        return false;
      }
    });
  }, [startTimerInterval]);

  // ── Persist rest timer preference to programme data ────────────────────────
  const saveRestTimer = useCallback((exIdx, value) => {
    if (programmeMode === 'auto' && programme) {
      const sessionIdx = programme.findIndex(s => s.name === currentSession?.name);
      if (sessionIdx >= 0 && updateAutoExerciseField) {
        updateAutoExerciseField(sessionIdx, exIdx, 'restTimer', value);
      }
    } else if (programmeMode === 'imported') {
      const day = currentSession?.day;
      if (day && updateImportedExerciseField) {
        updateImportedExerciseField(currentWeek, day, exIdx, 'restTimer', value);
      }
    }
  }, [programmeMode, programme, currentSession, currentWeek, updateAutoExerciseField, updateImportedExerciseField]);

  // ── Long-press: open the set-log popup ────────────────────────────────────
  const openPopup = useCallback((exKey, exIdx, si, ex, rect) => {
    const PH = 280, PW = 220;
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const top  = rect.top - PH - 10 > 16
      ? rect.top - PH - 10
      : Math.min(rect.bottom + 10, vh - PH - 16);
    const left = Math.max(8, Math.min(
      rect.left + rect.width / 2 - PW / 2,
      vw - PW - 8,
    ));
    setPopup({ exKey, exIdx, si, ex, position: { top, left } });
  }, []);

  // ── No session ─────────────────────────────────────────────────────────────
  if (!currentSession) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%', flexDirection: 'column', gap: 12, padding: 24, textAlign: 'center' }}>
        <Zap size={40} color={C.mute} />
        <p style={{ fontSize: 16, color: C.dim }}>
          {t('No session loaded.')}<br />{t('Go to Home to select one.')}
        </p>
      </div>
    );
  }

  const exercises = currentSession.exercises || [];
  const totalSets = exercises.reduce((s, ex) => s + ex.sets, 0);
  const doneSets  = Object.values(completedSets).filter(Boolean).length;
  const progress  = totalSets > 0 ? doneSets / totalSets : 0;
  const getWeight = (ex) => editWeights[ex.key] !== undefined ? editWeights[ex.key] : ex.weight;

  const isSetDone = (exKey, setIdx) => !!completedSets[`${exKey}_${setIdx}`];

  // Toggle set done; start/stop timer accordingly
  const toggleSet = (exKey, setIdx, ex) => {
    const k            = `${exKey}_${setIdx}`;
    const wasAlreadyDone = !!completedSets[k];
    setCompletedSets(cs => ({ ...cs, [k]: !cs[k] }));

    if (!wasAlreadyDone) {
      // Set just completed — check if ALL sets for this exercise are now done
      const newSets  = { ...completedSets, [k]: true };
      const allDone  = Array.from({ length: ex.sets }).every((_, si) => newSets[`${exKey}_${si}`]);

      if (allDone) {
        // All sets finished — hide timer for this exercise
        if (activeTimerKey === exKey) stopTimer();
      } else {
        // Start (or restart) the rest timer — prefer local override for instant response
        const restDur = restTimerLocal[exKey] !== undefined
          ? restTimerLocal[exKey]
          : ex.restTimer !== undefined ? ex.restTimer : getDefaultRestDuration(ex);
        if (restDur > 0) startTimer(exKey, restDur);
      }
    }
  };

  const handleSave = () => {
    const finalExercises = exercises.map(ex => {
      const base = {
        ...ex,
        weight: editWeights[ex.key] !== undefined ? editWeights[ex.key] : ex.weight,
      };
      // Attach per-set overrides if any sets were logged via long-press
      const perSetData = Array.from({ length: ex.sets }, (_, si) =>
        setLogs[`${ex.key}_${si}`] || null
      );
      if (perSetData.some(Boolean)) base.perSetData = perSetData;
      return base;
    });
    finishSession(finalExercises);
    setShowSummary(false);
    setEditWeights({});
    stopTimer();
  };

  const isWeek1  = history.length < 4;
  const isDeload = history.length >= 16;

  return (
    <div style={{ padding: '0 20px', paddingTop: 'max(env(safe-area-inset-top, 0px) + 16px, 24px)', paddingBottom: 24 }}>

      {/* ── Header ── */}
      <motion.h1
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        style={{
          fontSize: 26, fontWeight: 800, letterSpacing: lang === 'ar' ? '0' : '-0.02em',
          color: C.text, marginBottom: 4,
          fontFamily: headingFont(lang),
        }}
      >
        {translateContent(currentSession.name, lang)}
      </motion.h1>

      {currentSession.focus && (
        <p style={{ fontSize: 13, color: C.dim, marginBottom: 16 }}>
          {translateContent(currentSession.focus, lang)}{currentSession.block ? ` · ${translateContent(currentSession.block, lang)}` : ''}
        </p>
      )}

      {/* ── Progress bar ── */}
      <div style={{ marginBottom: 8 }}>
        <div style={{ height: 4, background: C.surface2, borderRadius: 2, overflow: 'hidden', marginBottom: 6 }}>
          <motion.div
            animate={{ width: `${progress * 100}%` }}
            transition={spring}
            style={{ height: '100%', background: C.accent, borderRadius: 2, willChange: 'width' }}
          />
        </div>
        <span style={{ fontSize: 12, color: C.dim, fontWeight: 600 }}>
          {doneSets} / {totalSets} {t('sets complete')}
        </span>
      </div>

      {/* ── Banners ── */}
      {isWeek1 && (
        <div style={{ background: 'rgba(184,255,0,0.06)', border: `1px solid rgba(184,255,0,0.25)`, borderRadius: 10, padding: '10px 14px', marginBottom: 14, display: 'flex', gap: 8, alignItems: 'flex-start' }}>
          <Sparkles size={14} color={C.accent} style={{ marginTop: 2, flexShrink: 0 }} />
          <span style={{ fontSize: 12, color: C.dim, lineHeight: 1.5 }}>
            {t('Calibration week — adjust weights as needed. This data trains your future progressions.')}
          </span>
        </div>
      )}
      {isDeload && (
        <div style={{ background: 'rgba(255,180,0,0.06)', border: `1px solid rgba(255,180,0,0.25)`, borderRadius: 10, padding: '10px 14px', marginBottom: 14 }}>
          <span style={{ fontSize: 12, color: '#FFB800' }}>
            {t('Deload recommended — consider reducing weights by 10-15%.')}
          </span>
        </div>
      )}

      {/* ── Exercise cards ── */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {exercises.map((ex, exIdx) => {
          const weight     = getWeight(ex);
          const showInline = inlineWeight === ex.key;
          // Effective rest duration — local state wins so chips respond immediately
          const restDurVal = restTimerLocal[ex.key] !== undefined
            ? restTimerLocal[ex.key]
            : ex.restTimer !== undefined ? ex.restTimer : getDefaultRestDuration(ex);

          return (
            <motion.div
              key={ex.key}
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ ...spring, delay: exIdx * 0.05 }}
              style={{ background: C.surface2, border: `1px solid ${C.border}`, borderRadius: 14, padding: '14px 16px' }}
            >
              {/* ── Card header: name + weight button ── */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 10 }}>
                <div style={{ flex: 1, marginRight: lang === 'ar' ? 0 : 8, marginLeft: lang === 'ar' ? 8 : 0 }}>
                  <div style={{ fontSize: 15, fontWeight: 700, color: C.text, marginBottom: 3 }}>{ex.name}</div>
                  <div style={{ fontSize: 12, color: C.dim }}>
                    {ex.sets} × {ex.reps}{ex.rpe ? ` · ${t('RPE')} ${ex.rpe}` : ''}
                    {ex.tag && (
                      <span style={{ marginLeft: 6, padding: '1px 6px', background: C.surface, borderRadius: 4, fontSize: 10, fontWeight: 600, color: C.mute }}>
                        {t(ex.tag)}
                      </span>
                    )}
                  </div>
                  {ex.readyToProgress && (
                    <span style={{ display: 'inline-block', marginTop: 4, fontSize: 10, fontWeight: 700, color: '#4ADE80', background: 'rgba(74,222,128,0.1)', borderRadius: 4, padding: '1px 6px' }}>
                      {t('↑ Ready to progress')}
                    </span>
                  )}
                  {ex.notes && (
                    <div style={{ fontSize: 11, color: C.mute, marginTop: 4, fontStyle: 'italic' }}>{translateContent(ex.notes, lang)}</div>
                  )}
                </div>

                {/* Weight / BW button — always toggles inline expand */}
                <motion.button
                  whileTap={{ scale: 0.95 }}
                  onClick={() => setInlineWeight(showInline ? null : ex.key)}
                  style={{
                    background: 'rgba(184,255,0,0.1)', border: `1.5px solid rgba(184,255,0,0.3)`,
                    borderRadius: 8, padding: '6px 10px', cursor: 'pointer',
                    touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                    display: 'flex', alignItems: 'center', gap: 4, flexShrink: 0,
                  }}
                >
                  <span style={{ fontSize: 14, fontWeight: 800, color: C.accent }}>
                    {ex.bodyweight ? t('BW') : ex.weightLabel === 'light' ? t('light') : `${weight}kg`}
                  </span>
                  {showInline ? <ChevronUp size={12} color={C.accent} /> : <ChevronDown size={12} color={C.accent} />}
                </motion.button>
              </div>

              {/* ── Inline expand: weight stepper + rest timer chips ── */}
              <AnimatePresence>
                {showInline && (
                  <motion.div
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: 'auto', opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    transition={spring}
                    style={{ overflow: 'hidden' }}
                  >
                    <div style={{ paddingTop: 10, paddingBottom: 6 }}>
                      {/* Weight stepper — non-bodyweight only */}
                      {!ex.bodyweight && (
                        <div style={{ marginBottom: 14 }}>
                          <WeightStepper
                            value={weight}
                            onChange={v => setEditWeights(w => ({ ...w, [ex.key]: v }))}
                          />
                        </div>
                      )}

                      {/* Rest timer chips */}
                      <div>
                        <div style={{
                          fontSize: 10, fontWeight: 700,
                          letterSpacing: lang === 'ar' ? '0' : '0.08em',
                          color: C.mute, marginBottom: 8,
                        }}>
                          {t('REST TIMER')}
                        </div>
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                          {TIMER_PRESETS.map(preset => {
                            const isActive = preset.value === -1
                              ? isCustomDuration(restDurVal)
                              : restDurVal === preset.value;
                            return (
                              <motion.button
                                key={preset.value}
                                whileTap={{ scale: 0.92 }}
                                onClick={() => {
                                  if (preset.value === -1) {
                                    // Show custom input
                                    setCustomTimerInput(d => ({
                                      ...d,
                                      [ex.key]: isCustomDuration(restDurVal) ? String(restDurVal) : '',
                                    }));
                                  } else {
                                    // Update local state immediately (instant visual response)
                                    // then persist to programme in the background
                                    setRestTimerLocal(o => ({ ...o, [ex.key]: preset.value }));
                                    setCustomTimerInput(d => {
                                      const n = { ...d };
                                      delete n[ex.key];
                                      return n;
                                    });
                                    saveRestTimer(exIdx, preset.value);
                                  }
                                }}
                                style={{
                                  padding: '5px 10px', borderRadius: 100,
                                  background: isActive ? C.accent : C.surface,
                                  border: `1.5px solid ${isActive ? C.accent : C.border}`,
                                  color: isActive ? '#000' : C.dim,
                                  fontSize: 11, fontWeight: 700,
                                  cursor: 'pointer', touchAction: 'manipulation',
                                  WebkitTapHighlightColor: 'transparent',
                                }}
                              >
                                {preset.label}
                              </motion.button>
                            );
                          })}
                        </div>

                        {/* Custom duration input */}
                        {(customTimerInput[ex.key] !== undefined || isCustomDuration(restDurVal)) && (
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
                            <input
                              type="number"
                              inputMode="numeric"
                              placeholder="e.g. 75"
                              value={
                                customTimerInput[ex.key] !== undefined
                                  ? customTimerInput[ex.key]
                                  : isCustomDuration(restDurVal) ? String(restDurVal) : ''
                              }
                              onChange={e => setCustomTimerInput(d => ({ ...d, [ex.key]: e.target.value }))}
                              onBlur={() => {
                                const draft = customTimerInput[ex.key];
                                if (draft !== undefined) {
                                  const val = parseInt(draft, 10);
                                  if (val > 0) {
                                    setRestTimerLocal(o => ({ ...o, [ex.key]: val }));
                                    saveRestTimer(exIdx, val);
                                  }
                                  setCustomTimerInput(d => {
                                    const n = { ...d };
                                    delete n[ex.key];
                                    return n;
                                  });
                                }
                              }}
                              style={{
                                width: 72,
                                background: C.surface,
                                border: `1.5px solid ${C.border}`,
                                borderRadius: 7, color: C.text,
                                fontSize: 13, padding: '5px 8px',
                                outline: 'none', fontFamily: 'inherit',
                              }}
                            />
                            <span style={{ fontSize: 11, color: C.mute }}>sec</span>
                          </div>
                        )}
                      </div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>

              {/* ── Set buttons + rest timer ring ── */}
              {/* alignItems:center keeps row height fixed at max(44px,52px)=52px always */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                {/* Set buttons */}
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', flex: 1 }}>
                  {Array.from({ length: ex.sets }).map((_, si) => {
                    const done    = isSetDone(ex.key, si);
                    const hasLog  = !!setLogs[`${ex.key}_${si}`];
                    return (
                      <motion.button
                        key={si}
                        whileTap={{ scale: 0.9 }}
                        transition={spring}
                        // Guard: swallow the synthetic click that fires after a touch long-press
                        onClick={() => {
                          if (lpFiredRef.current) { lpFiredRef.current = false; return; }
                          toggleSet(ex.key, si, ex);
                        }}
                        onTouchStart={(e) => {
                          const t = e.touches[0];
                          lpStartRef.current = { x: t.clientX, y: t.clientY };
                          clearTimeout(lpTimerRef.current);
                          lpFiredRef.current = false;
                          const el = e.currentTarget;
                          lpTimerRef.current = setTimeout(() => {
                            lpFiredRef.current = true;
                            navigator.vibrate && navigator.vibrate(50);
                            openPopup(ex.key, exIdx, si, ex, el.getBoundingClientRect());
                          }, 500);
                        }}
                        onTouchMove={(e) => {
                          const t = e.touches[0];
                          if (Math.abs(t.clientX - lpStartRef.current.x) > 10 ||
                              Math.abs(t.clientY - lpStartRef.current.y) > 10) {
                            clearTimeout(lpTimerRef.current);
                          }
                        }}
                        onTouchEnd={() => clearTimeout(lpTimerRef.current)}
                        onTouchCancel={() => clearTimeout(lpTimerRef.current)}
                        style={{
                          width: 44, height: 44, borderRadius: 10,
                          background: done ? C.accent : C.surface,
                          border: `1.5px solid ${done ? C.accent : C.border}`,
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
                          position: 'relative',
                        }}
                      >
                        {done ? (
                          <motion.div initial={{ scale: 0, rotate: -20 }} animate={{ scale: 1, rotate: 0 }} transition={spring}>
                            <Check size={18} color="#000" strokeWidth={3} />
                          </motion.div>
                        ) : (
                          <span style={{ fontSize: 13, fontWeight: 700, color: C.mute }}>{si + 1}</span>
                        )}
                        {/* White dot — indicates a long-press detailed log exists */}
                        {done && hasLog && (
                          <div style={{
                            position: 'absolute', top: 4, right: 4,
                            width: 5, height: 5, borderRadius: '50%',
                            background: 'rgba(0,0,0,0.55)',
                            pointerEvents: 'none',
                          }} />
                        )}
                      </motion.button>
                    );
                  })}
                </div>

                {/* Rest timer ring — shown only for the active exercise */}
                <RestTimer
                  duration={timerDuration}
                  remaining={activeTimerKey === ex.key ? timerRemaining : 0}
                  paused={timerPaused}
                  onTap={togglePause}
                />
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* ── Finish button — inline below last exercise ── */}
      <motion.button
        whileTap={{ scale: 0.97 }}
        onClick={() => setShowSummary(true)}
        style={{
          width: '100%', background: C.accent, border: 'none',
          borderRadius: 14, padding: '16px 0', fontSize: 15, fontWeight: 800, color: '#000',
          cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
          boxShadow: '0 4px 24px rgba(184,255,0,0.35)',
          fontFamily: headingFont(lang),
          marginTop: 16,
        }}
      >
        {t('Finish Session →')}
      </motion.button>

      {/* ── Long-press set log popup ── */}
      <AnimatePresence>
        {popup && (
          <SetLogPopup
            key="set-log-popup"
            popup={popup}
            onClose={() => setPopup(null)}
            onConfirm={(reps, rpe, failed) => {
              const { exKey, si, ex } = popup;
              const k = `${exKey}_${si}`;
              // Store the custom log data
              setSetLogs(logs => ({ ...logs, [k]: { reps, rpe, failed } }));
              // Mark set complete and start rest timer (mirrors toggleSet logic)
              const wasAlreadyDone = !!completedSets[k];
              setCompletedSets(cs => ({ ...cs, [k]: true }));
              if (!wasAlreadyDone) {
                const newSets = { ...completedSets, [k]: true };
                const allDone = Array.from({ length: ex.sets }).every((_, si2) =>
                  newSets[`${exKey}_${si2}`]
                );
                if (allDone) {
                  if (activeTimerKey === exKey) stopTimer();
                } else {
                  const restDur = restTimerLocal[exKey] !== undefined
                    ? restTimerLocal[exKey]
                    : ex.restTimer !== undefined ? ex.restTimer : getDefaultRestDuration(ex);
                  if (restDur > 0) startTimer(exKey, restDur);
                }
              }
              setPopup(null);
            }}
            t={t}
          />
        )}
      </AnimatePresence>

      {/* ── Session-complete modal ── */}
      <CenteredModal
        open={showSummary}
        onClose={() => setShowSummary(false)}
        footer={
          <motion.button
            whileTap={{ scale: 0.97 }}
            onClick={handleSave}
            style={{
              width: '100%', background: C.accent, border: 'none',
              borderRadius: 14, padding: '16px 0', fontSize: 15, fontWeight: 800, color: '#000',
              cursor: 'pointer', touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
              fontFamily: headingFont(lang),
            }}
          >
            {t('Save Session ✓')}
          </motion.button>
        }
      >
        <SummarySheet
          session={currentSession}
          exercises={exercises}
          editWeights={editWeights}
          setEditWeights={setEditWeights}
          doneSets={doneSets}
          lang={lang}
          t={t}
        />
      </CenteredModal>
    </div>
  );
}

// ─── SetLogPopup ───────────────────────────────────────────────────────────────
// Small popup that appears above a set button on long-press.
// popup = { exKey, exIdx, si, ex, position: { top, left } }
function SetLogPopup({ popup, onClose, onConfirm, t }) {
  const { ex, si } = popup;

  // Pre-fill with programmed values, extracting a single number from range strings
  const parseDefault = (v, fallback = '') => {
    if (v == null || v === '') return fallback;
    const s = String(v);
    const parts = s.split('-');
    return parts[parts.length - 1].trim();
  };

  const [reps,   setReps]   = useState(parseDefault(ex.reps));
  const [rpe,    setRpe]    = useState(parseDefault(ex.rpe, ''));
  const [failed, setFailed] = useState(false);

  const inputStyle = {
    width: '100%', boxSizing: 'border-box',
    background: C.surface, border: `1.5px solid ${C.border}`,
    borderRadius: 8, color: C.text, fontSize: 15,
    padding: '7px 10px', outline: 'none',
    fontFamily: 'Inter, system-ui, sans-serif',
    WebkitAppearance: 'none',
  };
  const labelStyle = {
    fontSize: 10, fontWeight: 700, color: C.mute,
    letterSpacing: '0.07em', display: 'block', marginBottom: 5,
  };

  return (
    <>
      {/* Dimmed backdrop — tap to dismiss */}
      <div
        onClick={onClose}
        style={{
          position: 'fixed', inset: 0,
          background: 'rgba(0,0,0,0.5)',
          backdropFilter: 'blur(2px)', WebkitBackdropFilter: 'blur(2px)',
          zIndex: 200,
        }}
      />

      {/* Popup card */}
      <motion.div
        initial={{ opacity: 0, scale: 0.88, y: 6 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.88, y: 6 }}
        transition={{ type: 'spring', stiffness: 480, damping: 34 }}
        onClick={e => e.stopPropagation()}
        style={{
          position: 'fixed',
          top: popup.position.top,
          left: popup.position.left,
          width: 220,
          background: C.surface2,
          border: `1px solid ${C.border}`,
          borderRadius: 14,
          padding: '14px 14px 12px',
          zIndex: 201,
          boxShadow: '0 8px 40px rgba(0,0,0,0.6)',
        }}
      >
        {/* Title */}
        <div style={{ fontSize: 13, fontWeight: 800, color: C.text, marginBottom: 12 }}>
          {t('Log set')} {si + 1}
        </div>

        {/* Reps */}
        <div style={{ marginBottom: 9 }}>
          <label style={labelStyle}>REPS COMPLETED</label>
          <input
            type="number"
            inputMode="numeric"
            value={reps}
            onChange={e => setReps(e.target.value)}
            style={inputStyle}
          />
        </div>

        {/* RPE */}
        <div style={{ marginBottom: 9 }}>
          <label style={labelStyle}>ACTUAL RPE</label>
          <input
            type="number"
            inputMode="decimal"
            step="0.5"
            min="1"
            max="10"
            value={rpe}
            onChange={e => setRpe(e.target.value)}
            style={inputStyle}
          />
        </div>

        {/* Failed set toggle */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          marginBottom: 12,
        }}>
          <span style={{ fontSize: 12, fontWeight: 600, color: C.dim }}>Failed set</span>
          <button
            onClick={() => setFailed(f => !f)}
            style={{
              width: 40, height: 22, borderRadius: 11, padding: 0,
              background: failed ? 'rgba(255,70,70,0.9)' : C.surface,
              border: `1.5px solid ${failed ? 'rgba(255,70,70,0.9)' : C.border}`,
              position: 'relative', cursor: 'pointer',
              transition: 'background 0.15s, border-color 0.15s',
              flexShrink: 0,
              WebkitTapHighlightColor: 'transparent',
            }}
          >
            <div style={{
              width: 16, height: 16, borderRadius: '50%', background: '#fff',
              position: 'absolute', top: 2,
              left: failed ? 20 : 2,
              transition: 'left 0.15s',
            }} />
          </button>
        </div>

        {/* Action buttons */}
        <div style={{ display: 'flex', gap: 7 }}>
          <button
            onClick={onClose}
            style={{
              flex: 1, padding: '9px 0',
              background: C.surface, border: `1.5px solid ${C.border}`,
              borderRadius: 10, color: C.dim,
              fontSize: 12, fontWeight: 700,
              cursor: 'pointer', WebkitTapHighlightColor: 'transparent',
            }}
          >
            Cancel
          </button>
          <button
            onClick={() => onConfirm(reps, rpe, failed)}
            style={{
              flex: 1, padding: '9px 0',
              background: C.accent, border: 'none',
              borderRadius: 10, color: '#000',
              fontSize: 12, fontWeight: 800,
              cursor: 'pointer', WebkitTapHighlightColor: 'transparent',
            }}
          >
            Log set
          </button>
        </div>
      </motion.div>
    </>
  );
}

// ─── SummarySheet ──────────────────────────────────────────────────────────────
function SummarySheet({ session, exercises, editWeights, setEditWeights, doneSets, lang, t }) {
  const totalVol = exercises.reduce((s, ex) => {
    if (ex.bodyweight) return s;
    const w = editWeights[ex.key] !== undefined ? editWeights[ex.key] : ex.weight;
    return s + w * ex.sets;
  }, 0);

  return (
    <div>
      <div style={{ textAlign: 'center', marginBottom: 20 }}>
        <div style={{
          fontSize: 11, fontWeight: 700,
          letterSpacing: lang === 'ar' ? '0' : '0.1em',
          color: C.accent, marginBottom: 6,
        }}>
          {t('SESSION COMPLETE')}
        </div>
        <div style={{ fontSize: 22, fontWeight: 800, color: C.text, marginBottom: 12, fontFamily: headingFont(lang) }}>
          {translateContent(session.name, lang)}
        </div>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 20 }}>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: 20, fontWeight: 800, color: C.text }}>{doneSets}</div>
            <div style={{ fontSize: 11, color: C.dim }}>{t('Sets done')}</div>
          </div>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: 20, fontWeight: 800, color: C.text }}>{Math.round(totalVol)} kg</div>
            <div style={{ fontSize: 11, color: C.dim }}>{t('Volume')}</div>
          </div>
        </div>
      </div>

      {exercises.filter(ex => !ex.bodyweight).length > 0 && (
        <>
          <div style={{
            fontSize: 12, fontWeight: 700,
            letterSpacing: lang === 'ar' ? '0' : '0.08em',
            color: C.dim, marginBottom: 12,
          }}>
            {t('EDIT FINAL WEIGHTS')}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 8 }}>
            {exercises.filter(ex => !ex.bodyweight).map(ex => (
              <WeightStepper
                key={ex.key}
                label={ex.name}
                value={editWeights[ex.key] !== undefined ? editWeights[ex.key] : ex.weight}
                onChange={v => setEditWeights(w => ({ ...w, [ex.key]: v }))}
              />
            ))}
          </div>
        </>
      )}
    </div>
  );
}
