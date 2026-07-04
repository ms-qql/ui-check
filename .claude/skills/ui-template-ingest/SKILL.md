---
name: ui-template-ingest
description: Nimmt ein externes Template bzw. einzelne Komponenten (z. B. von shadcnblocks) in die UI-Check-Komponenten-Registry (PROJ-11) auf — extrahiert die Seite, baut sie clean-room nach, überführt die Sektionen token-agnostisch in registry/blocks/, legt ein Branding-Profil an und verifiziert per Build. Nutze diesen Skill, wenn der Nutzer "ui-template-ingest <url>", "nimm dieses template in die registry auf", "shadcnblocks template <url> übernehmen", "neue komponente aus <url> in die registry", "template extrahieren und aufnehmen" oder Ähnliches will.
---

# ui-template-ingest

Überführt ein externes Template/Komponenten-Set in die lokale **Registry** (`registry/`, PROJ-11) nach demselben Verfahren wie das erste Profil `verdict`. Ergebnis: token-agnostische React-19/Tailwind-4-Blocks + ein Branding-Profil (`branding/<slug>/`) + Registry-Einträge, buildfähig und pipeline-konform.

## Grundregeln (verbindlich)

- **Clean-Room, keine Raubkopie:** Kommerzielle Templates (shadcnblocks u. a.) NICHT als kompilierten Code/Assets liften. Nur **Struktur/Layout/Look** mit freien shadcn/ui-Primitives nachbauen. Im `branding.md` und `registry.json.meta.source` die Herkunft + „clean-room" vermerken.
- **Keine Fotos speichern:** Bilder werden zu `data-image-slot`-Platzhaltern (`Slot` aus `registry/lib/ui.jsx`). `ui-images-fill` (PROJ-20) füllt sie später. Fonts dürfen gespeichert werden (self-hosted, OFL/DSGVO — **nie** Google-CDN).
- **Keine Kundendaten:** Copy in `content.json` generalisieren (Platzhalter), keine echten Namen/Logos.
- **Token-agnostisch:** Blocks nutzen NUR die semantischen Tokens (`paper, ink, ink-soft, muted, surface, line, accent, accent-soft, sand` + `radius`, `font-sans/mono`). Keine Tailwind-Default-Palette, kein Roh-Hex. Farben kommen aus dem Branding-Profil.
- **Contracts:** Jede Block-Wurzel `id={id}` (`^[a-z0-9-]+$`); Signatur `export default function Block({ data }) {}`; Deps nur aus der PROJ-6-Whitelist; kein `next/*`.

## Ablauf

### 1. Extraktion (deterministisch)
Playwright-CLI (global, `require`-Pfad `/home/dev/.nvm/versions/node/<v>/lib/node_modules/playwright`). Hole:
- Full-Page-Screenshot **und** per-Sektion-Screenshots (`elementHandle.screenshot()` nach Scroll-Durchlauf, damit Lazy-/Reveal-Inhalte laden).
- Strukturierten Content je Sektion: Headings, Absätze, Buttons/Links, `li`, **Bild-URLs**, `data-*`.
- **Design-Tokens** aus computed styles + `:root`-Custom-Properties: Hintergrund/Text-Farben (Häufigkeit), Akzent, `--radius`, Font-Families, Font-Links.

Helfer: `scripts/extract.cjs <url> <outdir>` (schreibt `content.json`, `tokens.json`, `full.png`, `sec-*.png`).

### 2. POC-Nachbau + Freigabe-Gate
Baue die Seite zuerst als eigenständigen React-19/Tailwind-4-POC (wie `templates/<slug>/poc/`, Build via esbuild + `@tailwindcss/cli`), rendere + screenshotte, **vergleiche gegen das Original** und lege es dem Nutzer vor. **Erst nach „ok"** in die Registry überführen. (Für `verdict` bereits geschehen — bei neuen Templates Pflicht.)

### 3. Token-agnostische Überführung
Je Sektion eine Datei `registry/blocks/<slug>-<section>.jsx`:
- Signatur `export default function <Pascal>({ data = {} })`, Felder aus `data` (Namen = `content.json`-Sektion), `const { id = "<section>" } = data;`, `id={id}` an die Wurzel.
- Primitives aus `../lib/ui.jsx`, `cn` aus `../lib/cn.js`. Kein `content.js`-Import.
- **Token-Ersetzung** (Standard-Mapping):
  | roh (POC) | Token |
  |---|---|
  | `bg-neutral-950` / dunkle Fläche | `bg-ink` |
  | dunkler Hover | `hover:bg-ink-soft` |
  | `text-white[/NN]` | `text-paper[/NN]` |
  | `border-white/NN`, `bg-white/NN`, `ring-white/NN` | `*-paper/NN` |
  | helle Sekundärfläche `bg-neutral-200` | `bg-surface` |
  | warmer Ton (Kennzahl) | `bg-sand` |
  | Roh-Hex-Verlauf | `bg-gradient-* from-accent via-accent-soft to-ink` |
  | Fließtext-Grau | `text-muted` · Rahmen `border-line` · Akzent `text-accent` |
  Verläufe `from/via/to-neutral-950` → `…-ink` (Opazitäten behalten). Layout/Grid/Spacing + Interaktionslogik (useState, Accordion, sticky) **unverändert** lassen.
- **Bilder** → `<Slot id="<slug>-<section>-<n>" className=<Box-Klassen> imgClass=<object-fit> dark? />`; Overlays als children; kein `src`.
- Große Sektionssätze parallel über Subagenten überführen (klare Regeln + Muster-Block mitgeben).

### 4. Content generalisieren
`registry/templates/<slug>/content.json`: `sections[]` (je `id`, `block`, `type`, Felder) + `image_slots[]`. Copy zu Platzhaltern generalisieren.

### 5. Branding-Profil
`branding/<slug>/`:
- `tailwind-theme.css` — `@theme`-Tokens (aus Schritt 1) + `@font-face` (self-hosted woff2 in `fonts/`).
- `tokens.json` — DTCG (Rollen + Hex + Type-Scale).
- `branding.md` — der **Branding-Guide** (Farbrollen, Typo, Radius, Buttons, Do/Don't).
- `fonts/`, `logo.svg` (generalisierte Marke).

### 6. Registry eintragen + Version
**Dedupe-Vorabprüfung je neuem Block** (PROJ-11): `node scripts/registry-dedupe.mjs --candidate registry/blocks/<name>.jsx --section <section> --name <name>` — Exit 2 (≥ 0.80) = Duplikat → nur mit bewusster Bestätigung eintragen; Exit 1 = ähnlich → Hinweis. (Ganzer Audit: `registry-dedupe.mjs` ohne Args.)

`registry/registry.json`: je Block ein `registry:block`-Item (name, title, description, files, `dependencies:["react"]`, `registryDependencies:["<slug>-lib"]`, `meta:{section,style,industry,source,date,image_slots}`) + ein `…-template`-Item. `registry/VERSION` erhöhen.

### 7. Verifikation
`registry/templates/<slug>/preview/` (esbuild + tailwind, `@source` auf `blocks`/`lib`, Branding-Theme + `base.css`) bauen, rendern, gegen POC/Original prüfen (Höhe, Sektionszahl, `data-image-slot`-Zahl, Konsolenfehler). `dist/`/`node_modules` sind gitignored.

### 8. Tracking
- Inventar neu generieren: `node scripts/registry-inventory.mjs` (`registry/INVENTORY.md` + `registry/inventory.html`).
- PROJ-11 Spec + `features/INDEX.md` per Write-Then-Verify aktualisieren (neue(s) Template/Profil, Datum).

## Verweise
- Contract & Struktur: `registry/README.md`
- Referenz-Umsetzung: Profil `verdict` (`registry/blocks/verdict-*.jsx`, `branding/verdict/`, `templates/verdict/`)
- Primitives: `registry/lib/ui.jsx` (Eyebrow, Button, TextLink, **Slot**, Logo)
- Bild-Befüllung danach: `ui-images-fill` (PROJ-20)
