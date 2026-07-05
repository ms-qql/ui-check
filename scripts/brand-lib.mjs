#!/usr/bin/env node
/*
 * brand-lib.mjs — Branding-Profil-Bibliothek (PROJ-12).
 *
 * Nutzung:
 *   node scripts/brand-lib.mjs seed
 *   node scripts/brand-lib.mjs save <run-dir> [--slug <slug>] [--as v2]
 *   node scripts/brand-lib.mjs list
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BRANDING = path.join(ROOT, "branding");
const HAL = "/home/dev/tools/Hal/00 Context";
const NOW = () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
const VERSION_RE = /^v([1-9]\d*)$/;

function die(msg) {
  console.error(`✗ ${msg}`);
  process.exit(2);
}

function readJson(file, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return fallback;
  }
}

function writeJson(file, data) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
}

function exists(file) {
  return fs.existsSync(file);
}

function slugify(input) {
  return String(input || "")
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/https?:\/\//g, "")
    .replace(/^www\./, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64);
}

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === "--slug") out.slug = argv[++i];
    else if (a === "--as") out.as = argv[++i];
    else if (a === "-h" || a === "--help") out.help = true;
    else if (a.startsWith("-")) die(`Unbekannte Option: ${a}`);
    else out._.push(a);
  }
  return out;
}

function versionsOf(profileDir) {
  if (!exists(profileDir)) return [];
  return fs
    .readdirSync(profileDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && VERSION_RE.test(d.name))
    .map((d) => d.name)
    .sort((a, b) => Number(a.slice(1)) - Number(b.slice(1)));
}

function currentVersion(profileDir) {
  const p = readJson(path.join(profileDir, "profile.json"), {});
  if (p.active_version) return p.active_version;
  const versions = versionsOf(profileDir);
  return versions.at(-1) || "v1";
}

function setCurrentSymlink(profileDir, version) {
  const link = path.join(profileDir, "current");
  try {
    fs.rmSync(link, { force: true, recursive: true });
  } catch {
    // ignore
  }
  fs.symlinkSync(version, link, "dir");
}

function copyIfExists(src, dest) {
  if (!exists(src)) return false;
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.cpSync(src, dest, { recursive: true, force: true, dereference: false });
  return true;
}

function copyBrandingArtifacts(srcDir, versionDir) {
  fs.rmSync(versionDir, { recursive: true, force: true });
  fs.mkdirSync(versionDir, { recursive: true });
  let copied = 0;
  for (const name of fs.readdirSync(srcDir)) {
    if (["profile.json", "current", "v1", "v2", "v3", "v4", "v5"].includes(name)) continue;
    const src = path.join(srcDir, name);
    const dest = path.join(versionDir, name);
    fs.cpSync(src, dest, { recursive: true, force: true, dereference: false });
    copied += 1;
  }
  if (!exists(path.join(versionDir, "tokens.json"))) die(`tokens.json fehlt in ${srcDir}`);
  if (!exists(path.join(versionDir, "tailwind-theme.css"))) die(`tailwind-theme.css fehlt in ${srcDir}`);
  return copied;
}

function extractHexes(value, acc = []) {
  if (!value) return acc;
  if (typeof value === "string") {
    const m = value.match(/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/);
    if (m) acc.push(value.toLowerCase());
    return acc;
  }
  if (Array.isArray(value)) {
    for (const x of value) extractHexes(x, acc);
    return acc;
  }
  if (typeof value === "object") {
    for (const x of Object.values(value)) extractHexes(x, acc);
  }
  return acc;
}

function statusFor(versionDir, kind) {
  if (kind === "logo") {
    const logo = fs.readdirSync(versionDir).find((n) => /^logo\.(svg|png|jpg|jpeg|webp)$/i.test(n));
    return logo ? { status: "extrahiert", file: logo } : { status: "manuell" };
  }
  if (kind === "fonts") {
    return exists(path.join(versionDir, "fonts")) ? { status: "extrahiert", dir: "fonts" } : { status: "manuell" };
  }
  return { status: "extrahiert" };
}

function profileSummary(slug, profileDir) {
  const profile = readJson(path.join(profileDir, "profile.json"), {});
  const active = profile.active_version || currentVersion(profileDir);
  const versionDir = path.join(profileDir, active);
  const tokens = readJson(path.join(versionDir, "tokens.json"), {});
  const swatches = [...new Set(extractHexes(tokens))].slice(0, 8);
  const logo = fs.readdirSync(versionDir).find((n) => /^logo\.(svg|png|jpg|jpeg|webp)$/i.test(n));
  return {
    slug,
    name: profile.name || slug,
    tags: profile.tags || [],
    industry: profile.industry || null,
    tone: profile.tone || profile.tonalitaet || null,
    source: profile.source || "manuell",
    active_version: active,
    versions: versionsOf(profileDir),
    swatches,
    logo_path: logo ? `${slug}/${active}/${logo}` : null,
    updated_at: profile.updated_at || null,
  };
}

function migrateFlatProfile(slug) {
  const profileDir = path.join(BRANDING, slug);
  if (!exists(path.join(profileDir, "tokens.json"))) return false;
  if (exists(path.join(profileDir, "profile.json")) || exists(path.join(profileDir, "v1"))) return false;

  const tmp = path.join(profileDir, ".migrate-v1");
  fs.rmSync(tmp, { recursive: true, force: true });
  fs.mkdirSync(tmp, { recursive: true });
  for (const name of fs.readdirSync(profileDir)) {
    if (name === ".migrate-v1") continue;
    fs.renameSync(path.join(profileDir, name), path.join(tmp, name));
  }
  fs.renameSync(tmp, path.join(profileDir, "v1"));
  const now = NOW();
  writeJson(path.join(profileDir, "profile.json"), {
    slug,
    name: slug[0].toUpperCase() + slug.slice(1),
    industry: null,
    tags: [],
    tone: null,
    source: "manuell",
    origin: { note: "Aus bestehendem flachen branding/<slug>/ Profil migriert." },
    created_at: now,
    updated_at: now,
    active_version: "v1",
    versions: [{ version: "v1", created_at: now, source: "manuell" }],
    logo: statusFor(path.join(profileDir, "v1"), "logo"),
    fonts: statusFor(path.join(profileDir, "v1"), "fonts"),
  });
  setCurrentSymlink(profileDir, "v1");
  return true;
}

function regenerateIndex() {
  fs.mkdirSync(BRANDING, { recursive: true });
  const migrated = [];
  for (const ent of fs.readdirSync(BRANDING, { withFileTypes: true })) {
    if (ent.isDirectory() && !ent.name.startsWith(".") && migrateFlatProfile(ent.name)) migrated.push(ent.name);
  }
  const profiles = fs
    .readdirSync(BRANDING, { withFileTypes: true })
    .filter((ent) => ent.isDirectory() && exists(path.join(BRANDING, ent.name, "profile.json")))
    .map((ent) => profileSummary(ent.name, path.join(BRANDING, ent.name)))
    .sort((a, b) => a.slug.localeCompare(b.slug));

  writeJson(path.join(BRANDING, "index.json"), {
    generated_at: NOW(),
    profiles,
  });
  writeHtml(profiles);
  return { profiles, migrated };
}

function htmlEscape(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function writeHtml(profiles) {
  const data = JSON.stringify(profiles)
    .replace(/&/g, "\\u0026")
    .replace(/</g, "\\u003c")
    .replace(/>/g, "\\u003e")
    .replace(/\u2028/g, "\\u2028")
    .replace(/\u2029/g, "\\u2029");
  const html = `<!doctype html><html lang="de"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>UI-Check Branding-Bibliothek</title>
<style>
:root{--bg:#0b0b0c;--panel:#151517;--line:#2b2b30;--ink:#f4f4f5;--muted:#a1a1aa;--accent:#0d9488}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 ui-sans-serif,system-ui,sans-serif}
header{position:sticky;top:0;background:linear-gradient(var(--bg),var(--bg) 80%,transparent);padding:28px 24px 14px}
h1{font-size:22px;margin:0}.sub{color:var(--muted);font-size:13px;margin-top:4px}.controls{display:flex;gap:8px;margin-top:14px}
input{width:min(520px,100%);background:var(--panel);color:var(--ink);border:1px solid var(--line);border-radius:8px;padding:9px 11px;font:inherit}
main{padding:10px 24px 60px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:12px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:14px}.top{display:flex;gap:12px;align-items:center}
.logo{width:42px;height:42px;border:1px solid var(--line);border-radius:8px;display:grid;place-items:center;overflow:hidden;background:#fff}
.logo img{max-width:100%;max-height:100%;display:block}.fallback{font-weight:700;color:var(--accent)}
h2{font-size:16px;margin:0}.meta{font-family:ui-monospace,monospace;font-size:12px;color:var(--muted);margin-top:2px}
.sw{display:flex;gap:6px;margin:14px 0}.sw span{width:28px;height:28px;border-radius:6px;border:1px solid rgba(255,255,255,.18)}
.tags{display:flex;gap:6px;flex-wrap:wrap}.tag{font-size:11px;border:1px solid var(--line);border-radius:999px;padding:2px 8px;color:var(--muted)}
.tag.on{border-color:var(--accent);color:var(--accent)}.empty{color:var(--muted);padding:30px 0}
</style></head><body>
<header><h1>Branding-Bibliothek</h1><div class="sub">${profiles.length} Profile · auto-generiert aus <code>branding/*/profile.json</code></div>
<div class="controls"><input id="q" placeholder="Suche nach Profil, Tag, Quelle ..."/></div></header>
<main><div class="grid" id="grid"></div><div class="empty" id="empty" hidden>Keine Profile gefunden.</div></main>
<script>
const DATA=${data};
const grid=document.getElementById('grid'),q=document.getElementById('q'),empty=document.getElementById('empty');
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function card(p){const d=document.createElement('article');d.className='card';
 const hay=[p.slug,p.name,p.source,p.industry,p.tone,...(p.tags||[])].join(' ').toLowerCase();
 d.dataset.hay=hay;
 const logo=p.logo_path?'<img src="'+esc(p.logo_path)+'" alt=""/>':'<span class="fallback">'+esc(p.slug.slice(0,2).toUpperCase())+'</span>';
 d.innerHTML='<div class="top"><div class="logo">'+logo+'</div><div><h2>'+esc(p.name)+'</h2><div class="meta">'+esc(p.slug)+' · '+esc(p.active_version)+'</div></div></div>'+
 '<div class="sw">'+(p.swatches||[]).map(c=>'<span title="'+esc(c)+'" style="background:'+esc(c)+'"></span>').join('')+'</div>'+
 '<div class="tags"><span class="tag on">'+esc(p.source||'manuell')+'</span>'+(p.industry?'<span class="tag">'+esc(p.industry)+'</span>':'')+(p.tags||[]).map(t=>'<span class="tag">'+esc(t)+'</span>').join('')+'</div>';
 return d;}
function render(){const term=q.value.trim().toLowerCase();grid.innerHTML='';let n=0;for(const p of DATA){const c=card(p);if(term&&!c.dataset.hay.includes(term))continue;grid.append(c);n++;}empty.hidden=n>0;}
q.addEventListener('input',render);render();
</script></body></html>`;
  fs.writeFileSync(path.join(BRANDING, "index.html"), html);
}

function domainFromRun(runDir) {
  const ctx = readJson(path.join(runDir, "ui-check.json"), {});
  const candidate = ctx.final_url || ctx.url || path.basename(runDir);
  try {
    return new URL(candidate).hostname;
  } catch {
    return candidate.replace(/^\d{4}-\d{2}-\d{2}-/, "").replace(/-\d+$/, "");
  }
}

function saveRun(runDir, opts) {
  const absRun = path.resolve(runDir);
  const src = path.join(absRun, "branding");
  if (!exists(src)) die(`Run-Branding fehlt: ${src}`);
  const slug = slugify(opts.slug || domainFromRun(absRun));
  if (!slug) die("Slug konnte nicht abgeleitet werden. Bitte --slug <slug> angeben.");
  const profileDir = path.join(BRANDING, slug);
  fs.mkdirSync(profileDir, { recursive: true });
  migrateFlatProfile(slug);

  const existing = versionsOf(profileDir);
  let version = opts.as || `v${existing.length + 1}`;
  if (!VERSION_RE.test(version)) die(`Ungültige Version: ${version} (erwartet v1, v2, ...)`);
  if (exists(path.join(profileDir, version))) die(`${slug}/${version} existiert bereits; kein stilles Überschreiben.`);

  const versionDir = path.join(profileDir, version);
  copyBrandingArtifacts(src, versionDir);
  const meta = readJson(path.join(src, "branding-meta.json"), {});
  const ctx = readJson(path.join(absRun, "ui-check.json"), {});
  const now = NOW();
  const prev = readJson(path.join(profileDir, "profile.json"), {});
  const profile = {
    slug,
    name: prev.name || slug.replace(/-/g, " ").replace(/\b\w/g, (m) => m.toUpperCase()),
    industry: prev.industry || ctx.industry_tag || null,
    tags: prev.tags || (ctx.industry_tag ? [ctx.industry_tag] : []),
    tone: prev.tone || null,
    source: "extrahiert",
    origin: {
      run: path.relative(ROOT, absRun),
      domain: domainFromRun(absRun),
      url: ctx.final_url || ctx.url || null,
    },
    created_at: prev.created_at || now,
    updated_at: now,
    active_version: version,
    versions: [...(prev.versions || []), { version, created_at: now, source: "extrahiert", run: path.relative(ROOT, absRun) }],
    logo: meta.logo?.source && meta.logo.source !== "null" ? statusFor(versionDir, "logo") : { status: "manuell" },
    fonts: statusFor(versionDir, "fonts"),
  };
  writeJson(path.join(profileDir, "profile.json"), profile);
  setCurrentSymlink(profileDir, version);
  const { profiles } = regenerateIndex();
  console.log(`✓ Profil gespeichert: branding/${slug}/${version} (${profiles.length} Profile im Katalog)`);
}

function cssVar(css, name) {
  const re = new RegExp(`--${name}\\s*:\\s*([^;]+);`, "i");
  return css.match(re)?.[1]?.trim() || "";
}

function seedAuxevo() {
  const brandingMd = path.join(HAL, "Branding.md");
  const designSystem = path.join(HAL, "design-system.html");
  if (!exists(brandingMd) || !exists(designSystem)) die(`Auxevo-Quelle fehlt: ${HAL}/Branding.md oder design-system.html`);
  const slug = "auxevo";
  const profileDir = path.join(BRANDING, slug);
  fs.mkdirSync(profileDir, { recursive: true });
  migrateFlatProfile(slug);
  const version = exists(path.join(profileDir, "v1")) ? `v${versionsOf(profileDir).length + 1}` : "v1";
  const versionDir = path.join(profileDir, version);
  fs.mkdirSync(versionDir, { recursive: true });
  const css = fs.readFileSync(designSystem, "utf8");
  const c = (name, fallback) => cssVar(css, name) || fallback;
  writeJson(path.join(versionDir, "tokens.json"), {
    $description: "Branding-Profil auxevo — Design-Tokens (DTCG). Aus /home/dev/tools/Hal/00 Context importiert.",
    $meta: { profile: "auxevo", source: "Hal 00 Context", mood: ["dark-first", "technical", "minimal", "teal"] },
    color: {
      accent: { $type: "color", $value: c("accent", "#0d9488"), $extensions: { role: "brand-accent / CTA" } },
      "accent-hover": { $type: "color", $value: c("accent-hover", "#0891b2"), $extensions: { role: "hover" } },
      "accent-active": { $type: "color", $value: c("accent-active", "#0e7490"), $extensions: { role: "active" } },
      "accent-soft": { $type: "color", $value: c("accent-soft", "#ccfbf1"), $extensions: { role: "soft tint" } },
      glow: { $type: "color", $value: c("glow", "#5eead4"), $extensions: { role: "highlight glow" } },
      ink: { $type: "color", $value: c("ink", "#0a0a0a"), $extensions: { role: "canvas / dark background" } },
      surface: { $type: "color", $value: c("surface", "#171717"), $extensions: { role: "surface" } },
      "surface-card": { $type: "color", $value: c("surface-card", "#1f1f1f"), $extensions: { role: "card surface" } },
      text: { $type: "color", $value: c("text", "#fafafa"), $extensions: { role: "on-dark text" } },
      muted: { $type: "color", $value: c("muted", "#a3a3a3"), $extensions: { role: "secondary text" } },
      "muted-2": { $type: "color", $value: c("muted-2", "#525252"), $extensions: { role: "tertiary text / border text" } },
    },
    font: {
      sans: { $type: "fontFamily", $value: ["DM Sans", "system-ui", "sans-serif"], $extensions: { source: "Bunny Fonts or self-hosted" } },
      mono: { $type: "fontFamily", $value: ["JetBrains Mono", "ui-monospace", "monospace"], $extensions: { role: "labels / code" } },
    },
    radius: {
      sm: { $type: "dimension", $value: c("r-sm", "4px") },
      md: { $type: "dimension", $value: c("r-md", "6px") },
      lg: { $type: "dimension", $value: c("r-lg", "8px") },
    },
  });
  fs.writeFileSync(
    path.join(versionDir, "tailwind-theme.css"),
    `@theme {\n  --color-accent: ${c("accent", "#0d9488")};\n  --color-accent-hover: ${c("accent-hover", "#0891b2")};\n  --color-accent-active: ${c("accent-active", "#0e7490")};\n  --color-accent-soft: ${c("accent-soft", "#ccfbf1")};\n  --color-glow: ${c("glow", "#5eead4")};\n  --color-ink: ${c("ink", "#0a0a0a")};\n  --color-surface: ${c("surface", "#171717")};\n  --color-surface-card: ${c("surface-card", "#1f1f1f")};\n  --color-text: ${c("text", "#fafafa")};\n  --color-muted: ${c("muted", "#a3a3a3")};\n  --color-muted-2: ${c("muted-2", "#525252")};\n  --font-sans: "DM Sans", system-ui, sans-serif;\n  --font-mono: "JetBrains Mono", ui-monospace, monospace;\n  --radius-sm: ${c("r-sm", "4px")};\n  --radius-md: ${c("r-md", "6px")};\n  --radius-lg: ${c("r-lg", "8px")};\n}\n`,
  );
  copyIfExists(brandingMd, path.join(versionDir, "branding.md"));
  fs.writeFileSync(
    path.join(versionDir, "logo.svg"),
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="currentColor" color="#0d9488"><line x1="50" y1="50" x2="20" y2="22" stroke="currentColor" stroke-width="6" stroke-linecap="round"/><line x1="50" y1="50" x2="86" y2="32" stroke="currentColor" stroke-width="6" stroke-linecap="round"/><line x1="50" y1="50" x2="22" y2="74" stroke="currentColor" stroke-width="6" stroke-linecap="round"/><line x1="50" y1="50" x2="80" y2="80" stroke="currentColor" stroke-width="6" stroke-linecap="round"/><line x1="50" y1="50" x2="50" y2="14" stroke="currentColor" stroke-width="6" stroke-linecap="round"/><line x1="50" y1="50" x2="56" y2="92" stroke="currentColor" stroke-width="6" stroke-linecap="round"/><circle cx="50" cy="50" r="13"/><circle cx="20" cy="22" r="6"/><circle cx="86" cy="32" r="8"/><circle cx="22" cy="74" r="6"/><circle cx="80" cy="80" r="8"/><circle cx="50" cy="14" r="5"/><circle cx="56" cy="92" r="7"/></svg>\n`,
  );
  const now = NOW();
  const prev = readJson(path.join(profileDir, "profile.json"), {});
  writeJson(path.join(profileDir, "profile.json"), {
    slug,
    name: "Auxevo",
    industry: "AI & Software",
    tags: ["ai", "software", "mittelstand", "dark-first"],
    tone: "Modern, technisch, minimalistisch; Dark-first mit Teal-Akzent.",
    source: "seed",
    origin: { files: [brandingMd, designSystem] },
    created_at: prev.created_at || now,
    updated_at: now,
    active_version: version,
    versions: [...(prev.versions || []), { version, created_at: now, source: "seed" }],
    logo: statusFor(versionDir, "logo"),
    fonts: { status: "manuell", note: "DM Sans / JetBrains Mono; Bunny Fonts oder self-hosted, kein Google-CDN." },
  });
  setCurrentSymlink(profileDir, version);
  regenerateIndex();
  console.log(`✓ Auxevo-Seed importiert: branding/auxevo/${version}`);
}

function usage() {
  console.log(`Nutzung:
  node scripts/brand-lib.mjs seed
  node scripts/brand-lib.mjs save <run-dir> [--slug <slug>] [--as v2]
  node scripts/brand-lib.mjs list`);
}

const [cmd, ...rest] = process.argv.slice(2);
const opts = parseArgs(rest);
if (!cmd || opts.help) {
  usage();
  process.exit(cmd ? 0 : 2);
}
if (cmd === "seed") seedAuxevo();
else if (cmd === "save") {
  const runDir = opts._[0];
  if (!runDir) die("save braucht <run-dir>.");
  saveRun(runDir, opts);
} else if (cmd === "list") {
  const { profiles, migrated } = regenerateIndex();
  if (migrated.length) console.log(`· Migriert: ${migrated.join(", ")}`);
  for (const p of profiles) {
    console.log(`${p.slug}\t${p.active_version}\t${p.source}\t${p.name}`);
  }
  console.log(`✓ Katalog aktualisiert: branding/index.json + branding/index.html (${profiles.length} Profile)`);
} else {
  die(`Unbekannter Befehl: ${cmd}`);
}
