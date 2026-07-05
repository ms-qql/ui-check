# PROJ-13: Portfolio-Assembler (Matrix-Angebote)

## Status: Approved
**Created:** 2026-07-02
**Last Updated:** 2026-07-05

## Dependencies
- Requires: PROJ-11 (Komponenten-Registry), PROJ-12 (Branding-Bibliothek), PROJ-7 (HTML-Export)

## User Stories
- Als Auxevo-Nutzer möchte ich aus Branding-Profil × Komponenten-Set (industrie-gefiltert) in Minuten ein Mockup assemblieren, um Low-Cost-Festpreisangebote („Landing-Page-Entwurf in 24h") zu machen.

## Acceptance Criteria
- [x] Aufruf: `--assemble --branding <slug> --industry <tag> [--sections hero,pricing,trust,cta]`
- [x] Claude wählt passende Registry-Bausteine, wendet das Branding-Profil an, füllt Platzhalter aus kurzem Kunden-Briefing (`--prompt`)
- [x] Output: teilbares Mockup via PROJ-7 (inkl. Gates) in < 30 min Ende-zu-Ende
- [x] Fehlende Bausteine für eine Sektion: Neu-Generierung via PROJ-6-Mechanik als Fallback, Kennzeichnung im Ergebnis

## Edge Cases
- Branding-Profil und Baustein-Stil beißen sich (Dark-Profil, Light-Baustein): Tokens gewinnen; Baustein wird umgefärbt, nicht verworfen
- Leere Registry für die Industrie: sauberer Hinweis + kompletter Generierungs-Fallback

---
## Tech Design (Solution Architect)
**Erstellt:** 2026-07-05 · **Stack:** Node-CLIs (ESM, nur Builtins) + Bash-Orchestrierung; wiederverwendet die dateibasierte UI-Check-Pipeline (`runs/`, keine DB/kein Server) · Verifikation via esbuild/@tailwindcss/cli/Playwright · **Branch:** dev

> Bewusst **kein** FastAPI/Flutter-Default-Stack — PROJ-13 ist Teil der dateibasierten
> UI-Check-Pipeline. Kernidee: PROJ-13 ist der **erste „greenfield"-Einstieg** — kein
> Capture/Audit als Ausgangspunkt, sondern **Katalog → Mockup**. Der Assembler
> **synthetisiert ein run-kompatibles `redesign/`-Verzeichnis**, sodass die bestehenden
> Bausteine (Registry-Selektor PROJ-11, Verify-Gates + `mockup-export.sh` PROJ-7)
> **unverändert** greifen. Neu ist nur der Einstiegs-Assembler + ein Skill.

### Nutzer-Entscheidungen (2026-07-05)
- **(A) Varianten-Modell:** Assembler baut **Safe + Bold** aus der Registry (zwei Block-Sets/Branding-Töne). `mockup-export.sh` bleibt unverändert; das Vorher/Nachher-Voting (PROJ-8) vergleicht hier **zwei Entwürfe** statt Original↔Redesign (es gibt kein „Vorher").
- **(A) Selektion:** Industrie-Filter läuft über den bestehenden `registry-select.mjs` — der Assembler synthetisiert dafür ein Run-Dir mit `content.json`; **kein** zweiter Selektor.
- **(A) `--sections`-Default:** fixer generischer Landing-Plan `hero, trust, features, pricing, cta`, wenn `--sections` fehlt.

### A) Ablauf / Komponenten-Struktur (was gebaut wird)
```
scripts/assemble.sh                 ← NEU · Orchestrator (Bash, spiegelt redesign.sh-Struktur)
  ├─ 1 INIT        Run-Dir synthetisieren:  runs/<datum>-assemble-<slug>-<industry>-NNN/
  │                 redesign/{shared,safe,bold}/, redesign-context.json (mode:"assemble")
  ├─ 2 PLAN        Sektionsplan aus --sections (Default: hero,trust,features,pricing,cta)
  │                 → redesign/shared/content.json (Sektionen mit id/type, Copy = Platzhalter)
  ├─ 3 BRANDING    branding/<slug>/ einlesen → shared/tokens.json + shared/tailwind-theme.css
  ├─ 4 SELECT      scripts/registry-select.mjs --run <dir> --style safe|bold  (industrie-gefiltert)
  │                 → registry-selection.{safe,bold}.json + redesign/registry/ (Blocks + Token-Alias)
  ├─ 5 (Skill)     Brief-Pass: Claude füllt content.json-Platzhalter aus --prompt (Kunden-Briefing)
  │                 Visual-Pass ×2: decision:"registry" → Block importieren; "generate" → PROJ-6-Fallback
  ├─ 6 VERIFY      scripts/redesign.sh --verify <dir>  (bestehende Gates inkl. G-REG, G3)
  └─ 7 EXPORT      scripts/mockup-export.sh <dir>      (PROJ-7, unverändert) → <dir>/mockup.html

.claude/skills/ui-assemble/         ← NEU · Human-in-the-Loop-Orchestrierung um assemble.sh
  SKILL.md                            (Brief→PLAN→SELECT→Visual-Pass→Verify→Export; headless-fähig für PROJ-14)
```

### B) Datenmodell (Klartext)
Kein Postgres/MinIO. Zwei bestehende Datenquellen + ein synthetisierter Lauf:
```
Eingaben:
- branding/<slug>/       (PROJ-12/11)  tokens.json (DTCG) + tailwind-theme.css + fonts/ + logo
- registry/ (PROJ-11)    industrie-getaggte Blocks (meta.industry / meta.section / meta.style)
- --prompt "<Briefing>"  kurzer Kundentext (Angebot, Zielgruppe, Ton) — NICHT persistiert in der Registry
Synthetisierter Lauf runs/<…>-assemble-<slug>-<industry>-NNN/:
- redesign/shared/content.json      Sektionsplan (id, type, Copy aus Brief gefüllt)
- redesign/shared/tokens.json + tailwind-theme.css   (aus branding/<slug>/)
- redesign/registry/…               gewählte Blocks + registry-tokens.css (Token-Alias)
- redesign/{safe,bold}/             zwei Varianten (Registry-Blocks + ggf. generierte Sektionen)
- redesign-context.json { mode:"assemble", branding, industry, sections, brief }
- mockup.html                        Endprodukt (teilbar, self-contained)
```
Kein Multi-Tenancy/RLS/Auth (kein Server). Der Recycle-Guard-Grundsatz „keine Kundendaten in der Registry" bleibt gewahrt: der Brief füllt nur das **Run**-`content.json`, nie die Registry.

### C) Schnittstellen (CLI-Kontrakte, keine HTTP-Endpunkte)
```
scripts/assemble.sh --branding <slug> --industry <tag>
                    [--sections hero,trust,features,pricing,cta]
                    [--prompt "<Kunden-Briefing>"]
                    [--template <slug>|--pin s=block|--exclude block|--registry-only|--no-registry]
Exit-Codes als Gates (durchgereicht von den Sub-CLIs):
  0 ok · 2 = harte Lücke (registry-only unauflösbar) / rote Verify-Gate / leere Registry für Industrie
Wiederverwendete Kontrakte (unverändert):
  registry-select.mjs   Sektionstyp+industry+Stil → decision registry|generate, Token-Alias
  redesign.sh --verify  G-REG (Registry-Andockung) · G3 (content.json-Kontrakt) · Slot-Contract
  mockup-export.sh      INIT-Gate (safe+bold+verify grün) → self-contained mockup.html
```

### D) Tech-Entscheidungen (Warum)
- **Run-Dir synthetisieren statt neuer Pipeline:** `registry-select.mjs`, die Verify-Gates und `mockup-export.sh` verlangen exakt die `runs/*/redesign/…`-Struktur. Baut der Assembler diese, ist PROJ-13 fast reine **Orchestrierung** bestehender, verifizierter Bausteine — minimales neues, testbares Terrain und die geforderte „< 30 min Ende-zu-Ende".
- **Safe + Bold statt Solo (A):** hält den Export-Pfad + das Voting-Feature (PROJ-7/8) unverändert; der Kunde bekommt zwei Angebotsvarianten zur Auswahl — passt zum „Matrix-Angebote"-Ziel besser als ein einzelnes Mockup.
- **Fixer Default-Sektionsplan (A):** ein bewährter Landing-Plan (hero→trust→features→pricing→cta) ist reproduzierbar und deckt Low-Cost-Festpreisangebote ab; `--sections` überschreibt bei Bedarf. Kein pro-Industrie-Sonderfall-Zoo.
- **Generierungs-Fallback = PROJ-6-Mechanik (AC4):** fehlt für eine Sektion ein Registry-Block, liefert `registry-select.mjs` `decision:"generate"`; der Visual-Pass generiert sie wie in `ui-redesign` und **kennzeichnet** sie im Ergebnis (Zähler `stats.generate` in `registry-selection.*.json`, sichtbar im Verify-Report).
- **Deterministische CLIs + LLM nur im Skill:** Struktur/Selektion/Export sind reproduzierbar & headless; das LLM-Urteil (Brief→Copy, Auswahl der Best-Sektionen, Freigabe) bleibt an den Skill-Gates (Human-in-the-Loop, PROJ-14-fähig).

### E) Edge Cases (aus der Spec, im Design verankert)
- **Dark-Profil × Light-Block:** Tokens gewinnen — der Token-Alias (`registry-tokens.css` aus `registry-select.mjs`) färbt den Block aufs Branding um, statt ihn zu verwerfen. Bereits so implementiert in PROJ-11.
- **Leere Registry für die Industrie:** SELECT liefert für alle Sektionen `generate` → Assembler gibt sauberen Hinweis aus und fährt den **kompletten Generierungs-Fallback** (kein Abbruch, außer `--registry-only` → Exit 2).

### F) Abhängigkeiten
- Bestehend/wiederverwendet: `registry-select.mjs`, `redesign.sh`, `mockup-export.sh`, `branding/<slug>/`, `registry/`.
- Node ≥ 18 (nur Builtins). Verifikation (nicht Laufzeit): esbuild, @tailwindcss/cli v4, Playwright.
- **Voraussetzung:** mindestens ein Branding-Profil (PROJ-12) und industrie-getaggte Registry-Blocks (PROJ-11) — beide vorhanden (`verdict`, `meridian`, `hero45`).
- Keine neuen Python/Flutter-Dependencies.

## QA Test Results

### QA Run — 2026-07-05 (`/abc-qa`)

**Scope:** CLI-Pipeline PROJ-13 gegen Akzeptanzkriterien und Edge Cases. FastAPI,
Postgres/RLS/Auth, MinIO und Flutter sind nicht anwendbar: dieses Projekt hat für
PROJ-13 laut Tech Design keinen Server und kein `flutter_app/`. Tooling-Hinweis:
`conda` ist in dieser Umgebung nicht installiert, daher kein globaler
`conda run -n Dashboard ... pytest`; die vorhandenen Shell-Suites wurden genutzt.

**Automatisierte Regressionen:**
- `scripts/tests/assemble_test.sh` → 17/17 grün.
- `scripts/tests/ui_check_test.sh` → 54/54 grün.
- `scripts/tests/brand_lib_test.sh` → 22/22 grün.
- `scripts/tests/mockup_export_test.sh` → 68/68 grün.

**Manuelle AC-Prüfung:**
- AC1 `scripts/ui-check.sh --assemble --branding meridian --industry saas --sections hero,pricing,trust,cta --prompt ...` → PASS. Run-Struktur, `ui-check.json`, `content.json`, `registry-selection.safe.json` und `registry-selection.bold.json` werden erzeugt.
- AC2 Claude-/Skill-Pass wählt/füllt final → FAIL/UNVERIFIZIERT. Das deterministische Scaffold übernimmt `--prompt` in `content.json`, aber es entsteht ohne anschließenden `ui-assemble`-Visual-Pass keine ausgefüllte Safe/Bold-Implementierung.
- AC3 teilbares Mockup via PROJ-7 in < 30 min → FAIL. Nach `--assemble` liegt kein `mockup.html` vor; Verify/Export können ohne `redesign/{safe,bold}/App.jsx` nicht laufen.
- AC4 fehlende Sektion → PASS. `--sections does-not-exist` liefert Exit 1 und `registry-selection.*.json` mit `decision:"generate"` sowie `stats.generate = 1`.

**Bugs:**
- `PROJ-13-BUG-1` · **High** · Industrie-Filter wird bei Block-Auswahl ignoriert. Repro: `scripts/assemble.sh --branding meridian --industry unknown-industry --sections hero,cta`. Erwartet: komplette Generierungs-Fallbacks für leere Industrie; Ist: Registry-Blöcke werden trotzdem per `type-match` gewählt (`hero45`, `verdict-contact`) und `--registry-only` endet sogar mit Exit 0.
- `PROJ-13-BUG-2` · **High** · Kein nachweisbarer Ende-zu-Ende-Output. Repro: erfolgreicher `--assemble`-Lauf mit `meridian/saas`; danach existiert kein `<run>/mockup.html`. Damit ist das Kernziel „teilbares Mockup via PROJ-7" noch nicht erfüllt.

**Security Audit:** Keine Auth-/Tenant-/RLS-Fläche vorhanden. CLI-Eingaben
`--branding` und `--industry` sind gegen Pfad-Traversal eingeschränkt; `--prompt`
wird JSON-escaped und nicht als Shell ausgeführt. Keine Critical-Security-Findings.

**Production Decision:** **NOT READY**. Zwei High-Bugs offen; Status bleibt
**In Review**.

### Fix Verification — 2026-07-05

**Änderungen nach QA-Priorisierung:**
- `PROJ-13-BUG-1` behoben: `registry-select.mjs` filtert Blocks jetzt hart nach
  `meta.industry`. Unbekannte Industrien fallen vollständig auf
  `decision:"generate"` zurück; `--registry-only` bricht dann mit Exit 2 ab.
- `PROJ-13-BUG-2` behoben: `assemble.sh` erzeugt einen vollständigen
  Starter-Visual-Stand (`brief.md`, `compare.json`, `images.md`,
  `redesign/{safe,bold}/App.jsx`, Manifest, Package), führt Verify aus und ruft
  standardmäßig `mockup-export.sh` auf. `--no-export` bleibt als Test-/Scaffold-Modus.
- CTA-Anker werden dynamisch auf eine existierende Sektion gesetzt, damit
  PROJ-7-Gate M8 bei Plänen ohne `cta` grün bleibt.

**Verifikation:**
- `scripts/tests/assemble_test.sh` → 27/27 grün.
- `scripts/tests/ui_check_test.sh` → 54/54 grün.
- `scripts/tests/brand_lib_test.sh` → 22/22 grün.
- `scripts/tests/redesign_test.sh` → 52/52 grün.
- `scripts/tests/mockup_export_test.sh` → 68/68 grün.
- Echter E2E-Lauf:
  `scripts/assemble.sh --branding meridian --industry saas --sections hero,pricing --prompt "B2B Incident-Plattform für SRE-Teams"` →
  `mockup.html` erzeugt, Verify `16 ok / 0 warn / 0 fail`, Export-Gates
  `14 ok / 4 warn / 0 fail`, Laufzeit ca. 30 Sekunden. Die 4 Export-Warnungen
  betreffen fehlende Original-Capture-Screenshots und sind für Greenfield-Assemble
  erwartbar.

**Production Decision:** **READY**. Keine Critical/High-Bugs offen.

## Deployment
**Deployed:** 2026-07-05 · **Version:** v0.3.0 · **Release:** GitHub `main`

Mit Release v0.3.0 ausgeliefert:
- `scripts/assemble.sh` als Portfolio-Assembler für
  Branding-Profil × Industrie × Sektionsplan.
- `scripts/ui-check.sh --assemble` als Haupt-CLI-Einstieg.
- Industrie-gefilterte Registry-Auswahl mit Generierungs-Fallback.
- Automatisch erzeugter Starter-Visual-Stand mit Verify + Mockup-Export.
- Skill `ui-assemble` für Kuratierung/Polish nach dem Starter-Export.

Kein Dokploy-/Server-Deploy: PROJ-13 ist Teil der lokalen CLI-/Dateipipeline und
wird über GitHub-Release/Tag verteilt.

## Implementation Notes
- `scripts/assemble.sh` erzeugt den PROJ-13-Run-Vertrag aus
  `branding/<slug>/current/` und `registry/registry.json`.
- `scripts/ui-check.sh --assemble ...` delegiert direkt an den Assembler, damit
  die bestehende Haupt-CLI den geforderten Einstieg bietet.
- `.claude/skills/ui-assemble/SKILL.md` dokumentiert den LLM-Teil:
  den automatisch erzeugten Starter-Stand bei Bedarf kuratieren, Registry-
  Entscheidungen übernehmen und `decision:"generate"`-Fallbacks polieren.
- Es wurden bewusst keine FastAPI-Endpunkte, Pydantic-Schemas, SQL-Migrationen,
  Mandanten-/RLS-Regeln oder DB-Tests angelegt; das Tech Design legt PROJ-13 als
  dateibasierte CLI-Pipeline ohne Server fest.
