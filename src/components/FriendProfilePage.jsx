import { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronLeft, Dumbbell, TrendingUp, Calendar, UserMinus, Trophy } from 'lucide-react';
import { C, springSoft } from '../tokens.js';
import { loadFriendProfile, loadFriendSessions, loadFriendWeights, removeFriend } from '../lib/db.js';
import { MUSCLE_GROUPS, resolveMuscleFromName } from '../lib/muscleUtils.js';

// ── Stat card ──────────────────────────────────────────────────────────────────
function StatCard({ label, value, sub }) {
  return (
    <div style={{
      flex: 1, background: C.surface2, borderRadius: 12,
      border: `1px solid ${C.border}`, padding: '12px 10px',
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
    }}>
      <div style={{ fontSize: 20, fontWeight: 800, color: C.text }}>{value}</div>
      {sub && <div style={{ fontSize: 11, color: C.accent, fontWeight: 700 }}>{sub}</div>}
      <div style={{ fontSize: 11, color: C.mute, textAlign: 'center', lineHeight: 1.3 }}>{label}</div>
    </div>
  );
}

// ── Muscle bar mini ────────────────────────────────────────────────────────────
function MuscleBar({ label, pct, isTop }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
      <div style={{ fontSize: 12, color: C.dim, width: 70, flexShrink: 0 }}>{label}</div>
      <div style={{ flex: 1, height: 6, background: C.surface2, borderRadius: 3, overflow: 'hidden' }}>
        <motion.div
          initial={{ width: 0 }}
          animate={{ width: `${Math.min(pct, 100)}%` }}
          transition={{ duration: 0.6, ease: 'easeOut' }}
          style={{ height: '100%', background: isTop ? C.accent : '#3a3a3a', borderRadius: 3 }}
        />
      </div>
      <div style={{ fontSize: 12, color: isTop ? C.accent : C.mute, fontWeight: 700, width: 36, textAlign: 'right' }}>
        +{pct}%
      </div>
    </div>
  );
}

// ── FriendProfilePage ──────────────────────────────────────────────────────────
export default function FriendProfilePage({ friendId, currentUserId, onBack, onRemoved }) {
  const [profile,  setProfile]  = useState(null);
  const [sessions, setSessions] = useState([]);
  const [weights,  setWeights]  = useState({});
  const [loading,  setLoading]  = useState(true);
  const [confirm,  setConfirm]  = useState(false);
  const [removing, setRemoving] = useState(false);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      const [prof, sess, wts] = await Promise.all([
        loadFriendProfile(friendId),
        loadFriendSessions(friendId, 10),
        loadFriendWeights(friendId),
      ]);
      if (!cancelled) {
        setProfile(prof);
        setSessions(sess || []);
        setWeights(wts || {});
        setLoading(false);
      }
    }
    load();
    return () => { cancelled = true; };
  }, [friendId]);

  // Compute muscle improvement from sessions
  const muscleImprovements = (() => {
    if (!sessions.length) return [];
    const exMap = {};
    for (const sess of sessions) {
      for (const ex of (sess.exercises || [])) {
        if (!ex.name || ex.bodyweight) continue;
        const muscle = resolveMuscleFromName(ex.name);
        if (!muscle) continue;
        if (!exMap[ex.name]) exMap[ex.name] = { muscle, weights: [] };
        if (ex.weight) exMap[ex.name].weights.push(parseFloat(ex.weight));
      }
    }
    const grouped = {};
    for (const [, info] of Object.entries(exMap)) {
      const { muscle, weights: ws } = info;
      if (ws.length < 2) continue;
      const first = ws[0], last = ws[ws.length - 1];
      const pct = first > 0 ? Math.round(((last - first) / first) * 100) : 0;
      if (!grouped[muscle]) grouped[muscle] = { pcts: [] };
      grouped[muscle].pcts.push(pct);
    }
    const results = [];
    for (const mg of MUSCLE_GROUPS) {
      const allMuscles = mg.muscles;
      const allPcts = allMuscles.flatMap(m => (grouped[m]?.pcts || []));
      if (!allPcts.length) continue;
      const avg = Math.round(allPcts.reduce((a, b) => a + b, 0) / allPcts.length);
      if (avg > 0) results.push({ id: mg.id, label: mg.label, pct: avg });
    }
    return results.sort((a, b) => b.pct - a.pct);
  })();

  const topMuscle = muscleImprovements[0] || null;

  const handleRemove = async () => {
    if (!confirm) { setConfirm(true); return; }
    setRemoving(true);
    await removeFriend(currentUserId, friendId);
    setRemoving(false);
    onRemoved?.();
    onBack();
  };

  const page = (
    <motion.div
      initial={{ x: '100%' }}
      animate={{ x: 0 }}
      exit={{ x: '100%' }}
      transition={springSoft}
      style={{
        position: 'fixed', inset: 0, zIndex: 5000,
        background: C.bg,
        display: 'flex', flexDirection: 'column',
        overflow: 'hidden',
        maxWidth: 390, margin: '0 auto',
      }}
    >
      {/* Header */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '12px 16px',
        paddingTop: 'max(env(safe-area-inset-top, 0px) + 12px, 20px)',
        borderBottom: `1px solid ${C.border}`, flexShrink: 0,
        background: C.surface,
      }}>
        <motion.button
          whileTap={{ scale: 0.93 }}
          onClick={onBack}
          style={{
            background: C.surface2, border: `1.5px solid ${C.border}`,
            borderRadius: 8, width: 36, height: 36,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', flexShrink: 0,
          }}
        >
          <ChevronLeft size={18} color={C.text} />
        </motion.button>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 16, fontWeight: 800, color: C.text }}>
            {loading ? 'Loading…' : (profile?.username || profile?.name || 'Bro')}
          </div>
          {profile?.username && (
            <div style={{ fontSize: 11, color: C.mute }}>@{profile.username}</div>
          )}
        </div>
        {!loading && (
          <motion.button
            whileTap={{ scale: 0.93 }}
            onClick={handleRemove}
            disabled={removing}
            style={{
              background: confirm ? 'rgba(255,80,80,0.12)' : C.surface2,
              border: `1.5px solid ${confirm ? 'rgba(255,80,80,0.4)' : C.border}`,
              borderRadius: 8, padding: '6px 12px',
              fontSize: 12, fontWeight: 700,
              color: confirm ? '#ff6b6b' : C.mute,
              cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 6,
            }}
          >
            <UserMinus size={13} />
            {confirm ? (removing ? 'Removing…' : 'Confirm?') : 'Remove'}
          </motion.button>
        )}
      </div>

      {/* Content */}
      <div style={{
        flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch',
        padding: '16px 16px',
        paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 20px, 32px)',
      }}>

        {loading ? (
          <div style={{ textAlign: 'center', padding: 60, color: C.mute, fontSize: 14 }}>
            Loading profile…
          </div>
        ) : (
          <>
            {/* Avatar + name */}
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: 24 }}>
              <div style={{
                width: 72, height: 72, borderRadius: '50%',
                background: `linear-gradient(135deg, ${C.accent}33, ${C.accent}11)`,
                border: `2px solid ${C.accent}44`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 28, marginBottom: 10,
              }}>
                {(profile?.username || profile?.name || '?')[0].toUpperCase()}
              </div>
              <div style={{ fontSize: 18, fontWeight: 800, color: C.text }}>
                {profile?.name || profile?.username || 'Gym Bro'}
              </div>
              {profile?.username && (
                <div style={{ fontSize: 13, color: C.mute, marginTop: 2 }}>@{profile.username}</div>
              )}
            </div>

            {/* Stats */}
            <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
              <StatCard
                label="Sessions"
                value={sessions.length}
                sub={sessions.length > 0 ? 'logged' : null}
              />
              <StatCard
                label="Top muscle"
                value={topMuscle ? topMuscle.label : '—'}
                sub={topMuscle ? `+${topMuscle.pct}%` : null}
              />
              <StatCard
                label="Lifts tracked"
                value={Object.keys(weights).length}
              />
            </div>

            {/* Muscle improvements */}
            {muscleImprovements.length > 0 && (
              <div style={{
                background: C.surface2, borderRadius: 14,
                border: `1px solid ${C.border}`, padding: '14px 16px', marginBottom: 16,
              }}>
                <div style={{ fontSize: 12, fontWeight: 700, color: C.dim, letterSpacing: '0.06em', marginBottom: 12 }}>
                  MUSCLE PROGRESS
                </div>
                {muscleImprovements.map((mg, i) => (
                  <MuscleBar key={mg.id} label={mg.label} pct={mg.pct} isTop={i === 0} />
                ))}
              </div>
            )}

            {/* Recent sessions */}
            {sessions.length > 0 && (
              <div style={{
                background: C.surface2, borderRadius: 14,
                border: `1px solid ${C.border}`, overflow: 'hidden', marginBottom: 16,
              }}>
                <div style={{
                  padding: '12px 16px 8px',
                  fontSize: 12, fontWeight: 700, color: C.dim, letterSpacing: '0.06em',
                }}>
                  RECENT SESSIONS
                </div>
                {sessions.slice(0, 5).map((s, i) => {
                  const date = new Date(s.date).toLocaleDateString('en-GB', { month: 'short', day: 'numeric' });
                  const exCount = (s.exercises || []).length;
                  return (
                    <div
                      key={s.id || i}
                      style={{
                        display: 'flex', alignItems: 'center', gap: 12,
                        padding: '11px 16px',
                        borderTop: `1px solid ${C.border}`,
                      }}
                    >
                      <div style={{
                        width: 32, height: 32, borderRadius: 8,
                        background: C.surface, flexShrink: 0,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                      }}>
                        <Dumbbell size={14} color={C.mute} />
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{
                          fontSize: 13, fontWeight: 700, color: C.text,
                          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                        }}>
                          {s.name || 'Session'}
                        </div>
                        <div style={{ fontSize: 11, color: C.mute }}>
                          {exCount} exercise{exCount !== 1 ? 's' : ''}
                        </div>
                      </div>
                      <div style={{ fontSize: 12, color: C.mute, flexShrink: 0 }}>{date}</div>
                    </div>
                  );
                })}
              </div>
            )}

            {/* Working weights */}
            {Object.keys(weights).length > 0 && (
              <div style={{
                background: C.surface2, borderRadius: 14,
                border: `1px solid ${C.border}`, overflow: 'hidden',
              }}>
                <div style={{
                  padding: '12px 16px 8px',
                  fontSize: 12, fontWeight: 700, color: C.dim, letterSpacing: '0.06em',
                }}>
                  WORKING WEIGHTS
                </div>
                {Object.entries(weights).slice(0, 8).map(([name, w], i, arr) => (
                  <div
                    key={name}
                    style={{
                      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                      padding: '11px 16px',
                      borderTop: `1px solid ${C.border}`,
                    }}
                  >
                    <div style={{
                      fontSize: 13, color: C.text, fontWeight: 600,
                      flex: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                    }}>
                      {name}
                    </div>
                    <div style={{
                      fontSize: 14, fontWeight: 800, color: C.accent,
                      marginLeft: 12, flexShrink: 0,
                    }}>
                      {w} kg
                    </div>
                  </div>
                ))}
              </div>
            )}

            {!sessions.length && !Object.keys(weights).length && (
              <div style={{ textAlign: 'center', padding: '32px 0', color: C.mute, fontSize: 14 }}>
                No public data yet
              </div>
            )}
          </>
        )}
      </div>
    </motion.div>
  );

  return createPortal(page, document.body);
}
