// Shell-Chrome (Vanilla-JS): Varianten-Umschalter + Anker-Scoping.
// Läuft im Client-Bundle VOR den React-Mounts; muss ohne React funktionieren.
// PROJ-8 hängt sich später über window.__SHELL_SET_VARIANT und die
// data-shell-slot-Container ein.

const RUN_ID = document.documentElement.dataset.runId || '';
const STORE_KEY = 'uicheck-mockup:' + RUN_ID + ':variant';

function setVariant(v) {
  if (v !== 'safe' && v !== 'bold') return;
  document.body.dataset.activeVariant = v;
  document.querySelectorAll('[data-variant-tab]').forEach((btn) => {
    btn.setAttribute('aria-pressed', btn.dataset.variantTab === v ? 'true' : 'false');
  });
  try { localStorage.setItem(STORE_KEY, v); } catch { /* file:// ohne Storage */ }
  if (typeof window.__refreshCompare === 'function') window.__refreshCompare();
}

document.querySelectorAll('[data-variant-tab]').forEach((btn) => {
  btn.addEventListener('click', () => setVariant(btn.dataset.variantTab));
});

// Beide Varianten tragen dieselben Sektions-IDs (gemeinsamer Sektionsplan).
// Anker-Klicks werden deshalb auf die AKTIVE Variante gescopet, statt immer
// zur ersten ID im Dokument (= Safe) zu springen.
document.addEventListener('click', (ev) => {
  const a = ev.target && ev.target.closest && ev.target.closest('a[href^="#"]');
  if (!a) return;
  const id = decodeURIComponent(a.getAttribute('href').slice(1));
  if (!id) return;
  const active = document.body.dataset.activeVariant || 'safe';
  const scoped = document.querySelector(
    '.shell-variant[data-variant="' + active + '"] [id="' + (window.CSS ? CSS.escape(id) : id) + '"]'
  );
  if (scoped) {
    ev.preventDefault();
    scoped.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
});

let stored = null;
try { stored = localStorage.getItem(STORE_KEY); } catch { /* s. o. */ }
setVariant(stored === 'bold' ? 'bold' : 'safe');

window.__SHELL_SET_VARIANT = setVariant;

const PROJ8 = window.__MOCKUP_PROJ8 || {};
const ORIGINALS = Array.isArray(PROJ8.original) ? PROJ8.original : [];
const COMPARE = Array.isArray(PROJ8.compare) ? PROJ8.compare : [];
const HAS_BOTH_VARIANTS = PROJ8.variants && PROJ8.variants.safe && PROJ8.variants.bold;
const HAS_ORIGINAL = ORIGINALS.length > 0;

function el(tag, attrs, children) {
  const node = document.createElement(tag);
  Object.entries(attrs || {}).forEach(([k, v]) => {
    if (v === false || v == null) return;
    if (k === 'class') node.className = v;
    else if (k === 'text') node.textContent = v;
    else node.setAttribute(k, String(v));
  });
  (children || []).forEach((child) => node.append(child));
  return node;
}

function activeVariant() {
  return document.body.dataset.activeVariant === 'bold' ? 'bold' : 'safe';
}

function setView(view) {
  if (!HAS_ORIGINAL) return;
  const next = view === 'before-after' || view === 'sections' ? view : 'redesign';
  document.body.dataset.shellView = next;
  document.querySelectorAll('[data-view-tab]').forEach((btn) => {
    btn.setAttribute('aria-pressed', btn.dataset.viewTab === next ? 'true' : 'false');
  });
  document.querySelectorAll('[data-view-panel]').forEach((panel) => {
    panel.hidden = panel.dataset.viewPanel !== next;
  });
  // Skalierungen erst berechnen, wenn das Panel sichtbar ist (in versteckten
  // Panels sind clientWidth/scrollHeight 0). Beide Ansichten neu vermessen.
  requestAnimationFrame(() => {
    const panel = document.querySelector('[data-view-panel="' + next + '"]');
    if (panel && typeof panel.__relayout === 'function') panel.__relayout();
    scaleAll();
  });
}

function currentOriginal() {
  const selected = document.querySelector('[data-viewport-tab][aria-pressed="true"]');
  const wanted = Number(selected && selected.dataset.viewportTab) || 375;
  return ORIGINALS.find((o) => Number(o.viewport) === wanted) || ORIGINALS[0];
}

function renderSlider(panel) {
  const data = currentOriginal();
  if (!data) return;
  const split = panel.querySelector('[data-split]');
  const beforeImg = panel.querySelector('[data-split-before-img]');
  const viewportLabel = panel.querySelector('[data-current-viewport]');
  if (!split || !beforeImg) return;
  // Nachher-Seite an die aktuell gewählte Variante binden (Klon neu aufbauen).
  const after = panel.querySelector('[data-split-after]');
  if (after) {
    const mount = document.querySelector('.shell-variant[data-variant="' + activeVariant() + '"] .shell-variant-mount');
    after.replaceChildren(revealClone(mount ? mount.cloneNode(true) : null) || el('div'));
    after.scrollTop = 0;
    beforeImg.style.transform = 'translateY(0px)';
  }
  setSplitPosition(panel, 50);
  // Vorher = Original-Screenshot als <img> in voller Container-Breite — dieselbe
  // Skalierung wie das Nachher darunter. So wischt der Regler die Ansicht frei,
  // statt das Vorher zu verkleinern.
  beforeImg.src = data.image;
  beforeImg.style.transform = 'translateY(0px)';
  if (viewportLabel) viewportLabel.textContent = data.viewport + ' px';
  panel.querySelectorAll('[data-viewport-tab]').forEach((btn) => {
    btn.setAttribute('aria-pressed', Number(btn.dataset.viewportTab) === Number(data.viewport) ? 'true' : 'false');
  });
}

// Reglerposition (in %) auf Clip-Fläche + Trennlinie anwenden.
function setSplitPosition(panel, pct) {
  const split = panel.querySelector('[data-split]');
  const divider = panel.querySelector('[data-split-divider]');
  if (split) split.style.setProperty('--shell-split', pct + '%');
  if (divider) divider.style.left = pct + '%';
}

// Motion rendert im SSR/Clone die Anfangszustände (opacity:0, translate) als
// Inline-Styles — in statischen Klonen (Vorschau, Vorher/Nachher, Sektionen)
// bliebe der Inhalt dadurch unsichtbar. Für Klone die Motion-Inline-Styles auf
// den sichtbaren Endzustand zurücksetzen. Generisch für jede Variante/Seite.
function revealClone(root) {
  if (!root) return root;
  const fix = (n) => {
    if (!n || !n.style) return;
    if (n.style.opacity !== '') n.style.opacity = '1';
    if (n.style.transform !== '') n.style.transform = 'none';
    if (n.style.visibility === 'hidden') n.style.visibility = 'visible';
    if (n.style.filter && /blur/.test(n.style.filter)) n.style.filter = 'none';
  };
  fix(root);
  if (root.querySelectorAll) root.querySelectorAll('*').forEach(fix);
  return root;
}

// Skaliert eine in Referenzbreite gerenderte Vorschau in ihre Box, sodass die
// ganze Seiten-/Sektionsbreite (Desktop-Layout) sichtbar ist statt nur der obere
// linke Ausschnitt. fitHeight=true ⇒ Box-Höhe folgt dem skalierten Inhalt.
const PREVIEW_DESIGN_WIDTH = 1280;
const scaledItems = [];
function registerScaled(inner, designWidth, fitHeight) {
  inner.style.width = (designWidth || PREVIEW_DESIGN_WIDTH) + 'px';
  scaledItems.push({ inner, designWidth: designWidth || PREVIEW_DESIGN_WIDTH, fitHeight: !!fitHeight });
}
function scaleAll() {
  scaledItems.forEach(({ inner, designWidth, fitHeight }) => {
    const box = inner.parentElement;
    if (!box || !box.clientWidth) return;
    const scale = box.clientWidth / designWidth;
    inner.style.transform = 'scale(' + scale + ')';
    if (fitHeight) box.style.height = Math.ceil(inner.scrollHeight * scale) + 'px';
    else inner.style.height = Math.round(box.clientHeight / scale) + 'px';
  });
}
window.addEventListener('resize', scaleAll);

function buildVoting() {
  if (!HAS_BOTH_VARIANTS) return;
  const slot = document.getElementById('shell-slot-voting');
  if (!slot) return;
  slot.hidden = false;
  slot.className = 'shell-voting';
  const buttons = ['safe', 'bold'].map((variant) => {
    const label = variant === 'safe' ? 'Safe · Facelift' : 'Bold · Neuinterpretation';
    const mount = document.getElementById('mount-' + variant);
    const preview = el('div', { class: 'shell-vote-preview', 'aria-hidden': 'true' });
    const inner = el('div', { class: 'shell-vote-preview-inner' });
    if (mount) { inner.innerHTML = mount.innerHTML; revealClone(inner); }
    preview.append(inner);
    registerScaled(inner, PREVIEW_DESIGN_WIDTH, false);
    const btn = el('button', { type: 'button', class: 'shell-vote-card', 'data-vote-variant': variant }, [
      el('span', { class: 'shell-vote-label', text: label }),
      preview,
    ]);
    btn.addEventListener('click', () => {
      setVariant(variant);
      setView('redesign');
      slot.hidden = true;
    });
    return btn;
  });
  slot.replaceChildren(
    el('div', { class: 'shell-voting-inner' }, [
      el('h1', { text: 'Welche Richtung gefällt Ihnen?' }),
      el('p', { class: 'shell-muted', text: 'Vorschau der Startseite — für die vollständige Ansicht auf eine Variante klicken.' }),
      el('div', { class: 'shell-vote-grid' }, buttons),
    ])
  );
  requestAnimationFrame(scaleAll);
}

function buildCompare() {
  if (!HAS_ORIGINAL) return;
  const viewGroup = document.querySelector('[data-shell-slot="view-group"]');
  const tabsExtra = document.querySelector('[data-shell-slot="tabs-extra"]');
  if (tabsExtra) {
    if (viewGroup) viewGroup.hidden = false;
    tabsExtra.hidden = false;
    tabsExtra.className = 'shell-view-tabs';
    // 'before-after' ist vorerst ausgeblendet (Vorher/Nachher funktioniert noch
    // nicht zuverlässig — TODO wieder aktivieren). Panel wird weiter gebaut.
    [
      ['redesign', 'Redesign'],
      ['sections', 'Sektionsvergleich'],
    ].forEach(([view, label]) => {
      const btn = el('button', { type: 'button', class: 'shell-tab shell-view-tab', 'data-view-tab': view, 'aria-pressed': view === 'redesign' ? 'true' : 'false', text: label });
      btn.addEventListener('click', () => setView(view));
      tabsExtra.append(btn);
    });
  }

  const slot = document.getElementById('shell-slot-compare');
  if (!slot) return;
  slot.hidden = false;
  slot.className = 'shell-compare';

  const viewportTabs = el('div', { class: 'shell-viewport-tabs', 'aria-label': 'Viewport wählen' },
    ORIGINALS.map((o, i) => {
      const btn = el('button', { type: 'button', class: 'shell-tab', 'data-viewport-tab': o.viewport, 'aria-pressed': i === 0 ? 'true' : 'false', text: String(o.viewport) });
      btn.addEventListener('click', () => {
        slot.querySelectorAll('[data-viewport-tab]').forEach((b) => b.setAttribute('aria-pressed', b === btn ? 'true' : 'false'));
        renderSlider(slot);
        buildSections(slot.querySelector('[data-view-panel="sections"]'));
      });
      return btn;
    })
  );

  const splitPanel = el('section', { class: 'shell-panel shell-before-after', 'data-view-panel': 'before-after', hidden: true }, [
    el('div', { class: 'shell-panel-head' }, [
      el('h2', { text: 'Vorher / Nachher' }),
      el('span', { class: 'shell-muted', 'data-current-viewport': '', text: '' }),
    ]),
    viewportTabs,
    el('div', { class: 'shell-split', 'data-split': '' }, [
      el('div', { class: 'shell-split-after', 'data-split-after': '' }, [revealClone(document.querySelector('.shell-variant[data-variant="' + activeVariant() + '"] .shell-variant-mount')?.cloneNode(true)) || el('div')]),
      el('div', { class: 'shell-split-before', 'data-split-before': '' }, [
        el('img', { class: 'shell-split-before-img', 'data-split-before-img': '', alt: 'Original-Screenshot' }),
      ]),
      el('div', { class: 'shell-split-divider', 'data-split-divider': '' }),
      el('input', { class: 'shell-split-range', type: 'range', min: '0', max: '100', value: '50', 'aria-label': 'Vergleichsposition' }),
    ]),
  ]);

  const sectionsPanel = el('section', { class: 'shell-panel shell-sections', 'data-view-panel': 'sections', hidden: true });
  const copyPanel = el('section', { class: 'shell-copybar' }, [
    el('button', { type: 'button', class: 'shell-copy-button', text: 'Antwort kopieren' }),
    el('textarea', { class: 'shell-copy-text', rows: '5', readonly: true }),
  ]);

  slot.replaceChildren(splitPanel, sectionsPanel, copyPanel);
  const range = splitPanel.querySelector('.shell-split-range');
  range.addEventListener('input', () => setSplitPosition(splitPanel, Number(range.value)));
  // Vorher-Bild mit dem scrollbaren Nachher synchronisieren, damit der Wisch
  // über die ganze Seitenhöhe denselben Ausschnitt vergleicht.
  const afterScroll = splitPanel.querySelector('[data-split-after]');
  const beforeImg = splitPanel.querySelector('[data-split-before-img]');
  if (afterScroll && beforeImg) {
    afterScroll.addEventListener('scroll', () => {
      beforeImg.style.transform = 'translateY(' + -afterScroll.scrollTop + 'px)';
    });
  }
  copyPanel.querySelector('button').addEventListener('click', async () => {
    const text = [
      'Rückmeldung zum Redesign-Vorschlag',
      'Domain: ' + (PROJ8.domain || ''),
      'Lauf: ' + (PROJ8.run_id || RUN_ID),
      'Gewählte Richtung: ' + (activeVariant() === 'bold' ? 'Bold · Neuinterpretation' : 'Safe · Facelift'),
      '',
      'Bitte diese Richtung weiter ausarbeiten.',
    ].join('\n');
    const area = copyPanel.querySelector('textarea');
    area.value = text;
    try { await navigator.clipboard.writeText(text); }
    catch { area.focus(); area.select(); }
  });
  // Beide Vergleichsansichten an die aktive Variante binden (auch bei Umschaltung).
  window.__refreshCompare = () => { renderSlider(slot); buildSections(sectionsPanel); };
  renderSlider(slot);
  buildSections(sectionsPanel);
  setView('redesign');
}

const beforeImgCache = {};
// Vorher-Bänder nach den Naturmaßen des Original-Screenshots positionieren, damit
// jede Sektion einen eigenen, nicht abgeschnittenen Ausschnitt zeigt.
function positionBeforeBands(src, boxes) {
  if (!src || !boxes.length) return;
  const apply = (natW, natH) => boxes.forEach(({ box, fy, fh }) => {
    const w = box.clientWidth || 320;
    const displayH = natH * (w / natW);
    box.style.backgroundSize = '100% auto';
    box.style.backgroundRepeat = 'no-repeat';
    box.style.backgroundPositionY = '-' + Math.round((fy || 0) * displayH) + 'px';
    box.style.height = (fh ? Math.min(520, Math.max(140, Math.round(fh * displayH))) : Math.min(520, Math.round(displayH))) + 'px';
  });
  const cached = beforeImgCache[src];
  if (cached) { apply(cached.w, cached.h); return; }
  const img = new Image();
  img.onload = () => { beforeImgCache[src] = { w: img.naturalWidth, h: img.naturalHeight }; apply(img.naturalWidth, img.naturalHeight); };
  img.src = src;
}

// Referenzbreite, in der Nachher-Sektionen gerendert (Desktop) und dann in die
// Spalte skaliert werden. Fix, damit die Berechnung nicht von der (in Vergleichs-
// Ansichten ausgeblendeten) Live-Variante abhängt.
const SECTION_DESIGN_WIDTH = 1280;

function buildSections(panel) {
  if (!panel) return;
  const data = currentOriginal();
  const byId = new Map(COMPARE.map((c) => [c.id, c]));
  // Zeilen bleiben IMMER die Redesign-Sektionen (id trägt Nachher-Klon + Begründung).
  // Die Original-Sektionsgrenzen (capture/sections.json) liefern nur die Vorher-Bänder —
  // per Index zugeordnet und nur, wenn ihre Anzahl mit den Redesign-Sektionen übereinstimmt.
  // Sonst (fehlt/abweichende Anzahl) Fallback auf proportionale Schätzung aus den Klon-Höhen.
  const origBounds = data && Array.isArray(data.sections) ? data.sections : [];
  const useBounds = origBounds.length > 0 && origBounds.length === COMPARE.length;
  const refHeight = useBounds
    ? Math.max(1, ...origBounds.map((s) => (Number(s.y) || 0) + (Number(s.height) || 0)))
    : 0;
  const rows = COMPARE.map((c, i) => ({ id: c.id, label: c.original || c.id || 'Abschnitt ' + (i + 1) }));

  const active = activeVariant();
  const liveOf = (id) => document.querySelector('.shell-variant[data-variant="' + active + '"] [id="' + (window.CSS ? CSS.escape(id) : id) + '"]');

  const items = [];  // { afterInner, before, boundFy, boundFh }

  const listEl = el('div', { class: 'shell-section-list' }, rows.map((s, i) => {
    const cmp = byId.get(s.id) || {};
    const live = liveOf(s.id);
    const ob = useBounds ? origBounds[i] : null;

    // Nachher: ganze Sektion in fixer Desktop-Breite geklont, später skaliert.
    const afterInner = el('div', { class: 'shell-section-after-inner' });
    let hasAfter = false;
    if (live) { afterInner.innerHTML = live.outerHTML; revealClone(afterInner); afterInner.style.width = SECTION_DESIGN_WIDTH + 'px'; hasAfter = true; }
    else afterInner.append(el('p', { class: 'shell-muted', text: 'Diese Sektion ist in der aktiven Variante nicht vorhanden.' }));
    const after = el('div', { class: 'shell-section-after' }, [afterInner]);

    const before = el('div', { class: 'shell-section-before' });
    if (data && data.image) before.style.backgroundImage = 'url("' + data.image + '")';
    else before.append(el('p', { class: 'shell-muted', text: 'Kein Original-Screenshot verfügbar.' }));

    items.push({
      afterInner: hasAfter ? afterInner : null,
      before: (data && data.image) ? before : null,
      boundFy: ob && refHeight ? Math.max(0, Number(ob.y) || 0) / refHeight : null,
      boundFh: ob && refHeight ? Math.max(1, Number(ob.height) || 0) / refHeight : null,
    });

    return el('article', { class: 'shell-section-row' }, [
      el('h3', { text: cmp.original || s.label || s.id }),
      el('div', { class: 'shell-section-pair' }, [
        el('figure', { class: 'shell-section-col' }, [el('figcaption', { class: 'shell-section-tag', text: 'Vorher' }), before]),
        el('figure', { class: 'shell-section-col' }, [el('figcaption', { class: 'shell-section-tag', text: 'Nachher' }), after]),
      ]),
      el('p', { class: 'shell-section-reason', text: cmp.change || 'Begründung folgt im Redesign-Brief.' }),
    ]);
  }));

  panel.replaceChildren(el('div', { class: 'shell-panel-head' }, [el('h2', { text: 'Sektionsvergleich' })]), listEl);

  // Layout wird berechnet, sobald das Panel sichtbar ist (setView ruft __relayout).
  panel.__relayout = () => layoutSections(items, data && data.image);
  requestAnimationFrame(panel.__relayout);
}

// Nachher skalieren + Vorher-Bänder setzen — aus den Klon-Maßen (keine Abhängigkeit
// von der ausgeblendeten Live-Variante). Fehlen Sektionsgrenzen, werden die Bänder
// proportional aus den Nachher-Sektionshöhen geschätzt.
function layoutSections(items, image) {
  const measurable = items.filter((it) => it.afterInner && it.afterInner.parentElement && it.afterInner.parentElement.clientWidth);
  if (!measurable.length) return;  // Panel noch versteckt — später erneut.

  const heights = items.map((it) => (it.afterInner ? it.afterInner.scrollHeight : 0));
  const total = heights.reduce((a, b) => a + b, 0) || 1;
  let acc = 0;
  const derived = heights.map((h) => { const fy = acc / total; acc += h; return { fy, fh: h / total }; });

  items.forEach((it, i) => {
    if (it.afterInner) {
      const box = it.afterInner.parentElement;
      const scale = box.clientWidth / SECTION_DESIGN_WIDTH;
      it.afterInner.style.transform = 'scale(' + scale + ')';
      box.style.height = Math.ceil(it.afterInner.scrollHeight * scale) + 'px';
    }
  });

  const boxes = items
    .map((it, i) => it.before ? { box: it.before, fy: it.boundFy != null ? it.boundFy : derived[i].fy, fh: it.boundFh != null ? it.boundFh : derived[i].fh } : null)
    .filter(Boolean);
  positionBeforeBands(image, boxes);
}

buildVoting();
buildCompare();
