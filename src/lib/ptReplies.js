import { buildProgramme } from './programme.js';
import { importedSessionToRuntime } from './importHelpers.js';

const FORM_CUES = {
  bench: `Bench Press cues:\n• Arch your upper back, not lower\n• Shoulder blades pinched and retracted\n• Bar path: slight diagonal toward lower chest\n• Drive feet into floor, full body tension\n• Wrists stacked over elbows`,
  squat: `Back Squat cues:\n• Brace your core 360° before unracking\n• Break at hips and knees simultaneously\n• Track knees over toes throughout\n• Keep chest tall, avoid good-morning lean\n• Drive hips through at lockout`,
  deadlift: `Deadlift cues:\n• Bar over mid-foot, hip-width stance\n• Hinge first, then knee bend to grip bar\n• Lat activation: "protect your armpits"\n• Push the floor away, don't pull the bar up\n• Lock out hips completely at top`,
  ohp: `Overhead Press cues:\n• Start with bar just above clavicle\n• Elbows slightly in front of bar at bottom\n• Push head through at top (don't hyperextend)\n• Brace core, squeeze glutes throughout\n• Full lockout on every rep`,
  row: `Barbell Row cues:\n• Hinge to ~45° torso angle\n• Pull to belly button, not chest\n• Lead with elbows, not biceps\n• Controlled eccentric, don't drop the bar\n• Squeeze shoulder blades at top`,
};

function findLift(text) {
  const t = text.toLowerCase();
  if (t.includes('bench') || t.includes('chest press')) return 'bench';
  if (t.includes('squat')) return 'squat';
  if (t.includes('deadlift') || t.includes('dead lift')) return 'deadlift';
  if (t.includes('overhead') || t.includes('ohp') || t.includes('press')) return 'ohp';
  if (t.includes('row')) return 'row';
  return null;
}

function findMuscle(text) {
  const t = text.toLowerCase();
  if (t.includes('arm') || t.includes('bicep') || t.includes('tricep')) return 'Arms';
  if (t.includes('chest')) return 'Chest';
  if (t.includes('back') || t.includes('lat')) return 'Back';
  if (t.includes('shoulder') || t.includes('delt')) return 'Shoulders';
  if (t.includes('leg') || t.includes('quad')) return 'Quads';
  if (t.includes('glute') || t.includes('ham')) return 'Glutes-Hams';
  if (t.includes('core') || t.includes('ab')) return 'Core';
  return null;
}

export function generateReply(input, appState) {
  const {
    programmeMode, profile, weights, programme, currentSession,
    importedProgramme, currentWeek, history,
    setProfile, setProgramme, setCurrentSession, setWeights,
    setCurrentWeek, rebuildProgramme, showToast,
    setCompletedSets,
  } = appState;

  const text = input.toLowerCase().trim();

  // ── IMPORTED MODE RESTRICTIONS ─────────────────────────────────────────
  if (programmeMode === 'imported') {
    // Jump to week
    const weekMatch = text.match(/(?:jump to|go to|week|w)\s*(\d+)/i);
    if (weekMatch) {
      const wn = parseInt(weekMatch[1]);
      const maxWeek = importedProgramme?.weeks?.length || 1;
      if (wn >= 1 && wn <= maxWeek) {
        setCurrentWeek(wn);
        const wk = importedProgramme.weeks.find(w => w.weekNumber === wn);
        const firstSession = wk?.sessions?.find(s => !s.isRest);
        if (firstSession) setCurrentSession(importedSessionToRuntime(firstSession));
        showToast(`Jumped to Week ${wn} ✓`);
        return `Jumped to Week ${wn}. ${firstSession ? `First session: **${firstSession.name}** — ${firstSession.exercises?.length || 0} exercises.` : 'Rest day today.'}`;
      }
      return `Week ${wn} doesn't exist in your programme (max: Week ${maxWeek}).`;
    }

    // Programme overview
    if (text.includes('overview') || text.includes('programme')) {
      const weeks = importedProgramme?.weeks?.length || 0;
      const sessPerWeek = importedProgramme?.weeks?.[0]?.sessions?.filter(s => !s.isRest).length || 0;
      return `**${importedProgramme?.name}**\n${weeks} weeks · ${sessPerWeek} sessions/week\n\nYou're currently on Week ${currentWeek}.${importedProgramme?.description ? `\n\n${importedProgramme.description}` : ''}`;
    }

    // What's today / current session
    if (text.includes("today") || text.includes("current session")) {
      if (!currentSession) return "No session loaded for today. Use the Home tab to select one.";
      const exList = currentSession.exercises?.map(e => `• ${e.name} — ${e.sets}×${e.reps} @ ${e.bodyweight ? 'BW' : `${e.weight}kg`}`).join('\n') || '';
      return `**${currentSession.name}**\n${currentSession.focus ? currentSession.focus + '\n' : ''}${exList}`;
    }

    // Show week N
    const showWeekMatch = text.match(/(?:show|what.?s|w)\s*(\d+)/i);
    if (showWeekMatch) {
      const wn = parseInt(showWeekMatch[1]);
      const wk = importedProgramme?.weeks?.find(w => w.weekNumber === wn);
      if (wk) {
        const sessions = wk.sessions.filter(s => !s.isRest);
        return `**Week ${wn}${wk.label ? ` — ${wk.label}` : ''}**\n${sessions.map(s => `• ${s.day.toUpperCase()}: ${s.name}`).join('\n')}`;
      }
    }

    // Weight bump still works
    if (text.match(/(?:bump|increase|add)\s+(?:my\s+)?(\w+)\s+(\d+)\s*kg?/i)) {
      // handled below in shared section
    }

    // Block restructuring
    if (text.match(/switch to|change.*days|rebuild|new programme|change goal|equipment|bodyweight only|home gym|full gym|dumbbells only/i)) {
      return `You're on an imported programme. To change structure, update your JSON in Claude and re-import. I can still handle weights and navigation.`;
    }
  }

  // ── SHARED COMMANDS (both modes) ───────────────────────────────────────

  // What's today
  if (text.includes("today") || text.includes("current session")) {
    if (!currentSession) return "No session scheduled. Complete onboarding or select one from Home.";
    const exList = currentSession.exercises?.map(e => `• ${e.name} — ${e.sets}×${e.reps} @ ${e.bodyweight ? 'BW' : `${e.weight}kg`}`).join('\n') || '';
    return `**${currentSession.name}**\n${currentSession.focus || ''}\n${exList}`;
  }

  // Form cues
  const formMatch = text.match(/form\s+(?:cues?\s+(?:for\s+)?|tips?\s+(?:for\s+)?|on\s+)?(.+)/i);
  if (formMatch || text.includes('how to')) {
    const lift = findLift(formMatch ? formMatch[1] : text);
    if (lift && FORM_CUES[lift]) return FORM_CUES[lift];
  }

  // Fatigue / recovery
  if (text.includes('fatigue') || text.includes('tired') || text.includes('worn out') || text.includes('exhausted')) {
    return `Recovery advice:\n• Take an extra rest day if RPE was consistently 9+ this week\n• Prioritise 8h sleep — most growth happens at night\n• Protein target: ~${Math.round((profile?.bodyweight || 75) * 2)}g/day\n• De-load every 4–6 weeks: reduce weight 15–20%, keep the movement\n\nWant me to make today's session lighter? Just say "lighter today".`;
  }

  // Lighter today
  if (text.includes('lighter') || text.includes('easy day') || text.includes('light day')) {
    if (currentSession) {
      const lighter = {
        ...currentSession,
        exercises: currentSession.exercises.map(ex => ({
          ...ex,
          weight: Math.round(ex.weight * 0.9 * 2) / 2,
        })),
      };
      setCurrentSession(lighter);
      showToast('Session updated ✓');
      return `Done — all weights reduced by 10% for today's session. Listen to your body and enjoy the active recovery.`;
    }
  }

  // Weight bump: "bump my squat 5kg" / "increase bench"
  const bumpMatch = text.match(/(?:bump|increase|add|raise)\s+(?:my\s+)?(\w+)(?:\s+by)?\s+(\d+(?:\.\d+)?)\s*kg?/i);
  if (bumpMatch) {
    const liftName = bumpMatch[1].toLowerCase();
    const liftKey = liftName === 'ohp' || liftName === 'overhead' ? 'ohp' : liftName === 'deadlift' ? 'deadlift' : liftName === 'squat' ? 'squat' : liftName === 'bench' ? 'bench' : 'bench';
    const amount = parseFloat(bumpMatch[2]);
    const newWeights = { ...weights, [liftKey]: (weights[liftKey] || 0) + amount };
    setWeights(newWeights);
    showToast('Session updated ✓');
    return `Done — ${liftKey} bumped to ${newWeights[liftKey]}kg.`;
  }

  // Simple increase (no amount)
  const simpleIncreaseMatch = text.match(/(?:increase|bump up|raise|progress)\s+(?:my\s+)?(\w+)/i);
  if (simpleIncreaseMatch) {
    const lift = findLift(simpleIncreaseMatch[1]);
    if (lift) {
      const step = lift === 'deadlift' ? 5 : 2.5;
      const newWeights = { ...weights, [lift]: (weights[lift] || 0) + step };
      setWeights(newWeights);
      showToast('Session updated ✓');
      return `${lift} increased by ${step}kg → now ${newWeights[lift]}kg.`;
    }
  }

  // Progress summary
  if (text.includes('progress') || text.includes('how am i doing')) {
    const sessionCount = history.length;
    const vol = history.slice(-4).reduce((s, h) => s + (h.volume || 0), 0);
    return `**Your progress:**\n• Sessions logged: ${sessionCount}\n• Volume last 4 sessions: ${Math.round(vol)}kg total\n\n**Current lifts:**\n• Bench: ${weights.bench}kg\n• Squat: ${weights.squat}kg\n• Deadlift: ${weights.deadlift}kg\n• OHP: ${weights.ohp}kg`;
  }

  // Nutrition
  if (text.includes('nutrition') || text.includes('protein') || text.includes('eat') || text.includes('diet')) {
    const bw = profile?.bodyweight || 75;
    return `**Nutrition basics:**\n• Protein: ~${Math.round(bw * 2)}g/day (2g per kg bodyweight)\n• Calorie surplus for muscle: +200–400 kcal/day\n• Calorie deficit for fat loss: −300–500 kcal/day\n• Hydration: 35ml/kg/day (~${Math.round(bw * 35 / 1000 * 10) / 10}L)\n• Prioritise whole foods, don't overcomplicate it.`;
  }

  // ── AUTO MODE ONLY ──────────────────────────────────────────────────────
  if (programmeMode === 'auto') {

    // Equipment change
    if (text.match(/switch to dumbbells|dumbbell[s]? only/i)) {
      const newProf = { ...profile, equipment: 'dumbbells' };
      setProfile(newProf);
      rebuildProgramme(newProf, weights);
      return `Switched to dumbbell-only equipment. Programme rebuilt!`;
    }
    if (text.match(/home gym/i)) {
      const newProf = { ...profile, equipment: 'home_gym' };
      setProfile(newProf);
      rebuildProgramme(newProf, weights);
      return `Switched to home gym setup. Programme rebuilt!`;
    }
    if (text.match(/bodyweight only|no equipment/i)) {
      const newProf = { ...profile, equipment: 'bodyweight' };
      setProfile(newProf);
      rebuildProgramme(newProf, weights);
      return `Switched to bodyweight training. Programme rebuilt!`;
    }
    if (text.match(/full gym|back to gym/i)) {
      const newProf = { ...profile, equipment: 'full_gym' };
      setProfile(newProf);
      rebuildProgramme(newProf, weights);
      return `Switched to full gym. Programme rebuilt!`;
    }

    // Days per week
    const daysMatch = text.match(/(\d)\s+days?\s+(?:per|a)\s+week/i);
    if (daysMatch) {
      const d = parseInt(daysMatch[1]);
      if (d >= 3 && d <= 5) {
        const newProf = { ...profile, days: d };
        setProfile(newProf);
        rebuildProgramme(newProf, weights);
        return `Updated to ${d} training days/week. Programme rebuilt!`;
      }
    }

    // Goal change
    if (text.match(/fat loss|lose fat|cut/i)) {
      const newProf = { ...profile, goal: 'fat' };
      setProfile(newProf);
      rebuildProgramme(newProf, weights);
      return `Goal updated to Fat Loss. Programme rebuilt with higher rep ranges!`;
    }
    if (text.match(/build muscle|more muscle|hypertrophy/i)) {
      const newProf = { ...profile, goal: 'muscle' };
      setProfile(newProf);
      rebuildProgramme(newProf, weights);
      return `Goal updated to Build Muscle. Programme rebuilt!`;
    }
    if (text.match(/get stronger|strength|powerlifting/i)) {
      const newProf = { ...profile, goal: 'stronger' };
      setProfile(newProf);
      rebuildProgramme(newProf, weights);
      return `Goal updated to Get Stronger. Programme rebuilt with heavier sets!`;
    }

    // Add more volume for muscle group
    const addMoreMatch = text.match(/add more (.+?) (?:work|exercises?|volume)/i);
    if (addMoreMatch) {
      const muscle = findMuscle(addMoreMatch[1]);
      if (muscle) {
        const newProf = { ...profile, weakPoints: [...(profile.weakPoints || []), muscle] };
        setProfile(newProf);
        rebuildProgramme(newProf, weights);
        return `Added ${muscle} as a priority. Programme rebuilt with more ${muscle} work!`;
      }
    }

    // Remove exercise
    const dislikeMatch = text.match(/(?:don.?t want|hate|remove|no more|avoid)\s+(?:to do\s+)?(.+)/i);
    if (dislikeMatch) {
      const exerciseName = dislikeMatch[1].replace(/\.$/, '').trim();
      const newProf = { ...profile, dislikes: [...(profile.dislikes || []), exerciseName] };
      setProfile(newProf);
      rebuildProgramme(newProf, weights);
      return `Got it — "${exerciseName}" removed from your programme. Rebuilt!`;
    }

    // Session length
    if (text.match(/shorter.* session|45 min|quick session/i)) {
      const newProf = { ...profile, sessionLength: 45 };
      setProfile(newProf);
      rebuildProgramme(newProf, weights);
      return `Sessions shortened to 45 minutes. Programme rebuilt!`;
    }
    if (text.match(/longer.*session|90 min/i)) {
      const newProf = { ...profile, sessionLength: 90 };
      setProfile(newProf);
      rebuildProgramme(newProf, weights);
      return `Sessions extended to 90 minutes. Programme rebuilt!`;
    }

    // Favourites
    const favMatch = text.match(/(?:love|like|prefer|favourite)\s+(.+)/i);
    if (favMatch) {
      const ex = favMatch[1].replace(/\.$/, '').trim();
      const newProf = { ...profile, favourites: [...(profile.favourites || []), ex] };
      setProfile(newProf);
      return `Added "${ex}" to your favourites — I'll prioritise it in future sessions.`;
    }

    // Swap exercise in today's session
    const swapMatch = text.match(/swap (.+?) (?:for|with) (.+)/i);
    if (swapMatch && currentSession) {
      const from = swapMatch[1].trim().toLowerCase();
      const toName = swapMatch[2].trim();
      const updated = {
        ...currentSession,
        exercises: currentSession.exercises.map(ex =>
          ex.name.toLowerCase().includes(from)
            ? { ...ex, name: toName }
            : ex
        ),
      };
      setCurrentSession(updated);
      showToast('Session updated ✓');
      return `Swapped — today's session now has ${toName} instead.`;
    }

    // Add a set
    if (text.match(/add a set|more sets/i) && currentSession) {
      const updated = {
        ...currentSession,
        exercises: currentSession.exercises.map((ex, i) =>
          i === 0 ? { ...ex, sets: ex.sets + 1 } : ex
        ),
      };
      setCurrentSession(updated);
      showToast('Session updated ✓');
      return `Added a set to ${currentSession.exercises[0]?.name}. Go get it!`;
    }

    // Next session
    if (text.includes("next session") || text.includes("what's next") || text.includes("whats next")) {
      if (!currentSession || !programme.length) return "No programme loaded.";
      const idx = programme.findIndex(s => s.name === currentSession.name);
      const next = programme[(idx + 1) % programme.length];
      return `**Next session: ${next.name}**\n${next.exercises?.slice(0,4).map(e => `• ${e.name} — ${e.sets}×${e.reps}`).join('\n') || ''}`;
    }
  }

  // Help
  if (text === 'help' || text.includes('what can you do') || text.includes('commands')) {
    if (programmeMode === 'imported') {
      return `**Imported mode commands:**\n• "What's today?" — current session\n• "Jump to week 3" — navigate weeks\n• "Show me week 1" — week breakdown\n• "Programme overview"\n• "Lighter today" — reduce weights 10%\n• "Bump my squat 5kg"\n• "Form cues for bench"\n• "I'm feeling fatigued"\n• "Nutrition"`;
    }
    return `**Available commands:**\n• "What's today?" / "Next session"\n• "Switch to dumbbells" / "Home gym" / "Full gym"\n• "Train 4 days a week"\n• "Change goal to fat loss" / "Build muscle"\n• "Add more arm work"\n• "I don't want to do deadlifts"\n• "Shorter sessions" / "90 min sessions"\n• "I love incline dumbbell"\n• "Swap bench for incline DB"\n• "Bump my squat 5kg"\n• "Add a set"\n• "Lighter today"\n• "How am I progressing?"\n• "Form cues for [lift]"\n• "Nutrition"\n• "I'm feeling fatigued"`;
  }

  // Fallback
  const suggestions = programmeMode === 'imported'
    ? ['Try: "Jump to week 2"', '"What\'s today?"', '"Show me week 1"']
    : ['Try: "What\'s today?"', '"Add more arm work"', '"Switch to dumbbells"', '"Help" for all commands'];
  return `I didn't catch that. ${suggestions[Math.floor(Math.random() * suggestions.length)]}`;
}
