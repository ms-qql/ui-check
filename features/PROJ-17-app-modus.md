# PROJ-17: App-Modus (Flow-Walk)

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-1 (Capture-Basis), PROJ-4 (Scoring-Engine mit Rubrik-Umschaltung)

## User Stories
- Als Auxevo-Nutzer möchte ich auch WebApps (hinter Login) auditieren, mit Usability- statt Conversion-Rubrik, um SaaS-Kunden bedienen zu können.

## Acceptance Criteria
- [ ] `--mode app`: agent-browser nutzt ein echtes Chrome-Profil (Login besteht); navigiert definierte Flows (`flows.yaml`: Schrittliste) und erstellt Snapshot + Screenshot pro Screen
- [ ] Scoring nutzt Nielsen-Heuristik-Rubrik (Navigation, Feedback, Fehlertoleranz, Konsistenz, IA) statt Cai-Conversion; Lighthouse-Dimension als „eingeschränkt aussagekräftig" markiert
- [ ] Report gruppiert Befunde pro Screen/Flow; Zustände (leer/gefüllt/Fehler) werden wo erreichbar erfasst
- [ ] Auto-Detection aus Stufe 1 (Login-Wall/App-Shell erkannt) schlägt den App-Modus aktiv vor
- [ ] Credentials werden nie gespeichert oder geloggt; nur bestehende Browser-Session wird genutzt

## Edge Cases
- Flow schlägt fehl (Element nicht gefunden): Screen wird übersprungen, Befund „Flow nicht abschließbar" mit Screenshot
- 2FA/Session-Ablauf mitten im Lauf: sauberer Abbruch mit Hinweis, Teilergebnis bleibt nutzbar

---
## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
