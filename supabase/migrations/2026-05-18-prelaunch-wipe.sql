-- ──────────────────────────────────────────────────────────────────────────
-- PRE-LAUNCH DATA WIPE
--
-- Resets every user-generated row across the database while keeping
-- the schema (tables, policies, indexes, RLS, functions) intact.
-- After running, the app behaves like a brand-new deployment — first
-- user to sign up gets a clean slate.
--
-- ⚠️ DESTRUCTIVE — cannot be undone. Verify the project URL in the
-- Supabase Dashboard top-right matches your TARGET project before
-- you click Run. Recommended: take a manual backup snapshot first
-- (Database → Backups → "Take backup").
--
-- Run from:
--   Supabase Dashboard → SQL Editor → New query → paste this → Run
--
-- The SQL editor runs as the `postgres` superuser by default, which
-- has access to both `public` and `auth` schemas — so both parts
-- below succeed in a single run.
-- ──────────────────────────────────────────────────────────────────────────

-- ─── Step 1: wipe user-data tables ───────────────────────────────────────
--
-- TRUNCATE ... CASCADE handles foreign key chains between these tables
-- automatically. Listed in safe order anyway to make the intent
-- obvious. RESTART IDENTITY resets any sequences (e.g. id auto-increments)
-- so the first new row starts at 1.

TRUNCATE TABLE
    public.league_members,
    public.leagues,
    public.activity_feed,
    public.invite_links,
    public.friendships,
    public.working_weights,
    public.sets,
    public.sessions,
    public.programmes,
    public.profiles
RESTART IDENTITY CASCADE;

-- ─── Step 2: delete auth users ───────────────────────────────────────────
--
-- Removes every row in auth.users. Profiles are gone from step 1, so
-- there's nothing dangling — these are now completely freed identities
-- (the email/phone can be re-used for a fresh signup).
--
-- This requires postgres superuser access — Supabase's SQL editor
-- has that by default for project owners. If this line errors with
-- "permission denied for table users", run it via the Dashboard's
-- Authentication → Users page instead (select all → delete).

DELETE FROM auth.users;
