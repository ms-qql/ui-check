# scripts/ — UI-Check Pipeline-Skripte

CLI-Bausteine der UI-Check-Pipeline (kein FastAPI/Flutter — siehe PRD).
Jeder Schritt schreibt in den **Run-Ordner-Kontrakt** (`runs/YYYY-MM-DD-<domain>-NNN/`).

## `capture.sh` — Seiten-Erfassung (PROJ-1)

Erfasst eine öffentliche URL visuell + strukturell als Grundlage für PROJ-2/3/4.

```bash
scripts/capture.sh <url> [--out <run-dir>] [--timeout 60] [--max-height 20000]
```

- `<url>` — Ziel-URL (Protokoll optional, `https://` wird ergänzt).
- `--out <run-dir>` — Run-Ordner. Ohne Angabe wird `runs/<datum>-<domain>-NNN` automatisch angelegt.
- `--timeout` — Preflight-Timeout in Sekunden (Default 60).
- `--max-height` — Screenshot-Höhenkappung in px (Default 20000).

### Ausgabe (Run-Ordner-Kontrakt)

```
<run-dir>/
├── meta.json                URL, finale URL, HTTP-Status, Dauer, Vermerke, Screenshot-Liste
└── capture/
    ├── shot-375.png         Fullpage-Screenshot 375 px (Mobil)
    ├── shot-768.png         Fullpage-Screenshot 768 px (Tablet)
    ├── shot-1440.png        Fullpage-Screenshot 1440 px (Desktop)
    ├── snapshot.txt         A11y-Tree (token-kompakt, für den Claude-Judge in PROJ-4)
    └── dom-meta.json        Title, Meta-Description, Favicon, OG-Tags, Sektionen-Anzahl
```

### Exit-Codes

| Code | Bedeutung |
|---|---|
| `0` | Erfolgreich erfasst |
| `2` | Sauberer Abbruch: nicht erreichbar (DNS/Timeout/HTTP ≥ 400), Bot-Schutz, kein HTML-Dokument |
| `1` | Interner Fehler (fehlendes Tool, ungültige Argumente) |

Bei Exit 2 wird — sofern der Run-Ordner steht — trotzdem ein `meta.json` mit
`status: "aborted"` und deutscher `error`-Meldung geschrieben.

### Verhalten

- **Redirects:** folgt der Kette (http→https, www, Sprach-Redirect); die finale URL landet in `meta.json`.
- **Lazy-Loading:** Scroll-Durchlauf vor jedem Screenshot löst nachladende Inhalte aus.
- **Cookie-Banner:** Best-Effort-Dismiss über gängige Selektoren/Buttontexte (OneTrust, Cookiebot, Usercentrics, Didomi, „Alle akzeptieren" …). Erfolg/Misserfolg in `meta.json` unter `cookie_banner`. Banner in Cross-Origin-iFrames (z. B. Sourcepoint) werden bewusst **nicht** umgangen.
- **Bot-Schutz:** Cloudflare-/Challenge-Erkennung → sauberer Abbruch, kein Umgehungsversuch (PRD-Non-Goal).
- **Höhenkappung:** Seiten > `--max-height` werden auf die oberen `max-height` px gekappt (Vermerk in `meta.json`).
- **SPA-Leerverdacht:** sehr wenig sichtbarer Text nach Network-Idle → `content_suspicion: "spa_empty"`.

## `lh-audit.sh` — Lighthouse-Audit (PROJ-2)

Misst die technische Qualität der Ziel-URL mit der lokalen Lighthouse-CLI
(headless Chrome): Performance/Core-Web-Vitals, Accessibility, SEO, Best
Practices — maschinenlesbare Basis für das Score-Panel in PROJ-4. Läuft
parallel zu `capture.sh` (gleiche Ziel-URL, gleicher Run-Ordner).

```bash
scripts/lh-audit.sh <url> [--out <run-dir>] [--desktop] [--timeout 120]
```

- `<url>` — Ziel-URL (Protokoll optional, `https://` wird ergänzt).
- `--out <run-dir>` — Run-Ordner (i. d. R. der von `capture.sh`). Ohne Angabe
  wird `runs/<datum>-<domain>-NNN` automatisch angelegt.
- `--desktop` — zusätzlich zum Mobile-Lauf (Default) einen Desktop-Lauf messen.
- `--timeout` — Hard-Timeout je Lauf in Sekunden (Default 120).

### Ausgabe (Run-Ordner-Kontrakt)

```
<run-dir>/lighthouse/
├── lighthouse-mobile.json    Voll-Report Mobile (Beweis/Archiv)
├── lighthouse-desktop.json   Voll-Report Desktop (nur bei --desktop)
├── lh-summary.json           kompaktes Extrakt für die Pipeline (s. u.)
└── lighthouse.log            Roh-Stderr der Lighthouse-Läufe (Diagnose)
```

`lh-summary.json` (Mobile ist kanonisch, Desktop optional unter `.desktop`):

```jsonc
{
  "url": "…", "final_url": "…",
  "status": "ok",            // ok | failed
  "error": null,             // Grund bei failed
  "timestamp": "…Z", "duration_seconds": 21, "lighthouse_version": "13.4.0",
  "form_factors": ["mobile", "desktop"],
  "scores": { "performance": 100, "accessibility": 100, "best_practices": 96, "seo": 100 },
  "core_web_vitals": {       // Google-Schwellen → rating good|needs-improvement|poor
    "lcp":  { "value_ms": 751, "rating": "good" },   // ≤2500 / ≤4000
    "cls":  { "value": 0,      "rating": "good" },   // ≤0.1  / ≤0.25
    "tbt":  { "value_ms": 0,   "rating": "good" },   // ≤200  / ≤600
    "fcp":  { "value_ms": 616, "rating": "good" },   // ≤1800 / ≤3000
    "speed_index": { "value_ms": 616, "rating": "good" } // ≤3400 / ≤5800
  },
  "opportunities": [ { "id": "…", "title": "…", "savings_ms": 1234 } ], // max. 5, savings > 0
  "cookie_banner": { "dismissed": false, "note": "…" }, // aus PROJ-1 meta.json gespiegelt
  "desktop": { "scores": { … }, "core_web_vitals": { … } } // nur bei --desktop
}
```

### Exit-Codes

| Code | Bedeutung |
|---|---|
| `0` | Audit erfolgreich (`status: "ok"`) |
| `1` | Lighthouse-Absturz/Timeout **oder** interner Fehler (fehlendes Tool, ungültige Argumente) |

Bei einem Lighthouse-Fehler wird bewusst **nicht abgebrochen**: es entsteht ein
`lh-summary.json` mit `status: "failed"` + deutschem `error`-Grund, damit die
Pipeline (PROJ-4/5) degradiert weiterläuft und die Dimension als „nicht messbar"
ausweisen kann.

### Verhalten

- **Lokale CLI statt PageSpeed-API:** kein API-Key, keine Quota. Trade-off: keine
  CrUX-Felddaten (dokumentiert, später zuschaltbar).
- **Voll-JSON bleibt erhalten** → Befunde in PROJ-4 sind stets belegbar; die
  Pipeline liest nur `lh-summary.json`.
- **Chrome:** nutzt `CHROME_PATH` (falls gesetzt), sonst das erste gefundene
  `chrome`/`google-chrome`/`chromium` im PATH — z. B. das Chromium der
  agent-browser-/Playwright-Installation.
- **Cookie-Banner-Spiegelung:** liegt im Run-Ordner ein `meta.json` aus PROJ-1,
  wird dessen `cookie_banner`-Vermerk übernommen; ein nicht geschlossenes Banner
  wird als Consent-Warnung notiert (Messung ggf. verfälscht).

## Voraussetzungen

- **lighthouse** (npm, global) für PROJ-2:
  ```bash
  npm install -g lighthouse
  ```
- **agent-browser** (npm, global) + Chromium:
  ```bash
  npm install -g agent-browser
  agent-browser install            # lädt Chrome-for-Testing
  ```
- **curl**, **jq** (Standard-CLI-Tools).
- In Container-/VM-Umgebungen startet Chromium nur mit `--no-sandbox`. Das Skript
  setzt `AGENT_BROWSER_ARGS=--no-sandbox,--disable-dev-shm-usage` als Default;
  eine bereits gesetzte Variable wird respektiert (Override möglich).
