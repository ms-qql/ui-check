# recipes/ — Layout-Rezepte für die Redesign-Generierung (PROJ-6)

Versionierte Taste-/Varianz-Vorgaben für den Visual-Pass des `ui-redesign`-Skills.
Beide Varianten teilen Content (`shared/content.json`) und Tokens; **nur** das
Layout-Rezept und das Animations-Level unterscheiden sich.

| Datei | Variante | Charakter |
|---|---|---|
| `safe.md` | Safe | konservatives Facelift — Varianz niedrig, Motion dezent |
| `bold.md` | Bold | mutige Neuinterpretation — Varianz hoch, Motion ausgeprägt |
| `VERSION` | — | Rezept-Version (Format `JJJJ.MM-N`) |

## Versionierung

Wie `rubrics/`: **jede inhaltliche Änderung = neue Version** in `VERSION`.
Die Version wird von `redesign.sh` in `redesign-context.json` eingefroren und
muss im `manifest.json` jeder generierten Variante stehen — so bleibt
nachvollziehbar, unter welchem Rezept ein Mockup entstand (PROJ-9-Deltas,
PROJ-11-Registry).

## Rangordnung (bindend)

1. **Extrahierte Tokens + `brief.md`** (Markentreue; Abweichungen nur mit
   Begründung im Brief + `shared/tokens-extra.json`)
2. **Nutzer-Prompt** (dokumentierte Abweichung schlägt Branding)
3. **Rezept** (diese Dateien)

Ein Rezept darf niemals einen Font-/Farb-Swap erzwingen, der den Tokens
widerspricht — Rezepte steuern Layout, Rhythmus, Motion und Anti-Slop.

## Quellen (destilliert, nicht live eingebunden)

- [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) v2 (MIT) —
  Drei-Dial-Modell, Anti-Default-Regeln, Pre-Flight-Checks (Stand 2026-07-03)
- [garrytan/gstack](https://github.com/garrytan/gstack) `design-review` (MIT) —
  AI-Slop-Blacklist (Stand 2026-07-03)
- [robonuggets/cinematic-site-components](https://github.com/robonuggets/cinematic-site-components)
  (MIT) — Effekt-Vokabular für Bold (Stand 2026-07-03)
- `rubrics/slop.md` — projekteigene Anti-Slop-Rubrik (Judge-Perspektive)
