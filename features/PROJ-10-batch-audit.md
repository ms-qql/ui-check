# PROJ-10: Batch-Audit (Kaltakquise)

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-5 (Skill-Orchestrierung, audit-only)
- Optional: PROJ-6/7 (Hero-Appetizer im Teaser)

## Beschreibung
Nimmt eine URL-Liste (z. B. 20 Handwerker einer Stadt), führt Audit-only-Läufe seriell/nachts aus, sortiert nach Score und erzeugt pro Kandidat einen 1-Seiten-Teaser. Versand bleibt manuell (Human-in-the-Loop, Non-Goal: kein Auto-Kontakt).

## User Stories
- Als Auxevo-Nutzer möchte ich eine Stadt/Branche über Nacht scannen und morgens eine nach Potenzial sortierte Liste haben.
- Als Auxevo-Nutzer möchte ich pro vielversprechendem Kandidaten einen fertigen Teaser („Ihre Website: 38/100 — drei konkrete Probleme"), den ich manuell verschicke.

## Acceptance Criteria
- [ ] Input: `urls.txt` oder CSV (URL, optional Firmenname, Industrie-Tag); Aufruf `/ui-check --batch <datei>`
- [ ] Serielle Abarbeitung mit Fortschrittsanzeige; Einzel-Fehler (Bot-Schutz, offline) überspringen den Kandidaten, stoppen nicht den Batch
- [ ] Output: `batch-report.md` — Ranking-Tabelle (Score aufsteigend, Top-Befund je Seite) + je Kandidat `teaser-<domain>.md` (max. 1 Seite: Score, 3 konkretste Befunde, 1 Empfehlungs-Satz, deutsch)
- [ ] Optional `--appetizer N`: für die N schlechtesten Kandidaten wird nur die Hero-Sektion neu generiert und als Vorher/Nachher-Bild in den Teaser eingebettet (braucht PROJ-6/7)
- [ ] Alle Läufe landen in `runs.jsonl` → Batch füttert automatisch die Industrie-Benchmarks (PROJ-4)
- [ ] Kein automatischer Versand, keine E-Mail-Integration

## Edge Cases
- Duplikate in der Liste: werden dedupliziert (finale URL nach Redirects zählt)
- Sehr große Listen (> 50): Warnung mit Zeitschätzung; Abbruch/Resume möglich (`--resume`)
- Alle Kandidaten scheitern (z. B. Branchenverzeichnis-Deeplinks statt Homepages): Batch-Report listet Fehlgründe statt leerer Tabelle

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
