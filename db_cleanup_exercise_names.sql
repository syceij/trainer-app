-- ============================================================
-- Exercise name cleanup — run in Supabase SQL editor
-- ============================================================
-- STEP A: Inspect current data first
-- ============================================================

SELECT DISTINCT exercise_name, COUNT(*) AS rows
  FROM sets
 GROUP BY exercise_name
 ORDER BY exercise_name;

SELECT DISTINCT exercise_name, COUNT(*) AS rows
  FROM working_weights
 GROUP BY exercise_name
 ORDER BY exercise_name;

-- ============================================================
-- STEP B: Normalise exercise_name in both tables
--
-- Each UPDATE uses  LOWER(TRIM(exercise_name)) IN (...)
-- so it is safe to run multiple times (idempotent).
-- Run all statements; only rows that match will be updated.
-- ============================================================

-- ── Deadlift ─────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Deadlift' WHERE LOWER(TRIM(exercise_name)) IN ('conventional deadlift','barbell deadlift','conventional dl','barbell dl','conv deadlift');
UPDATE working_weights SET exercise_name = 'Deadlift' WHERE LOWER(TRIM(exercise_name)) IN ('conventional deadlift','barbell deadlift','conventional dl','barbell dl','conv deadlift');

-- ── Overhead Press ────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Overhead Press' WHERE LOWER(TRIM(exercise_name)) IN ('ohp','barbell ohp','military press','barbell overhead press','standing overhead press','standing ohp');
UPDATE working_weights SET exercise_name = 'Overhead Press' WHERE LOWER(TRIM(exercise_name)) IN ('ohp','barbell ohp','military press','barbell overhead press','standing overhead press','standing ohp');

-- ── Lat Pulldown ──────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Lat Pulldown' WHERE LOWER(TRIM(exercise_name)) IN ('lat pulldown (bar)','lat pulldown (cable)','lat pulldown bar','lat pull-down','lat pull down','wide grip lat pulldown','cable pulldown','pulldown');
UPDATE working_weights SET exercise_name = 'Lat Pulldown' WHERE LOWER(TRIM(exercise_name)) IN ('lat pulldown (bar)','lat pulldown (cable)','lat pulldown bar','lat pull-down','lat pull down','wide grip lat pulldown','cable pulldown','pulldown');

-- ── Barbell Bench Press ───────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Barbell Bench Press' WHERE LOWER(TRIM(exercise_name)) IN ('bench','bench press','flat bench press','flat bench','barbell bench','bb bench press');
UPDATE working_weights SET exercise_name = 'Barbell Bench Press' WHERE LOWER(TRIM(exercise_name)) IN ('bench','bench press','flat bench press','flat bench','barbell bench','bb bench press');

-- ── Back Squat ────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Back Squat' WHERE LOWER(TRIM(exercise_name)) IN ('squat','barbell squat','bb squat','barbell back squat');
UPDATE working_weights SET exercise_name = 'Back Squat' WHERE LOWER(TRIM(exercise_name)) IN ('squat','barbell squat','bb squat','barbell back squat');

-- ── Barbell Row ───────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Barbell Row' WHERE LOWER(TRIM(exercise_name)) IN ('row','bent over row','bent-over row','bent over barbell row','barbell bent over row','bb row','bent-over barbell row');
UPDATE working_weights SET exercise_name = 'Barbell Row' WHERE LOWER(TRIM(exercise_name)) IN ('row','bent over row','bent-over row','bent over barbell row','barbell bent over row','bb row','bent-over barbell row');

-- ── Romanian Deadlift ─────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Romanian Deadlift' WHERE LOWER(TRIM(exercise_name)) IN ('rdl','romanian dl','barbell rdl');
UPDATE working_weights SET exercise_name = 'Romanian Deadlift' WHERE LOWER(TRIM(exercise_name)) IN ('rdl','romanian dl','barbell rdl');

-- ── Pull-Up ───────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Pull-Up' WHERE LOWER(TRIM(exercise_name)) IN ('pull-ups','pullups','pull ups');
UPDATE working_weights SET exercise_name = 'Pull-Up' WHERE LOWER(TRIM(exercise_name)) IN ('pull-ups','pullups','pull ups');

-- ── Chin-Up ───────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Chin-Up' WHERE LOWER(TRIM(exercise_name)) IN ('chin-ups','chinups','chin ups');
UPDATE working_weights SET exercise_name = 'Chin-Up' WHERE LOWER(TRIM(exercise_name)) IN ('chin-ups','chinups','chin ups');

-- ── Push-Up ───────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Push-Up' WHERE LOWER(TRIM(exercise_name)) IN ('push-ups','pushups','push ups');
UPDATE working_weights SET exercise_name = 'Push-Up' WHERE LOWER(TRIM(exercise_name)) IN ('push-ups','pushups','push ups');

-- ── Close-Grip Bench Press ────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Close-Grip Bench Press' WHERE LOWER(TRIM(exercise_name)) IN ('close grip bench press','cgbp','close grip bench');
UPDATE working_weights SET exercise_name = 'Close-Grip Bench Press' WHERE LOWER(TRIM(exercise_name)) IN ('close grip bench press','cgbp','close grip bench');

-- ── Incline Barbell Press ─────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Incline Barbell Press' WHERE LOWER(TRIM(exercise_name)) IN ('incline bench press','incline barbell bench press','incline bp');
UPDATE working_weights SET exercise_name = 'Incline Barbell Press' WHERE LOWER(TRIM(exercise_name)) IN ('incline bench press','incline barbell bench press','incline bp');

-- ── Incline DB Press ──────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Incline DB Press' WHERE LOWER(TRIM(exercise_name)) IN ('incline dumbbell press','dumbbell incline press','incline db bench press');
UPDATE working_weights SET exercise_name = 'Incline DB Press' WHERE LOWER(TRIM(exercise_name)) IN ('incline dumbbell press','dumbbell incline press','incline db bench press');

-- ── Dumbbell Bench Press ──────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Dumbbell Bench Press' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell bench press','db bench press');
UPDATE working_weights SET exercise_name = 'Dumbbell Bench Press' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell bench press','db bench press');

-- ── DB Shoulder Press ─────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'DB Shoulder Press' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell shoulder press','dumbbell ohp','db ohp','dumbbell overhead press','seated db press');
UPDATE working_weights SET exercise_name = 'DB Shoulder Press' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell shoulder press','dumbbell ohp','db ohp','dumbbell overhead press','seated db press');

-- ── DB Curl ───────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'DB Curl' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell curl','dumbbell curls','db bicep curl','dumbbell bicep curl');
UPDATE working_weights SET exercise_name = 'DB Curl' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell curl','dumbbell curls','db bicep curl','dumbbell bicep curl');

-- ── Dumbbell Row ──────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Dumbbell Row' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell row','db row','single arm row','one arm dumbbell row');
UPDATE working_weights SET exercise_name = 'Dumbbell Row' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell row','db row','single arm row','one arm dumbbell row');

-- ── DB Romanian Deadlift ──────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'DB Romanian Deadlift' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell rdl','dumbbell romanian deadlift','db rdl');
UPDATE working_weights SET exercise_name = 'DB Romanian Deadlift' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell rdl','dumbbell romanian deadlift','db rdl');

-- ── DB Lunge ──────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'DB Lunge' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell lunge','db lunges','dumbbell lunges');
UPDATE working_weights SET exercise_name = 'DB Lunge' WHERE LOWER(TRIM(exercise_name)) IN ('dumbbell lunge','db lunges','dumbbell lunges');

-- ── Standing Calf Raise ───────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Standing Calf Raise' WHERE LOWER(TRIM(exercise_name)) IN ('calf raise','calf raises','standing calf raises');
UPDATE working_weights SET exercise_name = 'Standing Calf Raise' WHERE LOWER(TRIM(exercise_name)) IN ('calf raise','calf raises','standing calf raises');

-- ── Seated Calf Raise ─────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Seated Calf Raise' WHERE LOWER(TRIM(exercise_name)) IN ('seated calf raises');
UPDATE working_weights SET exercise_name = 'Seated Calf Raise' WHERE LOWER(TRIM(exercise_name)) IN ('seated calf raises');

-- ── Hip Thrust ────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Hip Thrust' WHERE LOWER(TRIM(exercise_name)) IN ('barbell hip thrust','bb hip thrust','hip thrusts');
UPDATE working_weights SET exercise_name = 'Hip Thrust' WHERE LOWER(TRIM(exercise_name)) IN ('barbell hip thrust','bb hip thrust','hip thrusts');

-- ── Tricep Pushdown ───────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Tricep Pushdown' WHERE LOWER(TRIM(exercise_name)) IN ('triceps pushdown','cable tricep pushdown','tricep pulldown','cable pushdown');
UPDATE working_weights SET exercise_name = 'Tricep Pushdown' WHERE LOWER(TRIM(exercise_name)) IN ('triceps pushdown','cable tricep pushdown','tricep pulldown','cable pushdown');

-- ── Overhead Tricep Ext ───────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Overhead Tricep Ext' WHERE LOWER(TRIM(exercise_name)) IN ('overhead tricep extension','overhead triceps extension','db overhead tricep','overhead extension');
UPDATE working_weights SET exercise_name = 'Overhead Tricep Ext' WHERE LOWER(TRIM(exercise_name)) IN ('overhead tricep extension','overhead triceps extension','db overhead tricep','overhead extension');

-- ── Skull Crusher ─────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Skull Crusher' WHERE LOWER(TRIM(exercise_name)) IN ('skull crushers','lying tricep extension','ez bar skull crusher');
UPDATE working_weights SET exercise_name = 'Skull Crusher' WHERE LOWER(TRIM(exercise_name)) IN ('skull crushers','lying tricep extension','ez bar skull crusher');

-- ── Lateral Raise ─────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Lateral Raise' WHERE LOWER(TRIM(exercise_name)) IN ('lateral raises','side raises','db lateral raise');
UPDATE working_weights SET exercise_name = 'Lateral Raise' WHERE LOWER(TRIM(exercise_name)) IN ('lateral raises','side raises','db lateral raise');

-- ── Rear Delt Fly ─────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Rear Delt Fly' WHERE LOWER(TRIM(exercise_name)) IN ('rear delt flyes','rear delt flys','rear delt flies','reverse fly','reverse dumbbell fly');
UPDATE working_weights SET exercise_name = 'Rear Delt Fly' WHERE LOWER(TRIM(exercise_name)) IN ('rear delt flyes','rear delt flys','rear delt flies','reverse fly','reverse dumbbell fly');

-- ── Face Pull ─────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Face Pull' WHERE LOWER(TRIM(exercise_name)) IN ('face pulls','cable face pull');
UPDATE working_weights SET exercise_name = 'Face Pull' WHERE LOWER(TRIM(exercise_name)) IN ('face pulls','cable face pull');

-- ── Cable Row ─────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Cable Row' WHERE LOWER(TRIM(exercise_name)) IN ('seated cable row','cable row (seated)');
UPDATE working_weights SET exercise_name = 'Cable Row' WHERE LOWER(TRIM(exercise_name)) IN ('seated cable row','cable row (seated)');

-- ── Barbell Curl ──────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Barbell Curl' WHERE LOWER(TRIM(exercise_name)) IN ('barbell curls','bb curl','ez bar curl');
UPDATE working_weights SET exercise_name = 'Barbell Curl' WHERE LOWER(TRIM(exercise_name)) IN ('barbell curls','bb curl','ez bar curl');

-- ── Hammer Curl ───────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Hammer Curl' WHERE LOWER(TRIM(exercise_name)) IN ('hammer curls','db hammer curl');
UPDATE working_weights SET exercise_name = 'Hammer Curl' WHERE LOWER(TRIM(exercise_name)) IN ('hammer curls','db hammer curl');

-- ── Hanging Leg Raise ─────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Hanging Leg Raise' WHERE LOWER(TRIM(exercise_name)) IN ('hanging leg raises','hanging knee raise','hanging knee raises');
UPDATE working_weights SET exercise_name = 'Hanging Leg Raise' WHERE LOWER(TRIM(exercise_name)) IN ('hanging leg raises','hanging knee raise','hanging knee raises');

-- ── Ab Wheel ──────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Ab Wheel' WHERE LOWER(TRIM(exercise_name)) IN ('ab wheel rollout','ab rollout','wheel rollout');
UPDATE working_weights SET exercise_name = 'Ab Wheel' WHERE LOWER(TRIM(exercise_name)) IN ('ab wheel rollout','ab rollout','wheel rollout');

-- ── Sumo Deadlift ─────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Sumo Deadlift' WHERE LOWER(TRIM(exercise_name)) IN ('sumo deadlifts','sumo dl');
UPDATE working_weights SET exercise_name = 'Sumo Deadlift' WHERE LOWER(TRIM(exercise_name)) IN ('sumo deadlifts','sumo dl');

-- ── Misc ──────────────────────────────────────────────────────────────────────
UPDATE sets          SET exercise_name = 'Chest Dip' WHERE LOWER(TRIM(exercise_name)) IN ('dips','chest dips','weighted dips');
UPDATE working_weights SET exercise_name = 'Chest Dip' WHERE LOWER(TRIM(exercise_name)) IN ('dips','chest dips','weighted dips');

UPDATE sets          SET exercise_name = 'Leg Extension' WHERE LOWER(TRIM(exercise_name)) IN ('leg extensions','quad extension');
UPDATE working_weights SET exercise_name = 'Leg Extension' WHERE LOWER(TRIM(exercise_name)) IN ('leg extensions','quad extension');

UPDATE sets          SET exercise_name = 'Leg Curl' WHERE LOWER(TRIM(exercise_name)) IN ('leg curls','hamstring curl','lying leg curl');
UPDATE working_weights SET exercise_name = 'Leg Curl' WHERE LOWER(TRIM(exercise_name)) IN ('leg curls','hamstring curl','lying leg curl');

-- ============================================================
-- STEP C: Verify — re-run the SELECT queries from STEP A
--         to confirm all names are now canonical.
-- ============================================================

SELECT DISTINCT exercise_name FROM sets          ORDER BY exercise_name;
SELECT DISTINCT exercise_name FROM working_weights ORDER BY exercise_name;
