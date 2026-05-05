import { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  UserPlus, Search, Check, X, ChevronRight,
  Trophy, Dumbbell, Share2, Copy,
} from 'lucide-react';
import { C, springSoft } from '../tokens.js';
import {
  loadFriends, loadPendingRequests, sendFriendRequest,
  respondFriendRequest, createInviteLink, searchUsers,
  loadActivityFeed,
} from '../lib/db.js';
import FriendProfilePage from './FriendProfilePage.jsx';

// ── Section header ─────────────────────────────────────────────────────────────
function SectionTitle({ children }) {
  return (
    <div style={{
      fontSize: 11, fontWeight: 700, letterSpacing: '0.08em',
      color: C.dim, marginBottom: 8, marginTop: 20,
    }}>
      {children}
    </div>
  );
}

// ── Friend row ─────────────────────────────────────────────────────────────────
function FriendRow({ friend, onTap }) {
  return (
    <motion.div
      whileTap={{ scale: 0.98 }}
      onClick={() => onTap(friend)}
      style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '12px 16px',
        background: C.surface2, borderRadius: 12,
        border: `1px solid ${C.border}`,
        marginBottom: 8, cursor: 'pointer',
        WebkitTapHighlightColor: 'transparent',
      }}
    >
      <div style={{
        width: 40, height: 40, borderRadius: '50%',
        background: `linear-gradient(135deg, ${C.accent}33, ${C.accent}11)`,
        border: `2px solid ${C.accent}33`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 16, fontWeight: 800, color: C.accent, flexShrink: 0,
      }}>
        {(friend.username || friend.name || '?')[0].toUpperCase()}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: 14, fontWeight: 700, color: C.text,
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        }}>
          {friend.name || friend.username || 'Gym Bro'}
        </div>
        {friend.username && (
          <div style={{ fontSize: 12, color: C.mute }}>@{friend.username}</div>
        )}
      </div>
      <ChevronRight size={14} color={C.mute} />
    </motion.div>
  );
}

// ── Pending request row ────────────────────────────────────────────────────────
function RequestRow({ req, onAccept, onDecline }) {
  const [acting, setActing] = useState(false);
  const act = async (accept) => {
    setActing(true);
    await respondFriendRequest(req.friendshipId, accept);
    if (accept) onAccept(req); else onDecline(req);
  };
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '12px 16px',
      background: C.surface2, borderRadius: 12,
      border: `1px solid ${C.border}`,
      marginBottom: 8,
    }}>
      <div style={{
        width: 36, height: 36, borderRadius: '50%',
        background: C.surface, flexShrink: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 14, fontWeight: 800, color: C.dim,
      }}>
        {(req.username || req.name || '?')[0].toUpperCase()}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>
          {req.name || req.username || 'Gym Bro'}
        </div>
        <div style={{ fontSize: 12, color: C.mute }}>Wants to be your Bro</div>
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <motion.button
          whileTap={{ scale: 0.9 }}
          disabled={acting}
          onClick={() => act(true)}
          style={{
            width: 32, height: 32, borderRadius: 8,
            background: acting ? C.surface : 'rgba(173,255,47,0.15)',
            border: `1.5px solid ${acting ? C.border : C.accent}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer',
          }}
        >
          <Check size={14} color={acting ? C.mute : C.accent} strokeWidth={3} />
        </motion.button>
        <motion.button
          whileTap={{ scale: 0.9 }}
          disabled={acting}
          onClick={() => act(false)}
          style={{
            width: 32, height: 32, borderRadius: 8,
            background: C.surface,
            border: `1.5px solid ${C.border}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer',
          }}
        >
          <X size={14} color={C.mute} />
        </motion.button>
      </div>
    </div>
  );
}

// ── Leaderboard row ────────────────────────────────────────────────────────────
function LeaderboardRow({ rank, user, metric, isMe }) {
  const medal = rank === 1 ? '🥇' : rank === 2 ? '🥈' : rank === 3 ? '🥉' : null;
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '11px 16px',
      borderBottom: `1px solid ${C.border}`,
      background: isMe ? 'rgba(173,255,47,0.04)' : 'transparent',
    }}>
      <div style={{
        width: 24, textAlign: 'center', fontSize: 14,
        fontWeight: 800, color: medal ? C.text : C.mute, flexShrink: 0,
      }}>
        {medal || rank}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: 13, fontWeight: isMe ? 800 : 600, color: isMe ? C.accent : C.text,
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        }}>
          {user.name || user.username || 'Gym Bro'} {isMe ? '(you)' : ''}
        </div>
      </div>
      <div style={{ fontSize: 14, fontWeight: 800, color: isMe ? C.accent : C.text, flexShrink: 0 }}>
        {metric}
      </div>
    </div>
  );
}

// ── Activity item ──────────────────────────────────────────────────────────────
function ActivityItem({ item, currentUserId }) {
  const isMe = item.user_id === currentUserId;
  const name = item.profile?.username || item.profile?.name || 'Gym Bro';
  const time = (() => {
    const d = new Date(item.created_at);
    const diff = Date.now() - d.getTime();
    if (diff < 60000) return 'just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    return d.toLocaleDateString('en-GB', { month: 'short', day: 'numeric' });
  })();

  const body = (() => {
    if (item.type === 'session_complete') {
      return `completed "${item.data?.session_name || 'a session'}"`;
    }
    if (item.type === 'pr') {
      return `hit a new PR on ${item.data?.exercise || 'an exercise'}: ${item.data?.weight}kg`;
    }
    return 'did something impressive';
  })();

  const icon = item.type === 'pr' ? <Trophy size={14} color={C.accent} /> : <Dumbbell size={14} color={C.mute} />;

  return (
    <div style={{
      display: 'flex', alignItems: 'flex-start', gap: 12,
      padding: '12px 0',
      borderBottom: `1px solid ${C.border}`,
    }}>
      <div style={{
        width: 36, height: 36, borderRadius: '50%',
        background: isMe ? `${C.accent}22` : C.surface2,
        border: `1.5px solid ${isMe ? C.accent + '44' : C.border}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 13, fontWeight: 800, color: isMe ? C.accent : C.dim,
        flexShrink: 0, marginTop: 1,
      }}>
        {(isMe ? 'You' : name)[0].toUpperCase()}
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 13, color: C.text, lineHeight: 1.45 }}>
          <span style={{ fontWeight: 700 }}>{isMe ? 'You' : name}</span>{' '}
          <span style={{ color: C.dim }}>{body}</span>
        </div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 4, marginTop: 4,
        }}>
          {icon}
          <span style={{ fontSize: 11, color: C.mute }}>{time}</span>
        </div>
      </div>
    </div>
  );
}

// ── Add Bro sheet ──────────────────────────────────────────────────────────────
function AddBroSheet({ currentUserId, onClose, onRequestSent }) {
  const [tab,         setTab]         = useState('invite'); // 'invite' | 'search'
  const [inviteLink,  setInviteLink]  = useState(null);
  const [genLoading,  setGenLoading]  = useState(false);
  const [copied,      setCopied]      = useState(false);
  const [query,       setQuery]       = useState('');
  const [results,     setResults]     = useState([]);
  const [searching,   setSearching]   = useState(false);
  const [sent,        setSent]        = useState({}); // userId → true
  const debounceRef = useRef(null);

  const genLink = async () => {
    setGenLoading(true);
    try {
      const row = await createInviteLink(currentUserId);
      if (row?.code) {
        const base = window.location.origin;
        setInviteLink(`${base}/invite/${row.code}`);
      }
    } catch { /* non-fatal */ }
    setGenLoading(false);
  };

  useEffect(() => { if (tab === 'invite' && !inviteLink) genLink(); }, [tab]);

  const copyLink = () => {
    if (!inviteLink) return;
    navigator.clipboard?.writeText(inviteLink).catch(() => {});
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const shareLink = () => {
    if (!inviteLink) return;
    if (navigator.share) {
      navigator.share({ title: 'Join me on Trainer!', url: inviteLink }).catch(() => {});
    } else {
      copyLink();
    }
  };

  const handleSearch = (val) => {
    setQuery(val);
    clearTimeout(debounceRef.current);
    if (!val.trim()) { setResults([]); return; }
    setSearching(true);
    debounceRef.current = setTimeout(async () => {
      const res = await searchUsers(val.trim(), currentUserId);
      setResults(res || []);
      setSearching(false);
    }, 400);
  };

  const handleSendRequest = async (uid) => {
    setSent(prev => ({ ...prev, [uid]: 'sending' }));
    await sendFriendRequest(currentUserId, uid);
    setSent(prev => ({ ...prev, [uid]: 'sent' }));
    onRequestSent?.();
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      onClick={onClose}
      style={{
        position: 'fixed', inset: 0, zIndex: 6000,
        background: 'rgba(0,0,0,0.7)',
        display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
      }}
    >
      <motion.div
        initial={{ y: '100%' }}
        animate={{ y: 0 }}
        exit={{ y: '100%' }}
        transition={springSoft}
        onClick={e => e.stopPropagation()}
        style={{
          width: '100%', maxWidth: 390,
          background: C.surface,
          borderRadius: '20px 20px 0 0',
          maxHeight: '85vh',
          display: 'flex', flexDirection: 'column',
          paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 16px, 24px)',
        }}
      >
        {/* Handle */}
        <div style={{ padding: '16px 20px 0' }}>
          <div style={{
            width: 36, height: 4, borderRadius: 2, background: C.border, margin: '0 auto 16px',
          }} />
          <div style={{ fontSize: 17, fontWeight: 800, color: C.text, marginBottom: 14 }}>
            Add a Bro
          </div>

          {/* Tab toggle */}
          <div style={{
            display: 'flex', background: C.surface2, borderRadius: 10, padding: 3,
            marginBottom: 16,
          }}>
            {['invite', 'search'].map(t => (
              <button
                key={t}
                onClick={() => setTab(t)}
                style={{
                  flex: 1, padding: '8px 0',
                  background: tab === t ? C.surface : 'transparent',
                  border: tab === t ? `1px solid ${C.border}` : 'none',
                  borderRadius: 8,
                  fontSize: 13, fontWeight: tab === t ? 700 : 500,
                  color: tab === t ? C.text : C.mute,
                  cursor: 'pointer',
                  transition: 'all 0.15s',
                }}
              >
                {t === 'invite' ? 'Invite link' : 'Search users'}
              </button>
            ))}
          </div>
        </div>

        {/* Content */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '0 20px' }}>
          {tab === 'invite' && (
            <div>
              <div style={{ fontSize: 13, color: C.dim, marginBottom: 16, lineHeight: 1.5 }}>
                Share this link with a friend — it lets them add you as a Bro instantly.
                Link expires in 48 hours.
              </div>

              {genLoading ? (
                <div style={{
                  background: C.surface2, borderRadius: 12, padding: '14px 16px',
                  fontSize: 13, color: C.mute, textAlign: 'center',
                }}>
                  Generating link…
                </div>
              ) : inviteLink ? (
                <>
                  <div style={{
                    background: C.surface2, borderRadius: 12,
                    border: `1px solid ${C.border}`,
                    padding: '12px 14px', marginBottom: 12,
                    fontSize: 13, color: C.dim,
                    wordBreak: 'break-all', lineHeight: 1.4,
                  }}>
                    {inviteLink}
                  </div>
                  <div style={{ display: 'flex', gap: 10 }}>
                    <motion.button
                      whileTap={{ scale: 0.97 }}
                      onClick={copyLink}
                      style={{
                        flex: 1, background: copied ? 'rgba(173,255,47,0.12)' : C.surface2,
                        border: `1.5px solid ${copied ? C.accent : C.border}`,
                        borderRadius: 10, padding: '12px 0',
                        fontSize: 13, fontWeight: 700,
                        color: copied ? C.accent : C.text,
                        cursor: 'pointer',
                        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7,
                      }}
                    >
                      {copied ? <Check size={14} strokeWidth={3} /> : <Copy size={14} />}
                      {copied ? 'Copied!' : 'Copy'}
                    </motion.button>
                    <motion.button
                      whileTap={{ scale: 0.97 }}
                      onClick={shareLink}
                      style={{
                        flex: 1, background: C.accent,
                        border: 'none', borderRadius: 10, padding: '12px 0',
                        fontSize: 13, fontWeight: 800, color: '#000',
                        cursor: 'pointer',
                        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7,
                      }}
                    >
                      <Share2 size={14} />
                      Share
                    </motion.button>
                  </div>
                  <motion.button
                    whileTap={{ scale: 0.97 }}
                    onClick={genLink}
                    style={{
                      marginTop: 10, width: '100%', background: 'transparent',
                      border: 'none', padding: '8px 0',
                      fontSize: 12, color: C.mute, cursor: 'pointer',
                    }}
                  >
                    Generate new link
                  </motion.button>
                </>
              ) : null}
            </div>
          )}

          {tab === 'search' && (
            <div>
              <div style={{
                display: 'flex', alignItems: 'center', gap: 10,
                background: C.surface2, borderRadius: 10,
                border: `1px solid ${C.border}`,
                padding: '10px 14px', marginBottom: 12,
              }}>
                <Search size={15} color={C.mute} />
                <input
                  value={query}
                  onChange={e => handleSearch(e.target.value)}
                  placeholder="Search by username or name…"
                  autoFocus
                  style={{
                    flex: 1, background: 'none', border: 'none', outline: 'none',
                    color: C.text, fontSize: 14, fontFamily: 'inherit',
                  }}
                />
                {searching && <div style={{ fontSize: 11, color: C.mute }}>…</div>}
              </div>

              {results.map(u => (
                <div
                  key={u.id}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    padding: '10px 0',
                    borderBottom: `1px solid ${C.border}`,
                  }}
                >
                  <div style={{
                    width: 36, height: 36, borderRadius: '50%',
                    background: C.surface2, flexShrink: 0,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 14, fontWeight: 800, color: C.dim,
                  }}>
                    {(u.username || u.name || '?')[0].toUpperCase()}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>
                      {u.name || u.username}
                    </div>
                    {u.username && <div style={{ fontSize: 12, color: C.mute }}>@{u.username}</div>}
                  </div>
                  <motion.button
                    whileTap={{ scale: 0.95 }}
                    disabled={!!sent[u.id]}
                    onClick={() => handleSendRequest(u.id)}
                    style={{
                      background: sent[u.id] === 'sent' ? 'rgba(173,255,47,0.12)' : C.accent,
                      border: sent[u.id] === 'sent' ? `1.5px solid ${C.accent}` : 'none',
                      borderRadius: 8, padding: '7px 14px',
                      fontSize: 12, fontWeight: 700,
                      color: sent[u.id] === 'sent' ? C.accent : '#000',
                      cursor: sent[u.id] ? 'default' : 'pointer',
                      flexShrink: 0,
                    }}
                  >
                    {sent[u.id] === 'sending' ? '…' : sent[u.id] === 'sent' ? 'Sent ✓' : 'Add'}
                  </motion.button>
                </div>
              ))}

              {query && !searching && results.length === 0 && (
                <div style={{ textAlign: 'center', padding: '24px 0', color: C.mute, fontSize: 13 }}>
                  No users found for "{query}"
                </div>
              )}
            </div>
          )}
        </div>
      </motion.div>
    </motion.div>
  );
}

// ── GymBrosTab ─────────────────────────────────────────────────────────────────
export default function GymBrosTab({ state }) {
  const { user, history, showToast } = state;
  const uid = user?.id;

  const [friends,    setFriends]    = useState([]);
  const [pending,    setPending]    = useState([]);
  const [feed,       setFeed]       = useState([]);
  const [loading,    setLoading]    = useState(true);
  const [showAdd,    setShowAdd]    = useState(false);
  const [profileFor, setProfileFor] = useState(null); // friend object

  useEffect(() => {
    if (!uid) return;
    let cancelled = false;
    async function load() {
      setLoading(true);
      const [fr, pend] = await Promise.all([
        loadFriends(uid),
        loadPendingRequests(uid),
      ]);
      if (cancelled) return;
      const frList = fr || [];
      const pendList = pend || [];

      console.log('[GymBros] Friends fetched:', frList);
      console.log('[GymBros] Pending requests fetched:', pendList);

      setFriends(frList);
      setPending(pendList);

      const friendIds = frList.map(f => f.id);
      if (friendIds.length > 0) {
        const feedData = await loadActivityFeed(uid, friendIds);
        if (!cancelled) setFeed(feedData || []);
      }
      if (!cancelled) setLoading(false);
    }
    load();
    return () => { cancelled = true; };
  }, [uid]);

  // Leaderboard: self + friends sorted by session count
  const leaderboardEntries = (() => {
    const me = {
      id: uid,
      name: state.profile?.name || 'You',
      username: null,
      sessionCount: history.length,
    };
    const others = friends.map(f => ({
      ...f,
      sessionCount: f.session_count || 0,
    }));
    const entries = [me, ...others]
      .sort((a, b) => b.sessionCount - a.sessionCount)
      .map((u, i) => ({ ...u, rank: i + 1 }));
    console.log('[GymBros] Leaderboard:', entries);
    return entries;
  })();

  const handleAccept = (req) => {
    setPending(p => p.filter(r => r.friendshipId !== req.friendshipId));
    setFriends(f => [...f, { id: req.userId, name: req.name, username: req.username }]);
  };
  const handleDecline = (req) => {
    setPending(p => p.filter(r => r.friendshipId !== req.friendshipId));
  };

  if (!uid) {
    return (
      <div style={{ padding: 32, textAlign: 'center', color: C.mute }}>
        Sign in to use Gym Bros
      </div>
    );
  }

  return (
    <>
      <div style={{ padding: '16px 16px 0' }}>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 4 }}>
          <div style={{ fontSize: 22, fontWeight: 800, color: C.text, letterSpacing: '-0.03em' }}>
            Gym Bros
          </div>
          <motion.button
            whileTap={{ scale: 0.95 }}
            onClick={() => setShowAdd(true)}
            style={{
              background: C.accent, border: 'none', borderRadius: 10,
              padding: '8px 16px',
              fontSize: 13, fontWeight: 800, color: '#000',
              cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 6,
            }}
          >
            <UserPlus size={14} />
            Add Bro
          </motion.button>
        </div>
        <div style={{ fontSize: 13, color: C.mute, marginBottom: 4 }}>
          {friends.length} {friends.length === 1 ? 'bro' : 'bros'}
        </div>
      </div>

      <div style={{ padding: '0 16px' }}>

        {loading ? (
          /* Skeleton loader — shows structure while network fetches */
          <div style={{ marginTop: 20 }}>
            {[1, 2, 3].map(i => (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', gap: 12,
                padding: '12px 16px',
                background: C.surface2, borderRadius: 12,
                border: `1px solid ${C.border}`, marginBottom: 8,
              }}>
                <div style={{
                  width: 40, height: 40, borderRadius: '50%',
                  background: C.surface, flexShrink: 0,
                }} />
                <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
                  <div style={{ height: 12, width: '55%', background: C.surface, borderRadius: 6 }} />
                  <div style={{ height: 10, width: '35%', background: C.surface, borderRadius: 6 }} />
                </div>
              </div>
            ))}
          </div>
        ) : (
          <>
            {/* Pending requests */}
            {pending.length > 0 && (
              <>
                <SectionTitle>REQUESTS ({pending.length})</SectionTitle>
                {pending.map(req => (
                  <RequestRow
                    key={req.friendshipId}
                    req={req}
                    onAccept={handleAccept}
                    onDecline={handleDecline}
                  />
                ))}
              </>
            )}

            {/* Leaderboard */}
            {leaderboardEntries.length > 1 && (
              <>
                <SectionTitle>LEADERBOARD — SESSIONS</SectionTitle>
                <div style={{
                  background: C.surface2, borderRadius: 12,
                  border: `1px solid ${C.border}`, overflow: 'hidden', marginBottom: 4,
                }}>
                  {leaderboardEntries.map(entry => (
                    <LeaderboardRow
                      key={entry.id}
                      rank={entry.rank}
                      user={entry}
                      metric={`${entry.sessionCount} sess`}
                      isMe={entry.id === uid}
                    />
                  ))}
                </div>
              </>
            )}

            {/* Friends */}
            {friends.length > 0 && (
              <>
                <SectionTitle>YOUR BROS</SectionTitle>
                {friends.map(f => (
                  <FriendRow
                    key={f.id}
                    friend={f}
                    onTap={(friend) => setProfileFor(friend)}
                  />
                ))}
              </>
            )}

            {/* Activity feed */}
            {feed.length > 0 && (
              <>
                <SectionTitle>ACTIVITY</SectionTitle>
                <div style={{ marginBottom: 8 }}>
                  {feed.slice(0, 20).map((item, i) => (
                    <ActivityItem key={item.id || i} item={item} currentUserId={uid} />
                  ))}
                </div>
              </>
            )}

            {/* Empty state */}
            {friends.length === 0 && pending.length === 0 && (
              <div style={{
                display: 'flex', flexDirection: 'column', alignItems: 'center',
                padding: '48px 24px', gap: 12,
              }}>
                <div style={{ fontSize: 48 }}>🏋️</div>
                <div style={{ fontSize: 16, fontWeight: 800, color: C.text, textAlign: 'center' }}>
                  No Bros yet
                </div>
                <div style={{ fontSize: 13, color: C.dim, textAlign: 'center', lineHeight: 1.5 }}>
                  Invite your gym friends and compete on the leaderboard
                </div>
                <motion.button
                  whileTap={{ scale: 0.97 }}
                  onClick={() => setShowAdd(true)}
                  style={{
                    marginTop: 8,
                    background: C.accent, border: 'none', borderRadius: 12,
                    padding: '13px 28px',
                    fontSize: 14, fontWeight: 800, color: '#000',
                    cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8,
                  }}
                >
                  <UserPlus size={15} />
                  Add your first Bro
                </motion.button>
              </div>
            )}
          </>
        )}

      </div>

      {/* Add Bro sheet */}
      <AnimatePresence>
        {showAdd && (
          <AddBroSheet
            key="add-bro"
            currentUserId={uid}
            onClose={() => setShowAdd(false)}
            onRequestSent={() => showToast?.('Friend request sent ✓')}
          />
        )}
      </AnimatePresence>

      {/* Friend profile page */}
      <AnimatePresence>
        {profileFor && (
          <FriendProfilePage
            key={profileFor.id}
            friendId={profileFor.id}
            currentUserId={uid}
            onBack={() => setProfileFor(null)}
            onRemoved={() => {
              setFriends(f => f.filter(fr => fr.id !== profileFor.id));
              showToast?.('Bro removed');
            }}
          />
        )}
      </AnimatePresence>
    </>
  );
}
