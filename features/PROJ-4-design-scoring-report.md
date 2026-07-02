# PROJ-4: Design-Scoring & Report

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

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

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
