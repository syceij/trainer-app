-- ──────────────────────────────────────────────────────────────────────────
-- Username: allow capitals, keep uniqueness case-insensitive
--
-- Before this migration, both iOS and the web client lowercased every
-- typed username before insert, so the DB column was effectively
-- lowercase-only. Users couldn't have stylised usernames like "JohnDoe".
--
-- This migration:
--   1. Enables the `citext` extension (case-insensitive text type).
--   2. Converts profiles.username to citext — original casing is
--      preserved for display, but '=' / LIKE / unique-index comparisons
--      are all case-insensitive at the DB level.
--   3. Adds a unique index so "JohnDoe" can't be claimed if "johndoe"
--      already exists (and vice-versa).
--
-- Paired with the client-side change that removes the lowercasing step
-- in SignupView.swift / AuthScreen.jsx and broadens the regex to
-- [a-zA-Z0-9_].
--
-- Idempotent — safe to re-run.
-- ──────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS citext;

ALTER TABLE public.profiles
  ALTER COLUMN username TYPE citext;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_unique_idx
  ON public.profiles (username);
