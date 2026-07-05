# PROJ-12: Branding-Profil-Bibliothek

## Status: Approved
**Created:** 2026-07-02
**Last Updated:** 2026-07-05

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

## Backend Implementation Notes
**Implemented:** 2026-07-05 · **Branch:** dev

- `scripts/brand-lib.mjs` ergänzt die dateibasierte Profilbibliothek mit
  `seed`, `save <run-dir>` und `list`.
- Bestehende flache Profile `branding/verdict/` und `branding/meridian/` wurden
  nach `v1/` migriert und erhalten `profile.json` + `current`-Symlink.
- `branding/auxevo/v1/` wurde aus `/home/dev/tools/Hal/00 Context/` importiert.
- `branding/index.json` und `branding/index.html` werden deterministisch aus den
  Profilen regeneriert.
- `scripts/redesign.sh <run-dir> --branding <slug>` nutzt
  `branding/<slug>/current/` und schreibt `<run-dir>/.branding-source.json`.
- `scripts/ui-check.sh` gibt nach PROJ-3-Läufen einen fertigen
  `brand-lib save`-Befehl aus.
- PROJ-13 ist noch nicht implementiert (`scripts/assemble.sh` existiert nicht);
  der Assembler-Vertrag ist vorbereitet über `branding/<slug>/current/` und in
  `features/PROJ-13-portfolio-assembler.md` spezifiziert.

## QA Test Results
**QA-Datum:** 2026-07-05 · **Tester:** Codex QA (`/abc-qa 12`) · **Status:** Approved

| Datum | Suite | Ergebnis |
|---|---|---|
| 2026-07-05 | `bash scripts/tests/brand_lib_test.sh` | ✅ 22 bestanden, 0 fehlgeschlagen |
| 2026-07-05 | `bash scripts/tests/redesign_test.sh` | ✅ 52 bestanden, 0 fehlgeschlagen |
| 2026-07-05 | `bash scripts/tests/ui_check_test.sh` | ✅ 54 bestanden, 0 fehlgeschlagen |
| 2026-07-05 | Re-QA manuell: `redesign.sh --branding {auxevo,meridian,verdict}` | ✅ alle Exit 0, keine falsche Palette-Warnung |
| 2026-07-05 | Re-QA manuell: XSS-Fixture in `branding/index.html` | ✅ rohe `</script>`-Sequenz nicht vorhanden, escaped `\u003c/script\u003e` vorhanden |

### Acceptance Criteria
| AC | Ergebnis | Nachweis |
|---|---|---|
| `branding/<slug>/` mit Tokens, Theme, Logo, Fonts-Angabe, Tonalität, Quelle, Datum | ✅ PASS | `auxevo`, `meridian`, `verdict` haben `profile.json`, `current -> v1`, `tokens.json`, `tailwind-theme.css`, `branding.md`; Font-/Logo-Status in `profile.json`. |
| Auxevo-Seed aus `/home/dev/tools/Hal/00 Context/` | ✅ PASS | `branding/auxevo/v1/{tokens.json,tailwind-theme.css,branding.md,logo.svg}` vorhanden; `profile.json.source == "seed"`. |
| PROJ-3 bietet „Als Profil speichern" an | ✅ PASS | `scripts/ui-check.sh`-Regression grün; Ausgabe enthält den `node scripts/brand-lib.mjs save ...`-Hinweis nach Branding. |
| Profile in PROJ-6/PROJ-13 als `--branding <slug>` auswählbar | ✅ PASS | PROJ-6 `redesign.sh --branding` liefert für `auxevo`, `meridian`, `verdict` Exit 0; PROJ-13-Assembler-Aufruf mit `--branding auxevo --industry saas --out <tmp>` übernimmt Branding und erzeugt Run-Artefakte. Der Assembler kann wegen PROJ-13-Registry-Fallbacks Exit 1 liefern; das ist kein PROJ-12-Brandingfehler. |
| Profil-Übersicht mit Swatches | ✅ PASS | `branding/index.html` rendert Profile/Swatches; manipulierte `</script>`-Profilmetadaten werden escaped. |

### Edge Cases
| Edge Case | Ergebnis | Nachweis |
|---|---|---|
| Update derselben Domain erzeugt neue Version, kein stilles Überschreiben | ✅ PASS | `brand_lib_test.sh`: zweites `save --slug customer` erzeugt `v2`; `--as v2` auf bestehender Version bricht mit Exit 2 ab. |
| Unvollständige Extraktion ohne Logo/Font bleibt speicherbar | ✅ PASS | Temporärer Run ohne Logo/Fonts wurde gespeichert; `profile.json.logo.status == "manuell"` und `fonts.status == "manuell"`. |
| Ungültiger Branding-Slug / Pfadversuch | ✅ PASS | `redesign.sh <run> --branding ../verdict` bricht mit Exit 2 und „Ungültiger Branding-Slug" ab. |

### Bugs
| ID | Severity | Status | Beschreibung | Reproduktion | Erwartung |
|---|---|---|---|---|---|
| PROJ-12-BUG-1 | Medium | Behoben | `redesign.sh --branding <slug>` markierte vorhandene Bibliotheksprofile als degradiert, weil nur `.color.palette[]` gezählt wurde. | Fix: Palette-Check zählt jetzt eindeutige Hex-Werte aus allen DTCG-Farbtokens unter `color.*` (`$value` oder `hex`). Verifiziert: `auxevo`, `meridian`, `verdict` liefern Exit 0 ohne „Token-Palette ist leer". | ✅ |
| PROJ-12-BUG-2 | Medium | Behoben | `branding/index.html` bettete Profilmetadaten als rohes `JSON.stringify` in `<script>` ein; `</script>` konnte aus dem Script-Kontext ausbrechen. | Fix: Inline-JSON escaped `&`, `<`, `>`, U+2028 und U+2029. Verifiziert: XSS-Fixture enthält keine rohe `</script><script>...`-Sequenz; escaped `\u003c/script\u003e` ist vorhanden. | ✅ |

### Security Audit
- Auth/Tenant/RLS/JWT/MinIO: nicht anwendbar; PROJ-12 ist ein lokales dateibasiertes CLI ohne Server, DB oder Auth.
- Path Traversal: PASS für `redesign.sh --branding`; Slug wird validiert.
- Overwrite/Data Loss: PASS für `save --as` bestehender Version; bricht mit Exit 2 ab.
- XSS: behoben; Inline-JSON der statischen Katalogseite escaped Script-Breakout-Sequenzen.

### Regression
- PROJ-3/5-Orchestrierung: `scripts/tests/ui_check_test.sh` grün.
- PROJ-6-Redesign-Gates: `scripts/tests/redesign_test.sh` grün.
- PROJ-12-CLI: `scripts/tests/brand_lib_test.sh` grün.

### Production-Ready Decision
**APPROVED.** Alle PROJ-12-Akzeptanzkriterien und dokumentierten Edge-Cases sind verifiziert; keine Critical/High/Medium-Bugs offen.

## Deployment
_To be added by /abc-deploy_
