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
