/*
 * brand-extract.js — deterministischer Token-Extraktor (PROJ-3)
 *
 * Läuft via `agent-browser eval --stdin --json` im Kontext der bereits geöffneten,
 * gerenderten Seite. Liest ausschließlich computed styles (kein Zugriff auf
 * Quelldateien / CSS-in-JS-Klassennamen) und liefert EIN JSON-Objekt zurück:
 *
 *   { colors, fonts, radius, spacing, shadows, contrast_violations,
 *     copy_sample, logo_candidates, dark_mode_hint, stats }
 *
 * Alles hier ist reproduzierbar (keine Zufälligkeit, keine Netzwerkaufrufe).
 * Rollen-Vermutung ist ein deterministischer Heuristik-Schritt und als solcher
 * markiert (role_method: "heuristic"); die eigentliche LLM-Verfeinerung +
 * Tonalität passiert später in der Orchestrierung (PROJ-5).
 */
(() => {
  // ── Farb-Helfer ──────────────────────────────────────────────────────────
  const clamp255 = (x) => Math.max(0, Math.min(255, Math.round(x)));
  const parseColor = (str) => {
    if (!str) return null;
    str = str.trim();
    if (str === "transparent" || str === "none") return null;
    const m = str.match(/rgba?\(([^)]+)\)/i);
    if (!m) return null; // computed styles liefern immer rgb()/rgba()
    const p = m[1].split(",").map((s) => parseFloat(s.trim()));
    const [r, g, b] = p;
    const a = p.length > 3 ? p[3] : 1;
    if (a === 0) return null; // voll transparent → ignorieren
    return { r, g, b, a };
  };
  const toHex = ({ r, g, b }) =>
    "#" + [r, g, b].map((x) => clamp255(x).toString(16).padStart(2, "0")).join("");
  const hexToRgb = (hex) => ({
    r: parseInt(hex.slice(1, 3), 16),
    g: parseInt(hex.slice(3, 5), 16),
    b: parseInt(hex.slice(5, 7), 16),
  });
  const hsl = ({ r, g, b }) => {
    r /= 255; g /= 255; b /= 255;
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
    let h, s, l = (mx + mn) / 2;
    if (mx === mn) { h = 0; s = 0; }
    else {
      const d = mx - mn;
      s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
      switch (mx) {
        case r: h = (g - b) / d + (g < b ? 6 : 0); break;
        case g: h = (b - r) / d + 2; break;
        default: h = (r - g) / d + 4;
      }
      h /= 6;
    }
    return { h: Math.round(h * 360), s, l };
  };
  const relLum = ({ r, g, b }) => {
    const f = (c) => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
  };
  const contrast = (c1, c2) => {
    const a = Math.max(relLum(c1), relLum(c2)), b = Math.min(relLum(c1), relLum(c2));
    return (a + 0.05) / (b + 0.05);
  };
  const rgbDist = (a, b) =>
    Math.sqrt((a.r - b.r) ** 2 + (a.g - b.g) ** 2 + (a.b - b.b) ** 2);
  const px = (v) => { const n = parseFloat(v); return isNaN(n) ? null : Math.round(n); };

  // Effektiver Hintergrund: erste nicht-transparente bg-Farbe der Ahnenkette.
  const effBg = (el) => {
    let e = el;
    while (e && e !== document.documentElement) {
      const c = parseColor(getComputedStyle(e).backgroundColor);
      if (c && c.a >= 0.5) return c;
      e = e.parentElement;
    }
    return (
      parseColor(getComputedStyle(document.body).backgroundColor) ||
      parseColor(getComputedStyle(document.documentElement).backgroundColor) ||
      { r: 255, g: 255, b: 255, a: 1 }
    );
  };

  // ── Sichtbare Elemente sammeln (mit Deckel für Performance) ───────────────
  const all = [...document.querySelectorAll("body *")].filter((e) => {
    const s = getComputedStyle(e);
    if (s.display === "none" || s.visibility === "hidden" || parseFloat(s.opacity) === 0) return false;
    const r = e.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  });
  const CAP = 5000;
  const els = all.length > CAP ? all.filter((_, i) => i % Math.ceil(all.length / CAP) === 0) : all;

  // ── Aggregation ───────────────────────────────────────────────────────────
  const colorMap = new Map(); // hex -> {count, area, ctx:{}}
  const bump = (col, area, ctx) => {
    if (!col) return;
    const hex = toHex(col);
    let o = colorMap.get(hex);
    if (!o) { o = { count: 0, area: 0, ctx: {} }; colorMap.set(hex, o); }
    o.count++; o.area += area; o.ctx[ctx] = (o.ctx[ctx] || 0) + 1;
  };
  const fontMap = new Map();   // family -> {count, maxSize, tags:{}}
  const radiusMap = new Map(); // px -> count
  const spaceMap = new Map();  // px -> count
  const shadowMap = new Map(); // css -> count
  const violations = [];       // WCAG-AA-Textkontrast

  // Kanonischer Seitenhintergrund zuerst erfassen: der Body-Default ist oft
  // transparent (→ weiß) und würde sonst nie als Surface-Token auftauchen.
  bump(effBg(document.body), 200000, "background");

  for (const el of els) {
    const s = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    const area = Math.round(r.width * r.height);
    const tag = el.tagName.toLowerCase();

    // Hintergrundfarbe
    bump(parseColor(s.backgroundColor), area, "background");

    // Rahmenfarbe (nur wenn sichtbarer Rahmen)
    if (px(s.borderTopWidth) > 0) bump(parseColor(s.borderTopColor), Math.round(area * 0.1), "border");

    // Direkter Textinhalt?
    const directText = [...el.childNodes].some(
      (n) => n.nodeType === 3 && n.textContent.trim().length > 0,
    );
    if (directText) {
      const fg = parseColor(s.color);
      bump(fg, area, "text");

      // Fonts
      const fam = (s.fontFamily || "").split(",")[0].replace(/["']/g, "").trim();
      if (fam) {
        let f = fontMap.get(fam) || { count: 0, maxSize: 0, tags: {} };
        f.count++;
        const fsz = parseFloat(s.fontSize) || 16;
        if (fsz > f.maxSize) f.maxSize = fsz;
        f.tags[tag] = (f.tags[tag] || 0) + 1;
        fontMap.set(fam, f);
      }

      // WCAG-AA-Kontrast (nur echte, gut sichtbare Textknoten)
      if (fg && area > 100) {
        const eb = effBg(el);
        const cr = contrast(fg, eb);
        const fsz = parseFloat(s.fontSize) || 16;
        const bold = (parseInt(s.fontWeight) || 400) >= 700;
        const large = fsz >= 24 || (bold && fsz >= 18.66);
        const req = large ? 3.0 : 4.5;
        if (cr < req) {
          violations.push({
            fg: toHex(fg),
            bg: toHex(eb),
            ratio: Math.round(cr * 100) / 100,
            required: req,
            font_px: Math.round(fsz),
            large,
            sample: (el.textContent || "").trim().replace(/\s+/g, " ").slice(0, 60),
          });
        }
      }
    }

    // Radius / Spacing / Shadow
    const rad = px(s.borderTopLeftRadius);
    if (rad && rad > 0) radiusMap.set(rad, (radiusMap.get(rad) || 0) + 1);
    for (const p of ["paddingTop", "paddingLeft", "marginTop"]) {
      const v = px(s[p]);
      if (v && v > 0) spaceMap.set(v, (spaceMap.get(v) || 0) + 1);
    }
    if (s.boxShadow && s.boxShadow !== "none") {
      shadowMap.set(s.boxShadow, (shadowMap.get(s.boxShadow) || 0) + 1);
    }
  }

  // ── Farben clustern (nahe RGB-Nachbarn zusammenfassen) ────────────────────
  let raw = [...colorMap.entries()]
    .map(([hex, o]) => ({ hex, rgb: hexToRgb(hex), ...o }))
    .sort((a, b) => b.count - a.count);

  const merged = [];
  for (const c of raw) {
    const near = merged.find((m) => rgbDist(m.rgb, c.rgb) < 12);
    if (near) {
      near.count += c.count;
      near.area += c.area;
      for (const k in c.ctx) near.ctx[k] = (near.ctx[k] || 0) + c.ctx[k];
    } else {
      merged.push({ ...c });
    }
  }
  merged.sort((a, b) => b.count - a.count);

  const colors = merged.map((c) => {
    const { h, s, l } = hsl(c.rgb);
    return {
      hex: c.hex,
      count: c.count,
      area: c.area,
      contexts: c.ctx,
      h, s: Math.round(s * 100) / 100, l: Math.round(l * 100) / 100,
      neutral: s < 0.12,
    };
  });

  // ── Rollen-Heuristik (deterministisch, markiert) ──────────────────────────
  // Polarität am tatsächlichen Seitenhintergrund ausrichten: auf dunklen Seiten
  // (Dark-Mode-Default) ist Text hell und Surface dunkel — sonst umgekehrt.
  const pageBg = effBg(document.body);
  const darkMode = relLum(pageBg) < 0.2;
  const roles = { dark_mode: darkMode };

  // text: häufigste Textfarbe der zum Hintergrund passenden Polarität
  const byText = colors
    .filter((c) => c.contexts.text)
    .sort((a, b) => (b.contexts.text || 0) - (a.contexts.text || 0));
  const textPref = darkMode ? byText.filter((c) => c.l > 0.5) : byText.filter((c) => c.l < 0.6);
  const textPick = textPref[0] || byText[0];
  if (textPick) roles.text = textPick.hex;

  // surface: großflächigste (neutrale) Hintergrundfarbe passender Polarität
  const byBg = colors
    .filter((c) => c.contexts.background)
    .sort((a, b) => b.area - a.area);
  const surfPref = darkMode
    ? byBg.filter((c) => c.neutral && c.l < 0.4)
    : byBg.filter((c) => c.neutral && c.l > 0.6);
  const surfPick = surfPref[0] || byBg.filter((c) => c.neutral)[0] || byBg[0];
  if (surfPick) roles.surface = surfPick.hex;

  // primary/accent: häufigste gesättigte (nicht-neutrale) Farben (polaritätsunabhängig)
  const brand = colors
    .filter((c) => !c.neutral && c.s >= 0.15 && c.l > 0.12 && c.l < 0.92)
    .sort((a, b) => b.count - a.count);
  if (brand[0]) roles.primary = brand[0].hex;
  const accent = brand.find((c) => c.hex !== roles.primary && Math.abs(c.h - (brand[0]?.h ?? 0)) > 20);
  if (accent) roles.accent = accent.hex;

  // ── Fonts finalisieren + Display/Text-Rolle ──────────────────────────────
  let fonts = [...fontMap.entries()]
    .map(([family, o]) => ({
      family,
      usage_count: o.count,
      max_px: Math.round(o.maxSize),
      found_in: Object.keys(o.tags).sort((a, b) => o.tags[b] - o.tags[a]).slice(0, 6),
    }))
    .sort((a, b) => b.usage_count - a.usage_count);

  if (fonts.length) {
    const byText = [...fonts].sort((a, b) => b.usage_count - a.usage_count)[0];
    const byDisplay = [...fonts].sort((a, b) => b.max_px - a.max_px)[0];
    fonts = fonts.map((f) => ({
      ...f,
      role:
        f.family === byDisplay.family && byDisplay.family !== byText.family
          ? "display"
          : f.family === byText.family
          ? "text"
          : "other",
    }));
    // Ein-Font-System: Display == Text → beide markieren
    if (byDisplay.family === byText.family) {
      const f = fonts.find((x) => x.family === byText.family);
      if (f) f.role = "display+text";
    }
  }

  // ── Copy-Sample (für spätere LLM-Tonalität) ───────────────────────────────
  const grab = (sel, n) =>
    [...document.querySelectorAll(sel)]
      .map((e) => (e.textContent || "").trim().replace(/\s+/g, " "))
      .filter((t) => t.length > 0)
      .slice(0, n);
  const copy_sample = [
    document.title || "",
    ...grab("h1", 2),
    ...grab("h2", 4),
    ...grab("p", 6),
    ...grab("button, a.btn, .button", 6),
  ]
    .filter(Boolean)
    .join(" • ")
    .slice(0, 1500);

  // ── Logo-Kandidaten ───────────────────────────────────────────────────────
  const abs = (u) => { try { return u ? new URL(u, location.href).href : null; } catch (e) { return null; } };
  const logo_candidates = [];
  const seen = new Set();
  const addImg = (el, kind, score) => {
    const src = abs(el.getAttribute("src") || el.getAttribute("href") || el.getAttribute("content"));
    if (!src || seen.has(src)) return;
    seen.add(src);
    const r = el.getBoundingClientRect ? el.getBoundingClientRect() : { width: 0, height: 0 };
    logo_candidates.push({
      kind, src, score,
      alt: el.getAttribute && (el.getAttribute("alt") || ""),
      w: Math.round(r.width), h: Math.round(r.height),
    });
  };
  document
    .querySelectorAll('header img, nav img, a[href="/"] img, [class*="logo" i] img, img[class*="logo" i], img[alt*="logo" i], img[id*="logo" i]')
    .forEach((el) => addImg(el, "img", 100));
  // Inline-SVG im Header/Logo-Container
  const svg = document.querySelector('header svg, nav svg, [class*="logo" i] svg, a[href="/"] svg');
  if (svg) {
    const r = svg.getBoundingClientRect();
    logo_candidates.push({
      kind: "svg-inline", score: 90, svg_markup: svg.outerHTML.slice(0, 20000),
      w: Math.round(r.width), h: Math.round(r.height),
    });
  }
  document
    .querySelectorAll('link[rel="apple-touch-icon"], link[rel~="icon"]')
    .forEach((el) => addImg(el, "icon", 40));
  const ogImg = document.querySelector('meta[property="og:image"]');
  if (ogImg) addImg(ogImg, "og", 30);
  logo_candidates.sort((a, b) => b.score - a.score || (b.w * b.h) - (a.w * a.h));

  // ── Dark-Mode-Hinweis (gleiche Grundlage wie die Rollen-Polarität) ────────
  const dark_mode_hint = darkMode;

  // ── Top-N-Reduktion für kompakte Ausgabe ──────────────────────────────────
  const topN = (map, n) =>
    [...map.entries()].sort((a, b) => b[1] - a[1]).slice(0, n).map(([value, count]) => ({ value, count }));

  return {
    colors: colors.slice(0, 24),
    roles: { ...roles, method: "heuristic" },
    fonts,
    radius: topN(radiusMap, 8),
    spacing: topN(spaceMap, 12),
    shadows: topN(shadowMap, 6).map((s) => ({ value: String(s.value).slice(0, 200), count: s.count })),
    contrast_violations: violations
      .filter((v, i, a) => a.findIndex((x) => x.fg === v.fg && x.bg === v.bg) === i)
      .sort((a, b) => a.ratio - b.ratio)
      .slice(0, 12),
    copy_sample,
    logo_candidates: logo_candidates.slice(0, 6),
    dark_mode_hint,
    stats: { elements_scanned: els.length, elements_total: all.length, colors_raw: raw.length },
  };
})();
