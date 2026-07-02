# PROJ-12: Branding-Profil-Bibliothek

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-3 (liefert extrahierte Token-Profile)

## User Stories
- Als Auxevo-Nutzer möchte ich Branding-Profile (Tokens, Logo, Fonts, Tonalität) pro Kunde/Industrie speichern und wiederverwenden.
- Als Auxevo-Nutzer möchte ich Auxevo selbst als erstes Profil (Seed) angelegt haben.

## Acceptance Criteria
- [ ] `branding/<slug>/`: tokens.json (DTCG), tailwind-theme.css, Logo, Fonts-Angabe, Tonalität, Quelle (extrahiert/manuell), Datum
- [ ] Auxevo-Seed wird aus `/home/dev/tools/Hal/00 Context/` (Branding.md, design-system.html) importiert
- [ ] Jeder Lauf mit PROJ-3 bietet „Als Profil speichern" an (analog Branding-Tab im UI-Mockup)
- [ ] Profile sind in PROJ-6/PROJ-13 als `--branding <slug>` auswählbar
- [ ] Profil-Übersicht (Liste mit Swatches, wie Portfolio-Screen im Mockup)

## Edge Cases
- Profil-Update nach erneutem Lauf derselben Domain: Versionierung (v1, v2), kein stilles Überschreiben
- Unvollständige Extraktion (kein Logo/Font): Profil erlaubt manuelle Ergänzung, Felder als `manuell` markiert

---
## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
