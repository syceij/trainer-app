/**
 * iOS Live Activities bridge — wraps the native LiveActivityPlugin via Capacitor.
 * All calls are no-ops on web / Android so no guard is needed at the call site.
 *
 * Usage:
 *   import { liveActivity } from '../lib/liveActivity.js';
 *
 *   await liveActivity.start({ sessionName, exerciseName, setsDone, setsTotal,
 *                              timerEndsAt, weightKg, reps });
 *   await liveActivity.update({ ... same keys ... });
 *   await liveActivity.end();
 *
 * timerEndsAt: Unix timestamp in SECONDS (Date.now()/1000 + durationSec),
 *              or 0 / omitted when no rest timer is active.
 */

import { Capacitor, registerPlugin } from '@capacitor/core';

// ── Settings ──────────────────────────────────────────────────────────────────
const PREF_KEY = 'hex_live_activity_enabled';

export function isLiveActivityEnabled() {
  return localStorage.getItem(PREF_KEY) !== 'false'; // default ON
}

export function setLiveActivityEnabled(enabled) {
  localStorage.setItem(PREF_KEY, enabled ? 'true' : 'false');
}

// ── Native plugin (iOS only) ──────────────────────────────────────────────────
const isNative = Capacitor.isNativePlatform();

// registerPlugin returns a no-op object on non-native platforms
const _plugin = isNative
  ? registerPlugin('LiveActivityPlugin')
  : null;

// ── Public API ────────────────────────────────────────────────────────────────
export const liveActivity = {
  /**
   * Start a new Live Activity for the given workout session.
   * Replaces any existing activity automatically (native side handles this).
   */
  async start(params) {
    if (!isNative || !isLiveActivityEnabled()) return;
    try {
      await _plugin.start({
        sessionName:   params.sessionName   ?? 'Workout',
        exerciseName:  params.exerciseName  ?? 'Exercise',
        setsDone:      params.setsDone      ?? 0,
        setsTotal:     params.setsTotal     ?? 1,
        timerEndsAt:   params.timerEndsAt   ?? 0,
        weightKg:      params.weightKg      ?? 0,
        reps:          params.reps          ?? 0,
      });
    } catch (e) {
      // Live Activities can be denied by user; swallow silently
      console.warn('[LiveActivity] start failed:', e);
    }
  },

  /**
   * Push a state update to the running Live Activity.
   * Call this whenever a set is completed or the rest timer changes.
   */
  async update(params) {
    if (!isNative || !isLiveActivityEnabled()) return;
    try {
      await _plugin.update({
        sessionName:   params.sessionName   ?? 'Workout',
        exerciseName:  params.exerciseName  ?? 'Exercise',
        setsDone:      params.setsDone      ?? 0,
        setsTotal:     params.setsTotal     ?? 1,
        timerEndsAt:   params.timerEndsAt   ?? 0,
        weightKg:      params.weightKg      ?? 0,
        reps:          params.reps          ?? 0,
      });
    } catch (e) {
      console.warn('[LiveActivity] update failed:', e);
    }
  },

  /** End and dismiss the Live Activity immediately. */
  async end() {
    if (!isNative) return;
    try {
      await _plugin.end();
    } catch (e) {
      console.warn('[LiveActivity] end failed:', e);
    }
  },
};
