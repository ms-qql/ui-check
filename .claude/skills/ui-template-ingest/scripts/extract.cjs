#!/usr/bin/env node
/*
 * ui-template-ingest — Extraktion.
 * Nutzung: node extract.cjs <url> <outdir> [width=1440]
 * Schreibt: <outdir>/content.json, tokens.json, full.png, sec-00-*.png …
 * Playwright global (require-Pfad ggf. an die installierte Node-Version anpassen).
 */
const fs = require("fs");
const path = require("path");
const PW = process.env.PW_PATH || "/home/dev/.nvm/versions/node/v24.17.0/lib/node_modules/playwright";
const { chromium } = require(PW);

const url = process.argv[2];
const outdir = process.argv[3] || ".";
const width = parseInt(process.argv[4] || "1440", 10);
if (!url) { console.error("usage: node extract.cjs <url> <outdir> [width]"); process.exit(1); }
fs.mkdirSync(outdir, { recursive: true });

(async () => {
  const b = await chromium.launch({ headless: true });
  const p = await b.newPage({ viewport: { width, height: 1000 } });
  await p.goto(url, { waitUntil: "networkidle", timeout: 60000 });
  // Scroll-Durchlauf für Lazy-/Reveal-Inhalte
  const h = await p.evaluate(() => document.body.scrollHeight);
  for (let y = 0; y < h + 1000; y += 700) { await p.evaluate((_y) => window.scrollTo(0, _y), y); await p.waitForTimeout(150); }
  await p.evaluate(() => window.scrollTo(0, 0));
  await p.waitForTimeout(1000);

  await p.screenshot({ path: path.join(outdir, "full.png"), fullPage: true });

  // Design-Tokens aus computed styles + :root
  const tokens = await p.evaluate(() => {
    const top = (o) => Object.entries(o).sort((a, b) => b[1] - a[1]).slice(0, 12).map(([k, v]) => `${k} (${v})`);
    const fonts = new Set(), colors = {}, bgs = {};
    document.querySelectorAll("*").forEach((el) => {
      const s = getComputedStyle(el);
      if (s.fontFamily) fonts.add(s.fontFamily);
      if (el.textContent && el.textContent.trim()) colors[s.color] = (colors[s.color] || 0) + 1;
      const bg = s.backgroundColor; if (bg && bg !== "rgba(0, 0, 0, 0)") bgs[bg] = (bgs[bg] || 0) + 1;
    });
    const vars = {};
    for (const sheet of document.styleSheets) { try { for (const r of sheet.cssRules) {
      if (r.selectorText === ":root" || r.selectorText === "html") for (const prop of r.style) if (prop.startsWith("--")) vars[prop] = r.style.getPropertyValue(prop).trim();
    } } catch (e) {} }
    return { bodyFont: getComputedStyle(document.body).fontFamily, fonts: [...fonts], topColors: top(colors), topBgs: top(bgs), cssVars: vars,
      fontLinks: [...document.querySelectorAll('link[href*="font"]')].map((l) => l.href) };
  });
  fs.writeFileSync(path.join(outdir, "tokens.json"), JSON.stringify(tokens, null, 2));

  // Strukturierter Content je Sektion
  const content = await p.evaluate(() => {
    const clean = (t) => (t || "").replace(/\s+/g, " ").trim();
    const secs = [...document.querySelectorAll("body section, body > header, body > footer, body > nav")];
    const sections = secs.map((s, i) => ({
      i, tag: s.tagName, className: (s.className || "").toString().slice(0, 140),
      headings: [...s.querySelectorAll("h1,h2,h3,h4")].map((x) => ({ tag: x.tagName, t: clean(x.textContent) })).filter((x) => x.t),
      paras: [...s.querySelectorAll("p")].map((x) => clean(x.textContent)).filter(Boolean).slice(0, 24),
      buttons: [...new Set([...s.querySelectorAll('button, a[role="button"], [class*="btn"]')].map((x) => clean(x.textContent)).filter(Boolean))].slice(0, 24),
      links: [...new Set([...s.querySelectorAll("a")].map((x) => clean(x.textContent)).filter(Boolean))].slice(0, 30),
      lis: [...s.querySelectorAll("li")].map((x) => clean(x.textContent)).filter(Boolean).slice(0, 40),
      images: [...s.querySelectorAll("img")].map((x) => ({ src: x.currentSrc || x.src, alt: x.alt })),
    }));
    const allImgs = [...new Set([...document.querySelectorAll("img")].map((x) => x.currentSrc || x.src))];
    const bgImgs = [...new Set([...document.querySelectorAll("*")].map((el) => getComputedStyle(el).backgroundImage).filter((v) => v && v.includes("url(")))].slice(0, 40);
    return { url: location.href, sectionCount: secs.length, sections, allImgs, bgImgs };
  });
  fs.writeFileSync(path.join(outdir, "content.json"), JSON.stringify(content, null, 2));

  // Per-Sektion-Screenshots
  const handles = await p.$$("body section, body > footer");
  for (let i = 0; i < handles.length; i++) {
    try { await handles[i].scrollIntoViewIfNeeded(); await p.waitForTimeout(250);
      await handles[i].screenshot({ path: path.join(outdir, `sec-${String(i).padStart(2, "0")}.png`) });
    } catch (e) { /* zu groß/versteckt — überspringen */ }
  }
  console.log(`✓ ${content.sectionCount} Sektionen, ${content.allImgs.length} Bilder → ${outdir}`);
  await b.close();
})();
