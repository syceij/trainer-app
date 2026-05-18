-- ──────────────────────────────────────────────────────────────────────────
-- Performance indexes — user_id lookups on the hot tables
--
-- Postgres auto-creates an index on the primary key of each table but
-- NOT on foreign-key columns. Every query in this app filters by
-- `user_id` (it's how RLS scopes data), so without these indexes
-- Postgres does a Seq Scan over the whole table on every read.
--
-- Run once. All statements are IF NOT EXISTS so re-running is safe.
--
-- Expected impact (per audit 2026-05-19):
--   • Leaderboard recompute (4 parallel queries on sets/working_weights
--     /programmes) drops from ~30-50ms to <5ms per call.
--   • Activity feed read scoped to the user + their friends becomes
--     an index range scan instead of a full table scan.
--   • Session history queries on FriendProfilePage stop blowing up
--     as `sessions` grows past a few thousand rows.
-- ──────────────────────────────────────────────────────────────────────────

-- sets: the single hottest table. calculateLeaderboardScore() fires
-- TWO queries against this per recompute (completed-this-month + all
-- sets ever). Compound index on (user_id, created_at) covers both the
-- monthly filter and the "all sets, oldest first" ordering used to
-- compute volume improvement.
CREATE INDEX IF NOT EXISTS sets_user_id_created_idx
    ON sets(user_id, created_at);

-- activity_feed: fetched on every CrewView open via WHERE user_id IN
-- (uid, friend_ids…) ORDER BY created_at DESC LIMIT 20.
-- The DESC matches the query so Postgres can walk the index backwards.
CREATE INDEX IF NOT EXISTS activity_feed_user_id_created_idx
    ON activity_feed(user_id, created_at DESC);

-- working_weights: small per-user table, but read on every session
-- start AND every leaderboard recompute. user_id is the natural key.
CREATE INDEX IF NOT EXISTS working_weights_user_id_idx
    ON working_weights(user_id);

-- programmes: read on home screen, on session start, and on every
-- leaderboard recompute (active programme only). Filter by user_id +
-- active is hot enough to justify the partial index — it's tiny
-- compared to a full b-tree and Postgres uses it for both branches.
CREATE INDEX IF NOT EXISTS programmes_user_id_active_idx
    ON programmes(user_id, active);

-- sessions: read on FriendProfilePage (last N sessions per friend)
-- and on history pages. Order by date DESC is the dominant access
-- pattern, so make the index DESC on date.
CREATE INDEX IF NOT EXISTS sessions_user_id_date_idx
    ON sessions(user_id, date DESC);

-- friendships: most queries do `user_id.eq.X OR friend_id.eq.X`. A
-- single composite index can't cover an OR, so we add two separate
-- indexes — Postgres can bitmap-OR them together.
CREATE INDEX IF NOT EXISTS friendships_user_id_idx
    ON friendships(user_id);
CREATE INDEX IF NOT EXISTS friendships_friend_id_idx
    ON friendships(friend_id);

-- invite_links: looked up by `code` on accept, by `user_id` for the
-- "my invites" list. Code is unique-per-user but not globally so
-- we don't add a UNIQUE constraint — just a lookup index.
CREATE INDEX IF NOT EXISTS invite_links_code_idx
    ON invite_links(code);
CREATE INDEX IF NOT EXISTS invite_links_user_id_idx
    ON invite_links(user_id);
