---
name: ui-check
description: Kompletter Stufe-1-Audit-Lauf einer Website — Capture, Lighthouse, Branding, Design-Scoring & Report in einem Durchlauf. Nutze diesen Skill, wenn der Nutzer "ui-check <url>", "audit <url>", "prüf die Seite <url>", "Website-Audit", "Design-Score für <url>", oder eine vollständige UI-/Conversion-Analyse einer URL möchte. Orchestriert die Schritt-CLIs aus PROJ-1–4 (parallel wo möglich) und ist headless aufrufbar (Jupiter/PROJ-14).
---

# UI-Check — Skill-Orchestrierung (PROJ-5)

Einstiegspunkt von **Stufe 1**: nimmt eine URL + Optionen entgegen und liefert
einen vollständigen Audit-Lauf (Gesamtscore + deutscher Report), ohne dass der
Nutzer die Einzelschritte kennen muss. **Stufe 1 ist immer audit-only** (kein
Redesign — das ist Stufe 2, PROJ-6+).

## Aufruf

```
/ui-check <url> [--industry <tag>] [--prompt "…"] [--desktop] [--mode auto|landing]
```

- `<url>` — Ziel-URL (Protokoll optional).
- `--industry <tag>` — Branchen-Tag für Benchmark/`runs.jsonl` (z. B. `saas`, `finanz`, `handwerk`). Fehlt er, **schlägst du ihn aus dem Seiteninhalt vor** und markierst ihn als `auto`.
- `--prompt "…"` — Nutzer-Kontext (z. B. „Fokus auf Terminbuchung"). Fließt in den Judge-Kontext und wird im Report als Nutzer-Kontext ausgewiesen (Stufe 2 nutzt ihn im Redesign-Brief).
- `--desktop` — zusätzlicher Lighthouse-Desktop-Lauf.
- `--mode` — Stufe 1 ist immer audit-only; `--mode` wird nur durchgereicht/vermerkt.

## Architektur

Der deterministische Treiber **`scripts/ui-check.sh`** übernimmt alles außer der
Bewertung. Die Bewertung (der **Judge**) bist **du (Claude)** — anhand der
versionierten Rubriken in `rubrics/`. Ablauf in zwei Treiber-Aufrufen mit einem
Judge-Pass dazwischen:

```
1. ui-check.sh <url> [opts]     COLLECT: Preflight → Run-Ordner → Capture ∥ Lighthouse → Branding
2. (du) Judge-Pass              rubrics/ + Artefakte → <run-dir>/judge.json
3. ui-check.sh --finalize <dir> SCORING: score-report.sh → scores.json + report.md + runs.jsonl + Summary
```

Der Treiber verwaltet Run-Ordner (`runs/YYYY-MM-DD-<domain>-NNN/`), Parallelität,
`status.json` (Fortschritt für Jupiter) und die zentrale **Fehlerpolitik**:
Capture-Fehler ⇒ Abbruch (nichts zu bewerten); Lighthouse-/Logo-Fehler ⇒
weiterlaufen mit „nicht messbar"-Vermerk. Exit-Codes: **0** ok · **1** Teilfehler
(degradiert) · **2** Abbruch.

## Ablauf (Schritt für Schritt)

### 1. Collect starten

```bash
scripts/ui-check.sh "<url>" [--industry <tag>] [--prompt "…"] [--desktop]
```

- Prüfe den Exit-Code:
  - **2** → Abbruch (Capture-Fehler, fehlendes Tool, ungültige Argumente). Lies die deutsche Meldung, gib sie dem Nutzer weiter, **stopp hier**. Bei fehlenden Tools nenne die Installationszeile aus der Ausgabe.
  - **1** → degradiert (Lighthouse und/oder Branding ausgefallen) — Lauf ist nutzbar, weiter mit Schritt 2. Merke dir, welche Dimension „nicht messbar" ist.
  - **0** → alles erfasst, weiter mit Schritt 2.
- Der Run-Ordner steht in der Ausgabe (`→ Run-Ordner: runs/…`). Merke ihn dir als `<run-dir>`.
- Kontext liegt in `<run-dir>/ui-check.json` (URL, industry_tag, industry_source, user_prompt, rubric_version).

### 2. Industrie-Tag (falls `auto`)

Ist `industry_source == "auto"` (kein `--industry` übergeben): leite aus
`<run-dir>/capture/dom-meta.json` (Title/Description) + `snapshot.txt` einen
kurzen Branchen-Tag ab (z. B. `saas`, `finanz`, `arzt`, `handwerk`, `ecommerce`).
Verwende ihn in Schritt 4 als `--industry <tag>` und weise ihn im Bericht an den
Nutzer als „(auto)" aus.

### 3. Judge-Pass → `<run-dir>/judge.json`

Bewerte die erfasste Seite **selbst** gegen die drei Rubriken. **Lies zuerst**
`rubrics/VERSION`, `rubrics/visual.md`, `rubrics/slop.md`, `rubrics/conversion.md`
(die Anker-Bänder sind bindend — streng zuordnen, nicht glätten).
Alle deutschen Report- und Artefakttexte müssen echte deutsche Umlaute verwenden
(`ä`, `ö`, `ü`, `Ä`, `Ö`, `Ü`, `ß`) und keine ASCII-Umschreibungen wie
`fuer`, `ueber`, `Loesung`, `naechste`, `Erstgespraech` oder `Einschaetzung`,
sofern es sich nicht um technische Identifier, URLs, Dateinamen oder fremde
Eigennamen handelt.

**Inputs für die Bewertung:**
- `<run-dir>/capture/shot-375.png`, `shot-768.png`, `shot-1440.png` — die drei Screenshots (visuell, slop, conversion).
- `<run-dir>/capture/snapshot.txt` — A11y-Tree/Copy-Stichprobe (Conversion, Slop, Sprache).
- `<run-dir>/capture/dom-meta.json` — Title/Meta/OG.
- `<run-dir>/branding/branding.md` + `raw-extract.json` (`copy_sample`) — Tonalität (LLM-Anteil aus PROJ-3, den du hier verfasst), Palette/Fonts als Kontext.
- `--prompt`-Kontext aus `ui-check.json` (falls gesetzt) berücksichtigen.

Schreibe **exakt** diesen Kontrakt nach `<run-dir>/judge.json` (siehe `scripts/README.md`):

```jsonc
{
  "rubric_version": "<Inhalt von rubrics/VERSION>",  // MUSS passen, sonst Abbruch
  "language_confident": true,        // false ⇒ Copy-Befunde weglassen
  "app_mode": false,                 // App/Tool statt Landing?
  "cta_present": true,               // kein CTA ⇒ Action/Logic auf Info-Aufgabe beziehen
  "visual":     { "score": 0-100, "findings": [ … ] },   // rubrics/visual.md
  "ki_score":   0-10,                                     // rubrics/slop.md (roh; Skript invertiert)
  "slop":       { "findings": [ … ] },                   // optional
  "conversion": { "clarity": 0-100, "credibility": 0-100, "logic": 0-100,
                  "action": 0-100, "emotion": 0-100, "findings": [ … ] }
}
```

Jeder **Befund** (`findings[]`): `{ title, severity: hoch|mittel|niedrig, evidence, location, source }`.
**Kein Befund ohne sichtbaren Beleg + Fundort** — `score-report.sh` verwirft unbelegte Befunde.
`source` = `visual` / `slop` / `conversion` je nach Pass.

### 4. Finalize (Scoring & Report)

```bash
scripts/ui-check.sh --finalize "<run-dir>" --industry <tag>
```

- `--industry` nur nötig, wenn du in Schritt 2 einen Auto-Tag bestimmt hast (überschreibt den Default). Sonst wird er aus `ui-check.json` übernommen.
- Optional `--weights v,s,p,a,c` (Default `25,15,15,15,30`).
- Der Treiber ruft `score-report.sh` auf, aktualisiert `status.json` auf `done`, hängt eine Zeile an `data/runs.jsonl` (nur URL-Hash) und gibt die **Terminal-Zusammenfassung** aus (Gesamtscore, Top-3-Befunde, Report-Pfad).
- Exit-Code: **0** alle Dimensionen messbar · **1** degradiert (renormiert / Befund-Minimum) · **2** Gate (fehlendes/ungültiges judge.json, Rubrik-Konflikt).

### 5. Dem Nutzer berichten

Fasse auf Deutsch zusammen: Gesamtscore + Band (🟢/🟡/🔴), die stärkste/schwächste
Dimension, die Top-3-Befunde und den Pfad zu `<run-dir>/report.md`. Nenne
„nicht messbare" Dimensionen samt Grund (z. B. Lighthouse-Timeout). Verweise auf
Stufe 2 (`/abc-frontend` bzw. PROJ-6 Redesign), falls der Nutzer weitermöchte.

## Headless (Jupiter / PROJ-14)

Bei vollständigen Parametern **keine Rückfragen** stellen. Der ganze Ablauf ist
über die zwei Treiber-Aufrufe + einen Judge-Pass skriptbar; `status.json` ist die
Fortschrittsquelle, die Exit-Codes (0/1/2) steuern den aufrufenden Prozess.

Für den **vollautomatischen** headless-Lauf (Jupiter/PROJ-14) verkettet
`scripts/ui-check-auto.sh` die drei Stufen in einem Prozess: Collect →
Judge-Pass (headless `claude -p` erzeugt `judge.json`) → `--finalize`. Scheitert
der Judge-Pass, wird `status: error` gesetzt (Exit 3) — der Lauf bleibt nicht
still auf `awaiting_judge` hängen. Leere/Wartungsseiten brechen bereits im Collect
ab (`content_suspicion=spa_empty` → `status: aborted`, Exit 2).

## Fehlerbehandlung (Kurz)

| Situation | Verhalten |
|---|---|
| Tool fehlt (agent-browser/lighthouse) | Collect Exit 2 vor jeder Arbeit; deutsche Installationsanleitung ausgeben, stoppen. |
| Seite nicht erreichbar / bot-geschützt | Capture Exit ≠ 0 ⇒ Collect Exit 2, Lauf abgebrochen (`status: aborted`). |
| Lighthouse-Timeout | degradieren; Perf/A11y „nicht messbar", renormiert. |
| Kein Logo / leere Tokens | degradieren; Branding-Vermerk, Lauf läuft weiter. |
| Ctrl-C | Run-Ordner bleibt mit `status: aborted` in `status.json`. |
| Rubrik-Version ≠ judge.json | Finalize Exit 2 — judge.json mit aktueller `rubrics/VERSION` neu erzeugen. |

## Referenzen
- Schritt-CLIs + Kontrakte: `scripts/README.md`
- Rubriken: `rubrics/visual.md`, `rubrics/slop.md`, `rubrics/conversion.md`, `rubrics/VERSION`
- Feature-Spec: `features/PROJ-5-skill-orchestrierung.md`
