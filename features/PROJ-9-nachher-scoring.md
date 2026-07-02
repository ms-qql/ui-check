# PROJ-9: Nachher-Scoring (Score-Delta)

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-4 (Scoring-Engine), PROJ-7 (gebautes Mockup als Bewertungsobjekt)

## Beschreibung
Jagt die generierten Varianten durch dieselbe Scoring-Pipeline wie das Original. Das Delta („38 → 86") ist zugleich QA-Gate der Generierung und zentrales Verkaufsargument im Report/Mockup.

## User Stories
- Als Auxevo-Nutzer möchte ich belegen können, dass das Redesign messbar besser ist — mit derselben Methodik wie beim Audit.
- Als Pipeline möchte ich schwache Generierungen erkennen und neu anstoßen, bevor der Kunde sie sieht.

## Acceptance Criteria
- [ ] Beide Varianten werden lokal gerendert (headless) und mit identischer Rubrik-Version bewertet wie das Original; Ergebnis in `scores-safe.json` / `scores-bold.json`
- [ ] QA-Gate: Variante mit Gesamtscore < Original + 15 wird als „nicht ausgeliefert" markiert; ein automatischer Retry mit Feedback aus den Befunden (max. 1 Retry pro Variante)
- [ ] Score-Delta erscheint in `report.md` und im Mockup (Badge „38 → 86")
- [ ] Lighthouse-Dimension wird für lokale Mockups als „nicht vergleichbar" behandelt (kein echtes Hosting) und aus dem Delta-Vergleich renormiert — Vergleich läuft über die 4 übrigen Dimensionen

## Edge Cases
- Beide Varianten scheitern am Gate auch nach Retry: Lauf endet mit Audit-only-Ergebnis + Fehlerbericht statt schlechtem Mockup
- Judge bewertet eigenes Werk (Bias): Nachher-Scoring läuft mit frischem Kontext (kein Zugriff auf Generierungs-Verlauf), Rubrik-Anker identisch

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
