# PROJ-18: Design-Trend-Radar

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-11 (Registry als Ziel der Kandidaten)

## User Stories
- Als Auxevo-Nutzer möchte ich wöchentlich Layout-Muster von Award-Seiten (awwwards, godly.website) als Registry-Kandidaten vorgeschlagen bekommen, damit mein Portfolio nicht altert.

## Acceptance Criteria
- [ ] Wöchentlicher Cron (Claude-Code-Schedule): scannt 2–3 Award-Quellen, extrahiert Layout-Muster als beschriebene Wireframe-Skizzen (keine 1:1-Kopien, keine Assets Dritter)
- [ ] Kandidaten landen in `registry/candidates/` mit Trend-Tag + Quelle; Übernahme in die Registry bleibt manuell kuratiert (PROJ-11-Gate)
- [ ] Wochen-Digest (Markdown): neue Muster, je 1 Absatz + Skizze

## Edge Cases
- Quelle nicht erreichbar/Layout geändert: Digest vermerkt Ausfall, Cron läuft weiter
- Urheberrecht: nur Muster-Beschreibungen und eigene Nachbauten, nie kopierte Assets/Code Dritter

---
## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
