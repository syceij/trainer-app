// Exercise library: 50+ entries
export const EXERCISES = [
  // Chest - barbell
  { key: 'bench_press', name: 'Barbell Bench Press', muscle: 'chest', equipment: 'barbell', isMain: true },
  { key: 'incline_bench', name: 'Incline Barbell Press', muscle: 'chest', equipment: 'barbell' },
  { key: 'close_grip_bench', name: 'Close-Grip Bench Press', muscle: 'triceps', equipment: 'barbell' },
  // Chest - dumbbell
  { key: 'db_press', name: 'Dumbbell Bench Press', muscle: 'chest', equipment: 'dumbbell' },
  { key: 'incline_db_press', name: 'Incline DB Press', muscle: 'chest', equipment: 'dumbbell' },
  { key: 'db_fly', name: 'Dumbbell Fly', muscle: 'chest', equipment: 'dumbbell' },
  // Chest - cable/machine
  { key: 'cable_fly', name: 'Cable Fly', muscle: 'chest', equipment: 'cable' },
  { key: 'chest_press_machine', name: 'Chest Press Machine', muscle: 'chest', equipment: 'machine' },
  { key: 'pec_deck', name: 'Pec Deck', muscle: 'chest', equipment: 'machine' },
  // Chest - bodyweight
  { key: 'pushup', name: 'Push-Up', muscle: 'chest', equipment: 'bodyweight', bodyweight: true },
  { key: 'dip', name: 'Chest Dip', muscle: 'chest', equipment: 'bodyweight', bodyweight: true },

  // Back - barbell
  { key: 'deadlift', name: 'Deadlift', muscle: 'back', equipment: 'barbell', isMain: true },
  { key: 'barbell_row', name: 'Barbell Row', muscle: 'back', equipment: 'barbell', isMain: true },
  { key: 'rdl', name: 'Romanian Deadlift', muscle: 'hamstrings', equipment: 'barbell' },
  // Back - dumbbell
  { key: 'db_row', name: 'Dumbbell Row', muscle: 'back', equipment: 'dumbbell' },
  // Back - cable/machine
  { key: 'lat_pulldown', name: 'Lat Pulldown', muscle: 'back', equipment: 'machine' },
  { key: 'cable_row', name: 'Cable Row', muscle: 'back', equipment: 'cable' },
  { key: 'face_pull', name: 'Face Pull', muscle: 'back', equipment: 'cable' },
  { key: 'machine_row', name: 'Machine Row', muscle: 'back', equipment: 'machine' },
  // Back - bodyweight
  { key: 'pullup', name: 'Pull-Up', muscle: 'back', equipment: 'bodyweight', bodyweight: true },
  { key: 'chinup', name: 'Chin-Up', muscle: 'back', equipment: 'bodyweight', bodyweight: true },
  { key: 'inverted_row', name: 'Inverted Row', muscle: 'back', equipment: 'bodyweight', bodyweight: true },

  // Shoulders
  { key: 'ohp', name: 'Overhead Press', muscle: 'shoulders', equipment: 'barbell', isMain: true },
  { key: 'db_ohp', name: 'DB Shoulder Press', muscle: 'shoulders', equipment: 'dumbbell' },
  { key: 'lateral_raise', name: 'Lateral Raise', muscle: 'shoulders', equipment: 'dumbbell' },
  { key: 'front_raise', name: 'Front Raise', muscle: 'shoulders', equipment: 'dumbbell' },
  { key: 'cable_lateral', name: 'Cable Lateral Raise', muscle: 'shoulders', equipment: 'cable' },
  { key: 'machine_shoulder', name: 'Machine Shoulder Press', muscle: 'shoulders', equipment: 'machine' },
  { key: 'rear_delt_fly', name: 'Rear Delt Fly', muscle: 'shoulders', equipment: 'dumbbell' },

  // Legs - barbell
  { key: 'squat', name: 'Back Squat', muscle: 'quads', equipment: 'barbell', isMain: true },
  { key: 'front_squat', name: 'Front Squat', muscle: 'quads', equipment: 'barbell' },
  { key: 'sumo_deadlift', name: 'Sumo Deadlift', muscle: 'hamstrings', equipment: 'barbell' },
  // Legs - dumbbell
  { key: 'db_lunge', name: 'DB Lunge', muscle: 'quads', equipment: 'dumbbell' },
  { key: 'db_rdl', name: 'DB Romanian Deadlift', muscle: 'hamstrings', equipment: 'dumbbell' },
  // Legs - machine
  { key: 'leg_press', name: 'Leg Press', muscle: 'quads', equipment: 'machine' },
  { key: 'leg_curl', name: 'Leg Curl', muscle: 'hamstrings', equipment: 'machine' },
  { key: 'leg_ext', name: 'Leg Extension', muscle: 'quads', equipment: 'machine' },
  { key: 'hip_thrust', name: 'Hip Thrust', muscle: 'glutes', equipment: 'barbell' },
  { key: 'glute_bridge', name: 'Glute Bridge', muscle: 'glutes', equipment: 'bodyweight', bodyweight: true },
  { key: 'calf_raise', name: 'Standing Calf Raise', muscle: 'calves', equipment: 'machine' },
  { key: 'seated_calf', name: 'Seated Calf Raise', muscle: 'calves', equipment: 'machine' },
  // Legs - bodyweight
  { key: 'bodyweight_squat', name: 'Bodyweight Squat', muscle: 'quads', equipment: 'bodyweight', bodyweight: true },
  { key: 'jump_squat', name: 'Jump Squat', muscle: 'quads', equipment: 'bodyweight', bodyweight: true },

  // Arms
  { key: 'barbell_curl', name: 'Barbell Curl', muscle: 'biceps', equipment: 'barbell' },
  { key: 'db_curl', name: 'DB Curl', muscle: 'biceps', equipment: 'dumbbell' },
  { key: 'hammer_curl', name: 'Hammer Curl', muscle: 'biceps', equipment: 'dumbbell' },
  { key: 'cable_curl', name: 'Cable Curl', muscle: 'biceps', equipment: 'cable' },
  { key: 'preacher_curl', name: 'Preacher Curl', muscle: 'biceps', equipment: 'machine' },
  { key: 'tricep_pushdown', name: 'Tricep Pushdown', muscle: 'triceps', equipment: 'cable' },
  { key: 'overhead_tricep', name: 'Overhead Tricep Ext', muscle: 'triceps', equipment: 'dumbbell' },
  { key: 'skull_crusher', name: 'Skull Crusher', muscle: 'triceps', equipment: 'barbell' },
  { key: 'bench_dip', name: 'Bench Dip', muscle: 'triceps', equipment: 'bodyweight', bodyweight: true },

  // Core
  { key: 'plank', name: 'Plank', muscle: 'core', equipment: 'bodyweight', bodyweight: true },
  { key: 'ab_wheel', name: 'Ab Wheel', muscle: 'core', equipment: 'bodyweight', bodyweight: true },
  { key: 'cable_crunch', name: 'Cable Crunch', muscle: 'core', equipment: 'cable' },
  { key: 'hanging_leg_raise', name: 'Hanging Leg Raise', muscle: 'core', equipment: 'bodyweight', bodyweight: true },
];

const equipmentFilter = {
  full_gym: () => true,
  home_gym: ex => ex.equipment !== 'machine' && ex.equipment !== 'cable',
  dumbbells: ex => ex.equipment === 'dumbbell' || ex.equipment === 'bodyweight',
  bodyweight: ex => ex.equipment === 'bodyweight',
};

export function accessoryWeight(key, mains) {
  const ex = EXERCISES.find(e => e.key === key);
  if (!ex) return 20;
  const ratios = {
    chest: 0.4, back: 0.45, shoulders: 0.25, biceps: 0.2, triceps: 0.25,
    quads: 0.55, hamstrings: 0.5, glutes: 0.45, calves: 0.4, core: 0,
  };
  const mainMap = {
    chest: mains.bench, back: mains.row, shoulders: mains.ohp,
    quads: mains.squat, hamstrings: mains.deadlift, glutes: mains.squat,
    biceps: mains.row, triceps: mains.bench, calves: mains.squat, core: 0,
  };
  const base = mainMap[ex.muscle] || 20;
  const ratio = ratios[ex.muscle] || 0.3;
  if (ex.bodyweight) return 'BW';
  if (ex.equipment === 'dumbbell') return Math.round((base * ratio) / 2) * 2;
  return Math.round((base * ratio) / 5) * 5 || 20;
}

function getExerciseCount(sessionLength) {
  if (sessionLength === 45) return 5;
  if (sessionLength === 90) return 8;
  return 6;
}

function goalParams(goal) {
  if (goal === 'muscle') return { sets: 4, reps: '8-10', rpe: '7-8' };
  if (goal === 'stronger') return { sets: 5, reps: '4-6', rpe: '8-9' };
  if (goal === 'fat') return { sets: 4, reps: '10-12', rpe: '8-9' };
  return { sets: 4, reps: '6-8', rpe: '8-9' };
}

function filterAvail(exList, equipment, dislikes = [], avoid = '') {
  const filter = equipmentFilter[equipment] || (() => true);
  const avoidLower = avoid.toLowerCase();
  return exList.filter(ex => {
    if (!filter(ex)) return false;
    if (dislikes.some(d => ex.name.toLowerCase().includes(d.toLowerCase()))) return false;
    if (avoidLower && ex.name.toLowerCase().split(' ').some(w => avoidLower.includes(w))) return false;
    return true;
  });
}

function pickExercises(muscles, avail, weights, count, weakPoints, favourites) {
  const result = [];
  const used = new Set();

  const sorted = [...avail].sort((a, b) => {
    const aFav = favourites.some(f => a.name.toLowerCase().includes(f.toLowerCase())) ? -1 : 0;
    const bFav = favourites.some(f => b.name.toLowerCase().includes(f.toLowerCase())) ? -1 : 0;
    const aWeak = weakPoints.some(wp => a.muscle.toLowerCase().includes(wp.toLowerCase())) ? -1 : 0;
    const bWeak = weakPoints.some(wp => b.muscle.toLowerCase().includes(wp.toLowerCase())) ? -1 : 0;
    return (aFav + aWeak) - (bFav + bWeak);
  });

  for (const muscle of muscles) {
    if (result.length >= count) break;
    const ex = sorted.find(e => e.muscle === muscle && !used.has(e.key));
    if (ex) { result.push(ex); used.add(ex.key); }
  }

  // Fill remaining slots
  for (const ex of sorted) {
    if (result.length >= count) break;
    if (!used.has(ex.key)) { result.push(ex); used.add(ex.key); }
  }

  return result.slice(0, count);
}

function makeExercise(ex, params, weights) {
  const wRaw = accessoryWeight(ex.key, weights);
  return {
    key: ex.key,
    name: ex.name,
    sets: params.sets,
    reps: params.reps,
    weight: wRaw === 'BW' ? 0 : wRaw,
    weightLabel: wRaw === 'BW' ? 'BW' : undefined,
    rpe: params.rpe,
    tag: ex.isMain ? 'compound' : 'accessory',
    bodyweight: !!ex.bodyweight,
    muscle: ex.muscle,
    readyToProgress: false,
  };
}

function buildSession(name, muscles, avail, weights, params, count, focus, weakPoints, favourites) {
  const exercises = pickExercises(muscles, avail, weights, count, weakPoints, favourites);
  return {
    name,
    focus,
    block: 'Block 1',
    exercises: exercises.map(ex => makeExercise(ex, params, weights)),
  };
}

export function buildProgramme(profile, weights) {
  const { experience, days, goal, equipment, sessionLength, weakPoints = [], dislikes = [], avoid = '', favourites = [] } = profile;
  const avail = filterAvail(EXERCISES, equipment, dislikes, avoid);
  const count = getExerciseCount(sessionLength);
  const params = goalParams(goal);
  const p = { ...params, sets: params.sets };
  const accP = { ...params, sets: Math.max(3, params.sets - 1) };

  const sessions = [];

  if (experience === 'beginner') {
    // Full Body A/B/C
    const dayCount = days;
    const templates = [
      { name: 'Full Body A', muscles: ['chest','back','quads','shoulders','biceps','triceps','core'] },
      { name: 'Full Body B', muscles: ['back','chest','hamstrings','glutes','shoulders','biceps','core'] },
      { name: 'Full Body C', muscles: ['quads','chest','back','shoulders','triceps','calves','core'] },
    ];
    for (let i = 0; i < dayCount; i++) {
      const t = templates[i % templates.length];
      sessions.push(buildSession(t.name, t.muscles, avail, weights, p, count, 'Full Body', weakPoints, favourites));
    }
  } else if (experience === 'intermediate' && days <= 4) {
    // Upper/Lower
    sessions.push(buildSession('Upper A', ['chest','shoulders','back','biceps','triceps'], avail, weights, p, count, 'Push + Pull', weakPoints, favourites));
    sessions.push(buildSession('Lower A', ['quads','hamstrings','glutes','calves','core'], avail, weights, p, count, 'Squat focus', weakPoints, favourites));
    if (days >= 3) sessions.push(buildSession('Upper B', ['back','chest','shoulders','triceps','biceps'], avail, weights, p, count, 'Pull + Push', weakPoints, favourites));
    if (days >= 4) sessions.push(buildSession('Lower B', ['hamstrings','quads','glutes','calves','core'], avail, weights, p, count, 'Hinge focus', weakPoints, favourites));
  } else {
    // Push/Pull/Legs
    const vol = experience === 'advanced' ? { ...p, sets: p.sets + 1 } : p;
    sessions.push(buildSession('Push', ['chest','shoulders','triceps'], avail, weights, vol, count, 'Chest + Shoulders', weakPoints, favourites));
    sessions.push(buildSession('Pull', ['back','biceps'], avail, weights, vol, count, 'Back + Biceps', weakPoints, favourites));
    sessions.push(buildSession('Legs', ['quads','hamstrings','glutes','calves','core'], avail, weights, vol, count, 'Legs + Glutes', weakPoints, favourites));
    if (days >= 4) sessions.push(buildSession('Push B', ['chest','shoulders','triceps'], avail, weights, vol, count, 'Shoulder focus', weakPoints, favourites));
    if (days >= 5) sessions.push(buildSession('Pull B', ['back','biceps'], avail, weights, vol, count, 'Arms focus', weakPoints, favourites));
  }

  return sessions;
}

export function checkProgress(history, exerciseKey) {
  if (history.length < 4) return false;
  const last4 = history.slice(-4);
  const appearances = last4.filter(s =>
    s.exercises.some(e => e.key === exerciseKey)
  );
  return appearances.length >= 2;
}

export function flagProgress(sessions, history) {
  return sessions.map(session => ({
    ...session,
    exercises: session.exercises.map(ex => ({
      ...ex,
      readyToProgress: checkProgress(history, ex.key),
    })),
  }));
}
