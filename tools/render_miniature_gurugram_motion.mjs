import fs from 'node:fs';
import path from 'node:path';

const outputDir = process.argv[2];
if (!outputDir) throw new Error('Pass an output frame directory.');
fs.mkdirSync(outputDir, { recursive: true });

const W = 1280;
const H = 720;
const FRAMES = 210;
const FPS = 15;
const esc = (value) => String(value).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' }[c]));
const clamp = (value, min = 0, max = 1) => Math.max(min, Math.min(max, value));
const ease = (value) => {
  const x = clamp(value);
  return x * x * (3 - 2 * x);
};
const fmt = (value) => Number(value).toFixed(1);

function renderFrame(frame) {
  const t = frame / FPS;
  const ix = 632;
  const iy = 265;
  const iso = (x, y, z = 0) => [ix + (x - y) * 0.78, iy + (x + y) * 0.35 - z];
  const point = (x, y, z = 0) => iso(x, y, z).map(fmt).join(',');
  const points = (items) => items.map(([x, y, z]) => point(x, y, z)).join(' ');
  const camera = 1.25 - 0.07 * ease((t - 1) / 8);
  const camX = -28 + 20 * ease(t / 4);
  const camY = 34 - 18 * ease(t / 5);

  const road = (x, y, width, depth) => `<polygon points="${points([[x, y, 0], [x + width, y, 0], [x + width, y + depth, 0], [x, y + depth, 0]])}" fill="#25343b"/><polyline points="${points([[x + width / 2, y + 3, 1], [x + width / 2, y + depth - 3, 1]])}" fill="none" stroke="#d8d5ae" stroke-width="2" stroke-dasharray="9 9" opacity=".72"/>`;
  const park = (x, y, width, depth) => `<polygon points="${points([[x, y, 0], [x + width, y, 0], [x + width, y + depth, 0], [x, y + depth, 0]])}" fill="#7fac70" stroke="#638d5b" stroke-width="1"/>`;
  const tree = (x, y, size = 7) => {
    const [tx, ty] = iso(x, y, 1);
    return `<ellipse cx="${fmt(tx)}" cy="${fmt(ty)}" rx="${size}" ry="${size * .58}" fill="#3e733f"/><ellipse cx="${fmt(tx - size * .25)}" cy="${fmt(ty - size * .55)}" rx="${size * .72}" ry="${size * .54}" fill="#5f9b57"/>`;
  };
  const car = (x, y, color, flip = false) => {
    const [cx, cy] = iso(x, y, 4);
    return `<g transform="translate(${fmt(cx)} ${fmt(cy)}) rotate(${flip ? -24 : 24})"><rect x="-8" y="-3.5" width="16" height="7" rx="2" fill="${color}"/><rect x="-3.5" y="-5" width="7" height="4" rx="1" fill="#bfe5ef" opacity=".88"/></g>`;
  };
  const building = ({ x, y, w, d, h, name, accent, delay = 0, pulse = 0 }) => {
    const grown = h * ease((t - delay) / 1.15);
    const top = [[x, y, grown], [x + w, y, grown], [x + w, y + d, grown], [x, y + d, grown]];
    const front = [[x, y + d, 0], [x + w, y + d, 0], [x + w, y + d, grown], [x, y + d, grown]];
    const side = [[x + w, y, 0], [x + w, y + d, 0], [x + w, y + d, grown], [x + w, y, grown]];
    const [labelX, labelY] = iso(x + w / 2, y + d * .9, grown + 10);
    const windows = grown > 14 ? Array.from({ length: Math.floor(grown / 15) }, (_, i) => {
      const z = 11 + i * 15;
      const [aX, aY] = iso(x + 5, y + d + .01, z);
      const [bX, bY] = iso(x + w - 5, y + d + .01, z);
      return `<line x1="${fmt(aX)}" y1="${fmt(aY)}" x2="${fmt(bX)}" y2="${fmt(bY)}" stroke="#a9d8e5" stroke-width="2.1" opacity=".76"/>`;
    }).join('') : '';
    const glow = pulse ? `.7 + .3*sin(${fmt(t * 6 + pulse)})` : '.82';
    const badge = name ? `<rect x="${fmt(labelX - Math.max(20, name.length * 4.2))}" y="${fmt(labelY - 11)}" width="${Math.max(40, name.length * 8.4)}" height="18" rx="4" fill="${accent}" opacity="${glow}"/>
      <text x="${fmt(labelX)}" y="${fmt(labelY + 2)}" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-weight="800" font-size="11" fill="#fff">${esc(name)}</text>` : '';
    return `<g>
      <polygon points="${points(front)}" fill="#d7ddd5" stroke="#879ca0" stroke-width="1"/>
      <polygon points="${points(side)}" fill="#aebdc0" stroke="#7e969b" stroke-width="1"/>
      <polygon points="${points(top)}" fill="#eef3e8" stroke="#94a9a4" stroke-width="1"/>
      ${windows}
      ${badge}
    </g>`;
  };
  const crane = (x, y, delay, dir = 1) => {
    const progress = ease((t - delay) / 1.05);
    const height = 14 + 118 * progress;
    const [baseX, baseY] = iso(x, y, 2);
    const [topX, topY] = iso(x, y, height);
    const angle = dir * (10 + 20 * Math.sin(t * 2.1 + x));
    const hook = 30 + 14 * (1 + Math.sin(t * 3.3 + y));
    return `<g>
      <line x1="${fmt(baseX)}" y1="${fmt(baseY)}" x2="${fmt(topX)}" y2="${fmt(topY)}" stroke="#efb522" stroke-width="5"/>
      <line x1="${fmt(baseX - 8)}" y1="${fmt(baseY)}" x2="${fmt(topX)}" y2="${fmt(topY)}" stroke="#c98c17" stroke-width="2"/>
      <g transform="rotate(${fmt(angle)} ${fmt(topX)} ${fmt(topY)})">
        <line x1="${fmt(topX - 90)}" y1="${fmt(topY)}" x2="${fmt(topX + 102)}" y2="${fmt(topY)}" stroke="#f2bd27" stroke-width="5"/>
        <line x1="${fmt(topX - 90)}" y1="${fmt(topY - 4)}" x2="${fmt(topX + 102)}" y2="${fmt(topY - 4)}" stroke="#d59016" stroke-width="2"/>
        <line x1="${fmt(topX + 70)}" y1="${fmt(topY)}" x2="${fmt(topX + 70)}" y2="${fmt(topY + hook)}" stroke="#5a5a48" stroke-width="2"/>
        <path d="M ${fmt(topX + 66)} ${fmt(topY + hook)} q 4 9 9 0" fill="none" stroke="#424238" stroke-width="3"/>
      </g>
    </g>`;
  };

  const roadNetwork = [
    road(-360, -34, 720, 24), road(-30, -300, 28, 600), road(-365, 118, 730, 24), road(164, -292, 28, 590),
  ].join('');
  const greens = [park(-308, -246, 158, 128), park(54, -232, 110, 103), park(-290, 42, 160, 70), park(35, 43, 123, 74), park(205, -38, 103, 111)].join('');
  const trees = [[-282,-215],[-250,-190],[-206,-222],[-167,-177],[82,-200],[119,-169],[-256,67],[-219,90],[-188,61],[59,77],[105,90],[239,3],[268,27],[277,62]].map(([x,y]) => tree(x,y,7)).join('');
  const movingCars = [
    car(-350 + ((t * 72) % 690), -22, '#f6bc35'), car(332 - ((t * 55) % 680), -7, '#e95b4f', true),
    car(-330 + ((t * 63 + 210) % 690), 128, '#48a6cf'), car(334 - ((t * 49 + 165) % 680), 145, '#f7f5de', true),
    car(-18, -285 + ((t * 58) % 565), '#ef7850', true), car(-2, 276 - ((t * 61 + 170) % 565), '#78b851'),
    car(177, -278 + ((t * 65 + 77) % 560), '#4e8bc0'), car(191, 273 - ((t * 50 + 140) % 560), '#f4c43e', true),
  ].join('');
  const backgroundSites = [
    building({ x: -338, y: -245, w: 42, d: 35, h: 44, name: '', accent: '#d8e5e3' }),
    building({ x: -242, y: -282, w: 46, d: 38, h: 52, name: '', accent: '#d8e5e3' }),
    building({ x: -54, y: -258, w: 43, d: 35, h: 47, name: '', accent: '#d8e5e3' }),
    building({ x: 132, y: -264, w: 46, d: 39, h: 52, name: '', accent: '#d8e5e3' }),
    building({ x: 262, y: -236, w: 42, d: 36, h: 45, name: '', accent: '#d8e5e3' }),
    building({ x: 292, y: -112, w: 40, d: 35, h: 42, name: '', accent: '#d8e5e3' }),
    building({ x: -356, y: 57, w: 42, d: 36, h: 48, name: '', accent: '#d8e5e3' }),
    building({ x: -264, y: 151, w: 47, d: 38, h: 53, name: '', accent: '#d8e5e3' }),
    building({ x: -112, y: 151, w: 40, d: 34, h: 44, name: '', accent: '#d8e5e3' }),
    building({ x: 38, y: 151, w: 45, d: 37, h: 51, name: '', accent: '#d8e5e3' }),
    building({ x: 183, y: 151, w: 42, d: 35, h: 46, name: '', accent: '#d8e5e3' }),
  ].join('');
  const sites = [
    building({ x: -132, y: -91, w: 58, d: 46, h: 95, name: 'GOOGLE', accent: '#4285f4', delay: .4, pulse: 1 }),
    building({ x: -202, y: 45, w: 63, d: 50, h: 78, name: 'ZEPTO', accent: '#7c2ea5', delay: .8, pulse: 2 }),
    building({ x: 45, y: -126, w: 60, d: 47, h: 102, name: 'MICROSOFT', accent: '#00a4ef', delay: 1.1, pulse: 3 }),
    building({ x: 112, y: 34, w: 65, d: 52, h: 76, name: 'RAZORPAY', accent: '#3176ed', delay: 1.4, pulse: 4 }),
    building({ x: -58, y: 71, w: 58, d: 47, h: 72, name: 'PAYTM', accent: '#11a9de', delay: 1.7, pulse: 5 }),
    building({ x: 182, y: -145, w: 57, d: 43, h: 86, name: 'AMAZON', accent: '#f59c21', delay: 2.0, pulse: 6 }),
    building({ x: -298, y: -82, w: 55, d: 43, h: 60, name: 'BLINKIT', accent: '#e7db19', delay: 2.3, pulse: 7 }),
    building({ x: 238, y: 75, w: 53, d: 45, h: 66, name: 'THREAD', accent: '#111827', delay: 2.6, pulse: 8 }),
  ].join('');
  const construction = crane(-22, -27, .8, 1) + crane(68, -9, 1.3, -1) + crane(-77, 14, 1.8, 1);
  const giant = ease((t - 6.0) / 1.2);
  const giantY = 368 - 118 * giant;
  const title = `<g transform="translate(0 ${fmt(34 * (1 - giant))})">
      <text x="640" y="${fmt(giantY + 26)}" text-anchor="middle" font-family="Arial Black, Arial, Helvetica, sans-serif" font-size="83" letter-spacing="-5" fill="#6e1d1d" opacity="${fmt(giant)}">GURUGRAM</text>
      <text x="640" y="${fmt(giantY)}" text-anchor="middle" font-family="Arial Black, Arial, Helvetica, sans-serif" font-size="83" letter-spacing="-5" fill="#e5332a" stroke="#9f221d" stroke-width="1.5" opacity="${fmt(giant)}">GURUGRAM</text>
    </g>`;
  const subtitleOpacity = ease((t - 10.1) / .6);
  const subtitle = `<text x="640" y="618" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="16" letter-spacing="5" font-weight="800" fill="#22353a" opacity="${fmt(subtitleOpacity)}">THE CITY THAT KEEPS BUILDING</text>`;

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
    <rect width="1280" height="720" fill="#ece5d8"/>
    <defs><filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="12" stdDeviation="11" flood-color="#273436" flood-opacity=".27"/></filter></defs>
    <g transform="translate(640 360) scale(${fmt(camera)}) translate(-640 -360) translate(${fmt(camX)} ${fmt(camY)})" filter="url(#shadow)">
      <polygon points="${points([[-405,-330,0],[350,-330,0],[350,300,0],[-405,300,0]])}" fill="#d8dfcd"/>
      ${greens}${roadNetwork}${trees}${backgroundSites}${sites}${construction}${movingCars}
    </g>
    ${title}${subtitle}
  </svg>`;
}

for (let frame = 0; frame < FRAMES; frame += 1) {
  const filename = path.join(outputDir, `frame-${String(frame + 1).padStart(4, '0')}.svg`);
  fs.writeFileSync(filename, renderFrame(frame));
}
console.log(`Wrote ${FRAMES} SVG frames to ${outputDir}`);
