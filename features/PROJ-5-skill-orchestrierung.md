# PROJ-5: Skill-Orchestrierung (`ui-check`)

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

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
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
