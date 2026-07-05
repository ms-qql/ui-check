#!/usr/bin/env node
/*
 * registry-dedupe.mjs — Doppel-/Ähnlichkeits-Check für die Registry (PROJ-11).
 *
 * Zwei Ähnlichkeitssignale je Block-Paar (Char-5-Gramm-Jaccard auf normalisiertem Code):
 *   · literal     — Strings/Klassen erhalten → fängt Kopien/Re-Ingests
 *   · strukturell  — Strings→STR → fängt gleiches Layout mit anderer Copy/Branding
 * combined = max(literal, 0.9·strukturell). Gleicher Sektionstyp wird als Kontext gemeldet.
 *
 * Modi:
 *   (Audit)      node scripts/registry-dedupe.mjs [--min 0.5]
 *                Alle Paare oberhalb Schwelle, absteigend. Exit 1 bei Near-Dupe (≥ WARN).
 *   (Kandidat)   node scripts/registry-dedupe.mjs --candidate <file.jsx> [--section <s>] [--name <n>] [--json]
 *                Vergleicht Datei gegen Bestand. Exit 2 = Duplikat (≥ DUP, bewusste Bestätigung nötig),
 *                1 = ähnlich (≥ WARN), 0 = ok.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const REG = path.join(ROOT, "registry");
const DUP = 0.80;   // ab hier: Duplikat → bewusste Bestätigung
const WARN = 0.55;  // ab hier: ähnlich → Hinweis

// ── Args ──
const argv = process.argv.slice(2);
const opt = { min: 0.5, json: false };
for (let i = 0; i < argv.length; i++) {
  const k = argv[i];
  if (k === "--candidate") opt.candidate = argv[++i];
  else if (k === "--section") opt.section = argv[++i];
  else if (k === "--name") opt.name = argv[++i];
  else if (k === "--min") opt.min = parseFloat(argv[++i]);
  else if (k === "--json") opt.json = true;
  else if (k === "-h" || k === "--help") { console.log("siehe Kopf von registry-dedupe.mjs"); process.exit(0); }
}

// ── Normalisierung + n-Gramme ──
function stripComments(s) { return s.replace(/\/\*[\s\S]*?\*\//g, " ").replace(/\/\/[^\n]*/g, " "); }
function normLiteral(s) { return stripComments(s).replace(/\s+/g, " ").toLowerCase().trim(); }
function normStructural(s) {
  return stripComments(s)
    .replace(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`/g, " STR ")
    .replace(/\s+/g, " ").toLowerCase().trim();
}
function grams(s, n = 5) { const g = new Set(); for (let i = 0; i + n <= s.length; i++) g.add(s.slice(i, i + n)); return g; }
function jaccard(a, b) { if (!a.size || !b.size) return 0; let inter = 0; const [s, l] = a.size < b.size ? [a, b] : [b, a]; for (const x of s) if (l.has(x)) inter++; return inter / (a.size + b.size - inter); }

function fingerprint(code) { return { lit: grams(normLiteral(code)), str: grams(normStructural(code)) }; }
function similarity(fpA, fpB) {
  const lit = jaccard(fpA.lit, fpB.lit);
  const str = jaccard(fpA.str, fpB.str);
  return { lit, str, combined: Math.max(lit, 0.9 * str) };
}

// ── Registry laden ──
const registry = JSON.parse(fs.readFileSync(path.join(REG, "registry.json"), "utf8"));
const blocks = (registry.items || []).filter((it) => it.type === "registry:block" && it.meta?.kind !== "template" && it.files?.[0]?.path);
const loaded = blocks.map((b) => {
  const p = path.join(REG, b.files[0].path);
  const code = fs.existsSync(p) ? fs.readFileSync(p, "utf8") : "";
  return { name: b.name, section: b.meta?.section || "-", source: b.meta?.source || "-", fp: fingerprint(code) };
});
const label = (s) => s >= DUP ? "DUPLIKAT" : s >= WARN ? "ähnlich" : "ok";

// ── Kandidat-Modus ──
if (opt.candidate) {
  const p = path.resolve(opt.candidate);
  if (!fs.existsSync(p)) { console.error(`✗ Kandidat nicht gefunden: ${p}`); process.exit(2); }
  const fp = fingerprint(fs.readFileSync(p, "utf8"));
  const candName = opt.name || path.basename(p).replace(/\.(jsx|tsx|js)$/, "");
  const matches = loaded
    .filter((b) => b.name !== candName)
    .map((b) => ({ name: b.name, section: b.section, source: b.source, ...similarity(fp, b.fp), sameSection: opt.section ? b.section === opt.section : null }))
    .sort((a, b) => b.combined - a.combined)
    .slice(0, 5);
  const top = matches[0]?.combined || 0;
  const verdict = label(top);
  if (opt.json) { console.log(JSON.stringify({ candidate: candName, verdict, top, matches }, null, 2)); }
  else {
    console.log(`Dedupe-Kandidat: ${candName}  →  ${verdict.toUpperCase()} (max ${top.toFixed(2)})`);
    for (const m of matches) console.log(`   ${m.combined.toFixed(2)}  ${m.name} [${m.section}${m.sameSection ? " · gleicher Typ" : ""}]  (lit ${m.lit.toFixed(2)} / str ${m.str.toFixed(2)})`);
    if (verdict === "DUPLIKAT") console.log(`\n⚠ Sehr ähnlicher Baustein existiert bereits — Aufnahme nur mit bewusster Bestätigung (anderer Name/Zweck?).`);
    else if (verdict === "ähnlich") console.log(`\nℹ Ähnlicher Baustein vorhanden — bitte prüfen, ob wirklich ein neuer Block nötig ist.`);
  }
  process.exit(top >= DUP ? 2 : top >= WARN ? 1 : 0);
}

// ── Audit-Modus ──
const pairs = [];
for (let i = 0; i < loaded.length; i++)
  for (let j = i + 1; j < loaded.length; j++) {
    const s = similarity(loaded[i].fp, loaded[j].fp);
    if (s.combined >= opt.min) pairs.push({ a: loaded[i], b: loaded[j], ...s });
  }
pairs.sort((x, y) => y.combined - x.combined);

if (opt.json) { console.log(JSON.stringify({ threshold: opt.min, dup: DUP, warn: WARN, pairs: pairs.map((p) => ({ a: p.a.name, b: p.b.name, combined: p.combined, lit: p.lit, str: p.str, sameSection: p.a.section === p.b.section, label: label(p.combined) })) }, null, 2)); }
else {
  console.log(`Registry-Dedupe-Audit — ${loaded.length} Blocks, Schwelle ${opt.min} (Dup ≥ ${DUP}, Warn ≥ ${WARN})`);
  if (!pairs.length) console.log("  ✓ Keine ähnlichen Paare oberhalb der Schwelle.");
  for (const p of pairs) {
    const mark = p.combined >= DUP ? "✗" : p.combined >= WARN ? "⚠" : "·";
    console.log(`  ${mark} ${p.combined.toFixed(2)}  ${p.a.name}  ~  ${p.b.name}   [${p.a.section === p.b.section ? "gleicher Typ: " + p.a.section : p.a.section + " / " + p.b.section}]  (lit ${p.lit.toFixed(2)} / str ${p.str.toFixed(2)})`);
  }
}
const worst = pairs[0]?.combined || 0;
process.exit(worst >= WARN ? 1 : 0);
