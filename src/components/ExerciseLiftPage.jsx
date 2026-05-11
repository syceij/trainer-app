/**
 * ExerciseLiftPage — full-screen exercise progress history.
 * Slides in over the Progress tab.  Loads data from the `sets` table.
 *
 * Rendered via createPortal at document.body so position:fixed covers
 * the true viewport even when the parent tab container has a CSS transform
 * applied by framer-motion.
 */

import { createPortal } from 'react-dom';
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { ChevronLeft } from 'lucide-react';
import { loadSetsForExercise } from '../lib/db.js';
import { C, springSoft } from '../tokens.js';
import { getT } from '../lib/i18n.js';

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Group raw set rows by session_id, returning one summary row per session. */
function groupBySession(rows) {
  const map = {};
  for (const r of rows) {
    const sid = r.session_id || r.created_at.split('T')[0]; // fallback to date
    if (!map[sid]) map[sid] = { date: r.created_at, sets: [] };
    map[sid].sets.push(r);
  }
  return Object.values(map)
    .map(g => {
      const maxWeight = Math.max(...g.sets.map(s => parseFloat(s.weight) || 0));
      const firstSet  = g.sets[0];
      return {
        date:   g.date,
        count:  g.sets.length,
        reps:   firstSet?.reps  || '—',
        weight: maxWeight || null,
        rpe:    firstSet?.rpe   || null,
      };
    })
    .sort((a, b) => new Date(b.date) - new Date(a.date)); // newest first
}

/**
 * Derive one { date, weight, ms } chart point per session.
 *
 * Groups by session_id (falls back to the date string when session_id is absent
 * so old rows without a session_id still plot separately per day).
 * Weight used for each point is the MAX weight recorded in that session.
 * Rows must arrive sorted created_at ASC (the DB query guarantees this) so
 * the first row encountered per session gives the correct session date.
 */
function toChartData(rows) {
  const sessionMap = {};
  for (const r of rows) {
    const key = r.session_id || r.created_at.split('T')[0];
    const w   = parseFloat(r.weight);
    if (isNaN(w) || w <= 0) continue;
    if (!sessionMap[key]) {
      // First row for this session — record date and initial weight
      sessionMap[key] = { date: r.created_at, weight: w };
    } else {
      // Subsequent rows — keep the max weight for the session
      if (w > sessionMap[key].weight) sessionMap[key].weight = w;
    }
  }
  return Object.values(sessionMap)
    .map(({ date, weight }) => ({ date, weight, ms: new Date(date).getTime() }))
    .sort((a, b) => a.ms - b.ms);
}

function fmt(dateStr) {
  const d = new Date(dateStr);
  return `${d.getDate()}/${d.getMonth() + 1}`;
}

// ── SVG line chart ─────────────────────────────────────────────────────────────

function LineChart({ data }) {
  if (!data || data.length === 0) return null;

  // For a single data point just show a dot + label
  if (data.length === 1) {
    return (
      <svg width="100%" viewBox="0 0 335 120" style={{ overflow: 'visible' }}>
        <circle cx={167} cy={60} r={6} fill={C.accent} />
        <text x={167} y={84} textAnchor="middle" fontSize={10} fill={C.dim}>
          {fmt(data[0].date)}
        </text>
        <text x={167} y={52} textAnchor="middle" fontSize={10} fill={C.accent} fontWeight="700">
          {data[0].weight} kg
        </text>
      </svg>
    );
  }

  const PAD = { top: 20, right: 20, bottom: 34, left: 44 };
  const VW  = 335;
  const VH  = 180;
  const CW  = VW - PAD.left - PAD.right;
  const CH  = VH - PAD.top  - PAD.bottom;

  const minX = data[0].ms;
  const maxX = data[data.length - 1].ms;
  const minY = Math.min(...data.map(d => d.weight));
  const maxY = Math.max(...data.map(d => d.weight));
  const rangeX = maxX - minX || 1;
  // Add 10% padding to Y range so points aren't glued to edges
  const padY  = (maxY - minY) * 0.12 || maxY * 0.1 || 5;
  const lo    = minY - padY;
  const hi    = maxY + padY;
  const rangeY = hi - lo;

  const tx = ms  => PAD.left + ((ms  - minX) / rangeX) * CW;
  const ty = w   => PAD.top  + CH - ((w   - lo)    / rangeY) * CH;

  const pts   = data.map(d => ({ x: tx(d.ms), y: ty(d.weight), ...d }));
  const lineD = pts.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ');
  const areaD = `${lineD} L${pts[pts.length-1].x.toFixed(1)},${(PAD.top+CH).toFixed(1)} L${pts[0].x.toFixed(1)},${(PAD.top+CH).toFixed(1)} Z`;

  // Y ticks: 3 evenly spaced values
  const yTicks = [minY, (minY + maxY) / 2, maxY];

  // X labels: first, last, and at most one middle (avoid crowding)
  const xLabels = data.length <= 2
    ? data
    : [data[0], data[Math.floor((data.length - 1) / 2)], data[data.length - 1]];

  return (
    <svg width="100%" viewBox={`0 0 ${VW} ${VH}`} style={{ overflow: 'visible', display: 'block' }}>
      {/* Horizontal grid lines */}
      {yTicks.map((w, i) => (
        <g key={i}>
          <line
            x1={PAD.left} x2={PAD.left + CW}
            y1={ty(w)}    y2={ty(w)}
            stroke={C.border} strokeWidth="1"
          />
          <text
            x={PAD.left - 5} y={ty(w) + 3.5}
            textAnchor="end" fontSize="9" fill={C.mute}
            fontFamily="Inter, system-ui, sans-serif"
          >
            {Math.round(w)}
          </text>
        </g>
      ))}

      {/* X axis baseline */}
      <line
        x1={PAD.left} x2={PAD.left + CW}
        y1={PAD.top + CH} y2={PAD.top + CH}
        stroke={C.border} strokeWidth="1"
      />

      {/* Area fill */}
      <path d={areaD} fill={C.accent} fillOpacity="0.07" />

      {/* Line */}
      <path d={lineD} fill="none" stroke={C.accent} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />

      {/* Dots */}
      {pts.map((p, i) => {
        const isLast = i === pts.length - 1;
        return (
          <circle
            key={i}
            cx={p.x} cy={p.y}
            r={isLast ? 5 : 3}
            fill={isLast ? C.accent : C.surface2}
            stroke={C.accent}
            strokeWidth="2"
          />
        );
      })}

      {/* X axis labels */}
      {xLabels.map((d, i) => (
        <text
          key={i}
          x={tx(d.ms)} y={PAD.top + CH + 18}
          textAnchor="middle" fontSize="9" fill={C.mute}
          fontFamily="Inter, system-ui, sans-serif"
        >
          {fmt(d.date)}
        </text>
      ))}
    </svg>
  );
}

// ── Stat pill ─────────────────────────────────────────────────────────────────

function Stat({ label, value, accent }) {
  return (
    <div style={{
      flex: 1,
      background: C.surface2, borderRadius: 12,
      border: `1px solid ${C.border}`,
      padding: '12px 10px', textAlign: 'center',
    }}>
      <div style={{ fontSize: 10, fontWeight: 700, color: C.dim, letterSpacing: '0.06em', marginBottom: 6 }}>
        {label}
      </div>
      <div style={{ fontSize: 17, fontWeight: 800, color: accent ? C.accent : C.text, lineHeight: 1.1 }}>
        {value}
      </div>
    </div>
  );
}

// ── Main component ────────────────────────────────────────────────────────────

export default function ExerciseLiftPage({ exercise, userId, onBack, lang = 'en' }) {
  const t = getT(lang);
  const ar = lang === 'ar';
  const [rows,    setRows]    = useState(null); // null = loading
  const [error,   setError]   = useState(false);

  useEffect(() => {
    if (!exercise || !userId) return;
    setRows(null);
    setError(false);
    loadSetsForExercise(userId, exercise.name)
      .then(data => setRows(data))
      .catch(() => setError(true));
  }, [exercise, userId]);

  // Derived data (only computed when rows are ready)
  // rows is sorted created_at ASC by the DB query, so rows[0] is the oldest set
  // and rows[rows.length-1] is the most recently recorded set.
  const chartData  = rows ? toChartData(rows) : [];
  const tableRows  = rows ? groupBySession(rows) : [];
  const uniqueSessions = new Set(rows?.map(r => r.session_id)).size;

  // Use the raw rows for start/current so we get the actual first-ever weight (e.g. 25 kg)
  // rather than the per-day max that toChartData produces.
  const firstWeight = rows?.length ? (parseFloat(rows[0].weight) || null) : null;
  const lastWeight  = rows?.length ? (parseFloat(rows[rows.length - 1].weight) || null) : null;
  const increase    = firstWeight !== null && lastWeight !== null ? lastWeight - firstWeight : null;
  const increasePct = firstWeight && increase !== null ? Math.round((increase / firstWeight) * 100) : null;

  const page = (
    <motion.div
      initial={{ x: '100%' }}
      animate={{ x: 0 }}
      exit={{ x: '100%' }}
      transition={springSoft}
      style={{
        position: 'fixed', inset: 0,
        background: C.bg,
        zIndex: 600,
        display: 'flex', flexDirection: 'column',
        overflowY: 'auto', WebkitOverflowScrolling: 'touch',
        overflowX: 'hidden',  // prevent horizontal bleed from chart SVG
      }}
    >
      {/* ── Header ───────────────────────────────────────────────────────── */}
      <div style={{
        padding: '0 20px 16px',
        paddingTop: 'max(env(safe-area-inset-top, 0px) + 16px, 28px)',
        borderBottom: `1px solid ${C.border}`,
        flexShrink: 0,
        position: 'sticky', top: 0, background: C.bg, zIndex: 10,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <motion.button
            whileTap={{ scale: 0.92 }}
            onClick={onBack}
            style={{
              background: C.surface2, border: `1px solid ${C.border}`,
              borderRadius: 10, padding: 8, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <ChevronLeft size={18} color={C.text} />
          </motion.button>
          <div>
            <div style={{ fontSize: 18, fontWeight: 800, color: C.text, letterSpacing: '-0.01em' }}>
              {exercise?.name}
            </div>
            <div style={{ fontSize: 12, color: C.dim, marginTop: 1 }}>
              {rows === null
                ? t('Loading…')
                : ar
                  ? `${uniqueSessions} ${t('Sessions').toLowerCase()} مسجلة`
                  : `${uniqueSessions} session${uniqueSessions !== 1 ? 's' : ''} logged`}
            </div>
          </div>
        </div>
      </div>

      {/* ── Content ──────────────────────────────────────────────────────── */}
      <div style={{
        flex: 1, padding: '20px 20px', paddingBottom: 40,
        overflowX: 'hidden', width: '100%', boxSizing: 'border-box',
      }}>

        {/* Loading */}
        {rows === null && !error && (
          <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 60 }}>
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ repeat: Infinity, duration: 0.9, ease: 'linear' }}
              style={{
                width: 28, height: 28, borderRadius: '50%',
                border: `3px solid ${C.surface2}`, borderTopColor: C.accent,
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

        {/* No data */}
        {rows !== null && !error && rows.length === 0 && (
          <div style={{ textAlign: 'center', paddingTop: 60 }}>
            <div style={{ fontSize: 32, marginBottom: 16 }}>📊</div>
            <p style={{ fontSize: 14, fontWeight: 700, color: C.text, marginBottom: 8 }}>
              {t('No sessions logged yet')}
            </p>
            <p style={{ fontSize: 13, color: C.dim, lineHeight: 1.5 }}>
              {ar
                ? `أكمل جلسة مع ${exercise?.name} للبدء في تتبع التقدم.`
                : `Complete a session with ${exercise?.name} to start tracking progress.`}
            </p>
          </div>
        )}

        {/* Data */}
        {rows !== null && !error && rows.length > 0 && (
          <>
            {/* Summary stats */}
            <div style={{ display: 'flex', gap: 8, marginBottom: 24 }}>
              <Stat label={t('START')} value={firstWeight !== null ? `${firstWeight} kg` : '—'} />
              <Stat label={t('CURRENT')} value={lastWeight !== null ? `${lastWeight} kg` : '—'} accent />
              <Stat
                label={t('INCREASE')}
                value={increase !== null
                  ? `${increase >= 0 ? '+' : ''}${increase} kg`
                  : '—'}
                accent={increase > 0}
              />
              <Stat label={t('SESSIONS')} value={uniqueSessions} />
            </div>

            {/* Percentage badge if improved */}
            {increasePct !== null && increase > 0 && (
              <div style={{
                background: 'rgba(184,255,0,0.1)', border: '1px solid rgba(184,255,0,0.25)',
                borderRadius: 10, padding: '8px 14px', marginBottom: 20,
                display: 'flex', alignItems: 'center', gap: 8,
              }}>
                <span style={{ fontSize: 18 }}>📈</span>
                <span style={{ fontSize: 13, fontWeight: 700, color: C.accent }}>
                  {ar
                    ? `أقوى بنسبة +${increasePct}% منذ بدايتك`
                    : `+${increasePct}% stronger since you started`}
                </span>
              </div>
            )}

            {/* Chart */}
            <div style={{
              background: C.surface2, borderRadius: 14,
              border: `1px solid ${C.border}`,
              padding: '16px 12px 8px',
              marginBottom: 24,
              overflow: 'hidden',  // clip any SVG overflow within the card
              width: '100%', boxSizing: 'border-box',
            }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: C.dim, letterSpacing: ar ? '0' : '0.06em', marginBottom: 12 }}>
                {t('WEIGHT OVER TIME (kg)')}
              </div>
              <LineChart data={chartData} />
            </div>

            {/* Data table */}
            <div style={{ width: '100%', boxSizing: 'border-box' }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: C.dim, letterSpacing: ar ? '0' : '0.06em', marginBottom: 12 }}>
                {t('SESSION LOG')}
              </div>

              {/* Table header */}
              <div style={{
                display: 'grid', gridTemplateColumns: '2fr 2fr 1.5fr 1fr',
                padding: '6px 14px', gap: 4,
                width: '100%', boxSizing: 'border-box',
              }}>
                {[t('Date'), t('Sets × Reps'), t('Weight'), t('RPE')].map(h => (
                  <div key={h} style={{ fontSize: 10, fontWeight: 700, color: C.mute, letterSpacing: ar ? '0' : '0.04em' }}>
                    {h.toUpperCase()}
                  </div>
                ))}
              </div>

              {/* Table rows */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {tableRows.map((row, i) => (
                  <div
                    key={i}
                    style={{
                      display: 'grid', gridTemplateColumns: '2fr 2fr 1.5fr 1fr',
                      padding: '11px 14px', gap: 4,
                      background: C.surface2, borderRadius: 10,
                      border: `1px solid ${C.border}`,
                      width: '100%', boxSizing: 'border-box',
                    }}
                  >
                    <div style={{ fontSize: 12, fontWeight: 600, color: C.text }}>
                      {fmt(row.date)}
                    </div>
                    <div style={{ fontSize: 12, color: C.dim }}>
                      {row.count} × {row.reps}
                    </div>
                    <div style={{ fontSize: 12, fontWeight: 700, color: i === 0 ? C.accent : C.text }}>
                      {row.weight !== null ? `${row.weight} kg` : '—'}
                    </div>
                    <div style={{ fontSize: 12, color: C.dim }}>
                      {row.rpe || '—'}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </>
        )}
      </div>
    </motion.div>
  );

  return createPortal(page, document.body);
}
