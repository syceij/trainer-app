/**
 * db.js — Supabase data layer with full diagnostic logging.
 *
 * Every write logs:
 *   [DB ▶] <function> — payload preview
 *   [DB ✓] <function> — success + row count / data
 *   [DB ✗] <function> — full error object  ← thrown so caller can surface it
 *
 * ACTUAL TABLE SCHEMAS (verified):
 *   profiles         id, name, language, created_at
 *   programmes       id, user_id, name, data, active, created_at
 *   sessions         id, user_id, programme_id, name, date, week_number,
 *                    block, completed, data, created_at
 *   sets             id, session_id, user_id, exercise_name, set_number,
 *                    reps (text), weight, rpe, completed, created_at
 *   working_weights  id, user_id, exercise_name, weight, updated_at
 *
 * profiles.id = auth.uid() — all other tables FK into profiles.id via user_id.
 * Always call ensureProfileExists(user) before any write.
 */

import { supabase } from './supabase.js';

// ── tiny logging helpers ──────────────────────────────────────────────────────
const tag  = (fn, icon, msg) => console.log(`[DB ${icon}] ${fn} —`, msg);
const ok   = (fn, d)  => tag(fn, '✓', d);
const fail = (fn, e)  => { console.error(`[DB ✗] ${fn} — FULL ERROR:`, e); };

// ── Profile guard — must run before any FK-constrained write ──────────────────

/**
 * Guarantees a profiles row exists for this user.
 * Called at app startup (loadUserData) so all subsequent writes are safe.
 * Also safe to call redundantly — the SELECT is cheap and the INSERT only fires
 * when the row is genuinely missing.
 */
export async function ensureProfileExists(user) {
  const uid = user.id;
  tag('ensureProfileExists', '▶', `user=${uid}`);

  // profiles PK is "id" (= auth.uid()), NOT "user_id"
  const { data, error } = await supabase
    .from('profiles')
    .select('id')
    .eq('id', uid)
    .maybeSingle();

  if (error) { fail('ensureProfileExists (select)', error); return; }

  if (data) {
    ok('ensureProfileExists', 'row already exists');
    return;
  }

  // Row is missing — create a minimal profile so FK constraints are satisfied.
  // Column names match the actual table: id, name, language (NOT user_id / lang).
  const name = user.user_metadata?.name
    || user.email?.split('@')[0]
    || 'Athlete';

  const { error: insErr } = await supabase
    .from('profiles')
    .insert({ id: uid, name, language: 'en' });

  if (insErr) { fail('ensureProfileExists (insert)', insErr); throw insErr; }
  ok('ensureProfileExists', `created fallback profile — name="${name}"`);
}

// ── Profile ───────────────────────────────────────────────────────────────────

export async function loadProfile(userId) {
  tag('loadProfile', '▶', `user=${userId}`);
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)          // PK column is "id", not "user_id"
    .maybeSingle();
  if (error) { fail('loadProfile', error); return null; }
  ok('loadProfile', data ? `name="${data.name}"` : 'no row');
  return data;
}

export async function upsertProfile(userId, { name, lang, email, username, avatar_url } = {}) {
  // profiles columns: id, name, language, email, username, avatar_url, created_at
  // Only include fields that are explicitly provided so we never accidentally
  // overwrite existing values with undefined/null.
  tag('upsertProfile', '▶', `user=${userId} name="${name}" lang=${lang}`);
  const payload = { id: userId };
  if (name       !== undefined) payload.name       = name;
  if (lang       !== undefined) payload.language   = lang;
  if (email      !== undefined) payload.email      = email;
  if (username   !== undefined) payload.username   = username;
  if (avatar_url !== undefined) payload.avatar_url = avatar_url;
  const { data, error } = await supabase
    .from('profiles')
    .upsert(payload, { onConflict: 'id' })
    .select();
  if (error) { fail('upsertProfile', error); throw error; }
  ok('upsertProfile', data);
  return data;
}

// ── Programme ─────────────────────────────────────────────────────────────────

export async function loadProgramme(userId) {
  tag('loadProgramme', '▶', `user=${userId}`);
  // Use an array query (not .maybeSingle / .single) so duplicate rows — which can
  // accumulate when the upsert onConflict has no backing DB unique constraint —
  // never cause an error.  We take the most-recently-created active row.
  const { data, error } = await supabase
    .from('programmes')
    .select('*')
    .eq('user_id', userId)
    .eq('active', true)
    .order('created_at', { ascending: false })
    .limit(1);
  if (error) { fail('loadProgramme', error); return null; }
  const row = data?.[0] ?? null;
  ok('loadProgramme', row ? `mode="${row.data?.mode || row.name}"` : 'no row');
  return row;
}

export async function saveProgramme(userId, mode, programmeData) {
  tag('saveProgramme', '▶', `user=${userId} mode=${mode}`);
  // programmes table columns: id, user_id, name, data, active, created_at
  // We do a select-then-update/insert instead of a raw upsert because there may
  // be no unique constraint on user_id, meaning upsert would create duplicate rows.
  const { data: existing } = await supabase
    .from('programmes')
    .select('id')
    .eq('user_id', userId)
    .eq('active', true)
    .order('created_at', { ascending: false })
    .limit(1);

  const existingId = existing?.[0]?.id;
  const payload = {
    user_id: userId,
    name:    mode,                        // human-readable label in table editor
    data:    { mode, ...programmeData }, // mode + all content in the jsonb column
    active:  true,
  };

  let result;
  if (existingId) {
    tag('saveProgramme', '▶', `updating existing row id=${existingId}`);
    result = await supabase
      .from('programmes')
      .update(payload)
      .eq('id', existingId)
      .select();
  } else {
    tag('saveProgramme', '▶', 'no existing row — inserting');
    result = await supabase
      .from('programmes')
      .insert(payload)
      .select();
  }

  const { data: saved, error } = result;
  if (error) { fail('saveProgramme', error); throw error; }
  ok('saveProgramme', saved);
  return saved;
}

// ── Sessions ──────────────────────────────────────────────────────────────────

export async function loadSessions(userId) {
  tag('loadSessions', '▶', `user=${userId}`);
  const { data, error } = await supabase
    .from('sessions')
    .select('*')
    .eq('user_id', userId)
    .order('date', { ascending: true });
  if (error) { fail('loadSessions', error); return []; }
  ok('loadSessions', `${data.length} rows`);
  return data || [];
}

export async function insertSession(userId, session) {
  // Use crypto.randomUUID() so the id is always a proper UUID string,
  // regardless of what the sessions.id column type is.
  const id = session.id && typeof session.id === 'string'
    ? session.id
    : crypto.randomUUID();

  const payload = {
    id,
    user_id:      userId,
    programme_id: session.programmeId ?? null,
    name:         session.name,
    date:         session.date,
    week_number:  session.weekNumber ?? null,
    block:        session.block ?? null,
    completed:    true,
    data:         { exercises: session.exercises ?? [] },
  };

  tag('insertSession', '▶', `id=${id} name="${payload.name}" week=${payload.week_number}`);

  const { data, error } = await supabase
    .from('sessions')
    .insert(payload)
    .select();

  if (error) { fail('insertSession', error); throw error; }
  ok('insertSession', data);
  return { ...session, id }; // return session with the final UUID
}

// ── Column-type helpers ───────────────────────────────────────────────────────

/**
 * toText — for TEXT columns (reps, rpe).
 * Range strings like "7-8" or "8-10" are preserved as-is.
 * Numbers are coerced to string.  null / undefined → null.
 */
const toText = (v) => (v != null && v !== '') ? String(v) : null;

/**
 * toNumericWeight — for NUMERIC columns (weight).
 * Returns a finite positive number, or null for anything else
 * ("light", "BW", undefined, NaN, 0, negative).
 * Rows whose weight resolves to null are skipped before insert.
 */
const toNumericWeight = (v) => {
  const n = typeof v === 'number' ? v : parseFloat(v);
  return (Number.isFinite(n) && n > 0) ? n : null;
};

// ── Sets (one row per exercise per session) ───────────────────────────────────

export async function insertSets(userId, sessionId, exercises) {
  if (!exercises?.length) return;

  const rows = exercises.flatMap((ex) => {
    // Skip bodyweight exercises and any exercise whose weight is non-numeric
    // ("light", "BW", undefined, etc.) — weight column is NUMERIC in the DB.
    const w = toNumericWeight(ex.weight);
    if (ex.bodyweight || w == null) return [];

    // create one set row per actual set performed
    // ex.perSetData[si] may carry long-press overrides: { reps, rpe, failed }
    return Array.from({ length: ex.sets || 1 }, (_, si) => {
      const ps = ex.perSetData?.[si]; // per-set override from long-press log (or null)
      return {
        id:            crypto.randomUUID(),
        session_id:    sessionId,
        user_id:       userId,
        exercise_name: ex.name?.trim() || 'Unknown',
        set_number:    si + 1,
        reps:          ps ? toText(ps.reps)  : toText(ex.reps),
        weight:        w,
        rpe:           ps ? toText(ps.rpe)   : toText(ex.rpe),
        failed:        ps ? !!ps.failed      : false,
        completed:     true,
      };
    });
  });

  if (!rows.length) { ok('insertSets', 'no weighted sets to insert'); return; }

  tag('insertSets', '▶', `${rows.length} set rows for session=${sessionId}`);

  const { data, error } = await supabase
    .from('sets')
    .insert(rows)
    .select();

  if (error) { fail('insertSets', error); throw error; }
  ok('insertSets', `${data?.length ?? rows.length} rows inserted`);
  return data;
}

// ── Working weights ───────────────────────────────────────────────────────────

export async function loadWorkingWeights(userId) {
  tag('loadWorkingWeights', '▶', `user=${userId}`);
  const { data, error } = await supabase
    .from('working_weights')
    .select('*')
    .eq('user_id', userId);
  if (error) { fail('loadWorkingWeights', error); return {}; }
  // working_weights column is "exercise_name", not "key"
  // Store both the original-case key AND a lowercase key so callers can
  // look up by any capitalisation without a scan loop.
  const map = {};
  for (const row of data || []) {
    map[row.exercise_name] = row.weight;
    const lc = row.exercise_name?.toLowerCase();
    if (lc && map[lc] == null) map[lc] = row.weight;
  }
  ok('loadWorkingWeights', `${data?.length ?? 0} keys: ${Object.keys(map).join(', ')}`);
  return map;
}

// ── Tracked lifts ─────────────────────────────────────────────────────────────

/**
 * Persist the user's 4 tracked lift slots to profiles.tracked_lifts (jsonb).
 * lifts = array of 4 items: { name, key } | null
 */
export async function saveTrackedLifts(userId, lifts) {
  tag('saveTrackedLifts', '▶', `user=${userId} filled=${lifts.filter(Boolean).length}`);
  const { error } = await supabase
    .from('profiles')
    .update({ tracked_lifts: lifts })
    .eq('id', userId);
  if (error) { fail('saveTrackedLifts', error); throw error; }
  ok('saveTrackedLifts', 'saved');
}

// ── Sets by exercise ──────────────────────────────────────────────────────────

/**
 * Load all set rows for a specific exercise name, ordered oldest-first.
 * Used by the exercise progress page.
 */
export async function loadSetsForExercise(userId, exerciseName) {
  tag('loadSetsForExercise', '▶', `user=${userId} exercise="${exerciseName}"`);
  const { data, error } = await supabase
    .from('sets')
    .select('id, session_id, exercise_name, set_number, reps, weight, rpe, created_at')
    .eq('user_id', userId)
    .ilike('exercise_name', exerciseName)
    .order('created_at', { ascending: true });
  if (error) { fail('loadSetsForExercise', error); return []; }
  ok('loadSetsForExercise', `${data?.length ?? 0} rows`);
  return data || [];
}

/**
 * Load every set row for a user, ordered oldest-first.
 * Used by MusclePage to compute per-muscle stats without
 * making one query per exercise.
 */
export async function loadAllUserSets(userId) {
  tag('loadAllUserSets', '▶', `user=${userId}`);
  const { data, error } = await supabase
    .from('sets')
    .select('id, session_id, exercise_name, set_number, reps, weight, rpe, created_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: true });
  if (error) { fail('loadAllUserSets', error); return []; }
  ok('loadAllUserSets', `${data?.length ?? 0} rows`);
  return data || [];
}

export async function upsertAllWorkingWeights(userId, weights) {
  // working_weights columns: id, user_id, exercise_name, weight, updated_at
  // weight column is NUMERIC — guard with toNumericWeight and skip invalid entries.
  const rows = Object.entries(weights)
    .map(([key, weight]) => ({
      user_id:       userId,
      exercise_name: typeof key === 'string' ? key.trim() : key,
      weight:        toNumericWeight(weight),
    }))
    .filter(r => r.exercise_name && r.weight != null);
  if (!rows.length) return;

  tag('upsertAllWorkingWeights', '▶', `user=${userId} keys=${rows.map(r=>r.exercise_name).join(',')}`);

  const { data, error } = await supabase
    .from('working_weights')
    .upsert(rows, { onConflict: 'user_id,exercise_name' })
    .select();

  if (error) { fail('upsertAllWorkingWeights', error); throw error; }
  ok('upsertAllWorkingWeights', `${data?.length ?? rows.length} rows upserted`);
  return data;
}

// ── Social / Gym Bros ─────────────────────────────────────────────────────────

/** Check whether a username string is available (returns true if free). */
export async function checkUsername(username) {
  const { data } = await supabase
    .from('profiles').select('id').eq('username', username).maybeSingle();
  return !data;
}

/** Write username to the user's profile row. */
export async function setUsername(userId, username) {
  tag('setUsername', '▶', `user=${userId}`);
  const { error } = await supabase
    .from('profiles').update({ username }).eq('id', userId);
  if (error) { fail('setUsername', error); throw error; }
  ok('setUsername', username);
}

/** Update privacy_settings jsonb column on profiles. */
export async function updatePrivacySettings(userId, settings) {
  tag('updatePrivacySettings', '▶', `user=${userId}`);
  const { error } = await supabase
    .from('profiles').update({ privacy_settings: settings }).eq('id', userId);
  if (error) { fail('updatePrivacySettings', error); throw error; }
  ok('updatePrivacySettings', 'saved');
}

/**
 * Load all accepted friends for a user. Returns [{id, name, username}].
 *
 * Uses a single bidirectional OR query so the RLS policy
 *   USING (auth.uid() = user_id OR auth.uid() = friend_id)
 * covers both sides of every friendship row in one round-trip.
 * Previously two separate queries were used; the cross-direction
 * query was blocked by stricter RLS, causing friends to go missing
 * for the request-sender after acceptance.
 */
export async function loadFriends(userId) {
  tag('loadFriends', '▶', `user=${userId}`);
  const { data, error } = await supabase
    .from('friendships')
    .select('user_id, friend_id')
    .or(`user_id.eq.${userId},friend_id.eq.${userId}`)
    .eq('status', 'accepted');
  if (error) { fail('loadFriends', error); return []; }

  // Extract the other person's ID from whichever side is not the current user
  const friendIds = (data || []).map(row =>
    row.user_id === userId ? row.friend_id : row.user_id
  );
  console.log('[loadFriends] rows returned:', data?.length ?? 0, '| friendIds:', friendIds);

  if (!friendIds.length) { ok('loadFriends', '0 friends'); return []; }

  // Also fetch leaderboard_data so the leaderboard can show cached scores
  // without needing to query each friend's private tables.
  const { data: profiles, error: pErr } = await supabase
    .from('profiles').select('id, name, username, leaderboard_data, avatar_url').in('id', friendIds);
  if (pErr) { fail('loadFriends (profiles)', pErr); return []; }
  ok('loadFriends', `${profiles?.length ?? 0} friends`);
  return profiles || [];
}

// ── Leaderboard scoring ───────────────────────────────────────────────────────

/**
 * Calculate a user's leaderboard score from their own Supabase data.
 *
 * Formula: finalScore = round(consistencyScore × 0.7 + improvementScore × 0.3)
 *
 *   consistencyScore (0-100):
 *     sets completed this month / sets programmed (from active programme) × 100, cap 100.
 *     If no programme data → setsProgrammed = setsCompleted × 1.25 (or 20 if zero).
 *
 *   improvementScore (0-100):
 *     average volume improvement % per exercise (volume = reps × weight per set row).
 *     Compares earliest logged set vs most recent logged set for each exercise.
 *     Each exercise contribution capped at 100 before averaging.
 *
 * This always queries live Supabase data for the calling user.
 * Scores for OTHER users are read from their cached profiles.leaderboard_data.
 */
export async function calculateLeaderboardScore(userId) {
  const now = new Date();
  const firstDayOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  firstDayOfMonth.setHours(0, 0, 0, 0);
  const dayOfMonth = now.getDate();
  const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

  // Parse reps field — handles range strings like "8-10" by taking the lower bound
  const parseReps = (reps) => {
    if (typeof reps === 'number') return reps;
    const parts = String(reps || '8').split('-');
    return parseInt(parts[0], 10) || 8;
  };

  const [
    { data: completedSets },
    { data: weights },
    { data: programme },
    { data: allSets },
  ] = await Promise.all([
    // Sets completed this calendar month
    supabase.from('sets')
      .select('id')
      .eq('user_id', userId)
      .eq('completed', true)
      .gte('created_at', firstDayOfMonth.toISOString()),
    // Current working weight per exercise
    supabase.from('working_weights')
      .select('exercise_name, weight')
      .eq('user_id', userId),
    // Active programme for programmed-sets calculation
    supabase.from('programmes')
      .select('data')
      .eq('user_id', userId)
      .eq('active', true)
      .order('created_at', { ascending: false })
      .limit(1),
    // All sets oldest-first for volume improvement calculation
    supabase.from('sets')
      .select('exercise_name, reps, weight')
      .eq('user_id', userId)
      .order('created_at', { ascending: true }),
  ]);

  // ── Consistency ──────────────────────────────────────────────────────────────
  const setsCompleted = completedSets?.length || 0;

  // Derive setsProgrammed from the active programme if available
  let setsProgrammed;
  const progData = programme?.[0]?.data;
  if (progData) {
    // Handle various programme data shapes
    const days = progData.days || progData.sessions || progData.trainingDays || [];
    let setsPerWeek = 0;
    for (const day of days) {
      const exercises = day.exercises || day.workout || day.lifts || [];
      for (const ex of exercises) {
        setsPerWeek += typeof ex.sets === 'number' ? ex.sets : 3;
      }
    }
    const weeksElapsed = Math.max(Math.ceil(dayOfMonth / 7), 1);
    setsProgrammed = setsPerWeek > 0
      ? setsPerWeek * weeksElapsed
      : (setsCompleted > 0 ? Math.round(setsCompleted * 1.25) : 20);
  } else {
    setsProgrammed = setsCompleted > 0 ? Math.round(setsCompleted * 1.25) : 20;
  }

  const consistencyScore = setsProgrammed > 0
    ? (setsCompleted / setsProgrammed) * 100
    : 0;

  // ── Improvement ──────────────────────────────────────────────────────────────
  // Group all historical sets by exercise_name (lowercase) — already oldest-first
  const setsByExercise = {};
  for (const row of (allSets || [])) {
    const key = (row.exercise_name || '').toLowerCase().trim();
    if (!key) continue;
    if (!setsByExercise[key]) setsByExercise[key] = [];
    setsByExercise[key].push(row);
  }

  let totalImprovement = 0;
  let exerciseCount = 0;

  for (const w of (weights || [])) {
    const key = (w.exercise_name || '').toLowerCase().trim();
    const rows = setsByExercise[key];
    if (!rows || rows.length < 2) continue; // need at least two data points

    const firstRow   = rows[0];
    const currentRow = rows[rows.length - 1];

    const firstVolume   = parseReps(firstRow.reps)   * (parseFloat(firstRow.weight)   || 0);
    const currentVolume = parseReps(currentRow.reps) * (parseFloat(currentRow.weight) || 0);

    if (firstVolume > 0) {
      const improvement = ((currentVolume - firstVolume) / firstVolume) * 100;
      totalImprovement += Math.max(improvement, 0); // floor at 0, no ceiling
      exerciseCount++;
    }
  }

  const improvementScore = exerciseCount > 0
    ? totalImprovement / exerciseCount
    : 0;

  // ── Final score ──────────────────────────────────────────────────────────────
  const finalScore = Math.round(
    (consistencyScore * 0.7) + (improvementScore * 0.3)
  );

  return {
    score:          finalScore,
    setsCompleted,
    setsProgrammed,
    improvementPct: Math.round(improvementScore),
    month:          monthKey,   // used by viewers to detect stale month data
    updatedAt:      new Date().toISOString(),
  };
}

/**
 * Calculate this user's leaderboard score and persist it to profiles.leaderboard_data.
 * Call fire-and-forget after each session save so friends always see an up-to-date score.
 *
 * Requires: ALTER TABLE profiles ADD COLUMN IF NOT EXISTS leaderboard_data jsonb;
 */
export async function updateLeaderboardScore(userId) {
  try {
    tag('updateLeaderboardScore', '▶', `user=${userId}`);
    const scoreData = await calculateLeaderboardScore(userId);
    const { error } = await supabase
      .from('profiles')
      .update({ leaderboard_data: scoreData })
      .eq('id', userId);
    if (error) { fail('updateLeaderboardScore (save)', error); return null; }
    ok('updateLeaderboardScore', `score=${scoreData.score} month=${scoreData.month}`);
    return scoreData;
  } catch (e) {
    console.warn('[DB] updateLeaderboardScore failed (non-fatal):', e?.message);
    return null;
  }
}

/**
 * Load incoming pending friend requests (someone wants to add the current user).
 * Only returns rows where friend_id = userId AND status = 'pending'
 * (i.e. requests sent TO me, not requests I sent).
 * Uses the OR filter on the select so the bidirectional RLS policy allows the read.
 */
export async function loadPendingRequests(userId) {
  tag('loadPendingRequests', '▶', `user=${userId}`);
  const { data, error } = await supabase
    .from('friendships')
    .select('id, user_id, friend_id')
    .or(`user_id.eq.${userId},friend_id.eq.${userId}`)
    .eq('status', 'pending');
  if (error) { fail('loadPendingRequests', error); return []; }

  // Keep only INCOMING rows — where the current user is the recipient
  const incoming = (data || []).filter(r => r.friend_id === userId);
  console.log('[loadPendingRequests] total pending rows:', data?.length ?? 0,
    '| incoming to me:', incoming.length);

  const senderIds = incoming.map(r => r.user_id);
  if (!senderIds.length) return [];

  const { data: profiles } = await supabase
    .from('profiles').select('id, name, username').in('id', senderIds);
  const profileMap = Object.fromEntries((profiles || []).map(p => [p.id, p]));

  return incoming.map(r => ({
    friendshipId: r.id,
    userId: r.user_id,
    name: profileMap[r.user_id]?.name     || 'Unknown',
    username: profileMap[r.user_id]?.username || null,
  }));
}

/** Send a friend request (status = pending). */
export async function sendFriendRequest(userId, friendId) {
  tag('sendFriendRequest', '▶', `${userId} → ${friendId}`);
  const { error } = await supabase
    .from('friendships').insert({ user_id: userId, friend_id: friendId, status: 'pending' });
  if (error) { fail('sendFriendRequest', error); throw error; }
  ok('sendFriendRequest', 'sent');
}

/** Accept or decline a friendship row. */
export async function respondFriendRequest(friendshipId, accept) {
  tag('respondFriendRequest', '▶', `id=${friendshipId} accept=${accept}`);
  if (accept) {
    const { error } = await supabase
      .from('friendships').update({ status: 'accepted' }).eq('id', friendshipId);
    if (error) { fail('respondFriendRequest', error); throw error; }
  } else {
    const { error } = await supabase
      .from('friendships').delete().eq('id', friendshipId);
    if (error) { fail('respondFriendRequest', error); throw error; }
  }
  ok('respondFriendRequest', accept ? 'accepted' : 'declined');
}

/** Remove an accepted friend (deletes both directions). */
export async function removeFriend(userId, friendId) {
  await supabase.from('friendships')
    .delete().or(`and(user_id.eq.${userId},friend_id.eq.${friendId}),and(user_id.eq.${friendId},friend_id.eq.${userId})`);
}

/** Generate an 8-char invite code valid for 48 hours. */
export async function createInviteLink(userId) {
  const code = crypto.randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
  const expiresAt = new Date(Date.now() + 48 * 3600 * 1000).toISOString();
  tag('createInviteLink', '▶', `code=${code}`);
  const { data, error } = await supabase
    .from('invite_links').insert({ user_id: userId, code, expires_at: expiresAt }).select().single();
  if (error) { fail('createInviteLink', error); throw error; }
  ok('createInviteLink', `code=${code}`);
  return data;
}

/**
 * Accept an invite link — creates an accepted friendship and marks the link used.
 * Throws 'invalid', 'expired', or 'self' on bad codes.
 */
export async function acceptInvite(code, userId) {
  tag('acceptInvite', '▶', `code=${code}`);
  const { data: inv } = await supabase
    .from('invite_links').select('*').eq('code', code).eq('used', false).maybeSingle();
  if (!inv) throw new Error('invalid');
  if (inv.expires_at && new Date(inv.expires_at) < new Date()) throw new Error('expired');
  if (inv.user_id === userId) throw new Error('self');

  const { error: fErr } = await supabase
    .from('friendships').insert({ user_id: inv.user_id, friend_id: userId, status: 'accepted' });
  // Ignore duplicate-key error (already friends)
  if (fErr && !fErr.code?.startsWith('23')) { fail('acceptInvite (friendship)', fErr); throw fErr; }

  await supabase.from('invite_links').update({ used: true }).eq('id', inv.id);

  const { data: inviter } = await supabase
    .from('profiles').select('name').eq('id', inv.user_id).maybeSingle();
  ok('acceptInvite', `accepted from ${inv.user_id}`);
  return { inviterName: inviter?.name || 'Someone' };
}

/** Search profiles by username prefix (excludes self). */
export async function searchUsers(query, currentUserId) {
  if (!query || query.length < 2) return [];
  const { data, error } = await supabase
    .from('profiles').select('id, name, username')
    .ilike('username', `%${query}%`).neq('id', currentUserId).limit(10);
  if (error) { fail('searchUsers', error); return []; }
  return data || [];
}

/** Insert an activity feed event (fire-and-forget — never throws). */
export async function insertActivity(userId, type, data) {
  const { error } = await supabase.from('activity_feed').insert({ user_id: userId, type, data });
  if (error) console.warn('[DB] insertActivity failed (non-fatal):', error?.message);
}

/**
 * Load the recent activity feed for the user + their friends.
 * Returns rows with an attached `profile` field {name, username}.
 */
export async function loadActivityFeed(userId, friendIds) {
  const ids = [userId, ...friendIds];
  const { data, error } = await supabase
    .from('activity_feed').select('*').in('user_id', ids)
    .order('created_at', { ascending: false }).limit(20);
  if (error) { fail('loadActivityFeed', error); return []; }
  if (!data?.length) return [];
  // Attach profile names
  const { data: profiles } = await supabase
    .from('profiles').select('id, name, username').in('id', ids);
  const pmap = Object.fromEntries((profiles || []).map(p => [p.id, p]));
  return data.map(r => ({ ...r, profile: pmap[r.user_id] || null }));
}

/** Load a friend's public profile (respects privacy_settings). */
export async function loadFriendProfile(friendId) {
  const { data, error } = await supabase
    .from('profiles').select('id, name, username, privacy_settings').eq('id', friendId).maybeSingle();
  if (error) { fail('loadFriendProfile', error); return null; }
  return data;
}

/** Load a friend's recent sessions (last N). */
export async function loadFriendSessions(friendId, limit = 5) {
  const { data, error } = await supabase
    .from('sessions').select('*').eq('user_id', friendId)
    .order('date', { ascending: false }).limit(limit);
  if (error) { fail('loadFriendSessions', error); return []; }
  return (data || []).map(r => ({
    id: r.id, date: r.date, name: r.name,
    exercises: r.data?.exercises || [],
    volume: (r.data?.exercises || []).reduce(
      (s, ex) => (!ex.bodyweight && ex.weight) ? s + ex.weight * (ex.sets || 1) : s, 0
    ),
  }));
}

/** Load a friend's working weights map {exercise_name → weight}. */
export async function loadFriendWeights(friendId) {
  const { data, error } = await supabase
    .from('working_weights').select('exercise_name, weight').eq('user_id', friendId);
  if (error) { fail('loadFriendWeights', error); return {}; }
  return Object.fromEntries((data || []).map(r => [r.exercise_name, r.weight]));
}

// ── Custom exercises ──────────────────────────────────────────────────────────

/**
 * Persist user's custom exercises to profiles.custom_exercises (jsonb array).
 * Each item: { name, key, muscle, category, isCustom, equipment, createdAt }
 */
export async function saveCustomExercises(userId, exercises) {
  tag('saveCustomExercises', '▶', `user=${userId} count=${exercises.length}`);
  const { error } = await supabase
    .from('profiles')
    .update({ custom_exercises: exercises })
    .eq('id', userId);
  if (error) { fail('saveCustomExercises', error); throw error; }
  ok('saveCustomExercises', 'saved');
}
