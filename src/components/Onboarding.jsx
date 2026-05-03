import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronLeft } from 'lucide-react';
import Field from './shared/Field.jsx';
import Input from './shared/Input.jsx';
import TextArea from './shared/TextArea.jsx';
import SegmentedPicker from './shared/SegmentedPicker.jsx';
import WeightStepper from './shared/WeightStepper.jsx';
import ChoiceCard from './shared/ChoiceCard.jsx';
import ChoiceCardWide from './shared/ChoiceCardWide.jsx';
import { C, spring, springSoft } from '../tokens.js';

const WEAK_POINTS = ['Chest','Back','Shoulders','Arms','Quads','Glutes-Hams','Core'];

const GOALS = [
  { value: 'muscle', label: 'Build Muscle', icon: '💪' },
  { value: 'stronger', label: 'Get Stronger', icon: '🏋️' },
  { value: 'fat', label: 'Lose Fat', icon: '🔥' },
  { value: 'athletic', label: 'Athletic', icon: '⚡' },
];

const EXPERIENCE = [
  { value: 'beginner', label: 'Beginner', sub: 'Less than 1 year of consistent training' },
  { value: 'intermediate', label: 'Intermediate', sub: '1–3 years, comfortable with all main lifts' },
  { value: 'advanced', label: 'Advanced', sub: '3+ years, strong technique and high tolerance' },
];

const EQUIPMENT = [
  { value: 'full_gym', label: 'Full Gym', sub: 'Barbells, machines, cables, dumbbells' },
  { value: 'home_gym', label: 'Home Gym', sub: 'Barbell, rack, dumbbells (no machines)' },
  { value: 'dumbbells', label: 'Dumbbells', sub: 'A pair of dumbbells + bench' },
  { value: 'bodyweight', label: 'Bodyweight', sub: 'No equipment — just you and a bar maybe' },
];

function ProgressBar({ step, total }) {
  return (
    <div style={{ display: 'flex', gap: 4, marginBottom: 24 }}>
      {Array.from({ length: total }).map((_, i) => (
        <motion.div
          key={i}
          animate={{ background: i < step ? C.accent : C.surface2 }}
          transition={spring}
          style={{ flex: 1, height: 3, borderRadius: 2 }}
        />
      ))}
    </div>
  );
}

export default function Onboarding({ onComplete, onBack }) {
  const [step, setStep] = useState(1);
  const [dir, setDir] = useState(1);

  const [profile, setProfile] = useState({
    name: '', age: '', sex: 'Male',
    experience: '', bodyweight: 70,
    goal: '', days: 4, cardio: 'none',
    equipment: '', sessionLength: 60,
    weakPoints: [],
    injuries: '', avoid: '',
    favourites: [], dislikes: [],
  });
  const [weights, setWeights] = useState({
    bench: 60, squat: 80, deadlift: 100, ohp: 40, row: 60,
  });

  const set = (key, val) => setProfile(p => ({ ...p, [key]: val }));
  const toggleWeak = (wp) => set('weakPoints',
    profile.weakPoints.includes(wp)
      ? profile.weakPoints.filter(w => w !== wp)
      : [...profile.weakPoints, wp]
  );

  const canContinue = () => {
    if (step === 1) return profile.name.trim() && profile.age;
    if (step === 2) return profile.experience;
    if (step === 3) return profile.goal;
    if (step === 4) return profile.equipment;
    return true;
  };

  const goNext = () => {
    if (!canContinue()) return;
    if (step === 7) {
      onComplete(profile, weights);
      return;
    }
    setDir(1);
    setStep(s => s + 1);
  };

  const goBack = () => {
    if (step === 1) { onBack(); return; }
    setDir(-1);
    setStep(s => s - 1);
  };

  const variants = {
    enter: (d) => ({ x: d > 0 ? 24 : -24, opacity: 0 }),
    center: { x: 0, opacity: 1 },
    exit: (d) => ({ x: d > 0 ? -24 : 24, opacity: 0 }),
  };

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      height: '100%',
      width: '100%',
      maxWidth: 390,
      padding: '0 20px',
      paddingTop: 'max(env(safe-area-inset-top, 0px) + 16px, 24px)',
      paddingBottom: 'max(env(safe-area-inset-bottom, 0px) + 16px, 24px)',
      overflow: 'hidden',
    }}>
      {/* Top bar */}
      <div style={{ flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 16, gap: 12 }}>
          <button
            onClick={goBack}
            style={{
              background: C.surface2,
              border: `1.5px solid ${C.border}`,
              borderRadius: 8,
              width: 36, height: 36,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: C.text, cursor: 'pointer',
              touchAction: 'manipulation', WebkitTapHighlightColor: 'transparent',
              flexShrink: 0,
            }}
          >
            <ChevronLeft size={18} />
          </button>
          <span style={{ fontSize: 11, fontWeight: 600, letterSpacing: '0.08em', color: C.dim }}>
            STEP {step} / 7
          </span>
        </div>
        <ProgressBar step={step} total={7} />
      </div>

      {/* Step content */}
      <div style={{ flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch', position: 'relative' }}>
        <AnimatePresence mode="wait" custom={dir}>
          <motion.div
            key={step}
            custom={dir}
            variants={variants}
            initial="enter"
            animate="center"
            exit="exit"
            transition={springSoft}
            style={{ display: 'flex', flexDirection: 'column', gap: 20, paddingBottom: 100 }}
          >
            {step === 1 && <Step1 profile={profile} set={set} />}
            {step === 2 && <Step2 profile={profile} set={set} weights={weights} setWeights={setWeights} />}
            {step === 3 && <Step3 profile={profile} set={set} />}
            {step === 4 && <Step4 profile={profile} set={set} />}
            {step === 5 && <Step5 profile={profile} toggleWeak={toggleWeak} />}
            {step === 6 && <Step6 profile={profile} set={set} />}
            {step === 7 && <Step7 weights={weights} setWeights={setWeights} />}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Continue button */}
      <div style={{ flexShrink: 0, paddingTop: 12 }}>
        <motion.button
          whileTap={{ scale: 0.97 }}
          transition={spring}
          onClick={goNext}
          disabled={!canContinue()}
          style={{
            width: '100%',
            background: canContinue() ? C.accent : C.surface2,
            color: canContinue() ? '#000' : C.mute,
            border: 'none',
            borderRadius: 14,
            padding: '16px 24px',
            fontSize: 15,
            fontWeight: 700,
            cursor: canContinue() ? 'pointer' : 'default',
            touchAction: 'manipulation',
            WebkitTapHighlightColor: 'transparent',
            transition: 'background 0.2s, color 0.2s',
          }}
        >
          {step === 7 ? 'Build my programme →' : 'Continue'}
        </motion.button>
      </div>
    </div>
  );
}

function Step1({ profile, set }) {
  return (
    <>
      <h2 style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.02em', color: C.text }}>Tell us about you</h2>
      <Field label="First Name">
        <Input value={profile.name} onChange={e => set('name', e.target.value)} placeholder="e.g. Alex" />
      </Field>
      <Field label="Age">
        <Input type="number" inputMode="numeric" value={profile.age} onChange={e => set('age', e.target.value)} placeholder="e.g. 28" />
      </Field>
      <Field label="Sex">
        <SegmentedPicker
          options={[{value:'Male'},{value:'Female'},{value:'Other'}]}
          value={profile.sex}
          onChange={v => set('sex', v)}
        />
      </Field>
    </>
  );
}

function Step2({ profile, set, weights, setWeights }) {
  return (
    <>
      <h2 style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.02em', color: C.text }}>Experience level</h2>
      {EXPERIENCE.map(e => (
        <ChoiceCardWide key={e.value} label={e.label} sub={e.sub} value={e.value} selected={profile.experience === e.value} onSelect={v => set('experience', v)} />
      ))}
      <Field label="Bodyweight (kg)">
        <WeightStepper value={profile.bodyweight} onChange={v => set('bodyweight', v)} step={0.5} min={30} />
      </Field>
    </>
  );
}

function Step3({ profile, set }) {
  return (
    <>
      <h2 style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.02em', color: C.text }}>Your goal</h2>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        {GOALS.map(g => (
          <ChoiceCard key={g.value} label={g.label} icon={g.icon} value={g.value} selected={profile.goal === g.value} onSelect={v => set('goal', v)} />
        ))}
      </div>
      <Field label="Days per week">
        <SegmentedPicker
          options={[{value:3,label:'3'},{value:4,label:'4'},{value:5,label:'5'}]}
          value={profile.days}
          onChange={v => set('days', v)}
        />
      </Field>
      <Field label="Cardio">
        <SegmentedPicker
          options={[{value:'none',label:'None'},{value:'light',label:'Light'},{value:'moderate',label:'Moderate'},{value:'heavy',label:'Heavy'}]}
          value={profile.cardio}
          onChange={v => set('cardio', v)}
        />
      </Field>
    </>
  );
}

function Step4({ profile, set }) {
  return (
    <>
      <h2 style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.02em', color: C.text }}>Your setup</h2>
      {EQUIPMENT.map(e => (
        <ChoiceCardWide key={e.value} label={e.label} sub={e.sub} value={e.value} selected={profile.equipment === e.value} onSelect={v => set('equipment', v)} />
      ))}
      <Field label="Session length">
        <SegmentedPicker
          options={[{value:45,label:'45 min'},{value:60,label:'60 min'},{value:90,label:'90 min'}]}
          value={profile.sessionLength}
          onChange={v => set('sessionLength', v)}
        />
      </Field>
    </>
  );
}

function Step5({ profile, toggleWeak }) {
  return (
    <>
      <h2 style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.02em', color: C.text }}>Anything lagging?</h2>
      <p style={{ fontSize: 14, color: C.dim }}>Optional. We'll bias accessory work toward these areas.</p>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {WEAK_POINTS.map(wp => {
          const active = profile.weakPoints.includes(wp);
          return (
            <motion.button
              key={wp}
              whileTap={{ scale: 0.95 }}
              transition={spring}
              onClick={() => toggleWeak(wp)}
              style={{
                padding: '8px 16px',
                borderRadius: 100,
                background: active ? 'rgba(184,255,0,0.12)' : C.surface2,
                border: `1.5px solid ${active ? C.accent : C.border}`,
                color: active ? C.accent : C.dim,
                fontSize: 13,
                fontWeight: 600,
                cursor: 'pointer',
                touchAction: 'manipulation',
                WebkitTapHighlightColor: 'transparent',
              }}
            >{wp}</motion.button>
          );
        })}
      </div>
    </>
  );
}

function Step6({ profile, set }) {
  return (
    <>
      <h2 style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.02em', color: C.text }}>Any injuries?</h2>
      <Field label="Current injuries (or 'none')">
        <TextArea value={profile.injuries} onChange={e => set('injuries', e.target.value)} placeholder="e.g. left knee pain, lower back tightness" rows={3} />
      </Field>
      <Field label="Exercises to avoid">
        <TextArea value={profile.avoid} onChange={e => set('avoid', e.target.value)} placeholder="e.g. heavy squats, behind-neck press" rows={3} />
      </Field>
    </>
  );
}

function Step7({ weights, setWeights }) {
  const setW = (key, val) => setWeights(w => ({ ...w, [key]: val }));
  const rows = [
    { key: 'bench', label: 'Bench Press' },
    { key: 'squat', label: 'Back Squat' },
    { key: 'deadlift', label: 'Deadlift' },
    { key: 'ohp', label: 'Overhead Press' },
    { key: 'row', label: 'Barbell Row' },
  ];
  return (
    <>
      <h2 style={{ fontSize: 24, fontWeight: 800, letterSpacing: '-0.02em', color: C.text }}>Starting weights</h2>
      <p style={{ fontSize: 13, color: C.dim, lineHeight: 1.5 }}>Your current working weight — the weight you actually lift for sets, not your max.</p>
      {rows.map(r => (
        <div key={r.key} style={{ padding: '12px 0', borderBottom: `1px solid ${C.border}` }}>
          <WeightStepper label={r.label} value={weights[r.key]} onChange={v => setW(r.key, v)} />
        </div>
      ))}
    </>
  );
}
