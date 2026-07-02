# PROJ-7: Mockup-Export (Self-contained HTML)

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-6 (Redesign-Varianten als React-Code)

## Beschreibung
Bündelt die Redesign-Varianten via web-artifacts-builder (Parcel) zu **einer** statischen HTML-Datei, die ohne Server/Deployment per Mail oder Link teilbar ist. Vor dem Export laufen automatische Publish-Gates (Cai-Checklisten).

## User Stories
- Als Auxevo-Nutzer möchte ich das Mockup als eine Datei verschicken können, damit der Kunde es ohne Infrastruktur im Browser öffnet.
- Als Auxevo-Nutzer möchte ich, dass kein Mockup mit vermeidbaren Mängeln (fehlender Title, kaputtes Mobile-Layout) das Haus verlässt.

## Acceptance Criteria
- [ ] `mockup.html`: self-contained (CSS/JS inlined, Bilder base64), < 5 MB, offline lauffähig, keine externen Requests außer Bunny Fonts (oder Fonts subsettet inlined)
- [ ] Enthält beide Varianten (Safe/Bold) mit Umschalter; responsiv 375–1440 px
- [ ] Publish-Gates (automatisch geprüft, Lauf bricht bei Rot ab): Title gesetzt, Meta-Description, Favicon, Mobile-Layout ohne horizontales Scrollen (375 px), alle internen Anker funktionieren, keine Platzhalter-Lorem-Reste
- [ ] Gate-Ergebnis als `gates.json` im Run-Ordner (grün/rot je Check)
- [ ] DSGVO: keine Google-Fonts-CDN-Referenzen (Gate-Check)

## Edge Cases
- Bundle > 5 MB (viele Bilder): Bilder werden komprimiert/skaliert; hilft das nicht, Warnung + Angabe des Treibers
- Kunde öffnet in Outlook-Vorschau/altem Browser: Baseline funktionsfähig ohne JS (Inhalte sichtbar, nur Interaktionen degradieren)
- Font nicht über Bunny verfügbar: Subset self-hosted inlined statt CDN-Fallback auf Google

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
