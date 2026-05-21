// ──────────────────────────────────────────────────────────────────────────
// send-push — Supabase Edge Function
//
// Signs an APNs JWT with the .p8 auth key (ES256) and posts a push
// notification to Apple's HTTP/2 endpoint for every active device a
// target user has registered in public.push_devices.
//
// Invocation shape (POST body):
//   {
//     "user_ids": ["uuid-1", "uuid-2", ...],   // recipients
//     "category": "friend_request" | "friend_accepted" | "league_invite"
//                | "friend_session" | "friend_badge" | "monthly_leaderboard",
//     "title": "string",                       // shown on lock screen
//     "body":  "string",                       // body text
//     "data":  { ... }                         // arbitrary client routing payload
//   }
//
// Auth: this function should be called server-to-server (from a DB
// trigger / cron / another Edge Function) using the SERVICE_ROLE_KEY,
// OR by an authenticated user calling it via the SDK — but in either
// case we always look up the recipient's tokens with the service role
// (so the caller can't bypass RLS to discover someone else's tokens).
//
// Per-user opt-out: profiles.notification_prefs is a jsonb blob where
// missing keys = "opted in" (default ON) and `false` = explicitly off.
// ──────────────────────────────────────────────────────────────────────────

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

// ─── Configuration via Supabase secrets ──────────────────────────────────
const APNS_TEAM_ID   = Deno.env.get("APNS_TEAM_ID")   ?? "";
const APNS_KEY_ID    = Deno.env.get("APNS_KEY_ID")    ?? "";
const APNS_AUTH_KEY  = Deno.env.get("APNS_AUTH_KEY")  ?? "";
const APNS_TOPIC     = Deno.env.get("APNS_TOPIC")     ?? "com.hexapp.training";
const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")   ?? "";
const SERVICE_ROLE   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_AUTH_KEY) {
  console.error("[send-push] Missing APNs secrets — refusing to start");
}

// ─── JWT signing (ES256 with the .p8 key) ────────────────────────────────
//
// Apple gives you a PKCS#8-encoded ECDSA P-256 private key. We import it
// via Web Crypto, sign a tiny JWT, and cache the result for ~50 minutes
// (Apple accepts up to 1h; we refresh slightly under that). One cached
// token covers every push from this function until rotation.

let cachedJwt: { token: string; expiresAt: number } | null = null;

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && cachedJwt.expiresAt > now + 60) {
    return cachedJwt.token;
  }

  const header  = { alg: "ES256", kid: APNS_KEY_ID, typ: "JWT" };
  const payload = { iss: APNS_TEAM_ID, iat: now };

  const enc = (o: object) =>
    base64url(new TextEncoder().encode(JSON.stringify(o)));

  const signingInput = `${enc(header)}.${enc(payload)}`;
  const sigBytes     = await signES256(signingInput, APNS_AUTH_KEY);
  const jwt          = `${signingInput}.${base64url(sigBytes)}`;

  // Apple allows the token for 1h; refresh after 50 min to be safe.
  cachedJwt = { token: jwt, expiresAt: now + 50 * 60 };
  return jwt;
}

async function signES256(input: string, p8Pem: string): Promise<Uint8Array> {
  // Strip PEM armour + whitespace → raw base64 → ArrayBuffer
  const b64 = p8Pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    der.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(input),
  );
  return new Uint8Array(sig);
}

function base64url(buf: Uint8Array): string {
  let s = btoa(String.fromCharCode(...buf));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

// ─── Per-category opt-out check ──────────────────────────────────────────
//
// Maps the 5 notification categories to the 4 toggle keys in
// notification_prefs. (Friend request + accepted share one toggle.)
function isOptedOut(
  prefs: Record<string, unknown> | null | undefined,
  category: string,
): boolean {
  if (!prefs) return false;
  const key = {
    friend_request:      "friends",
    friend_accepted:     "friends",
    league_invite:       "leagues",
    friend_session:      "friend_sessions",
    friend_badge:        "friend_badges",
    monthly_leaderboard: "monthly_leaderboard",
  }[category];
  if (!key) return false;
  return prefs[key] === false; // missing → ON, explicit false → OFF
}

// ─── APNs POST ───────────────────────────────────────────────────────────
type Device = {
  id: string;
  device_token: string;
  is_sandbox: boolean;
};

async function sendOne(
  jwt: string,
  device: Device,
  payload: object,
  category: string,
): Promise<{ status: number; tokenForDelete?: string }> {
  const host = device.is_sandbox
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";
  const url = `https://${host}/3/device/${device.device_token}`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "authorization":   `bearer ${jwt}`,
      "apns-topic":      APNS_TOPIC,
      "apns-push-type":  "alert",
      "apns-priority":   "10",
      "content-type":    "application/json",
    },
    body: JSON.stringify(payload),
  });

  // 410 = "device no longer registered" → caller should delete this row.
  // 200 = success. Anything else → log + drop.
  if (res.status === 410) return { status: 410, tokenForDelete: device.device_token };
  if (res.status !== 200) {
    const text = await res.text().catch(() => "");
    console.warn(`[send-push] APNs returned ${res.status} for category ${category}:`, text);
  }
  return { status: res.status };
}

// ─── Quiet hours ─────────────────────────────────────────────────────────
//
// No notifications between 23:00 and 08:00 Asia/Riyadh time (the primary
// HEX audience). Friend-request / accepted / league-invite are still
// allowed even at night because they're rare; sessions/badges are
// silenced. monthly_leaderboard is also allowed (rare, useful).
function inQuietHours(): boolean {
  // Riyadh = UTC+3, no DST.
  const utcHour = new Date().getUTCHours();
  const localHour = (utcHour + 3) % 24;
  return localHour >= 23 || localHour < 8;
}

function isSilencedDuringQuietHours(category: string): boolean {
  return category === "friend_session" || category === "friend_badge";
}

// ─── Main handler ────────────────────────────────────────────────────────
type RequestBody = {
  user_ids: string[];
  category: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  if (!body.user_ids?.length || !body.category || !body.title || !body.body) {
    return new Response("Missing required fields", { status: 400 });
  }

  // Quiet-hours gate for noisy categories.
  if (inQuietHours() && isSilencedDuringQuietHours(body.category)) {
    return Response.json({ skipped: "quiet_hours" });
  }

  // Service-role client — bypasses RLS so we can read other users'
  // tokens to deliver to them. The caller's identity doesn't matter
  // here; this function only takes server-side instructions.
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

  // 1) Pull preferences + tokens for every recipient in one query each.
  const { data: profiles, error: pErr } = await supabase
    .from("profiles")
    .select("id, notification_prefs")
    .in("id", body.user_ids);
  if (pErr) {
    console.error("[send-push] profiles fetch failed:", pErr);
    return new Response("DB error", { status: 500 });
  }
  const recipients = (profiles ?? []).filter(
    (p) => !isOptedOut(p.notification_prefs as Record<string, unknown>, body.category),
  );
  if (recipients.length === 0) {
    return Response.json({ delivered: 0, opted_out: body.user_ids.length });
  }

  const { data: devices, error: dErr } = await supabase
    .from("push_devices")
    .select("id, user_id, device_token, is_sandbox")
    .in("user_id", recipients.map((r) => r.id))
    .eq("platform", "ios");
  if (dErr) {
    console.error("[send-push] devices fetch failed:", dErr);
    return new Response("DB error", { status: 500 });
  }
  if (!devices?.length) {
    return Response.json({ delivered: 0, no_devices: recipients.length });
  }

  // 2) Build the APNs payload once — same for every recipient.
  const payload = {
    aps: {
      alert: { title: body.title, body: body.body },
      sound: "default",
      badge: 1,
    },
    category: body.category,
    ...(body.data ?? {}),
  };

  // 3) Sign JWT once, fan out the sends in parallel.
  const jwt = await getApnsJwt();
  const results = await Promise.all(
    devices.map((d) => sendOne(jwt, d as Device, payload, body.category)),
  );

  // 4) Clean up dead tokens (410 responses). Best-effort; ignore failures.
  const deadTokens = results
    .filter((r) => r.tokenForDelete)
    .map((r) => r.tokenForDelete!);
  if (deadTokens.length) {
    await supabase
      .from("push_devices")
      .delete()
      .in("device_token", deadTokens);
  }

  const delivered = results.filter((r) => r.status === 200).length;
  return Response.json({
    delivered,
    dead_tokens_cleaned: deadTokens.length,
    total_devices: devices.length,
  });
});
