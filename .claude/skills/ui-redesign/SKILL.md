---
name: ui-redesign
description: Stufe-2-Redesign-Generierung — erzeugt aus einem abgeschlossenen ui-check-Lauf zwei buildfähige React/Tailwind-Redesign-Varianten (Safe = konservatives Facelift, Bold = mutige Neuinterpretation). Nutze diesen Skill, wenn der Nutzer "ui-redesign <run-dir>", "redesign für <run/url>", "Redesign-Varianten erzeugen", "Safe und Bold generieren" oder nach einem Audit ein Redesign/Mockup möchte. Headless aufrufbar (Jupiter/PROJ-14); Input für den Mockup-Export (PROJ-7).
---

# UI-Redesign — Safe + Bold (PROJ-6)

Erzeugt aus Audit (PROJ-4) + Branding (PROJ-3) zwei Redesign-Varianten als
React/Tailwind/shadcn-Code. **Beide teilen Tokens und Content** —
nur Layout-Rezept und Animations-Level unterscheiden sich.

## Aufruf

```
/ui-redesign <run-dir>
```

- `<run-dir>` — abgeschlossener Stufe-1-Lauf (`runs/YYYY-MM-DD-<domain>-NNN/`
  mit `scores.json` + `branding/`). Fehlt er, zuerst `/ui-check <url>` fahren.

## Architektur (Generator-Sandwich)

Der deterministische Treiber **`scripts/redesign.sh`** übernimmt Scaffold,
Kontext und Gates. Die Generierung (Brief → Struktur/Content → Visuals) bist
**du (Claude)** — anhand der versionierten Rezepte in `recipes/`.

```
1. redesign.sh <run-dir>            INIT: Gate + Scaffold + redesign-context.json
2. (du) Brief-Pass                  → redesign/brief.md
3. (du) Struktur/Content-Pass       → redesign/shared/content.json + redesign/compare.json
4. (du) Visual-Pass ×2              → redesign/safe/ + redesign/bold/ + redesign/images.md
5. redesign.sh --verify <run-dir>   GATES → redesign/verify.json (rot ⇒ fixen, erneut)
```

Die Reihenfolge **Struktur → Content → Visuals** (Cai-Iterationsmodell) ist
bindend: erst der Plan, dann die Texte, dann die Gestaltung.

## Ablauf (Schritt für Schritt)

### 1. INIT

```bash
scripts/redesign.sh "<run-dir>"
```

- **Exit 2** → Abbruch (Stufe-1-Lauf unvollständig / redesign/ existiert schon).
  Meldung dem Nutzer auf Deutsch weitergeben, stoppen.
- **Exit 1** → degradiert (z. B. leere Token-Palette) — weiterarbeiten, die
  `notes` aus `redesign-context.json` im Brief adressieren.
- Lies danach `<run-dir>/redesign/redesign-context.json`: URL, Industrie-Tag,
  `user_prompt`, Scores + Cai-Teilscores, Top-Befunde, Rezept-Version.

### 2. Brief-Pass → `redesign/brief.md`

**Inputs:** `report.md`, `scores.json` (Cai-Teilscores zeigen, WO Conversion
schwächelt), `branding/branding.md` + `tokens.json`, `capture/snapshot.txt` +
`dom-meta.json` (Original-Struktur), `user_prompt` aus dem Kontext.

Pflicht-Abschnitte (Gate G2 prüft die Überschriften wörtlich):

```markdown
## Conversion-Ziel        was der Besucher tun soll; ohne CTA im Original:
                          Ziel vorschlagen und als **Annahme** markieren
## Primärer CTA           Label (≤ 3 Wörter!), intent, Ziel-Anker
## Sektionsplan           aus dem Original abgeleitet (dom-meta/snapshot);
                          je Sektion: id, Zweck, Original-Herkunft
## Brand-Entscheidungen   beibehalten vs. angepasst, je mit Begründung;
                          Anpassungen zusätzlich in shared/tokens-extra.json
## Anti-Slop-Constraints  die für diesen Lauf bindenden Regeln (aus
                          rubrics/slop.md + recipes/) + Nutzer-Prompt-Abweichungen
```

Edge Cases im Brief behandeln:
- **Kein CTA im Original** → Conversion-Ziel vorschlagen, als Annahme markieren.
- **Marke kollidiert mit Lesbarkeit** (z. B. Neon auf Weiß) → Anpassung erlaubt,
  begründen + in `shared/tokens-extra.json` deklarieren (`{"colors":[{"value":"#…","reason":"…"}]}`).
- **Sehr wenig Original-Content** → Sektionsplan reduzieren; **nichts erfinden**
  (keine Leistungen/Testimonials/Zahlen, die das Original nicht hat).
- **`user_prompt` widerspricht Branding** → Nutzer-Prompt gewinnt, Abweichung
  dokumentieren (+ tokens-extra.json).

### 3. Struktur/Content-Pass → `shared/content.json` + `compare.json`

`content.json` (Gate G3 prüft den Kontrakt):

```jsonc
{
  "language": "de",
  "conversion": {
    "goal": "Terminanfrage",
    "assumed": false,                       // true, wenn Ziel eine Annahme ist
    "primary_cta": { "label": "Termin buchen", "intent": "kontakt", "target": "#kontakt" }
  },
  "sections": [
    { "id": "hero",                         // ^[a-z0-9-]+$
      "type": "hero",                       // hero|leistungen|social-proof|cta|footer|…
      "heading": "…", "body": "…",          // verbesserte deutsche Original-Copy
      "cta": { "label": "Termin buchen", "intent": "kontakt", "target": "#kontakt" },
      "image_slots": ["hero-bild"] }
  ]
}
```

- Copy: **Original-Copy verbessern, nicht erfinden** — Quelle ist
  `capture/snapshot.txt`. Deutsch, klar, aktiv; keine Filler-Verben
  („nahtlos", „revolutionär"), keine erfundenen Fakten/Claims.
- CTAs: **ein Label pro `intent`** auf der ganzen Seite (Gate G11);
  primäres Label ≤ 3 Wörter (Gate G10).

`compare.json` (PROJ-8-Input, Gate G4): je content-Sektion ein Eintrag —
Zuordnung zum Original + 1-Satz-Begründung:

```jsonc
{ "sections": [
    { "id": "hero", "original": "Hero mit Bild-Slider", "change": "Slider durch statisches Hero mit klarem CTA ersetzt — Slider verwässern die Botschaft." },
    { "id": "social-proof", "original": null, "change": "Neu: vorhandene Kundenlogos aus dem Footer als eigene Vertrauens-Sektion." }
] }
```

### 4. Visual-Pass ×2 → `safe/` + `bold/` + `images.md`

**Lies zuerst das Rezept** (`recipes/safe.md` bzw. `recipes/bold.md`) — Dials,
Layout-Familien, Effekt-Vokabular und Anti-Slop-Regeln sind bindend.
Rangordnung: Tokens + Brief > Nutzer-Prompt > Rezept.

Je Variante:

```
redesign/<safe|bold>/
├── App.jsx              Einstieg: lädt ../shared/content.json + Theme
├── sections/            eine Komponente pro Sektion (ids aus content.json)
├── components/ui/       kopierte shadcn-Komponenten (an Tokens angepasst)
├── components/effects/  nur Bold: portierte Effekte (React/Motion, tokenbasiert)
├── manifest.json        Kontrakt s. u. (Gate G5)
└── package.json         nur benötigte Dependencies (Whitelist, Gate G13)
```

`manifest.json`:

```jsonc
{
  "variant": "safe",                        // == Ordnername
  "recipe_version": "<recipes/VERSION>",    // MUSS passen, sonst Gate rot
  "entry": "App.jsx",
  "dials": { "variance": 3, "motion": 2, "density": 4 },
  "sections": [ { "id": "hero", "layout": "full-bleed", "motion": "none" } ],
  "components_used": ["shadcn/button", "cinematic/sticky-stack(port)"]
}
```

Regeln (Auswahl — vollständig in den Rezepten):
- **Nur Token-Farben** (`shared/tailwind-theme.css`); Ausnahmen nur via
  `shared/tokens-extra.json` (Gate G6). Fonts via Bunny/self-hosted, nie
  Google-CDN (Gate G7).
- **Framework-agnostisches Client-React:** kein `next/*`, Motion aus
  `motion/react`; Effekte nach React portieren, nie GSAP/CDN einbinden.
- **Bild-Slots:** Platzhalter-Fläche mit `data-image-slot="<id>"`; keine
  automatische Bild-Generierung.
- Layout-Familien fürs Manifest: `full-bleed`, `stack`, `split`, `grid`,
  `bento`, `logo-wall`, `accordion`, `marquee`, `sticky-stack`,
  `horizontal-scroll`, `curtain`, `split-scroll`, `color-shift` —
  max. 2 × `split` in Folge (Gate G12).

`images.md` — je Slot ein Block (Gate G9 prüft `Slot: <id>`):

```markdown
## Slot: hero-bild
- **Platzhalter:** Token-Fläche (surface) mit Slot-Label, 1600×900
- **Bild-Prompt:** "Fotorealistische Aufnahme eines …, warmes Tageslicht,
  Markenfarbe #… als Akzent, 16:9, keine Texte im Bild"
```

### 5. Verify + Bericht

```bash
scripts/redesign.sh --verify "<run-dir>"
```

- **Exit 2** → rote Gates in `redesign/verify.json` lesen, im **zuständigen
  Pass** fixen (Content-Fehler im Content, Farb-Fehler im Visual-Pass),
  erneut verifizieren. Nicht die Gates umgehen.
- **Exit 1** → Warnungen dem Nutzer nennen, Lauf ist nutzbar.
- Danach auf Deutsch berichten: Conversion-Ziel + primärer CTA, Sektionsplan
  (Anzahl), was Safe vs. Bold unterscheidet (Dials, markanteste
  Layout-Entscheidungen), Brand-Abweichungen aus dem Brief, offene Bild-Slots,
  Pfad `<run-dir>/redesign/`. Verweis: weiter mit PROJ-7 (Mockup-Export).

## Headless (Jupiter / PROJ-14)

Bei vollständigen Parametern keine Rückfragen. `status.json` führt
`phases.redesign` (`awaiting_generation` → `ok|degraded|failed`);
Exit-Codes 0/1/2 steuern den Aufrufer.

## Fehlerbehandlung (Kurz)

| Situation | Verhalten |
|---|---|
| `scores.json`/`branding/` fehlt | INIT Exit 2 — erst `/ui-check <url>` fahren. |
| `redesign/` existiert bereits | INIT Exit 2 — Feedback-Runde? Bestehendes weiterbearbeiten oder `--force` (Scaffold neu, Generiertes bleibt). |
| Token-Palette leer | INIT Exit 1 — im Brief begründete Palette via `tokens-extra.json` aufbauen. |
| Rotes Gate bei Verify | Fix im zuständigen Pass, erneut `--verify`; Gates nie umgehen. |
| `recipe_version`-Konflikt | Manifest mit aktueller `recipes/VERSION` neu erzeugen (Rezept zwischenzeitlich geändert). |

## Referenzen

- Treiber + Gates: `scripts/redesign.sh` · Kontrakte: `scripts/README.md`
- Rezepte: `recipes/safe.md`, `recipes/bold.md`, `recipes/VERSION`
- Anti-Slop-Rubrik: `rubrics/slop.md` · Feature-Spec: `features/PROJ-6-redesign-generierung.md`
