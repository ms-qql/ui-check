# PROJ-1: Seiten-Erfassung (Capture)

## Status: In Progress
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
**Erstellt:** 2026-07-02 · **Stack:** Claude-Code-Skill-Pipeline (CLI, kein FastAPI/Flutter) · **Branch:** dev

### Pipeline-Struktur
```
ui-check Skill (PROJ-5, Orchestrator — später)
└── Schritt „capture" (PROJ-1)
    ├── Preflight     — Tool-Check (agent-browser installiert?), URL-Validierung
    ├── Browse        — Seite öffnen, Network-Idle, Scroll-Durchlauf (Lazy-Loading),
    │                   Cookie-Banner-Dismiss (Best-Effort-Selektorliste)
    ├── Shots         — Fullpage-Screenshots 375 / 768 / 1440 px
    ├── Snapshot      — A11y-Tree (token-kompakt) + dom-meta (Title, Meta, OG, Favicon)
    └── Finalize      — meta.json schreiben, Exit-Code setzen
```

### Datenhaltung (Run-Ordner-Kontrakt — Vertrag aller Stufe-1-Features)
```
runs/YYYY-MM-DD-<domain>-NNN/
├── capture/    shot-375.png · shot-768.png · shot-1440.png
│               snapshot.txt (A11y-Tree) · dom-meta.json
├── meta.json   URL, finale URL, Status, Dauer, Vermerke (Cookie-Banner, Kappung …)
└── (später: lighthouse/ · branding/ · report.md · scores.json — PROJ-2/3/4)
```
Keine DB, kein MinIO — Läufe sind lokale Archive; `runs/` steht in `.gitignore`.

### CLI-Kontrakt
```
capture <url> --out <run-dir> [--timeout 60] [--max-height 20000]
Exit 0 = ok · 2 = Abbruch (nicht erreichbar / Bot-Schutz / kein HTML)
Meldungen deutsch auf stdout; maschinenlesbares Ergebnis in meta.json
```

### Tech-Entscheidungen
- **agent-browser statt Playwright-MCP:** reine CLI ohne Server-Setup; A11y-Snapshots ~200–400 Tokens statt rohem HTML → hält den Claude-Judge (PROJ-4) token-günstig. Vorhandener playwright-Skill bleibt Fallback.
- **Dateien statt DB:** Run-Ordner-Kontrakt macht jedes Stufe-1-Feature unabhängig testbar; ein Lauf = ein Archiv.
- **Bot-Schutz = sauberer Abbruch,** kein Umgehungsversuch (PRD Non-Goal).
- **Feste Viewports 375/768/1440:** deckungsgleich mit QA-Konvention und UI-Mockup → Vergleichbarkeit über alle Läufe.
- **Helper-Skripte bash-/stdlib-basiert;** wo Python nötig, im `Dashboard`-Conda-Env (Haus-Konvention).

### Dependencies
- `agent-browser` (npm, global) + `agent-browser install` (Chromium)
- keine neuen Python-Pakete (Stdlib genügt)

## Implementierungs-Notizen (Backend)
**Umgesetzt:** 2026-07-02 · **Branch:** dev · **Datei:** `scripts/capture.sh` (+ `scripts/README.md`)

### Was gebaut wurde
`scripts/capture.sh` — eigenständiger Bash-CLI-Schritt nach dem Tech-Design (kein FastAPI/DB, Run-Ordner statt Persistenz). Ablauf: Preflight (curl) → Browse (agent-browser) → Shots → Snapshot → Finalize.

- **Preflight (curl):** folgt Redirects, ermittelt finale URL / HTTP-Status / Content-Type / Redirect-Anzahl. Fehlerklassifizierung mit deutschen Meldungen und Exit 2:
  - DNS (curl 6), Connection refused (7), Timeout (28, `--timeout`), TLS (35/51/60), sonstige Netzfehler.
  - HTTP ≥ 400 → „Seite nicht erreichbar: HTTP <code>".
  - Content-Type ≠ `text/html`/`xhtml` → „Kein HTML-Dokument".
  - Bot-Schutz (Cloudflare/Challenge-Marker in Header/Body, `cf-mitigated`, 403/503+cloudflare) → „Seite ist bot-geschützt — Lauf nicht möglich" (kein Umgehungsversuch).
- **Browse:** `agent-browser open` → `wait --load networkidle`; finale Client-URL wird nachgezogen; Cookie-Banner-Dismiss best-effort über Selektor- **und** Textliste (OneTrust, Cookiebot, Usercentrics, Didomi, „Alle akzeptieren" …), Ergebnis in `meta.json.cookie_banner`.
- **Lazy-Loading:** async-IIFE-Scroll-Durchlauf (global + pro Viewport), danach zurück nach oben + erneutes Network-Idle.
- **Shots 375/768/1440 (Fullpage):** `screenshot --full`; bei Seitenhöhe > `--max-height` (Default 20000) Kappung via Viewport-Screenshot der oberen `max-height` px (Vermerk + `capped:true` je Screenshot).
- **Snapshot + dom-meta:** `snapshot -c` → `snapshot.txt`; ein `eval` liefert Title, Meta-Description, absolut aufgelösten Favicon, OG-Tags, Sektionen-Anzahl → `dom-meta.json`.
- **SPA-Leerverdacht:** < 40 Zeichen sichtbarer Text nach Idle → `content_suspicion: "spa_empty"`.
- **meta.json:** url, final_url, status (ok|aborted), error, http_status, content_type, redirects, timestamp (UTC ISO), duration_seconds, agent_browser_version, cookie_banner, content_suspicion, screenshots[], notes[]. Wird auch bei Abbruch geschrieben (sofern Run-Ordner steht).

### Abweichungen / Ergänzungen vom Spec
- **`--out` ist optional:** ohne Angabe wird `runs/<datum>-<domain>-NNN` automatisch nach Run-Ordner-Kontrakt angelegt (Bequemlichkeit; PROJ-5 übergibt `--out` explizit).
- **Preflight via curl statt Browser** für Status/Redirects/Bot-Erkennung — robuster und token-frei; der Browser rendert erst nach bestandenem Preflight.
- **Kappung** über hochgesetzten Viewport (`set viewport <w> <max-height>` + Nicht-`--full`-Screenshot) statt CSS-Clamp — Letzteres kollabierte die Fullpage-Höhe auf den Viewport (verworfen).
- **`AGENT_BROWSER_ARGS=--no-sandbox,--disable-dev-shm-usage`** als Default nötig (Container/VM); überschreibbar.
- Neue Abhängigkeit dokumentiert: `agent-browser` global installiert (v0.27.0) + `agent-browser install` (Chrome-for-Testing 150).

### Manuell verifiziert
- example.com (0 Redirects, kurze Seite) · github.com (http→https-Redirect, ~13k px Fullpage) · heise.de (Kappung 45k→20000 px, 548 Sektionen, 7 OG-Tags) → Exit 0.
- Fehlerpfade Exit 2 + deutsche Meldung: nicht existierende Domain (DNS), GitHub-404 (HTTP 404), W3C-Dummy-PDF (Kein HTML-Dokument); jeweils `meta.json` mit `status:"aborted"`.

Offen für `/abc-qa`: Bot-geschützte Seite (Cloudflare-Challenge) live gegenprüfen; Interstitial/Alters-Gate-Screenshot; sehr große Seite (> 90 s Laufzeitgrenze) unter Last.

## QA Test Results
**Getestet:** 2026-07-03 · **Branch:** dev · **Methode:** Black-Box gegen `capture.sh` mit deterministischen lokalen Fixtures (kein Internet, keine Flakiness).
**Test-Suite:** `scripts/tests/capture_test.sh` (+ `scripts/tests/serve_fixtures.py`) — **45/45 Assertions bestanden**.

Ausführen: `bash scripts/tests/capture_test.sh` (startet Fixture-Server automatisch, ~90 s Laufzeit).

### Acceptance Criteria

| # | Kriterium | Ergebnis | Nachweis |
|---|---|---|---|
| 1 | `capture <url> --out <dir>` erzeugt shot-375/768/1440.png, snapshot.txt, dom-meta.json | ✅ Pass | Gruppe A: alle Dateien vorhanden + korrekte Bildbreiten (375/768/1440); dom-meta enthält Title, Meta-Description, absolut aufgelösten Favicon, OG-Tags, Sektionen-Anzahl |
| 2 | `meta.json` enthält URL, finale URL, Timestamp, Dauer, HTTP-Status, agent-browser-Version | ✅ Pass | Gruppe A: alle Pflichtfelder gesetzt + Typen geprüft (ISO-Timestamp, numerische Dauer, http_status 200) |
| 3 | Lazy-Loading durch Scroll-Durchlauf vor Screenshot | ✅ Pass | Async-Scroll-Durchlauf global + je Viewport; volle Seitenhöhe wird erfasst (/tall 26.042 px gemessen) |
| 4 | Cookie-Banner Best-Effort weggeklickt, Erfolg/Misserfolg in meta.json | ✅ Pass | Gruppe D: `/cookie` → `cookie_banner.dismissed=true`, `method="selector:#onetrust-accept-btn-handler"` |
| 5 | Nicht erreichbar (DNS, Timeout, HTTP ≥ 400) → Exit ≠ 0 + deutsche Meldung | ✅ Pass | Gruppe F: HTTP 404 → Exit 2 „nicht erreichbar: HTTP 404"; DNS-Fehler → Exit 2 „nicht erreichbar"; aborted-meta geschrieben |
| 6 | Bot-Schutz erkannt → sauberer Abbruch, kein Umgehungsversuch | ✅ Pass | Gruppe F: `/botwall` (403 + cloudflare + cf-mitigated + „Just a moment") → Exit 2 „bot-geschützt"; **nicht** fälschlich als HTTP 403 gemeldet (Reihenfolge korrekt) |

### Edge Cases

| Fall | Ergebnis | Nachweis |
|---|---|---|
| Redirect-Kette (http→https / Sprach-Redirect) | ✅ Pass | Gruppe B: `/redirect`→`/normal`, `final_url` dokumentiert, `redirects≥1` |
| Sehr lange Seite > max-height → gekappt + Vermerk | ✅ Pass | Gruppe C: `/tall` → shot-1440 auf 20000 px, `capped=true`, Kappungs-Vermerk in notes. Custom `--max-height 3000` → 1440×3000 verifiziert |
| Non-HTML (PDF/Bild) → „Kein HTML-Dokument" | ✅ Pass | Gruppe F: `/doc.pdf` (application/pdf) → Exit 2 „Kein HTML-Dokument" |
| SPA ohne SSR (leerer Body) → `content_suspicion: spa_empty` | ✅ Pass | Gruppe E: `/spa` → Exit 0 + `content_suspicion="spa_empty"` |
| Argument-Validierung (keine URL / unbekannte Option) | ✅ Pass | Gruppe G: Exit 1 (interner Fehler) |
| Interstitial / Alters-Gate: nicht umgangen, Screenshot zeigt Gate | ⏳ Nicht live geprüft | Verhalten folgt aus dem Code (kein Bypass), aber ohne echte Gate-Seite nicht visuell verifiziert |

### Red-Team / Robustheit

- **Command-Injection:** URL/`--out`/Content-Type fließen als Argumente bzw. via `jq --arg` — **keine** Shell- oder JSON-Injection. Auto-Run-Ordner wird aus der Domain sanitisiert (`[^a-zA-Z0-9.-]`→`-`), kein Path-Traversal. ✅
- **Session-Isolation:** eindeutige `AGENT_BROWSER_SESSION` je PID, Browser-Close im EXIT-Trap → parallele Läufe kollidieren nicht. ✅
- **Secrets:** keine Geheimnisse verarbeitet/geloggt. ✅

### Gefundene Bugs (keine Critical/High)

| ID | Severity | Titel | Beschreibung / Empfehlung |
|---|---|---|---|
| QA-1 | Low | Kein harter Laufzeit-Deckel | AC-Ziel „< 90 s" (optional/Technical Requirement) ist nicht garantiert: Summe der Waits (networkidle 25 s + Scrollpässe + 3 Screenshots) kann im Worst Case ~90 s überschreiten. **Empfehlung:** aggregierte Deadline bzw. `timeout 120 …`-Wrapper in PROJ-5-Orchestrator. |
| QA-2 | Low | `--timeout`/`--max-height` nicht validiert | Nicht-numerische Werte führen zu curl-/Arithmetik-Fehler statt klarer deutscher Meldung. **Empfehlung:** numerische Validierung beim Parsen. |
| QA-3 | Info | SSRF by design | Tool ruft beliebige URLs inkl. intern/localhost auf (Zweck des Tools). Für internes Single-User-Tool akzeptabel — **nicht** als offener Batch-/Netzdienst exponieren. |
| QA-4 | Info | Cross-Origin-CMP nicht dismissbar | Cookie-Banner in Fremd-iFrames (Sourcepoint u. Ä.) werden bewusst nicht umgangen; korrekt als `dismissed:false` vermerkt. |

**Nicht live gegengeprüft (Empfehlung: opportunistisch):** echte Cloudflare-Challenge (nur Fixtur simuliert), Interstitial/Alters-Gate-Screenshot, reale Seite > 90 s unter Last.

### Fazit
**Production-Ready: JA** — keine Critical/High-Bugs. Alle 6 Acceptance Criteria + alle automatisiert prüfbaren Edge Cases bestehen (45/45). Die zwei Low-Findings (QA-1/QA-2) sind Robustheits-Verbesserungen, keine Blocker; sinnvoll im Zuge von PROJ-5 (Orchestrierung) mitzunehmen.

## Deployment
_To be added by /abc-deploy_
