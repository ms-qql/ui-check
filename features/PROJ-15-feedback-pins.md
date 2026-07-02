# PROJ-15: Feedback-Pins im Mockup

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-7 (Mockup-Export), PROJ-8 (Ansichten)
- Offener Entscheidungspunkt: POST-Endpoint (kleiner Hosted-Collector) vs. mailto-Fallback — siehe Brainstorm

## User Stories
- Als Kunde möchte ich direkt im Mockup Sektionen kommentieren und Varianten bewerten, ohne ein Meeting zu brauchen.
- Als Auxevo-Nutzer möchte ich Kundenfeedback als maschinenlesbare Task-Liste erhalten, die Claude direkt abarbeiten kann.

## Acceptance Criteria
- [ ] Klick auf Sektion → Kommentar + 👍/👎 je Variante; Übersicht der eigenen Kommentare vor dem Absenden
- [ ] Export als JSON, kompatibel zum Drawbridge-`.moat`-Taskformat (comment, selector/Sektion, status)
- [ ] Übertragung: POST an konfigurierbaren Endpoint ODER mailto-Fallback mit JSON im Body (funktioniert ohne Backend)
- [ ] Empfangenes Feedback lässt sich als Task-Liste in einen Folgelauf einspeisen („Änderungswünsche umsetzen")

## Edge Cases
- Kunde sendet mehrfach: Einsendungen werden per Zeitstempel versioniert, nicht gemergt
- Kein Netz beim Kunden: Kommentare bleiben im localStorage erhalten, Hinweis zum erneuten Senden

---
## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
