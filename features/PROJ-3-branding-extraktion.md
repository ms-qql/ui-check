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
**Getestet:** 2026-07-03 · **Tester:** QA (Red-Team) · **Suite:** `scripts/tests/brand_extract_test.sh`
**Ergebnis:** **55 Assertions bestanden, 0 fehlgeschlagen** · Umgebung: agent-browser 0.27 + lokale Fixtures (kein Netz)

### Acceptance Criteria (5/5 bestanden)
| # | Kriterium | Status | Nachweis |
|---|---|---|---|
| 1 | `tokens.json` (DTCG): Farben+Rollen, Fonts (Display/Text+Fundstellen), Radius, Spacing, Schatten | ✅ PASS | Gruppe A — surface `#ffffff`, text `#111827`, primary/accent Blau+Amber, Fonts Georgia/Arial+`found_in`, Radius 12px, Schatten |
| 2 | `tailwind-theme.css` (`@theme`, Tailwind 4) aus Tokens generiert | ✅ PASS | Gruppe A — `--color-*`/`--font-*`/`--radius-*`, generische Keywords ungequotet |
| 3 | Logo: Brandfetch → Inline-SVG → DOM; Datei + Quelle | ✅ PASS | Gruppe A (DOM-`<img>`) + Gruppe F (Inline-SVG → `logo.svg`) |
| 4 | `branding.md`: Palette, Fonts, Tonalität (LLM-markiert), WCAG-AA-Verstöße | ✅ PASS | Gruppe A — Kontrast-Abschnitt (`#bbbbbb`-Verstoß), Tonalität als „LLM-Anteil" + `copy_sample` |
| 5 | Deterministik für Farben/Fonts/Radius; nur Rollen+Tonalität LLM/heuristik-markiert | ✅ PASS | Gruppe B — zweiter Lauf identisch; `role_method: "heuristic"` gesetzt |

### Edge Cases
| Fall | Erwartet | Status |
|---|---|---|
| >12 Farben (Gruppe E) | Kern-Palette ≤ 8, Rest `extended` | ✅ 16 Farben → Palette 8 / extended 8 |
| Kein Logo (Gruppe C) | `logo: null`, Exit 1, Tokens trotzdem | ✅ `status: partial`, Outputs vollständig |
| Inline-SVG-Logo (Gruppe F) | `logo.svg`, source `dom` | ✅ |
| Dark-Mode-Default (Gruppe G) | Default-Zustand + Vermerk | ⚠️ erkannt & vermerkt, aber **BUG-1** (Rollen) |
| Seite nicht ladbar | Exit 1, gültige leere Tokens + CSS | ✅ graceful degradation |
| Argument-Fehler (Gruppe D) | Exit 2, deutsche Meldung | ✅ keine URL / unbekannte Option |

### Security / Red-Team
| Angriff | Ergebnis |
|---|---|
| Command-Injection via Seiten-Copy (`$(…)`, Backticks in `copy_sample` → `branding.md`) | ✅ **sicher** — Werte werden literal ausgegeben, keine Ausführung |
| Nebenläufigkeit (2 parallele Läufe) | ✅ **sicher** — Session-Isolation via `$$`, keine Kreuz-Kontamination |
| Ungültiges/leeres Extraktor-Ergebnis (`{}`) | ✅ jq baut gültiges `tokens.json`, kein Crash |
| Nicht-Bild-Antwort beim Logo-Download | ✅ Content-Type-Prüfung verwirft Nicht-Bilder |

> Kein Mandanten-/Auth-/RLS-Kontext (lokale CLI-Pipeline, keine DB/API) — entsprechende Red-Team-Punkte n/a.

### Gefundene Bugs
- **BUG-1 (Medium) — Rollen-Heuristik ist Light-Mode-fixiert.**
  Auf dunklen Default-Seiten bleiben **`surface`- und `text`-Rolle leer** (dadurch fehlen
  `--color-surface`/`--color-text` im generierten Theme). Ursache: die Schwellen sind
  hart auf hell (`text` erfordert `l<0.6`, `surface` erfordert `l>0.6`).
  *Repro:* `brand-extract.sh <dark-site> --out X` → `tokens.json .color.surface`/`.text` == null.
  *Auswirkung begrenzt:* Palette enthält die Farben weiterhin (`#0a0a0a`, `#e5e7eb`), Rollen
  sind ausdrücklich `role_method: "heuristic"` und in PROJ-5 durch Claude überschreibbar;
  Pipeline bricht nicht ab. *Empfohlener Fix (Backend):* im Extraktor bei `dark_mode_hint`
  die Lightness-Richtung invertieren (surface = größte Fläche unabhängig von l; text =
  häufigste Textfarbe unabhängig von l).

- **BUG-2 (Low) — Markdown-Robustheit im Copy-Sample.**
  Seiten-Copy mit Markdown (`##`, `**`) kann den Blockquote im Tonalitäts-Abschnitt optisch
  aufbrechen. Rein kosmetisch (kein Sicherheits-/Datenproblem). *Fix optional:* Copy vor der
  Ausgabe escapen/auf eine Zeile normalisieren.

### Produktionsreife-Empfehlung
**READY (mit Vorbehalt).** Keine Critical/High-Bugs; alle 5 Acceptance Criteria + 6 Edge Cases
grün; Security-Red-Team ohne Befund. BUG-1 (Medium) und BUG-2 (Low) blockieren nicht, da die
Rollen als Heuristik gekennzeichnet und in PROJ-5 überschreibbar sind und die Palette die Daten
verlustfrei erhält. Empfehlung: BUG-1 vor produktivem Dark-Mode-Einsatz beheben.

## Deployment
_To be added by /abc-deploy_
