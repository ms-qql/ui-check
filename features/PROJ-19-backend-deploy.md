# PROJ-19: Backend-Verdrahtung & Dokploy-Deploy

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-6/7 (Gewinner-Variante), PROJ-15 (Kundenfeedback eingearbeitet)

## User Stories
- Als Auxevo-Nutzer möchte ich aus der vom Kunden gewählten Mockup-Variante ein produktives Next.js-Projekt machen (Formulare, Terminbuchung, Kontakt) und es auf Dokploy deployen.

## Acceptance Criteria
- [ ] Mockup → vollwertiges Next.js-16-Projekt (App Router, Standard-Projektstruktur aus CLAUDE.md); Funktionalität je Kundenbedarf (mind. Kontaktformular mit Spam-Schutz)
- [ ] Backend nur wo nötig: statisch bevorzugt; Formulare via FastAPI-Endpoint oder Mail-Relay (Entscheidung in /abc-architecture)
- [ ] Deploy via `/abc-deploy` auf Dokploy (docker-compose, TLS); Fonts DSGVO-konform (Bunny/self-hosted)
- [ ] Deploy bleibt human-gated: dieses Feature bereitet vor, der Nutzer löst den Deploy aus

## Edge Cases
- Kundendomain noch nicht umgezogen: Deploy auf Subdomain-Preview, Umzug dokumentiert
- Kunde will CMS-Pflege: außerhalb des Scopes (Non-Goal) — als Folgeauftrag behandeln

---
## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
