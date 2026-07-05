# scripts/ — UI-Check Pipeline-Skripte

CLI-Bausteine der UI-Check-Pipeline (kein FastAPI/Flutter — siehe PRD).
Jeder Schritt schreibt in den **Run-Ordner-Kontrakt** (`runs/YYYY-MM-DD-<domain>-NNN/`).

## `capture.sh` — Seiten-Erfassung (PROJ-1)

Erfasst eine öffentliche URL visuell + strukturell als Grundlage für PROJ-2/3/4.

```bash
scripts/capture.sh <url> [--out <run-dir>] [--timeout 60] [--max-height 20000]
```

- `<url>` — Ziel-URL (Protokoll optional, `https://` wird ergänzt).
- `--out <run-dir>` — Run-Ordner. Ohne Angabe wird `runs/<datum>-<domain>-NNN` automatisch angelegt.
- `--timeout` — Preflight-Timeout in Sekunden (Default 60).
- `--max-height` — Screenshot-Höhenkappung in px (Default 20000).

### Ausgabe (Run-Ordner-Kontrakt)

```
<run-dir>/
├── meta.json                URL, finale URL, HTTP-Status, Dauer, Vermerke, Screenshot-Liste
└── capture/
    ├── shot-375.png         Fullpage-Screenshot 375 px (Mobil)
    ├── shot-768.png         Fullpage-Screenshot 768 px (Tablet)
    ├── shot-1440.png        Fullpage-Screenshot 1440 px (Desktop)
    ├── snapshot.txt         A11y-Tree (token-kompakt, für den Claude-Judge in PROJ-4)
    └── dom-meta.json        Title, Meta-Description, Favicon, OG-Tags, Sektionen-Anzahl
```

### Exit-Codes

| Code | Bedeutung |
|---|---|
| `0` | Erfolgreich erfasst |
| `2` | Sauberer Abbruch: nicht erreichbar (DNS/Timeout/HTTP ≥ 400), Bot-Schutz, kein HTML-Dokument |
| `1` | Interner Fehler (fehlendes Tool, ungültige Argumente) |

Bei Exit 2 wird — sofern der Run-Ordner steht — trotzdem ein `meta.json` mit
`status: "aborted"` und deutscher `error`-Meldung geschrieben.

### Verhalten

- **Redirects:** folgt der Kette (http→https, www, Sprach-Redirect); die finale URL landet in `meta.json`.
- **Lazy-Loading:** Scroll-Durchlauf vor jedem Screenshot löst nachladende Inhalte aus.
- **Cookie-Banner:** Best-Effort-Dismiss über gängige Selektoren/Buttontexte (OneTrust, Cookiebot, Usercentrics, Didomi, „Alle akzeptieren" …). Erfolg/Misserfolg in `meta.json` unter `cookie_banner`. Banner in Cross-Origin-iFrames (z. B. Sourcepoint) werden bewusst **nicht** umgangen.
- **Bot-Schutz:** Cloudflare-/Challenge-Erkennung → sauberer Abbruch, kein Umgehungsversuch (PRD-Non-Goal).
- **Höhenkappung:** Seiten > `--max-height` werden auf die oberen `max-height` px gekappt (Vermerk in `meta.json`).
- **SPA-Leerverdacht:** sehr wenig sichtbarer Text nach Network-Idle → `content_suspicion: "spa_empty"`.

## `lh-audit.sh` — Lighthouse-Audit (PROJ-2)

Misst die technische Qualität der Ziel-URL mit der lokalen Lighthouse-CLI
(headless Chrome): Performance/Core-Web-Vitals, Accessibility, SEO, Best
Practices — maschinenlesbare Basis für das Score-Panel in PROJ-4. Läuft
parallel zu `capture.sh` (gleiche Ziel-URL, gleicher Run-Ordner).

```bash
scripts/lh-audit.sh <url> [--out <run-dir>] [--desktop] [--timeout 120]
```

- `<url>` — Ziel-URL (Protokoll optional, `https://` wird ergänzt).
- `--out <run-dir>` — Run-Ordner (i. d. R. der von `capture.sh`). Ohne Angabe
  wird `runs/<datum>-<domain>-NNN` automatisch angelegt.
- `--desktop` — zusätzlich zum Mobile-Lauf (Default) einen Desktop-Lauf messen.
- `--timeout` — Hard-Timeout je Lauf in Sekunden (Default 120).

### Ausgabe (Run-Ordner-Kontrakt)

```
<run-dir>/lighthouse/
├── lighthouse-mobile.json    Voll-Report Mobile (Beweis/Archiv)
├── lighthouse-desktop.json   Voll-Report Desktop (nur bei --desktop)
├── lh-summary.json           kompaktes Extrakt für die Pipeline (s. u.)
└── lighthouse.log            Roh-Stderr der Lighthouse-Läufe (Diagnose)
```

`lh-summary.json` (Mobile ist kanonisch, Desktop optional unter `.desktop`):

```jsonc
{
  "url": "…", "final_url": "…",
  "status": "ok",            // ok | failed
  "error": null,             // Grund bei failed
  "timestamp": "…Z", "duration_seconds": 21, "lighthouse_version": "13.4.0",
  "form_factors": ["mobile", "desktop"],
  "scores": { "performance": 100, "accessibility": 100, "best_practices": 96, "seo": 100 },
  "core_web_vitals": {       // Google-Schwellen → rating good|needs-improvement|poor
    "lcp":  { "value_ms": 751, "rating": "good" },   // ≤2500 / ≤4000
    "cls":  { "value": 0,      "rating": "good" },   // ≤0.1  / ≤0.25
    "tbt":  { "value_ms": 0,   "rating": "good" },   // ≤200  / ≤600
    "fcp":  { "value_ms": 616, "rating": "good" },   // ≤1800 / ≤3000
    "speed_index": { "value_ms": 616, "rating": "good" } // ≤3400 / ≤5800
  },
  "opportunities": [ { "id": "…", "title": "…", "savings_ms": 1234 } ], // max. 5, savings > 0
  "cookie_banner": { "dismissed": false, "note": "…" }, // aus PROJ-1 meta.json gespiegelt
  "desktop": { "scores": { … }, "core_web_vitals": { … } } // nur bei --desktop
}
```

### Exit-Codes

| Code | Bedeutung |
|---|---|
| `0` | Audit erfolgreich (`status: "ok"`) |
| `1` | Lighthouse-Absturz/Timeout **oder** interner Fehler (fehlendes Tool, ungültige Argumente) |

Bei einem Lighthouse-Fehler wird bewusst **nicht abgebrochen**: es entsteht ein
`lh-summary.json` mit `status: "failed"` + deutschem `error`-Grund, damit die
Pipeline (PROJ-4/5) degradiert weiterläuft und die Dimension als „nicht messbar"
ausweisen kann.

### Verhalten

- **Lokale CLI statt PageSpeed-API:** kein API-Key, keine Quota. Trade-off: keine
  CrUX-Felddaten (dokumentiert, später zuschaltbar).
- **Voll-JSON bleibt erhalten** → Befunde in PROJ-4 sind stets belegbar; die
  Pipeline liest nur `lh-summary.json`.
- **Chrome:** nutzt `CHROME_PATH` (falls gesetzt), sonst das erste gefundene
  `chrome`/`google-chrome`/`chromium` im PATH — z. B. das Chromium der
  agent-browser-/Playwright-Installation.
- **Cookie-Banner-Spiegelung:** liegt im Run-Ordner ein `meta.json` aus PROJ-1,
  wird dessen `cookie_banner`-Vermerk übernommen; ein nicht geschlossenes Banner
  wird als Consent-Warnung notiert (Messung ggf. verfälscht).

## `brand-extract.sh` — Branding-Extraktion (PROJ-3)

Extrahiert das faktische Design-System der gerenderten Ziel-Seite als
strukturierte Tokens (Farben mit Rollen-Vermutung, Fonts, Radius, Spacing,
Schatten) + Tailwind-4-Theme + Logo + Kurzprofil mit WCAG-AA-Kontrastverstößen.
Basis für das Redesign (Stufe 2) und die Branding-Bibliothek (PROJ-12).

```bash
scripts/brand-extract.sh <url> [--out <run-dir>] [--timeout 60] [--brandfetch-key <id>]
```

- `<url>` — Ziel-URL (Protokoll optional, `https://` wird ergänzt).
- `--out <run-dir>` — Run-Ordner (i. d. R. der von `capture.sh`). Ohne Angabe
  wird `runs/<datum>-<domain>-NNN` automatisch angelegt.
- `--timeout` — Ladewartezeit in Sekunden (Default 60).
- `--brandfetch-key <id>` — optionale Brandfetch-Client-ID (oder Env
  `BRANDFETCH_CLIENT_ID`) für die Logo-CDN; ohne Key wird der DOM-Fallback genutzt.

### Ausgabe (Run-Ordner-Kontrakt)

```
<run-dir>/branding/
├── tokens.json          DTCG-orientierte Tokens (Farben mit Rollen-Vermutung, Fonts,
│                        Radius, Spacing, Schatten) — deterministisch
├── tailwind-theme.css   @theme-Variablen (Tailwind 4), aus tokens.json generiert
├── branding.md          Kurzprofil: Palette, Fonts, WCAG-AA-Kontrast, Tonalität (LLM)
├── logo.*               Logo + Quellenvermerk (brandfetch | dom | null)
├── branding-meta.json   Status, Werkzeug, Extraktor-Stats, Logo-Quelle, Vermerke
└── raw-extract.json     Roh-Extrakt des Browser-Laufs (Beweis/Archiv)
```

### Exit-Codes

| Code | Bedeutung |
|---|---|
| `0` | Vollständig erfolgreich (Tokens **und** Logo) |
| `1` | Teilausfall: kein Logo / Seite nicht ladbar / leere Tokens — Pipeline läuft degradiert weiter, Outputs stehen trotzdem (`status: "partial"`) |
| `2` | Interner Fehler (fehlendes Tool, ungültige Argumente) |

### Verhalten & Deterministik-Grenze

- **Computed styles statt OSS-Tool-Kaskade:** Statt der im Tech-Design genannten
  (nicht installierten) Tools `design-extract`/`dembrandt`/`css-analyzer` läuft die
  Extraktion über einen eigenen, zero-dependency Extraktor (`lib/brand-extract.js`)
  auf `getComputedStyle` der gerenderten Seite — robuster und hermetisch testbar.
- **Deterministisch (reproduzierbar):** Farben (inkl. Clustering naher Nachbarn),
  Fonts (Display/Text + Fundstellen), Radius, Spacing, Schatten und die
  WCAG-AA-Kontrastprüfung. Zwei Läufe liefern identische Tokens.
- **Markierter Heuristik-Anteil:** die Rollen-Vermutung (primary/accent/surface/text)
  ist eine deterministische Heuristik und in `tokens.json` als
  `role_method: "heuristic"` gekennzeichnet — in der Orchestrierung (PROJ-5) durch
  Claude überprüf-/überschreibbar.
- **LLM-Anteil:** die Tonalität (2–4 Sätze) wird **nicht** vom Skript verfasst,
  sondern in PROJ-5 aus dem in `raw-extract.json`/`branding.md` gelieferten
  `copy_sample` von Claude abgeleitet (in `branding.md` als LLM-Anteil markiert).
- **Logo-Kaskade:** Brandfetch-Logo-CDN (nur mit Client-ID) → Inline-SVG im Header
  → DOM-`<img>`/Icon/OG-Image (Download). Kein Logo → `logo: null` (kein Fehler).
- **Cookie-Banner:** gleiche Best-Effort-Kaskade wie `capture.sh`.
- **Dark-Mode:** ist der Default-Zustand dunkel, wird der dunkle Zustand extrahiert
  und in `branding.md` + `branding-meta.json` vermerkt.
- **Farb-Clustering:** RGB-Nachbarn (Distanz < 12) werden zusammengefasst; Kern-Palette
  = Top 8 nach Häufigkeit, Rest als `extended` (max. 24 gesamt).

## `brand-lib.mjs` — Branding-Profil-Bibliothek (PROJ-12)

Versioniert Branding-Artefakte aus Läufen in `branding/<slug>/vN/`, hält
`current` als aktiven Versionszeiger und erzeugt den Katalog
`branding/index.json` + `branding/index.html` mit Swatches.

```bash
node scripts/brand-lib.mjs seed
node scripts/brand-lib.mjs save <run-dir> [--slug <slug>] [--as v2]
node scripts/brand-lib.mjs list
```

- `seed` — importiert Auxevo aus `/home/dev/tools/Hal/00 Context/`
  (`Branding.md`, `design-system.html`) als `branding/auxevo/v1/`.
- `save` — kopiert `<run-dir>/branding/` als neue Version. Existiert der Slug
  bereits, wird automatisch `v2`, `v3` usw. angelegt; explizite `--as vN`
  überschreibt nie still.
- `list` — migriert alte flache Profile (`branding/verdict/`) nach `v1/`,
  regeneriert den Katalog und rendert die statische Übersicht.

`redesign.sh <run-dir> --branding <slug>` nutzt anschließend
`branding/<slug>/current/` statt des Run-Brandings und protokolliert die Quelle in
`<run-dir>/.branding-source.json`. Der spätere PROJ-13-Assembler verwendet denselben
Profilvertrag (`branding/<slug>/current/{tokens.json,tailwind-theme.css,...}`).

## `assemble.sh` — Portfolio-Assembler (PROJ-13)

Erzeugt einen Greenfield-Run aus Branding-Profil × Industrie-Tag, ohne vorherige
Capture-/Audit-Phase. Der Assembler synthetisiert die gleiche `redesign/`-Struktur,
die `redesign.sh --verify` und `mockup-export.sh` erwarten.

```bash
scripts/ui-check.sh --assemble --branding <slug> --industry <tag> \
  [--sections hero,trust,features,pricing,cta] \
  [--prompt "<Kunden-Briefing>"] [--no-export]
```

Direkt nutzbar ist auch:

```bash
scripts/assemble.sh --branding <slug> --industry <tag>
```

### Ausgabe

```
runs/YYYY-MM-DD-assemble-<branding>-<industry>-NNN/
├── ui-check.json
├── status.json
└── redesign/
    ├── redesign-context.json
    ├── registry-config.json
    ├── registry-selection.safe.json
    ├── registry-selection.bold.json
    ├── verify.json
    ├── registry/
    ├── shared/
    │   ├── content.json
    │   ├── tokens.json
    │   └── tailwind-theme.css
    ├── safe/
    │   ├── App.jsx
    │   ├── manifest.json
    │   └── package.json
    └── bold/
        ├── App.jsx
        ├── manifest.json
        └── package.json
```

`registry-selection.*.json` markiert je Sektion `decision: "registry"` oder
`decision: "generate"`. Der Assembler erzeugt einen exportierbaren Starter-
Visual-Stand, führt `scripts/redesign.sh --verify <run>` aus und ruft danach
`scripts/mockup-export.sh <run>` auf. `--no-export` überspringt nur den finalen
Mockup-Export, lässt Verify aber laufen.

### Exit-Codes

| Code | Bedeutung |
|---|---|
| `0` | Scaffold und Registry-Auswahl erfolgreich |
| `1` | Degradiert: Registry-Fallbacks oder Export-Warnungen; Lauf bleibt nutzbar und `mockup.html` liegt an, sofern der Export keine roten Gates hatte |
| `2` | Abbruch: Eingabe ungültig oder `--registry-only` kann nicht erfüllt werden |

## `score-report.sh` — Design-Scoring & Report (PROJ-4)

Mergt die **Claude-Judge-Ausgabe** (`judge.json`) mit den Lighthouse- (PROJ-2) und
Branding-Dimensionen (PROJ-3) zum zentralen Stufe-1-Deliverable: `scores.json`
(maschinenlesbar) + `report.md` (deutsch, kundentauglich). Das Skript **bewertet
nicht** — es rechnet & rendert rein deterministisch (jq/bash), damit reproduzierbar.
Der Judge ist Claude selbst; die Orchestrierung (PROJ-5) erzeugt `judge.json` anhand
der versionierten Rubriken in `rubrics/`.

```bash
scripts/score-report.sh <run-dir> [--judge <file>] [--industry <tag>] [--weights v,s,p,a,c]
```

- `<run-dir>` — Run-Ordner aus PROJ-1 (mit `meta.json`, `status: "ok"`). **Pflicht.**
- `--judge <file>` — Judge-Ausgabe (Default `<run-dir>/judge.json`).
- `--industry <tag>` — Industrie-Tag für Benchmark/`data/runs.jsonl` (Default `unknown`).
- `--weights v,s,p,a,c` — Gewichte visuell,slop,performance,a11y,conversion
  (Default `25,15,15,15,30`). Nicht messbare Dimensionen werden **renormiert**.

### Judge-Ausgabe-Kontrakt (`<run-dir>/judge.json`)

Von PROJ-5 aus drei Judge-Pässen gegen `rubrics/` erzeugt:

```jsonc
{
  "rubric_version": "2026.07-1",     // MUSS zu rubrics/VERSION passen (sonst Abbruch)
  "language_confident": true,        // Copy-Befunde nur bei sicherer Sprache
  "app_mode": false,                 // App/Tool statt Landing? → Report-Hinweis
  "cta_present": true,               // kein CTA → Action/Logic auf Info-Aufgabe bezogen
  "visual":     { "score": 72, "findings": [ … ] },              // 0–100 (rubrics/visual.md)
  "ki_score":   3,                                               // 0–10 design-ai-check (rubrics/slop.md)
  "slop":       { "findings": [ … ] },                           // optional; Score kommt aus ki_score
  "conversion": { "clarity": 80, "credibility": 70, "logic": 65, // je 0–100 (rubrics/conversion.md)
                  "action": 55, "emotion": 60, "findings": [ … ] }
}
```

Jeder **Befund** (`findings[]`): `{ title, severity: hoch|mittel|niedrig, evidence, location, source }`.
`score-report.sh` ergänzt Befunde aus Lighthouse-Opportunities (`source: lighthouse`) und
Kontrast-Verstößen (`source: contrast`) und **verwirft unbelegte** Befunde (Beleg + Fundort Pflicht).

### Dimensionen & Gesamtscore

| Dimension | Herkunft |
|---|---|
| `visuell` | `judge.visual.score` |
| `slop` | `(10 − judge.ki_score) · 10` (invertiert: 0 Slop = 100) |
| `performance` | `lh-summary.scores.performance` (fehlt/failed → *nicht messbar*) |
| `accessibility` | `lh a11y − min(4·Kontrastverstöße, 40)` (fehlt → *nicht messbar*) |
| `conversion` | Mittel der fünf Cai-Teilscores |

Gesamtscore = gewichtetes Mittel; **nicht messbare** Dimensionen fallen aus der
Gewichtung und werden **renormiert** (kein Null-Strafe-Effekt).

### Ausgabe (Run-Ordner-Kontrakt)

```
<run-dir>/scores.json    Dimensionen · Cai-Teilscores · Gewichte (+ renormiert) ·
                         Gesamtscore · Befunde · Benchmark · Rubrik-Version
<run-dir>/report.md      Score-Panel · Befunde nach Severity · Kurzempfehlungen ·
                         Benchmark-Zeile · Meta (URL, Datum, Lauf-ID, Rubrik)
data/runs.jsonl          + 1 Zeile (append-only, nur URL-Hash — s. data/README.md)
```

### Exit-Codes

| Code | Bedeutung |
|---|---|
| `0` | Report erzeugt, alle 5 Dimensionen messbar |
| `1` | Report erzeugt, aber **degradiert** (≥ 1 Dimension nicht messbar ODER Befund-Minimum unterschritten) — Pipeline läuft weiter |
| `2` | Input-Gate/intern: kein Capture (`status ≠ ok`), fehlendes/ungültiges `judge.json`, Rubrik-Version-Konflikt, ungültige Argumente |

### Verhalten

- **Reproduzierbarkeit:** rein deterministisch — identischer Input ⇒ identischer Score
  (Judge-Streuung via Rubrik-Anker gedämpft; AC-Ziel ±5). Rubrik-Version wird erzwungen.
- **Befund-Menge:** 5–15 Befunde; bei Gesamtscore ≥ 85 sinkt das Minimum auf 3.
- **Benchmark:** erscheint erst ab n ≥ 10 Läufen gleichen `industry_tag` in `runs.jsonl`.
- **Kein Glätten:** Widersprüche Judge ↔ Lighthouse (schön, aber langsam) bleiben getrennt
  mit Quelle stehen.
- **Rubriken** liegen versioniert in `rubrics/` (`visual.md`, `slop.md`, `conversion.md`,
  `VERSION`); jede Änderung = neue Version (Benchmark-Vergleichbarkeit).

## `ui-check.sh` — Skill-Orchestrierung (PROJ-5)

Deterministischer Treiber, den der Claude-Code-Skill `ui-check`
(`.claude/skills/ui-check/SKILL.md`) aufruft. Führt die vier Schritt-CLIs in
korrekter Reihenfolge (Capture ∥ Lighthouse parallel, dann Branding) aus,
verwaltet den Run-Ordner + `status.json` und wendet die zentrale Fehlerpolitik
an. Die eigentliche Bewertung (der **Judge**) ist Claude selbst; sie liegt
zwischen den beiden Treiber-Modi.

```bash
# 1) COLLECT — Datenerfassung
scripts/ui-check.sh <url> [--industry <tag>] [--prompt "…"] [--desktop] [--out <run-dir>] [--timeout 60]
# 2) (Claude) Judge-Pass gegen rubrics/ → <run-dir>/judge.json
# 3) FINALIZE — Scoring & Report
scripts/ui-check.sh --finalize <run-dir> [--industry <tag>] [--weights v,s,p,a,c]
```

- `<url>` — Ziel-URL (Protokoll optional).
- `--industry <tag>` — Branchen-Tag für Benchmark/`runs.jsonl`. Fehlt er, wird
  `industry_source: "auto"` vermerkt (Claude schlägt den Tag im Skill vor).
- `--prompt "…"` — Nutzer-Kontext, in `ui-check.json` abgelegt und an den Judge
  durchgereicht.
- `--desktop` — zusätzlicher Lighthouse-Desktop-Lauf.
- `--out` / `--timeout` — Run-Ordner erzwingen bzw. Preflight-/Ladezeit.

#### `ui-check-auto.sh` — End-to-End für Jupiter (Collect → Judge → Finalize)

`ui-check.sh` pausiert bewusst bei `awaiting_judge` (der Judge ist Claude). Im
Terminal macht Claude den Judge-Pass selbst; **headless (Jupiter/PROJ-14)** übernimmt
das `ui-check-auto.sh`: es ruft Collect auf, löst den Judge-Pass über einen headless
`claude -p`-Lauf aus (schreibt `judge.json`) und ruft dann `--finalize`. Ohne diesen
Treiber blieben Jupiter-Läufe dauerhaft auf `awaiting_judge` (UI: „Läuft") stehen.

```
scripts/ui-check-auto.sh <url> [<ui-check.sh-Optionen>] [--judge-model <modell>] [--no-judge]
```

- `--judge-model <modell>` — Modell für den Judge-Lauf (Default `sonnet`).
- `--no-judge` — Collect ausführen, dann bei `awaiting_judge` stehen bleiben (manueller Judge-Pass).
- Zusätzlicher Exit-Code **3**: Judge-Pass fehlgeschlagen → `status: error` (kein stiller Hänger).
- Testhaken: `UI_CHECK_JUDGE_CMD` (Ersatz-Judge), `UI_CHECK_SH`, `CLAUDE_BIN`,
  `UI_CHECK_JUDGE_MODEL`, `UI_CHECK_JUDGE_TIMEOUT`.

### Ausgabe (Run-Ordner-Kontrakt, zusätzlich zu PROJ-1–4)

```
<run-dir>/status.json    Lauf-Status + je-Phase (capture/lighthouse/branding/scoring):
                         status · duration_seconds · error — Fortschrittsquelle für Jupiter (PROJ-14)
<run-dir>/ui-check.json  Kontext: url, final_url, industry_tag(+source), user_prompt,
                         desktop, rubric_version — Brücke Collect → Judge → Finalize
<run-dir>/.{capture,lighthouse,branding}.log   Roh-Stdout/-Stderr der Schritte (Diagnose)
```

### Fehlerpolitik (zentral im Orchestrator)

| Schritt | Fehler | Verhalten |
|---|---|---|
| Capture | Exit ≠ 0 | **Abbruch** des Laufs (`status: aborted`, Exit 2) — nichts zu bewerten. |
| Inhalts-Gate | `content_suspicion=spa_empty` (leere/Wartungs-/nicht-gerenderte Seite) | **Abbruch** (`status: aborted`, Exit 2) — kein bewertbarer Inhalt, verhindert Hänger am Judge-Pausenpunkt. |
| Lighthouse | Exit ≠ 0 / `status: failed` | degradieren: Perf/A11y „nicht messbar", renormiert (Exit 1). |
| Branding | Exit ≠ 0 | degradieren: Vermerk, Lauf läuft weiter (Exit 1). |
| Scoring | score-report Exit 1 / 2 | Exit 1 (degradiert) bzw. Exit 2 (Gate) durchgereicht. |

### Exit-Codes

| Code | Bedeutung |
|---|---|
| `0` | Lauf vollständig, alle Dimensionen messbar |
| `1` | Teilfehler: Lauf nutzbar, aber degradiert (Dimension „nicht messbar") |
| `2` | Abbruch: Capture-Fehler, Input-Gate, ungültige Argumente, fehlendes Tool |

### Verhalten

- **Parallelität:** Capture und Lighthouse starten gleichzeitig (beide brauchen nur
  die URL, gleicher Run-Ordner); Branding folgt nach Capture; Scoring erst nach dem
  Judge-Pass.
- **Preflight:** prüft `agent-browser`, `lighthouse`, `jq`, `curl` + die vier
  Schritt-Skripte **vor** jeder Arbeit — deutsche Installationsanleitung statt Crash
  mitten im Lauf.
- **Headless:** bei vollständigen Parametern keine interaktiven Abfragen; `status.json`
  + Exit-Codes steuern den aufrufenden Prozess (Jupiter/PROJ-14).
- **Kollisionssicherheit:** NNN-Suffix pro Tag/Domain (wie `capture.sh`); parallele
  Läufe kollidieren nicht; `runs.jsonl`-Append (durch `score-report.sh`) ist zeilenatomar.
- **Ctrl-C:** Run-Ordner bleibt mit `status: aborted` in `status.json` erhalten.
- **Testbarkeit:** `UI_CHECK_BIN` lenkt die Schritt-CLIs auf ein Stub-Verzeichnis um
  (siehe `scripts/tests/ui_check_test.sh`) — hermetischer Orchestrierungs-Test ohne
  Browser/Lighthouse/Netz.

## `redesign.sh` — Redesign-Generierung Safe+Bold (PROJ-6, Stufe 2)

Deterministischer Treiber, den der Claude-Code-Skill `ui-redesign`
(`.claude/skills/ui-redesign/SKILL.md`) aufruft. Die Generierung selbst
(Brief → Struktur/Content → Visuals) macht Claude anhand der versionierten
Rezepte in `recipes/` — der Treiber übernimmt Scaffold, Kontext-Bündelung
und alle deterministischen Gates (Generator-Sandwich, analog PROJ-5).

```bash
# 1) INIT — Gate + Scaffold + Kontext
scripts/redesign.sh <run-dir> [--force] [--branding <slug>]
# 2) (Claude) Brief-Pass       → redesign/brief.md
# 3) (Claude) Struktur/Content → redesign/shared/content.json + redesign/compare.json
# 4) (Claude) Visual-Pass ×2   → redesign/safe/ + redesign/bold/ + redesign/images.md
# 5) VERIFY — deterministische Gates
scripts/redesign.sh --verify <run-dir>
```

- `<run-dir>` — abgeschlossener Stufe-1-Lauf (`scores.json` + `branding/` Pflicht).
- `--force` — Re-INIT: überschreibt `shared/` + `redesign-context.json`,
  bereits generierte Inhalte bleiben.
- `--branding <slug>` — nutzt `branding/<slug>/current/` aus der
  Branding-Bibliothek statt `<run-dir>/branding/`.

### Ausgabe (Run-Ordner-Kontrakt)

```
<run-dir>/redesign/
├── redesign-context.json   INIT: Scores + Cai-Teilscores, Top-Befunde, Branding-Lage,
│                           user_prompt, Rezept-/Rubrik-Version, degraded/notes
├── brief.md                Brief-Pass (Pflicht-Abschnitte: Conversion-Ziel, Primärer CTA,
│                           Sektionsplan, Brand-Entscheidungen, Anti-Slop-Constraints)
├── compare.json            Zuordnung Original↔Redesign je Sektion + 1-Satz-Begründung (PROJ-8)
├── images.md               je Bild-Slot: Platzhalter-Vermerk + fertiger Bild-Prompt
├── shared/                 content.json (Sektionen + deutsche Copy, ein Content für beide
│                           Varianten) · tokens.json + tailwind-theme.css (eingefroren) ·
│                           optional tokens-extra.json (im Brief begründete Zusatzfarben)
├── safe/ · bold/           buildfähige React-Varianten: App.jsx, sections/, components/,
│                           manifest.json (variant, recipe_version, dials, sections[].layout),
│                           package.json (Dependency-Whitelist)
└── verify.json             Gate-Ergebnis (grün/gelb/rot je Check)
```

### Verify-Gates (deterministisch)

| Gate | Prüfung | rot ⇒ Exit 2 |
|---|---|---|
| G1 | Ordner-/Datei-Struktur vollständig | ✓ |
| G2 | `brief.md` enthält alle Pflicht-Abschnitte | ✓ |
| G3 | `content.json`-Kontrakt (sections, ids, primary_cta); Sprache ≠ de nur Warnung | ✓ |
| G4 | `compare.json` deckt alle Sektionen mit Begründung | ✓ |
| G5 | Manifeste: variant, `recipe_version` == `recipes/VERSION`, entry, sections | ✓ |
| G6 | Token-Lint: Hex-Farben ⊆ Tokens ∪ `tokens-extra.json` ∪ #fff/#000; keine Tailwind-Default-Palette (`bg-blue-500` …); rgb()/hsl()-Literale nur Warnung | ✓ |
| G7 | kein Google-Fonts-CDN (DSGVO) | ✓ |
| G8 | keine Lorem-/TODO-/FIXME-Reste | ✓ |
| G9 | Bild-Slots: content.json ↔ `images.md` ↔ `data-image-slot` im Code | ✓ |
| G10 | CTA-Länge: primär ≤ 3 Wörter, Sektions-CTAs ≤ 4 (Wrap-Ban) | ✓ |
| G11 | ein CTA-Label pro `intent` (ganze Seite) | ✓ |
| G12 | Zigzag-Cap: max. 2 × `split`-Layout in Folge, je Variante | ✓ |
| G13 | npm-Dependency-Whitelist | nur Warnung |
| G14 | deutsche Copy/Reports nutzen echte Umlaute statt ASCII-Umschreibungen | ✓ |

### Exit-Codes

| Code | Bedeutung |
|---|---|
| `0` | INIT vollständig bzw. alle Gates grün |
| `1` | degradiert: INIT mit Vermerk (leere Palette) bzw. nur Warn-Gates |
| `2` | Abbruch: Stufe-1-Lauf unvollständig, ungültige Argumente, ≥ 1 Pflicht-Gate rot |

### Verhalten

- **Rangordnung Markentreue:** Tokens + `brief.md` > Nutzer-Prompt > Rezept.
  Farbabweichungen nur über `shared/tokens-extra.json` mit Begründung — der
  Token-Lint erzwingt das.
- **Rezept-Versionierung:** `recipes/VERSION` wird in Kontext + Manifeste
  eingefroren; Konflikt ⇒ Gate rot (analog Rubrik-Gate in PROJ-4).
- **status.json:** führt `phases.redesign` (`awaiting_generation` →
  `ok|degraded|failed`) für Jupiter (PROJ-14) fort.
- **Buildbarkeit** prüft bewusst erst PROJ-7 (Mockup-Export-Build) — hier
  nur statisch prüfbare Kontrakte.
- **Testbarkeit:** `scripts/tests/redesign_test.sh` — hermetische Suite
  (49 Assertions) mit Fixture-Läufen, ohne Browser/Netz/Claude.

## `mockup-export.sh` — Self-contained Mockup-HTML (PROJ-7, Stufe 2)

Deterministischer Export-Treiber nach PROJ-6. Er bündelt die beiden React-Varianten
(`redesign/safe/`, `redesign/bold/`) zu einer teilbaren `mockup.html`, rendert beide
Varianten vor und stoppt bei roten Publish-Gates.

```bash
scripts/mockup-export.sh <run-dir> [--force]
```

- `<run-dir>` — Run mit vollständigem PROJ-6-Output und grünem
  `redesign/verify.json`.
- `--force` — bestehende `<run-dir>/mockup.html` überschreiben.

### Ausgabe (Run-Ordner-Kontrakt)

```
<run-dir>/mockup.html
<run-dir>/mockup/
├── gates.json          Publish-Gates mit Status und Beleg
├── build.log           npm-/Build-Harness-Output
└── build-report.json   Größen- und Asset-Treiber für Diagnose
```

### Publish-Gates

| Gate | Prüfung | Verstoß |
|---|---|---|
| M1 | Title gesetzt | rot, Exit 2 |
| M2 | Meta-Description gesetzt | rot, Exit 2 |
| M3 | Favicon inline | rot, Exit 2 |
| M4 | kein Google-Fonts-CDN | rot, Exit 2 |
| M5 | keine externen Ressourcen außer Bunny Fonts | rot, Exit 2 |
| M6 | keine Lorem-/TODO-/FIXME-Reste | rot, Exit 2 |
| M7 | No-JS-Baseline: beide Varianten vorgerendert, CTA sichtbar | rot, Exit 2 |
| M8 | interne Anker haben Ziele | rot, Exit 2 |
| M9 | Dateigröße < 5 MB | gelb, Exit 1, Promote trotzdem |
| M10 | kein horizontales Scrollen bei 375 px | rot, Exit 2 |
| M11 | interaktive Ansicht mountet beide Varianten | gelb, Exit 1 |
| M12 | PROJ-8 Voting-Screen vorhanden | rot, Exit 2 |
| M13 | `redesign/compare.json` enthält Begründungen je Vergleichs-Sektion | rot, Exit 2 |
| M14 | Split-Slider für Original-Screenshots 375/768/1440 vorhanden | rot, Exit 2; gelb bei fehlenden/teilweisen Capture-Screenshots |
| M15 | „Antwort kopieren" liefert strukturierten Text | rot, Exit 2; gelb ohne Capture-Screenshots |
| M16 | No-JS-Fallback für Vorher/Nachher sichtbar | rot, Exit 2; gelb ohne Capture-Screenshots |
| M17 | `capture/sections.json` für Sektionsvergleich verfügbar | gelb, Exit 1 |

### Verhalten

- **Build-Harness:** `scripts/lib/mockup-shell/` nutzt `esbuild`, `react-dom/server`
  und Tailwind CLI. Abhängigkeiten werden im Workspace gemerged und unter
  `~/.cache/ui-check/mockup-deps-*` gecacht; `node_modules` bleibt aus dem Repo.
- **No-JS-Baseline:** Safe und Bold stehen statisch im HTML. JavaScript blendet im
  Normalfall nur auf Tab-Modus um und mountet die interaktive React-Ansicht.
- **status.json:** führt `phases.mockup` (`ok|degraded|failed`) für Jupiter (PROJ-14)
  fort, falls die Datei im Run existiert.
- **Testbarkeit:** `scripts/tests/mockup_export_test.sh` — hermetische Suite mit
  Build- und Browser-Stubs; `MOCKUP_EXPORT_E2E=1` schaltet den echten npm/Browser-Build
  gegen Fixture-Varianten dazu.
- **QA-Stand 2026-07-03:** hermetische Suite **68/68 grün**; echter
  `MOCKUP_EXPORT_E2E=1`-Build **70/70 grün**. Regression abgedeckt: fehlende
  Capture-Screenshots degradieren M14-M17 gelb und blockieren den Export nicht mehr
  mit roten PROJ-8-Browser-Gates.

## `after-score.sh` — Nachher-Scoring / Score-Delta (PROJ-9, Stufe 2)

Deterministischer Gate-Schritt nach PROJ-7. Das Skript bewertet nicht selbst per LLM,
sondern konsumiert frische Nachher-Judge-Dateien für Safe/Bold, normalisiert sie mit
derselben Rubrik-Version wie PROJ-4 und entscheidet, welche Variante ausgeliefert wird.
Performance/Lighthouse wird für lokale Mockups bewusst als nicht vergleichbar markiert
und aus dem Delta renormiert.

```bash
scripts/after-score.sh <run-dir> [--judge-safe <file>] [--judge-bold <file>]
                           [--retry-safe <file>] [--retry-bold <file>]
                           [--retry-cmd <executable>] [--threshold 15] [--force]
```

- `<run-dir>` — Run mit `scores.json`, `report.md` und `mockup.html`.
- `--judge-safe` / `--judge-bold` — frische Judge-Ausgaben für die Varianten.
  Defaults: `<run-dir>/after-judge-safe.json` und `<run-dir>/after-judge-bold.json`.
- `--retry-safe` / `--retry-bold` — optionale Judge-Ausgaben nach einem Retry.
  Defaults: `<run-dir>/after-judge-safe-retry.json` und
  `<run-dir>/after-judge-bold-retry.json`.
- `--retry-cmd` — optionaler automatischer Retry-Hook. Wird eine Variante initial
  nicht ausgeliefert und existiert noch keine Retry-Judge-Datei, ruft das Skript
  `<executable> <variant> <run-dir> <retry-brief> <retry-judge-out>` auf. Das
  Kommando muss genau eine Retry-Judge-Datei schreiben; es wird kein `eval` genutzt.
  Alternativ kann `AFTER_SCORE_RETRY_CMD` gesetzt werden.
- `--threshold` — erforderliches Delta zum renormierten Originalscore, Default `15`.
- `--force` — bestehendes `after-scoring.json` überschreiben.

### Ausgabe (Run-Ordner-Kontrakt)

```
<run-dir>/scores-safe.json       Nachher-Score Safe inkl. Gate-Status
<run-dir>/scores-bold.json       Nachher-Score Bold inkl. Gate-Status
<run-dir>/after-scoring.json     Zusammenfassung, Gewinner, lieferbare Varianten
<run-dir>/after-score/
├── safe-first.json              initialer Safe-Versuch
├── bold-first.json              initialer Bold-Versuch
├── retry-safe.md                Feedback-Brief, falls Safe initial scheitert
└── retry-bold.md                Feedback-Brief, falls Bold initial scheitert
```

Zusätzlich werden `report.md` und `mockup.html` idempotent mit einem
`Nachher-Scoring`-Abschnitt bzw. Score-Delta-Badge angereichert. Existiert
`status.json`, wird `phases.after_scoring` für Jupiter/PROJ-14 fortgeschrieben.

### Exit-Codes

| Code | Bedeutung |
|---|---|
| `0` | mindestens eine Variante besteht das Delta-Gate |
| `1` | beide Varianten scheitern; Audit-only-Ergebnis + Fehlerbericht erzeugt |
| `2` | Input-Gate/intern: fehlende Pflichtdatei, ungültiges JSON, Rubrik-Version-Konflikt |

### Judge-Ausgabe-Kontrakt

Gleicher Kernvertrag wie PROJ-4: `rubric_version`, `visual.score`, `ki_score`,
`accessibility.score` (oder `a11y.score`) und
`conversion.{clarity,credibility,logic,action,emotion}`. Die Accessibility-Dimension
ist Pflicht, weil PROJ-9 den Vergleich über die vier nicht-Performance-Dimensionen
renormiert. Findings werden nur übernommen, wenn sie Beleg und Fundort enthalten.

### Testbarkeit

`scripts/tests/after_score_test.sh` prüft Happy Path, Gate-Fail, Retry, Audit-only,
Rubrik-Konflikt, Mockup-/Report-Anreicherung und `status.json` hermetisch ohne Browser
oder LLM.

## Voraussetzungen

- **jq** genügt für `score-report.sh` (PROJ-4) — kein Browser/Lighthouse nötig.
- **lighthouse** (npm, global) für PROJ-2:
  ```bash
  npm install -g lighthouse
  ```
- **agent-browser** (npm, global) + Chromium:
  ```bash
  npm install -g agent-browser
  agent-browser install            # lädt Chrome-for-Testing
  ```
- **curl**, **jq** (Standard-CLI-Tools).
- In Container-/VM-Umgebungen startet Chromium nur mit `--no-sandbox`. Das Skript
  setzt `AGENT_BROWSER_ARGS=--no-sandbox,--disable-dev-shm-usage` als Default;
  eine bereits gesetzte Variable wird respektiert (Override möglich).
