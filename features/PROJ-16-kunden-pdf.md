# PROJ-16: Kunden-PDF (Mail-fertiger Report)

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-4 (Report-Inhalte); optional PROJ-9 (Score-Delta), PROJ-8 (Vorher/Nachher-Bilder)

## User Stories
- Als Auxevo-Nutzer möchte ich aus einem Lauf ein gebrandetes PDF (Auxevo-CI) erzeugen, das ich direkt an den Kunden mailen kann.

## Acceptance Criteria
- [ ] `--pdf` erzeugt aus `report.md` + Screenshots ein PDF via vorhandenem pdf-Skill (Bilder eingebettet, self-contained)
- [ ] Auxevo-Branding (Logo, Farben aus PROJ-12-Seed); Kundenlogo optional auf Titelseite
- [ ] Kundentaugliche Sprache: keine internen Metriken/Rubrik-Details, max. 6 Seiten
- [ ] Vorher/Nachher-Bild auf Seite 1, wenn Redesign vorliegt

## Edge Cases
- Lauf ohne Redesign (audit-only): PDF ist reiner Befund-Report mit Empfehlungs-Seite
- Sehr lange Befundlisten: Top 8 im PDF, Rest als „weitere Punkte im Gespräch"

---
## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
