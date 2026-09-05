import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const outputDir = resolve(process.argv[2] ?? '/private/tmp/gurugram-construction-frames');
const frames = 240;
const duration = 10;

mkdirSync(outputDir, { recursive: true });

const clamp = (value, min = 0, max = 1) => Math.max(min, Math.min(max, value));
const ease = (value) => {
  const t = clamp(value);
  return t * t * (3 - 2 * t);
};

function point(x, y, z = 0) {
  return [960 + (x - y) * 9.4, 170 + (x + y) * 4.65 - z];
}

function polygon(points, fill, extra = '') {
  return `<polygon points="${points.map((p) => p.join(',')).join(' ')}" fill="${fill}" ${extra}/>`;
}

function line(a, b, stroke, width = 2, extra = '') {
  return `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${stroke}" stroke-width="${width}" ${extra}/>`;
}

function worldRect(x, y, width, depth, fill, extra = '') {
  return polygon([point(x, y), point(x + width, y), point(x + width, y + depth), point(x, y + depth)], fill, extra);
}

function road(x, y, width, depth) {
  const svg = [worldRect(x, y, width, depth, '#27333a')];
  svg.push(polygon([point(x + 1, y + 1), point(x + width - 1, y + 1), point(x + width - 1, y + depth - 1), point(x + 1, y + depth - 1)], '#34434a'));
  const longX = width > depth;
  const segments = Math.floor((longX ? width : depth) / 8);
  for (let i = 0; i < segments; i += 1) {
    const offset = i * 8 + 2;
    const dash = longX
      ? [point(x + offset, y + depth / 2 - .25), point(x + offset + 4, y + depth / 2 - .25), point(x + offset + 4, y + depth / 2 + .25), point(x + offset, y + depth / 2 + .25)]
      : [point(x + width / 2 - .25, y + offset), point(x + width / 2 + .25, y + offset), point(x + width / 2 + .25, y + offset + 4), point(x + width / 2 - .25, y + offset + 4)];
    svg.push(polygon(dash, '#F7E2A6'));
  }
  return svg.join('');
}

function renderBuilding(spec, t) {
  const construction = ease((t - spec.start) / spec.duration);
  const demolition = spec.demolish ? ease((t - spec.demolish) / .9) : 0;
  const progress = clamp(construction * (1 - demolition));
  const height = spec.height * progress;
  const floorHeight = 13;
  const floors = Math.max(0, Math.floor(height / floorHeight));
  const x = spec.x;
  const y = spec.y;
  const w = spec.w;
  const d = spec.d;
  const base = [point(x, y), point(x + w, y), point(x + w, y + d), point(x, y + d)];
  const top = [point(x, y, height), point(x + w, y, height), point(x + w, y + d, height), point(x, y + d, height)];
  const left = [base[3], base[2], top[2], top[3]];
  const right = [base[1], base[2], top[2], top[1]];
  const pieces = [polygon(base, '#B8AA91')];
  if (height > 2) {
    pieces.push(polygon(left, spec.left), polygon(right, spec.right), polygon(top, spec.roof));
    for (let floor = 1; floor <= floors; floor += 1) {
      const z = floor * floorHeight;
      pieces.push(line(point(x, y + d, z), point(x + w, y + d, z), '#D8E6E5', 1, 'opacity="0.7"'));
      pieces.push(line(point(x + w, y, z), point(x + w, y + d, z), '#D8E6E5', 1, 'opacity="0.45"'));
    }
    const signProgress = clamp((progress - .78) / .22);
    if (spec.name && signProgress > 0) {
      const [sx, sy] = point(x + w * .56, y + d, height * .54);
      pieces.push(`<text x="${sx}" y="${sy}" text-anchor="middle" font-family="Verdana, sans-serif" font-size="${12 + spec.name.length / 4}" font-weight="700" letter-spacing="1.2" fill="${spec.sign}" opacity="${signProgress}">${spec.name}</text>`);
    }
  }
  return pieces.join('');
}

function crane(spec, t) {
  const active = clamp((t - spec.start) / .35) * (1 - clamp((t - spec.end) / .35));
  if (active <= 0) return '';
  const towerTop = point(spec.x, spec.y, spec.height);
  const towerBase = point(spec.x, spec.y, 0);
  const angle = t * 1.8 + spec.phase;
  const boomLength = spec.length;
  const boomX = spec.x + Math.cos(angle) * boomLength;
  const boomY = spec.y + Math.sin(angle) * boomLength;
  const tailX = spec.x - Math.cos(angle) * boomLength * .32;
  const tailY = spec.y - Math.sin(angle) * boomLength * .32;
  const boomEnd = point(boomX, boomY, spec.height);
  const tailEnd = point(tailX, tailY, spec.height);
  const hookWorldX = spec.x + Math.cos(angle) * boomLength * .58;
  const hookWorldY = spec.y + Math.sin(angle) * boomLength * .58;
  const hookZ = 34 + 34 * (1 + Math.sin(t * 4 + spec.phase)) / 2;
  const hook = point(hookWorldX, hookWorldY, hookZ);
  return [
    line(towerBase, towerTop, '#D99D20', 5, `opacity="${active}"`),
    line(point(spec.x - 1.2, spec.y, 0), towerTop, '#F3C84C', 2, `opacity="${active}"`),
    line(point(spec.x + 1.2, spec.y, 0), towerTop, '#F3C84C', 2, `opacity="${active}"`),
    line(tailEnd, boomEnd, '#E4A82A', 5, `opacity="${active}"`),
    line(towerTop, hook, '#314139', 2, `opacity="${active}"`),
    `<circle cx="${hook[0]}" cy="${hook[1]}" r="4" fill="#F3C84C" opacity="${active}"/>`,
  ].join('');
}

function car(x, y, color) {
  const body = [point(x - 1.4, y - .8, 3), point(x + 1.4, y - .8, 3), point(x + 1.4, y + .8, 3), point(x - 1.4, y + .8, 3)];
  return polygon(body, color, 'stroke="#19211E" stroke-width="1"');
}

const buildings = [
  { name: 'GOOGLE', x: 19, y: 18, w: 15, d: 13, height: 112, start: .7, duration: 2.4, left: '#8EAFB2', right: '#638E98', roof: '#D7E1DE', sign: '#2765A8' },
  { name: 'AMAZON', x: 58, y: 18, w: 17, d: 14, height: 138, start: 1.15, duration: 2.35, left: '#A0B4B0', right: '#5E858B', roof: '#E7E1D4', sign: '#D57616' },
  { name: 'PAYTM', x: 15, y: 53, w: 15, d: 14, height: 86, start: 1.7, duration: 2.0, left: '#9ABCC1', right: '#4F8C9D', roof: '#D5E4DF', sign: '#1384B4' },
  { name: 'MICROSOFT', x: 40, y: 39, w: 15, d: 15, height: 96, start: 2.0, duration: 2.1, left: '#A6B6AD', right: '#6D8D80', roof: '#E8E6D8', sign: '#417D44' },
  { name: '', x: 70, y: 50, w: 14, d: 14, height: 102, start: 0, duration: .1, demolish: 2.4, left: '#9B958B', right: '#706E67', roof: '#C7C0B0', sign: '#4A4740' },
  { name: 'ZEPTO', x: 70, y: 50, w: 14, d: 14, height: 118, start: 3.25, duration: 2.15, left: '#B69AC4', right: '#80619A', roof: '#E3D1E7', sign: '#622A88' },
  { name: 'BLINKIT', x: 72, y: 28, w: 13, d: 12, height: 78, start: 3.55, duration: 1.75, left: '#BEC48D', right: '#8D9A4F', roof: '#E6E7C4', sign: '#6C7500' },
  { name: 'THREADS', x: 28, y: 67, w: 14, d: 13, height: 82, start: 4.05, duration: 1.75, left: '#AE9CC4', right: '#7E67A0', roof: '#E4DBEE', sign: '#5E327E' },
  { name: 'RAZORPAY', x: 56, y: 65, w: 14, d: 13, height: 90, start: 4.45, duration: 1.7, left: '#8DA7C2', right: '#4F6F9B', roof: '#D8E2EE', sign: '#264F9C' },
  { name: 'BUDGET GURUGRAM', x: 43, y: 54, w: 20, d: 16, height: 150, start: 5.05, duration: 1.65, left: '#426C64', right: '#23483F', roof: '#D9C278', sign: '#FFF4D8' },
];

function centralRoofMark(t) {
  const progress = ease((t - 5.05) / 1.65);
  if (progress < .82) return '';
  const opacity = clamp((progress - .82) / .18);
  const [cx, cy] = point(53, 62, 150 * progress + 5);
  return `<g opacity="${opacity}"><text x="${cx}" y="${cy - 4}" text-anchor="middle" font-family="Verdana, sans-serif" font-size="15" font-weight="700" letter-spacing="2" fill="#FFF4D8">BUDGET</text><text x="${cx}" y="${cy + 17}" text-anchor="middle" font-family="Verdana, sans-serif" font-size="23" font-weight="700" letter-spacing="1" fill="#FFF4D8">GURUGRAM</text></g>`;
}

function frameSvg(t) {
  const sky = `<rect width="1920" height="1080" fill="#F3E6CA"/><rect width="1920" height="430" fill="#DDE8E6"/>`;
  const ground = polygon([point(0, 0), point(100, 0), point(100, 100), point(0, 100)], '#C9D7C4', 'stroke="#A7B9A6" stroke-width="3"');
  const parks = [worldRect(5, 7, 20, 9, '#75A663'), worldRect(77, 6, 17, 13, '#75A663'), worldRect(7, 74, 24, 16, '#7EAD68'), worldRect(72, 73, 19, 17, '#7EAD68')].join('');
  const roads = [road(0, 44, 100, 12), road(45, 0, 12, 100), road(0, 78, 100, 10)].join('');
  const trees = Array.from({ length: 44 }, (_, index) => {
    const x = (index * 37) % 94 + 3;
    const y = (index * 53) % 92 + 3;
    if ((x > 43 && x < 59) || (y > 42 && y < 57)) return '';
    const [cx, cy] = point(x, y, 10 + (index % 3) * 2);
    return `<circle cx="${cx}" cy="${cy}" r="${5 + (index % 3)}" fill="#4F874D"/><circle cx="${cx - 3}" cy="${cy + 2}" r="3" fill="#6FA65D"/>`;
  }).join('');
  const orderedBuildings = [...buildings].sort((a, b) => (a.x + a.y) - (b.x + b.y));
  const city = orderedBuildings.map((spec) => renderBuilding(spec, t)).join('');
  const cranes = [
    crane({ x: 27, y: 16, height: 162, length: 20, phase: 0, start: .4, end: 3.3 }, t),
    crane({ x: 67, y: 17, height: 185, length: 22, phase: 2.2, start: .8, end: 3.7 }, t),
    crane({ x: 77, y: 51, height: 164, length: 18, phase: .9, start: 2.7, end: 5.8 }, t),
    crane({ x: 47, y: 55, height: 194, length: 21, phase: 3.4, start: 4.5, end: 7.3 }, t),
    crane({ x: 33, y: 69, height: 130, length: 16, phase: 4.3, start: 3.7, end: 6.2 }, t),
  ].join('');
  const cars = [
    car((t * 12 + 5) % 98, 49, '#E85D4A'), car((t * 10 + 43) % 98, 51.5, '#FFFFFF'), car((t * 14 + 78) % 98, 82, '#4A98C6'),
    car(50, (t * 11 + 10) % 98, '#F1BE3A'), car(53.5, (t * 9 + 48) % 98, '#7F5EB5'), car(47.5, (t * 13 + 82) % 98, '#68AA77'),
  ].join('');
  const title = t > 7.4 ? `<text x="960" y="930" text-anchor="middle" font-family="Verdana, sans-serif" font-size="26" letter-spacing="4" fill="#173C34">A CITY UNDER CONSTRUCTION</text>` : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">${sky}${ground}${parks}${roads}${trees}${city}${cranes}${centralRoofMark(t)}${cars}${title}</svg>`;
}

for (let index = 0; index < frames; index += 1) {
  const time = (index / (frames - 1)) * duration;
  writeFileSync(resolve(outputDir, `frame-${String(index).padStart(3, '0')}.svg`), frameSvg(time));
}
