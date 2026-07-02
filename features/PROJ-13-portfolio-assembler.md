# PROJ-13: Portfolio-Assembler (Matrix-Angebote)

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-11 (Komponenten-Registry), PROJ-12 (Branding-Bibliothek), PROJ-7 (HTML-Export)

## User Stories
- Als Auxevo-Nutzer möchte ich aus Branding-Profil × Komponenten-Set (industrie-gefiltert) in Minuten ein Mockup assemblieren, um Low-Cost-Festpreisangebote („Landing-Page-Entwurf in 24h") zu machen.

## Acceptance Criteria
- [ ] Aufruf: `--assemble --branding <slug> --industry <tag> [--sections hero,pricing,trust,cta]`
- [ ] Claude wählt passende Registry-Bausteine, wendet das Branding-Profil an, füllt Platzhalter aus kurzem Kunden-Briefing (`--prompt`)
- [ ] Output: teilbares Mockup via PROJ-7 (inkl. Gates) in < 30 min Ende-zu-Ende
- [ ] Fehlende Bausteine für eine Sektion: Neu-Generierung via PROJ-6-Mechanik als Fallback, Kennzeichnung im Ergebnis

## Edge Cases
- Branding-Profil und Baustein-Stil beißen sich (Dark-Profil, Light-Baustein): Tokens gewinnen; Baustein wird umgefärbt, nicht verworfen
- Leere Registry für die Industrie: sauberer Hinweis + kompletter Generierungs-Fallback

---
## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
