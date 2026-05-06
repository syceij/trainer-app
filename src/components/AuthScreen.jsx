import { useState, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Eye, EyeOff, Loader } from 'lucide-react';
import { supabase } from '../lib/supabase.js';
import { upsertProfile } from '../lib/db.js';
import { C, spring, springSoft } from '../tokens.js';

const USERNAME_RE = /^[a-z0-9_]{3,20}$/;
const GREEN = '#ADFF2F';
const RED   = '#E24B4A';

// ── Shared primitives ─────────────────────────────────────────────────────────

function Logo() {
  return (
    <motion.div
      initial={{ scale: 0.8, opacity: 0 }}
      animate={{ scale: 1, opacity: 1 }}
      transition={{ ...spring, delay: 0.05 }}
      style={{ marginBottom: 40 }}
    >
      <img src="/logo.png" alt="HEX" style={{ height: 70, width: 'auto', objectFit: 'contain', display: 'block' }} />
    </motion.div>
  );
}

function Field({ label, type, value, onChange, autoComplete, placeholder }) {
  const [show, setShow] = useState(false);
  const isPassword = type === 'password';
  return (
    <div style={{ marginBottom: 14 }}>
      <label style={{
        display: 'block', fontSize: 12, fontWeight: 700,
        color: C.dim, marginBottom: 6, letterSpacing: '0.04em',
      }}>
        {label.toUpperCase()}
      </label>
      <div style={{ position: 'relative' }}>
        <input
          type={isPassword && show ? 'text' : type}
          value={value}
          onChange={e => onChange(e.target.value)}
          autoComplete={autoComplete}
          placeholder={placeholder}
          style={{
            width: '100%', boxSizing: 'border-box',
            background: C.surface2, border: `1.5px solid ${C.border}`,
            borderRadius: 12, padding: '14px 16px',
            paddingRight: isPassword ? 44 : 16,
            color: C.text, fontSize: 16, outline: 'none',
            fontFamily: 'Inter, system-ui, sans-serif',
            WebkitTapHighlightColor: 'transparent',
          }}
          onFocus={e => { e.target.style.borderColor = C.accent; }}
          onBlur={e => { e.target.style.borderColor = C.border; }}
        />
        {isPassword && (
          <button
            type="button"
            onClick={() => setShow(s => !s)}
            style={{
              position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)',
              background: 'none', border: 'none', cursor: 'pointer', padding: 4,
              color: C.mute, display: 'flex', alignItems: 'center',
            }}
          >
            {show ? <EyeOff size={16} /> : <Eye size={16} />}
          </button>
        )}
      </div>
    </div>
  );
}

// ── Username field — real-time availability check ─────────────────────────────
// status: 'idle' | 'short' | 'checking' | 'available' | 'taken' | 'invalid'
function UsernameField({ value, onChange, status }) {
  const hasDecision = status === 'available' || status === 'taken';
  const isError     = status === 'taken' || status === 'invalid';
  const borderCol   = hasDecision ? (status === 'available' ? GREEN : RED) : C.border;

  let hint = null;
  if (status === 'invalid')        hint = { color: RED,    text: 'Letters, numbers and _ only' };
  else if (status === 'checking')  hint = { color: C.mute, text: 'Checking availability…' };
  else if (status === 'available') hint = { color: GREEN,  text: '✓ Available' };
  else if (status === 'taken')     hint = { color: RED,    text: '✗ Already taken' };
  else                             hint = { color: C.mute, text: '3–20 chars · letters, numbers and _ only' };

  return (
    <div style={{ marginBottom: 14 }}>
      <label style={{
        display: 'block', fontSize: 12, fontWeight: 700,
        color: C.dim, marginBottom: 6, letterSpacing: '0.04em',
      }}>
        USERNAME
      </label>
      <div style={{ position: 'relative' }}>
        <input
          type="text"
          value={value}
          onChange={e => onChange(e.target.value.toLowerCase().replace(/\s/g, ''))}
          autoComplete="username"
          placeholder="e.g. ahmed_lifts"
          maxLength={20}
          style={{
            width: '100%', boxSizing: 'border-box',
            background: C.surface2,
            border: `1.5px solid ${isError ? RED : borderCol}`,
            borderRadius: 12, padding: '14px 16px',
            paddingRight: hasDecision ? 44 : 16,
            color: C.text, fontSize: 16, outline: 'none',
            fontFamily: 'Inter, system-ui, sans-serif',
            WebkitTapHighlightColor: 'transparent',
            transition: 'border-color 0.18s',
          }}
          onFocus={e => {
            e.target.style.borderColor = hasDecision
              ? (status === 'available' ? GREEN : RED)
              : C.accent;
          }}
          onBlur={e => { e.target.style.borderColor = isError ? RED : borderCol; }}
        />
        {hasDecision && (
          <div style={{
            position: 'absolute', right: 14, top: '50%', transform: 'translateY(-50%)',
            fontSize: 17, fontWeight: 800, lineHeight: 1,
            color: status === 'available' ? GREEN : RED,
          }}>
            {status === 'available' ? '✓' : '✗'}
          </div>
        )}
      </div>
      {hint && (
        <div style={{ fontSize: 11, color: hint.color, marginTop: 5, lineHeight: 1.4 }}>
          {hint.text}
        </div>
      )}
    </div>
  );
}

function PrimaryButton({ children, onClick, loading, disabled }) {
  return (
    <motion.button
      whileTap={{ scale: loading ? 1 : 0.97 }}
      onClick={onClick}
      disabled={disabled || loading}
      style={{
        width: '100%',
        background: disabled || loading ? C.surface2 : C.accent,
        border: 'none', borderRadius: 14,
        padding: '16px 0', fontSize: 15, fontWeight: 800,
        color: disabled || loading ? C.mute : '#000',
        cursor: disabled ? 'default' : 'pointer',
        touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        marginTop: 8, transition: 'background 0.15s',
      }}
    >
      {loading
        ? (
          <motion.div
            animate={{ rotate: 360 }}
            transition={{ repeat: Infinity, duration: 0.8, ease: 'linear' }}
            style={{ display: 'flex' }}
          >
            <Loader size={18} color={C.mute} />
          </motion.div>
        )
        : children
      }
    </motion.button>
  );
}

function ErrorBanner({ msg }) {
  if (!msg) return null;
  return (
    <motion.div
      initial={{ opacity: 0, y: -6 }}
      animate={{ opacity: 1, y: 0 }}
      style={{
        background: 'rgba(255,80,80,0.1)', border: '1px solid rgba(255,80,80,0.3)',
        borderRadius: 10, padding: '10px 14px', marginBottom: 16,
        fontSize: 13, color: '#ff6b6b', lineHeight: 1.5,
      }}
    >
      {msg}
    </motion.div>
  );
}

// ── Login view ────────────────────────────────────────────────────────────────
function LoginView({ onSwitch, onSuccess }) {
  const [emailOrUsername, setEmailOrUsername] = useState('');
  const [password,        setPassword]        = useState('');
  const [error,           setError]           = useState('');
  const [loading,         setLoading]         = useState(false);

  const handleLogin = async () => {
    setError('');
    if (!emailOrUsername || !password) {
      setError('Please enter your email/username and password.');
      return;
    }
    setLoading(true);

    let resolvedEmail = emailOrUsername.trim();

    // Detect email: must contain @ with at least one . in the domain part
    const atIdx   = resolvedEmail.indexOf('@');
    const isEmail = atIdx > 0 && resolvedEmail.slice(atIdx + 1).includes('.');

    if (!isEmail) {
      // Username login — look up the email stored in profiles
      const { data: profile } = await supabase
        .from('profiles')
        .select('email')
        .eq('username', resolvedEmail.toLowerCase())
        .maybeSingle();

      if (!profile?.email) {
        setLoading(false);
        setError('No account found with that username.');
        return;
      }
      resolvedEmail = profile.email;
    }

    const { error: err } = await supabase.auth.signInWithPassword({
      email: resolvedEmail,
      password,
    });
    setLoading(false);
    if (err) {
      // Deliberately vague for security
      setError('Incorrect email/username or password.');
      return;
    }
    onSuccess();
  };

  const handleKey = (e) => { if (e.key === 'Enter') handleLogin(); };

  return (
    <motion.div
      key="login"
      initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }}
      transition={springSoft}
    >
      <Logo />
      <h2 style={{ fontSize: 26, fontWeight: 800, letterSpacing: '-0.02em', color: C.text, marginBottom: 6 }}>
        Welcome back
      </h2>
      <p style={{ fontSize: 14, color: C.dim, marginBottom: 28 }}>Sign in to continue</p>

      <ErrorBanner msg={error} />

      <Field
        label="Email or username"
        type="text"
        value={emailOrUsername}
        onChange={setEmailOrUsername}
        autoComplete="email"
        placeholder="Email or @username"
      />
      <Field
        label="Password"
        type="password"
        value={password}
        onChange={setPassword}
        autoComplete="current-password"
        placeholder="••••••••"
      />

      <div onKeyDown={handleKey}>
        <PrimaryButton onClick={handleLogin} loading={loading} disabled={!emailOrUsername || !password}>
          Sign in
        </PrimaryButton>
      </div>

      <p style={{ textAlign: 'center', marginTop: 20, fontSize: 13, color: C.dim }}>
        Don&apos;t have an account?{' '}
        <button onClick={onSwitch} style={{ background: 'none', border: 'none', color: C.accent, fontWeight: 700, cursor: 'pointer', fontSize: 13 }}>
          Sign up
        </button>
      </p>
    </motion.div>
  );
}

// ── Signup view ───────────────────────────────────────────────────────────────
function SignupView({ onSwitch, onConfirm }) {
  const [name,           setName]           = useState('');
  const [username,       setUsername]       = useState('');
  const [usernameStatus, setUsernameStatus] = useState('idle');
  const [email,          setEmail]          = useState('');
  const [password,       setPassword]       = useState('');
  const [error,          setError]          = useState('');
  const [loading,        setLoading]        = useState(false);
  const debounceRef = useRef(null);

  const handleUsernameChange = (val) => {
    const cleaned = val.toLowerCase().replace(/\s/g, '');
    setUsername(cleaned);
    clearTimeout(debounceRef.current);

    if (cleaned.length === 0)        { setUsernameStatus('idle');    return; }
    if (cleaned.length < 3)          { setUsernameStatus('short');   return; }
    if (!USERNAME_RE.test(cleaned))  { setUsernameStatus('invalid'); return; }

    setUsernameStatus('checking');
    debounceRef.current = setTimeout(async () => {
      const { data } = await supabase
        .from('profiles')
        .select('id')
        .eq('username', cleaned)
        .maybeSingle();
      setUsernameStatus(data ? 'taken' : 'available');
    }, 500);
  };

  const handleSignup = async () => {
    setError('');
    if (!name.trim())                   { setError('Please enter your name.'); return; }
    if (!username)                      { setError('Please choose a username.'); return; }
    if (!USERNAME_RE.test(username))    { setError('Username must be 3–20 chars: letters, numbers and _ only.'); return; }
    if (usernameStatus === 'taken')     { setError('That username is already taken.'); return; }
    if (usernameStatus === 'checking')  { setError('Please wait for the username check to finish.'); return; }
    if (usernameStatus !== 'available') { setError('Please choose a valid, available username.'); return; }
    if (!email)                         { setError('Please enter your email.'); return; }
    if (password.length < 6)           { setError('Password must be at least 6 characters.'); return; }

    setLoading(true);
    const timeout = new Promise((_, reject) =>
      setTimeout(() => reject(new Error('timeout')), 10000)
    );

    try {
      const { error: err } = await Promise.race([
        supabase.auth.signUp({
          email,
          password,
          options: {
            data: { name: name.trim() },
            emailRedirectTo: undefined,
          },
        }),
        timeout,
      ]);

      setLoading(false);

      if (err) {
        setError(
          err.message.toLowerCase().includes('already registered') ||
          err.message.toLowerCase().includes('already been registered')
            ? 'An account with this email already exists. Try signing in.'
            : err.message
        );
        return;
      }

      // Go to OTP screen — username travels with us so it gets saved after verification
      onConfirm({ email, name: name.trim(), username });
    } catch (e) {
      setLoading(false);
      setError(e.message === 'timeout' ? 'Something went wrong. Please try again.' : e.message);
    }
  };

  const ready = name.trim() && username && usernameStatus === 'available' && email && password.length >= 6;

  return (
    <motion.div
      key="signup"
      initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }}
      transition={springSoft}
    >
      <Logo />
      <h2 style={{ fontSize: 26, fontWeight: 800, letterSpacing: '-0.02em', color: C.text, marginBottom: 6 }}>
        Create account
      </h2>
      <p style={{ fontSize: 14, color: C.dim, marginBottom: 28 }}>Start your training journey</p>

      <ErrorBanner msg={error} />

      <Field label="Name" type="text" value={name} onChange={setName} autoComplete="given-name" placeholder="Your name" />
      <UsernameField value={username} onChange={handleUsernameChange} status={usernameStatus} />
      <Field label="Email" type="email" value={email} onChange={setEmail} autoComplete="email" placeholder="you@example.com" />
      <Field label="Password" type="password" value={password} onChange={setPassword} autoComplete="new-password" placeholder="Min. 6 characters" />

      <PrimaryButton onClick={handleSignup} loading={loading} disabled={!ready}>
        Create account
      </PrimaryButton>

      <p style={{ textAlign: 'center', marginTop: 20, fontSize: 13, color: C.dim }}>
        Already have an account?{' '}
        <button onClick={onSwitch} style={{ background: 'none', border: 'none', color: C.accent, fontWeight: 700, cursor: 'pointer', fontSize: 13 }}>
          Sign in
        </button>
      </p>
    </motion.div>
  );
}

// ── OTP verification view ─────────────────────────────────────────────────────
function OtpView({ email, name, username, onSuccess, onBack }) {
  const [digits,    setDigits]    = useState(['', '', '', '', '', '']);
  const [error,     setError]     = useState('');
  const [loading,   setLoading]   = useState(false);
  const [resending, setResending] = useState(false);
  const [resentOk,  setResentOk]  = useState(false);
  const inputRefs = useRef([]);

  const handleDigitChange = (index, value) => {
    const digit = value.replace(/\D/g, '').slice(-1);
    const next = [...digits];
    next[index] = digit;
    setDigits(next);
    setError('');
    if (digit && index < 5) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handleKeyDown = (index, e) => {
    if (e.key === 'Backspace') {
      if (digits[index]) {
        const next = [...digits];
        next[index] = '';
        setDigits(next);
      } else if (index > 0) {
        const next = [...digits];
        next[index - 1] = '';
        setDigits(next);
        inputRefs.current[index - 1]?.focus();
      }
    } else if (e.key === 'ArrowLeft'  && index > 0) { inputRefs.current[index - 1]?.focus(); }
      else if (e.key === 'ArrowRight' && index < 5) { inputRefs.current[index + 1]?.focus(); }
  };

  const handlePaste = (e) => {
    const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    if (!pasted) return;
    e.preventDefault();
    const next = Array.from({ length: 6 }, (_, i) => pasted[i] || '');
    setDigits(next);
    inputRefs.current[Math.min(pasted.length - 1, 5)]?.focus();
  };

  const handleVerify = async () => {
    const token = digits.join('');
    if (token.length < 6) { setError('Enter the 6-digit code.'); return; }

    setLoading(true);
    setError('');

    const { data, error: err } = await supabase.auth.verifyOtp({
      email,
      token,
      type: 'signup',
    });

    if (err) {
      setLoading(false);
      setError(
        err.message.toLowerCase().includes('expired')
          ? 'Code expired. Tap Resend to get a new one.'
          : 'Invalid code. Please try again.'
      );
      return;
    }

    // Session is live — persist name + username + email to profiles row
    if (data?.user) {
      try {
        await upsertProfile(data.user.id, {
          name:     name.trim(),
          lang:     'en',
          username: username || null,
          email:    email    || null,
        });
      } catch {
        // Non-critical — ensureProfileExists in App.jsx will catch it on next load
      }
    }

    setLoading(false);
    onSuccess();
  };

  const handleResend = async () => {
    setResending(true);
    setResentOk(false);
    setError('');
    const { error: err } = await supabase.auth.resend({ type: 'signup', email });
    setResending(false);
    if (err) setError(err.message);
    else {
      setResentOk(true);
      setDigits(['', '', '', '', '', '']);
      inputRefs.current[0]?.focus();
    }
  };

  const filled = digits.every(d => d !== '');

  return (
    <motion.div
      key="otp"
      initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }}
      transition={springSoft}
    >
      <button
        onClick={onBack}
        style={{
          background: 'none', border: 'none',
          color: C.dim, cursor: 'pointer',
          fontSize: 13, fontWeight: 600,
          display: 'flex', alignItems: 'center', gap: 4,
          marginBottom: 32, padding: 0,
          WebkitTapHighlightColor: 'transparent',
        }}
      >
        ← Back
      </button>

      <Logo />

      <h2 style={{ fontSize: 26, fontWeight: 800, letterSpacing: '-0.02em', color: C.text, marginBottom: 8 }}>
        Check your email
      </h2>
      <p style={{ fontSize: 14, color: C.dim, lineHeight: 1.6, marginBottom: 28 }}>
        Enter the 6-digit code sent to{' '}
        <span style={{ color: C.text, fontWeight: 700 }}>{email}</span>
      </p>

      <ErrorBanner msg={error} />

      <div
        style={{ display: 'flex', gap: 8, justifyContent: 'center', marginBottom: 28 }}
        onPaste={handlePaste}
      >
        {digits.map((d, i) => (
          <input
            key={i}
            ref={el => { inputRefs.current[i] = el; }}
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            autoComplete="one-time-code"
            maxLength={1}
            value={d}
            onChange={e => handleDigitChange(i, e.target.value)}
            onKeyDown={e => handleKeyDown(i, e)}
            style={{
              flex: 1, minWidth: 0, maxWidth: 52, height: 58,
              background: C.surface2,
              border: `1.5px solid ${d ? C.accent : C.border}`,
              borderRadius: 12,
              textAlign: 'center',
              fontSize: 24, fontWeight: 800, color: C.text,
              outline: 'none',
              fontFamily: 'Inter, system-ui, sans-serif',
              WebkitTapHighlightColor: 'transparent',
              caretColor: 'transparent',
            }}
            onFocus={e => { e.target.style.borderColor = C.accent; }}
            onBlur={e => { e.target.style.borderColor = d ? C.accent : C.border; }}
          />
        ))}
      </div>

      <PrimaryButton onClick={handleVerify} loading={loading} disabled={!filled}>
        Verify
      </PrimaryButton>

      <div style={{ textAlign: 'center', marginTop: 20 }}>
        {resentOk && (
          <motion.p
            initial={{ opacity: 0 }} animate={{ opacity: 1 }}
            style={{ fontSize: 12, color: '#4ADE80', marginBottom: 8 }}
          >
            Code resent ✓
          </motion.p>
        )}
        <button
          onClick={handleResend}
          disabled={resending}
          style={{
            background: 'none', border: 'none',
            color: resending ? C.mute : C.accent,
            fontWeight: 700,
            cursor: resending ? 'default' : 'pointer',
            fontSize: 13,
            display: 'inline-flex', alignItems: 'center', gap: 6,
            WebkitTapHighlightColor: 'transparent',
          }}
        >
          {resending
            ? (
              <>
                <motion.div
                  animate={{ rotate: 360 }}
                  transition={{ repeat: Infinity, duration: 0.8, ease: 'linear' }}
                  style={{ display: 'flex' }}
                >
                  <Loader size={14} color={C.mute} />
                </motion.div>
                Sending…
              </>
            )
            : 'Resend code'
          }
        </button>
      </div>
    </motion.div>
  );
}

// ── Root export ───────────────────────────────────────────────────────────────
export default function AuthScreen({ onAuth }) {
  const [view,        setView]        = useState('login'); // 'login' | 'signup' | 'otp'
  const [otpEmail,    setOtpEmail]    = useState('');
  const [otpName,     setOtpName]     = useState('');
  const [otpUsername, setOtpUsername] = useState('');

  const goToOtp = ({ email, name, username }) => {
    setOtpEmail(email);
    setOtpName(name);
    setOtpUsername(username || '');
    setView('otp');
  };

  return (
    <div style={{
      width: '100%', height: '100%', background: C.bg,
      display: 'flex', flexDirection: 'column', justifyContent: 'center',
      padding: '0 28px',
      paddingTop: 'max(env(safe-area-inset-top, 0px) + 20px, 40px)',
      paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 20px, 40px)',
      overflowY: 'auto', WebkitOverflowScrolling: 'touch', boxSizing: 'border-box',
    }}>
      <AnimatePresence mode="wait">
        {view === 'login' && (
          <LoginView key="login" onSwitch={() => setView('signup')} onSuccess={onAuth} />
        )}
        {view === 'signup' && (
          <SignupView key="signup" onSwitch={() => setView('login')} onConfirm={goToOtp} />
        )}
        {view === 'otp' && (
          <OtpView
            key="otp"
            email={otpEmail}
            name={otpName}
            username={otpUsername}
            onSuccess={onAuth}
            onBack={() => setView('signup')}
          />
        )}
      </AnimatePresence>
    </div>
  );
}
