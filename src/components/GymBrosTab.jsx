import { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  UserPlus, Search, Check, X, ChevronRight, Plus,
  Trophy, Dumbbell, Share2, Copy, Info,
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
function RequestRow({ req, onAccept, onDecline, ar }) {
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
        <div style={{ fontSize: 11, color: C.mute }}>{ar ? 'يريد أن يكون صديقاً لك' : 'Wants to be your Bro'}</div>
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
function AddBubble({ onTap, ar }) {
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
      <div style={{ fontSize: 10, fontWeight: 600, color: '#444' }}>{ar ? 'إضافة' : 'Add'}</div>
    </motion.div>
  );
}

// ── All Friends slide-over page ────────────────────────────────────────────────
function AllFriendsPage({ friends, currentUserId, onTap, onBack, ar }) {
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
          <div style={{ fontSize: 16, fontWeight: 800, color: C.text }}>{ar ? 'أصدقاؤك' : 'Your Bros'}</div>
          <div style={{ fontSize: 11, color: C.mute }}>
            {ar ? `${friends.length} صديق` : `${friends.length} ${friends.length === 1 ? 'bro' : 'bros'}`}
          </div>
        </div>
      </div>

      {/* List */}
      <div style={{ flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch' }}>
        {friends.length === 0 ? (
          <div style={{ padding: '48px 24px', textAlign: 'center', color: C.mute, fontSize: 14 }}>
            {ar ? 'لا أصدقاء بعد — أضف بعضهم!' : 'No Bros yet — add some!'}
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
function LeaderboardRow({ rank, user, isMe, onTap, ar }) {
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
        <div style={{ fontSize: 10, color: '#555' }}>{ar ? 'نقطة' : 'pts'}</div>
      </div>

      {/* Chevron */}
      {!isMe && <ChevronRight size={14} color="#333" />}
      {isMe  && <div style={{ width: 14 }} />}
    </motion.div>
  );
}

// ── Activity item ──────────────────────────────────────────────────────────────
function ActivityItem({ item, currentUserId, onProfileTap, ar }) {
  const isMe = item.user_id === currentUserId;
  // Display @username when available, fall back to name
  const displayName = isMe
    ? (ar ? 'أنت' : 'You')
    : item.profile?.username
      ? `@${item.profile.username}`
      : (item.profile?.name || (ar ? 'صديق صالة' : 'Gym Bro'));
  const time = (() => {
    const d = new Date(item.created_at);
    const diff = Date.now() - d.getTime();
    if (ar) {
      if (diff < 60000) return 'الآن';
      if (diff < 3600000) return `منذ ${Math.floor(diff / 60000)}د`;
      if (diff < 86400000) return `منذ ${Math.floor(diff / 3600000)}س`;
      return d.toLocaleDateString('ar-SA', { month: 'short', day: 'numeric' });
    }
    if (diff < 60000) return 'just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    return d.toLocaleDateString('en-GB', { month: 'short', day: 'numeric' });
  })();
  const body = (() => {
    if (item.type === 'session_completed') {
      const vol = item.data?.volume;
      const volStr = vol && vol > 0 ? ` · ${Math.round(vol).toLocaleString()} كجم` : '';
      const volStrEn = vol && vol > 0 ? ` · ${Math.round(vol).toLocaleString()} kg` : '';
      const name = item.data?.session_name || (ar ? 'جلسة' : 'a session');
      return ar
        ? `أتم "${name}"${volStr}`
        : `completed "${name}"${volStrEn}`;
    }
    if (item.type === 'new_pr') {
      const prev = item.data?.previous_weight;
      const exName = item.data?.exercise_name || (ar ? 'تمرين' : 'an exercise');
      return ar
        ? `رقم قياسي في ${exName}: ${item.data?.weight} كجم${prev > 0 ? ` (كان ${prev})` : ''}`
        : `PR on ${exName}: ${item.data?.weight} kg${prev > 0 ? ` (was ${prev})` : ''}`;
    }
    return ar ? 'أنجز شيئاً رائعاً' : 'did something impressive';
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
        {displayName.replace(/^@/, '')[0]?.toUpperCase() ?? '?'}
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
function AddBroSheet({ currentUserId, username, onClose, onRequestSent, ar }) {
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
      ? `Hey! Join me on HEX 💪 I'm @${username}. Use this link to connect with me: ${inviteLink}`
      : `Hey! Join me on HEX 💪 Use this link to add me as a Gym Bro: ${inviteLink}`;
    if (navigator.share) {
      navigator.share({ title: 'Join me on HEX!', text: msg, url: inviteLink }).catch(() => {});
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
          <div style={{ fontSize: 17, fontWeight: 800, color: C.text, marginBottom: 14 }}>{ar ? 'إضافة صديق' : 'Add a Bro'}</div>
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
                {t === 'invite' ? (ar ? 'رابط الدعوة' : 'Invite link') : (ar ? 'البحث' : 'Search users')}
              </button>
            ))}
          </div>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: '0 20px' }}>
          {tab === 'invite' && (
            <div>
              <div style={{ fontSize: 13, color: C.dim, marginBottom: 16, lineHeight: 1.5 }}>
                {ar
                  ? 'شارك هذا الرابط — يتيح لهم إضافتك كصديق فوراً. ينتهي خلال ٤٨ ساعة.'
                  : 'Share this link — it lets them add you as a Bro instantly. Expires in 48h.'}
              </div>
              {genLoading ? (
                <div style={{ background: '#1e1e1e', borderRadius: 12, padding: '14px 16px', fontSize: 13, color: C.mute, textAlign: 'center' }}>
                  {ar ? 'جارٍ إنشاء الرابط…' : 'Generating link…'}
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
                      {copied ? (ar ? 'تم النسخ!' : 'Copied!') : (ar ? 'نسخ' : 'Copy')}
                    </motion.button>
                    <motion.button whileTap={{ scale: 0.97 }} onClick={shareLink} style={{
                      flex: 1, background: LIME, border: 'none', borderRadius: 10, padding: '12px 0',
                      fontSize: 13, fontWeight: 800, color: '#000', cursor: 'pointer',
                      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7,
                    }}>
                      <Share2 size={13} />{ar ? 'مشاركة' : 'Share'}
                    </motion.button>
                  </div>
                  <motion.button whileTap={{ scale: 0.97 }} onClick={genLink} style={{
                    marginTop: 10, width: '100%', background: 'transparent', border: 'none',
                    padding: '8px 0', fontSize: 12, color: '#444', cursor: 'pointer',
                  }}>
                    {ar ? 'إنشاء رابط جديد' : 'Generate new link'}
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
                  placeholder={ar ? 'ابحث باسم المستخدم أو الاسم…' : 'Search by username or name…'}
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
                    {sent[u.id] === 'sending' ? '…' : sent[u.id] === 'sent' ? (ar ? 'تم ✓' : 'Sent ✓') : (ar ? 'إضافة' : 'Add')}
                  </motion.button>
                </div>
              ))}
              {query && !searching && results.length === 0 && (
                <div style={{ textAlign: 'center', padding: '24px 0', color: C.mute, fontSize: 13 }}>
                  {ar ? `لا مستخدمين لـ "${query}"` : `No users found for "${query}"`}
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

// ── Points info card (bottom sheet) ───────────────────────────────────────────
function PointsInfoCard({ onClose, ar }) {
  return createPortal(
    <motion.div
      initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
      onClick={onClose}
      style={{
        position: 'fixed', inset: 0, zIndex: 7000,
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
          paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 16px, 28px)',
          direction: ar ? 'rtl' : 'ltr',
          maxHeight: '88vh', display: 'flex', flexDirection: 'column',
        }}
      >
        {/* Handle + header */}
        <div style={{ padding: '14px 20px 0', flexShrink: 0 }}>
          <div style={{ width: 36, height: 4, borderRadius: 2, background: '#2a2a2a', margin: '0 auto 16px' }} />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
            <div>
              <div style={{ fontSize: 18, fontWeight: 800, color: LIME }}>
                {ar ? 'كيف تُحسب النقاط؟' : 'How points are calculated'}
              </div>
              <div style={{ fontSize: 12, color: '#555', marginTop: 3 }}>
                {ar ? 'نقاط من ١٠٠ — تُعاد شهرياً' : 'Score out of 100 · resets every month'}
              </div>
            </div>
            <motion.button whileTap={{ scale: 0.9 }} onClick={onClose} style={{
              width: 30, height: 30, borderRadius: 8,
              background: '#1e1e1e', border: '1.5px solid #2a2a2a',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer', flexShrink: 0,
            }}>
              <X size={14} color="#555" />
            </motion.button>
          </div>
        </div>

        {/* Scrollable body */}
        <div style={{ overflowY: 'auto', WebkitOverflowScrolling: 'touch', padding: '0 20px', display: 'flex', flexDirection: 'column', gap: 12 }}>

          {/* ── Formula pill ── */}
          <div style={{
            background: '#111', border: `1.5px solid ${LIME}33`,
            borderRadius: 14, padding: '14px 16px',
          }}>
            <div style={{ fontSize: 10, fontWeight: 700, color: LIME, letterSpacing: '0.08em', marginBottom: 10 }}>
              {ar ? 'المعادلة' : 'THE FORMULA'}
            </div>
            <div style={{ fontSize: 13, fontWeight: 700, color: '#ccc', marginBottom: 12, lineHeight: 1.6 }}>
              {ar
                ? 'النقاط = (الالتزام × ٧٠٪) + (التحسن × ٣٠٪)'
                : 'Score = (Consistency × 70%) + (Improvement × 30%)'}
            </div>
            {/* Visual bar */}
            <div style={{ display: 'flex', height: 8, borderRadius: 4, overflow: 'hidden', gap: 2 }}>
              <div style={{ width: '70%', background: LIME, borderRadius: 4 }} />
              <div style={{ width: '30%', background: '#ADFF2F88', borderRadius: 4 }} />
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 5 }}>
              <span style={{ fontSize: 10, color: LIME, fontWeight: 700 }}>{ar ? 'الالتزام ٧٠٪' : 'Consistency 70%'}</span>
              <span style={{ fontSize: 10, color: '#ADFF2F88', fontWeight: 700 }}>{ar ? 'التحسن ٣٠٪' : 'Improvement 30%'}</span>
            </div>
          </div>

          {/* ── Consistency block ── */}
          <div style={{ background: '#1a1a1a', borderRadius: 14, border: '1px solid #2a2a2a', overflow: 'hidden' }}>
            <div style={{ padding: '12px 14px', borderBottom: '1px solid #222' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                <span style={{ fontSize: 18 }}>✅</span>
                <span style={{ fontSize: 14, fontWeight: 800, color: LIME }}>
                  {ar ? 'الالتزام — ٧٠ نقطة' : 'Consistency — 70 pts'}
                </span>
              </div>
              <div style={{ fontSize: 12, color: '#666', lineHeight: 1.5 }}>
                {ar
                  ? 'عدد المجموعات التي أتممتها هذا الشهر مقسوماً على المجموعات المبرمجة في برنامجك.'
                  : 'Sets you completed this month divided by the sets programmed in your programme.'}
              </div>
            </div>
            {/* Example rows */}
            {[
              ar
                ? { label: 'أتممت ٢٠ من أصل ٢٠ مجموعة', value: '١٠٠', highlight: true }
                : { label: 'Complete 20 of 20 programmed sets', value: '100', highlight: true },
              ar
                ? { label: 'أتممت ١٤ من أصل ٢٠ مجموعة', value: '٧٠', highlight: false }
                : { label: 'Complete 14 of 20 programmed sets', value: '70', highlight: false },
              ar
                ? { label: 'تجاوزت البرنامج (أكثر من ١٠٠٪)', value: '١٠٠', highlight: true }
                : { label: 'Exceed your programme (over 100%)', value: '100', highlight: true },
            ].map((row, i) => (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                padding: '9px 14px', borderTop: '1px solid #1e1e1e',
              }}>
                <span style={{ fontSize: 12, color: '#666' }}>{row.label}</span>
                <span style={{ fontSize: 13, fontWeight: 800, color: row.highlight ? LIME : '#aaa' }}>
                  {row.value} {ar ? 'نقطة' : 'pts'}
                </span>
              </div>
            ))}
          </div>

          {/* ── Improvement block ── */}
          <div style={{ background: '#1a1a1a', borderRadius: 14, border: '1px solid #2a2a2a', overflow: 'hidden' }}>
            <div style={{ padding: '12px 14px', borderBottom: '1px solid #222' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                <span style={{ fontSize: 18 }}>📈</span>
                <span style={{ fontSize: 14, fontWeight: 800, color: '#ADFF2F88' }}>
                  {ar ? 'التحسن — ٣٠ نقطة' : 'Improvement — 30 pts'}
                </span>
              </div>
              <div style={{ fontSize: 12, color: '#666', lineHeight: 1.5 }}>
                {ar
                  ? 'متوسط نسبة تحسن الحجم لكل تمرين (الوزن × التكرارات) مقارنةً بأول تسجيل لك.'
                  : 'Average volume gain per exercise (weight × reps) vs. your very first logged set — averaged across all your exercises.'}
              </div>
            </div>
            {[
              ar
                ? { label: 'بدأت بـ ٥٠ كجم، والآن ٦٥ كجم (+٣٠٪)', value: '٩ / ٣٠', highlight: false }
                : { label: 'Started 50 kg → now 65 kg (+30% vol.)', value: '9 / 30', highlight: false },
              ar
                ? { label: 'حسّنت كل تمارينك بأكثر من ١٠٠٪', value: '٣٠ / ٣٠', highlight: true }
                : { label: 'Improved every exercise by 100%+', value: '30 / 30', highlight: true },
              ar
                ? { label: 'كل تمرين محدود بـ ١٠٠٪ كحد أقصى', value: '—', highlight: false }
                : { label: 'Each exercise capped at 100% gain', value: '—', highlight: false },
            ].map((row, i) => (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                padding: '9px 14px', borderTop: '1px solid #1e1e1e',
              }}>
                <span style={{ fontSize: 12, color: '#666', flex: 1, paddingRight: 8 }}>{row.label}</span>
                <span style={{ fontSize: 13, fontWeight: 800, color: row.highlight ? LIME : '#aaa', flexShrink: 0 }}>
                  {row.value}
                </span>
              </div>
            ))}
          </div>

          {/* ── Tips ── */}
          <div style={{ background: '#1a1a1a', borderRadius: 14, border: '1px solid #2a2a2a', padding: '12px 14px' }}>
            <div style={{ fontSize: 10, fontWeight: 700, color: '#555', letterSpacing: '0.07em', marginBottom: 10 }}>
              {ar ? 'نصائح للتصدر' : 'TIPS TO CLIMB THE BOARD'}
            </div>
            {(ar ? [
              'أكمل كل مجموعات البرنامج هذا الشهر',
              'زِد الوزن التدريجي في كل تمرين',
              'النقاط تُحدَّث تلقائياً بعد كل جلسة',
              'النقاط تُعاد في أول كل شهر — ابدأ قوياً',
            ] : [
              'Complete every programmed set this month',
              'Progressively add weight to each exercise',
              'Your score updates automatically after every session',
              'Scores reset on the 1st of each month — start strong',
            ]).map((tip, i) => (
              <div key={i} style={{ display: 'flex', gap: 8, marginBottom: i < 3 ? 8 : 0 }}>
                <span style={{ color: LIME, fontSize: 12, flexShrink: 0, marginTop: 1 }}>→</span>
                <span style={{ fontSize: 12, color: '#666', lineHeight: 1.5 }}>{tip}</span>
              </div>
            ))}
          </div>

        </div>
      </motion.div>
    </motion.div>,
    document.body
  );
}

// ── GymBrosTab ─────────────────────────────────────────────────────────────────
export default function GymBrosTab({ state }) {
  const { user, showToast, lang = 'en' } = state;
  const ar = lang === 'ar';
  const uid = user?.id;

  const [friends,      setFriends]      = useState([]);
  const [pending,      setPending]      = useState([]);
  const [feed,         setFeed]         = useState([]);
  const [leaderboard,  setLeaderboard]  = useState([]);
  const [loading,      setLoading]      = useState(true);
  const [showAdd,      setShowAdd]      = useState(false);
  const [showAllFriends, setShowAllFriends] = useState(false);
  const [profileFor,   setProfileFor]   = useState(null);
  const [showPointsInfo, setShowPointsInfo] = useState(false);

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
    <div style={{ padding: 32, textAlign: 'center', color: C.mute }}>
      {ar ? 'سجّل الدخول لاستخدام أصدقاء الصالة' : 'Sign in to use Gym Bros'}
    </div>
  );

  return (
    <>
      {/* ── Fixed header ──────────────────────────────────────────────────────── */}
      <div style={{ padding: '14px 16px 0', background: '#111' }}>

        {/* Row 1: Title + Add button */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <div style={{ fontSize: 22, fontWeight: 800, color: C.text, letterSpacing: ar ? '0' : '-0.03em', fontFamily: ar ? "'ThmanyahSans', sans-serif" : undefined }}>
            {ar ? 'أصدقاء الصالة' : 'Gym Bros'}
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
                {ar ? '← عرض الكل' : 'See all →'}
              </motion.button>
            )
          }
        >
          {ar ? 'أصدقاؤك' : 'YOUR BROS'}
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
              <AddBubble onTap={() => setShowAdd(true)} ar={ar} />
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
            <SectionLabel>{ar ? `الطلبات (${pending.length})` : `REQUESTS (${pending.length})`}</SectionLabel>
            {pending.map(req => (
              <RequestRow key={req.friendshipId} req={req} onAccept={handleAccept} onDecline={handleDecline} ar={ar} />
            ))}
          </div>
        )}

        {/* Leaderboard */}
        {leaderboard.length > 1 && (
          <div style={{ marginTop: 14 }}>
            <SectionLabel
              right={
                <motion.button
                  whileTap={{ scale: 0.9 }}
                  onClick={() => setShowPointsInfo(true)}
                  style={{
                    background: 'none', border: 'none', cursor: 'pointer',
                    display: 'flex', alignItems: 'center', gap: 5,
                    padding: '2px 0',
                    WebkitTapHighlightColor: 'transparent',
                  }}
                >
                  <span style={{ fontSize: 10, fontWeight: 700, color: '#444' }}>
                    {ar ? 'كيف تعمل النقاط؟' : 'How points work'}
                  </span>
                  <Info size={13} color="#444" />
                </motion.button>
              }
            >
              {ar ? 'المتصدرون · هذا الشهر' : 'LEADERBOARD · THIS MONTH'}
            </SectionLabel>
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
                    ar={ar}
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
            <SectionLabel>{ar ? 'النشاط الأخير' : 'RECENT ACTIVITY'}</SectionLabel>
            <div style={{ marginBottom: 8 }}>
              {feed.slice(0, 20).map((item, i) => (
                <ActivityItem
                  key={item.id || i}
                  item={item}
                  currentUserId={uid}
                  ar={ar}
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
            <div style={{ fontSize: 16, fontWeight: 800, color: C.text, textAlign: 'center' }}>
              {ar ? 'لا أصدقاء بعد' : 'No Bros yet'}
            </div>
            <div style={{ fontSize: 13, color: C.dim, textAlign: 'center', lineHeight: 1.5 }}>
              {ar
                ? 'ادعُ أصدقاء الصالة وتنافسوا على قائمة المتصدرين'
                : 'Invite your gym friends and compete on the leaderboard'}
            </div>
            <motion.button whileTap={{ scale: 0.97 }} onClick={() => setShowAdd(true)} style={{
              marginTop: 8, background: LIME, border: 'none', borderRadius: 12,
              padding: '13px 28px', fontSize: 14, fontWeight: 800, color: '#000',
              cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8,
            }}>
              <UserPlus size={15} />{ar ? 'أضف أول صديق' : 'Add your first Bro'}
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
            ar={ar}
            onClose={() => setShowAdd(false)}
            onRequestSent={() => showToast?.(ar ? 'تم إرسال طلب الصداقة ✓' : 'Friend request sent ✓')}
          />
        )}
      </AnimatePresence>

      <AnimatePresence>
        {showAllFriends && (
          <AllFriendsPage
            key="all-friends"
            friends={friends}
            currentUserId={uid}
            ar={ar}
            onTap={(f) => { setShowAllFriends(false); setProfileFor(f); }}
            onBack={() => setShowAllFriends(false)}
          />
        )}
      </AnimatePresence>

      <AnimatePresence>
        {showPointsInfo && (
          <PointsInfoCard
            key="points-info"
            ar={ar}
            onClose={() => setShowPointsInfo(false)}
          />
        )}
      </AnimatePresence>

      <AnimatePresence>
        {profileFor && (
          <FriendProfilePage
            key={profileFor.id}
            friendId={profileFor.id}
            currentUserId={uid}
            lang={lang}
            onBack={() => setProfileFor(null)}
            onRemoved={() => {
              setFriends(f => f.filter(fr => fr.id !== profileFor.id));
              showToast?.(ar ? 'تمت إزالة الصديق' : 'Bro removed');
            }}
          />
        )}
      </AnimatePresence>
    </>
  );
}
