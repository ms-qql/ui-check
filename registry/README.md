# UI-Check Komponenten-Registry (PROJ-11)

Kuratierte, **token-agnostische** React-19/Tailwind-4-Bausteine, aus denen `ui-redesign` (PROJ-6) und Menschen professionelle Webseiten zusammensetzen. Format: shadcn-Registry (`registry.json` + Dateien), lesbar über den shadcn-MCP.

## Struktur

```
registry/
  registry.json          Index aller Items (Blocks + Template + Lib + Styles) mit Metadaten
  VERSION
  styles/
    tokens.css           branding-neutraler @theme-Token-Contract
    base.css             Utility-Klassen (eyebrow, mono-label, display, section-padding, container-x)
  lib/
    cn.js                className-Joiner
    ui.jsx               Primitives: Eyebrow, Button, TextLink, Slot, Logo
  blocks/
    verdict-*.jsx        12 Sektions-Blocks (props-getrieben: <Block data={section} />)
  templates/
    verdict/
      App.jsx            Kompositions-Entry (content.sections[].block → Block)
      content.json       generalisierte Platzhalter-Copy + image_slots
      README.md
      preview/           lokaler Verifikations-Build (gitignored dist)
```

Branding liegt getrennt in `branding/<slug>/` (Farben/Fonts/Radius). Dasselbe Template lässt sich mit jedem Branding-Profil kombinieren.

## Contract (verbindlich für jeden Block)

- **Nur semantische Tokens:** `paper, ink, ink-soft, muted, surface, line, accent, accent-soft, sand` + `radius`, `font-sans/mono`. Keine Tailwind-Default-Palette (`bg-blue-500`), kein Roh-Hex.
- **Bilder** nur über `Slot` (`data-image-slot`-Contract) — die Registry speichert **keine Fotos**. `ui-images-fill` (PROJ-20) füllt sie später.
- **Section-id:** jede Block-Wurzel rendert `id={id}` (`^[a-z0-9-]+$`).
- **Props:** `export default function Block({ data }) {}` — `data` = eine `content.json`-Sektion.
- **Tech:** React 19, Tailwind v4, optional `motion/react`; **kein** `next/*`. Deps nur aus der PROJ-6-Whitelist.

## Verwenden (Konsument)

```css
@import "tailwindcss";
@import ".../branding/verdict/tailwind-theme.css";   /* oder registry/styles/tokens.css für neutral */
@import ".../registry/styles/base.css";
```
```jsx
import App from ".../registry/templates/verdict/App.jsx";  // rendert content.json
```

## Weitere Templates/Blocks aufnehmen

Zwei Ingest-Pfade, je nach Quelle:

- **Einzelner kostenloser shadcnblocks-Block** (hat eine `/block/<name>`-Seite, z. B. `hero45`): Skill **`ui-block-ingest`** (`/ui-block-ingest <name|url>`). Holt den echten, lizenzierten Quellcode über den offiziellen shadcn-Registry-Endpoint `https://www.shadcnblocks.com/r/<name>`, überführt ihn token-agnostisch nach `blocks/<name>.jsx` und verifiziert per Build. Siehe `.claude/skills/ui-block-ingest/SKILL.md`.
- **Ganze fremde Templates / Seiten ohne Registry-JSON / Pro-Blocks**: Skill **`ui-template-ingest`** (`/ui-template-ingest <url>`). Extrahiert die Seite (Playwright), baut sie clean-room nach, überführt sie token-agnostisch und legt ein Branding-Profil an. Siehe `.claude/skills/ui-template-ingest/SKILL.md`.

## Versionierung

Jede inhaltliche Änderung an Block-Code/Contract erhöht `VERSION`. Läufe frieren die Version in ihrem `manifest.json`/`redesign-context.json` ein (analog `recipes/`).
