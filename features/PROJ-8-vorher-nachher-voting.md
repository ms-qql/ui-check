# PROJ-8: Vorher/Nachher-Ansicht & Varianten-Voting

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-1 (Original-Screenshots), PROJ-7 (Mockup-Export als Träger)

## Beschreibung
Erweitert das exportierte Mockup um die Verkaufs-Ansichten: A/B-Voting-Screen (Safe vs. Bold) als Einstieg, Vorher/Nachher-Split-Slider und sektionsweisen Vergleich mit Begründungen.

## User Stories
- Als Kunde möchte ich zuerst mit einem Klick sagen, welche Richtung mir gefällt, bevor ich Details sehe.
- Als Kunde möchte ich Original und Redesign nebeneinander schieben können, um den Unterschied sofort zu erfassen.
- Als Auxevo-Nutzer möchte ich pro Sektion eine 1-Satz-Begründung zeigen, um Design-Entscheidungen verhandelbar zu machen.

## Acceptance Criteria
- [ ] Einstiegs-Screen: „Welche Richtung gefällt Ihnen?" — Safe/Bold nebeneinander, Auswahl wird lokal gespeichert und auf der Detailseite vorausgewählt
- [ ] Split-Slider: Original-Screenshot vs. Redesign, synchron scrollend, Viewport-Umschalter 375/768/1440
- [ ] Sektionsvergleich: je Sektion Vorher-Ausschnitt, Nachher-Ausschnitt, Begründung (aus `brief.md`)
- [ ] Alles innerhalb der einen `mockup.html` (kein zweites Artefakt); Voting-Ergebnis exportierbar (sichtbarer „Antwort kopieren"-Button → strukturierter Text für Mail)
- [ ] Deutsche UI-Texte, verständlich für Nicht-Techniker

## Edge Cases
- Original-Screenshot deutlich länger/kürzer als Redesign: Slider alignt an Sektionsgrenzen, nicht pixelweise
- Kunde ohne JS: statische Vorher/Nachher-Bilder als Fallback sichtbar
- Nur eine Variante generiert (Safe fehlgeschlagen): Voting-Screen entfällt automatisch

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
