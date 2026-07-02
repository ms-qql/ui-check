# PROJ-2: Lighthouse-Audit

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- None (parallel zu PROJ-1 lauffähig; gleiche Ziel-URL)

## Beschreibung
Misst die technische Qualität der Ziel-URL mit Lighthouse (CLI, headless): Performance/Core Web Vitals, Accessibility, SEO, Best Practices — als maschinenlesbare Basis für die Dimensionen „Performance" und „Accessibility" des Score-Panels.

## User Stories
- Als Auxevo-Nutzer möchte ich belegbare Google-Metriken im Report, um Score-Aussagen gegenüber Kunden verteidigen zu können.
- Als Pipeline (PROJ-4) möchte ich normalisierte Kennzahlen (0–100 je Kategorie + CWV-Rohwerte), um sie ins Score-Panel zu übernehmen.

## Acceptance Criteria
- [ ] `lighthouse <url>` (Mobile-Emulation, Default) erzeugt `lighthouse-mobile.json` im Run-Ordner; optional `--desktop` zusätzlich `lighthouse-desktop.json`
- [ ] Extrakt `lh-summary.json` mit: 4 Kategorie-Scores (0–100), LCP, CLS, TBT, FCP, Speed Index inkl. Bewertung (good/needs-improvement/poor nach Google-Schwellen)
- [ ] Top-Opportunities (max. 5) mit geschätzter Ersparnis werden übernommen (Input für Befunde in PROJ-4)
- [ ] Lighthouse-Absturz oder Timeout: Pipeline läuft weiter; `lh-summary.json` enthält `status: failed` + Grund; Report weist die Dimension als „nicht messbar" aus
- [ ] Keine Google-API nötig (lokale CLI); kein API-Key erforderlich

## Edge Cases
- Consent-Wall verfälscht Messung: Vermerk aus PROJ-1 (`cookie_banner: not_dismissed`) wird in `lh-summary.json` gespiegelt
- SPA mit langer Hydration: Timeout 120 s, danach `status: failed`
- Weiterleitung auf andere Domain: es wird die finale URL aus PROJ-1 gemessen
- Extrem schlechte Seiten (Score 0 in einer Kategorie): gültiges Ergebnis, kein Fehler

## Technical Requirements (optional)
- Tooling: `lighthouse` (npm, global), headless Chrome
- Laufzeit: < 3 min pro URL (mobile + desktop)

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
