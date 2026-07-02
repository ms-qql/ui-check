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
**Erstellt:** 2026-07-02 · **Stack:** Claude-Code-Skill-Pipeline (CLI) · **Branch:** dev

### Struktur
CSS-Sammlung (gerenderte Seite) → deterministische Token-Extraktion → Rollen-Vermutung + Tonalität (Claude, als LLM-Anteil markiert) → Logo-Beschaffung → Output-Generierung.

### Daten (im Run-Ordner-Kontrakt)
```
branding/
├── tokens.json          DTCG-orientiert: Farben (mit Rollenvermutung), Fonts
│                        (Display/Text + Fundstellen), Radius, Spacing, Schatten
├── tailwind-theme.css   generierte @theme-Variablen (Tailwind 4)
├── branding.md          Kurzprofil: Palette, Fonts, Tonalität (LLM, markiert),
│                        WCAG-AA-Kontrastverstöße
└── logo.*               + Quellenvermerk (brandfetch | dom | null)
```

### CLI-Kontrakt
`brand-extract <url> --out <run-dir>` · Exit 0 = ok, 1 = Teilausfall (z. B. kein Logo — Pipeline läuft weiter).

### Tech-Entscheidungen
- **Werkzeug-Kaskade** `design-extract` → `dembrandt` → `@projectwallace/css-analyzer`: die drei jungen OSS-Tools sind unterschiedlich robust; das erste funktionierende gewinnt, die Wahl wird in `meta.json` protokolliert.
- **Deterministik und LLM-Anteile strikt getrennt:** Farben/Fonts/Radius kommen aus CSS-Analyse (reproduzierbar); nur Rollenvermutung + Tonalität sind LLM-gestützt und so gekennzeichnet.
- **DTCG-Format** wegen Wiederverwendung in der Branding-Bibliothek (PROJ-12) und im Redesign (PROJ-6).
- **Logo:** Brandfetch-Logo-API (kostenlos, 500k/Mo) mit DOM-Fallback; kein Paid-Brand-API-Zwang.

### Dependencies
- `design-extract` oder `dembrandt` (npm, MIT) · `@projectwallace/css-analyzer` (npm, MIT, Fallback)

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
