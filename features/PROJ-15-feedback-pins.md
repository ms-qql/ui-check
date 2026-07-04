# PROJ-15: Feedback-Pins im Mockup

## Status: Architected
**Created:** 2026-07-02
**Last Updated:** 2026-07-04

## Dependencies
- Requires: PROJ-7 (Mockup-Export), PROJ-8 (Ansichten)
- Offener Entscheidungspunkt: POST-Endpoint (kleiner Hosted-Collector) vs. mailto-Fallback — siehe Brainstorm

## User Stories
- Als Kunde möchte ich direkt im Mockup Sektionen kommentieren und Varianten bewerten, ohne ein Meeting zu brauchen.
- Als Auxevo-Nutzer möchte ich Kundenfeedback als maschinenlesbare Task-Liste erhalten, die Claude direkt abarbeiten kann.

## Acceptance Criteria
- [ ] Klick auf Sektion → Kommentar + 👍/👎 je Variante; Übersicht der eigenen Kommentare vor dem Absenden
- [ ] Export als JSON, kompatibel zum Drawbridge-`.moat`-Taskformat (comment, selector/Sektion, status)
- [ ] Übertragung: POST an konfigurierbaren Endpoint ODER mailto-Fallback mit JSON im Body (funktioniert ohne Backend)
- [ ] Empfangenes Feedback lässt sich als Task-Liste in einen Folgelauf einspeisen („Änderungswünsche umsetzen")

## Edge Cases
- Kunde sendet mehrfach: Einsendungen werden per Zeitstempel versioniert, nicht gemergt
- Kein Netz beim Kunden: Kommentare bleiben im localStorage erhalten, Hinweis zum erneuten Senden

---
## Tech Design (Solution Architect)
**Erstellt:** 2026-07-04 · **Stack:** Erweiterung der PROJ-7/8-Viewer-Shell (React/Tailwind, esbuild-Bundle) — rein clientseitig · **Branch:** dev

### Struktur (Erweiterung, kein neuer Baustein)
PROJ-15 ist wie PROJ-8 **kein eigener Treiber und kein eigener Skill**: Die
Feedback-Ebene wird Teil der versionierten Viewer-Shell
(`scripts/lib/mockup-shell/`), die `mockup-export.sh` (PROJ-7) ohnehin bündelt.
Es kommen nur **eine neue Interaktions-Ebene** (Kommentar-Pins), ein
**Export-/Sende-Flow** und **neue Publish-Gates** hinzu. Ablauf, Exit-Codes und
Artefakt (`mockup.html`) bleiben unverändert (AC PROJ-7/8: „kein zweites
Artefakt"). Der Empfangs-/Einspeise-Teil (Feedback → Folgelauf) ist ein
**kleiner deterministischer Script-Schritt**, kein UI.

### Aufbau der erweiterten `mockup.html` (PM-Sicht)
```
mockup.html (weiterhin eine Datei, offline lauffähig)
├── Detailansicht (aus PROJ-8) + NEU: Kommentar-Modus
│   ├── „Kommentieren"-Umschalter in der Kopfleiste
│   ├── Klick auf eine Sektion → Pin + Popover:
│   │   ├── Freitext-Kommentar
│   │   └── 👍 / 👎 je Variante (Safe / Bold)
│   └── Pins sind nummeriert und je Sektion sichtbar
├── „Mein Feedback"-Übersicht (vor dem Absenden)
│   ├── Liste aller eigenen Kommentare + Bewertungen (bearbeiten / löschen)
│   └── Zwei Sende-Wege nebeneinander:
│       ├── „Als E-Mail senden"  → mailto: mit JSON im Body (Default, kein Backend)
│       └── „Absenden"           → POST an konfigurierten Endpoint (nur wenn gesetzt)
└── (unverändert) Voting-Screen, Redesign, Vorher/Nachher, Sektionsvergleich
```

### Daten — Feedback-JSON (Drawbridge-`.moat`-kompatibel)
Der Export erzeugt exakt das Task-Format, das der `/bridge`-Command liest
(`moat-tasks-detail.json`), damit Claude die Wünsche direkt abarbeiten kann:
```
{
  "run_id": "<aus data-run-id der Shell>",
  "domain": "<Domain>",
  "submitted_at": "<ISO-Zeitstempel>",       // Versionierung, nicht Merge
  "tasks": [
    {
      "id": "fb-1",
      "comment": "<Freitext des Kunden>",
      "selector": "<CSS-Selektor / data-section der Sektion>",
      "section": "<Sektions-Label>",
      "variant_votes": { "safe": "up|down|null", "bold": "up|down|null" },
      "status": "to do"                        // moat-Lifecycle: to do→doing→done
    }
  ]
}
```

### Übertragung — zwei Wege, beide ohne Zwang zum Backend
```
1) mailto-Fallback (DEFAULT, funktioniert immer / offline / Datei-per-Mail)
   „Als E-Mail senden" öffnet mailto:<konfigurierte Empfängeradresse>
   mit dem Feedback-JSON im Body. Kein Server nötig.
2) POST an Endpoint (OPTIONAL, nur aktiv wenn beim Build konfiguriert)
   Ist ein Endpoint gesetzt, erscheint zusätzlich „Absenden" → fetch(POST, JSON).
   Bei Erfolg: Bestätigung. Bei Fehler/kein Netz: automatischer Rückfall auf
   mailto + Hinweis „später erneut senden"; Kommentare bleiben im localStorage.
```

### Empfang & Einspeisung in einen Folgelauf
```
scripts/feedback-ingest.sh <run-dir> <feedback.json>
→ validiert das JSON, legt es versioniert unter
  <run-dir>/feedback/<submitted_at>.json ab (mehrere Einsendungen: nie gemergt)
→ schreibt/aktualisiert <run-dir>/.moat/moat-tasks-detail.json + moat-tasks.md
  im Drawbridge-Format, sodass /bridge bzw. ein Redesign-Folgelauf
  („Änderungswünsche umsetzen") die Tasks direkt abarbeiten kann.
```
Das erfüllt die AC „Empfangenes Feedback lässt sich als Task-Liste in einen
Folgelauf einspeisen" deterministisch, ohne LLM-Anteil.

### Konfiguration (Build-Zeit, in den Bundle eingebacken)
```
<run-dir>/redesign/feedback.json   (optional, aus PROJ-6/Lauf-Konfig):
  { "endpoint": "https://…"|null,          // null → nur mailto
    "mailto": "kunde-feedback@auxevo.de" } // Default-Empfänger für mailto
Fehlt die Datei: endpoint=null, mailto = projektweiter Default. So bleibt der
Lauf ohne Konfiguration voll funktionsfähig (nur mailto).
```

### Neue Publish-Gates (in `gates.json`, gleiche Mechanik wie PROJ-7/8)
| Gate | Prüfweise | Bei Verstoß |
|---|---|---|
| Kommentar-Modus aktivierbar, Pin+Popover erscheint | Browser (agent-browser) | rot → Abbruch |
| Export erzeugt `.moat`-kompatibles JSON (Pflichtfelder je Task) | Browser (JSON aus DOM parsen) | rot → Abbruch |
| mailto-Weg vorhanden und befüllt JSON in den Body | statisch + Browser | rot → Abbruch |
| POST-Button nur sichtbar wenn Endpoint gesetzt (sonst nicht) | statisch (Config-Scan) | gelb → Warnung |
| localStorage-Persistenz + „erneut senden"-Hinweis vorhanden | Browser | gelb → Warnung |
| Feedback-Ebene ohne JS unschädlich (Pins nur Progressive Enhancement) | statisch (No-JS-Baseline) | rot → Abbruch |

### Tech-Entscheidungen
- **Auflösung des offenen Entscheidungspunkts (POST vs. mailto):** PROJ-15
  liefert **beides**, aber der **mailto-Weg ist der Default** und der POST-Weg
  nur ein optionaler, build-konfigurierter Zusatz. Der *tatsächliche* Hosted-
  Collector (Endpoint-Implementierung, Speicherung) gehört bewusst zu **PROJ-19
  (Backend-Verdrahtung)** — PROJ-19 hängt laut INDEX explizit von PROJ-15 ab
  („Kundenfeedback eingearbeitet"). So bleibt PROJ-15 in der Projektlinie
  „kein Backend bis Stufe 4/PROJ-19" und ist trotzdem ohne Server voll nutzbar.
- **Shell-Erweiterung statt neues Artefakt:** gleiche Begründung wie PROJ-8 —
  ein Build-Weg, eine Gate-Infrastruktur, ein Deliverable (`mockup.html`).
- **`.moat`-Format als Export-Kontrakt:** Das Feedback-JSON ist absichtlich
  format-gleich zu `moat-tasks-detail.json`, damit der bestehende `/bridge`-Flow
  (Status-Lifecycle to do→doing→done, `comment`/`selector`) ohne Adapter greift.
  Kein neues Feedback-Schema erfinden, wenn ein etabliertes existiert.
- **Pins als Progressive Enhancement:** Die Kommentar-Ebene liegt rein additiv
  über der PROJ-8-Ansicht; ohne JS ist sie schlicht abwesend und die Datei bleibt
  voll lesbar (No-JS-Gate bleibt grün). Kein Eingriff in die vor-gerenderten
  Varianten.
- **Versionierung statt Merge (Edge-Case):** Jede Einsendung trägt
  `submitted_at`; `feedback-ingest.sh` legt sie als eigene Datei ab und mergt
  nie automatisch — mehrfaches Senden bleibt nachvollziehbar, Konfliktauflösung
  ist eine menschliche Entscheidung.
- **localStorage je Lauf getrennt (Edge-Case „kein Netz"):** Kommentare
  überleben Reload/Offline (gleicher `STORE_KEY`-Mechanismus wie die
  Richtungs-Wahl aus PROJ-8); der Sende-Screen zeigt bei Fehlschlag einen
  „später erneut senden"-Hinweis statt Datenverlust.
- **Clipboard-/mailto-Robustheit:** `mailto:` funktioniert auch bei
  `file://`-geöffneten Dateien (Mail-Anhang-Szenario), wo `navigator.clipboard`
  und `fetch` teils blockiert sind — deshalb ist mailto der verlässliche Default,
  POST der Bonus.

### Dependencies
- **Neu:** keine npm-Pakete. `feedback-ingest.sh` nutzt `jq` (vorhanden).
- **Vorhanden:** Viewer-Shell + esbuild/Tailwind-Harness (PROJ-7/8),
  `agent-browser` (Browser-Gates), `jq`, `node` v22.

### Betroffene Dateien (Umsetzungs-Landkarte für /abc-frontend)
- `scripts/lib/mockup-shell/chrome.js` — Kommentar-Modus, Pins/Popover,
  „Mein Feedback"-Übersicht, mailto+POST-Sende-Flow, localStorage.
- `scripts/lib/mockup-shell/template.html` + `shell.css` — Kopfleisten-Umschalter,
  Pin-/Popover-/Übersichts-Markup + Styles (neuer `data-shell-slot`).
- `scripts/lib/mockup-shell/build.mjs` — Feedback-Config (`endpoint`/`mailto`)
  in den Bundle einbacken; Default wenn Datei fehlt.
- `scripts/mockup-export.sh` — optionale `redesign/feedback.json` in den
  Workspace kopieren; neue Publish-Gates in `gates.json`.
- `scripts/feedback-ingest.sh` (NEU) + `scripts/tests/feedback_ingest_test.sh` (NEU)
  — Empfang/Validierung/`.moat`-Erzeugung.
- `scripts/tests/mockup_export_test.sh` — Fixtures + Gates für die Feedback-Ebene.

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
