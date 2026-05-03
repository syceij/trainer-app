/**
 * importHelpers.js
 *
 * All utilities for importing and running imported programmes.
 *
 * CANONICAL NAME RULE
 * ───────────────────
 * The EXERCISES array in programme.js is the single source of truth for
 * exercise names.  Every name that enters the app through an import must
 * be normalised to the canonical library name before it is stored or used.
 *
 * normalizeToCanonical(rawName)  ← apply to EVERY exercise.name coming from
 *   imported JSON before writing it to React state or the database.
 */

import { EXERCISES } from './programme.js';

// ─── Canonical name lookup ────────────────────────────────────────────────────

/** Lowercase name → canonical name for every exercise in the library. */
const CANON_BY_LOWER = new Map(EXERCISES.map(e => [e.name.toLowerCase(), e.name]));

/** EXERCISES keyed by key field for fast reverse-lookup. */
const EX_BY_KEY = Object.fromEntries(EXERCISES.map(e => [e.key, e]));

/**
 * ALIASES  ─  lowercase raw name → canonical library name
 *
 * Covers common AI-generated variants that are semantically the same
 * exercise but spelt differently from the library.
 * DO NOT add ambiguous single-word aliases like "squat" or "row" here;
 * those could map to the wrong exercise.
 */
const ALIASES = {
  // ── Deadlift ───────────────────────────────────────────────────────────────
  'conventional deadlift':      'Deadlift',
  'barbell deadlift':           'Deadlift',
  'conventional dl':            'Deadlift',
  'barbell dl':                 'Deadlift',
  'conv deadlift':              'Deadlift',

  // ── Overhead Press ─────────────────────────────────────────────────────────
  'ohp':                        'Overhead Press',
  'barbell ohp':                'Overhead Press',
  'military press':             'Overhead Press',
  'barbell overhead press':     'Overhead Press',
  'standing overhead press':    'Overhead Press',
  'standing ohp':               'Overhead Press',
  'press':                      'Overhead Press',  // only valid when unambiguous

  // ── Lat Pulldown ───────────────────────────────────────────────────────────
  'lat pulldown (bar)':         'Lat Pulldown',
  'lat pulldown (cable)':       'Lat Pulldown',
  'lat pulldown bar':           'Lat Pulldown',
  'lat pull-down':              'Lat Pulldown',
  'lat pull down':              'Lat Pulldown',
  'wide grip lat pulldown':     'Lat Pulldown',
  'wide-grip lat pulldown':     'Lat Pulldown',
  'cable pulldown':             'Lat Pulldown',
  'pulldown':                   'Lat Pulldown',

  // ── Barbell Bench Press ────────────────────────────────────────────────────
  'bench press':                'Barbell Bench Press',
  'flat bench press':           'Barbell Bench Press',
  'flat bench':                 'Barbell Bench Press',
  'barbell bench':              'Barbell Bench Press',
  'bb bench press':             'Barbell Bench Press',

  // ── Back Squat ─────────────────────────────────────────────────────────────
  'barbell squat':              'Back Squat',
  'bb squat':                   'Back Squat',
  'barbell back squat':         'Back Squat',

  // ── Barbell Row ────────────────────────────────────────────────────────────
  'bent over row':              'Barbell Row',
  'bent-over row':              'Barbell Row',
  'bent over barbell row':      'Barbell Row',
  'barbell bent over row':      'Barbell Row',
  'bb row':                     'Barbell Row',
  'bent-over barbell row':      'Barbell Row',
  'barbell bentover row':       'Barbell Row',

  // ── Romanian Deadlift ──────────────────────────────────────────────────────
  'rdl':                        'Romanian Deadlift',
  'romanian dl':                'Romanian Deadlift',
  'barbell rdl':                'Romanian Deadlift',

  // ── Pull-Up / Chin-Up (plural forms) ──────────────────────────────────────
  'pull-ups':                   'Pull-Up',
  'pullups':                    'Pull-Up',
  'pull ups':                   'Pull-Up',
  'chin-ups':                   'Chin-Up',
  'chinups':                    'Chin-Up',
  'chin ups':                   'Chin-Up',

  // ── Push-Up (plural form) ─────────────────────────────────────────────────
  'push-ups':                   'Push-Up',
  'pushups':                    'Push-Up',
  'push ups':                   'Push-Up',

  // ── Close-Grip Bench Press ────────────────────────────────────────────────
  'close grip bench press':     'Close-Grip Bench Press',
  'cgbp':                       'Close-Grip Bench Press',
  'close grip bench':           'Close-Grip Bench Press',

  // ── Incline Barbell Press ─────────────────────────────────────────────────
  'incline bench press':        'Incline Barbell Press',
  'incline barbell bench press':'Incline Barbell Press',
  'incline bp':                 'Incline Barbell Press',

  // ── Incline DB Press ──────────────────────────────────────────────────────
  'incline dumbbell press':     'Incline DB Press',
  'dumbbell incline press':     'Incline DB Press',
  'incline db bench press':     'Incline DB Press',

  // ── Dumbbell Bench Press ──────────────────────────────────────────────────
  'dumbbell bench press':       'Dumbbell Bench Press',
  'db bench press':             'Dumbbell Bench Press',

  // ── Dumbbell Fly ──────────────────────────────────────────────────────────
  'dumbbell fly':               'Dumbbell Fly',
  'db fly':                     'Dumbbell Fly',
  'dumbbell flyes':             'Dumbbell Fly',
  'dumbbell flies':             'Dumbbell Fly',

  // ── Chest Dip ─────────────────────────────────────────────────────────────
  'dips':                       'Chest Dip',
  'chest dips':                 'Chest Dip',
  'weighted dips':              'Chest Dip',

  // ── Pec Deck ──────────────────────────────────────────────────────────────
  'pec fly machine':            'Pec Deck',
  'butterfly machine':          'Pec Deck',
  'pec fly':                    'Pec Deck',

  // ── DB Shoulder Press ─────────────────────────────────────────────────────
  'dumbbell shoulder press':    'DB Shoulder Press',
  'dumbbell ohp':               'DB Shoulder Press',
  'db ohp':                     'DB Shoulder Press',
  'dumbbell overhead press':    'DB Shoulder Press',
  'seated db press':            'DB Shoulder Press',

  // ── Lateral Raise ─────────────────────────────────────────────────────────
  'lateral raises':             'Lateral Raise',
  'side raises':                'Lateral Raise',
  'db lateral raise':           'Lateral Raise',

  // ── Front Raise ───────────────────────────────────────────────────────────
  'front raises':               'Front Raise',
  'db front raise':             'Front Raise',

  // ── Cable Lateral Raise ───────────────────────────────────────────────────
  'cable lateral raises':       'Cable Lateral Raise',
  'cable side raise':           'Cable Lateral Raise',

  // ── Rear Delt Fly ─────────────────────────────────────────────────────────
  'rear delt flyes':            'Rear Delt Fly',
  'rear delt flys':             'Rear Delt Fly',
  'rear delt flies':            'Rear Delt Fly',
  'reverse fly':                'Rear Delt Fly',
  'reverse dumbbell fly':       'Rear Delt Fly',

  // ── Face Pull ─────────────────────────────────────────────────────────────
  'face pulls':                 'Face Pull',
  'cable face pull':            'Face Pull',

  // ── Cable Row ─────────────────────────────────────────────────────────────
  'seated cable row':           'Cable Row',
  'cable row (seated)':         'Cable Row',

  // ── Dumbbell Row ─────────────────────────────────────────────────────────
  'dumbbell row':               'Dumbbell Row',
  'db row':                     'Dumbbell Row',
  'single arm row':             'Dumbbell Row',
  'one arm dumbbell row':       'Dumbbell Row',

  // ── Inverted Row ─────────────────────────────────────────────────────────
  'inverted rows':              'Inverted Row',

  // ── Hip Thrust ────────────────────────────────────────────────────────────
  'barbell hip thrust':         'Hip Thrust',
  'bb hip thrust':              'Hip Thrust',
  'hip thrusts':                'Hip Thrust',

  // ── Standing Calf Raise ───────────────────────────────────────────────────
  'calf raise':                 'Standing Calf Raise',
  'calf raises':                'Standing Calf Raise',
  'standing calf raises':       'Standing Calf Raise',

  // ── Seated Calf Raise ─────────────────────────────────────────────────────
  'seated calf raises':         'Seated Calf Raise',

  // ── Glute Bridge ─────────────────────────────────────────────────────────
  'glute bridges':              'Glute Bridge',

  // ── Sumo Deadlift ─────────────────────────────────────────────────────────
  'sumo deadlifts':             'Sumo Deadlift',
  'sumo dl':                    'Sumo Deadlift',

  // ── Front Squat ───────────────────────────────────────────────────────────
  'front squats':               'Front Squat',
  'barbell front squat':        'Front Squat',

  // ── DB Lunge ─────────────────────────────────────────────────────────────
  'dumbbell lunge':             'DB Lunge',
  'db lunges':                  'DB Lunge',
  'dumbbell lunges':            'DB Lunge',

  // ── DB Romanian Deadlift ─────────────────────────────────────────────────
  'dumbbell rdl':               'DB Romanian Deadlift',
  'dumbbell romanian deadlift': 'DB Romanian Deadlift',
  'db rdl':                     'DB Romanian Deadlift',

  // ── Leg Curl ─────────────────────────────────────────────────────────────
  'leg curls':                  'Leg Curl',
  'hamstring curl':             'Leg Curl',
  'lying leg curl':             'Leg Curl',

  // ── Leg Extension ─────────────────────────────────────────────────────────
  'leg extensions':             'Leg Extension',
  'quad extension':             'Leg Extension',

  // ── Barbell Curl ─────────────────────────────────────────────────────────
  'barbell curls':              'Barbell Curl',
  'bb curl':                    'Barbell Curl',
  'ez bar curl':                'Barbell Curl',

  // ── DB Curl ──────────────────────────────────────────────────────────────
  'dumbbell curl':              'DB Curl',
  'dumbbell curls':             'DB Curl',
  'db bicep curl':              'DB Curl',
  'dumbbell bicep curl':        'DB Curl',

  // ── Hammer Curl ───────────────────────────────────────────────────────────
  'hammer curls':               'Hammer Curl',
  'db hammer curl':             'Hammer Curl',

  // ── Cable Curl ────────────────────────────────────────────────────────────
  'cable curls':                'Cable Curl',

  // ── Preacher Curl ─────────────────────────────────────────────────────────
  'preacher curls':             'Preacher Curl',

  // ── Tricep Pushdown ───────────────────────────────────────────────────────
  'triceps pushdown':           'Tricep Pushdown',
  'cable tricep pushdown':      'Tricep Pushdown',
  'tricep pulldown':            'Tricep Pushdown',
  'cable pushdown':             'Tricep Pushdown',

  // ── Overhead Tricep Ext ───────────────────────────────────────────────────
  'overhead tricep extension':  'Overhead Tricep Ext',
  'overhead triceps extension': 'Overhead Tricep Ext',
  'db overhead tricep':         'Overhead Tricep Ext',
  'overhead extension':         'Overhead Tricep Ext',

  // ── Skull Crusher ─────────────────────────────────────────────────────────
  'skull crushers':             'Skull Crusher',
  'lying tricep extension':     'Skull Crusher',
  'ez bar skull crusher':       'Skull Crusher',

  // ── Bench Dip ────────────────────────────────────────────────────────────
  'bench dips':                 'Bench Dip',
  'tricep bench dip':           'Bench Dip',

  // ── Ab Wheel ─────────────────────────────────────────────────────────────
  'ab wheel rollout':           'Ab Wheel',
  'ab rollout':                 'Ab Wheel',
  'wheel rollout':              'Ab Wheel',

  // ── Hanging Leg Raise ─────────────────────────────────────────────────────
  'hanging leg raises':         'Hanging Leg Raise',
  'hanging knee raise':         'Hanging Leg Raise',
  'hanging knee raises':        'Hanging Leg Raise',

  // ── Cable Crunch ─────────────────────────────────────────────────────────
  'cable crunches':             'Cable Crunch',

  // ── Plank ────────────────────────────────────────────────────────────────
  'planks':                     'Plank',

  // ── Bodyweight Squat / Jump Squat ─────────────────────────────────────────
  'bodyweight squats':          'Bodyweight Squat',
  'bw squat':                   'Bodyweight Squat',
  'jump squats':                'Jump Squat',

  // ── Short-key aliases (from old workingWeights schema) ───────────────────
  // These cover the "bench/squat/ohp/row" keys emitted by older AI imports
  // and must map to the canonical programme.js name.
  'bench':                      'Barbell Bench Press',
  'squat':                      'Back Squat',
  'ohp':                        'Overhead Press',
  'row':                        'Barbell Row',
  // 'deadlift' is already in the library as-is; the Map handles it.
};

/**
 * normalizeToCanonical(rawName)
 *
 * Maps any exercise name string to the canonical library name from EXERCISES.
 * Resolution order:
 *   1. Case-insensitive exact match against the library  →  use canonical
 *   2. Alias table lookup                                →  use canonical
 *   3. No match                                          →  return trimmed original
 *
 * Export this function so App.jsx can use it for workingWeights key normalisation.
 */
export function normalizeToCanonical(rawName) {
  if (!rawName || typeof rawName !== 'string') return rawName ?? null;
  const trimmed = rawName.trim();
  const lower   = trimmed.toLowerCase();
  // 1. Exact case-insensitive match against EXERCISES library
  if (CANON_BY_LOWER.has(lower)) return CANON_BY_LOWER.get(lower);
  // 2. Alias table
  if (ALIASES[lower] != null) return ALIASES[lower];
  // 3. Return trimmed original unchanged
  return trimmed;
}

// ─── Import prompt template ───────────────────────────────────────────────────

export const PROMPT_TEMPLATE = `Convert my training programme to this JSON format. Output ONLY the JSON, no explanation.

Schema:
{
  "name": "string",
  "description": "string (optional)",
  "totalWeeks": number,
  "profileSeed": { "name": string, "days": number, "goal": string, "experience": string },
  "workingWeights": { "Barbell Bench Press": kg, "Back Squat": kg, "Deadlift": kg, "Overhead Press": kg, "Barbell Row": kg },
  "weeks": [
    {
      "weekNumber": 1,
      "label": "string (optional)",
      "sessions": [
        {
          "day": "mon|tue|wed|thu|fri|sat|sun",
          "name": "string",
          "focus": "string (optional)",
          "exercises": [
            {
              "name": "string — use exact name from canonical list below",
              "tag": "compound|accessory (optional)",
              "sets": number,
              "reps": "string e.g. 8-10",
              "weight": "number in kg OR BW OR light",
              "rpe": "string e.g. 7-8 (optional)",
              "notes": "string (optional)",
              "bodyweight": true (optional)
            }
          ]
        },
        { "day": "tue", "isRest": true }
      ]
    }
  ]
}

Rules:
- Lowercase day names, weights in kg, rest days as isRest: true.
- For exercise names use EXACT spelling from this canonical list when the exercise matches.
  Any exercise not on this list may keep its original name.

Canonical exercise names:
Barbell Bench Press | Incline Barbell Press | Close-Grip Bench Press | Dumbbell Bench Press | Incline DB Press | Dumbbell Fly | Cable Fly | Chest Press Machine | Pec Deck | Push-Up | Chest Dip
Deadlift | Barbell Row | Romanian Deadlift | Dumbbell Row | Lat Pulldown | Cable Row | Face Pull | Machine Row | Pull-Up | Chin-Up | Inverted Row
Overhead Press | DB Shoulder Press | Lateral Raise | Front Raise | Cable Lateral Raise | Machine Shoulder Press | Rear Delt Fly
Back Squat | Front Squat | Sumo Deadlift | DB Lunge | DB Romanian Deadlift | Leg Press | Leg Curl | Leg Extension | Hip Thrust | Glute Bridge | Standing Calf Raise | Seated Calf Raise | Bodyweight Squat | Jump Squat
Barbell Curl | DB Curl | Hammer Curl | Cable Curl | Preacher Curl | Tricep Pushdown | Overhead Tricep Ext | Skull Crusher | Bench Dip
Plank | Ab Wheel | Cable Crunch | Hanging Leg Raise

My programme: [paste here]`;

// ─── Sample programme ─────────────────────────────────────────────────────────

export const SAMPLE_PROGRAMME = {
  name: "Sample — 5-day PPL",
  totalWeeks: 1,
  weeks: [
    {
      weekNumber: 1,
      label: "Week 1 — Calibration",
      sessions: [
        {
          day: "mon",
          name: "Push A",
          focus: "Chest focus",
          exercises: [
            { name: "Barbell Bench Press", tag: "compound", sets: 4, reps: "8-10", weight: 60, rpe: "7-8", notes: "Calibrate week 1" },
            { name: "Incline DB Press", tag: "compound", sets: 3, reps: "10-12", weight: 22, rpe: "7-8" },
            { name: "Cable Fly", tag: "accessory", sets: 3, reps: "12-15", weight: "light", rpe: "7", notes: "Full stretch at bottom" },
            { name: "Lateral Raise", tag: "accessory", sets: 4, reps: "12-15", weight: 5, rpe: "7" },
            { name: "Tricep Pushdown", tag: "accessory", sets: 3, reps: "12-15", weight: 25, rpe: "7" },
          ],
        },
        { day: "tue", isRest: true },
        {
          day: "wed",
          name: "Pull A",
          focus: "Back + Biceps",
          exercises: [
            { name: "Pull-Up", tag: "compound", sets: 4, reps: "6-10", weight: "BW", rpe: "7-8", bodyweight: true },
            { name: "Barbell Row", tag: "compound", sets: 3, reps: "8-10", weight: 65, rpe: "7-8" },
            { name: "Lat Pulldown", tag: "accessory", sets: 3, reps: "10-12", weight: 50, rpe: "7-8" },
            { name: "Face Pull", tag: "accessory", sets: 3, reps: "12-15", weight: 20, rpe: "7" },
            { name: "DB Curl", tag: "accessory", sets: 3, reps: "10-12", weight: 12, rpe: "7" },
          ],
        },
        {
          day: "thu",
          name: "Legs",
          focus: "Squat + Hinge",
          exercises: [
            { name: "Back Squat", tag: "compound", sets: 4, reps: "6-8", weight: 100, rpe: "7-8" },
            { name: "Romanian Deadlift", tag: "compound", sets: 3, reps: "8-10", weight: 80, rpe: "7-8" },
            { name: "Leg Press", tag: "accessory", sets: 3, reps: "12-15", weight: 140, rpe: "7-8" },
            { name: "Leg Curl", tag: "accessory", sets: 3, reps: "10-12", weight: 35, rpe: "7" },
            { name: "Standing Calf Raise", tag: "accessory", sets: 4, reps: "12-15", weight: 60, rpe: "7" },
          ],
        },
        {
          day: "fri",
          name: "Push B",
          focus: "Shoulder focus",
          exercises: [
            { name: "Overhead Press", tag: "compound", sets: 4, reps: "6-8", weight: 45, rpe: "7-8" },
            { name: "Incline DB Press", tag: "compound", sets: 3, reps: "10-12", weight: 22, rpe: "7-8" },
            { name: "Lateral Raise", tag: "accessory", sets: 4, reps: "12-15", weight: 5, rpe: "7" },
            { name: "Cable Fly", tag: "accessory", sets: 3, reps: "12-15", weight: "light", rpe: "7" },
            { name: "Overhead Tricep Ext", tag: "accessory", sets: 3, reps: "10-12", weight: 12, rpe: "7" },
          ],
        },
        {
          day: "sat",
          name: "Pull B",
          focus: "Back + Arms",
          exercises: [
            { name: "Cable Row", tag: "compound", sets: 4, reps: "8-10", weight: 60, rpe: "7-8" },
            { name: "Lat Pulldown", tag: "accessory", sets: 3, reps: "10-12", weight: 50, rpe: "7-8" },
            { name: "Hammer Curl", tag: "accessory", sets: 4, reps: "10-12", weight: 12, rpe: "7" },
            { name: "Tricep Pushdown", tag: "accessory", sets: 4, reps: "12-15", weight: 25, rpe: "7" },
            { name: "Face Pull", tag: "accessory", sets: 3, reps: "15-20", weight: 18, rpe: "7" },
          ],
        },
        { day: "sun", isRest: true },
      ],
    },
  ],
};

// ─── Validation ───────────────────────────────────────────────────────────────

export function validateImported(data) {
  const errors = [];
  if (!data || typeof data !== 'object') { errors.push('Invalid JSON object'); return errors; }
  if (!data.name || typeof data.name !== 'string') errors.push('Missing or invalid "name" field');
  if (!Array.isArray(data.weeks) || data.weeks.length === 0) {
    errors.push('Missing or empty "weeks" array');
    return errors;
  }
  data.weeks.forEach((week, wi) => {
    if (typeof week.weekNumber !== 'number') errors.push(`Week ${wi + 1}: missing weekNumber`);
    if (!Array.isArray(week.sessions) || week.sessions.length === 0) {
      errors.push(`Week ${wi + 1}: missing sessions array`);
      return;
    }
    week.sessions.forEach((session, si) => {
      if (session.isRest) return;
      if (!session.name) errors.push(`Week ${wi + 1}, session ${si + 1}: missing name`);
      if (!Array.isArray(session.exercises) || session.exercises.length === 0) {
        errors.push(`Week ${wi + 1}, session ${si + 1}: missing exercises`);
        return;
      }
      session.exercises.forEach((ex, ei) => {
        if (!ex.name) errors.push(`Week ${wi + 1}, session ${si + 1}, ex ${ei + 1}: missing name`);
        if (typeof ex.sets !== 'number') errors.push(`Week ${wi + 1}, session ${si + 1}, ex ${ei + 1}: sets must be a number`);
        if (!ex.reps) errors.push(`Week ${wi + 1}, session ${si + 1}, ex ${ei + 1}: missing reps`);
      });
    });
  });
  return errors;
}

// ─── Runtime session builder ──────────────────────────────────────────────────

/**
 * importedSessionToRuntime(session)
 *
 * Converts a raw JSON session (as stored in the DB) into the runtime format
 * used by TodayTab / finishSession.
 *
 * Exercise names are normalised via normalizeToCanonical so that all writes
 * to the `sets` and `working_weights` tables use canonical library names,
 * regardless of what the original JSON contained.
 *
 * The `key` field is resolved to the matching EXERCISES.key when possible;
 * otherwise it falls back to a stable slug derived from the canonical name.
 */
export function importedSessionToRuntime(session) {
  if (!session || session.isRest) return null;
  return {
    name:      session.name  || 'Session',
    focus:     session.focus || '',
    block:     session.block || '',
    notes:     session.notes || '',
    exercises: (session.exercises || []).map((ex, i) => {
      const canonicalName = normalizeToCanonical(ex.name);
      // Resolve library key if the name mapped to a known exercise
      const libEx = EXERCISES.find(e => e.name === canonicalName);
      return {
        key:         libEx?.key ?? `imported_${i}_${canonicalName.replace(/\s+/g, '_').toLowerCase()}`,
        name:        canonicalName,
        sets:        ex.sets   || 3,
        reps:        String(ex.reps || '8-12'),
        weight:      typeof ex.weight === 'number' ? ex.weight : 0,
        weightLabel: ex.weight === 'BW'    ? 'BW'
                   : ex.weight === 'light' ? 'light'
                   : undefined,
        rpe:         ex.rpe   || '7-8',
        tag:         ex.tag   || 'accessory',
        bodyweight:  !!ex.bodyweight,
        notes:       ex.notes || '',
        readyToProgress: false,
      };
    }),
  };
}

// ─── Week/session helpers ─────────────────────────────────────────────────────

const DAY_ORDER = ['mon','tue','wed','thu','fri','sat','sun'];

export function sessionForTodayImported(imported, weekNum) {
  if (!imported || !imported.weeks) return null;
  const week = imported.weeks.find(w => w.weekNumber === weekNum) || imported.weeks[0];
  if (!week) return null;
  const today   = new Date().getDay();
  const dayName = ['sun','mon','tue','wed','thu','fri','sat'][today];
  const session = week.sessions.find(s => s.day === dayName && !s.isRest);
  if (!session) return null;
  return importedSessionToRuntime(session);
}

export function getWeekSessions(imported, weekNum) {
  if (!imported?.weeks) return [];
  const week = imported.weeks.find(w => w.weekNumber === weekNum) || imported.weeks[0];
  if (!week) return [];
  return DAY_ORDER.map(day => {
    const s = week.sessions.find(ss => ss.day === day);
    return s ? { ...s, day } : { day, isRest: true };
  });
}
