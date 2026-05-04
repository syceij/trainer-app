/**
 * muscleUtils.js — shared muscle-group resolution utilities.
 *
 * Used by both ProgressTab (chart bars) and MusclePage (detail page)
 * so name-matching logic is maintained in one place.
 */

import { EXERCISES } from './programme.js';

// ── Muscle group definitions ───────────────────────────────────────────────────

export const MUSCLE_GROUPS = [
  { id: 'chest',     label: 'Chest',     muscles: ['chest'] },
  { id: 'back',      label: 'Back',      muscles: ['back'] },
  { id: 'shoulders', label: 'Shoulders', muscles: ['shoulders'] },
  { id: 'arms',      label: 'Arms',      muscles: ['biceps', 'triceps'] },
  { id: 'legs',      label: 'Legs',      muscles: ['quads', 'hamstrings', 'glutes', 'calves'] },
  { id: 'core',      label: 'Core',      muscles: ['core'] },
];

export function getMuscleGroup(id) {
  return MUSCLE_GROUPS.find(mg => mg.id === id) || null;
}

// ── Lookup tables built from the EXERCISES library ────────────────────────────

const _keyToMuscle  = Object.fromEntries(EXERCISES.map(e => [e.key, e.muscle]));
const _nameToMuscle = Object.fromEntries(EXERCISES.map(e => [e.name.toLowerCase(), e.muscle]));

// Manual alias map — maps known sets-table names to the nearest library name
const EXERCISE_NAME_MAP = {
  'deadlift':                    'deadlift',
  'incline db press':            'incline db press',
  'cable row':                   'cable row',
  'lat pulldown (neutral grip)': 'lat pulldown',
  'lateral raise (db)':          'lateral raise',
  'skull crusher':               'tricep pushdown',
  'skull crushers':              'tricep pushdown',
  'tricep pushdown (cable)':     'tricep pushdown',
  'hammer curl':                 'hammer curl',
  'cable fly':                   'cable fly',
  'cable crunch':                'cable crunch',
  'barbell bench press':         'barbell bench press',
};

// Direct muscle assignments for names not in the EXERCISES library at all
const MANUAL_MUSCLE_MAP = {
  'skull crusher':               'triceps',
  'skull crushers':              'triceps',
  'cable crunch':                'core',
  'lat pulldown (neutral grip)': 'back',
  'lateral raise (db)':          'shoulders',
  'tricep pushdown (cable)':     'triceps',
  'hammer curl':                 'biceps',
};

// ── Resolution function ───────────────────────────────────────────────────────

/**
 * Resolve muscle group value for an exercise object { name, key, muscle }.
 * Falls back through 7 strategies before giving up.
 */
export function resolveMuscle(ex) {
  // 1. Muscle already on the object (auto-programme exercises)
  if (ex.muscle) return ex.muscle;

  // 2. Key-based exact lookup
  if (ex.key && _keyToMuscle[ex.key]) return _keyToMuscle[ex.key];

  if (!ex.name) return null;
  const nameLc = ex.name.toLowerCase().trim();

  // 3. Direct manual map (known mismatches)
  if (MANUAL_MUSCLE_MAP[nameLc]) return MANUAL_MUSCLE_MAP[nameLc];

  // 4. Alias normalisation then exact library lookup
  const normalised = EXERCISE_NAME_MAP[nameLc] || nameLc;
  if (_nameToMuscle[normalised]) return _nameToMuscle[normalised];

  // 5. Case-insensitive exact library lookup
  if (_nameToMuscle[nameLc]) return _nameToMuscle[nameLc];

  // 6. Partial — library name contains the exercise's first word
  const firstWord = nameLc.split(' ')[0];
  for (const [libName, muscle] of Object.entries(_nameToMuscle)) {
    if (libName.includes(firstWord)) return muscle;
  }

  // 7. Reverse partial — exercise name contains the library entry's first word
  for (const [libName, muscle] of Object.entries(_nameToMuscle)) {
    if (nameLc.includes(libName.split(' ')[0])) return muscle;
  }

  console.log('[MuscleUtils] No muscle category found for:', ex.name);
  return null;
}

/** Convenience wrapper for sets-table rows that only have an exercise_name string. */
export function resolveMuscleFromName(exerciseName) {
  return resolveMuscle({ name: exerciseName });
}
