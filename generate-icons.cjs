/**
 * generate-icons.cjs
 * Generates PWA icons from public/logo.png using sharp.
 * Run: node generate-icons.cjs
 */
const sharp = require('sharp');
const path  = require('path');

const SRC = path.join(__dirname, 'public', 'logo.png');
const OUT = path.join(__dirname, 'public');

const SIZES = [
  { name: 'apple-touch-icon.png', size: 180 },
  { name: 'icon-192.png',         size: 192 },
  { name: 'icon-512.png',         size: 512 },
];

async function generateIcon(name, size) {
  // Resize logo to exact square, preserving transparency — no background added
  await sharp(SRC)
    .resize(size, size, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toFile(path.join(OUT, name));

  console.log(`✓ ${name} (${size}×${size})`);
}

(async () => {
  for (const { name, size } of SIZES) {
    await generateIcon(name, size);
  }
  console.log('Done.');
})();
