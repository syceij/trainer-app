-- ──────────────────────────────────────────────────────────────────────────
-- delete_current_user() — RPC for "delete my account" button
--
-- Before this migration, the iOS app's "Delete Account" flow could only
-- wipe public-schema rows (programmes / sessions / sets / etc.) — it
-- couldn't touch auth.users, because that table is protected and
-- requires the service-role key. Result: the user's email stayed
-- "taken" forever and they couldn't re-register with the same address.
--
-- This function lets an authenticated user delete THEIR OWN auth row
-- via RPC. SECURITY DEFINER means it runs with the owner's
-- privileges (postgres) — bypassing RLS / table grants — but the body
-- restricts the delete to `auth.uid()`, so a user can never delete
-- anyone else.
--
-- Caller flow:
--   1. Wipe public-schema data (the existing resetUserData path).
--   2. Call delete_current_user() — drops the auth row + cascades
--      anything we missed via ON DELETE CASCADE foreign keys.
--   3. signOut() to clear the local session token (which is now
--      invalid anyway).
--
-- Idempotent — safe to re-run.
-- ──────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.delete_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  uid uuid;
BEGIN
  uid := auth.uid();
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;

  -- Belt-and-suspenders cleanup of public-schema rows. If FK ON DELETE
  -- CASCADE is set up correctly (it is on most tables), the auth.users
  -- DELETE below would handle this — but explicit deletes guarantee
  -- no orphan rows even if a future table forgets its CASCADE.
  DELETE FROM public.league_members WHERE user_id = uid;
  DELETE FROM public.leagues        WHERE admin_id = uid;
  DELETE FROM public.activity_feed  WHERE user_id = uid;
  DELETE FROM public.invite_links   WHERE user_id = uid;
  DELETE FROM public.friendships    WHERE user_id = uid OR friend_id = uid;
  DELETE FROM public.working_weights WHERE user_id = uid;
  DELETE FROM public.sets           WHERE user_id = uid;
  DELETE FROM public.sessions       WHERE user_id = uid;
  DELETE FROM public.programmes     WHERE user_id = uid;
  DELETE FROM public.profiles       WHERE id = uid;

  -- Finally, drop the auth identity itself. After this returns, the
  -- email is reusable for a fresh signup and the user's JWT is dead.
  DELETE FROM auth.users WHERE id = uid;
END;
$$;

-- Only authenticated callers can invoke this (anon role can't).
REVOKE ALL ON FUNCTION public.delete_current_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_current_user() TO authenticated;
