# PROJ-3: Branding-Extraktion

## Status: In Progress
**Created:** 2026-07-02
**Last Updated:** 2026-07-03

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

## Implementation Notes (Backend)
**Umgesetzt:** 2026-07-03 · **Branch:** dev

### Gelieferte Artefakte
- `scripts/brand-extract.sh` — CLI `brand-extract.sh <url> [--out <run-dir>] [--timeout] [--brandfetch-key]`.
- `scripts/lib/brand-extract.js` — deterministischer Token-Extraktor (läuft via
  `agent-browser eval --stdin` im Seitenkontext).
- `scripts/tests/brand_extract_test.sh` — Black-Box-QA gegen lokale Fixtures.
- `scripts/tests/serve_fixtures.py` — neue Routen `/branding` (bekanntes Design-System)
  + `/brand-logo.png`.
- `scripts/README.md` — Abschnitt `brand-extract.sh`.

### Output (Run-Ordner-Kontrakt)
`<run-dir>/branding/`: `tokens.json` (DTCG-orientiert), `tailwind-theme.css`
(Tailwind-4-`@theme`), `branding.md`, `logo.*`, `branding-meta.json`, `raw-extract.json`.

### Abweichungen vom Tech-Design (bewusst, dokumentiert)
- **Werkzeug statt OSS-Kaskade:** Die genannten Tools `design-extract`/`dembrandt`/
  `@projectwallace/css-analyzer` sind auf dem VPS **nicht installiert**. Statt sie
  einzuführen (junge OSS, variable Robustheit, externe Deps) extrahiert ein eigener,
  zero-dependency Extraktor über `getComputedStyle`. Reproduzierbar, hermetisch
  testbar, kein Netz. `tool: "computed-styles"` steht in `branding-meta.json`.
- **Rollen-Vermutung deterministisch statt LLM:** Als markierte Heuristik im Skript
  (`role_method: "heuristic"`) statt LLM — reproduzierbar/testbar und in PROJ-5 durch
  Claude überschreibbar. Der **Tonalitäts**-Teil bleibt LLM: das Skript liefert nur
  `copy_sample` + markierten Platzhalter; Claude ergänzt die 2–4 Sätze in PROJ-5.
- **Exit-Codes:** `0` ok · `1` Teilausfall (kein Logo / Seite nicht ladbar / leere
  Tokens — Pipeline läuft weiter) · `2` interner Fehler (Args/Tools). Spec-Kontrakt
  „0 = ok, 1 = Teilausfall" bleibt gewahrt; `2` ergänzt für Bedienfehler (analog capture.sh).

### Acceptance Criteria — Status
- [x] `tokens.json` (DTCG): Farben + Rollenvermutung, Fonts (Display/Text + Fundstellen), Radius, Spacing, Schatten
- [x] `tailwind-theme.css` (`@theme`, Tailwind 4) aus Tokens generiert
- [x] Logo: Brandfetch (mit Key) → Inline-SVG → DOM-`<img>`/Icon/OG; Datei + Quelle in `branding/`
- [x] `branding.md`: Palette, Fonts, WCAG-AA-Kontrastverstöße; Tonalität als LLM-Anteil markiert (Copy-Sample geliefert)
- [x] Deterministik für Farben/Fonts/Radius (CSS-Analyse); nur Rollenvermutung + Tonalität LLM/heuristik-markiert

### Edge Cases — abgedeckt
- CSS-in-JS / gehashte Klassen → Analyse auf computed styles (keine Quelldateien).
- >12 Farben → Clustering (RGB-Distanz < 12), Kern-Palette Top 8, Rest `extended`.
- Kein Logo → `logo: null` + Vermerk, kein Fehler (Exit 1, Pipeline läuft weiter).
- Nur Fallback-Font-Stack → generische Familie mit Vermerk in `branding.md`.
- Dark-/Light-Umschalter → Default-Zustand extrahiert, `dark_mode`-Vermerk.

## QA Test Results
**Ausgeführt:** 2026-07-03 · `scripts/tests/brand_extract_test.sh` — **43 bestanden, 0 fehlgeschlagen**

- **A Happy Path** (`/branding`): Exit 0; alle Outputs; Rollen (surface/text/primary/accent)
  korrekt; Palette enthält Kernfarben; Radius/Shadow; Fonts Georgia/Arial mit Fundstellen;
  ≥1 WCAG-AA-Verstoß (`#bbbbbb`); Tailwind-`@theme` mit `--color-*`/`--font-*`/`--radius-*`;
  DOM-Logo; Tonalität als LLM-Anteil markiert + `copy_sample`.
- **B Determinismus:** zweiter Lauf → identische `tokens.json` (ohne Zeitstempel).
- **C Kein Logo** (`/normal`): Exit 1, `status: partial`, `logo: null`, Tokens trotzdem da.
- **D Argument-Validierung:** keine URL / unbekannte Option → Exit 2, deutsche Meldung.

> Formales `/abc-qa` (Akzeptanzkriterien-Red-Team) noch offen — Backend-Selbsttest grün.

## Deployment
_To be added by /abc-deploy_
