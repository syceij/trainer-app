-- ──────────────────────────────────────────────────────────────────────────
-- Push notifications schema
--
-- Tracks one row per (user × installed device) plus a per-user toggle
-- blob on profiles. The send-push Edge Function reads from
-- public.push_devices with the service role key (bypasses RLS) and
-- the app inserts/updates its own row with the user's JWT.
--
-- Run once via SQL Editor. Idempotent — safe to re-run.
-- ──────────────────────────────────────────────────────────────────────────

-- ─── push_devices ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.push_devices (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token  TEXT NOT NULL UNIQUE,
    platform      TEXT NOT NULL CHECK (platform IN ('ios','android','web')),
    -- is_sandbox = true for debug builds (Xcode), false for TestFlight/AppStore.
    -- Routes to api.sandbox.push.apple.com vs api.push.apple.com.
    is_sandbox    BOOLEAN NOT NULL DEFAULT FALSE,
    app_version   TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS push_devices_user_id_idx
    ON public.push_devices(user_id);

-- ─── notification_prefs column ──────────────────────────────────────────
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS notification_prefs JSONB NOT NULL DEFAULT '{}';

-- ─── RLS ────────────────────────────────────────────────────────────────
ALTER TABLE public.push_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "push_devices: own insert" ON public.push_devices;
CREATE POLICY "push_devices: own insert"
    ON public.push_devices FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "push_devices: own update" ON public.push_devices;
CREATE POLICY "push_devices: own update"
    ON public.push_devices FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "push_devices: own delete" ON public.push_devices;
CREATE POLICY "push_devices: own delete"
    ON public.push_devices FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "push_devices: own select" ON public.push_devices;
CREATE POLICY "push_devices: own select"
    ON public.push_devices FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());
