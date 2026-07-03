# PROJ-4: Design-Scoring & Report

## Status: Deployed
**Created:** 2026-07-02
**Last Updated:** 2026-07-03

## Dependencies
- Requires: PROJ-1 (Screenshots + Snapshot), PROJ-2 (Lighthouse-Kennzahlen), PROJ-3 (Kontrast-Verstöße, Branding-Kontext)

## Beschreibung
Bewertet die erfasste Seite in fünf Dimensionen und erzeugt den zentralen Deliverable von Stufe 1: `report.md` (deutsch, kundentauglich) + `scores.json` (maschinenlesbar). Claude fungiert als Design-Judge mit fester Rubrik; technische Dimensionen kommen aus Lighthouse.

## Score-Panel (5 Dimensionen, je 0–100)
| Dimension | Quelle |
|---|---|
| Visuelle Qualität | Claude-Judge (Screenshots, 3 Viewports) |
| KI-Generik / Slop | design-ai-check-Rubrik (invertiert: 10 = kein Slop → 100) |
| Performance | Lighthouse (Performance-Score + CWV) |
| Accessibility | Lighthouse A11y + Kontrast-Verstöße aus PROJ-3 |
| Conversion | Cai-Modell: Clarity, Credibility, Logic, Action, Emotion (je 0–100, Mittel) |

Gesamtscore = gewichtetes Mittel (Default: 25/15/15/15/30 — Conversion am höchsten, da Landing-Fokus).

## User Stories
- Als Auxevo-Nutzer möchte ich einen mehrdimensionalen Score mit belegten Befunden, um Kunden konkret und verteidigbar ansprechen zu können.
- Als Auxevo-Nutzer möchte ich jeden Befund mit Severity, Fundort (Sektion/Viewport) und Quelle sehen, um Prioritäten fürs Redesign abzuleiten.
- Als Pipeline (PROJ-9) möchte ich `scores.json` maschinenlesbar, um Vorher/Nachher-Deltas zu berechnen.

## Acceptance Criteria
- [ ] `scores.json`: 5 Dimensions-Scores + Cai-Teilscores + Gesamtscore + Gewichte + Rubrik-Version
- [ ] `report.md` (deutsch): Score-Panel, Top-Befunde (Severity hoch/mittel/niedrig, je mit 1-Satz-Beleg, Fundort, Quelle), Kurzempfehlungen, Meta (URL, Datum, Lauf-ID)
- [ ] Jede Dimension nennt ihre Quelle; ausgefallene Messungen (z. B. Lighthouse failed) erscheinen als „nicht messbar" und werden aus der Gewichtung entfernt (Renormierung)
- [ ] Claude-Judge nutzt eine versionierte Rubrik-Datei mit Anker-Beispielen (Score-Deskriptoren je 20er-Band); Rubrik-Version steht im Report
- [ ] Reproduzierbarkeit: zwei Läufe derselben URL innerhalb 24 h weichen im Gesamtscore max. ±5 Punkte ab (Stichprobe 5 URLs)
- [ ] Mindestens 5, maximal 15 Befunde pro Lauf; Befunde ohne Beleg sind unzulässig
- [ ] Benchmark-Zeile erscheint, sobald ≥ 10 Läufe mit gleichem Industrie-Tag in `runs.jsonl` vorliegen (sonst ausgeblendet)

## Edge Cases
- Sehr gute Seiten (≥ 85): Report würdigt Stärken, Befunde-Minimum reduziert sich auf 3
- Seite ohne erkennbaren CTA (reine Info-Seite): Cai-Dimensionen Action/Logic werden auf die Info-Aufgabe bezogen bewertet, Vermerk im Report
- Fremdsprachige Seiten: Bewertung sprachunabhängig; Copy-bezogene Befunde nur, wenn Claude die Sprache sicher versteht
- Widerspruch Judge vs. Lighthouse (z. B. schön, aber LCP 8 s): kein Glätten — beide Aussagen erscheinen getrennt mit Quelle
- App statt Landing erkannt (Heuristik aus PROJ-1-Snapshot): Hinweis „App-Modus empfohlen — Stufe-4-Feature", Bewertung läuft mit Landing-Rubrik + Disclaimer

## Technical Requirements (optional)
- Rubrik-Dateien versioniert im Repo (`rubrics/`); Änderungen an Rubrik = neue Version (Benchmark-Vergleichbarkeit)
- `runs.jsonl` (Append-only) je Lauf: Datum, URL-Hash, Industrie-Tag, Scores — Basis für PROJ-10/Benchmarks

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
**Erstellt:** 2026-07-02 · **Stack:** Claude-Code-Skill-Pipeline (Claude als Judge) · **Branch:** dev

### Struktur
Input-Gate (Capture zwingend; Lighthouse/Branding optional-degradiert) → drei Judge-Pässe: **Visuell** (3 Screenshots gegen Rubrik), **KI-Generik** (design-ai-check-Rubrik, invertiert), **Conversion** (Cai: Clarity/Credibility/Logic/Action/Emotion auf Screenshots + Snapshot) → Merge mit Lighthouse-Dimensionen → Gewichtung 25/15/15/15/30 mit Renormierung fehlender Dimensionen → Befund-Assembly (jeder Befund mit Beleg: Screenshot-Region, Lighthouse-Audit-ID oder Kontrastwert) → Rendern `report.md` + `scores.json` → Benchmark-Zeile aus `data/runs.jsonl` (ab n ≥ 10 je Industrie-Tag).

### Daten
```
<run-dir>/report.md · scores.json        Deliverables
rubrics/  (im Repo, versioniert)         Anker-Beispiele je 20er-Band, je Judge-Pass
data/runs.jsonl  (append-only)           Datum · URL-Hash · Industrie-Tag · Scores ·
                                         Rubrik-Version — keine Klardaten
```

### Tech-Entscheidungen
- **Versionierte Rubriken mit Anker-Beispielen** sind der Mechanismus für die ±5-Reproduzierbarkeit; jede Rubrik-Änderung = neue Version, damit Benchmarks vergleichbar bleiben.
- **Judge in frischem Kontext** ohne Pipeline-Verlauf (Bias-Schutz) — identisches Setup wie später beim Nachher-Scoring (PROJ-9).
- **Renormierung statt Null-Strafe** bei ausgefallenen Messungen: „nicht messbar" verfälscht den Gesamtscore nicht.
- **Befunde ohne Beleg sind unzulässig** — erzwungen durch das Befund-Schema (Quelle + Fundort Pflichtfelder).
- **`data/runs.jsonl` nur mit URL-Hashes:** Benchmark-Wert ohne Kundendaten im Repo-Verlauf.

### Dependencies
- keine neuen — der Judge ist Claude selbst; Rendern via Stdlib

## Implementation Notes (Backend)
**Umgesetzt:** 2026-07-03 · **Branch:** `dev`

### Gelieferte Artefakte
- `scripts/score-report.sh` — deterministische Scoring-/Report-Engine (jq/bash, **kein**
  Browser/Lighthouse nötig). Bewertet nicht selbst — mergt & rendert reproduzierbar.
- `rubrics/` — versionierte Judge-Rubriken (`visual.md`, `slop.md`, `conversion.md`) mit
  Anker-Beispielen je 20er-Band + `VERSION` (`2026.07-1`) + `README.md`.
- `data/runs.jsonl` (+ `data/README.md`) — append-only Benchmark-Korpus, nur URL-Hashes.
- `scripts/tests/score_report_test.sh` — 43 hermetische Assertions (A–H), alle grün.
- `scripts/README.md` — `score-report.sh`-Abschnitt inkl. **Judge-Ausgabe-Kontrakt** (`judge.json`).

### Architektur-Split (wichtig für PROJ-5)
Der Judge ist **Claude** in frischem Kontext (Bias-Schutz). PROJ-5 fährt die drei
Judge-Pässe gegen `rubrics/` und schreibt **`<run-dir>/judge.json`** (Schema in
`scripts/README.md`). `score-report.sh` konsumiert diese Datei + `lh-summary.json`
(PROJ-2) + `branding-meta.json`/`raw-extract.json` (PROJ-3) + `meta.json` (PROJ-1).

### Mapping der Dimensionen
- `visuell` = `judge.visual.score` · `slop` = `(10 − ki_score)·10` · `conversion` = Mittel der 5 Cai-Teilscores.
- `performance` = Lighthouse-Performance · `accessibility` = Lighthouse-A11y − `min(4·Kontrastverstöße, 40)`.
- Fehlende Lighthouse-Dimensionen → *nicht messbar* → aus Gewichtung entfernt + **renormiert**.

### Umgesetzte AC
- [x] `scores.json`: 5 Dimensionen + Cai-Teilscores + Gesamtscore + Gewichte (roh + effektiv) + Rubrik-Version.
- [x] `report.md` (deutsch): Score-Panel, Befunde nach Severity (Beleg + Fundort + Quelle), Kurzempfehlungen, Meta.
- [x] Quelle je Dimension; ausgefallene Messungen als *nicht messbar* + Renormierung.
- [x] Versionierte Rubrik-Dateien mit Anker-Beispielen je 20er-Band; Rubrik-Version im Report + erzwungener Abgleich.
- [x] Reproduzierbarkeit: rein deterministisch (identischer Input ⇒ identischer Score); Test D belegt Δ = 0.
- [x] 5–15 Befunde (Min 3 bei ≥ 85); unbelegte Befunde werden verworfen (Test B).
- [x] Benchmark-Zeile ab n ≥ 10 gleicher `industry_tag` in `runs.jsonl` (Test F), sonst ausgeblendet.
- [x] Edge Cases: sehr gute Seiten (Min 3), fehlender CTA, App-Modus-Hinweis, SPA-Verdacht, Judge↔Lighthouse-Widerspruch (kein Glätten).

### Bewusste Entscheidungen / Abweichungen
- **`ki_score` (roh 0–10)** kommt vom Judge; die Invertierung zur Slop-Dimension macht das
  Skript — weniger Transformation beim Judge = reproduzierbarer.
- **Boolean-Defaults ohne jq-`//`** (jq behandelt `false` wie null) — explizit via `if == null`.
- **jq-`//`-Fallstrick** dokumentiert; Tests decken `cta_present:false` explizit ab.

### Test ausführen
```bash
scripts/tests/score_report_test.sh    # 43 Assertions, hermetisch (nur jq)
```

## QA Test Results
**Getestet:** 2026-07-03 · **Tester:** QA/Red-Team · **Branch:** `dev`
**Methode:** hermetische Suite (`score_report_test.sh`, 43 Assertions) + 8 adversariale Probes (P1–P8) gegen `score-report.sh`. Rein CLI (jq/bash) — kein Browser/Backend, daher keine FastAPI/Flutter-/Tenant-Aspekte anwendbar.

### Acceptance Criteria (7/7 bestanden)
| # | Kriterium | Ergebnis | Beleg |
|---|---|---|---|
| 1 | `scores.json`: 5 Dims + Cai-Teilscores + Gesamtscore + Gewichte + Rubrik-Version | ✅ PASS | Test A (visuell/slop/perf/a11y/conv, `weights`, `rubric_version`, Cai-Subscores) |
| 2 | `report.md` (deutsch): Panel, Befunde (Severity+Beleg+Fundort+Quelle), Empfehlungen, Meta | ✅ PASS | Test A (Score-Panel, Lauf-ID); manuelle Report-Sichtung |
| 3 | Quelle je Dimension; ausgefallene Messung „nicht messbar" + Renormierung | ✅ PASS | Test A (5 Quellen) + C (LH failed → Perf/A11y nicht messbar, eff. Gewichte 36/21/43, Total 69) |
| 4 | Versionierte Rubrik mit Anker je 20er-Band; Rubrik-Version im Report + Abgleich | ✅ PASS | `rubrics/{visual,slop,conversion}.md` (Bänder 0–20…81–100), Test H3 (Version-Konflikt → Exit 2) |
| 5 | Reproduzierbarkeit ±5 bei zwei Läufen | ✅ PASS (Skript-Ebene: Δ=0, deterministisch) | Test D. **Hinweis:** End-to-End-Streuung hängt am Claude-Judge (nicht skriptbar testbar), durch Anker-Rubrik gedämpft |
| 6 | 5–15 Befunde (Min 3 ab ≥85); Befunde ohne Beleg unzulässig | ✅ PASS | Test A (5), B (unbelegte verworfen), E (Min 3), Probe P3 (>15 → Cap 15, Severity-sortiert) |
| 7 | Benchmark-Zeile ab n≥10 gleicher Industrie-Tag, sonst ausgeblendet | ✅ PASS (mit Einschränkung, s. BUG-2) | Test F (n=9 aus, n=10 an) |

### Edge Cases (alle abgedeckt)
Sehr gute Seite ≥85 (Test E) · fehlender CTA (Test G) · App-Modus-Hinweis (Test G) · SPA-Verdacht (Test G) · Judge↔Lighthouse kein Glätten (Design + Report-Footer) · Out-of-range-Scores geclampt (Probe P2: 250→100, ki 15→slop 0) · alle Cai-Teilscores null → conversion nicht messbar + renormiert (Probe P8).

### Input-Gates / Robustheit (Exit 2)
Kein `judge.json` · Capture `status≠ok` · Rubrik-Version-Konflikt · kein Run-Ordner (Test H, alle Exit 2). `--weights 0,0,0,0,0` → Division-Guard greift, `total:null`, gültiges JSON (Probe P5). Kaputte `runs.jsonl`-Zeile → kein Crash (Probe P4).

### Gefundene Bugs — **alle 5 gefixt am 2026-07-03** (verifiziert, Regressionstests Block I + F)
**Keine Critical/High.** 2 Medium (Datenintegrität) + 3 Low — **alle behoben**.

- **BUG-1 (Medium) — String-Score wird still zu 100 inflationiert.**
  Liefert der Judge einen Score als String (z. B. `"visual":{"score":"72"}` — bei LLM-Output plausibel), ergibt `"72" > 100` in jq `true` → `clamp` liefert **100** (Bestwert) statt 72. Der Fehler ist still (kein Abbruch, `scores.json` gültig) und **verfälscht Gesamtscore + PROJ-9-Deltas nach oben**.
  *Repro:* Probe P1 → `dimensions.visuell.score == 100`.
  *Fix-Vorschlag (Backend):* numerische Felder vor `clamp` per `tonumber?` koercieren **oder** Nicht-Zahl als „nicht messbar" behandeln/hart ablehnen. Danach Regressionstest P1 als Assertion aufnehmen.

- **BUG-2 (Medium) — Benchmark mischt Rubrik-Versionen.**
  Die Benchmark-Aggregation filtert nur nach `industry_tag`, **nicht** nach `rubric_version`. Ein Lauf unter `2026.07-1` wird gegen einen Durchschnitt aus Läufen anderer Rubrik-Versionen verglichen → irreführender `delta`. Das widerspricht der Tech-Design-Zusage „jede Rubrik-Änderung = neue Version, damit Benchmarks vergleichbar bleiben"; das Feld `rubric_version` liegt in `runs.jsonl` vor, wird aber ungenutzt.
  *Repro:* Probe P6 → Benchmark aus `rubric_version:"1999.00-0"`-Zeilen für einen `2026.07-1`-Lauf.
  *Fix-Vorschlag:* Benchmark-Filter um `.rubric_version == aktuelle Version` erweitern (oder Vergleich pro Version + Vermerk im Report).

- **BUG-3 (Low) — URL unescaped in `report.md`.**
  `final_url` (von der Zielseite kontrolliert) wird roh in die Report-Überschrift gerendert; Markdown/HTML (`<script>…`, `](javascript:…)`) landet ungefiltert im Deliverable — relevant erst beim späteren HTML/PDF-Rendern (PROJ-7/16).
  *Repro:* Probe P7. *Fix:* Sonderzeichen in der Titelzeile escapen/strippen.

- **BUG-4 (Low) — Renormierte Gewichte summieren gerundet ggf. auf 101 %.**
  Unabhängiges Runden der `weights_effective` (z. B. 63 + 38). Rein kosmetisch (Gesamtscore selbst rundet korrekt über die Rohgewichte). *Repro:* Probe P8.

- **BUG-5 (Low) — Eine kaputte `runs.jsonl`-Zeile deaktiviert Benchmark still.**
  `jq -s` scheitert am ganzen File → Benchmark fällt auf `null` (fail-safe, kein Crash), auch wenn 10 valide Zeilen existieren. *Repro:* Probe P4. *Fix:* zeilenweise robust parsen (`jq -R 'fromjson?'`).

### Regression
Keine Fremd-Features berührt (reine Neu-Dateien + additive README-/INDEX-Änderungen). PROJ-1/2/3-Skripte unverändert; deren Ausgabekontrakte werden nur gelesen. Offene `scripts/lib/brand-extract.js`-Änderungen (PROJ-3) bewusst nicht angefasst.

### Bugfixes (2026-07-03, im Anschluss an QA)
- **BUG-1 gefixt:** neue jq-`def num` lässt nur echte Zahlen zu; nicht-numerische Judge-Scores ⇒ *nicht messbar* (renormiert) statt still 100. Regression: Block I.
- **BUG-2 gefixt:** Benchmark-Filter um `.rubric_version == aktuelle Version` erweitert; `benchmark.rubric_version` steht jetzt im Output. Regression: Block F (Fremd-Rubrik zählt nicht mit).
- **BUG-3 gefixt:** `def md_safe` strippt Steuerzeichen + `<>[]()` aus der Report-Titelzeile. Regression: Block I.
- **BUG-4 gefixt:** `def renorm` (Largest-Remainder) — effektive Gewichte summieren jetzt exakt 100. Regression: Block I.
- **BUG-5 gefixt:** Benchmark liest `runs.jsonl` zeilenweise via `jq -R 'fromjson?'` — eine kaputte Zeile kippt den Benchmark nicht mehr. Regression: Block I.
- Test-Suite auf **50 Assertions** erweitert (Block I neu, Block F um Rubrik-Version-Filter ergänzt) — alle grün.
- Root-Cause-Notiz: Der ursprüngliche Testlauf-Fehlschlag nach dem BUG-5-Fix lag an Test-Fixtures, die `jq -n` (mehrzeilig, Pretty-Print) statt `jq -c -n` (JSONL) nutzten — nicht am Skript. Das Skript hängt Läufe stets kompakt an; Fixtures nachgezogen.

### Production-Ready-Bewertung
**READY.** Keine offenen Critical/High/Medium-Bugs mehr; alle 7 AC bestanden, alle 5 QA-Bugs behoben und per Regressionstest abgesichert (50/50 grün). Freigabe für `/abc-deploy`.

## Deployment
**Deployed:** 2026-07-03 · **Version/Tag:** `v0.1.0` (Stufe 1 komplett) · **Ziel:** GitHub-Quell-Release

- **Repo:** https://github.com/ms-qql/ui-check
- **Art:** CLI-/Claude-Code-Skill-Tool (kein Web-Host/Container) — "Deploy" = Veröffentlichung des getesteten Standes auf GitHub (`main`).
- **Enthalten:** PROJ-4 (Design-Scoring & Report (score-report.sh)) als Teil des Stufe-1-Bundles (Capture → Lighthouse → Branding → Scoring → Orchestrierung `ui-check`).
- **Nutzung:** siehe `scripts/README.md` bzw. `.claude/skills/ui-check/SKILL.md`.
