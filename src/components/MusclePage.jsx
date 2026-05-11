/**
 * MusclePage — full-screen muscle-group detail page.
 *
 * Slides in from the Progress tab when a bar is tapped.
 * Loads all sets for the user from Supabase, then filters
 * to this muscle group using the shared muscleUtils resolver.
 *
 * Sections (top → bottom):
 *   Header → Summary stats → Strongest mover →
 *   All exercises → Muscle trend chart
 */

import { createPortal }              from 'react-dom';
import { useState, useEffect, useMemo } from 'react';
import { motion }                    from 'framer-motion';
import { ChevronLeft }               from 'lucide-react';
import { loadAllUserSets }           from '../lib/db.js';
import { getMuscleGroup, resolveMuscleFromName } from '../lib/muscleUtils.js';
import { C, springSoft }             from '../tokens.js';
import { getT }                      from '../lib/i18n.js';

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Parse reps string to lower-bound integer: "8-10" → 8, "10" → 10 */
function repsLower(repsStr) {
  if (!repsStr) return 0;
  return parseInt(String(repsStr).split('-')[0]) || 0;
}

function fmtDate(dateStr) {
  const d = new Date(dateStr);
  return `${d.getDate()}/${d.getMonth() + 1}`;
}

function fmtVolume(v) {
  if (v >= 10000) return `${Math.round(v / 1000)}k`;
  if (v >= 1000)  return `${(Math.round(v / 100) / 10).toFixed(1)}k`;
  return `${Math.round(v)}`;
}

// ── Stat card ─────────────────────────────────────────────────────────────────

function StatCard({ label, value, accent }) {
  return (
    <div style={{
      flex: 1, background: C.surface2, borderRadius: 12,
      border: `1px solid ${C.border}`,
      padding: '12px 10px', textAlign: 'center',
    }}>
      <div style={{
        fontSize: 9, fontWeight: 700, color: C.dim,
        letterSpacing: '0.06em', marginBottom: 6,
      }}>
        {label}
      </div>
      <div style={{
        fontSize: 16, fontWeight: 800,
        color: accent ? C.accent : C.text,
        lineHeight: 1.1,
      }}>
        {value}
      </div>
    </div>
  );
}

// ── Mini sparkline (weight over sessions) ─────────────────────────────────────

function MiniSparkline({ data }) {
  if (!data || data.length === 0) return <div style={{ height: 28 }} />;
  if (data.length === 1) {
    return (
      <svg width={80} height={28} style={{ overflow: 'visible' }}>
        <circle cx={40} cy={14} r={3} fill={C.accent} />
      </svg>
    );
  }
  const W = 80, H = 28;
  const min   = Math.min(...data);
  const max   = Math.max(...data);
  const range = max - min || 1;
  const pts = data.map((v, i) => {
    const x = (i / (data.length - 1)) * W;
    const y = H - ((v - min) / range) * (H - 4) - 2;
    return `${x},${y}`;
  }).join(' ');
  const [lx, ly] = pts.split(' ').pop().split(',');
  return (
    <svg width={W} height={H} style={{ overflow: 'visible' }}>
      <polyline
        fill="none" stroke={C.accent} strokeWidth="1.5"
        strokeLinejoin="round" points={pts}
      />
      <circle cx={lx} cy={ly} r={2.5} fill={C.accent} />
    </svg>
  );
}

// ── Trend line chart ──────────────────────────────────────────────────────────

function TrendChart({ data }) {
  if (!data || data.length < 2) return null;

  const PAD = { top: 18, right: 14, bottom: 28, left: 40 };
  const VW  = 335, VH = 130;
  const CW  = VW - PAD.left - PAD.right;
  const CH  = VH - PAD.top  - PAD.bottom;

  const vals  = data.map(d => d.pct);
  const minY  = Math.min(...vals);
  const maxY  = Math.max(...vals);
  const padY  = (maxY - minY) * 0.15 || 2;
  const lo    = minY - padY;
  const hi    = maxY + padY;
  const rY    = hi - lo || 1;

  const tx = i => PAD.left + (i / (data.length - 1)) * CW;
  const ty = v => PAD.top  + CH - ((v - lo) / rY) * CH;

  const pts   = data.map((d, i) => ({ x: tx(i), y: ty(d.pct), ...d }));
  const lineD = pts.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ');
  const areaD = [
    lineD,
    `L${pts[pts.length - 1].x.toFixed(1)},${(PAD.top + CH).toFixed(1)}`,
    `L${pts[0].x.toFixed(1)},${(PAD.top + CH).toFixed(1)} Z`,
  ].join(' ');

  const yTicks = [minY, (minY + maxY) / 2, maxY];

  return (
    <svg width="100%" viewBox={`0 0 ${VW} ${VH}`} style={{ display: 'block', overflow: 'visible' }}>
      {/* Y gridlines */}
      {yTicks.map((v, i) => (
        <g key={i}>
          <line
            x1={PAD.left} x2={PAD.left + CW}
            y1={ty(v)}    y2={ty(v)}
            stroke={C.border} strokeWidth={1}
          />
          <text
            x={PAD.left - 5} y={ty(v) + 3.5}
            textAnchor="end" fontSize={8} fill={C.mute}
            fontFamily="Inter,system-ui,sans-serif"
          >
            {Math.round(v)}%
          </text>
        </g>
      ))}

      {/* X baseline */}
      <line
        x1={PAD.left} x2={PAD.left + CW}
        y1={PAD.top + CH} y2={PAD.top + CH}
        stroke={C.border} strokeWidth={1}
      />

      {/* Area fill */}
      <path d={areaD} fill={C.accent} fillOpacity="0.06" />

      {/* Line */}
      <path
        d={lineD} fill="none"
        stroke={C.accent} strokeWidth="2"
        strokeLinejoin="round" strokeLinecap="round"
      />

      {/* Dots */}
      {pts.map((p, i) => {
        const isLast = i === pts.length - 1;
        return (
          <circle
            key={i} cx={p.x} cy={p.y}
            r={isLast ? 4 : 2.5}
            fill={isLast ? C.accent : C.surface2}
            stroke={C.accent} strokeWidth="1.5"
          />
        );
      })}

      {/* X labels */}
      {data.map((d, i) => (
        <text
          key={i} x={tx(i)} y={PAD.top + CH + 16}
          textAnchor="middle" fontSize={8} fill={C.mute}
          fontFamily="Inter,system-ui,sans-serif"
        >
          {d.label}
        </text>
      ))}
    </svg>
  );
}

// ── Main component ────────────────────────────────────────────────────────────

export default function MusclePage({ muscleId, userId, onBack, lang = 'en' }) {
  const t = getT(lang);
  const ar = lang === 'ar';
  const [allSets, setAllSets] = useState(null); // null = loading
  const [error,   setError]   = useState(false);

  const mg = getMuscleGroup(muscleId);

  // Load all sets once on mount (or when userId changes)
  useEffect(() => {
    if (!userId) return;
    setAllSets(null);
    setError(false);
    loadAllUserSets(userId)
      .then(rows => setAllSets(rows))
      .catch(() => setError(true));
  }, [userId, muscleId]);

  // ── Derived data ──────────────────────────────────────────────────────────

  /** Sets belonging to this muscle group */
  const muscleSets = useMemo(() => {
    if (!allSets || !mg) return [];
    return allSets.filter(s => {
      const m = resolveMuscleFromName(s.exercise_name);
      return m && mg.muscles.includes(m);
    });
  }, [allSets, mg]);

  /** Per-exercise stats sorted by improvement % descending */
  const exerciseStats = useMemo(() => {
    const map = {};
    for (const s of muscleSets) {
      if (!map[s.exercise_name]) map[s.exercise_name] = [];
      map[s.exercise_name].push(s);
    }
    return Object.entries(map).map(([name, sets]) => {
      const sorted  = [...sets].sort((a, b) =>
        new Date(a.created_at) - new Date(b.created_at)
      );
      const firstW   = parseFloat(sorted[0]?.weight) || null;
      const lastW    = parseFloat(sorted[sorted.length - 1]?.weight) || null;
      const pct      = firstW && lastW && firstW > 0
        ? Math.round(((lastW - firstW) / firstW) * 100)
        : 0;
      const lastDate = sorted[sorted.length - 1]?.created_at;

      // Sparkline: max weight per session
      const sessMap = {};
      for (const s of sorted) {
        const sid = s.session_id || s.created_at.split('T')[0];
        const w   = parseFloat(s.weight);
        if (!isNaN(w) && w > 0) sessMap[sid] = Math.max(sessMap[sid] || 0, w);
      }

      return { name, firstW, lastW, pct, lastDate, sparkData: Object.values(sessMap) };
    }).sort((a, b) => b.pct - a.pct);
  }, [muscleSets]);

  const uniqueSessions = useMemo(
    () => new Set(muscleSets.map(s => s.session_id || s.created_at.split('T')[0])).size,
    [muscleSets]
  );

  const totalVolume = useMemo(
    () => muscleSets.reduce((sum, s) =>
      sum + (parseFloat(s.weight) || 0) * repsLower(s.reps), 0),
    [muscleSets]
  );

  const overallPct = useMemo(() => {
    const imp = exerciseStats.filter(e => e.firstW && e.lastW && e.firstW > 0);
    if (!imp.length) return 0;
    const avg = imp.reduce((s, e) =>
      s + ((e.lastW - e.firstW) / e.firstW) * 100, 0) / imp.length;
    return Math.round(avg);
  }, [exerciseStats]);

  const bestPct        = Math.max(...exerciseStats.map(e => e.pct), 1);
  const strongestMover = exerciseStats.find(e => e.pct > 0) || exerciseStats[0] || null;

  /** Per-week average improvement % vs each exercise's all-time baseline */
  const trendData = useMemo(() => {
    if (!muscleSets.length || !exerciseStats.length) return [];
    const baseline = Object.fromEntries(exerciseStats.map(e => [e.name, e.firstW]));

    const weekMap = {};
    for (const s of muscleSets) {
      const d   = new Date(s.created_at);
      const dow = d.getDay() || 7;
      const mon = new Date(d);
      mon.setDate(d.getDate() - dow + 1);
      const wk  = mon.toISOString().split('T')[0];
      if (!weekMap[wk]) weekMap[wk] = {};
      const w = parseFloat(s.weight);
      if (!isNaN(w) && w > 0)
        weekMap[wk][s.exercise_name] = Math.max(weekMap[wk][s.exercise_name] || 0, w);
    }

    return Object.keys(weekMap).sort().map((wk, idx) => {
      const pcts = Object.entries(weekMap[wk]).map(([name, maxW]) => {
        const base = baseline[name];
        return base && base > 0 ? ((maxW - base) / base) * 100 : 0;
      });
      const avg = pcts.length ? pcts.reduce((s, v) => s + v, 0) / pcts.length : 0;
      return { label: `W${idx + 1}`, pct: Math.round(avg * 10) / 10 };
    });
  }, [muscleSets, exerciseStats]);

  // ── Render ────────────────────────────────────────────────────────────────

  const page = (
    <motion.div
      initial={{ x: '100%' }}
      animate={{ x: 0 }}
      exit={{ x: '100%' }}
      transition={springSoft}
      style={{
        position: 'fixed', inset: 0,
        background: C.bg, zIndex: 600,
        display: 'flex', flexDirection: 'column',
        overflowY: 'auto', WebkitOverflowScrolling: 'touch',
        overflowX: 'hidden',
      }}
    >
      {/* ── Header ─────────────────────────────────────────────────────── */}
      <div style={{
        padding: '0 20px 14px',
        paddingTop: 'max(env(safe-area-inset-top, 0px) + 16px, 28px)',
        borderBottom: `1px solid ${C.border}`,
        flexShrink: 0,
        position: 'sticky', top: 0,
        background: C.bg, zIndex: 10,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <motion.button
            whileTap={{ scale: 0.92 }}
            onClick={onBack}
            style={{
              background: C.surface2, border: `1px solid ${C.border}`,
              borderRadius: 10, padding: 8,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0, cursor: 'pointer',
              touchAction: 'manipulation',
              WebkitTapHighlightColor: 'transparent',
            }}
          >
            <ChevronLeft size={18} color={C.text} />
          </motion.button>
          <div>
            <div style={{ fontSize: 22, fontWeight: 800, color: C.text, letterSpacing: '-0.01em' }}>
              {mg?.label}
            </div>
            <div style={{ fontSize: 12, color: C.dim, marginTop: 2 }}>
              {allSets === null
                ? t('Loading…')
                : ar
                  ? `${uniqueSessions} جلسة · ${exerciseStats.length} تمرين متتبع`
                  : `${uniqueSessions} session${uniqueSessions !== 1 ? 's' : ''} · ${exerciseStats.length} exercise${exerciseStats.length !== 1 ? 's' : ''} tracked`}
            </div>
          </div>
        </div>
      </div>

      {/* ── Body ───────────────────────────────────────────────────────── */}
      <div style={{
        flex: 1, padding: '20px',
        paddingBottom: 52,
        boxSizing: 'border-box',
        overflowX: 'hidden',
      }}>

        {/* Loading */}
        {allSets === null && !error && (
          <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 60 }}>
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ repeat: Infinity, duration: 0.9, ease: 'linear' }}
              style={{
                width: 28, height: 28, borderRadius: '50%',
                border: `3px solid ${C.surface2}`,
                borderTopColor: C.accent,
              }}
            />
          </div>
        )}

        {/* Error */}
        {error && (
          <p style={{ fontSize: 13, color: C.dim, textAlign: 'center', paddingTop: 60 }}>
            {t('Failed to load data. Please try again.')}
          </p>
        )}

        {/* Empty state */}
        {allSets !== null && !error && muscleSets.length === 0 && (
          <div style={{ textAlign: 'center', paddingTop: 60 }}>
            <div style={{ fontSize: 40, marginBottom: 16 }}>💪</div>
            <p style={{ fontSize: 15, fontWeight: 700, color: C.text, marginBottom: 8 }}>
              {ar
                ? `لا جلسات مسجلة لـ${mg?.label} بعد`
                : `No sessions logged for ${mg?.label} yet`}
            </p>
            <p style={{ fontSize: 13, color: C.dim, lineHeight: 1.6 }}>
              {t('Complete a session to start tracking.')}
            </p>
          </div>
        )}

        {/* Data */}
        {allSets !== null && !error && muscleSets.length > 0 && (
          <>
            {/* ── Summary 3-card row ───────────────────────────────────── */}
            <div style={{ display: 'flex', gap: 8, marginBottom: 24 }}>
              <StatCard
                label={t('OVERALL')}
                value={overallPct > 0 ? `+${overallPct}%` : '0%'}
                accent={overallPct > 0}
              />
              <StatCard
                label={t('TOTAL VOLUME')}
                value={`${fmtVolume(totalVolume)} kg`}
              />
              <StatCard
                label={t('EXERCISES')}
                value={exerciseStats.length}
              />
            </div>

            {/* ── Strongest mover ─────────────────────────────────────── */}
            {strongestMover && (
              <div style={{ marginBottom: 24 }}>
                <div style={{
                  fontSize: 11, fontWeight: 700, color: C.dim,
                  letterSpacing: ar ? '0' : '0.08em', marginBottom: 10,
                }}>
                  {t('STRONGEST MOVER')}
                </div>
                <div style={{
                  background: C.surface2, border: `1px solid ${C.border}`,
                  borderRadius: 14, padding: '14px 16px',
                }}>
                  <div style={{
                    display: 'flex', alignItems: 'flex-start',
                    justifyContent: 'space-between', marginBottom: 12,
                  }}>
                    <div style={{ flex: 1, paddingRight: 12 }}>
                      <div style={{
                        display: 'inline-flex', alignItems: 'center',
                        background: C.accent, borderRadius: 6,
                        padding: '2px 8px', marginBottom: 8,
                      }}>
                        <span style={{
                          fontSize: 9, fontWeight: 800,
                          color: '#000', letterSpacing: ar ? '0' : '0.04em',
                        }}>
                          {t('MOST IMPROVED')}
                        </span>
                      </div>
                      <div style={{
                        fontSize: 15, fontWeight: 800,
                        color: C.text, marginBottom: 4,
                      }}>
                        {strongestMover.name}
                      </div>
                      <div style={{ fontSize: 12, color: C.dim }}>
                        {strongestMover.firstW != null ? `${strongestMover.firstW} kg` : '—'}
                        {' → '}
                        {strongestMover.lastW  != null ? `${strongestMover.lastW} kg`  : '—'}
                      </div>
                    </div>
                    <div style={{ textAlign: 'right', flexShrink: 0 }}>
                      <div style={{
                        fontSize: 26, fontWeight: 800,
                        color: strongestMover.pct > 0 ? C.accent : C.dim,
                      }}>
                        {strongestMover.pct > 0 ? `+${strongestMover.pct}%` : '—'}
                      </div>
                    </div>
                  </div>
                  <MiniSparkline data={strongestMover.sparkData} />
                </div>
              </div>
            )}

            {/* ── All exercises ────────────────────────────────────────── */}
            <div style={{ marginBottom: 24 }}>
              <div style={{
                fontSize: 11, fontWeight: 700, color: C.dim,
                letterSpacing: ar ? '0' : '0.08em', marginBottom: 10,
              }}>
                {t('ALL EXERCISES')}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {exerciseStats.map(ex => {
                  const barW = bestPct > 0 && ex.pct > 0
                    ? Math.max((ex.pct / bestPct) * 100, 4)
                    : 0;
                  return (
                    <div key={ex.name} style={{
                      background: C.surface2, border: `1px solid ${C.border}`,
                      borderRadius: 12, padding: '12px 14px',
                    }}>
                      <div style={{
                        display: 'flex', justifyContent: 'space-between',
                        alignItems: 'flex-start', marginBottom: 8,
                      }}>
                        <div style={{ flex: 1, paddingRight: 12 }}>
                          <div style={{
                            fontSize: 13, fontWeight: 700,
                            color: C.text, marginBottom: 2,
                          }}>
                            {ex.name}
                          </div>
                          <div style={{ fontSize: 11, color: C.dim }}>
                            {ex.firstW != null && ex.lastW != null
                              ? `${ex.firstW} kg → ${ex.lastW} kg`
                              : '—'}
                            {ex.lastDate ? `  ·  ${fmtDate(ex.lastDate)}` : ''}
                          </div>
                        </div>
                        <div style={{
                          fontSize: 15, fontWeight: 800,
                          color: ex.pct > 0 ? C.accent : C.mute,
                          flexShrink: 0,
                        }}>
                          {ex.pct > 0 ? `+${ex.pct}%` : '0%'}
                        </div>
                      </div>

                      {/* Progress bar */}
                      <div style={{
                        height: 4, background: C.border,
                        borderRadius: 2, overflow: 'hidden',
                      }}>
                        <motion.div
                          initial={{ width: 0 }}
                          animate={{ width: `${barW}%` }}
                          transition={{ type: 'spring', stiffness: 160, damping: 24 }}
                          style={{
                            height: '100%',
                            background: ex.pct > 0 ? C.accent : 'rgba(255,255,255,0.1)',
                            borderRadius: 2,
                          }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* ── Trend chart ─────────────────────────────────────────── */}
            {trendData.length >= 2 && (
              <div style={{ marginBottom: 24 }}>
                <div style={{
                  fontSize: 11, fontWeight: 700, color: C.dim,
                  letterSpacing: ar ? '0' : '0.08em', marginBottom: 10,
                }}>
                  {ar ? `اتجاه ${mg?.label}` : `${mg?.label.toUpperCase()} TREND`}
                </div>
                <div style={{
                  background: C.surface2, border: `1px solid ${C.border}`,
                  borderRadius: 14, padding: '16px 12px 8px',
                  overflow: 'hidden', boxSizing: 'border-box',
                }}>
                  <TrendChart data={trendData} />
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </motion.div>
  );

  return createPortal(page, document.body);
}
