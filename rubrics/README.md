# rubrics/ — Versionierte Judge-Rubriken (PROJ-4)

Diese Rubriken sind der **Mechanismus für Reproduzierbarkeit** (AC: zwei Läufe
derselben URL ≤ ±5 Punkte). Der Claude-Judge in der Orchestrierung (PROJ-5) liest
sie in **frischem Kontext** (ohne Pipeline-Verlauf, Bias-Schutz) und bewertet die
Screenshots/Snapshot streng anhand der Anker-Beispiele je 20er-Band.

| Datei | Judge-Pass | Skala | Fließt in Dimension |
|---|---|---|---|
| `visual.md` | Visuelle Qualität | 0–100 | `visuell` |
| `slop.md` | KI-Generik / Slop (design-ai-check) | KI-Score 0–10 | `slop` (invertiert: `(10−ki)·10`) |
| `conversion.md` | Cai-Modell (Clarity/Credibility/Logic/Action/Emotion) | je 0–100 | `conversion` (Mittel) |

## Versionierung (wichtig)

`VERSION` (aktuell **`2026.07-1`**) taggt jede Rubrik-Generation. **Jede inhaltliche
Änderung an einer Rubrik = neue Version** — sonst werden Benchmarks in
`data/runs.jsonl` unvergleichbar. Die aktive Version landet in `report.md`,
`scores.json` und pro Lauf in `runs.jsonl`.

`score-report.sh` liest `rubrics/VERSION` und **verlangt**, dass die im `judge.json`
gemeldete `rubric_version` damit übereinstimmt (sonst Abbruch: veralteter Judge-Lauf).

## Judge-Ausgabe-Kontrakt (`<run-dir>/judge.json`)

PROJ-5 erzeugt diese Datei aus den drei Judge-Pässen; `score-report.sh` konsumiert sie.
Siehe `scripts/README.md` → `score-report.sh` für das vollständige Schema.
