#!/usr/bin/env node
/*
 * registry-recycle.mjs — Best-of-Recycling für die Registry (PROJ-11).
 *
 * Schlägt am Ende eines Redesign-Laufs portfoliowürdige Sektionen vor und
 * bewacht die Übernahme (keine Kundendaten, keine Roh-Tokens, kein Duplikat).
 * Deterministisch (kein LLM) — die eigentliche Generalisierung/Token-Umstellung
 * macht Claude (Skill `ui-recycle`), dieser Guard lässt sie erst durch, wenn sauber.
 *
 * Modi:
 *   (propose)  node scripts/registry-recycle.mjs --run <run-dir> [--min-total 62] [--min-visual 65] [--force]
 *              → redesign/recycle-proposals.json + Ranking. Nur neuartige Sektionen (nicht schon abgedeckt).
 *   (guard)    node scripts/registry-recycle.mjs --run <run-dir> --guard <block.jsx> [--name <n>] [--json]
 *              → Exit 2, wenn Kundendaten / Roh-Tokens / Duplikat gefunden (Übernahme blockiert), sonst 0.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const REG = path.join(ROOT, "registry");
const DUP = 0.80, WARN = 0.55;

// ── Args ──
const argv = process.argv.slice(2); const opt = { minTotal: 62, minVisual: 65 };
for (let i = 0; i < argv.length; i++) { const k = argv[i];
  if (k === "--run") opt.run = argv[++i];
  else if (k === "--guard") opt.guard = argv[++i];
  else if (k === "--name") opt.name = argv[++i];
  else if (k === "--min-total") opt.minTotal = +argv[++i];
  else if (k === "--min-visual") opt.minVisual = +argv[++i];
  else if (k === "--force") opt.force = true;
  else if (k === "--json") opt.json = true;
  else if (k === "-h" || k === "--help") { console.log("siehe Kopf von registry-recycle.mjs"); process.exit(0); }
}
const die = (m) => { console.error(`✗ ${m}`); process.exit(2); };
const readJSON = (p, f) => { try { return JSON.parse(fs.readFileSync(p, "utf8")); } catch { return f; } };
if (!opt.run) die("--run <run-dir> fehlt.");
const RUN = path.resolve(opt.run), RD = path.join(RUN, "redesign");
if (!fs.existsSync(RD)) die(`Kein redesign/ in ${RUN}.`);

// ── Ähnlichkeit (wie registry-dedupe) ──
const stripC = (s) => s.replace(/\/\*[\s\S]*?\*\//g, " ").replace(/\/\/[^\n]*/g, " ");
const normLit = (s) => stripC(s).replace(/\s+/g, " ").toLowerCase().trim();
const normStr = (s) => stripC(s).replace(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`/g, " STR ").replace(/\s+/g, " ").toLowerCase().trim();
const grams = (s, n = 5) => { const g = new Set(); for (let i = 0; i + n <= s.length; i++) g.add(s.slice(i, i + n)); return g; };
const jac = (a, b) => { if (!a.size || !b.size) return 0; let x = 0; const [s, l] = a.size < b.size ? [a, b] : [b, a]; for (const v of s) if (l.has(v)) x++; return x / (a.size + b.size - x); };
const fp = (c) => ({ lit: grams(normLit(c)), str: grams(normStr(c)) });
const sim = (a, b) => Math.max(jac(a.lit, b.lit), 0.9 * jac(a.str, b.str));

// Registry-Fingerprints (Novelty-Referenz)
const registry = readJSON(path.join(REG, "registry.json"), { items: [] });
const regBlocks = registry.items.filter((it) => it.type === "registry:block" && it.meta?.kind !== "template" && it.files?.[0]?.path)
  .map((b) => ({ name: b.name, fp: fp(fs.existsSync(path.join(REG, b.files[0].path)) ? fs.readFileSync(path.join(REG, b.files[0].path), "utf8") : "") }));
const novelty = (code, exclude) => { const f = fp(code); let best = { name: null, s: 0 }; for (const r of regBlocks) { if (r.name === exclude) continue; const s = sim(f, r.fp); if (s > best.s) best = { name: r.name, s }; } return best; };

// Run-eigene Token-Namen (aus dem Run-Theme) minus Registry-Semantik → müssen bei
// der Übernahme auf semantische Tokens umgestellt werden (z. B. text-primary, bg-palette-2).
const REG_TOKENS = new Set(["paper", "ink", "ink-soft", "muted", "surface", "line", "accent", "accent-soft", "sand"]);
const themeCss = fs.existsSync(path.join(RD, "shared", "tailwind-theme.css")) ? fs.readFileSync(path.join(RD, "shared", "tailwind-theme.css"), "utf8") : "";
const runTokenNames = [...new Set([...themeCss.matchAll(/--color-([a-z0-9-]+)\s*:/g)].map((m) => m[1]))].filter((n) => !REG_TOKENS.has(n));
const RUN_TOKEN_RE = runTokenNames.length ? new RegExp(`\\b(?:bg|text|border|from|via|to|ring|fill|stroke|divide|outline|shadow|decoration|accent)-(?:${runTokenNames.map((n) => n.replace(/[-]/g, "\\-")).join("|")})(?:/\\d+)?\\b`, "g") : null;

// ── Kundendaten-Guard-Grundlage ──
const content = readJSON(path.join(RD, "shared", "content.json"), {});
const ctx = readJSON(path.join(RUN, "ui-check.json"), {});
function collectStrings(o, acc = []) { if (typeof o === "string") { if (o.trim().length >= 20) acc.push(o.trim().replace(/\s+/g, " ")); } else if (Array.isArray(o)) o.forEach((v) => collectStrings(v, acc)); else if (o && typeof o === "object") Object.values(o).forEach((v) => collectStrings(v, acc)); return acc; }
const customerCopy = [...new Set(collectStrings(content))];
const domain = (() => { try { return new URL(ctx.final_url || ctx.url).hostname.replace(/^www\./, ""); } catch { return null; } })();
const PII = [
  { label: "E-Mail", re: /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/gi },
  { label: "Telefon", re: /\+?\d[\d\s().\/-]{7,}\d/g },
];
const RAW_HEX = /#[0-9a-fA-F]{3,8}\b/g;
const DEFAULT_PALETTE = /\b(?:bg|text|border|from|via|to|ring|fill|stroke|divide|outline|shadow|decoration)-(?:slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-(?:50|100|200|300|400|500|600|700|800|900|950)\b/g;

function scanCustomer(code) {
  const flat = code.replace(/\s+/g, " ");
  const verbatim = customerCopy.filter((s) => flat.includes(s)).slice(0, 20);
  const pii = [];
  for (const p of PII) { const m = code.match(p.re); if (m) pii.push(`${p.label}: ${[...new Set(m)].slice(0, 3).join(", ")}`); }
  if (domain && new RegExp(domain.replace(/[.]/g, "\\.")).test(code)) pii.push(`Domain: ${domain}`);
  return { verbatim, pii };
}
function scanTokens(code) {
  const hex = [...new Set(code.match(RAW_HEX) || [])].filter((h) => h.length >= 4); // #abc/#aabbcc
  const pal = [...new Set(code.match(DEFAULT_PALETTE) || [])];
  const run = RUN_TOKEN_RE ? [...new Set(code.match(RUN_TOKEN_RE) || [])] : [];
  return { hex, pal, run };
}

// ══════════════════════════════════════════════════════════════════════════
// GUARD-Modus
// ══════════════════════════════════════════════════════════════════════════
if (opt.guard) {
  const p = path.resolve(opt.guard);
  if (!fs.existsSync(p)) die(`Block nicht gefunden: ${p}`);
  const code = fs.readFileSync(p, "utf8");
  const name = opt.name || path.basename(p).replace(/\.(jsx|tsx|js)$/, "");
  const cust = scanCustomer(code), tok = scanTokens(code);
  const nov = novelty(code, name);
  const blockers = [];
  if (cust.verbatim.length) blockers.push(`Kundencopy verbatim (${cust.verbatim.length}) — generalisieren zu Platzhaltern`);
  if (cust.pii.length) blockers.push(`PII/Domain: ${cust.pii.join(" · ")}`);
  if (tok.hex.length) blockers.push(`Roh-Hex: ${tok.hex.join(", ")} — Tokens nutzen`);
  if (tok.pal.length) blockers.push(`Tailwind-Default-Palette: ${tok.pal.slice(0, 6).join(", ")} — semantische Tokens nutzen`);
  if (tok.run.length) blockers.push(`Run-Tokens (auf Registry-Semantik umstellen): ${tok.run.slice(0, 8).join(", ")}`);
  if (nov.s >= DUP) blockers.push(`Duplikat zu \`${nov.name}\` (${nov.s.toFixed(2)}) — bewusste Bestätigung / anderer Zweck?`);
  const ok = blockers.length === 0;
  if (opt.json) console.log(JSON.stringify({ block: name, ok, blockers, nearest: nov }, null, 2));
  else {
    console.log(`Recycle-Guard: ${name} → ${ok ? "✓ SAUBER (Übernahme frei)" : "✗ BLOCKIERT"}`);
    for (const b of blockers) console.log(`   ✗ ${b}`);
    if (nov.s >= WARN && nov.s < DUP) console.log(`   ℹ ähnlich zu \`${nov.name}\` (${nov.s.toFixed(2)}) — prüfen, ob nötig.`);
    if (ok) console.log(`   Neu, token-agnostisch, ohne Kundendaten. → in registry/blocks/ eintragen (Skill ui-recycle Schritt 4).`);
  }
  process.exit(ok ? 0 : 2);
}

// ══════════════════════════════════════════════════════════════════════════
// PROPOSE-Modus
// ══════════════════════════════════════════════════════════════════════════
const scores = readJSON(path.join(RUN, "scores.json"), {});
const total = scores.total ?? null, visual = scores.dimensions?.visuell?.score ?? null;
const runGood = total != null && total >= opt.minTotal && (visual == null || visual >= opt.minVisual);
if (!runGood && !opt.force) {
  const msg = `Lauf unter Schwelle (total ${total}/${opt.minTotal}, visuell ${visual}/${opt.minVisual}) — kein Recycling empfohlen. --force überschreibt.`;
  fs.writeFileSync(path.join(RD, "recycle-proposals.json"), JSON.stringify({ run_id: path.basename(RUN), eligible: false, reason: msg, proposals: [] }, null, 2));
  console.log(`ℹ ${msg}`);
  process.exit(0);
}

const secAlias = { leistungen: "services", stimmen: "social-proof", kontakt: "cta", abschluss: "cta", nav: "nav", hero: "hero", footer: "footer", about: "about", team: "team", prozess: "process", faq: "faq" };
const idOf = (s) => s.id || s.type;
const typeById = Object.fromEntries((content.sections || []).map((s) => [idOf(s), s.type || idOf(s)]));

const proposals = [];
for (const variant of ["safe", "bold"]) {
  const dir = path.join(RD, variant, "sections");
  if (!fs.existsSync(dir)) continue;
  for (const file of fs.readdirSync(dir).filter((f) => /\.jsx$/.test(f))) {
    const full = path.join(dir, file);
    const code = fs.readFileSync(full, "utf8");
    const id = file.replace(/\.jsx$/, "").toLowerCase();
    const secType = typeById[id] || secAlias[id] || id;
    const nov = novelty(code);
    const cust = scanCustomer(code), tok = scanTokens(code);
    const generalizeCost = cust.verbatim.length + cust.pii.length + tok.hex.length + tok.pal.length + tok.run.length;
    const covered = nov.s >= WARN;
    // Portfolio-Score: Lauf-Qualität + Neuartigkeit (Generalisierungsaufwand ist behebbar → gering gewichtet)
    const score = Math.round(((total || 0) * 0.5) + ((1 - nov.s) * 40) - Math.min(generalizeCost, 10));
    proposals.push({
      variant, section_id: id, section_type: secType, style: variant,
      source_file: path.relative(RUN, full),
      novelty: +(1 - nov.s).toFixed(2), nearest_block: nov.name, nearest_sim: +nov.s.toFixed(2),
      already_covered: covered,
      suggested_name: `${secType}-${path.basename(RUN).replace(/[^a-z0-9]+/gi, "").slice(0, 8)}`.toLowerCase(),
      suggested_meta: { section: secType, style: variant, industry: ctx.industry_tag ? [ctx.industry_tag] : [] },
      generalize: { verbatim_customer_copy: cust.verbatim.length, pii: cust.pii, raw_hex: tok.hex, default_palette: tok.pal.slice(0, 8), run_tokens: tok.run.slice(0, 12) },
      portfolio_score: score,
    });
  }
}
proposals.sort((a, b) => b.portfolio_score - a.portfolio_score);
const fresh = proposals.filter((p) => !p.already_covered);

const out = { run_id: path.basename(RUN), eligible: true, run: { total, visual }, dup_threshold: DUP, warn_threshold: WARN, proposals };
fs.writeFileSync(path.join(RD, "recycle-proposals.json"), JSON.stringify(out, null, 2));

console.log(`Recycle-Vorschläge — Lauf ${path.basename(RUN)} (total ${total}, visuell ${visual})`);
console.log(`  ${fresh.length} neuartige Sektion(en) vorgeschlagen, ${proposals.length - fresh.length} bereits abgedeckt.\n`);
for (const p of fresh) {
  console.log(`  ★ ${p.portfolio_score}  ${p.variant}/${p.section_id} (${p.section_type})  Neuartigkeit ${p.novelty}` + (p.nearest_block ? ` (nächster: ${p.nearest_block} ${p.nearest_sim})` : ""));
  const g = p.generalize; const need = [];
  if (g.verbatim_customer_copy) need.push(`${g.verbatim_customer_copy}× Kundencopy`);
  if (g.pii.length) need.push(`PII (${g.pii.length})`);
  if (g.raw_hex.length) need.push(`${g.raw_hex.length}× Roh-Hex`);
  if (g.default_palette.length) need.push(`${g.default_palette.length}× Default-Palette`);
  if (g.run_tokens.length) need.push(`${g.run_tokens.length}× Run-Token→Semantik`);
  console.log(`      → generalisieren: ${need.length ? need.join(", ") : "nichts"}  ·  Vorschlag-Name: ${p.suggested_name}`);
}
if (proposals.some((p) => p.already_covered))
  console.log(`\n  Bereits abgedeckt: ${proposals.filter((p) => p.already_covered).map((p) => `${p.section_id}→${p.nearest_block}`).join(", ")}`);
console.log(`\n  Details: ${path.relative(process.cwd(), path.join(RD, "recycle-proposals.json"))}. Übernahme: Skill ui-recycle (Guard: registry-recycle.mjs --guard).`);
