# PROJ-14: Jupiter-MicroApp-UI

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-5 (headless aufrufbarer Skill); sinnvoll erst mit PROJ-6–9 (sonst nur Audit-Ansichten)
- Referenz: `design/ui-mockup.html` (v0.2 — genehmigtes UI-Design)

## User Stories
- Als Auxevo-Nutzer möchte ich UI-Check aus Jupiter heraus starten (URL + Modus + Prompt-Feld) und Ergebnisse dort ansehen, statt im Terminal zu arbeiten.

## Acceptance Criteria
- [ ] Integration nach PROJ-53-Muster (Buch-Nuggets): MicroApp ruft den Skill headless auf, zeigt Fortschritt und Ergebnis
- [ ] Screens gemäß Mockup: Dashboard (URL, Modi, Prompt-Feld, Lauf-Historie), Audit-Report (Score-Ring, 5 Dimensionen, Befunde), Branding (Scraped-Karte), Vorher/Nachher, Portfolio
- [ ] Light/Dark-Toggle konsistent mit Jupiter
- [ ] Lauf-Historie aus `runs.jsonl`; Öffnen eines Laufs zeigt dessen Artefakte
- [ ] Deutsche UI durchgängig

## Edge Cases
- Lauf läuft noch (bis 10 min): Fortschrittsanzeige mit Phasen, kein UI-Freeze; Abbruch möglich
- Alte Läufe mit älterer Rubrik-Version: Version wird angezeigt, Scores nicht stillschweigend vergleichbar gemacht

---
## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
