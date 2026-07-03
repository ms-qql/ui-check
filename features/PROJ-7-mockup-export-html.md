# PROJ-7: Mockup-Export (Self-contained HTML)

## Status: In Review
**Created:** 2026-07-02
**Last Updated:** 2026-07-03

## Dependencies
- Requires: PROJ-6 (Redesign-Varianten als React-Code)

## Beschreibung
Bündelt die Redesign-Varianten über einen versionierten Build-Harness zu **einer** statischen HTML-Datei, die ohne Server/Deployment per Mail oder Link teilbar ist. Vor dem Export laufen automatische Publish-Gates (Cai-Checklisten).

## User Stories
- Als Auxevo-Nutzer möchte ich das Mockup als eine Datei verschicken können, damit der Kunde es ohne Infrastruktur im Browser öffnet.
- Als Auxevo-Nutzer möchte ich, dass kein Mockup mit vermeidbaren Mängeln (fehlender Title, kaputtes Mobile-Layout) das Haus verlässt.

## Acceptance Criteria
- [ ] `mockup.html`: self-contained (CSS/JS inlined, Bilder base64), < 5 MB, offline lauffähig, keine externen Requests außer Bunny Fonts (oder Fonts subsettet inlined)
- [ ] Enthält beide Varianten (Safe/Bold) mit Umschalter; responsiv 375–1440 px
- [ ] Publish-Gates (automatisch geprüft, Lauf bricht bei Rot ab): Title gesetzt, Meta-Description, Favicon, Mobile-Layout ohne horizontales Scrollen (375 px), alle internen Anker funktionieren, keine Platzhalter-Lorem-Reste
- [ ] Gate-Ergebnis als `gates.json` im Run-Ordner (grün/rot je Check)
- [ ] DSGVO: keine Google-Fonts-CDN-Referenzen (Gate-Check)

## Edge Cases
- Bundle > 5 MB (viele Bilder): Bilder werden komprimiert/skaliert; hilft das nicht, Warnung + Angabe des Treibers
- Kunde öffnet in Outlook-Vorschau/altem Browser: Baseline funktionsfähig ohne JS (Inhalte sichtbar, nur Interaktionen degradieren)
- Font nicht über Bunny verfügbar: Subset self-hosted inlined statt CDN-Fallback auf Google

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
**Erstellt:** 2026-07-03 · **Stack:** Node-Build-Pipeline (esbuild, Tailwind CLI, versionierter Build-Harness im Repo) + agent-browser-Gates · **Branch:** dev

### Struktur (rein deterministischer Treiber — kein LLM-Anteil)
Anders als PROJ-5/6 gibt es hier kein Generator-Sandwich: Bündeln und Prüfen sind
vollständig skriptbar. Ein Treiber, zwei Phasen:

```
scripts/mockup-export.sh <run-dir>
1. INIT-Gate      PROJ-6-Output komplett? (redesign/{safe,bold}/, brief.md,
                  shared/content.json + tailwind-theme.css) — sonst Abbruch (Exit 2)
2. Zusammenbau    Viewer-Shell (versioniert im Repo) + beide Varianten + Tokens/Theme
                  in einen Build-Workspace kopieren
3. Pre-Render     beide Varianten werden beim Build zu statischem HTML gerendert;
                  JS hydratisiert nur Interaktionen → No-JS-Baseline (Outlook-Edge-Case)
4. Bundle         esbuild + Tailwind + Assembler → EINE Datei: CSS/JS inline,
                  Bilder base64, Favicon inline
5. Publish-Gates  statische Checks (grep/jq) + Browser-Checks (agent-browser, lokal,
                  ohne Netz) → gates.json; rote Pflicht-Gates = Abbruch
```

### Aufbau der `mockup.html` (PM-Sicht)
```
mockup.html (eine Datei, offline lauffähig)
├── Viewer-Shell (deutsch)
│   ├── Varianten-Umschalter Safe | Bold
│   └── Erweiterungs-Slots für PROJ-8 (Voting-Screen, Split-Slider, Sektionsvergleich)
├── Variante Safe   (aus redesign/safe/, vor-gerendert + hydratisiert)
└── Variante Bold   (aus redesign/bold/, vor-gerendert + hydratisiert)
```
Die Shell ist bewusst der **Träger** für PROJ-8: Voting & Vorher/Nachher kommen später
in dieselbe Datei (Spec PROJ-8: „kein zweites Artefakt"), nicht in ein neues Format.

### Publish-Gates (`gates.json`)

| Gate | Prüfweise | Bei Verstoß |
|---|---|---|
| Title gesetzt | statisch | rot → Abbruch |
| Meta-Description vorhanden | statisch | rot → Abbruch |
| Favicon (inline) vorhanden | statisch | rot → Abbruch |
| Keine Google-Fonts-CDN-Referenz (DSGVO) | statisch | rot → Abbruch |
| Keine externen Requests außer Bunny Fonts | statisch (URL-Scan) | rot → Abbruch |
| Keine Lorem-/TODO-/Platzhalter-Text-Reste | statisch | rot → Abbruch |
| No-JS-Baseline: Inhalte ohne JS im HTML | statisch (dank Pre-Render prüfbar) | rot → Abbruch |
| Kein horizontales Scrollen bei 375 px | Browser (agent-browser, beide Varianten) | rot → Abbruch |
| Alle internen Anker erreichen ihr Ziel | Browser | rot → Abbruch |
| Dateigröße < 5 MB | statisch; vorher automatische Bild-Kompression/-Skalierung | gelb → Warnung + größter Treiber benannt (Exit 1) |

`gates.json` hält je Check grün/gelb/rot **mit Beleg** (z. B. gefundene URL, gemessene
Scrollbreite) — gleiche Beweispflicht wie bei den Befunden in PROJ-4.

### Daten (Run-Ordner-Kontrakt, zusätzlich zu PROJ-6)
```
<run-dir>/mockup.html        das teilbare Deliverable (neben report.md das zweite Top-Level-Artefakt)
<run-dir>/mockup/
├── gates.json               Gate-Ergebnis je Check (grün/gelb/rot + Beleg)
└── build.log                Roh-Output von npm/Build-Harness (Diagnose)

scripts/lib/mockup-shell/    (im Repo, versioniert)
                             Viewer-Shell + Build-Konfiguration + Gate-Prüfskript
```

### CLI-/Skill-Kontrakt
- **Kein eigener Claude-Skill:** Der Export ist vollständig deterministisch. Er wird
  (a) als letzter Schritt vom `/ui-redesign`-Skill (PROJ-6) nach erfolgreichem
  `redesign.sh --verify` aufgerufen und ist (b) standalone headless nutzbar
  (Jupiter/PROJ-14; PROJ-9 nimmt `mockup.html` als Scoring-Input).
- Exit-Codes analog zur Skript-Familie: `0` alle Gates grün · `1` degradiert
  (nur gelbe Warn-Gates, z. B. Größe) · `2` Abbruch (rote Pflicht-Gates, fehlender
  PROJ-6-Output, fehlendes Tool).

### Tech-Entscheidungen
- **Versionierter Build-Harness statt web-artifacts-builder-Skill:** Der in der Spec
  genannte Skill ist auf dem VPS **nicht installiert** — gleiche Lage wie
  `frontend-design`/`taste` in PROJ-6, gleiche Lösung: das Bundling- und Inline-Muster
  wird als versionierter Repo-Baustein `scripts/lib/mockup-shell/` nachgebaut. Der
  konkrete MVP-Harness nutzt `esbuild` + Tailwind CLI + einen expliziten HTML-Assembler,
  weil damit CSS/JS/Favicon/Data-URIs und Gate-Belege deterministisch kontrollierbar
  bleiben. Kein unversioniertes Skill-Dependency; wird der Skill später installiert,
  bleibt der Output-Kontrakt gleich.
- **Pre-Rendering für die No-JS-Baseline:** Reines client-seitiges React zeigt ohne JS
  eine leere Seite — genau der Outlook-/Alt-Browser-Edge-Case der Spec. Darum rendert
  der Build die Varianten zu statischem HTML und JS übernimmt nur Interaktionen
  (Umschalter, Animationen). Nebeneffekt: die No-JS-Baseline wird statisch prüfbar
  (Gate) statt nur erhofft.
- **Browser-Gates mit agent-browser:** bereits Pipeline-Voraussetzung (PROJ-1/3), kein
  neues Tool. Die Checks laufen gegen die **lokal gebaute Datei** — kein Netzzugriff,
  hermetisch testbar (gleiche Stub-Teststrategie wie `ui_check_test.sh`, eigener Test
  `scripts/tests/mockup_export_test.sh`).
- **Gates als Abbruch, nicht als Hinweis:** „Kein Mockup mit vermeidbaren Mängeln
  verlässt das Haus" ist nur durchsetzbar, wenn rote Gates den Lauf beenden statt eine
  Notiz zu erzeugen — gleiche Philosophie wie Token-Lint in PROJ-6.
- **Größe = Warn-Gate mit Auto-Kompression:** Im MVP sind Bilder Platzhalter
  (PROJ-6: `images.md`), das 5-MB-Risiko ist klein. Kommen später echte Bilder, werden
  sie vor dem Inlining komprimiert/skaliert; reicht das nicht, degradiert der Lauf mit
  Benennung des größten Treibers (Edge-Case der Spec) statt hart zu scheitern.
- **Bunny Fonts als einzige erlaubte externe Referenz:** DSGVO-Vorgabe aus den globalen
  Regeln; Google-Fonts-CDN ist ein rotes Gate. Ist eine Marken-Schrift nicht über Bunny
  verfügbar, wird ein Subset ins HTML eingebettet (Edge-Case) — niemals CDN-Fallback.
- **npm-Install im Build-Workspace, gecacht:** Abhängigkeiten (react, tailwind, esbuild)
  werden beim Export in einen Workspace installiert und repo-weit gecacht — wiederholte
  Exporte bleiben schnell, das Repo selbst bleibt frei von `node_modules`.

### Dependencies
- **Neu (npm, im Build-Workspace, nicht global):** `esbuild` (Pre-Render- und
  Client-Bundle), `react`/`react-dom` (Rendern der Varianten), `tailwindcss` v4 +
  `@tailwindcss/cli` (Theme aus PROJ-3)
- **Vorhanden:** `agent-browser` (Browser-Gates), `jq`, `node` v22

## Implementation Notes
**Implemented:** 2026-07-03

- `scripts/mockup-export.sh <run-dir> [--force]` implementiert INIT-Gate,
  Workspace-Aufbau, Build, Publish-Gates, `gates.json`, Status-Fortschreibung und
  Promote nach `<run-dir>/mockup.html`.
- `scripts/lib/mockup-shell/` enthält Viewer-Shell, No-JS-Template,
  Varianten-Umschalter, Tailwind/esbuild-Harness und Slots für PROJ-8.
- `scripts/tests/mockup_export_test.sh` deckt rote Gates, Warn-Gates, Browser-Gates,
  Promote-Verhalten, `status.json` und optionalen echten E2E-Build ab.

## QA Test Results
- 2026-07-03: `scripts/tests/mockup_export_test.sh` → 53 bestanden, 0 fehlgeschlagen.
- 2026-07-03: `MOCKUP_EXPORT_E2E=1 scripts/tests/mockup_export_test.sh` → 58 bestanden,
  0 fehlgeschlagen; echter Build erzeugte `mockup.html` mit 333428 Bytes und allen
  Publish-Gates grün.

## Deployment
_To be added by /abc-deploy_
