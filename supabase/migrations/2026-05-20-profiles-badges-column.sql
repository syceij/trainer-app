-- ──────────────────────────────────────────────────────────────────────────
-- Add `badges` jsonb column to profiles
--
-- Persists each user's earned trophies as a jsonb array of EarnedBadge
-- objects. Before this migration, badges were a UI placeholder —
-- ProfileView.swift and FriendProfilePage.swift returned a hardcoded
-- sample list (Jan/Mar/May monthlies, two Power trophies, Hero) so
-- every account showed the same six fake badges.
--
-- After this migration:
--   • Every existing row gets `[]` (no trophies — the correct launch
--     state for everyone).
--   • New rows default to `[]` too.
--   • The iOS app reads the column via Profile.badges /
--     FriendProfileRow.badges — both fields populate from the existing
--     SELECT, no extra round-trip.
--
-- The awarding logic (Monthly / Power / Hero / Lebron / Invincible)
-- that appends to this column is a separate milestone — for now the
-- column just sits at [] for everyone until a real evaluator ships.
--
-- Idempotent — safe to re-run.
-- ──────────────────────────────────────────────────────────────────────────

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS badges jsonb NOT NULL DEFAULT '[]'::jsonb;
