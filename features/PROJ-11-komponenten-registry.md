# PROJ-11: Komponenten-Registry & Best-of-Recycling

## Status: In Progress
**Created:** 2026-07-02
**Last Updated:** 2026-07-04 (Profil „meridian" aufgenommen)

## Dependencies
- Requires: PROJ-6 (liefert die Sektionen, die kuratiert werden)

## User Stories
- Als Auxevo-Nutzer möchte ich gelungene Sektionen aus Läufen mit einem Schritt generalisiert ins Portfolio übernehmen, um das Rad nicht neu zu erfinden.
- Als Claude (Generierung) möchte ich die eigene Registry wie jede shadcn-Registry durchsuchen und installieren können.

## Acceptance Criteria
- [ ] Lokale Registry im shadcn-Registry-Format (`registry.json` + Komponenten-Dateien), lesbar über den offiziellen shadcn-MCP
- [ ] Metadaten je Baustein: Industrie, Kundensegment, Sektionstyp (Hero/Pricing/Trust/CTA/…), Stil (Safe/Bold), Herkunfts-Lauf, Datum
- [ ] Recycling-Schritt am Ende jedes Redesign-Laufs: Vorschlag portfoliowürdiger Sektionen; Übernahme generalisiert Kundentexte zu Platzhaltern (keine Kundendaten in der Registry)
- [x] PROJ-6 bevorzugt bei passenden Tags Registry-Bausteine vor Neu-Generierung (Selektor `scripts/registry-select.mjs` + `redesign.sh --select`)
- [x] Registry-Browser-Ansicht (einfaches Markdown/HTML-Inventar) zum Durchblättern (`scripts/registry-inventory.mjs` → `registry/INVENTORY.md` + `registry/inventory.html`)

## Edge Cases
- Kundenspezifische Inhalte (Logos, Fotos, Namen) im Baustein: Übernahme wird blockiert, bis Platzhalter ersetzt sind
- Doppelte/sehr ähnliche Bausteine: Hinweis auf Bestands-Baustein, bewusste Bestätigung nötig

---
## Implementation Notes (2026-07-04)

Erste Ausbaustufe umgesetzt — Registry live mit dem ersten Template-Profil **`verdict`**.

**Angelegt:**
- `registry/` — shadcn-Registry-Format: `registry.json` (14 Items: 12 Blocks + `verdict-template` + `verdict-lib`/`verdict-styles`), `VERSION` (0.1.0), `README.md`, `styles/{tokens.css,base.css}`, `lib/{cn.js,ui.jsx}` (Primitives inkl. `Slot` für den `data-image-slot`-Contract).
- `registry/blocks/verdict-*.jsx` — 12 **token-agnostische** Sektions-Blocks (nav, hero, about, services, cases, process, team, awards, testimonials, faq, contact, footer). Props-getrieben (`{ data }`), `id={id}`-Contract, nur semantische Tokens, Bilder als `Slot` (keine Fotos gespeichert). Interaktivität erhalten (Services-Hover, Process-Stepper, Cases-Sticky, FAQ-Accordion).
- `registry/templates/verdict/` — `template.json`, `content.json` (generalisierte Platzhalter-Copy + 27 `image_slots`, keine Kundendaten), `App.jsx` (Kompositions-Entry, zugleich Vorlage für `ui-redesign`-App.jsx), `preview/` (Verifikations-Build).
- `branding/verdict/` — **Branding-Guide** `branding.md` + `tokens.json` (DTCG) + `tailwind-theme.css` (@theme + @font-face) + `fonts/` (Geist self-hosted, DSGVO) + `logo.svg`. (Legt zugleich die PROJ-12-Konvention `branding/<slug>/` an.)

**Herkunft:** Clean-Room-Nachbau von `verdict-nextjs-template.vercel.app` (shadcnblocks, kommerziell) — nur Struktur/Look, kein proprietärer Code/Assets. POC unter `templates/verdict/poc/`.

**Verifiziert:** Preview-Build (esbuild + @tailwindcss/cli) rendert alle 12 Sektionen mit dem Branding-Profil identisch zum POC (Höhe ~13,5k px, 27 `data-image-slot`, keine Konsolenfehler).

**Neuer Skill:** `ui-template-ingest` (`.claude/skills/ui-template-ingest/`) — nimmt weitere shadcnblocks-Templates/Komponenten nach demselben Verfahren auf (Extraktion → Clean-Room-POC + Freigabe → token-agnostische Blocks → Content generalisieren → Branding-Profil → registry.json + VERSION → Verifikation). Enthält `scripts/extract.cjs`.

---
## Implementation Notes (2026-07-04, Nachtrag: shadcnblocks-Free-Blocks)

Zweiter Ingest-Pfad für **einzelne kostenlose shadcnblocks-Blocks** ergänzt (POC: `hero45`).

**Erkenntnis:** Free-Blocks liefern über den offiziellen shadcn-Registry-Endpoint `https://www.shadcnblocks.com/r/<name>` den **echten, lizenzierten Quellcode** als `registry-item.json` — also kein Playwright-Clean-Room-Rebuild nötig (wie bei ganzen Templates via `ui-template-ingest`), sondern Fetch + token-agnostische Transformation des TSX.

**Angelegt:**
- `registry/blocks/hero45.jsx` — token-agnostischer Nachbau von `shadcnblocks/hero45` (Feature-Slider-Hero: Outline-Badge, Headline, breites Landscape-Bild mit Crossfade beim Spalten-Hover, 3 icon-geführte Feature-Spalten). TSX→JSX, shadcn-Default-Tokens→UI-Check-Semantik, `lucide-react`→inline-SVG-Icons (`dependencies:["react"]`), Foto-URLs→`Slot` (3 Slots), plus `export const demo` mit Default-Copy. `id={id}`-Contract erfüllt.
- `registry/registry.json` → neues Item `hero45` (`source:"shadcnblocks/hero45 (free)"`, `image_slots:["hero45-visual-1..3"]`). `VERSION` 0.1.0 → **0.2.0**.

**Verifiziert:** `preview_block.cjs` (esbuild + Tailwind v4 gegen neutrale Tokens, Playwright-Render) → 1 Section, 3 `data-image-slot`, keine Konsolenfehler; Layout deckt sich mit dem shadcnblocks-Original.

**Neuer Skill:** `ui-block-ingest` (`.claude/skills/ui-block-ingest/`) — importiert weitere Free-Blocks nach diesem Verfahren (Fetch `/r/<name>` → Analyse → token-agnostische Überführung → Build-Verifikation → registry.json + VERSION → Tracking). Scripts: `scripts/fetch_block.cjs` (holt/entpackt das Registry-JSON, erkennt Pro/Premium via 401/403), `scripts/preview_block.cjs` (generischer Single-Block-Verifikations-Build + Screenshot, optional gegen ein Branding-Profil). Abgrenzung: `ui-template-ingest` bleibt für ganze fremde Templates/Pro-Blocks ohne Registry-JSON.

**Offen (nächste Stufen):**
- AC „Recycling-Schritt am Ende jedes Redesign-Laufs" (portfoliowürdige Sektionen aus `runs/*/redesign` vorschlagen + generalisiert übernehmen).
- AC „Registry-Browser-Ansicht" (Markdown/HTML-Inventar) — soll auch die Einzel-Blocks (hero45 …) listen.
- Doppelte/ähnliche Bausteine erkennen (Dedupe-Hinweis).

---
## Implementation Notes (2026-07-04, Nachtrag: Registry-Andockung an ui-redesign)

AC „PROJ-6 bevorzugt bei passenden Tags Registry-Bausteine" umgesetzt — Variante **(a) Auto + Fallback + Flags** (Nutzer-Entscheidung).

**Angelegt:**
- `scripts/registry-select.mjs` — deterministischer Selektor (kein LLM, nur Node-Builtins). Wählt je Sektion einen Block: Match über Sektionstyp (mit de/en-Synonymen, z. B. `leistungen→services`, `stimmen→social-proof`) + `industry_tag` (Template-Auflösung) + Stil (Safe/Bold als **weiches** Ranking, kein Ausschluss), **Fallback = generieren**. Emittiert `registry-selection.{safe,bold}.json`, kopiert gewählte Blocks + `lib/` nach `redesign/registry/` und schreibt **`registry-tokens.css`** (Token-Alias Registry-Semantik → Run-Branding; Luminanz-Heuristik aus `branding/tokens.json`, fehlende Rollen aus paper/ink abgeleitet, inkl. `--font-display`). Exit 0/1/2.
- Overrides: `--template <slug>` · `--pin <section>=<block>` · `--exclude <block>` · `--registry-only` (Exit 2 bei Lücke) · `--no-registry`.
- `scripts/redesign.sh` — neuer **`--select`-Modus** + Flag-Parsing + Persistenz in `redesign/registry-config.json`; INIT triggert die Auswahl automatisch, sobald `content.json` existiert. Verify-Gate **G-REG** prüft Auswahl-Status, kopierte Blocks und Token-Alias.
- `.claude/skills/ui-redesign/SKILL.md` — Schritt **3b**: `--select` nach dem Content-Pass; im Visual-Pass `decision:"registry"`-Sektionen aus `../registry/blocks/*` importieren + `registry-tokens.css`/`base.css` einbinden, `generate`-Sektionen wie bisher.

**Getestet** (Kopie von `runs/2026-07-04-auxevo.tech-001`): Auto (6/6 aus Registry), erzwungenes Template, `--pin`/`--exclude` (Fallback greift), `--registry-only` (Exit 2), `--no-registry`; Token-Alias distinkt (surface/line ≠ paper); G-REG grün bzw. rot bei manipuliertem Status. Zusatzblöcke (z. B. `hero45`) werden automatisch als Kandidaten berücksichtigt.

---
## Implementation Notes (2026-07-04, Nachtrag: zweites Template-Profil „meridian")

Zweites vollständiges Template-Profil via `ui-template-ingest` aufgenommen: **`meridian`** — dunkles, editoriales Observability-/Dev-Tool-SaaS im „Blueprint"-Stil (Kontrast zum hellen `verdict`). Clean-Room aus `meridian-nextjs-template.vercel.app` (Next.js/fumadocs-Template, kommerziell) — nur Struktur/Look, kein Fremdcode/Assets. POC + Freigabe-Gate durchlaufen (POC unter `templates/meridian/poc/`).

**Angelegt:**
- `registry/blocks/meridian-*.jsx` — 12 **token-agnostische** Blocks: `nav, hero, glance` (feature-list A–F), `bulletin` (stats 217/2/215, mittlere invertiert), `flow` (steps + Watch-Mockup), `incidents` (log-table + Sparklines), `testimonials`, `compare` (us vs. Legacy), `island` (Phone/Dynamic-Island-Showcase), `logos`, `pricing` (Ticket/Receipt), `footer`. Props-getrieben, `id={id}`-Contract, nur semantische Tokens, Bilder als `Slot` (5: `hero-visual`, `glance-visual`, `testimonial-1..3`). Interaktivität/Mockups code-gerendert (kein Foto).
- `registry/lib/meridian-ui.jsx` — eigene Primitives (Logo, Button **mit irisierendem Glow**, TextLink, `DispatchBar`, `SpecCard`, `Barcode`, `Slot`); teilt `lib/cn.js`.
- `registry/templates/meridian/` — `template.json`, `content.json` (generalisierte Platzhalter-Copy + 5 `image_slots`, keine Kundendaten), `App.jsx` (dunkel-default `bg-ink text-paper`), `README.md`, `preview/` (Verifikations-Build).
- `branding/meridian/` — `branding.md` (Branding-Guide) + `tokens.json` (DTCG) + `tailwind-theme.css` (@theme + @font-face) + `fonts/` (DM Sans / Space Grotesk / JetBrains Mono self-hosted via Bunny, OFL/DSGVO) + `logo.svg`.
- `registry/registry.json` — **14 neue Items** (`meridian-lib` + 12 Blocks + `meridian-template`), Style `bold`, Industrie `saas/developer-tools/observability`. `VERSION` → **0.2.0**.

**Contract-Erweiterung (rückwärtskompatibel):** neuer optionaler Token `--font-display` (Headline-Schrift) in `registry/styles/tokens.css` (Fallback = `font-sans`) + `base.css` `.display` nutzt ihn; `branding/verdict` explizit auf Geist gesetzt (unverändertes Rendering). Ermöglicht drei Schrift-Rollen (sans/display/mono) statt zwei.

**Verifiziert:** Preview-Build (esbuild + @tailwindcss/cli, Meridian-Branding) rendert alle **12 Sektionen** identisch zum POC — Höhe ~11,9k px, **5 `data-image-slot`** (korrekte IDs), 12 Sektions-IDs = content-id-Contract, **0 Konsolenfehler**. Hero/Glance-Bilder korrekt als leere Slots (Contract: keine Fotos in der Registry).

---
## Implementation Notes (2026-07-04, Nachtrag: Registry-Browser + Dedupe)

Zwei AC-Bausteine ergänzt.

**Registry-Browser** (`scripts/registry-inventory.mjs`, deterministisch aus `registry.json`):
- `registry/INVENTORY.md` — gruppiert nach Sektionstyp, Tabelle je Block (Titel, Stil, Branchen, Quelle, Slots, interaktiv) + Template-Kompositionen.
- `registry/inventory.html` — statische, self-contained Galerie (kein Build, kein CDN): Volltextsuche + Filter (Sektion/Stil/Quelle), Template- und Block-Karten mit Tags, Preview-Links. Verifiziert (Playwright): 27 Karten, Filter greifen, 0 Fehler.
- Regeneration in beide Ingest-Skills (`ui-block-ingest`, `ui-template-ingest`) als Tracking-Schritt aufgenommen.

**Dedupe** (`scripts/registry-dedupe.mjs`, Char-5-Gramm-Jaccard, literal + strukturell, `combined = max(lit, 0.9·str)`; Schwellen Warn 0.55 / Dup 0.80):
- Audit-Modus (alle Paare) und **Kandidat-Modus** (`--candidate <file> --section --name`) → Exit 2 = Duplikat (bewusste Bestätigung nötig), 1 = ähnlich, 0 = ok. Als **Vorabprüfung** in beide Ingest-Skills eingehängt (Edge Case „doppelte/ähnliche Bausteine").
- Kalibriert an der Registry: exakte Kopie → 1.00 (Dup), echter neuer Block → ~0.28 (ok), einziges real ähnliches Paar `verdict-nav ~ meridian-nav` → 0.72 (Warn). Keine Fehlalarme.

**Zusatz:** `registry-select.mjs` normalisiert jetzt auch die **Block-Section** über die Synonym-Tabelle → Blocks mit granularen Tags (z. B. `meridian-testimonials`=`testimonials`, `meridian-flow`=`steps`) matchen `social-proof`/`process`-Sektionen; Stil bricht den Gleichstand zwischen Templates.

Offene AC: nur noch „Recycling-Schritt am Ende jedes Redesign-Laufs".

---
## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
