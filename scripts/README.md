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

## Voraussetzungen

- **agent-browser** (npm, global) + Chromium:
  ```bash
  npm install -g agent-browser
  agent-browser install            # lädt Chrome-for-Testing
  ```
- **curl**, **jq** (Standard-CLI-Tools).
- In Container-/VM-Umgebungen startet Chromium nur mit `--no-sandbox`. Das Skript
  setzt `AGENT_BROWSER_ARGS=--no-sandbox,--disable-dev-shm-usage` als Default;
  eine bereits gesetzte Variable wird respektiert (Override möglich).
