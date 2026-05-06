import { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  UserPlus, Search, Check, X, ChevronRight, Plus,
  Trophy, Dumbbell, Share2, Copy,
} from 'lucide-react';
import { C, springSoft } from '../tokens.js';
import {
  loadFriends, loadPendingRequests, sendFriendRequest,
  respondFriendRequest, createInviteLink, searchUsers,
  loadActivityFeed, calculateLeaderboardScore, updateLeaderboardScore,
} from '../lib/db.js';
import FriendProfilePage from './FriendProfilePage.jsx';

// ── Colours ────────────────────────────────────────────────────────────────────
const GOLD   = '#FFD700';
const SILVER = '#C0C0C0';
const BRONZE = '#CD7F32';
const LIME   = '#ADFF2F';
const RANK_COLORS = { 1: GOLD, 2: SILVER, 3: BRONZE };

// ── Section label ──────────────────────────────────────────────────────────────
function SectionLabel({ children, right }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      marginBottom: 8,
    }}>
      <div style={{
        fontSize: 10, fontWeight: 700, letterSpacing: '0.09em', color: C.dim,
      }}>
        {children}
      </div>
      {right}
    </div>
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
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '10px 12px',
      background: C.surface2, borderRadius: 10,
      border: `1px solid ${C.border}`,
      marginBottom: 6,
    }}>
      <div style={{
        width: 34, height: 34, borderRadius: '50%',
        background: C.surface, flexShrink: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 13, fontWeight: 800, color: C.dim,
      }}>
        {(req.username || req.name || '?')[0].toUpperCase()}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, fontWeight: 700, color: C.text }}>{req.name || req.username || 'Gym Bro'}</div>
        <div style={{ fontSize: 11, color: C.mute }}>Wants to be your Bro</div>
      </div>
      <div style={{ display: 'flex', gap: 7 }}>
        <motion.button whileTap={{ scale: 0.9 }} disabled={acting} onClick={() => act(true)} style={{
          width: 30, height: 30, borderRadius: 8,
          background: acting ? C.surface : 'rgba(173,255,47,0.15)',
          border: `1.5px solid ${acting ? C.border : LIME}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        }}>
          <Check size={13} color={acting ? C.mute : LIME} strokeWidth={3} />
        </motion.button>
        <motion.button whileTap={{ scale: 0.9 }} disabled={acting} onClick={() => act(false)} style={{
          width: 30, height: 30, borderRadius: 8,
          background: C.surface, border: `1.5px solid ${C.border}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        }}>
          <X size={13} color={C.mute} />
        </motion.button>
      </div>
    </div>
  );
}

// ── Friend avatar bubble (horizontal row) ──────────────────────────────────────
function FriendBubble({ friend, trainedToday, onTap }) {
  const initial = (friend.name || friend.username || '?')[0].toUpperCase();
  const firstName = (friend.name || friend.username || 'Bro').split(' ')[0].slice(0, 8);
  const ringColor = trainedToday ? LIME : '#2a2a2a';
  return (
    <motion.div
      whileTap={{ scale: 0.92 }}
      onClick={() => onTap(friend)}
      style={{
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5,
        cursor: 'pointer', flexShrink: 0, width: 60,
        WebkitTapHighlightColor: 'transparent',
      }}
    >
      <div style={{
        width: 48, height: 48, borderRadius: '50%',
        background: `${LIME}18`,
        border: `2.5px solid ${ringColor}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 17, fontWeight: 800, color: trainedToday ? LIME : C.dim,
        transition: 'border-color 0.2s',
      }}>
        {initial}
      </div>
      <div style={{
        fontSize: 10, fontWeight: 600, color: C.mute,
        textAlign: 'center', maxWidth: 56,
        whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
      }}>
        {firstName}
      </div>
    </motion.div>
  );
}

// ── Add Bro bubble (dashed, end of row) ───────────────────────────────────────
function AddBubble({ onTap }) {
  return (
    <motion.div
      whileTap={{ scale: 0.92 }}
      onClick={onTap}
      style={{
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5,
        cursor: 'pointer', flexShrink: 0, width: 60,
        WebkitTapHighlightColor: 'transparent',
      }}
    >
      <div style={{
        width: 48, height: 48, borderRadius: '50%',
        border: `2px dashed #333`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <Plus size={18} color="#444" />
      </div>
      <div style={{ fontSize: 10, fontWeight: 600, color: '#444' }}>Add</div>
    </motion.div>
  );
}

// ── All Friends slide-over page ────────────────────────────────────────────────
function AllFriendsPage({ friends, currentUserId, onTap, onBack }) {
  const page = (
    <motion.div
      initial={{ x: '100%' }}
      animate={{ x: 0 }}
      exit={{ x: '100%' }}
      transition={springSoft}
      style={{
        position: 'fixed', inset: 0, zIndex: 5000,
        background: '#111',
        display: 'flex', flexDirection: 'column',
        maxWidth: 390, margin: '0 auto',
      }}
    >
      {/* Header */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '12px 16px',
        paddingTop: 'max(env(safe-area-inset-top, 0px) + 12px, 20px)',
        borderBottom: `1px solid #222`, flexShrink: 0,
        background: '#161616',
      }}>
        <motion.button whileTap={{ scale: 0.93 }} onClick={onBack} style={{
          background: '#1e1e1e', border: '1.5px solid #2a2a2a',
          borderRadius: 8, width: 36, height: 36,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer', flexShrink: 0,
        }}>
          <ChevronRight size={18} color={C.text} style={{ transform: 'rotate(180deg)' }} />
        </motion.button>
        <div>
          <div style={{ fontSize: 16, fontWeight: 800, color: C.text }}>Your Bros</div>
          <div style={{ fontSize: 11, color: C.mute }}>{friends.length} {friends.length === 1 ? 'bro' : 'bros'}</div>
        </div>
      </div>

      {/* List */}
      <div style={{ flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch' }}>
        {friends.length === 0 ? (
          <div style={{ padding: '48px 24px', textAlign: 'center', color: C.mute, fontSize: 14 }}>
            No Bros yet — add some!
          </div>
        ) : friends.map((f, i) => {
          const ld = f.leaderboard_data || {};
          const improvement = ld.improvementPct ?? 0;
          const sets = ld.setsCompleted ?? 0;
          return (
            <motion.div
              key={f.id}
              whileTap={{ scale: 0.99 }}
              onClick={() => onTap(f)}
              style={{
                display: 'flex', alignItems: 'center', gap: 12,
                padding: '13px 16px',
                borderBottom: '1px solid #1a1a1a',
                cursor: 'pointer',
                WebkitTapHighlightColor: 'transparent',
              }}
            >
              <div style={{
                width: 42, height: 42, borderRadius: '50%', flexShrink: 0,
                background: `${LIME}18`, border: `2px solid #2a2a2a`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 15, fontWeight: 800, color: C.dim,
              }}>
                {(f.name || f.username || '?')[0].toUpperCase()}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: C.text,
                  whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {f.name || f.username || 'Gym Bro'}
                </div>
                {f.username && <div style={{ fontSize: 11, color: C.mute }}>@{f.username}</div>}
                <div style={{ fontSize: 11, color: C.mute, marginTop: 1 }}>
                  {sets} sets · +{improvement}% volume
                </div>
              </div>
              <ChevronRight size={14} color="#333" />
            </motion.div>
          );
        })}
      </div>
    </motion.div>
  );
  return createPortal(page, document.body);
}

// ── Compact leaderboard row ────────────────────────────────────────────────────
function LeaderboardRow({ rank, user, isMe, onTap }) {
  const rankColor = isMe ? LIME : (RANK_COLORS[rank] || '#444');
  const initial = (user.name || user.username || '?')[0].toUpperCase();
  const subtitle = `${user.setsCompleted ?? 0} sets · +${user.improvementPct ?? 0}% volume`;

  return (
    <motion.div
      whileTap={!isMe ? { scale: 0.99 } : {}}
      onClick={!isMe ? onTap : undefined}
      style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '7px 12px',
        borderBottom: '1px solid #1c1c1c',
        background: isMe ? '#1a2a00' : 'transparent',
        borderLeft: isMe ? `2px solid ${LIME}` : '2px solid transparent',
        cursor: isMe ? 'default' : 'pointer',
        WebkitTapHighlightColor: 'transparent',
        minHeight: 38,
      }}
    >
      {/* Rank */}
      <div style={{
        width: 18, textAlign: 'center', fontSize: 12, fontWeight: 800,
        color: rankColor, flexShrink: 0,
      }}>
        {rank}
      </div>

      {/* Avatar 28px */}
      <div style={{
        width: 28, height: 28, borderRadius: '50%', flexShrink: 0,
        background: isMe ? `${LIME}22` : '#1e1e1e',
        border: `1.5px solid ${isMe ? LIME + '55' : '#2a2a2a'}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 11, fontWeight: 800,
        color: isMe ? LIME : '#666',
      }}>
        {initial}
      </div>

      {/* Name @username · subtitle */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', gap: 5,
          whiteSpace: 'nowrap', overflow: 'hidden',
          lineHeight: 1.3,
        }}>
          <span style={{
            fontSize: 13, fontWeight: isMe ? 700 : 600,
            color: isMe ? LIME : C.text,
            flexShrink: 0, maxWidth: '55%',
            overflow: 'hidden', textOverflow: 'ellipsis',
          }}>
            {user.name || user.username || 'Gym Bro'}
          </span>
          {user.username && (
            <span style={{
              fontSize: 10, fontWeight: 500,
              color: isMe ? LIME + '88' : '#444',
              flexShrink: 1, minWidth: 0,
              overflow: 'hidden', textOverflow: 'ellipsis',
            }}>
              @{user.username}
            </span>
          )}
        </div>
        <div style={{ fontSize: 10, color: '#555', marginTop: 1 }}>
          {subtitle}
        </div>
      </div>

      {/* Score + pts */}
      <div style={{ textAlign: 'right', flexShrink: 0, marginRight: 6 }}>
        <div style={{ fontSize: 15, fontWeight: 800, color: isMe ? LIME : C.text, lineHeight: 1.2 }}>
          {user.score ?? 0}
        </div>
        <div style={{ fontSize: 10, color: '#555' }}>pts</div>
      </div>

      {/* Chevron */}
      {!isMe && <ChevronRight size={14} color="#333" />}
      {isMe  && <div style={{ width: 14 }} />}
    </motion.div>
  );
}

// ── Activity item ──────────────────────────────────────────────────────────────
function ActivityItem({ item, currentUserId, onProfileTap }) {
  const isMe = item.user_id === currentUserId;
  // Display @username when available, fall back to name
  const displayName = isMe
    ? 'You'
    : item.profile?.username
      ? `@${item.profile.username}`
      : (item.profile?.name || 'Gym Bro');
  const time = (() => {
    const d = new Date(item.created_at);
    const diff = Date.now() - d.getTime();
    if (diff < 60000) return 'just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    return d.toLocaleDateString('en-GB', { month: 'short', day: 'numeric' });
  })();
  const body = (() => {
    if (item.type === 'session_completed') {
      const vol = item.data?.volume;
      const volStr = vol && vol > 0 ? ` · ${Math.round(vol).toLocaleString()} kg` : '';
      return `completed "${item.data?.session_name || 'a session'}"${volStr}`;
    }
    if (item.type === 'new_pr') {
      const prev = item.data?.previous_weight;
      return `PR on ${item.data?.exercise_name || 'an exercise'}: ${item.data?.weight} kg${prev > 0 ? ` (was ${prev})` : ''}`;
    }
    return 'did something impressive';
  })();
  const icon = item.type === 'new_pr'
    ? <Trophy size={13} color={LIME} />
    : <Dumbbell size={13} color={C.mute} />;
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-start', gap: 10,
      padding: '11px 0', borderBottom: '1px solid #1a1a1a',
    }}>
      <div style={{
        width: 34, height: 34, borderRadius: '50%',
        background: isMe ? `${LIME}18` : C.surface2,
        border: `1.5px solid ${isMe ? LIME + '44' : '#222'}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 12, fontWeight: 800, color: isMe ? LIME : C.dim,
        flexShrink: 0, marginTop: 1,
      }}>
        {(isMe ? 'You' : name)[0].toUpperCase()}
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 13, color: C.text, lineHeight: 1.4 }}>
          <span
            style={{
              fontWeight: 700,
              cursor: !isMe ? 'pointer' : 'default',
              WebkitTapHighlightColor: 'transparent',
            }}
            onClick={!isMe ? () => onProfileTap?.(item.user_id) : undefined}
          >
            {displayName}
          </span>{' '}
          <span style={{ color: C.dim }}>{body}</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginTop: 3 }}>
          {icon}
          <span style={{ fontSize: 10, color: '#555' }}>{time}</span>
        </div>
      </div>
    </div>
  );
}

// ── Add Bro bottom sheet ───────────────────────────────────────────────────────
function AddBroSheet({ currentUserId, username, onClose, onRequestSent }) {
  const [tab,        setTab]        = useState('invite');
  const [inviteLink, setInviteLink] = useState(null);
  const [genLoading, setGenLoading] = useState(false);
  const [copied,     setCopied]     = useState(false);
  const [query,      setQuery]      = useState('');
  const [results,    setResults]    = useState([]);
  const [searching,  setSearching]  = useState(false);
  const [sent,       setSent]       = useState({});
  const debounceRef = useRef(null);

  const genLink = async () => {
    setGenLoading(true);
    try {
      const row = await createInviteLink(currentUserId);
      if (row?.code) {
        const base = (import.meta.env.VITE_APP_URL || window.location.origin).replace(/\/$/, '');
        setInviteLink(`${base}/invite/${row.code}`);
      }
    } catch { /* non-fatal */ }
    setGenLoading(false);
  };

  useEffect(() => { if (tab === 'invite' && !inviteLink) genLink(); }, [tab]);

  const copyLink = () => {
    navigator.clipboard?.writeText(inviteLink).catch(() => {});
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };
  const shareLink = () => {
    const msg = username
      ? `Hey! Join me on Trainer 💪 I'm @${username}. Use this link to connect with me: ${inviteLink}`
      : `Hey! Join me on Trainer 💪 Use this link to add me as a Gym Bro: ${inviteLink}`;
    if (navigator.share) {
      navigator.share({ title: 'Join me on Trainer!', text: msg, url: inviteLink }).catch(() => {});
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

  const handleSend = async (uid) => {
    setSent(p => ({ ...p, [uid]: 'sending' }));
    await sendFriendRequest(currentUserId, uid);
    setSent(p => ({ ...p, [uid]: 'sent' }));
    onRequestSent?.();
  };

  return (
    <motion.div
      initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
      onClick={onClose}
      style={{
        position: 'fixed', inset: 0, zIndex: 6000,
        background: 'rgba(0,0,0,0.75)',
        display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
      }}
    >
      <motion.div
        initial={{ y: '100%' }} animate={{ y: 0 }} exit={{ y: '100%' }}
        transition={springSoft}
        onClick={e => e.stopPropagation()}
        style={{
          width: '100%', maxWidth: 390,
          background: '#161616',
          borderRadius: '20px 20px 0 0',
          maxHeight: '85vh',
          display: 'flex', flexDirection: 'column',
          paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 16px, 24px)',
        }}
      >
        <div style={{ padding: '16px 20px 0' }}>
          <div style={{ width: 36, height: 4, borderRadius: 2, background: '#2a2a2a', margin: '0 auto 16px' }} />
          <div style={{ fontSize: 17, fontWeight: 800, color: C.text, marginBottom: 14 }}>Add a Bro</div>
          <div style={{ display: 'flex', background: '#1e1e1e', borderRadius: 10, padding: 3, marginBottom: 16 }}>
            {['invite', 'search'].map(t => (
              <button key={t} onClick={() => setTab(t)} style={{
                flex: 1, padding: '8px 0',
                background: tab === t ? '#2a2a2a' : 'transparent',
                border: tab === t ? '1px solid #333' : 'none',
                borderRadius: 8,
                fontSize: 13, fontWeight: tab === t ? 700 : 500,
                color: tab === t ? C.text : C.mute,
                cursor: 'pointer', transition: 'all 0.15s',
              }}>
                {t === 'invite' ? 'Invite link' : 'Search users'}
              </button>
            ))}
          </div>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: '0 20px' }}>
          {tab === 'invite' && (
            <div>
              <div style={{ fontSize: 13, color: C.dim, marginBottom: 16, lineHeight: 1.5 }}>
                Share this link — it lets them add you as a Bro instantly. Expires in 48h.
              </div>
              {genLoading ? (
                <div style={{ background: '#1e1e1e', borderRadius: 12, padding: '14px 16px', fontSize: 13, color: C.mute, textAlign: 'center' }}>
                  Generating link…
                </div>
              ) : inviteLink ? (
                <>
                  <div style={{
                    background: '#1e1e1e', borderRadius: 12, border: '1px solid #2a2a2a',
                    padding: '12px 14px', marginBottom: 12,
                    fontSize: 12, color: C.dim, wordBreak: 'break-all', lineHeight: 1.5,
                  }}>{inviteLink}</div>
                  <div style={{ display: 'flex', gap: 10 }}>
                    <motion.button whileTap={{ scale: 0.97 }} onClick={copyLink} style={{
                      flex: 1, background: copied ? `${LIME}18` : '#1e1e1e',
                      border: `1.5px solid ${copied ? LIME : '#333'}`,
                      borderRadius: 10, padding: '12px 0',
                      fontSize: 13, fontWeight: 700, color: copied ? LIME : C.text,
                      cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7,
                    }}>
                      {copied ? <Check size={13} strokeWidth={3} /> : <Copy size={13} />}
                      {copied ? 'Copied!' : 'Copy'}
                    </motion.button>
                    <motion.button whileTap={{ scale: 0.97 }} onClick={shareLink} style={{
                      flex: 1, background: LIME, border: 'none', borderRadius: 10, padding: '12px 0',
                      fontSize: 13, fontWeight: 800, color: '#000', cursor: 'pointer',
                      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7,
                    }}>
                      <Share2 size={13} />Share
                    </motion.button>
                  </div>
                  <motion.button whileTap={{ scale: 0.97 }} onClick={genLink} style={{
                    marginTop: 10, width: '100%', background: 'transparent', border: 'none',
                    padding: '8px 0', fontSize: 12, color: '#444', cursor: 'pointer',
                  }}>
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
                background: '#1e1e1e', borderRadius: 10, border: '1px solid #2a2a2a',
                padding: '10px 14px', marginBottom: 12,
              }}>
                <Search size={15} color={C.mute} />
                <input
                  value={query}
                  onChange={e => handleSearch(e.target.value)}
                  placeholder="Search by username or name…"
                  autoFocus
                  style={{ flex: 1, background: 'none', border: 'none', outline: 'none', color: C.text, fontSize: 14, fontFamily: 'inherit' }}
                />
                {searching && <div style={{ fontSize: 11, color: C.mute }}>…</div>}
              </div>
              {results.map(u => (
                <div key={u.id} style={{
                  display: 'flex', alignItems: 'center', gap: 12,
                  padding: '10px 0', borderBottom: '1px solid #1a1a1a',
                }}>
                  <div style={{
                    width: 34, height: 34, borderRadius: '50%',
                    background: '#1e1e1e', flexShrink: 0,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 13, fontWeight: 800, color: '#555',
                  }}>
                    {(u.username || u.name || '?')[0].toUpperCase()}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>{u.name || u.username}</div>
                    {u.username && <div style={{ fontSize: 11, color: C.mute }}>@{u.username}</div>}
                  </div>
                  <motion.button whileTap={{ scale: 0.95 }} disabled={!!sent[u.id]}
                    onClick={() => handleSend(u.id)}
                    style={{
                      background: sent[u.id] === 'sent' ? `${LIME}18` : LIME,
                      border: sent[u.id] === 'sent' ? `1.5px solid ${LIME}` : 'none',
                      borderRadius: 8, padding: '6px 14px',
                      fontSize: 12, fontWeight: 700,
                      color: sent[u.id] === 'sent' ? LIME : '#000',
                      cursor: sent[u.id] ? 'default' : 'pointer', flexShrink: 0,
                    }}>
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

// ── Skeleton rows ──────────────────────────────────────────────────────────────
function SkeletonRow() {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '9px 12px', borderBottom: '1px solid #1c1c1c', minHeight: 44,
    }}>
      <div style={{ width: 18, height: 12, background: '#1e1e1e', borderRadius: 4 }} />
      <div style={{ width: 28, height: 28, borderRadius: '50%', background: '#1e1e1e', flexShrink: 0 }} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 5 }}>
        <div style={{ height: 11, width: '50%', background: '#1e1e1e', borderRadius: 4 }} />
        <div style={{ height: 9, width: '30%', background: '#181818', borderRadius: 4 }} />
      </div>
      <div style={{ width: 28, height: 18, background: '#1e1e1e', borderRadius: 4 }} />
    </div>
  );
}

// ── GymBrosTab ─────────────────────────────────────────────────────────────────
export default function GymBrosTab({ state }) {
  const { user, showToast } = state;
  const uid = user?.id;

  const [friends,      setFriends]      = useState([]);
  const [pending,      setPending]      = useState([]);
  const [feed,         setFeed]         = useState([]);
  const [leaderboard,  setLeaderboard]  = useState([]);
  const [loading,      setLoading]      = useState(true);
  const [showAdd,      setShowAdd]      = useState(false);
  const [showAllFriends, setShowAllFriends] = useState(false);
  const [profileFor,   setProfileFor]   = useState(null);

  useEffect(() => {
    if (!uid) return;
    let cancelled = false;

    async function load() {
      setLoading(true);
      const [fr, pend] = await Promise.all([loadFriends(uid), loadPendingRequests(uid)]);
      if (cancelled) return;
      const frList  = fr   || [];
      const pendList = pend || [];
      console.log('[GymBros] Friends:', frList);
      console.log('[GymBros] Pending:', pendList);
      setFriends(frList);
      setPending(pendList);

      const friendIds = frList.map(f => f.id);
      const [feedData, myScore] = await Promise.all([
        friendIds.length > 0 ? loadActivityFeed(uid, friendIds) : Promise.resolve([]),
        calculateLeaderboardScore(uid),
      ]);
      if (cancelled) return;

      if (feedData?.length) setFeed(feedData);
      updateLeaderboardScore(uid).catch(() => {});

      // Build leaderboard
      const now = new Date();
      const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

      const myEntry = {
        id: uid,
        name: state.profile?.name || 'You',
        username: state.username || null,
        score:          myScore?.score          ?? 0,
        setsCompleted:  myScore?.setsCompleted  ?? 0,
        setsProgrammed: myScore?.setsProgrammed ?? 20,
        improvementPct: myScore?.improvementPct ?? 0,
        isMe: true,
      };

      const friendEntries = frList.map(f => {
        const ld = f.leaderboard_data;
        const isCurrent = ld?.month === currentMonth;
        return {
          id: f.id, name: f.name, username: f.username,
          score:          isCurrent ? (ld?.score          ?? 0) : 0,
          setsCompleted:  isCurrent ? (ld?.setsCompleted  ?? 0) : 0,
          setsProgrammed: ld?.setsProgrammed ?? 20,
          improvementPct: ld?.improvementPct ?? 0,
          isMe: false,
        };
      });

      const sorted = [myEntry, ...friendEntries]
        .sort((a, b) => b.score !== a.score ? b.score - a.score : (a.name || '').localeCompare(b.name || ''))
        .map((e, i) => ({ ...e, rank: i + 1 }));

      console.log('[GymBros] Leaderboard:', sorted);
      if (!cancelled) { setLeaderboard(sorted); setLoading(false); }
    }

    load();
    return () => { cancelled = true; };
  }, [uid]);

  // Who trained today (from feed — used for avatar ring colours)
  const trainedTodaySet = (() => {
    const todayStr = new Date().toDateString();
    const s = new Set();
    for (const item of feed) {
      if (item.type === 'session_completed' &&
          new Date(item.created_at).toDateString() === todayStr) {
        s.add(item.user_id);
      }
    }
    return s;
  })();

  const handleAccept  = (req) => {
    setPending(p => p.filter(r => r.friendshipId !== req.friendshipId));
    setFriends(f => [...f, { id: req.userId, name: req.name, username: req.username }]);
  };
  const handleDecline = (req) => {
    setPending(p => p.filter(r => r.friendshipId !== req.friendshipId));
  };

  if (!uid) return (
    <div style={{ padding: 32, textAlign: 'center', color: C.mute }}>Sign in to use Gym Bros</div>
  );

  return (
    <>
      {/* ── Fixed header ──────────────────────────────────────────────────────── */}
      <div style={{ padding: '14px 16px 0', background: '#111' }}>

        {/* Row 1: Title + Add button */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <div style={{ fontSize: 22, fontWeight: 800, color: C.text, letterSpacing: '-0.03em' }}>
            Gym Bros
          </div>
          <motion.button whileTap={{ scale: 0.93 }} onClick={() => setShowAdd(true)} style={{
            width: 32, height: 32, borderRadius: '50%',
            background: LIME, border: 'none',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer',
          }}>
            <Plus size={16} color="#000" strokeWidth={3} />
          </motion.button>
        </div>

        {/* Row 2: YOUR BROS label + See all */}
        <SectionLabel
          right={
            friends.length > 0 && (
              <motion.button whileTap={{ scale: 0.95 }} onClick={() => setShowAllFriends(true)} style={{
                background: 'none', border: 'none', cursor: 'pointer',
                fontSize: 11, fontWeight: 700, color: LIME, padding: 0,
              }}>
                See all →
              </motion.button>
            )
          }
        >
          YOUR BROS
        </SectionLabel>

        {/* Row 3: Horizontal friends bubbles */}
        <div style={{
          display: 'flex', gap: 12, overflowX: 'auto',
          paddingBottom: 14,
          // Hide scrollbar
          scrollbarWidth: 'none', msOverflowStyle: 'none',
          WebkitOverflowScrolling: 'touch',
        }}>
          {loading ? (
            // Skeleton bubbles
            [1, 2, 3].map(i => (
              <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5, flexShrink: 0 }}>
                <div style={{ width: 48, height: 48, borderRadius: '50%', background: '#1e1e1e', border: '2.5px solid #2a2a2a' }} />
                <div style={{ width: 36, height: 8, background: '#1e1e1e', borderRadius: 4 }} />
              </div>
            ))
          ) : (
            <>
              {friends.map(f => (
                <FriendBubble
                  key={f.id}
                  friend={f}
                  trainedToday={trainedTodaySet.has(f.id)}
                  onTap={setProfileFor}
                />
              ))}
              <AddBubble onTap={() => setShowAdd(true)} />
            </>
          )}
        </div>

        {/* Divider */}
        <div style={{ borderTop: '1px solid #1a1a1a', marginLeft: -16, marginRight: -16 }} />
      </div>

      {/* ── Scrollable body ────────────────────────────────────────────────────── */}
      <div style={{ padding: '0 16px' }}>

        {/* Pending requests */}
        {!loading && pending.length > 0 && (
          <div style={{ marginTop: 14 }}>
            <SectionLabel>REQUESTS ({pending.length})</SectionLabel>
            {pending.map(req => (
              <RequestRow key={req.friendshipId} req={req} onAccept={handleAccept} onDecline={handleDecline} />
            ))}
          </div>
        )}

        {/* Leaderboard */}
        {leaderboard.length > 1 && (
          <div style={{ marginTop: 14 }}>
            <SectionLabel>LEADERBOARD · THIS MONTH</SectionLabel>
            <div style={{
              background: '#161616', borderRadius: 12,
              border: '1px solid #1e1e1e', overflow: 'hidden',
            }}>
              {loading ? (
                [1, 2, 3].map(i => <SkeletonRow key={i} />)
              ) : (
                leaderboard.map(entry => (
                  <LeaderboardRow
                    key={entry.id}
                    rank={entry.rank}
                    user={entry}
                    isMe={entry.isMe}
                    onTap={() => {
                      const f = friends.find(fr => fr.id === entry.id);
                      if (f) setProfileFor(f);
                    }}
                  />
                ))
              )}
            </div>
          </div>
        )}

        {/* Activity feed */}
        {!loading && feed.length > 0 && (
          <div style={{ marginTop: 14 }}>
            <SectionLabel>RECENT ACTIVITY</SectionLabel>
            <div style={{ marginBottom: 8 }}>
              {feed.slice(0, 20).map((item, i) => (
                <ActivityItem
                  key={item.id || i}
                  item={item}
                  currentUserId={uid}
                  onProfileTap={(userId) => {
                    const f = friends.find(fr => fr.id === userId);
                    if (f) setProfileFor(f);
                  }}
                />
              ))}
            </div>
          </div>
        )}

        {/* Empty state — no friends and not loading */}
        {!loading && friends.length === 0 && pending.length === 0 && (
          <div style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            padding: '40px 24px', gap: 10,
          }}>
            <div style={{ fontSize: 44 }}>🏋️</div>
            <div style={{ fontSize: 16, fontWeight: 800, color: C.text, textAlign: 'center' }}>No Bros yet</div>
            <div style={{ fontSize: 13, color: C.dim, textAlign: 'center', lineHeight: 1.5 }}>
              Invite your gym friends and compete on the leaderboard
            </div>
            <motion.button whileTap={{ scale: 0.97 }} onClick={() => setShowAdd(true)} style={{
              marginTop: 8, background: LIME, border: 'none', borderRadius: 12,
              padding: '13px 28px', fontSize: 14, fontWeight: 800, color: '#000',
              cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8,
            }}>
              <UserPlus size={15} />Add your first Bro
            </motion.button>
          </div>
        )}

      </div>

      {/* ── Sheets & pages ─────────────────────────────────────────────────────── */}
      <AnimatePresence>
        {showAdd && (
          <AddBroSheet
            key="add-bro"
            currentUserId={uid}
            username={state.username}
            onClose={() => setShowAdd(false)}
            onRequestSent={() => showToast?.('Friend request sent ✓')}
          />
        )}
      </AnimatePresence>

      <AnimatePresence>
        {showAllFriends && (
          <AllFriendsPage
            key="all-friends"
            friends={friends}
            currentUserId={uid}
            onTap={(f) => { setShowAllFriends(false); setProfileFor(f); }}
            onBack={() => setShowAllFriends(false)}
          />
        )}
      </AnimatePresence>

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
