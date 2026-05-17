-- ──────────────────────────────────────────────────────────────────────────
-- Leagues feature — schema + RLS
--
-- Run once in the Supabase SQL Editor (or via your migration tool of
-- choice). Idempotent — safe to re-run.
--
-- Tables:
--   leagues          — the league itself; admin_id is the creator.
--   league_members   — combined members + invites. A row's `status`
--                       is 'pending' (invite outstanding), 'accepted'
--                       (active member), or 'declined' (invitee said no).
--
-- Authorship rules:
--   • Anyone signed in can create a league. They become the admin and
--     are auto-inserted into league_members as accepted.
--   • Only the admin can insert new members (the invite flow).
--   • An invitee can update their own row to set status = 'accepted'
--     or 'declined'.
--   • An accepted member can DELETE their own row (leave the league).
--   • The admin can DELETE any row (kick a member).
-- ──────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS leagues (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 32),
    admin_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS leagues_admin_id_idx ON leagues(admin_id);

CREATE TABLE IF NOT EXISTS league_members (
    league_id    UUID NOT NULL REFERENCES leagues(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role         TEXT NOT NULL DEFAULT 'member'
                   CHECK (role IN ('admin', 'member')),
    status       TEXT NOT NULL DEFAULT 'accepted'
                   CHECK (status IN ('pending', 'accepted', 'declined')),
    invited_by   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    joined_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (league_id, user_id)
);

CREATE INDEX IF NOT EXISTS league_members_user_id_idx
    ON league_members(user_id);
CREATE INDEX IF NOT EXISTS league_members_status_idx
    ON league_members(status);

-- ──────────────────────────────────────────────────────────────────────────
-- Row-Level Security
-- ──────────────────────────────────────────────────────────────────────────

ALTER TABLE leagues          ENABLE ROW LEVEL SECURITY;
ALTER TABLE league_members   ENABLE ROW LEVEL SECURITY;

-- ── leagues ──────────────────────────────────────────────────────────────

-- SECURITY DEFINER helper used by both leagues and league_members
-- SELECT policies. Postgres applies RLS recursively when one policy
-- references its own table inside an EXISTS subquery — wrapping the
-- check in a SECURITY DEFINER function bypasses RLS for the inner
-- read and breaks the loop. Without this, "infinite recursion
-- detected in policy" errors fire on every league_members SELECT.
CREATE OR REPLACE FUNCTION public.is_league_accepted_member(
    p_league_id uuid,
    p_user_id   uuid
) RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.league_members
        WHERE league_id = p_league_id
          AND user_id   = p_user_id
          AND status    = 'accepted'
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_league_accepted_member(uuid, uuid)
    TO authenticated;

DROP POLICY IF EXISTS "Members can view their leagues" ON leagues;
CREATE POLICY "Members can view their leagues"
    ON leagues FOR SELECT
    USING (
        admin_id = auth.uid()
        OR public.is_league_accepted_member(leagues.id, auth.uid())
    );

DROP POLICY IF EXISTS "Authenticated users can create leagues" ON leagues;
CREATE POLICY "Authenticated users can create leagues"
    ON leagues FOR INSERT
    WITH CHECK (admin_id = auth.uid());

DROP POLICY IF EXISTS "Admin can update their league" ON leagues;
CREATE POLICY "Admin can update their league"
    ON leagues FOR UPDATE
    USING (admin_id = auth.uid())
    WITH CHECK (admin_id = auth.uid());

DROP POLICY IF EXISTS "Admin can delete their league" ON leagues;
CREATE POLICY "Admin can delete their league"
    ON leagues FOR DELETE
    USING (admin_id = auth.uid());

-- ── league_members ───────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Members can view league membership" ON league_members;
CREATE POLICY "Members can view league membership"
    ON league_members FOR SELECT
    USING (
        -- See your own row (so invitees can see pending invites)
        user_id = auth.uid()
        -- See all rows for a league you're an accepted member of —
        -- uses the SECURITY DEFINER function so the inner query
        -- doesn't trigger this policy recursively.
        OR public.is_league_accepted_member(league_id, auth.uid())
        -- Admin sees everything for their league
        OR EXISTS (
            SELECT 1 FROM leagues l
            WHERE l.id = league_members.league_id
              AND l.admin_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Admin can invite members" ON league_members;
CREATE POLICY "Admin can invite members"
    ON league_members FOR INSERT
    WITH CHECK (
        -- Admin inviting someone
        EXISTS (
            SELECT 1 FROM leagues l
            WHERE l.id = league_members.league_id
              AND l.admin_id = auth.uid()
        )
        -- Or the admin auto-inserting themselves on league creation
        OR (user_id = auth.uid() AND role = 'admin' AND status = 'accepted')
    );

DROP POLICY IF EXISTS "Member can update own status" ON league_members;
CREATE POLICY "Member can update own status"
    ON league_members FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Member can leave / admin can kick" ON league_members;
CREATE POLICY "Member can leave / admin can kick"
    ON league_members FOR DELETE
    USING (
        -- Member leaving
        user_id = auth.uid()
        -- Or admin kicking
        OR EXISTS (
            SELECT 1 FROM leagues l
            WHERE l.id = league_members.league_id
              AND l.admin_id = auth.uid()
        )
    );

-- ──────────────────────────────────────────────────────────────────────────
-- Enable realtime so clients see member-list changes live
-- ──────────────────────────────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE leagues;
ALTER PUBLICATION supabase_realtime ADD TABLE league_members;
