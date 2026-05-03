import { motion } from 'framer-motion';
import { spring } from '../../tokens.js';

const COLORS = ['#B8FF00', '#FFFFFF', '#6BCC00', '#E0FF80', '#FFFFFF'];
const N = 30;

function rand(min, max) { return min + Math.random() * (max - min); }

export default function ConfettiBurst({ active }) {
  if (!active) return null;
  return (
    <div style={{ position: 'fixed', inset: 0, pointerEvents: 'none', zIndex: 9998, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      {Array.from({ length: N }).map((_, i) => {
        const angle = (i / N) * 2 * Math.PI + rand(-0.3, 0.3);
        const dist = rand(120, 260);
        const x = Math.cos(angle) * dist;
        const y = Math.sin(angle) * dist;
        const color = COLORS[i % COLORS.length];
        const size = rand(6, 12);
        return (
          <motion.div
            key={i}
            initial={{ x: 0, y: 0, opacity: 1, scale: 1, rotate: 0 }}
            animate={{ x, y, opacity: 0, scale: 0.3, rotate: rand(-180, 180) }}
            transition={{ ...spring, duration: 0.9, delay: rand(0, 0.15) }}
            style={{
              position: 'absolute',
              width: size,
              height: size,
              borderRadius: i % 3 === 0 ? '50%' : 3,
              background: color,
              willChange: 'transform, opacity',
            }}
          />
        );
      })}
    </div>
  );
}
