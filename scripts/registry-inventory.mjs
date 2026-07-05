#!/usr/bin/env node
/*
 * registry-inventory.mjs — Registry-Browser (PROJ-11).
 * Liest registry/registry.json + VERSION und erzeugt:
 *   registry/INVENTORY.md   — gruppiertes Markdown-Inventar
 *   registry/inventory.html  — statische, durchsuchbare/filterbare Galerie (kein Build, kein CDN)
 * Nutzung: node scripts/registry-inventory.mjs
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const REG = path.join(ROOT, "registry");
const registry = JSON.parse(fs.readFileSync(path.join(REG, "registry.json"), "utf8"));
const VERSION = fs.readFileSync(path.join(REG, "VERSION"), "utf8").trim();

const items = registry.items || [];
const blocks = items.filter((it) => it.type === "registry:block" && it.meta?.kind !== "template" && it.meta?.section);
const templates = items.filter((it) => it.meta?.kind === "template");
const has = (p) => fs.existsSync(path.join(REG, p));

// Template-Kompositionen (aus templates/<slug>/template.json), falls vorhanden.
function templateComposition(t) {
  const slug = t.meta?.branding || t.name.replace(/-template$/, "");
  const tj = has(`templates/${slug}/template.json`) ? JSON.parse(fs.readFileSync(path.join(REG, `templates/${slug}/template.json`), "utf8")) : null;
  const preview = has(`templates/${slug}/preview/dist/index.html`) ? `templates/${slug}/preview/dist/index.html` : null;
  return { slug, sections: tj?.sections || [], branding: t.meta?.branding || slug, preview };
}

const bySection = {};
for (const b of blocks) (bySection[b.meta.section] ||= []).push(b);
const sourcesOf = [...new Set(blocks.map((b) => b.meta.source).filter(Boolean))];

// ── Markdown ──────────────────────────────────────────────────────────────────
const md = [];
md.push(`# Registry-Inventar\n`);
md.push(`> Auto-generiert von \`scripts/registry-inventory.mjs\` — **nicht von Hand editieren**. Registry-Version **${VERSION}**.\n`);
md.push(`**${blocks.length} Blocks** · **${templates.length} Templates** · **${Object.keys(bySection).length} Sektionstypen** · Quellen: ${sourcesOf.map((s) => `\`${s}\``).join(", ")}\n`);

md.push(`## Templates\n`);
for (const t of templates) {
  const c = templateComposition(t);
  md.push(`### ${t.title || t.name}`);
  md.push(`- Branding: \`${c.branding}\` · Stil: \`${t.meta?.style || "-"}\` · Branchen: ${(t.meta?.industry || []).map((x) => `\`${x}\``).join(", ") || "-"}`);
  if (c.preview) md.push(`- Preview: \`registry/${c.preview}\``);
  if (c.sections.length) md.push(`- Sektionen: ${c.sections.map((s) => `\`${s.block || s.id}\``).join(" → ")}`);
  md.push("");
}

md.push(`## Blocks nach Sektionstyp\n`);
for (const sec of Object.keys(bySection).sort()) {
  md.push(`### \`${sec}\` (${bySection[sec].length})`);
  md.push(`| Block | Titel | Stil | Branchen | Quelle | Slots | interaktiv |`);
  md.push(`|---|---|---|---|---|---|---|`);
  for (const b of bySection[sec].sort((a, z) => a.name.localeCompare(z.name))) {
    const slots = (b.meta.image_slots || []).length;
    md.push(`| \`${b.name}\` | ${b.title || "-"} | ${b.meta.style || "-"} | ${(b.meta.industry || []).join(", ") || "-"} | ${b.meta.source || "-"} | ${slots} | ${b.meta.interactive ? "✓" : ""} |`);
  }
  md.push("");
}
md.push(`---\n_Neu generieren: \`node scripts/registry-inventory.mjs\`. Browser: \`registry/inventory.html\`._`);
fs.writeFileSync(path.join(REG, "INVENTORY.md"), md.join("\n") + "\n");

// ── HTML (statisch, self-contained, kein CDN) ─────────────────────────────────
const data = {
  version: VERSION,
  blocks: blocks.map((b) => ({ name: b.name, title: b.title || b.name, desc: b.description || "", section: b.meta.section, style: b.meta.style || "", industry: b.meta.industry || [], source: b.meta.source || "", slots: (b.meta.image_slots || []).length, interactive: !!b.meta.interactive, file: b.files?.[0]?.path || "" })),
  templates: templates.map((t) => { const c = templateComposition(t); return { name: t.name, title: t.title || t.name, branding: c.branding, style: t.meta?.style || "", industry: t.meta?.industry || [], sections: c.sections.map((s) => s.block || s.id), preview: c.preview }; }),
};
const html = `<!doctype html><html lang="de"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>UI-Check Registry — Inventar ${VERSION}</title>
<style>
 :root{--bg:#0b0b0c;--card:#151517;--line:#26262a;--ink:#f4f4f5;--muted:#a1a1aa;--accent:#c87f2c}
 *{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 ui-sans-serif,system-ui,sans-serif}
 header{padding:28px 24px 12px;position:sticky;top:0;background:linear-gradient(var(--bg),var(--bg) 70%,transparent)}
 h1{margin:0 0 4px;font-size:22px} .sub{color:var(--muted);font-size:13px}
 .controls{display:flex;flex-wrap:wrap;gap:8px;margin-top:14px}
 input,select{background:var(--card);color:var(--ink);border:1px solid var(--line);border-radius:8px;padding:8px 10px;font:inherit}
 input{flex:1;min-width:200px}
 main{padding:8px 24px 60px} h2{font-size:13px;text-transform:uppercase;letter-spacing:.1em;color:var(--muted);margin:26px 0 10px}
 .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:12px}
 .card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px}
 .card h3{margin:0 0 2px;font-size:15px} .card .name{font-family:ui-monospace,monospace;font-size:12px;color:var(--accent)}
 .card p{margin:8px 0 10px;color:var(--muted);font-size:13px}
 .tags{display:flex;flex-wrap:wrap;gap:6px} .tag{font-size:11px;border:1px solid var(--line);border-radius:999px;padding:2px 8px;color:var(--muted)}
 .tag.sec{color:var(--ink)} .tag.style{border-color:var(--accent);color:var(--accent)}
 a{color:var(--accent)} .count{color:var(--muted);font-weight:400}
 .hidden{display:none}
</style></head><body>
<header>
 <h1>UI-Check Registry <span class="count">· v${VERSION}</span></h1>
 <div class="sub">${data.blocks.length} Blocks · ${data.templates.length} Templates. Token-agnostisch — Look kommt aus dem Branding-Profil.</div>
 <div class="controls">
  <input id="q" placeholder="Suche (Name, Titel, Beschreibung, Branche) …"/>
  <select id="fsec"><option value="">alle Sektionen</option></select>
  <select id="fstyle"><option value="">alle Stile</option></select>
  <select id="fsrc"><option value="">alle Quellen</option></select>
 </div>
</header>
<main>
 <section id="templates"><h2>Templates</h2><div class="grid" id="tgrid"></div></section>
 <section><h2>Blocks <span class="count" id="bcount"></span></h2><div class="grid" id="bgrid"></div></section>
</main>
<script>
const DATA=${JSON.stringify(data)};
const el=(t,c,h)=>{const e=document.createElement(t);if(c)e.className=c;if(h!=null)e.innerHTML=h;return e};
const uniq=a=>[...new Set(a)].sort();
for(const s of uniq(DATA.blocks.map(b=>b.section))) fsec.append(new Option(s,s));
for(const s of uniq(DATA.blocks.map(b=>b.style).filter(Boolean))) fstyle.append(new Option(s,s));
for(const s of uniq(DATA.blocks.map(b=>b.source).filter(Boolean))) fsrc.append(new Option(s,s));
function tagRow(b){return '<div class="tags"><span class="tag sec">'+b.section+'</span>'+(b.style?'<span class="tag style">'+b.style+'</span>':'')+
 b.industry.map(i=>'<span class="tag">'+i+'</span>').join('')+
 (b.slots?'<span class="tag">'+b.slots+' Slots</span>':'')+(b.interactive?'<span class="tag">interaktiv</span>':'')+'</div>';}
function renderTemplates(){tgrid.innerHTML='';for(const t of DATA.templates){const c=el('div','card');
 c.innerHTML='<h3>'+t.title+'</h3><div class="name">'+t.name+'</div>'+
  '<p>'+t.sections.length+' Sektionen: '+t.sections.map(s=>'<code>'+s+'</code>').join(' → ')+'</p>'+
  '<div class="tags"><span class="tag sec">'+t.branding+'</span>'+(t.style?'<span class="tag style">'+t.style+'</span>':'')+t.industry.map(i=>'<span class="tag">'+i+'</span>').join('')+'</div>'+
  (t.preview?'<p><a href="'+t.preview+'">Preview öffnen ↗</a></p>':'');
 tgrid.append(c);}}
function renderBlocks(){const q=qInput.value.toLowerCase(),fs=fsec.value,st=fstyle.value,sr=fsrc.value;
 bgrid.innerHTML='';let n=0;
 for(const b of DATA.blocks){
  const hay=(b.name+' '+b.title+' '+b.desc+' '+b.industry.join(' ')+' '+b.source).toLowerCase();
  if(q&&!hay.includes(q))continue; if(fs&&b.section!==fs)continue; if(st&&b.style!==st)continue; if(sr&&b.source!==sr)continue;
  n++;const c=el('div','card');
  c.innerHTML='<h3>'+b.title+'</h3><div class="name">'+b.name+'</div><p>'+(b.desc||'')+'</p>'+tagRow(b);
  bgrid.append(c);}
 bcount.textContent='('+n+')';}
const qInput=document.getElementById('q');
[qInput,fsec,fstyle,fsrc].forEach(e=>e.addEventListener('input',renderBlocks));
renderTemplates();renderBlocks();
</script></body></html>`;
fs.writeFileSync(path.join(REG, "inventory.html"), html);

console.log(`✓ Inventar: ${blocks.length} Blocks, ${templates.length} Templates → registry/INVENTORY.md + registry/inventory.html (v${VERSION})`);
