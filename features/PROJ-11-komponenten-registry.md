# PROJ-11: Komponenten-Registry & Best-of-Recycling

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-6 (liefert die Sektionen, die kuratiert werden)

## User Stories
- Als Auxevo-Nutzer möchte ich gelungene Sektionen aus Läufen mit einem Schritt generalisiert ins Portfolio übernehmen, um das Rad nicht neu zu erfinden.
- Als Claude (Generierung) möchte ich die eigene Registry wie jede shadcn-Registry durchsuchen und installieren können.

## Acceptance Criteria
- [ ] Lokale Registry im shadcn-Registry-Format (`registry.json` + Komponenten-Dateien), lesbar über den offiziellen shadcn-MCP
- [ ] Metadaten je Baustein: Industrie, Kundensegment, Sektionstyp (Hero/Pricing/Trust/CTA/…), Stil (Safe/Bold), Herkunfts-Lauf, Datum
- [ ] Recycling-Schritt am Ende jedes Redesign-Laufs: Vorschlag portfoliowürdiger Sektionen; Übernahme generalisiert Kundentexte zu Platzhaltern (keine Kundendaten in der Registry)
- [ ] PROJ-6 bevorzugt bei passenden Tags Registry-Bausteine vor Neu-Generierung
- [ ] Registry-Browser-Ansicht (einfaches Markdown/HTML-Inventar) zum Durchblättern

## Edge Cases
- Kundenspezifische Inhalte (Logos, Fotos, Namen) im Baustein: Übernahme wird blockiert, bis Platzhalter ersetzt sind
- Doppelte/sehr ähnliche Bausteine: Hinweis auf Bestands-Baustein, bewusste Bestätigung nötig

---
## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
