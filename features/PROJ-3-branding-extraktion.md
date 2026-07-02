# PROJ-3: Branding-Extraktion

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-1 (Seiten-Erfassung) — für gerendertes CSS/DOM und Copy-Texte (Tonalität)

## Beschreibung
Extrahiert das faktische Design-System der Ziel-Seite als strukturierte Tokens: Farben (mit Rollenvermutung), Fonts, Radius, Spacing, Schatten — plus Logo und eine von Claude verfasste Tonalitäts-Beschreibung. Output dient dem Redesign (Stufe 2), dem Branding-Tab der MicroApp und der Profil-Bibliothek (PROJ-12).

## User Stories
- Als Auxevo-Nutzer möchte ich das Branding einer Kundenseite als `tokens.json` + Tailwind-Theme erhalten, um Redesigns markentreu zu generieren.
- Als Auxevo-Nutzer möchte ich eine „Scraped Brand"-Karte (Fonts, Palette, Tonalität) sehen, um das extrahierte Branding auf einen Blick zu prüfen und zu korrigieren.

## Acceptance Criteria
- [ ] `tokens.json` (DTCG-orientiert): Farben mit Hex + Rollenvermutung (primary/accent/surface/text), Font-Familien mit Einsatz (Display/Text) und Fundstellen, Radius-Werte, Spacing-Raster, Schatten
- [ ] `tailwind-theme.css` (`@theme`-Variablen, Tailwind 4) wird aus den Tokens generiert
- [ ] Logo: bevorzugt via Brandfetch-Logo-API (kostenlos), Fallback DOM-Extraktion (`<img>`/SVG im Header); Datei + Quelle in `branding/`
- [ ] `branding.md`: Kurzprofil mit Palette, Fonts, Tonalität (2–4 Sätze, von Claude aus der Seiten-Copy abgeleitet, deutsch), erkannten Kontrast-Verstößen (WCAG AA)
- [ ] Extraktion ist deterministisch für Farben/Fonts/Radius (CSS-Analyse, nicht LLM); nur Rollenvermutung + Tonalität sind LLM-gestützt und als solche markiert

## Edge Cases
- CSS-in-JS / stark gehashte Klassen: Analyse läuft auf gerendertem CSS (computed styles), nicht auf Quelldateien
- Mehr als 12 Farben gefunden: Clustering auf Kern-Palette (max. 8), Rest als `extended` gelistet
- Kein Logo auffindbar: `logo: null` + Hinweis im Branding-Profil, kein Fehler
- Webfonts nicht identifizierbar (nur Fallback-Stack sichtbar): generische Familie wird mit Vermerk übernommen
- Seite mit Dark-/Light-Umschalter: es wird der Default-Zustand extrahiert, Vermerk in `branding.md`

## Technical Requirements (optional)
- Tooling: `design-extract` oder `dembrandt` (CLI, Open Source) + `@projectwallace/css-analyzer` als Fallback/Ergänzung; Brandfetch-Logo-API (Free-Tier)
- Kosten: 0 € im Basisbetrieb

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
