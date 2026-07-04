// build.mjs — Build-Orchestrator des Mockup-Exports (PROJ-7).
//
// Läuft mit cwd = Build-Workspace (<run-dir>/mockup/.build/), den
// mockup-export.sh zusammengestellt hat:
//
//   workspace/
//   ├── package.json + node_modules   (Shell-Pins ∪ Varianten-Dependencies)
//   ├── shell/                        Kopie von scripts/lib/mockup-shell/
//   ├── redesign/                     Kopie von <run-dir>/redesign/ (shared, safe, bold)
//   ├── meta/build-meta.json          Titel, Description, Domain, Run-ID, Favicon, Fonts
//   └── out/                          ← Ergebnis: mockup.html, prerendered.json, build-report.json
//
// Schritte: Entries generieren → Pre-Render (react-dom/server, No-JS-Baseline)
// → Client-Bundle (esbuild, iife) → Tailwind-CSS (@tailwindcss/cli) →
// Assemble (eine selbsttragende HTML-Datei, Assets base64-inline).
//
// Deterministisch bis auf Dependency-Versionen; alle Meldungen auf Deutsch.

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const WS = process.cwd();
const SHELL = path.join(WS, 'shell');
const RD = path.join(WS, 'redesign');
const OUT = path.join(WS, 'out');
const die = (msg) => { console.error(`✗ build.mjs: ${msg}`); process.exit(1); };

for (const p of [SHELL, RD, path.join(WS, 'meta', 'build-meta.json')]) {
  if (!fs.existsSync(p)) die(`Workspace unvollständig: ${p} fehlt.`);
}
fs.mkdirSync(OUT, { recursive: true });

const meta = JSON.parse(fs.readFileSync(path.join(WS, 'meta', 'build-meta.json'), 'utf8'));
const esbuild = await import('esbuild').catch(() => die('esbuild nicht installiert (node_modules fehlt?)'));
const readJson = (file, fallback) => {
  try { return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : fallback; }
  catch { return fallback; }
};
const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');

// ── Varianten-Entries aus den Manifesten ────────────────────────────────────
const variants = {};
for (const v of ['safe', 'bold']) {
  const manifest = JSON.parse(fs.readFileSync(path.join(RD, v, 'manifest.json'), 'utf8'));
  const entry = path.join(RD, v, manifest.entry || 'App.jsx');
  if (!fs.existsSync(entry)) die(`Entry der Variante '${v}' fehlt: ${entry}`);
  variants[v] = entry;
}

const LOADERS = {
  '.png': 'dataurl', '.jpg': 'dataurl', '.jpeg': 'dataurl', '.gif': 'dataurl',
  '.svg': 'dataurl', '.webp': 'dataurl', '.woff': 'dataurl', '.woff2': 'dataurl',
  '.css': 'empty', // Styling kommt ausschließlich aus Tailwind + Tokens
};

// ── 1) Pre-Render (No-JS-Baseline) ──────────────────────────────────────────
// Fehler einer Variante brechen den Build nicht ab — sie landen in
// prerendered.json und lassen das No-JS-Gate im Treiber rot werden.
const prerenderEntry = path.join(OUT, 'entry-prerender.jsx');
fs.writeFileSync(prerenderEntry, `
import { renderToString } from 'react-dom/server';
import React from 'react';
import fs from 'node:fs';
import Safe from ${JSON.stringify(variants.safe)};
import Bold from ${JSON.stringify(variants.bold)};
const out = {};
for (const [name, App] of [['safe', Safe], ['bold', Bold]]) {
  try { out[name] = renderToString(React.createElement(App)); }
  catch (e) { out[name] = ''; out[name + '_error'] = String((e && e.stack) || e).slice(0, 2000); }
}
fs.writeFileSync(process.env.PRERENDER_OUT, JSON.stringify(out));
`);

await esbuild.build({
  entryPoints: [prerenderEntry], outfile: path.join(OUT, 'prerender.cjs'),
  bundle: true, platform: 'node', format: 'cjs', target: 'node20',
  jsx: 'automatic', loader: LOADERS, legalComments: 'none', logLevel: 'warning',
  define: { 'process.env.NODE_ENV': '"production"' },
}).catch(() => die('Pre-Render-Bundle fehlgeschlagen (Syntaxfehler in einer Variante?).'));

const prerenderedFile = path.join(OUT, 'prerendered.json');
const pr = spawnSync(process.execPath, [path.join(OUT, 'prerender.cjs')], {
  env: { ...process.env, PRERENDER_OUT: prerenderedFile }, stdio: ['ignore', 'inherit', 'inherit'],
});
if (pr.status !== 0 || !fs.existsSync(prerenderedFile)) die('Pre-Render-Lauf fehlgeschlagen.');
const prerendered = JSON.parse(fs.readFileSync(prerenderedFile, 'utf8'));

// ── 2) Client-Bundle (Hydration light: Client-Render ERSETZT die Baseline) ──
// Bewusst createRoot statt hydrateRoot: kein Mismatch-Risiko durch
// Animations-Initialzustände; ohne JS bleibt die vorgerenderte Baseline stehen.
const clientEntry = path.join(OUT, 'entry-client.jsx');
fs.writeFileSync(clientEntry, `
import ${JSON.stringify(path.join(SHELL, 'chrome.js'))};
import React from 'react';
import { createRoot } from 'react-dom/client';
import Safe from ${JSON.stringify(variants.safe)};
import Bold from ${JSON.stringify(variants.bold)};
const mounted = {};
for (const [name, App] of [['safe', Safe], ['bold', Bold]]) {
  try {
    createRoot(document.getElementById('mount-' + name)).render(React.createElement(App));
    mounted[name] = true;
  } catch (e) { mounted[name] = false; console.error('Mount ' + name + ' fehlgeschlagen:', e); }
}
window.__MOCKUP_MOUNTED = mounted;
`);

const clientResult = await esbuild.build({
  entryPoints: [clientEntry], write: false,
  bundle: true, platform: 'browser', format: 'iife', target: 'es2020',
  minify: true, charset: 'utf8', jsx: 'automatic', loader: LOADERS, legalComments: 'none', logLevel: 'warning',
  define: { 'process.env.NODE_ENV': '"production"' },
}).catch(() => die('Client-Bundle fehlgeschlagen.'));
const clientJs = clientResult.outputFiles[0].text;

// ── 2b) PROJ-8-Daten: Original-Screenshots + Sektionsplan + Begründungen ────
const CAPTURE = path.join(WS, 'capture');
let sharp = null;
try { sharp = (await import('sharp')).default; }
catch { sharp = null; }

async function imageDataUri(file, viewport) {
  if (!fs.existsSync(file)) return null;
  const ext = path.extname(file).toLowerCase();
  const fallbackMime = ext === '.jpg' || ext === '.jpeg' ? 'image/jpeg' : ext === '.webp' ? 'image/webp' : 'image/png';
  if (sharp) {
    try {
      const buf = await sharp(file)
        .resize({ width: viewport, withoutEnlargement: true })
        .webp({ quality: 76, effort: 4 })
        .toBuffer();
      return `data:image/webp;base64,${buf.toString('base64')}`;
    } catch (e) {
      console.warn(`⚠ Screenshot-Kompression fehlgeschlagen (${path.basename(file)}): ${String(e).slice(0, 160)} — Original wird eingebettet.`);
    }
  }
  return `data:${fallbackMime};base64,${fs.readFileSync(file).toString('base64')}`;
}

const sectionsRaw = readJson(path.join(CAPTURE, 'sections.json'), {});
const sectionsFor = (viewport) => {
  if (Array.isArray(sectionsRaw)) return sectionsRaw;
  return sectionsRaw[String(viewport)] || sectionsRaw[viewport] || sectionsRaw.viewports?.[String(viewport)] || sectionsRaw.viewports?.[viewport] || [];
};
const normalizeSection = (s, i) => ({
  id: String(s.id || s.section_id || `section-${i + 1}`),
  label: String(s.label || s.title || s.name || s.id || `Abschnitt ${i + 1}`),
  y: Math.max(0, Number(s.y ?? s.top ?? s.start ?? s.start_y ?? 0) || 0),
  height: Math.max(1, Number(s.height ?? ((s.bottom ?? s.end ?? s.end_y ?? 0) - (s.y ?? s.top ?? s.start ?? s.start_y ?? 0))) || 1),
});
const compareRaw = readJson(path.join(RD, 'compare.json'), { sections: [] });
const compareSections = (compareRaw.sections || []).map((s, i) => ({
  id: String(s.id || s.section_id || `section-${i + 1}`),
  original: s.original == null ? null : String(s.original),
  change: String(s.change || s.reason || s.begruendung || ''),
}));
const originalShots = [];
for (const viewport of [375, 768, 1440]) {
  const image = await imageDataUri(path.join(CAPTURE, `shot-${viewport}.png`), viewport);
  if (!image) continue;
  originalShots.push({
    viewport,
    image,
    sections: sectionsFor(viewport).map(normalizeSection),
  });
}
const proj8Data = {
  run_id: meta.run_id,
  domain: meta.domain,
  variants: { safe: Boolean(prerendered.safe), bold: Boolean(prerendered.bold) },
  original: originalShots,
  compare: compareSections,
};
const fallbackShot = originalShots.find((s) => s.viewport === 1440) || originalShots[0];
const proj8Fallback = fallbackShot ? `
<section class="shell-proj8-fallback" aria-label="Statischer Vorher-Nachher-Vergleich">
  <h2>Vorher / Nachher</h2>
  <figure>
    <figcaption>Vorher: Original-Screenshot (${fallbackShot.viewport}px)</figcaption>
    <img src="${fallbackShot.image}" alt="Original-Screenshot von ${esc(meta.domain)}" loading="lazy">
  </figure>
  <figure>
    <figcaption>Nachher: Redesign-Vorschlag Safe</figcaption>
    <div class="shell-proj8-fallback-after">${prerendered.safe || ''}</div>
  </figure>
</section>` : '';

// ── 3) Tailwind-CSS (Theme-Tokens + Varianten-Klassen) ──────────────────────
// Quellen explizit (source(none) + @source): nur redesign/ + Shell-Template,
// nicht die Build-Artefakte in out/.
const twInput = path.join(OUT, 'tw-input.css');
fs.writeFileSync(twInput, [
  '@import "tailwindcss" source(none);',
  '@import "../redesign/shared/tailwind-theme.css";',
  '@source "../redesign";',
  '@source "../shell/template.html";',
  '',
].join('\n'));
const twBin = path.join(WS, 'node_modules', '@tailwindcss', 'cli', 'dist', 'index.mjs');
const tw = spawnSync(process.execPath, [twBin, '-i', twInput, '-o', path.join(OUT, 'tw.css'), '--minify'],
  { cwd: WS, stdio: ['ignore', 'inherit', 'inherit'] });
if (tw.status !== 0) die('Tailwind-Build fehlgeschlagen.');
const css = fs.readFileSync(path.join(OUT, 'tw.css'), 'utf8')
  + '\n' + fs.readFileSync(path.join(SHELL, 'shell.css'), 'utf8');

// ── 4) Favicon + Fonts ──────────────────────────────────────────────────────
let favicon = '';
if (meta.favicon_file && fs.existsSync(meta.favicon_file)) {
  const ext = path.extname(meta.favicon_file).toLowerCase();
  const mime = { '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.ico': 'image/x-icon' }[ext];
  if (mime) favicon = `data:${mime};base64,${fs.readFileSync(meta.favicon_file).toString('base64')}`;
}
if (!favicon) {
  // Fallback: neutrales Marken-Monogramm aus der Primärfarbe — deterministisch, kein erfundenes Logo.
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><rect width="16" height="16" rx="3" fill="${meta.primary_color || '#16181d'}"/></svg>`;
  favicon = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
}

// DSGVO: Fonts ausschließlich über Bunny (fonts.bunny.net), nie Google-CDN.
// Web-safe-/System-Fonts brauchen keinen Webfont-Link.
const WEBSAFE = new Set(['arial', 'helvetica', 'helvetica neue', 'georgia', 'times', 'times new roman',
  'courier', 'courier new', 'verdana', 'tahoma', 'trebuchet ms', 'garamond', 'palatino',
  'system-ui', 'ui-sans-serif', 'ui-serif', 'ui-monospace', '-apple-system', 'sans-serif', 'serif', 'monospace']);
const families = [...new Set((meta.font_families || []).filter((f) => f && !WEBSAFE.has(f.toLowerCase())))];
const fontsTag = families.length
  ? `<link rel="stylesheet" href="https://fonts.bunny.net/css2?${families.map((f) => `family=${encodeURIComponent(f).replace(/%20/g, '+')}:wght@400;500;600;700`).join('&')}&display=swap">`
  : '';

// ── 4b) PROJ-20: gefüllte Bild-Slots (background-image + a11y) ──────────────
// Guard: greift NUR, wenn images-fill.json (PROJ-20) existiert. Ohne Füllung
// bleibt der Build byte-identisch zu vorher.
let slotCss = '';
let slotAriaJs = '';
const imagesFill = readJson(path.join(RD, 'images-fill.json'), null);
if (imagesFill && Array.isArray(imagesFill.slots)) {
  const filled = imagesFill.slots.filter((s) => s && s.source && s.source !== 'placeholder' && s.file);
  const ariaMap = {};
  const rules = [];
  for (const s of filled) {
    const uri = await imageDataUri(path.join(RD, s.file), 1600);
    if (!uri) continue;
    const id = String(s.slot_id).replace(/["\\]/g, '');
    rules.push(`[data-image-slot="${id}"]{background-image:url("${uri}");background-size:cover;background-position:center;background-repeat:no-repeat}`);
    const label = (s.attribution && s.attribution.alt) || s.prompt || '';
    if (label) ariaMap[id] = String(label).slice(0, 200);
  }
  slotCss = rules.join('\n');
  if (Object.keys(ariaMap).length) {
    slotAriaJs = `\n;(function(){try{var M=${JSON.stringify(ariaMap)};function ap(){document.querySelectorAll('[data-image-slot]').forEach(function(el){var id=el.getAttribute('data-image-slot');if(M[id]&&!el.getAttribute('aria-label')){el.setAttribute('role','img');el.setAttribute('aria-label',M[id]);}});}if(document.body){new MutationObserver(ap).observe(document.body,{childList:true,subtree:true});}ap();}catch(e){}})();`;
  }
  if (filled.length) console.log(`  · PROJ-20: ${rules.length}/${filled.length} Bild-Slot(s) eingebettet.`);
}
const cssAll = slotCss ? `${css}\n${slotCss}` : css;
const jsAll = slotAriaJs ? clientJs + slotAriaJs : clientJs;

// ── 5) Assemble ─────────────────────────────────────────────────────────────
const fill = (tpl, marker, value) => tpl.split(`<!--UICHECK:${marker}-->`).join(value);

let html = fs.readFileSync(path.join(SHELL, 'template.html'), 'utf8');
html = fill(html, 'TITLE', esc(meta.title));
html = fill(html, 'DESCRIPTION', esc(meta.description));
html = fill(html, 'DOMAIN', esc(meta.domain));
html = fill(html, 'RUN_ID', esc(meta.run_id));
html = fill(html, 'FAVICON', favicon);
html = fill(html, 'FONTS', fontsTag);
html = fill(html, 'CSS', cssAll.split('</style').join('<\\2f style'));
html = fill(html, 'JS', jsAll.split('</script').join('<\\/script'));
html = fill(html, 'PROJ8_DATA', JSON.stringify(proj8Data).split('</script').join('<\\/script'));
html = fill(html, 'PROJ8_FALLBACK', proj8Fallback);
html = fill(html, 'SAFE_HTML', prerendered.safe || '');
html = fill(html, 'BOLD_HTML', prerendered.bold || '');

const outHtml = path.join(OUT, 'mockup.html');
fs.writeFileSync(outHtml, html);

// ── 6) Build-Report (Größen-Treiber für das 5-MB-Gate) ──────────────────────
const dataUris = [...html.matchAll(/data:([a-z0-9.+/-]+);base64,[A-Za-z0-9+/=]{512,}/gi)]
  .map((m) => ({ mime: m[1], bytes: m[0].length }))
  .sort((a, b) => b.bytes - a.bytes).slice(0, 5);
fs.writeFileSync(path.join(OUT, 'build-report.json'), JSON.stringify({
  bytes: {
    total: Buffer.byteLength(html),
    css: Buffer.byteLength(css),
    js: Buffer.byteLength(clientJs),
    prerendered_safe: Buffer.byteLength(prerendered.safe || ''),
    prerendered_bold: Buffer.byteLength(prerendered.bold || ''),
  },
  font_families: families,
  largest_data_uris: dataUris,
}, null, 2));

console.log(`✓ build.mjs: mockup.html gebaut (${(Buffer.byteLength(html) / 1024).toFixed(0)} kB) → ${outHtml}`);
