import { useState, useCallback, useEffect, useRef } from 'react';
import { Capacitor } from '@capacitor/core';
import { SplashScreen } from '@capacitor/splash-screen';
import { AnimatePresence, motion } from 'framer-motion';
import WelcomeScreen from './components/WelcomeScreen.jsx';
import ManualProgrammeBuilder from './components/ManualProgrammeBuilder.jsx';
import Onboarding from './components/Onboarding.jsx';
import ImportScreen from './components/ImportScreen.jsx';
import AuthScreen from './components/AuthScreen.jsx';
import HomeTab from './components/HomeTab.jsx';
import TodayTab from './components/TodayTab.jsx';
import ProgressTab from './components/ProgressTab.jsx';
import ProfileTab from './components/ProfileTab.jsx';
import GymBrosTab from './components/GymBrosTab.jsx';
import UsernameModal from './components/shared/UsernameModal.jsx';
import ProgrammePage from './components/ProgrammePage.jsx';
import CalendarPage from './components/CalendarPage.jsx';
import AccountPage from './components/AccountPage.jsx';
import BottomNav from './components/BottomNav.jsx';
import Toast from './components/shared/Toast.jsx';
import ConfettiBurst from './components/shared/ConfettiBurst.jsx';
import { buildProgramme, flagProgress } from './lib/programme.js';
import { sessionForTodayImported, normalizeToCanonical } from './lib/importHelpers.js';
import { getT } from './lib/i18n.js';
import { supabase } from './lib/supabase.js';
import {
  ensureProfileExists,
  loadProfile, upsertProfile,
  loadProgramme, saveProgramme,
  loadSessions, insertSession, insertSets,
  loadWorkingWeights, upsertAllWorkingWeights,
  saveTrackedLifts,
  insertActivity, acceptInvite,
  updateLeaderboardScore,
  saveCustomExercises,
} from './lib/db.js';
import { C, spring, springSoft } from './tokens.js';

// ─── Clear all legacy localStorage on first run ──────────────────────────────
const CLEARED_KEY = 'supa_cleared_v1';
if (!localStorage.getItem(CLEARED_KEY)) {
  localStorage.clear();
  localStorage.setItem(CLEARED_KEY, '1');
}

// ─── Tiny localStorage helpers for ephemeral UI state only ──────────────────
const UI_KEY = 'trainer_ui';
function loadUI() { try { return JSON.parse(localStorage.getItem(UI_KEY)) || {}; } catch { return {}; } }
function saveUI(s) { try { localStorage.setItem(UI_KEY, JSON.stringify(s)); } catch {} }

const defaultProfile = {
  name: '', age: '', sex: 'Male',
  experience: 'beginner', goal: 'muscle',
  days: 4, sessionLength: 60,
  equipment: 'full_gym', cardio: 'none',
  weakPoints: [], favourites: [], dislikes: [],
  injuries: '', avoid: '', bodyweight: 70,
};
const defaultWeights = { bench: 60, squat: 80, deadlift: 100, ohp: 40, row: 60 };

// ─── Full-screen loading spinner ─────────────────────────────────────────────
function LoadingScreen() {
  return (
    <div style={{
      position: 'absolute', inset: 0, background: C.bg,
      display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 999,
    }}>
      <motion.img
        src="/loading%20logo.png"
        alt="HEX"
        animate={{ scale: [0.95, 1.05, 0.95] }}
        transition={{ repeat: Infinity, duration: 1.2, ease: 'easeInOut' }}
        style={{ width: 140, height: 140, objectFit: 'contain' }}
      />
    </div>
  );
}

// ─── Connection error banner ──────────────────────────────────────────────────
function NetworkError({ onRetry }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, background: C.bg,
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      padding: 32, gap: 16, zIndex: 999,
    }}>
      <div style={{ fontSize: 32 }}>📡</div>
      <p style={{ fontSize: 15, fontWeight: 700, color: C.text, textAlign: 'center' }}>
        Connection error
      </p>
      <p style={{ fontSize: 13, color: C.dim, textAlign: 'center' }}>
        Check your internet connection and try again.
      </p>
      <motion.button
        whileTap={{ scale: 0.97 }}
        onClick={onRetry}
        style={{
          background: C.accent, border: 'none', borderRadius: 12,
          padding: '13px 28px', fontSize: 14, fontWeight: 800, color: '#000',
          cursor: 'pointer', marginTop: 8,
        }}
      >
        Retry
      </motion.button>
    </div>
  );
}

// ─── Extract weighted exercises from a programme row (both modes) ─────────────
//
// For imported programmes the exercise names are normalised to canonical library
// names via normalizeToCanonical so that tracked_lifts, working_weights and sets
// all share the same name strings.
function extractProgrammeExercises(progRow) {
  if (!progRow) return [];
  const mode = progRow.data?.mode || progRow.name;
  const seen = new Set();
  const result = [];

  const push = (ex, fromImport = false) => {
    if (!ex?.name || ex.bodyweight) return;
    // Normalise imported names to canonical library names
    const name = fromImport ? normalizeToCanonical(ex.name) : ex.name;
    if (!name || seen.has(name)) return;
    seen.add(name);
    result.push({ name, key: ex.key || null });
  };

  if (mode === 'auto' && progRow.data?.programme) {
    for (const session of progRow.data.programme) {
      for (const ex of (session.exercises || [])) push(ex, false);
    }
  } else if (mode === 'imported' && progRow.data?.importedProgramme) {
    for (const week of (progRow.data.importedProgramme.weeks || [])) {
      for (const session of (week.sessions || [])) {
        if (session.isRest) continue;
        for (const ex of (session.exercises || [])) push(ex, true);
      }
    }
  }
  return result;
}

// ─── App ─────────────────────────────────────────────────────────────────────
export default function App() {
  // ── Auth state
  const [authState, setAuthState]     = useState('loading'); // 'loading' | 'unauthenticated' | 'authenticated'
  const [user, setUser]               = useState(null);
  const [netError, setNetError]       = useState(false);
  const [dataLoading, setDataLoading] = useState(false);

  // ── App state (loaded from Supabase after login)
  const ui = loadUI();
  // phase is always determined by loadUserData (DB-driven), never from localStorage
  const [phase, setPhase]                         = useState('welcome');
  const [programmeMode, setProgrammeMode]         = useState('auto');
  const [importedProgramme, setImportedProgramme] = useState(null);
  const [currentWeek, setCurrentWeek]             = useState(1);
  const [profile, setProfile]                     = useState(defaultProfile);
  const [weights, setWeights]                     = useState(defaultWeights);
  const [programme, setProgramme]                 = useState([]);
  const [currentSession, setCurrentSession]       = useState(null);
  const [completedSets, setCompletedSets]         = useState({});
  const [history, setHistory]                     = useState([]);
  const [streak, setStreak]                       = useState([false,false,false,false,false]);
  const [activeTab, setActiveTab]                 = useState(ui.activeTab || 'home');
  const [chatMessages, setChatMessages]           = useState([]);
  const [lastWeightAdded, setLastWeightAdded]     = useState(null);
  const [lang, setLang]                           = useState(ui.lang || 'en');
  const [toast, setToast]                         = useState(null);
  const [showConfetti, setShowConfetti]           = useState(false);
  const [programmeView, setProgrammeView]         = useState(false);
  const [calendarView, setCalendarView]           = useState(false);
  const [accountView, setAccountView]             = useState(false);
  const [editedKeys, setEditedKeys]               = useState([]);
  const [trackedLifts, setTrackedLifts]           = useState(null); // null = not yet loaded
  const [username, setUsername]                   = useState(null); // null = not yet loaded
  const [privacySettings, setPrivacySettings]     = useState(null);
  const [showUsernameModal, setShowUsernameModal] = useState(false);
  const [customExercises, setCustomExercises]     = useState([]);
  const [avatarUrl,        setAvatarUrl]           = useState(() => localStorage.getItem('hex_avatar') || null);

  // Refs so callbacks always see the latest values without stale closures
  const userRef        = useRef(user);
  const programmeIdRef = useRef(null);   // UUID of the programmes table row
  const currentWeekRef = useRef(1);
  // Set to true while deleteAccount is running — prevents onAuthStateChange from
  // double-resetting state and prevents the NetworkError screen from appearing.
  const isDeletingRef  = useRef(false);
  useEffect(() => { userRef.current = user; }, [user]);
  useEffect(() => { currentWeekRef.current = currentWeek; }, [currentWeek]);

  // ── Sync HTML dir + body font ─────────────────────────────────────────────
  useEffect(() => {
    document.documentElement.dir  = lang === 'ar' ? 'rtl' : 'ltr';
    document.documentElement.lang = lang;
    document.body.style.fontFamily = lang === 'ar'
      ? "'ThmanyahSans', system-ui, sans-serif"
      : "Inter, system-ui, -apple-system, sans-serif";
  }, [lang]);

  // ── Persist lang + activeTab to localStorage (ephemeral UI only) ──────────
  // Do NOT persist phase — phase is always derived from the DB (has a programme
  // or not) and must never be cached, otherwise a logged-out user's stale
  // "app" phase bleeds into the next session before loadUserData finishes.
  useEffect(() => {
    saveUI({ lang, activeTab });
  }, [lang, activeTab]);

  // ── Handle invite link on load ───────────────────────────────────────────
  // Checks window.location.pathname for /invite/[CODE] and stores the code
  // so it can be actioned once the user is authenticated.
  const pendingInviteRef = useRef(null);
  useEffect(() => {
    const match = window.location.pathname.match(/^\/invite\/([A-Z0-9]{8})$/i);
    if (match) {
      pendingInviteRef.current = match[1].toUpperCase();
      // Clean the URL without a page reload
      window.history.replaceState({}, '', '/');
    }
  }, []);

  // ── Supabase auth listener ────────────────────────────────────────────────
  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) {
        setUser(session.user);
        setAuthState('authenticated');
        loadUserData(session.user);
      } else {
        setAuthState('unauthenticated');
        if (Capacitor.isNativePlatform()) {
          SplashScreen.hide({ fadeOutDuration: 500 });
        }
      }
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (session?.user) {
        setUser(session.user);
        setAuthState('authenticated');
      } else {
        // deleteAccount handles its own cleanup — skip the double-reset
        if (isDeletingRef.current) return;
        setUser(null);
        setAuthState('unauthenticated');
        resetAppState();
      }
    });

    return () => subscription.unsubscribe();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── Load all user data from Supabase ──────────────────────────────────────
  const loadUserData = useCallback(async (u) => {
    setDataLoading(true);
    setNetError(false);
    console.log('[App] loadUserData — uid:', u.id);
    try {
      // Re-fetch the user from Supabase auth so we always have the full
      // user_metadata (name, etc.) even when called from an onAuthStateChange
      // callback that may only carry a minimal user object.
      const { data: { user: freshUser } } = await supabase.auth.getUser();
      const resolvedUser = freshUser ?? u;
      const uid = resolvedUser.id;
      console.log('[App] loadUserData — resolved uid:', uid);

      // ── Guarantee a profiles row exists before any FK-constrained write ──────
      // profiles PK = "id" (= auth.uid()).  This covers users whose signup
      // profile insert failed and users predating the profiles table.
      await ensureProfileExists(resolvedUser);

      const [profileRow, progRow, sessionRows, weightMap] = await Promise.all([
        loadProfile(uid),
        loadProgramme(uid),
        loadSessions(uid),
        loadWorkingWeights(uid),
      ]);
      console.log('[App] loadUserData — profileRow:', profileRow);
      console.log('[App] loadUserData — progRow:', progRow);
      console.log('[App] loadUserData — sessionRows count:', sessionRows.length);
      console.log('[App] loadUserData — weightMap:', weightMap);

      // Apply profile — profiles table has: id, name, language, email, username, created_at
      if (profileRow) {
        if (profileRow.language) setLang(profileRow.language);
        if (profileRow.name)     setProfile(p => ({ ...p, name: profileRow.name }));
        // Social fields
        setUsername(profileRow.username || null);
        if (profileRow.privacy_settings) setPrivacySettings(profileRow.privacy_settings);
        // Custom exercises
        if (Array.isArray(profileRow.custom_exercises)) {
          setCustomExercises(profileRow.custom_exercises);
        }
        // Load avatar — also cache locally for instant display on next open
        if (profileRow.avatar_url) {
          setAvatarUrl(profileRow.avatar_url);
          try { localStorage.setItem('hex_avatar', profileRow.avatar_url); } catch {}
        }

        // One-time email backfill: populate profiles.email for users who signed up
        // before the email column was added (they can then log in by username).
        if (!profileRow.email && resolvedUser.email) {
          supabase.from('profiles')
            .update({ email: resolvedUser.email })
            .eq('id', uid)
            .then(() => console.log('[App] loadUserData — email backfilled'))
            .catch(() => {});
        }
      }

      // Apply working weights from DB
      if (Object.keys(weightMap).length > 0) {
        setWeights(w => ({ ...w, ...weightMap }));
      } else if (sessionRows.length > 0) {
        // ── Backfill: working_weights table is empty but the user has session history.
        // Extract the most-recent weight for each exercise from sessions (sorted
        // oldest→newest so later entries naturally win) and save them to the DB.
        // This is a one-time migration for users who existed before FIX 1 was live.
        const backfill = {};
        const sorted = [...sessionRows].sort((a, b) => new Date(a.date) - new Date(b.date));
        for (const s of sorted) {
          for (const ex of (s.data?.exercises || [])) {
            if (ex.bodyweight || !ex.name) continue;
            const w = typeof ex.weight === 'number' ? ex.weight : parseFloat(ex.weight);
            if (Number.isFinite(w) && w > 0) backfill[ex.name.trim()] = w;
          }
        }
        if (Object.keys(backfill).length > 0) {
          console.log('[App] loadUserData — backfilling working_weights from history:', Object.keys(backfill));
          setWeights(prev => ({ ...prev, ...backfill }));
          upsertAllWorkingWeights(uid, backfill).catch(e =>
            console.warn('[App] loadUserData — backfill upsert failed:', e)
          );
        }
      }

      // Apply session history — exercises live in data.exercises (jsonb column)
      if (sessionRows.length > 0) {
        const hist = sessionRows.map(r => ({
          id: r.id, date: r.date, name: r.name,
          exercises: r.data?.exercises || [],
          volume: r.data?.exercises
            ? r.data.exercises.reduce((s, ex) => (!ex.bodyweight && ex.weight) ? s + ex.weight * (ex.sets || 1) : s, 0)
            : 0,
        }));
        setHistory(hist);
        // Rebuild streak from history
        const newStreak = [false,false,false,false,false];
        hist.forEach(s => {
          const d = new Date(s.date).getDay();
          if (d < 5) newStreak[d] = true;
        });
        setStreak(newStreak);
      }

      // ── Tracked lifts — load from profile or auto-pick from programme ─────────
      {
        let slots = profileRow?.tracked_lifts;
        if (!slots || slots.length === 0) {
          // Auto-select up to 4 weighted exercises from the active programme
          const candidates = extractProgrammeExercises(progRow);
          if (candidates.length > 0) {
            const shuffled = [...candidates].sort(() => Math.random() - 0.5);
            slots = shuffled.slice(0, 4);
          } else {
            slots = [null, null, null, null];
          }
          // Save auto-selection so it won't randomise again on next load
          saveTrackedLifts(uid, slots).catch(e => console.warn('[App] saveTrackedLifts failed:', e));
        }
        // Normalise to exactly 4 slots
        while (slots.length < 4) slots.push(null);
        setTrackedLifts(slots.slice(0, 4));
      }

      // ── Route: programme present → home screen, absent → welcome/onboarding ──
      // progRow comes from loadProgramme which filters active=true and takes the
      // newest row, so it is either a valid row or null.  Routing is decided here
      // and nowhere else — never driven by cached localStorage phase.
      if (progRow) {
        programmeIdRef.current = progRow.id;   // capture DB row UUID for session inserts
        // mode lives inside the data jsonb column (no top-level "mode" column)
        const mode = progRow.data?.mode || progRow.name;
        setProgrammeMode(mode);

        if (mode === 'imported' && progRow.data?.importedProgramme) {
          const imp = progRow.data.importedProgramme;
          setImportedProgramme(imp);
          const wk = progRow.data.currentWeek || 1;
          setCurrentWeek(wk);
          currentWeekRef.current = wk;
          const sess = sessionForTodayImported(imp, wk);
          setCurrentSession(sess);
          if (progRow.data.editedKeys) setEditedKeys(progRow.data.editedKeys);
        } else if (mode === 'auto' && progRow.data?.programme) {
          const prog = progRow.data.programme;
          const hist2 = sessionRows.map(r => ({
            id: r.id, date: r.date, name: r.name,
            exercises: r.data?.exercises || [], volume: 0,
          }));
          const flagged = flagProgress(prog, hist2);
          setProgramme(flagged);
          setCurrentSession(flagged[0] || null);
          if (progRow.data.editedKeys) setEditedKeys(progRow.data.editedKeys);
        }

        // Always go to the home screen — a programme row existing is the only
        // signal needed.  Never fall through to welcome for a returning user.
        console.log('[App] loadUserData — programme found, routing to app');
        setPhase('app');

        // FIX 6 — Show username modal after the user is on the main home screen,
        // not during onboarding or on the first tap of the Bros tab.
        // profileRow.username is null for users who haven't set one yet.
        if (!profileRow?.username) {
          setShowUsernameModal(true);
        }
      } else {
        // Genuinely new user with no programme yet → show welcome/onboarding
        console.log('[App] loadUserData — no programme, routing to welcome');
        setPhase('welcome');
      }

      // ── Process any pending invite link ──────────────────────────────────────
      if (pendingInviteRef.current) {
        const code = pendingInviteRef.current;
        pendingInviteRef.current = null;
        try {
          const { inviterName } = await acceptInvite(code, uid);
          showToast(`You and ${inviterName} are now Gym Bros! 🤝`);
        } catch (e) {
          const msg = e?.message;
          if (msg === 'expired') showToast('Invite link has expired');
          else if (msg === 'self') showToast("That's your own invite link!");
          else if (msg === 'invalid') showToast('Invalid invite link');
          // else silently ignore (e.g. already friends)
        }
      }
    } catch {
      setNetError(true);
    } finally {
      setDataLoading(false);
      if (Capacitor.isNativePlatform()) {
        SplashScreen.hide({ fadeOutDuration: 500 });
      }
    }
  }, []);

  const resetAppState = useCallback(() => {
    setPhase('welcome');
    setProgrammeMode('auto');
    setImportedProgramme(null);
    setCurrentWeek(1);
    setProfile(defaultProfile);
    setWeights(defaultWeights);
    setProgramme([]);
    setCurrentSession(null);
    setCompletedSets({});
    setHistory([]);
    setStreak([false,false,false,false,false]);
    setActiveTab('home');
    setChatMessages([]);
    setLastWeightAdded(null);
    setEditedKeys([]);
    setTrackedLifts(null);
  }, []);

  // ── Helpers ────────────────────────────────────────────────────────────────
  const showToast = useCallback((msg) => {
    setToast(msg);
    setTimeout(() => setToast(null), 2200);
  }, []);

  const triggerConfetti = useCallback(() => {
    setShowConfetti(true);
    setTimeout(() => setShowConfetti(false), 1200);
  }, []);

  const markEdited = useCallback((key) => {
    setEditedKeys(prev => prev.includes(key) ? prev : [...prev, key]);
  }, []);

  // ── Persist programme to Supabase whenever it changes ────────────────────
  const saveProgrammeToDb = useCallback(async (mode, data) => {
    const uid = userRef.current?.id;
    if (!uid) return;
    await saveProgramme(uid, mode, data);
  }, []);

  // ── Shared DB error handler ───────────────────────────────────────────────
  const handleDbError = useCallback((context, err) => {
    console.error(`[App] DB error in ${context}:`, err);
    showToast(`⚠ Sync error (${context}): ${err?.message ?? 'check console'}`);
  }, [showToast]);

  // ── Phase transitions ─────────────────────────────────────────────────────
  const enterApp = useCallback(async (prof, wts) => {
    const prog = buildProgramme(prof, wts);
    const flagged = flagProgress(prog, []);
    setProfile(prof);
    setWeights(wts);
    setProgramme(flagged);
    setCurrentSession(flagged[0] || null);
    setCompletedSets({});
    setProgrammeMode('auto');
    setPhase('app');
    setActiveTab('home');
    setEditedKeys([]);

    const uid = userRef.current?.id;
    console.log('[App] enterApp — uid:', uid);
    if (uid) {
      try {
        // Do NOT upsert wts here — the onboarding weights use short-key aliases
        // (bench, squat, ohp …) that would corrupt the working_weights table.
        // Working weights are written with full exercise names exclusively by
        // finishSession after every session completion.
        const [, progSaved] = await Promise.all([
          upsertProfile(uid, { name: prof.name, lang }),
          saveProgramme(uid, 'auto', { programme: flagged, editedKeys: [] }),
        ]);
        if (progSaved?.[0]?.id) programmeIdRef.current = progSaved[0].id;
        console.log('[App] enterApp — all DB writes OK, progId:', programmeIdRef.current);
      } catch (err) { handleDbError('enterApp', err); }
    }
  }, [lang, handleDbError]);

  const enterAppWithImport = useCallback(async (imported) => {
    const session = sessionForTodayImported(imported, 1);
    setImportedProgramme(imported);
    setCurrentSession(session);
    setCurrentWeek(1);
    setCompletedSets({});
    setProgrammeMode('imported');
    setPhase('app');
    setActiveTab('home');
    setEditedKeys([]);
    if (imported.workingWeights) setWeights(imported.workingWeights);
    if (imported.profileSeed)    setProfile(p => ({ ...p, ...imported.profileSeed }));

    const uid = userRef.current?.id;
    console.log('[App] enterAppWithImport — uid:', uid);
    if (uid) {
      try {
        // Normalise workingWeights keys to canonical library names before saving.
        // The imported JSON may use short-key aliases ("bench", "ohp") or
        // non-canonical names ("Conventional deadlift") — map them all.
        const saves = [
          saveProgramme(uid, 'imported', { importedProgramme: imported, currentWeek: 1, editedKeys: [] }),
        ];
        if (imported.workingWeights && Object.keys(imported.workingWeights).length > 0) {
          const normalisedWW = {};
          for (const [k, v] of Object.entries(imported.workingWeights)) {
            const canonical = normalizeToCanonical(k);
            if (canonical) normalisedWW[canonical] = v;
          }
          if (Object.keys(normalisedWW).length > 0) {
            setWeights(prev => ({ ...prev, ...normalisedWW }));
            saves.push(upsertAllWorkingWeights(uid, normalisedWW));
          }
        }
        const [progSaved] = await Promise.all(saves);
        if (progSaved?.[0]?.id) programmeIdRef.current = progSaved[0].id;
        console.log('[App] enterAppWithImport — all DB writes OK, progId:', programmeIdRef.current);
      } catch (err) { handleDbError('enterAppWithImport', err); }
    }
  }, [handleDbError]);

  const rebuildProgramme = useCallback(async (newProfile, newWeights) => {
    const prog = buildProgramme(newProfile, newWeights);
    const flagged = flagProgress(prog, history);
    setProgramme(flagged);
    setCurrentSession(flagged[0] || null);
    setCompletedSets({});
    setEditedKeys([]);
    showToast('Programme rebuilt ✓');

    const uid = userRef.current?.id;
    console.log('[App] rebuildProgramme — uid:', uid);
    if (uid) {
      try {
        // Do NOT upsert newWeights — the weights state is a merged object that
        // still contains short-key aliases from the initial defaultWeights.
        // Working weights are maintained exclusively by finishSession.
        await Promise.all([
          upsertProfile(uid, { name: newProfile.name, lang }),
          saveProgramme(uid, 'auto', { programme: flagged, editedKeys: [] }),
        ]);
        console.log('[App] rebuildProgramme — all DB writes OK');
      } catch (err) { handleDbError('rebuildProgramme', err); }
    }
  }, [history, showToast, lang, handleDbError]);

  const updateWeights = useCallback(async (newWeights) => {
    setWeights(newWeights);
    setLastWeightAdded(Date.now());
    const uid = userRef.current?.id;
    if (uid) {
      try {
        await upsertAllWorkingWeights(uid, newWeights);
      } catch (err) { handleDbError('updateWeights', err); }
    }
  }, [handleDbError]);

  // Persist lang change to profile
  const handleSetLang = useCallback(async (newLang) => {
    setLang(newLang);
    const uid = userRef.current?.id;
    if (uid) {
      try {
        await upsertProfile(uid, { name: profile.name, lang: newLang });
      } catch (err) { handleDbError('setLang', err); }
    }
  }, [profile, handleDbError]);

  // ── Tracked lifts ─────────────────────────────────────────────────────────
  const updateTrackedLifts = useCallback(async (newLifts) => {
    setTrackedLifts(newLifts);
    const uid = userRef.current?.id;
    if (uid) {
      try {
        await saveTrackedLifts(uid, newLifts);
      } catch (err) { handleDbError('updateTrackedLifts', err); }
    }
  }, [handleDbError]);

  // ── Custom exercises ──────────────────────────────────────────────────────
  const addCustomExercise = useCallback(async (exercise) => {
    setCustomExercises(prev => {
      const updated = [...prev, exercise];
      const uid = userRef.current?.id;
      if (uid) {
        saveCustomExercises(uid, updated).catch(err =>
          console.warn('[App] saveCustomExercises failed (non-fatal):', err)
        );
      }
      return updated;
    });
  }, []);

  // ── Avatar ────────────────────────────────────────────────────────────────
  const saveAvatarUrl = useCallback(async (url) => {
    setAvatarUrl(url);
    try { localStorage.setItem('hex_avatar', url); } catch {}
    const uid = userRef.current?.id;
    if (uid) {
      try { await upsertProfile(uid, { avatar_url: url }); }
      catch (err) { console.warn('[App] saveAvatarUrl DB write failed (non-fatal):', err); }
    }
  }, []);

  // ── Programme field editors (AUTO) ────────────────────────────────────────
  const updateAutoExerciseField = useCallback((sessionIdx, exIdx, field, value) => {
    const editKey = `auto_s${sessionIdx}_e${exIdx}_${field}`;
    markEdited(editKey);

    setProgramme(prev => {
      const next = prev.map((s, si) =>
        si !== sessionIdx ? s : {
          ...s,
          exercises: s.exercises.map((ex, ei) => ei !== exIdx ? ex : { ...ex, [field]: value }),
        }
      );
      const uid = userRef.current?.id;
      if (uid) saveProgramme(uid, 'auto', { programme: next, editedKeys: [editKey] })
        .catch(err => console.error('[App] updateAutoExerciseField save error:', err));
      return next;
    });

    setCurrentSession(prev => {
      if (!prev) return prev;
      return {
        ...prev,
        exercises: prev.exercises.map((ex, ei) => ei !== exIdx ? ex : { ...ex, [field]: value }),
      };
    });
  }, [markEdited]);

  const updateAutoSessionField = useCallback((sessionIdx, field, value) => {
    const editKey = `auto_s${sessionIdx}_${field}`;
    markEdited(editKey);
    setProgramme(prev => {
      const next = prev.map((s, si) => si !== sessionIdx ? s : { ...s, [field]: value });
      const uid = userRef.current?.id;
      if (uid) saveProgramme(uid, 'auto', { programme: next, editedKeys: [editKey] })
        .catch(err => console.error('[App] updateAutoSessionField save error:', err));
      return next;
    });
    setCurrentSession(prev => prev ? { ...prev, [field]: value } : prev);
  }, [markEdited]);

  // ── Programme field editors (IMPORTED) ───────────────────────────────────
  const updateImportedExerciseField = useCallback((weekNum, sessionDay, exIdx, field, value) => {
    const editKey = `imp_w${weekNum}_${sessionDay}_e${exIdx}_${field}`;
    markEdited(editKey);

    setImportedProgramme(imp => {
      const next = {
        ...imp,
        weeks: imp.weeks.map(w =>
          w.weekNumber !== weekNum ? w : {
            ...w,
            sessions: w.sessions.map(s =>
              s.day !== sessionDay ? s : {
                ...s,
                exercises: (s.exercises || []).map((ex, ei) => ei !== exIdx ? ex : { ...ex, [field]: value }),
              }
            ),
          }
        ),
      };
      const uid = userRef.current?.id;
      if (uid) saveProgramme(uid, 'imported', { importedProgramme: next, currentWeek, editedKeys: [editKey] })
        .catch(err => console.error('[App] updateImportedExerciseField save error:', err));
      return next;
    });

    setCurrentSession(prev => {
      if (!prev) return prev;
      return {
        ...prev,
        exercises: prev.exercises.map((ex, ei) => ei !== exIdx ? ex : { ...ex, [field]: value }),
      };
    });
  }, [markEdited, currentWeek]);

  const updateImportedSessionField = useCallback((weekNum, sessionDay, field, value) => {
    const editKey = `imp_w${weekNum}_${sessionDay}_${field}`;
    markEdited(editKey);
    setImportedProgramme(imp => {
      const next = {
        ...imp,
        weeks: imp.weeks.map(w =>
          w.weekNumber !== weekNum ? w : {
            ...w,
            sessions: w.sessions.map(s => s.day !== sessionDay ? s : { ...s, [field]: value }),
          }
        ),
      };
      const uid = userRef.current?.id;
      if (uid) saveProgramme(uid, 'imported', { importedProgramme: next, currentWeek, editedKeys: [editKey] })
        .catch(err => console.error('[App] updateImportedSessionField save error:', err));
      return next;
    });
    setCurrentSession(prev => prev ? { ...prev, [field]: value } : prev);
  }, [markEdited, currentWeek]);

  // ── Session finish ─────────────────────────────────────────────────────────
  const finishSession = useCallback(async (editedExercises) => {
    if (!currentSession) return;
    const exList = editedExercises || currentSession.exercises;
    const vol = exList.reduce((sum, ex) => {
      if (ex.bodyweight || !ex.weight) return sum;
      return sum + ex.weight * ex.sets;
    }, 0);

    // Always use a proper UUID so Supabase accepts the id column regardless of type
    const sessionId = crypto.randomUUID();
    const logged = {
      id:          sessionId,
      date:        new Date().toISOString(),
      name:        currentSession.name,
      exercises:   exList,
      volume:      vol,
      // DB schema fields (picked up by insertSession)
      programmeId: programmeIdRef.current ?? null,
      weekNumber:  currentWeekRef.current ?? null,
      block:       currentSession.block   ?? null,
    };

    // Update React state immediately (optimistic UI)
    const newHistory = [...history, logged];
    setHistory(newHistory);

    if (programmeMode === 'auto' && programme.length > 0) {
      const idx = programme.findIndex(s => s.name === currentSession.name);
      const nextIdx = (idx + 1) % programme.length;
      const flagged = flagProgress(programme, newHistory);
      setProgramme(flagged);
      setCurrentSession(flagged[nextIdx]);
    }
    const today = new Date().getDay();
    const newStreak = [...streak];
    newStreak[today % 5] = true;
    setStreak(newStreak);
    setCompletedSets({});
    triggerConfetti();

    // Persist to Supabase — log success/failure visibly
    const uid = userRef.current?.id;
    console.log('[App] finishSession — uid:', uid, 'sessionId:', sessionId);

    if (!uid) {
      console.warn('[App] finishSession — no user id, skipping DB write');
      showToast('Session saved locally (not synced — please sign in)');
      return;
    }

    try {
      const saved = await insertSession(uid, logged);
      const finalId = saved?.id ?? sessionId;

      // Write individual set rows
      await insertSets(uid, finalId, exList);

      // Refresh own leaderboard score so friends see updated numbers (fire-and-forget)
      updateLeaderboardScore(uid).catch(() => {});

      // FIX 1 — Activity feed: use correct type 'session_completed' with full data
      insertActivity(uid, 'session_completed', {
        session_name: currentSession.name,
        volume: vol,
        exercise_count: exList.length,
        week_number: currentWeekRef.current ?? null,
        session_id: finalId,
      }).catch(() => {});

      showToast('Session saved ✓');

      // ── Upsert working weights for every weighted exercise in this session ──
      // Best-effort: a failure here must not roll back the session save or
      // change the toast that was already shown to the user.
      try {
        const weightUpdates = {};
        for (const ex of exList) {
          if (ex.bodyweight || !ex.name) continue;
          const w = typeof ex.weight === 'number' ? ex.weight : parseFloat(ex.weight);
          if (Number.isFinite(w) && w > 0) weightUpdates[ex.name.trim()] = w;
        }
        if (Object.keys(weightUpdates).length > 0) {
          // Update local state immediately so the Progress page reflects new weights
          setWeights(prev => ({ ...prev, ...weightUpdates }));
          await upsertAllWorkingWeights(uid, weightUpdates);
          console.log('[App] finishSession — working weights upserted:', Object.keys(weightUpdates));

          // FIX 2 — PR detection: for each updated exercise, check if the new
          // weight exceeds any previously logged weight (excluding this session).
          // Fire-and-forget per exercise so a single failure doesn't block others.
          for (const [exerciseName, newWeight] of Object.entries(weightUpdates)) {
            (async () => {
              try {
                const { data: prevSets } = await supabase
                  .from('sets')
                  .select('weight')
                  .eq('user_id', uid)
                  .ilike('exercise_name', exerciseName)
                  .neq('session_id', finalId)   // exclude the just-inserted sets
                  .order('weight', { ascending: false })
                  .limit(1);

                const previousMax = parseFloat(prevSets?.[0]?.weight) || 0;
                if (newWeight > previousMax) {
                  console.log(`[App] finishSession — PR! ${exerciseName}: ${previousMax}→${newWeight}kg`);
                  await insertActivity(uid, 'new_pr', {
                    exercise_name: exerciseName,
                    weight: newWeight,
                    previous_weight: previousMax,
                  });
                }
              } catch { /* non-fatal — PR logging should never surface errors */ }
            })();
          }
        }
      } catch (wErr) {
        console.warn('[App] finishSession — working weights upsert failed (non-fatal):', wErr);
      }
    } catch (err) {
      console.error('[App] finishSession DB error:', err);
      showToast(`⚠ Sync failed: ${err?.message ?? 'unknown error'}`);
    }
  }, [currentSession, history, programme, programmeMode, streak, triggerConfetti, showToast]);

  // ── Persist current week for imported programmes ──────────────────────────
  const handleSetCurrentWeek = useCallback((wk) => {
    setCurrentWeek(wk);
    const uid = userRef.current?.id;
    if (uid && programmeMode === 'imported' && importedProgramme) {
      saveProgramme(uid, 'imported', {
        importedProgramme, currentWeek: wk, editedKeys,
      }).catch(() => {});
    }
  }, [programmeMode, importedProgramme, editedKeys]);

  // ── Reset all user data ───────────────────────────────────────────────────
  const resetAllData = useCallback(async () => {
    const uid = userRef.current?.id;
    if (!uid) return;
    console.log('[App] resetAllData — deleting all data for uid:', uid);
    try {
      // Delete in FK-safe order: sets first (child), then sessions, weights, programme
      await supabase.from('sets').delete().eq('user_id', uid);
      await supabase.from('sessions').delete().eq('user_id', uid);
      await supabase.from('working_weights').delete().eq('user_id', uid);
      await supabase.from('programmes').delete().eq('user_id', uid);
      console.log('[App] resetAllData — all rows deleted');
      // Wipe local state and send user back to welcome/onboarding
      resetAppState();
      showToast('All data deleted ✓');
    } catch (err) {
      console.error('[App] resetAllData error:', err);
      showToast(`⚠ Delete failed: ${err?.message ?? 'unknown error'}`);
    }
  }, [showToast, resetAppState]);

  // ── Logout ─────────────────────────────────────────────────────────────────
  const logout = useCallback(async () => {
    await supabase.auth.signOut();
    // resetAppState is called via onAuthStateChange listener
  }, []);

  // ── Delete account ─────────────────────────────────────────────────────────
  const deleteAccount = useCallback(async () => {
    const uid = userRef.current?.id;
    if (!uid) return;

    isDeletingRef.current = true;
    console.log('[App] deleteAccount — uid:', uid);

    try {
      // 1. Delete all user data in FK-safe order
      await supabase.from('sets').delete().eq('user_id', uid);
      await supabase.from('sessions').delete().eq('user_id', uid);
      await supabase.from('working_weights').delete().eq('user_id', uid);
      await supabase.from('programmes').delete().eq('user_id', uid);
      await supabase.from('profiles').delete().eq('id', uid);
      // 2. Delete the auth.users row via the security-definer RPC
      //    Requires this SQL in Supabase:
      //    create or replace function delete_user() returns void language plpgsql
      //    security definer as $$ begin delete from auth.users where id = auth.uid(); end; $$;
      await supabase.rpc('delete_user');
    } catch (err) {
      // Log but do NOT rethrow — always proceed to cleanup so the user is
      // never left on a crashed screen even if a DB step fails.
      console.error('[App] deleteAccount — data/rpc error (continuing cleanup):', err);
    } finally {
      // 3. Always run in this order regardless of errors above:
      //    sign out → wipe localStorage → clear React state → show login
      try { await supabase.auth.signOut(); } catch { /* ignore */ }
      localStorage.clear();
      setNetError(false);
      resetAppState();
      setUser(null);
      setAuthState('unauthenticated');
      isDeletingRef.current = false;
    }
  }, [resetAppState]);

  // ── Tab navigation (username modal is triggered by loadUserData, not here) ──
  const handleSetActiveTab = useCallback((tab) => {
    setActiveTab(tab);
  }, []);

  // ── appState bundle ────────────────────────────────────────────────────────
  const appState = {
    phase, programmeMode, importedProgramme, currentWeek, setCurrentWeek: handleSetCurrentWeek,
    profile, setProfile, weights, updateWeights, setWeights,
    programme, setProgramme, rebuildProgramme,
    currentSession, setCurrentSession,
    completedSets, setCompletedSets,
    history, finishSession,
    streak,
    totalSessions: history.length,
    currentStreakCount: streak.filter(Boolean).length,
    activeTab, setActiveTab: handleSetActiveTab,
    chatMessages, setChatMessages,
    lastWeightAdded,
    showToast, triggerConfetti,
    programmeView, setProgrammeView,
    calendarView, setCalendarView,
    accountView, setAccountView,
    editedKeys,
    lang, setLang: handleSetLang,
    t: getT(lang),
    updateAutoExerciseField, updateAutoSessionField,
    updateImportedExerciseField, updateImportedSessionField,
    logout,
    resetAllData,
    deleteAccount,
    user,
    trackedLifts, updateTrackedLifts,
    username, setUsername,
    privacySettings, setPrivacySettings,
    showUsernameModal, setShowUsernameModal,
    customExercises, addCustomExercise,
    avatarUrl, saveAvatarUrl,
  };

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div style={{
      position: 'relative', width: '100%',
      height: '100%', display: 'flex', flexDirection: 'column',
      overflow: 'hidden', background: C.bg,
    }}>
      <Toast message={toast} />
      <ConfettiBurst active={showConfetti} />

      {/* Auth loading */}
      {authState === 'loading' && <LoadingScreen message="Signing in…" />}

      {/* Network error — only when authenticated; never shown after sign-out or account deletion */}
      {netError && authState === 'authenticated' && <NetworkError onRetry={() => user && loadUserData(user)} />}

      {/* Data loading overlay (after auth, before data arrives) */}
      {authState === 'authenticated' && dataLoading && <LoadingScreen message="Loading your data…" />}

      {/* Auth screens */}
      {authState === 'unauthenticated' && !netError && (
        <AuthScreen
          lang={lang}
          onLangChange={() => setLang(l => l === 'ar' ? 'en' : 'ar')}
          onAuth={() => {
          supabase.auth.getSession().then(({ data: { session } }) => {
            if (session?.user) {
              setUser(session.user);
              setAuthState('authenticated');
              loadUserData(session.user);
            }
          });
        }} />
      )}

      {/* Main app */}
      {authState === 'authenticated' && !dataLoading && !netError && (
        <AnimatePresence mode="wait">
          {phase === 'welcome' && (
            <motion.div key="welcome" style={{ width: '100%', height: '100%', display: 'flex', flexDirection: 'column', overflowY: 'auto', WebkitOverflowScrolling: 'touch' }}>
              <WelcomeScreen lang={lang} onBuild={() => setPhase('onboarding')} onManual={() => setPhase('manual_builder')} onImport={() => setPhase('import')} />
            </motion.div>
          )}
          {phase === 'manual_builder' && (
            <motion.div key="manual_builder" style={{ width: '100%', height: '100%', display: 'flex', flexDirection: 'column' }}>
              <ManualProgrammeBuilder
                onComplete={enterAppWithImport}
                onBack={() => setPhase('welcome')}
                lang={lang}
                t={getT(lang)}
              />
            </motion.div>
          )}
          {phase === 'onboarding' && (
            <motion.div key="onboarding" style={{ width: '100%', height: '100%', display: 'flex', flexDirection: 'column' }}>
              <Onboarding onComplete={enterApp} onBack={() => setPhase('welcome')} lang={lang} />
            </motion.div>
          )}
          {phase === 'import' && (
            <motion.div key="import" style={{ width: '100%', height: '100%', display: 'flex', flexDirection: 'column' }}>
              <ImportScreen onImport={enterAppWithImport} onBack={() => setPhase('welcome')} lang={lang} />
            </motion.div>
          )}
          {phase === 'app' && (
            <AppShell key="app" state={appState} />
          )}
        </AnimatePresence>
      )}
    </div>
  );
}

// ─── AppShell ──────────────────────────────────────────────────────────────────
function AppShell({ state }) {
  const {
    activeTab, setActiveTab,
    programmeView, setProgrammeView,
    calendarView, setCalendarView,
    accountView, setAccountView,
    lang, t,
    showUsernameModal, setShowUsernameModal,
    user, setUsername,
  } = state;

  const tabs = {
    home:     <HomeTab     state={state} />,
    today:    <TodayTab    state={state} />,
    progress: <ProgressTab state={state} />,
    gymbros:  <GymBrosTab  state={state} />,
    profile:  <ProfileTab  state={state} />,
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden', position: 'relative' }}
    >
      <div style={{ flex: 1, overflow: 'hidden', position: 'relative' }}>
        <AnimatePresence mode="wait">
          <motion.div
            key={activeTab}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            style={{
              height: '100%',
              // PT tab owns its own scroll (messages area) and its own bottom bar,
              // so skip the global paddingBottom that reserves space for the nav.
              overflowY: 'auto',
              // Reserve space for nav bar (49px) + home indicator safe area so
              // the last list item is never hidden behind the bottom nav.
              paddingBottom: Capacitor.isNativePlatform() ? 'calc(78px + max(env(safe-area-inset-bottom), 8px))' : 'calc(49px + env(safe-area-inset-bottom))',
              WebkitOverflowScrolling: 'touch',
            }}
          >
            {tabs[activeTab]}
          </motion.div>
        </AnimatePresence>
      </div>

      <BottomNav activeTab={activeTab} setActiveTab={setActiveTab} t={t} lang={lang} />

      <AnimatePresence>
        {programmeView && (
          <ProgrammePage key="programme-page" state={state} onBack={() => setProgrammeView(false)} />
        )}
      </AnimatePresence>

      <AnimatePresence>
        {calendarView && (
          <CalendarPage key="calendar-page" state={state} onBack={() => setCalendarView(false)} />
        )}
      </AnimatePresence>

      <AnimatePresence>
        {accountView && (
          <AccountPage key="account-page" state={state} onBack={() => setAccountView(false)} />
        )}
      </AnimatePresence>

      {/* Username setup modal — shown once when a user first opens Gym Bros */}
      <AnimatePresence>
        {showUsernameModal && user && (
          <UsernameModal
            key="username-modal"
            userId={user.id}
            onComplete={(uname) => {
              setUsername(uname);
              setShowUsernameModal(false);
            }}
          />
        )}
      </AnimatePresence>
    </motion.div>
  );
}
