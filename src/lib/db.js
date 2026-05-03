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

export async function upsertProfile(userId, { name, lang }) {
  // profiles columns: id, name, language, created_at
  // There is NO profile_json column — do not insert it.
  tag('upsertProfile', '▶', `user=${userId} name="${name}" lang=${lang}`);
  const { data, error } = await supabase
    .from('profiles')
    .upsert(
      { id: userId, name, language: lang },
      { onConflict: 'id' }
    )
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
    return Array.from({ length: ex.sets || 1 }, (_, si) => ({
      id:            crypto.randomUUID(),
      session_id:    sessionId,
      user_id:       userId,
      exercise_name: ex.name?.trim() || 'Unknown',
      set_number:    si + 1,
      reps:          toText(ex.reps),   // TEXT column — "8-10", "10", or null
      weight:        w,                  // NUMERIC column — always a finite number
      rpe:           toText(ex.rpe),    // TEXT column — "7-8", "8", or null
      completed:     true,
    }));
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
