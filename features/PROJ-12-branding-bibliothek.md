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
**Erstellt:** 2026-07-05 · **Stack:** Bash-/Node-CLI-Pipeline (kein FastAPI/Flutter — lokales UI-Check-Toolkit) · **Branch:** dev

### Ausgangslage (was schon existiert)
- `branding/<slug>/` **existiert bereits** als Ad-hoc-Konvention aus PROJ-11 (`verdict`, `meridian`) und trägt exakt den Ziel-Kontrakt: `tokens.json` (DTCG), `tailwind-theme.css`, `branding.md`, `logo.*`, `fonts/`. PROJ-12 **formalisiert** diesen Ordner zur Bibliothek — kein Neubau.
- PROJ-3 (`scripts/brand-extract.sh`) schreibt pro Lauf `runs/<run>/branding/{tokens.json, tailwind-theme.css, branding.md, logo.*, branding-meta.json, raw-extract.json}`. Die Run-Tokens sind bereits rollenbenannt (`color.primary/surface/…`, `role_method: heuristic`) — nah am Profil-Format.
- Redesign (PROJ-6, `scripts/redesign.sh`) zieht Branding **aktuell aus dem Run** (`runs/<run>/branding/…` → `redesign/shared/`). `scripts/registry-select.mjs` mappt Run-Tokens per Luminanz-Heuristik auf Registry-Semantik.
- Template-Profile referenzieren ihr Branding über `template.json → meta.branding = "<slug>"`.

**Kern-Lücke, die PROJ-12 schließt:** Es gibt keinen Katalog, keine Versionierung, keinen Auxevo-Seed und keine Möglichkeit, ein gespeichertes Profil per `--branding <slug>` **statt** des Run-Brandings in Redesign/Assembler einzuspeisen.

### A) Struktur (Verzeichnis-Baum statt UI-Komponenten)
```
branding/
├── index.json                     ← NEU: Katalog aller Profile (Quelle der Wahrheit für Listing/Auswahl)
├── auxevo/                         ← NEU: Seed (aus Hal 00 Context importiert)
│   ├── profile.json               ← NEU: Metadaten (slug, name, industrie, tonalität, quelle, datum, aktive Version)
│   ├── v1/                         ← Versionsordner (kein stilles Überschreiben)
│   │   ├── tokens.json  ├── tailwind-theme.css  ├── logo.svg
│   │   ├── branding.md  └── fonts/
│   └── current → v1                ← Symlink auf aktive Version
├── verdict/  (Bestand → in v1/ + profile.json überführt)
└── meridian/ (Bestand → in v1/ + profile.json überführt)
```
Profil-Übersicht (AC „Liste mit Swatches") = statische HTML wie `registry-inventory.mjs` (`scripts/registry-inventory.mjs` als Vorlage) → `branding/index.html` mit Farbfeldern, Logo, Fonts, Version, Quelle.

### B) Datenmodell (Klartext)
**Jedes Profil (`profile.json`):** slug · Anzeigename · Industrie/Tags · Tonalität · Quelle (`extrahiert` | `manuell` | `seed`) · Ursprungs-Domain+Run (falls extrahiert) · Erstell-/Änderungsdatum · aktive Version · Versionsliste.
**Jede Version (`v<n>/`):** die 5 Bestands-Artefakte (tokens/theme/logo/branding.md/fonts). Fehlende Extraktions-Teile (kein Logo/Font) werden im Profil als `"logo": {"status":"manuell"}` markiert, nicht erfunden.
**Katalog (`index.json`):** Array {slug, name, tags, aktive Version, Swatch-Hauptfarben, logo-Pfad} — von Listing & `--branding`-Auflösung gelesen, deterministisch aus den `profile.json` neu erzeugbar.

### C) CLI-Oberfläche (Befehle statt REST-Endpoints)
- `scripts/brand-lib.mjs seed` → importiert Auxevo aus `/home/dev/tools/Hal/00 Context/` (Branding.md, design-system.html) als `branding/auxevo/v1/`.
- `scripts/brand-lib.mjs save <run-dir> [--slug <slug>] [--as v2]` → kopiert `runs/<run>/branding/` in `branding/<slug>/v<n>/`, schreibt `profile.json`/aktualisiert `index.json`. Existiert der Slug → **neue Version** (v2…), kein Überschreiben (Edge Case).
- `scripts/brand-lib.mjs list` → regeneriert `index.json` + `index.html` (Swatch-Liste).
- **Integration `--branding <slug>`** in `redesign.sh`/Assembler: statt `runs/<run>/branding/` wird `branding/<slug>/current/` als Branding-Quelle nach `redesign/shared/` kopiert. Fällt der Slug weg → Bestandsverhalten (Run-Branding). Ein `.branding-source.json` im Run protokolliert, welches Profil/Version verwendet wurde.
- „Als Profil speichern"-Angebot am Ende jedes PROJ-3-Laufs: `ui-check`-Orchestrierung (PROJ-5) gibt den Hinweis + fertigen `brand-lib save`-Befehl aus (analog Branding-Tab im Mockup) — kein interaktiver Prompt in headless-Läufen.

### D) Tech-Entscheidungen (WARUM)
1. **`branding/` bleibt der Bibliotheks-Root** (nicht `registry/` oder neu). Es existiert schon, PROJ-11 und `registry-select.mjs`/`template.json` referenzieren diese Slugs bereits — ein Umzug bräche Bestand ohne Mehrwert. *Empfehlung, Freigabe nötig.*
2. **Versionierung als Unterordner `v1/ v2/` + `current`-Symlink** (nicht Suffix-Dateien, nicht Git-only). Erfüllt „kein stilles Überschreiben" sichtbar im Dateisystem, hält Artefakt-Sätze zusammen und lässt `--branding <slug>` stets auf `current` zeigen. Rollback = Symlink umhängen. *Empfehlung, Freigabe nötig.*
3. **`index.json` ist abgeleitet, nicht handgepflegt** — jederzeit aus den `profile.json` regenerierbar (`list`), so kann keine Divergenz entstehen.
4. **Node-Skript (`.mjs`) statt Bash** für `brand-lib`, weil es JSON liest/schreibt/mergt und Swatch-HTML rendert — konsistent mit `registry-*.mjs`. Extraktion selbst bleibt in `brand-extract.sh` (unverändert).
5. **Speichern = Kopie des Run-Outputs**, keine Re-Extraktion. Das Run-`branding/` ist bereits der fertige Artefakt-Satz; „save" ist reines Promoten + Metadaten. Token-Rollen-Mapping (Heuristik → Semantik) bleibt bei der Extraktion/`registry-select`, nicht doppelt in der Bibliothek.
6. **Kein Backend/DB/MinIO/Auth** — Single-User-Toolkit, alles Dateisystem-basiert und git-versionierbar. (Die globalen Stack-Defaults greifen für dieses Projekt bewusst nicht.)

### E) Abhängigkeiten
- Keine neuen Runtime-Pakete. Node ≥ genutzte Version (bereits für `registry-*.mjs` vorhanden), `jq`/Bash wie im Bestand. Seed-Import liest zwei vorhandene Hal-Dateien (kein Netz).

### Offene Punkte für die Freigabe
- **D1** `branding/` als Root bestätigen (vs. Umbenennung).
- **D2** Versionsschema `vN/`+`current`-Symlink bestätigen (vs. flaches Feld in `profile.json`).
- Bestätigt → Übergabe an `/abc-frontend` bzw. direkt `/abc-backend` (hier: Skript-Implementierung `brand-lib.mjs` + `--branding`-Verdrahtung).

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
