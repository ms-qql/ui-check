# PROJ-6: Redesign-Generierung Safe + Bold

## Status: In Progress
**Created:** 2026-07-02
**Last Updated:** 2026-07-03

## Dependencies
- Requires: PROJ-3 (Branding-Tokens), PROJ-4 (Befunde + Cai-Teilscores als Redesign-Input), PROJ-5 (Orchestrierung, `--prompt`)

## Beschreibung
Erzeugt aus Audit + Branding zwei Redesign-Varianten als React/Tailwind/shadcn-Code: **Bold** (mutige Neuinterpretation, unkonventionelle Layouts) und **Safe** (konservatives Facelift). Beide teilen Tokens und Content-Struktur; nur Layout-Rezept und Animations-Level unterscheiden sich.

## User Stories
- Als Auxevo-Nutzer möchte ich pro Lauf eine mutige und eine konservative Variante erhalten, um dem Kunden eine Richtungs-Wahl zu geben.
- Als Auxevo-Nutzer möchte ich, dass das Redesign auf ein explizites Conversion-Ziel optimiert (CTA-First-Brief), nicht nur „schöner" ist.
- Als Auxevo-Nutzer möchte ich mein `--prompt` (Zielgruppe, Ton, Constraints) im Ergebnis berücksichtigt sehen.

## Acceptance Criteria
- [ ] Vor der Generierung entsteht `brief.md`: Conversion-Ziel, primärer CTA, Sektionsplan (aus Original abgeleitet), beibehaltene vs. angepasste Brand-Entscheidungen mit Begründung
- [ ] Generierungs-Reihenfolge: Struktur → Content → Visuals (Cai-Iterationsmodell)
- [ ] Skill-Sandwich aktiv: frontend-design-Skill + taste-Skill (Bold: Varianz hoch / Safe: niedrig) + Anti-Slop-Constraints aus der design-ai-check-Rubrik (dokumentiert in `brief.md`)
- [ ] Beide Varianten nutzen ausschließlich extrahierte Tokens (PROJ-3) bzw. im Brief begründete Anpassungen; deutsche Texte, Original-Copy wird verbessert, nicht erfunden (keine falschen Fakten/Claims)
- [ ] Komponenten aus shadcn/Magic UI/Aceternity-Registries; animierte Backgrounds nur assetfrei (Paper Shaders/CSS) — keine Bild-API-Pflicht
- [ ] Output: `redesign/safe/` und `redesign/bold/` als buildfähige React-Komponenten (Input für PROJ-7)
- [ ] Bild-Slots: Platzhalter + fertiger Bild-Prompt pro Slot (`images.md`) — keine automatische Bild-Generierung im MVP

## Edge Cases
- Original hat keinen CTA: Brief schlägt Conversion-Ziel vor, markiert es als Annahme
- Extrahierte Marke kollidiert mit Lesbarkeit (z. B. Neon auf Weiß): Anpassung erlaubt, muss im Brief begründet sein
- Sehr wenig Original-Content: Sektionsplan reduziert sich; keine erfundenen Leistungen/Testimonials
- `--prompt` widerspricht Branding (z. B. „mach es lila"): Nutzer-Prompt gewinnt, Abweichung wird im Brief dokumentiert

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
**Erstellt:** 2026-07-03 · **Stack:** Claude-Code-Skill-Pipeline (Claude als Generator) → React/Tailwind/shadcn-Output · **Branch:** dev

### Struktur (Generator-Sandwich, analog PROJ-5)
Alles Kreative macht Claude, alles Prüfbare ein deterministischer Treiber — dasselbe Muster wie der Judge-Pass in PROJ-5:

```
1. redesign.sh <run-dir>          INIT: Gate (Stufe-1-Lauf komplett? scores.json + branding/ da?)
                                  → Scaffold redesign/ anlegen → Kontext bündeln
                                  (Tokens, Report, Cai-Teilscores, Branding, --prompt aus ui-check.json)
2. (Claude) Brief-Pass            brief.md — VOR jeder Generierung: Conversion-Ziel, primärer CTA,
                                  Sektionsplan (aus Original), Brand-Entscheidungen
                                  (beibehalten/angepasst + Begründung), Anti-Slop-Constraints,
                                  Abweichungen durch Nutzer-Prompt
3. (Claude) Struktur → Content    shared/content.json — Sektionsplan + verbesserte deutsche
                                  Original-Copy (nichts erfinden) + Bild-Slot-Liste
4. (Claude) Visual-Pass ×2        safe/ + bold/ — React-Komponenten nach Rezept
                                  (recipes/safe.md bzw. recipes/bold.md) + images.md
5. redesign.sh --verify <run-dir> GATES: Ordner-/Datei-Struktur, Token-Lint (nur Farben aus
                                  tailwind-theme.css bzw. im Brief begründete), kein
                                  Google-Fonts-CDN, keine Lorem-/TODO-Reste,
                                  images.md deckt alle referenzierten Slots
                                  + mechanische Anti-Slop-Checks (aus Taste-Skill v2
                                  destilliert): CTA-Text einzeilig, kein doppelter
                                  CTA-Intent (ein Label pro Absicht), max. 2
                                  Bild/Text-Zigzag-Sektionen in Folge
```

Die Reihenfolge Struktur → Content → Visuals (Cai-Iterationsmodell) ist damit fest im Ablauf verankert, nicht nur eine Prompt-Bitte.

### Aufbau einer Variante (PM-Sicht)
```
redesign/<safe|bold>/
├── Einstiegskomponente          lädt shared/content.json + Theme
├── Sektionen laut Sektionsplan  z. B. Hero, Leistungen, Social Proof, CTA, Footer
├── components/ui/               kopierte shadcn-/Magic-UI-/Aceternity-Komponenten
└── Hintergrund-/Scroll-Effekte  nur Bold: Paper Shaders/CSS + nach React/Motion portierte
                                 Cinematic-Module (kuratiert in recipes/bold.md) — assetfrei
```
Beide Varianten teilen Content + Tokens; nur Layout-Rezept und Animations-Level unterscheiden sich.

### Daten (Run-Ordner-Kontrakt)
```
<run-dir>/redesign/
├── brief.md          Redesign-Brief (siehe Brief-Pass) — Pflicht vor Generierung
├── compare.json      Sektionsplan maschinenlesbar: Zuordnung Original↔Redesign-Sektion
│                     + 1-Satz-Begründung je Sektion (ergänzt durch PROJ-8-Design;
│                     Konsument: Sektionsvergleich in mockup.html)
├── images.md         je Bild-Slot: Platzhalter-Vermerk + fertiger Bild-Prompt
├── shared/           content.json (Sektionen + deutsche Copy) · Kopie tokens.json
│                     + tailwind-theme.css (eingefrorener Stand dieses Laufs)
├── safe/             buildfähige React-Komponenten (konservatives Facelift)
└── bold/             buildfähige React-Komponenten (mutige Neuinterpretation)

recipes/  (im Repo, versioniert wie rubrics/)
├── safe.md           Layout-Rezept + Taste-Vorgaben, Varianz niedrig, Animation dezent
└── bold.md           Layout-Rezept + Taste-Vorgaben, Varianz hoch, Animation ausgeprägt
```

### Skill-/CLI-Kontrakt
- Neuer Skill **`/ui-redesign <run-dir>`** (`.claude/skills/ui-redesign/SKILL.md`) — Stufe 1 bleibt audit-only, `/ui-check` unverändert. Headless aufrufbar (Jupiter, PROJ-14).
- Treiber `scripts/redesign.sh <run-dir>` (INIT) und `--verify <run-dir>` (Gates) · Exit 0 = ok, 1 = degradiert (z. B. Gate-Warnung), 2 = Abbruch (fehlender Stufe-1-Lauf, rote Pflicht-Gates).

### Tech-Entscheidungen
- **Generator-Sandwich statt Ein-Skript:** Generierung ist LLM-Arbeit und nicht skriptbar — aber Scaffold, Kontext-Bündelung und alle Gates sind es. Gleiches bewährtes Muster wie PROJ-5 (Judge zwischen Collect/Finalize), gleiche Testbarkeit (hermetische Suite gegen den Treiber).
- **Framework-agnostisches React statt Next.js:** Die Varianten nutzen bewusst keine Next-spezifischen APIs. Grund: PROJ-7 bündelt per web-artifacts-builder zu einer Datei (kein Next-Server), PROJ-19 deployt später echte Next.js-Sites — client-seitige React/Tailwind-Komponenten bedienen beide Abnehmer. Der PRD-Zielstack bleibt damit erreichbar, ohne PROJ-7 zu blockieren.
- **Rezepte im Repo statt externer Skills:** Die in der Spec genannten `frontend-design`-/`taste`-Skills sind auf dem VPS **nicht installiert**. Statt einer unversionierten Abhängigkeit werden die Taste-/Varianz-Vorgaben als versionierte Rezept-Dateien `recipes/{safe,bold}.md` ins Repo gelegt (Muster: `rubrics/`); die Anti-Slop-Constraints kommen aus der bestehenden `rubrics/slop.md` und werden je Lauf in `brief.md` dokumentiert (AC erfüllt). Werden externe Skills später installiert, ergänzen sie die Rezepte — der Output-Kontrakt bleibt gleich.
- **Quellmaterial für die Rezepte: Taste-Skill v2** ([Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill), MIT — geprüft 2026-07-03): Das Drei-Dial-Modell (`DESIGN_VARIANCE`/`MOTION_INTENSITY`/`VISUAL_DENSITY`, je 1–10) kalibriert Safe vs. Bold präzise — Safe ≈ Preset „Redesign preserve" (Varianz niedrig), Bold ≈ „Redesign overhaul" (+2 Varianz/+2 Motion). Anti-Default-Regeln und motivierte Motion werden destilliert (übersetzt auf Motion statt GSAP, deutsch), die mechanischen Pre-Flight-Checks wandern als deterministische Gates in den Verify-Schritt. **Nicht live installieren als Kontrakt-Abhängigkeit:** v2 ist „experimental" und ändert sich laufend — Reproduzierbarkeit (±5, PROJ-9-Deltas) verlangt eingefrorene, versionierte Rezepte. **Wichtige Unterordnung:** Die Font-/Farb-Swap-Empfehlungen des Skills (z. B. „Inter → Satoshi") widersprechen der Markentreue — Token-Gate + Brief stehen immer über den Rezepten.
- **Effekt-Vokabular für Bold: Cinematic Site Components** ([robonuggets/cinematic-site-components](https://github.com/robonuggets/cinematic-site-components), MIT — geprüft 2026-07-03): 30 assetfreie, responsive Effekt-Module (Scroll-Driven wie Sticky-Stack/Horizontal-Scroll/Curtain-Reveal/Color-Shift, Cursor-Effekte, Ambient wie Mesh-Gradient/Marquee) — genau die „unkonventionellen Layouts" der Bold-Variante, und alle Module theming per CSS-Variablen (mappt direkt auf unsere Tokens). **Als Pattern-Katalog, nicht als Drop-in:** Die Module sind Vanilla-HTML + GSAP mit Google-Fonts-/cdnjs-CDN — beides verletzt unseren Kontrakt (React/Motion, DSGVO, keine externen Requests). `recipes/bold.md` listet ein kuratiertes Effekt-Vokabular (Modul-Namen + Einsatzzweck); der Visual-Pass portiert gewählte Muster nach React/Motion, entfernt CDNs und bindet Farben an Tokens. Kuratierung nach der „Motion muss motiviert sein"-Regel: Scroll-Narrative und Ambient-Backgrounds ja, Gimmicks (Glitch, Image-Trail, Typewriter) nein. Die bestehenden Gates (kein Google-Fonts-CDN) fangen Fehlports deterministisch ab.
- **gstack bewusst nicht übernommen** ([garrytan/gstack](https://github.com/garrytan/gstack) — geprüft 2026-07-03): Workflow-Suite (23 Rollen), dupliziert den bestehenden `abc-*`-Workflow; schwerer Footprint (eigenes Setup, Auto-Update, `~/.gstack`-State, Bun-Pflicht); der Codegenerator `design-html` erzeugt proprietäres „Pretext"-HTML — inkompatibel mit dem React/Tailwind/shadcn-Kontrakt für PROJ-7. Einziges verwertbares Stück: die „AI-Slop-Blacklist" (10 Anti-Patterns) aus dessen `design-review` — fließt in die **Rezepte** ein; in `rubrics/slop.md` erst bei einem ohnehin geplanten Rubrik-Versionssprung (Rubrik-Änderung = neue Version = Benchmark-Reset).
- **Copy-Paste-Vendoring (shadcn-Modell):** Komponenten aus shadcn/Magic UI/Aceternity werden in den Variantenordner kopiert, kein Registry-Fetch zur Buildzeit → offline buildfähig, und die Kopien sind die Rohware für die Komponenten-Registry (PROJ-11).
- **Ein Content, zwei Layouts:** Beide Varianten lesen dieselbe `content.json`. So vergleichen Vorher/Nachher (PROJ-8) und Nachher-Scoring (PROJ-9) wirklich Layout-Entscheidungen statt Content-Zufall — und der Content-Pass läuft nur einmal (Token-Kosten).
- **Token-Treue als Gate, nicht als Bitte:** Der Verify-Schritt lintet deterministisch, dass nur extrahierte Farben (bzw. im Brief begründete Anpassungen) vorkommen — Markentreue wird geprüft, nicht erhofft.
- **Bilder = Platzhalter + Prompt:** keine Bild-API im MVP (0-€-Constraint); `images.md` macht die Slots später automatisierbar.
- **Buildbarkeit wird in PROJ-7 verifiziert:** Der Verify-Schritt prüft Struktur/Inhalt; der echte Build (Parcel) ist der Publish-Gate-Job von PROJ-7 — keine doppelte Build-Infrastruktur in PROJ-6.

### Dependencies
- Keine neuen System-Tools (Generator = Claude; Treiber = bash/jq wie gehabt)
- npm-Abhängigkeiten werden nur **in den generierten Varianten deklariert** (react, motion, optional `@paper-design/shaders-react`, tailwindcss); installiert/gebaut wird erst in PROJ-7

## Implementation Notes (Backend)
**Umgesetzt:** 2026-07-03 · **Branch:** dev

### Gelieferte Artefakte
- **`scripts/redesign.sh`** — deterministischer Treiber mit zwei Modi:
  - **INIT** (`<run-dir> [--force]`): Stufe-1-Gate (meta.json ok + scores.json +
    branding/) → Scaffold `redesign/` (shared/-Kopien von tokens.json +
    tailwind-theme.css) → `redesign-context.json` (Scores + Cai-Teilscores,
    Top-Befunde, Branding-Lage, user_prompt, Rezept-Version). Leere Palette ⇒
    Exit 1 (degradiert) mit `notes`.
  - **VERIFY** (`--verify <run-dir>`): 13 deterministische Gates (G1–G13, siehe
    `scripts/README.md`) → `redesign/verify.json`; rote Gates ⇒ Exit 2,
    nur Warnungen ⇒ Exit 1. Führt `status.json` → `phases.redesign` fort (Jupiter).
- **`recipes/`** — versionierte Rezepte (`VERSION` `2026.07-1`, `safe.md`,
  `bold.md`, `README.md`): Drei-Dial-Kalibrierung (Safe 3/2 · Bold 8/7),
  Layout-Familien, kuratiertes Effekt-Vokabular (Bold), Anti-Slop-Regeln;
  destilliert aus Taste-Skill v2 + gstack-Slop-Blacklist + cinematic-Modulen
  (Quellen im README). Rangordnung Tokens+Brief > Nutzer-Prompt > Rezept.
- **`.claude/skills/ui-redesign/SKILL.md`** — Orchestrator-Anweisung für Claude:
  INIT → Brief-Pass → Struktur/Content-Pass (content.json + compare.json) →
  Visual-Pass ×2 (Rezepte) → Verify → deutscher Bericht. Enthält alle
  Kontrakt-Schemata (content.json, compare.json, manifest.json, images.md,
  tokens-extra.json) + Edge-Case-Behandlung im Brief.
- **`scripts/tests/redesign_test.sh`** — hermetische QA-Suite (**46 Assertions,
  alle grün**): INIT Happy Path/Gates/Degradierung, Verify komplett grün, je ein
  Rot-Fall pro Gate (Off-Token-Hex, Tailwind-Default-Palette, Google-Fonts,
  Lorem, Slot-Deckung beidseitig, CTA-Länge, Intent-Duplikat, Zigzag,
  Brief-Abschnitt, Rezept-Versions-Konflikt, compare-Lücke), Warn-Fälle
  (Dependency-Whitelist, Sprache), status.json-Fortschreibung.
- **`scripts/README.md`** — `redesign.sh`-Abschnitt inkl. Gate-Tabelle + Kontrakte.

### Kontrakt-Erweiterungen (Run-Ordner)
`<run-dir>/redesign/`: `redesign-context.json` · `brief.md` · `compare.json`
(PROJ-8-Input) · `images.md` · `shared/` (content.json, eingefrorene Tokens,
optional tokens-extra.json) · `safe/` + `bold/` (App.jsx, manifest.json,
package.json) · `verify.json`.

### Entscheidungen / Abweichungen
- **CTA-Einzeiligkeit als Wortlimit:** „CTA-Text einzeilig" ist statisch nicht
  render-prüfbar — mechanisches Proxy-Gate: primäres Label ≤ 3 Wörter,
  Sektions-CTAs ≤ 4 (Taste-Pre-Flight-Regel).
- **Zigzag-/Layout-Prüfung über `manifest.json`:** Layout-Familien sind im
  Manifest deklariert (nicht aus JSX geraten) — deterministisch prüfbar und
  zugleich Registry-Metadaten für PROJ-11.
- **CTA-Intents deklarativ:** jedes CTA in content.json trägt `intent`;
  Gate erzwingt ein Label pro Intent (statt semantischer Intent-Erkennung).
- **`compare.json` schon in PROJ-6 gegated** (G4), da per PROJ-8-Design Teil
  des Redesign-Kontrakts.
- **Dependency-Whitelist nur Warnung** (G13): PROJ-7 entscheidet beim Build,
  was wirklich bundelbar ist.

### Acceptance Criteria — Abdeckung
- [x] `brief.md` vor Generierung (Pflicht-Abschnitte, Gate G2; Reihenfolge im Skill fest)
- [x] Struktur → Content → Visuals als getrennte Pässe im Skill-Ablauf
- [x] Skill-Sandwich: Rezepte (Taste-Destillat, Bold hoch/Safe niedrig) +
  Anti-Slop aus `rubrics/slop.md`, je Lauf in `brief.md` dokumentiert (G2)
- [x] Token-Treue erzwungen (G6 inkl. Tailwind-Default-Palette-Ban);
  deutsche Texte (G3b) + „nichts erfinden" (Skill + G8)
- [x] Komponenten shadcn/Magic UI/Aceternity als Vendoring; Backgrounds
  assetfrei (Rezept + Effekt-Whitelist, keine Bild-API)
- [x] Output `redesign/safe/` + `redesign/bold/` als React-Komponenten
  (Struktur-Gate G1; **Buildbarkeit verifiziert erst PROJ-7**)
- [x] `images.md`: Platzhalter + Bild-Prompt je Slot, Deckung beidseitig (G9)
- [x] Edge Cases im Skill-Ablauf: kein CTA (Annahme), Kontrast-Kollision
  (tokens-extra.json), wenig Content, Prompt-vs-Branding

### Test ausführen
```bash
scripts/tests/redesign_test.sh    # 46 Assertions, hermetisch (nur jq)
```

### Offen für QA (/abc-qa)
- End-to-End-Lauf gegen einen echten Run-Ordner (INIT + echte Claude-Pässe +
  Verify) — die hermetische Suite testet den Treiber, nicht die Generierung.
- Bewertung der Rezept-Qualität (Safe/Bold-Differenzierung) ist Judge-/QA-Arbeit,
  nicht skriptbar.

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
