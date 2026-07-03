# PROJ-2: Lighthouse-Audit

## Status: Approved
**Created:** 2026-07-02
**Last Updated:** 2026-07-03

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
**Erstellt:** 2026-07-02 · **Stack:** Claude-Code-Skill-Pipeline (CLI) · **Branch:** dev

### Struktur
Preflight (lighthouse installiert?) → Lauf Mobile (Default) → optional Desktop → Extraktion `lh-summary.json` → Spiegelung der Capture-Vermerke (Cookie-Banner) aus PROJ-1.

### Daten (im Run-Ordner-Kontrakt)
```
lighthouse/
├── lighthouse-mobile.json    Voll-Report (Beweis/Archiv)
├── lighthouse-desktop.json   nur bei --desktop
└── lh-summary.json           4 Kategorie-Scores · CWV mit Google-Bewertung ·
                              Top-5-Opportunities · status: ok|failed + Grund
```

### CLI-Kontrakt
`lh-audit <url> --out <run-dir> [--desktop]` · Exit 0 = ok, 1 = failed (Pipeline degradiert, bricht nicht ab) · Timeout 120 s.

### Tech-Entscheidungen
- **Lokale Lighthouse-CLI statt PageSpeed-Insights-API:** kein API-Key, keine Quota, funktioniert für jede erreichbare URL. Trade-off: keine CrUX-Felddaten — dokumentiert, später zuschaltbar.
- **Voll-JSON bleibt erhalten,** Pipeline liest nur das Summary → Befunde in PROJ-4 sind stets belegbar.
- **Ein Browser für alles:** Lighthouse nutzt das Chromium der agent-browser-Installation (CHROME_PATH).

### Dependencies
- `lighthouse` (npm, global)

## Implementation Notes (Backend)
**Umgesetzt:** 2026-07-03 · **Branch:** dev · **Artefakt:** `scripts/lh-audit.sh`

### Was gebaut wurde
- **`scripts/lh-audit.sh`** — Bash-CLI im Stil von `capture.sh`. Kontrakt:
  `lh-audit.sh <url> [--out <run-dir>] [--desktop] [--timeout 120]`.
  Schreibt `<run-dir>/lighthouse/{lighthouse-mobile.json, lighthouse-desktop.json*, lh-summary.json, lighthouse.log}`.
- **Lighthouse-CLI 13.4.0** global installiert (`npm i -g lighthouse`); Mobile ist
  Default, Desktop via `--preset=desktop` bei `--desktop`. Chrome über `CHROME_PATH`
  (Fallback-Suche `chrome`/`google-chrome`/`chromium`); nutzt hier das
  Playwright-Chromium (`~/.local/bin/chrome`, Chrome-for-Testing 147).
- **`lh-summary.json`** via `jq` extrahiert: 4 Kategorie-Scores (0–100), CWV
  (LCP/CLS/TBT/FCP/Speed-Index) mit Rohwert **und** Google-Rating
  (good/needs-improvement/poor), Top-5-Opportunities (nur `overallSavingsMs > 0`,
  absteigend), `form_factors`, optional `.desktop`-Block, Meta (timestamp,
  duration, lighthouse_version).
- **Degradation statt Abbruch:** Timeout (`timeout 120s` → Exit 124), Lighthouse-
  Exit≠0 oder `.runtimeError` → `lh-summary.json` mit `status:"failed"` + deutschem
  `error`-Grund, Exit 1. Erfolg → `status:"ok"`, Exit 0.
- **Cookie-Banner-Spiegelung:** liest `<run-dir>/meta.json` aus PROJ-1 und
  übernimmt `cookie_banner`; nicht geschlossenes Banner → Consent-Warnung in
  `note`. Ohne capture-meta bleibt `cookie_banner: null`.
- **`scripts/tests/lh_audit_test.sh`** — Black-Box-Suite gegen `serve_fixtures.py`
  (echtes Lighthouse, lokale Fixtures). **38/38 Tests grün.**
- `scripts/README.md` um den `lh-audit.sh`-Abschnitt + Voraussetzung `lighthouse` ergänzt.

### Abdeckung Acceptance Criteria
- [x] Mobile-Default + optional `--desktop` → getrennte Voll-Reports
- [x] `lh-summary.json` mit 4 Scores, 5 CWV inkl. Google-Bewertung
- [x] Top-5-Opportunities mit `savings_ms`
- [x] Absturz/Timeout → `status:failed` + Grund, Pipeline läuft weiter (Exit 1)
- [x] Keine Google-API/kein API-Key (lokale CLI)
- [x] Edge: Cookie-Vermerk aus PROJ-1 gespiegelt

### Entscheidungen/Abweichungen
- Timeout-Default aus dem Tech-Design (120 s) als `--timeout` überschreibbar.
- Desktop-Werte werden nicht in die Top-Level-Scores gemischt, sondern liegen
  unter `.desktop` — Mobile bleibt kanonisch (Google-Primärindex).
- Zusätzlich `lighthouse.log` (Roh-Stderr) für Diagnose bei `failed`.
- Manuelle Prüfung noch offen: Lauf gegen echte Consent-Wall-Seite + sehr
  langsame SPA (Timeout-Pfad) im Feld — mit lokalen Fixtures nur simuliert.

## QA Test Results
**Getestet:** 2026-07-03 · **Tester:** QA Engineer · **Branch:** dev · **Ergebnis:** ✅ Production-Ready

**Umgebung:** Lighthouse 13.4.0, Chrome-for-Testing 147 (Playwright-Chromium via `CHROME_PATH`).
Black-Box gegen lokale Fixtures (`scripts/tests/serve_fixtures.py`) — deterministisch, kein Internet.

### Automatisierte Suite
`scripts/tests/lh_audit_test.sh` → **38/38 bestanden.** Deckt Happy-Path (Mobile+Desktop),
Nur-Mobile, Fehlerpfad (unerreichbar → failed/Exit 1) und Argument-Validierung ab.

### Acceptance Criteria (manuell + automatisiert)
| # | Kriterium | Ergebnis |
|---|---|---|
| 1 | Mobile-Default → `lighthouse-mobile.json`; `--desktop` → zusätzlich `lighthouse-desktop.json` | ✅ Pass |
| 2 | `lh-summary.json`: 4 Kategorie-Scores (0–100), LCP/CLS/TBT/FCP/Speed-Index + good/ni/poor-Rating | ✅ Pass |
| 3 | Top-Opportunities (max. 5) mit geschätzter Ersparnis (`savings_ms`, nur > 0, absteigend) | ✅ Pass |
| 4 | Absturz/Timeout: Pipeline läuft weiter; `status:"failed"` + Grund; Exit 1 (degradiert, kein Abbruch) | ✅ Pass |
| 5 | Keine Google-API/kein API-Key (lokale CLI) | ✅ Pass |
| 6 | Edge: Cookie-Vermerk (`cookie_banner`) aus PROJ-1 `meta.json` gespiegelt | ✅ Pass |

### Zusätzliche Edge Cases (über die Suite hinaus)
| Fall | Erwartung | Ergebnis |
|---|---|---|
| `--timeout 1` (SPA-/Lade-Timeout-Simulation) | Exit 124-Pfad → `status:failed`, Meldung „Zeitüberschreitung nach 1s" | ✅ Pass |
| Ungültiges `--timeout abc` | Exit 1, deutsche Meldung | ✅ Pass |
| Cookie `dismissed:true` in capture-meta | `cookie_banner.note == null` (keine Warnung) | ✅ Pass |
| Kein `--out` | Auto-Run-Ordner `runs/<datum>-<domain>-NNN/lighthouse/` | ✅ Pass |
| `--help` | Exit 0, Nutzungs-Header | ✅ Pass |
| Redirect `/redirect → /normal` | `final_url` = aufgelöste Ziel-URL (Lighthouse `finalDisplayedUrl`) | ✅ Pass |

### Security / Red-Team
Lokale CLI ohne Auth-/Tenant-/DB-Modell → JWT-/RLS-/Injection-Vektoren **nicht anwendbar**.
- **Parametrisierung:** URL wird als Argument an `lighthouse`/`timeout` übergeben (kein `eval`, keine Shell-Interpolation der URL in Kommandos). ✅
- **Kein Secret-Leak:** kein API-Key, keine `.env`; `lighthouse.log` enthält nur Roh-Stderr. ✅
- **Informationell (kein Bug):** das Tool auditiert jede erreichbare URL inkl. interner/localhost-Adressen. Als lokales CLI-Werkzeug erwünscht; **falls** PROJ-19 es je als Netzwerk-Service exponiert, dort eine URL-Allowlist/SSRF-Schranke ergänzen. Für Stufe 1 kein Handlungsbedarf.

### Regression
Keine gemeinsamen Artefakte mit PROJ-1 verändert; `lh-audit.sh` schreibt ausschließlich nach
`<run-dir>/lighthouse/`. `capture.sh`-Ausgabe (`meta.json`, `capture/`) bleibt unberührt (nur lesend
für die Cookie-Spiegelung). Kein Repo-Pollution durch `runs/`.

### Bugs
Keine (Critical/High/Medium/Low = 0/0/0/0).

### Production-Ready: **JA** — keine Critical/High-Bugs.

## Deployment
_To be added by /abc-deploy_
