# PROJ-5: Skill-Orchestrierung (`ui-check`)

## Status: Approved
**Created:** 2026-07-02
**Last Updated:** 2026-07-03

## Dependencies
- Requires: PROJ-1, PROJ-2, PROJ-3, PROJ-4 (orchestriert alle vier)

## Beschreibung
Der Claude-Code-Skill `ui-check` ist der Einstiegspunkt von Stufe 1: nimmt URL + Optionen entgegen, legt den Run-Ordner an, führt Capture → Lighthouse → Branding → Scoring in korrekter Reihenfolge (parallel wo möglich) aus und meldet Fortschritt/Ergebnis auf Deutsch. Headless aufrufbar (Jupiter-Vorbereitung, PROJ-14).

## User Stories
- Als Auxevo-Nutzer möchte ich `/ui-check <url>` aufrufen und einen kompletten Audit-Lauf erhalten, ohne Einzelschritte zu kennen.
- Als Auxevo-Nutzer möchte ich per `--prompt` spezielle Anweisungen mitgeben (z. B. „Fokus auf Terminbuchung"), die in Scoring-Kontext und (später) Redesign-Brief einfließen.
- Als Auxevo-Nutzer möchte ich bei Teilfehlern ein nutzbares Teilergebnis statt eines Totalabbruchs.

## Acceptance Criteria
- [ ] Aufruf: `/ui-check <url> [--industry <tag>] [--prompt "…"] [--desktop] [--mode auto|landing]`; Stufe 1 ist immer audit-only
- [ ] Run-Ordner `runs/YYYY-MM-DD-<domain>-NNN/` mit allen Artefakten aus PROJ-1–4; NNN läuft bei Mehrfach-Läufen am selben Tag hoch
- [ ] Ablaufregeln: Capture-Fehler ⇒ Abbruch des Laufs (nichts zu bewerten); Lighthouse-/Logo-Fehler ⇒ weiterlaufen mit „nicht messbar"-Vermerk
- [ ] PROJ-2 läuft parallel zu PROJ-1/PROJ-3, Scoring startet erst wenn alle Inputs final sind
- [ ] Nach Erfolg: Zusammenfassung im Terminal (Gesamtscore, Top-3-Befunde, Pfad zum Report) + Append in `runs.jsonl`
- [ ] Fehlende Voraussetzungen (agent-browser/lighthouse nicht installiert) werden beim Start geprüft; deutsche Anleitung zur Installation, kein Crash mitten im Lauf
- [ ] Headless-tauglich: keine interaktiven Abfragen bei vollständigen Parametern; Exit-Codes 0/1/2 (ok/Teilfehler/Abbruch)

## Edge Cases
- Gleiche URL erneut am selben Tag: neuer Run-Ordner (NNN+1), kein Überschreiben
- `--industry` fehlt: Claude schlägt Tag aus Seiteninhalt vor, markiert ihn als `auto`
- Parallele Läufe: Ordner-Namenskonvention verhindert Kollisionen; `runs.jsonl`-Appends sind zeilenatomar
- Abbruch durch Nutzer (Ctrl-C): Run-Ordner bleibt mit `status: aborted` in `meta.json` erhalten

## Technical Requirements (optional)
- Skill-Verzeichnis: `.claude/skills/ui-check/SKILL.md` im Projekt (später global promotebar)
- Laufzeitziel: < 10 min pro URL Ende-zu-Ende

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
**Erstellt:** 2026-07-02 · **Stack:** Claude-Code-Skill (projektlokal) + Schritt-CLIs aus PROJ-1–4 · **Branch:** dev

### Struktur
```
.claude/skills/ui-check/SKILL.md      Orchestrator-Anweisung
└── Ablauf pro Lauf:
    1. Preflight        alle Tools prüfen (agent-browser, lighthouse, extractor)
    2. Run-Ordner       runs/YYYY-MM-DD-<domain>-NNN/ anlegen
    3. Capture ∥ Lighthouse   parallel (beide brauchen nur die URL)
    4. Branding         nach Capture
    5. Scoring          wenn alle Inputs final
    6. Abschluss        Terminal-Summary (Score, Top-3, Report-Pfad)
                        + Append data/runs.jsonl
```
Jeder Lauf führt `status.json` (Phase, Zeiten, Teilfehler) — spätere Fortschrittsquelle für Jupiter (PROJ-14).

### CLI-Kontrakt
`/ui-check <url> [--industry <tag>] [--prompt "…"] [--desktop]` · Exit 0 = ok, 1 = Teilfehler, 2 = Abbruch.

### Tech-Entscheidungen
- **Fehlerpolitik zentral im Orchestrator:** Capture-Fehler = Abbruch (nichts zu bewerten); Lighthouse-/Logo-/Extraktor-Fehler = degradieren mit „nicht messbar"-Vermerk. Schritte selbst bleiben dumm.
- **Skill projektlokal** (`.claude/skills/`), später global promotebar — Jupiter ruft denselben Skill headless auf (PROJ-53-Muster).
- **Headless-Garantie:** bei vollständigen Parametern keine interaktiven Fragen; `--industry` fehlt → Auto-Vorschlag mit `auto`-Markierung.
- **`--prompt` wird durchgereicht** und im Report als Nutzer-Kontext ausgewiesen (Stufe 2 nutzt ihn im Redesign-Brief).
- **Kollisionssicherheit:** NNN-Suffix pro Tag/Domain; `runs.jsonl`-Appends zeilenatomar.

### Dependencies
- keine über PROJ-1–4 hinaus

## Implementation Notes (Backend)
**Umgesetzt:** 2026-07-03 · **Branch:** dev

### Was gebaut wurde
- **`scripts/ui-check.sh`** — deterministischer Orchestrator-Treiber mit zwei Modi:
  - **COLLECT** (`<url> [--industry] [--prompt] [--desktop] [--out] [--timeout]`): Preflight → Run-Ordner (NNN) → **Capture ∥ Lighthouse** (parallel) → Branding. Schreibt `status.json` (je-Phase) + `ui-check.json` (Kontext für Judge/Finalize).
  - **FINALIZE** (`--finalize <run-dir> [--industry] [--weights]`): ruft `score-report.sh`, aktualisiert `status.json` → `done`, gibt Terminal-Summary (Gesamtscore, Top-3, Report-Pfad) aus. `runs.jsonl`-Append erledigt `score-report.sh`.
- **`.claude/skills/ui-check/SKILL.md`** — Orchestrator-Anweisung für Claude: Collect → **Judge-Pass** (Claude erzeugt `judge.json` gegen `rubrics/`) → Finalize → deutscher Bericht. Der Judge sitzt bewusst zwischen den beiden Treiber-Aufrufen (Bewertung = Claude, nicht skriptbar).
- **`scripts/tests/ui_check_test.sh`** — hermetische QA-Suite (48 Checks, alle grün): Schritt-CLIs via `UI_CHECK_BIN`-Stubs ersetzt, `score-report.sh` real. Deckt Happy Path, Fehlerpolitik (Capture=Abbruch/Rest=degradieren), Parallelität, NNN-Kollision, status.json/ui-check.json, Finalize + Summary, Auto-Industrie, Gates/Exit-Codes.
- **`scripts/README.md`** um den `ui-check.sh`-Abschnitt erweitert.

### Kontrakt-Erweiterungen (Run-Ordner)
- `status.json` — Lauf-Status + `phases.{capture,lighthouse,branding,scoring}.{status,duration_seconds,error}`. Fortschrittsquelle für Jupiter (PROJ-14).
- `ui-check.json` — url/final_url, industry_tag(+`industry_source: auto|explicit`), user_prompt, desktop, rubric_version.
- Diagnose-Logs `.{capture,lighthouse,branding}.log` im Run-Ordner.

### Entscheidungen / Abweichungen
- **Zwei-Phasen-Treiber statt Ein-Skript:** Der Judge (Claude) kann nicht skriptbar in der Mitte laufen — daher Collect/Finalize als getrennte Treiber-Aufrufe, dazwischen der Judge-Pass des Skills. Headless bleibt gewahrt (Jupiter ruft den Skill headless auf, PROJ-53-Muster).
- **Exit-Semantik durchgereicht:** score-report Exit 1/2 → Orchestrator Exit 1/2; Collect degradiert (Lighthouse/Branding) → Exit 1.
- **`UI_CHECK_BIN`-Override** nur für Tests (Stub-Verzeichnis) — Produktivpfad = `scripts/`.
- **Auto-Industrie** ist ein Claude-Schritt: Treiber markiert nur `industry_source: auto`; der Skill leitet den Tag aus dom-meta/snapshot ab und übergibt ihn an Finalize.

### Acceptance Criteria — Abdeckung
- [x] Aufruf `/ui-check <url> [--industry] [--prompt] [--desktop] [--mode]`, Stufe 1 audit-only (SKILL.md; `--mode` durchgereicht/vermerkt).
- [x] Run-Ordner `runs/YYYY-MM-DD-<domain>-NNN/`, NNN hochzählend (Test G).
- [x] Ablaufregeln: Capture-Fehler ⇒ Abbruch; Lighthouse/Logo-Fehler ⇒ „nicht messbar" (Tests C/D/E).
- [x] PROJ-2 parallel zu PROJ-1; Scoring erst nach finalen Inputs (Test H + Ablauflogik).
- [x] Erfolg: Terminal-Summary (Gesamtscore, Top-3, Report-Pfad) + runs.jsonl-Append (Test B).
- [x] Preflight prüft Tools beim Start, deutsche Installationsanleitung, kein Crash mitten im Lauf.
- [x] Headless: keine interaktiven Abfragen bei vollständigen Parametern; Exit-Codes 0/1/2.
- [x] Edge Cases: erneuter Lauf (NNN+1), `--industry` fehlt (auto), Ctrl-C (`status: aborted`).

### Offen für QA (/abc-qa)
- End-to-End-Lauf gegen eine echte URL (Treiber + realer Judge-Pass) — die hermetische Suite testet die Orchestrierung, nicht die Schritte selbst (die haben eigene Tests).

## QA Test Results
**Getestet:** 2026-07-03 · **Tester:** QA Engineer (Red-Team) · **Branch:** dev
**Verdict:** ✅ **Production-Ready** — keine Critical/High/Medium-Bugs. 3 Low-Findings (nicht blockierend).

### Testumfang
- **Automatisiert:** `scripts/tests/ui_check_test.sh` — **48/48 bestanden** (hermetisch, Stub-Schritte via `UI_CHECK_BIN`, echtes `score-report.sh`).
- **Regression:** `scripts/tests/score_report_test.sh` — bestanden (score-report ist Finalize-Abhängigkeit; die vorbestehenden BUG-1/2/4/5-Fixes im Working-Tree sind mit dem Orchestrator kompatibel — E2E lief grün).
- **Echter End-to-End-Lauf** gegen den lokalen Fixture-Server (`/normal`), reale Sub-Skripte (agent-browser + lighthouse):
  - Collect 21s, Capture ∥ Lighthouse parallel, Branding degradiert (keine Logos in Fixture) → Exit 1 korrekt.
  - Alle Artefakte erzeugt (meta/capture/lighthouse/branding/status/ui-check).
  - Finalize mit gültigem judge.json → `scores.json` (Total 72, alle 5 Dims messbar), `report.md`, Terminal-Summary (Top-3), `runs.jsonl`-Append.
- **Red-Team-Probes** (manuell, Stub- + reale Skripte).

### Acceptance Criteria — Ergebnis

| # | Kriterium | Ergebnis |
|---|---|---|
| 1 | Aufruf `<url> [--industry --prompt --desktop --mode]`, audit-only | ✅ SKILL.md + Treiber; `--desktop` an lh-audit durchgereicht (Log verifiziert) |
| 2 | Run-Ordner `YYYY-MM-DD-<domain>-NNN/`, NNN hochzählend | ✅ Test G (zwei Läufe → -001/-002) |
| 3 | Capture-Fehler ⇒ Abbruch; Lighthouse/Logo ⇒ „nicht messbar" | ✅ Tests C/D/E + realer Branding-Degrade |
| 4 | PROJ-2 parallel zu PROJ-1; Scoring nach finalen Inputs | ✅ Test H (~2s statt 4s) + reale parallele Ausführung |
| 5 | Erfolg: Terminal-Summary (Score, Top-3, Report-Pfad) + runs.jsonl | ✅ Test B + realer E2E-Summary |
| 6 | Preflight prüft Tools, deutsche Anleitung, kein Crash mittendrin | ✅ Gate G2: fehlendes Skript → Exit 2 vor jeder Arbeit, nennt fehlendes Tool |
| 7 | Headless: keine interaktiven Abfragen; Exit 0/1/2 | ✅ P2 (`</dev/null`, kein Hang); Exit-Codes durchweg korrekt |
| EC | erneuter Lauf (NNN+1), `--industry` auto, Ctrl-C `aborted` | ✅ Test G/F + P3 (SIGINT → Exit 2, `status: aborted`, Ordner erhalten) |

### Security / Red-Team
- **Command-Injection (P1):** URL/`--prompt`/`--industry` mit `$(…)`, Backticks, `"; touch … #` → **keine Ausführung**; Werte landen wörtlich in gültigem JSON (jq `--arg`, durchweg quotierte Expansion). ✅
- **DSGVO (runs.jsonl):** nur 16-stelliger URL-Hash, **keine Klar-URL** — auch beim realen Lauf verifiziert. ✅ (`status.json`/`ui-check.json` enthalten Klartext, liegen aber ausschließlich im gitignorierten `runs/`.)
- **Rubrik-Konflikt-Gate (G1):** Finalize mit falscher `rubric_version` → Exit 2, `status: aborted`, **kein** Summary gedruckt. ✅
- **Preflight-Gate (G2):** keine Arbeit vor vollständiger Tool-Prüfung. ✅

### Bugs / Findings (alle Low, nicht blockierend)
- **BUG-L1 (Low, Aufräumen):** Bei SIGINT beendet `on_signal` sofort (`exit 2`), ohne die noch laufenden Hintergrund-Kinder (Capture/Lighthouse-Subprozesse) zu killen. Diese laufen detached zu Ende; die echte `capture.sh` schließt ihre agent-browser-Session per EXIT-Trap selbst → kein dauerhaftes Leck, aber eine Browser-Session läuft nach dem Abbruch noch aus. *Empfehlung:* in `on_signal` `kill "$cap_pid" "$lh_pid" 2>/dev/null` vor `exit`.
- **BUG-L2 (Low, Tote Variable):** `scripts/ui-check.sh` berechnet am Ende von Collect `dur=$(( … ))`, gibt es aber nie aus. *Empfehlung:* Variable entfernen oder in die „Datenerfassung abgeschlossen"-Zeile aufnehmen.
- **BUG-L3 (Low, Defense-in-Depth):** `--timeout` wird in `ui-check.sh` nicht validiert (nur an capture/lh durchgereicht, die es selbst prüfen). Nicht ausnutzbar, aber ein früher Zahlen-Check wäre konsistent mit der `--weights`-Prüfung in score-report. *Empfehlung:* optionaler Regex-Guard.

### Produktionsempfehlung
**READY.** Keine Critical/High/Medium-Bugs. Die drei Low-Findings sind kosmetisch/Aufräumen und können vor oder nach dem Deploy adressiert werden.

## Deployment
_To be added by /abc-deploy_
