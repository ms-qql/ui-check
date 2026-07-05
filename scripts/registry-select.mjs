#!/usr/bin/env node
/*
 * registry-select.mjs — Registry-Andockung für ui-redesign (PROJ-11).
 *
 * Deterministisch (kein LLM): wählt je Sektion eines Laufs einen Registry-Block
 * (Auto-Match nach Sektionstyp + Branche + Stil) mit Fallback auf Neu-Generierung,
 * respektiert Nutzer-Overrides, emittiert einen Token-Alias (Registry-Semantik →
 * Run-Branding) und kopiert lib + gewählte Blocks in den Lauf.
 *
 * Nutzung:
 *   node scripts/registry-select.mjs --run <run-dir> --style safe|bold [flags]
 * Flags (überschreiben --config):
 *   --template <slug>        Template erzwingen (sonst Auto nach industry_tag)
 *   --pin <section>=<block>  Sektion fest auf Block (wiederholbar)
 *   --exclude <block>        Block ausschließen (wiederholbar)
 *   --registry-only          kein Fallback — unauflösbare Sektion = Fehler (Exit 2)
 *   --no-registry            alles generieren (Registry aus)
 *   --config <file>          Defaults (JSON) laden (von redesign.sh geschrieben)
 * Exit: 0 ok · 1 degradiert (Fallback genutzt) · 2 harter Fehler.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const REG_DIR = path.join(ROOT, "registry");

// ── Args ────────────────────────────────────────────────────────────────────
function parseArgs(argv) {
  const a = { pin: {}, exclude: [] };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    const next = () => argv[++i];
    if (k === "--run") a.run = next();
    else if (k === "--style") a.style = next();
    else if (k === "--template") a.template = next();
    else if (k === "--pin") { const [s, b] = String(next()).split("="); if (s && b) a.pin[s] = b; }
    else if (k === "--exclude") a.exclude.push(next());
    else if (k === "--registry-only") a.registryOnly = true;
    else if (k === "--no-registry") a.noRegistry = true;
    else if (k === "--config") a.config = next();
    else if (k === "-h" || k === "--help") { console.log("siehe Kopf von registry-select.mjs"); process.exit(0); }
    else die(`Unbekannte Option: ${k}`);
  }
  return a;
}
function die(msg) { console.error(`✗ ${msg}`); process.exit(2); }
function readJSON(p, fallback) { try { return JSON.parse(fs.readFileSync(p, "utf8")); } catch { return fallback; } }

// ── Sektionstyp-Synonyme (Content-`type` → Registry-`meta.section`) ───────────
const SECTION_ALIASES = {
  nav: "nav", navbar: "nav", header: "nav",
  hero: "hero", intro: "hero",
  about: "about", "ueber-uns": "about", "ueber": "about", "about-us": "about", story: "about",
  services: "services", leistungen: "services", angebot: "services", angebote: "services", loesungen: "services", features: "services",
  portfolio: "portfolio", cases: "portfolio", "case-studies": "portfolio", referenzen: "portfolio", projekte: "portfolio", work: "portfolio",
  process: "process", prozess: "process", ablauf: "process", steps: "process", "wie-es-funktioniert": "process",
  team: "team", people: "team", "das-team": "team",
  trust: "trust", awards: "trust", auszeichnungen: "trust", zertifikate: "trust", partner: "trust", logos: "trust",
  "social-proof": "social-proof", testimonials: "social-proof", stimmen: "social-proof", bewertungen: "social-proof", reviews: "social-proof",
  faq: "faq", fragen: "faq",
  cta: "cta", kontakt: "cta", contact: "cta", abschluss: "cta", "call-to-action": "cta", anfrage: "cta",
  footer: "footer", fuss: "footer",
};
const canonSection = (t) => SECTION_ALIASES[String(t || "").toLowerCase()] || String(t || "").toLowerCase();

// ── Farb-Helfer ───────────────────────────────────────────────────────────────
function hexToRgb(h) { const s = h.replace("#", ""); return [0, 2, 4].map((i) => parseInt(s.substr(i, 2), 16)); }
function rgbToHex(r, g, b) { return "#" + [r, g, b].map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0")).join(""); }
function luminance(hex) { const [r, g, b] = hexToRgb(hex).map((v) => v / 255); return 0.2126 * r + 0.7152 * g + 0.0722 * b; }
function mix(hex, withHex, t) { const a = hexToRgb(hex), b = hexToRgb(withHex); return rgbToHex(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t); }
function saturation(hex) { const [r, g, b] = hexToRgb(hex).map((v) => v / 255); const mx = Math.max(r, g, b), mn = Math.min(r, g, b); const l = (mx + mn) / 2; if (mx === mn) return 0; const d = mx - mn; return l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn); }

// Registry-Default-Werte (verdict) als Fallback, falls Run-Tokens dünn sind.
const DEFAULTS = { paper: "#ffffff", ink: "#0a0a0a", "ink-soft": "#171717", muted: "#737373", surface: "#f5f5f5", line: "#e3ddd6", accent: "#c87f2c", "accent-soft": "#e8a95c", sand: "#c9b191" };

// Token-Alias aus branding/tokens.json des Laufs bauen (Luminanz-Heuristik).
function buildTokenAlias(runTokens) {
  const out = { ...DEFAULTS };
  const pal = runTokens?.color?.palette ? Object.values(runTokens.color.palette).map((e) => ({ hex: (e.$value || "").toLowerCase(), neutral: e.$extensions?.["uicheck.neutral"], l: e.$extensions?.["uicheck.hsl"]?.l })) : [];
  const withHex = pal.filter((p) => /^#[0-9a-f]{6}$/.test(p.hex));
  const withL = withHex.map((p) => ({ ...p, l: typeof p.l === "number" ? p.l : luminance(p.hex) }));
  const neutrals = withL.filter((p) => p.neutral !== false); // neutral true/undef
  // Nur übernehmen, wenn ein Neutral nah genug am Ziel liegt UND sich von der
  // Bezugsfarbe unterscheidet — sonst deterministisch aus paper/ink mischen.
  const pickNear = (target, tol, distinctFrom) => {
    const c = neutrals.slice().sort((a, b) => Math.abs(a.l - target) - Math.abs(b.l - target))[0];
    return (c && Math.abs(c.l - target) <= tol && c.hex !== distinctFrom) ? c.hex : null;
  };
  if (neutrals.length) {
    out.ink = neutrals.slice().sort((a, b) => a.l - b.l)[0].hex;
    out.paper = neutrals.slice().sort((a, b) => b.l - a.l)[0].hex;
    out["ink-soft"] = pickNear(0.10, 0.05, out.ink) || mix(out.ink, out.paper, 0.06);
    out.surface = pickNear(0.96, 0.06, out.paper) || mix(out.paper, out.ink, 0.04);
    out.line = pickNear(0.87, 0.08, out.paper) || mix(out.paper, out.ink, 0.12);
  }
  // primary / surface / text aus den Rollen-Tokens bevorzugen
  const roleHex = (k) => (runTokens?.color?.[k]?.$value || "").toLowerCase();
  if (/^#[0-9a-f]{6}$/.test(roleHex("primary"))) out.accent = roleHex("primary");
  else { const chroma = withL.filter((p) => p.neutral === false).sort((a, b) => saturation(b.hex) - saturation(a.hex))[0]; if (chroma) out.accent = chroma.hex; }
  if (/^#[0-9a-f]{6}$/.test(roleHex("text"))) out.muted = roleHex("text");
  if (/^#[0-9a-f]{6}$/.test(roleHex("surface"))) out.paper = out.paper === DEFAULTS.paper ? roleHex("surface") : out.paper;
  // abgeleitete Akzente
  out["accent-soft"] = mix(out.accent, "#ffffff", 0.35);
  out.sand = mix(out.accent, out.line || "#cccccc", 0.5);
  return out;
}

// Font-Familien aus dem Run-Theme (Namen) ziehen.
function fontsFromTheme(themeCss) {
  const grab = (name) => { const m = themeCss.match(new RegExp(`--${name}:\\s*([^;]+);`)); return m ? m[1].trim() : null; };
  const sans = grab("font-display-text") || grab("font-sans") || '"Geist", ui-sans-serif, system-ui, sans-serif';
  const mono = grab("font-mono") || grab("font-other") || sans;
  const display = grab("font-display") || grab("font-display-text") || sans;
  return { sans, mono, display };
}

// ── Hauptlauf ─────────────────────────────────────────────────────────────────
const cli = parseArgs(process.argv.slice(2));
const cfg = cli.config ? readJSON(cli.config, {}) : {};
const opt = {
  run: cli.run || cfg.run,
  style: cli.style || cfg.style || "safe",
  template: cli.template ?? cfg.template ?? null,
  pin: { ...(cfg.pin || {}), ...cli.pin },
  exclude: [...new Set([...(cfg.exclude || []), ...cli.exclude])],
  registryOnly: cli.registryOnly ?? cfg.registryOnly ?? false,
  noRegistry: cli.noRegistry ?? cfg.noRegistry ?? false,
};
if (!opt.run) die("--run <run-dir> fehlt.");
if (!["safe", "bold"].includes(opt.style)) die(`--style muss safe|bold sein (war: ${opt.style}).`);
const RUN = path.resolve(opt.run);
const RD = path.join(RUN, "redesign");
if (!fs.existsSync(RD)) die(`Kein redesign/ in ${RUN} — erst redesign.sh INIT.`);

const registry = readJSON(path.join(REG_DIR, "registry.json"), null);
if (!registry) die(`registry/registry.json nicht lesbar.`);
const blocks = registry.items.filter((it) => it.type === "registry:block" && it.meta?.section);
const templates = registry.items.filter((it) => it.meta?.kind === "template");

const ctx = readJSON(path.join(RD, "redesign-context.json"), {});
const industry = ctx.industry_tag || null;
const matchesIndustry = (item) => {
  if (!industry) return true;
  const tags = item.meta?.industry || [];
  return tags.some((tag) => industry.includes(tag) || tag.includes(industry));
};

// Template auflösen: Flag > Branche-Match > einziges Template > keins.
let template = null, templateReason = "";
if (opt.noRegistry) { templateReason = "--no-registry: Registry deaktiviert"; }
else if (opt.template) {
  template = templates.find((t) => t.meta?.branding === opt.template || t.name === opt.template || t.name === `${opt.template}-template`) || null;
  if (!template) die(`--template ${opt.template}: kein Template gefunden.`);
  templateReason = `erzwungen (--template ${opt.template})`;
} else if (industry) {
  const scored = templates.map((t) => ({ t, s: (t.meta?.industry || []).filter((x) => industry.includes(x) || x.includes(industry)).length })).sort((a, b) => b.s - a.s);
  if (scored[0]?.s > 0) { template = scored[0].t; templateReason = `Branche-Match "${industry}"`; }
}
if (!template && !opt.noRegistry) {
  if (templates.length === 1) { template = templates[0]; templateReason = `einziges Template (industry_tag=${industry ?? "null"}, low-confidence)`; }
  else templateReason = `kein Branche-Match (industry_tag=${industry ?? "null"}) → Blocks generisch`;
}
const templateBranding = template?.meta?.branding || null;

// Sektionsplan: aus shared/content.json, sonst aus template.json.
const content = readJSON(path.join(RD, "shared", "content.json"), null);
let plan = [];
if (content?.sections?.length) plan = content.sections.map((s) => ({ id: s.id, type: s.type || s.id }));
else if (template) {
  const tj = readJSON(path.join(REG_DIR, "templates", templateBranding, "template.json"), null);
  plan = (tj?.sections || []).map((s) => ({ id: s.id, type: s.id, forcedBlock: s.block }));
}

// Block je Sektion wählen.
const chosen = new Set();
const sections = plan.map(({ id, type, forcedBlock }) => {
  const canon = canonSection(type);
  // Pin?
  if (opt.pin[id]) {
    const b = blocks.find((x) => x.name === opt.pin[id]);
    if (!b) die(`--pin ${id}=${opt.pin[id]}: Block existiert nicht.`);
    chosen.add(b.name);
    return { id, type, canon, decision: "registry", block: b.name, reason: "pin" };
  }
  if (opt.noRegistry) return { id, type, canon, decision: "generate", reason: "--no-registry" };
  // Kandidaten: gleicher Sektionstyp, nicht ausgeschlossen. Stil ist WEICH (Ranking,
  // kein Ausschluss) — ein Safe-Block darf als Fallback in eine Bold-Variante.
  const cands = blocks
    .filter((b) => canonSection(b.meta.section) === canon && matchesIndustry(b) && !opt.exclude.includes(b.name))
    .map((b) => ({ b, score: (b.meta.source === templateBranding ? 2 : 0) + (!b.meta.style || b.meta.style === opt.style ? 1 : 0) }))
    .sort((a, b) => b.score - a.score);
  const pick = cands[0]?.b || null;
  if (pick) {
    chosen.add(pick.name);
    const styleMismatch = pick.meta.style && pick.meta.style !== opt.style;
    const reason = (pick.meta.source === templateBranding ? "template-match" : "type-match") + (styleMismatch ? ` (Stil ${pick.meta.style}≠${opt.style})` : "");
    return { id, type, canon, decision: "registry", block: pick.name, reason };
  }
  if (forcedBlock && blocks.find((b) => b.name === forcedBlock)) { chosen.add(forcedBlock); return { id, type, canon, decision: "registry", block: forcedBlock, reason: "template-default" }; }
  return { id, type, canon, decision: "generate", reason: `kein Block für Typ "${canon}"` };
});

const unresolved = sections.filter((s) => s.decision === "generate" && !opt.noRegistry);
if (opt.registryOnly && unresolved.length) {
  console.error(`✗ --registry-only: ${unresolved.length} Sektion(en) ohne Block: ${unresolved.map((s) => s.id).join(", ")}`);
  writeSelection("error");
  process.exit(2);
}

// ── Artefakte schreiben ───────────────────────────────────────────────────────
const OUT = path.join(RD, "registry");
fs.mkdirSync(path.join(OUT, "blocks"), { recursive: true });
fs.mkdirSync(path.join(OUT, "lib"), { recursive: true });

// lib kopieren
for (const f of ["cn.js", "ui.jsx"]) fs.copyFileSync(path.join(REG_DIR, "lib", f), path.join(OUT, "lib", f));
// gewählte Blocks kopieren
for (const name of chosen) {
  const item = blocks.find((b) => b.name === name);
  const rel = item.files[0].path; // z.B. blocks/verdict-hero.jsx
  fs.copyFileSync(path.join(REG_DIR, rel), path.join(OUT, "blocks", path.basename(rel)));
}

// Token-Alias: Registry-Semantik → Run-Branding (aufgelöste Hex + Fonts)
const runTokens = readJSON(path.join(RUN, "branding", "tokens.json"), readJSON(path.join(RD, "shared", "tokens.json"), {}));
const alias = buildTokenAlias(runTokens);
const themeCss = fs.existsSync(path.join(RD, "shared", "tailwind-theme.css")) ? fs.readFileSync(path.join(RD, "shared", "tailwind-theme.css"), "utf8") : "";
const fonts = fontsFromTheme(themeCss);
const aliasCss = `/* Auto-generiert von registry-select.mjs — Registry-Token-Semantik auf das
   Branding dieses Laufs abgebildet. Registry-Blocks nutzen NUR diese Tokens. */
@theme {
  --color-paper: ${alias.paper};
  --color-ink: ${alias.ink};
  --color-ink-soft: ${alias["ink-soft"]};
  --color-muted: ${alias.muted};
  --color-surface: ${alias.surface};
  --color-line: ${alias.line};
  --color-accent: ${alias.accent};
  --color-accent-soft: ${alias["accent-soft"]};
  --color-sand: ${alias.sand};
  --font-sans: ${fonts.sans};
  --font-mono: ${fonts.mono};
  --font-display: ${fonts.display};
}
`;
fs.writeFileSync(path.join(OUT, "registry-tokens.css"), aliasCss);
// Basis-Utilities mitkopieren (eyebrow, mono-label, display, section-padding, container-x)
fs.copyFileSync(path.join(REG_DIR, "styles", "base.css"), path.join(OUT, "base.css"));

writeSelection(unresolved.length ? "degraded" : "ok");

const registryCount = sections.filter((s) => s.decision === "registry").length;
console.log(`✓ registry-select [${opt.style}] · Template: ${template?.meta?.branding ?? "—"} (${templateReason})`);
console.log(`  ${registryCount}/${sections.length} Sektionen aus Registry, ${unresolved.length} generieren.`);
for (const s of sections) console.log(`   · ${s.id} (${s.canon}) → ${s.decision === "registry" ? s.block : "GENERIEREN"}  [${s.reason}]`);
console.log(`  Alias + lib + blocks → ${path.relative(process.cwd(), OUT)}`);
process.exit(unresolved.length ? 1 : 0);

function writeSelection(status) {
  const sel = {
    $meta: { generator: "registry-select.mjs", registry_version: (fs.readFileSync(path.join(REG_DIR, "VERSION"), "utf8").trim()) },
    run_id: path.basename(RUN), style: opt.style, status,
    template: template?.meta?.branding ?? null, template_reason: templateReason,
    branding_alias: "redesign/registry/registry-tokens.css",
    overrides: { template: opt.template ?? null, pin: opt.pin, exclude: opt.exclude, registryOnly: opt.registryOnly, noRegistry: opt.noRegistry },
    stats: { total: plan.length, registry: sections.filter((s) => s.decision === "registry").length, generate: sections.filter((s) => s.decision === "generate").length },
    sections,
    blocks_copied: [...chosen],
  };
  fs.writeFileSync(path.join(RD, `registry-selection.${opt.style}.json`), JSON.stringify(sel, null, 2));
}
