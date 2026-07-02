# PROJ-1: Seiten-Erfassung (Capture)

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- None (erstes Glied der Pipeline)

## Beschreibung
Erfasst eine öffentliche URL visuell und strukturell als Grundlage aller weiteren Pipeline-Schritte: Fullpage-Screenshots in drei Viewports plus DOM-/Accessibility-Snapshot via `agent-browser`, abgelegt in einem standardisierten Run-Ordner.

## User Stories
- Als Auxevo-Nutzer möchte ich zu einer URL automatisch Screenshots in 375/768/1440 px erhalten, um die Seite ohne manuellen Browser-Besuch bewerten zu können.
- Als Pipeline (PROJ-4) möchte ich einen kompakten A11y-Tree-Snapshot statt rohem HTML, um token-effizient über Struktur und Inhalte zu urteilen.
- Als Auxevo-Nutzer möchte ich alle Artefakte eines Laufs in einem Run-Ordner finden, um Läufe archivieren und vergleichen zu können.

## Acceptance Criteria
- [ ] `capture <url> --out <run-dir>` erzeugt: `shot-375.png`, `shot-768.png`, `shot-1440.png` (Fullpage), `snapshot.txt` (A11y-Tree), `dom-meta.json` (Title, Meta-Description, Favicon-URL, OG-Tags, erkannte Sektionen-Anzahl)
- [ ] `meta.json` enthält: URL, finale URL nach Redirects, Timestamp, Dauer, HTTP-Status, agent-browser-Version
- [ ] Lazy-Loading wird durch Scroll-Durchlauf vor dem Screenshot ausgelöst
- [ ] Sichtbare Cookie-Banner werden per Best-Effort weggeklickt (gängige Selektoren); Erfolg/Misserfolg wird in `meta.json` vermerkt
- [ ] Nicht erreichbare URL (DNS, Timeout 60 s, HTTP ≥ 400): Abbruch mit Exit-Code ≠ 0 und deutscher Fehlermeldung („Seite nicht erreichbar: …")
- [ ] Bot-Schutz erkannt (Cloudflare-Challenge o. ä.): sauberer Abbruch mit Meldung „Seite ist bot-geschützt — Lauf nicht möglich" (kein Umgehungsversuch)

## Edge Cases
- Redirect-Ketten (http→https, www, Sprach-Redirect): finale URL wird verwendet und dokumentiert
- Sehr lange Seiten (> 20.000 px): Screenshot wird bei 20.000 px gekappt, Hinweis in `meta.json`
- Non-HTML-Ziel (PDF, Bild): Abbruch mit Meldung „Kein HTML-Dokument"
- Seite erfordert JS-Interaktion für Inhalt (SPA ohne SSR): Warten auf Network-Idle; bleibt die Seite leer, Vermerk `content_suspicion: spa_empty`
- Interstitial/Alters-Gate: wird nicht umgangen; Screenshot zeigt das Gate, Vermerk in `meta.json`

## Technical Requirements (optional)
- Tooling: `agent-browser` (npm, global), headless Chromium
- Laufzeit: < 90 s pro URL für alle drei Viewports
- Alle Meldungen auf Deutsch

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
