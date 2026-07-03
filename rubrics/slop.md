# Rubrik: KI-Generik / Slop — Judge-Pass „slop"

**Version:** siehe `rubrics/VERSION` · **Skala:** KI-Score **0–10** (design-ai-check-Rubrik)
**Input:** die drei Screenshots + `snapshot.txt` (Copy-Stichprobe) aus PROJ-1.

> Der Judge liefert den **rohen KI-Score 0–10** (0 = wirkt handgebaut, 10 = maximaler
> Slop). `score-report.sh` **invertiert** ihn zur Dimension `slop`:
> `slop = (10 − ki_score) · 10` → 0 Slop = 100 Punkte.

## Auftrag an den Judge

Bewerte, wie stark die Seite nach **generischem KI-/Baukasten-Output** aussieht — der
„vibe-coded"/„AI-slop"-Look. Gemeint ist Austauschbarkeit und fehlende gestalterische
Entscheidung, **nicht** technische Qualität (die deckt „visuell" ab). Vergib **einen
ganzzahligen KI-Score 0–10**.

### Slop-Signale (je mehr, desto höher der KI-Score)
- Vorlagen-Hero mit generischem Verlauf/Blob, Standard-SaaS-Purple, Glassmorphism ohne Grund.
- Austauschbare Stock-/Midjourney-Ästhetik, „3D-Blob"-Illustrationen, generische Icon-Grids.
- Floskel-Copy („Elevate your …", „Seamlessly …", „Unlock the power of …"), leere Superlative.
- Symmetrische 3-Karten-Feature-Reihe ohne Inhaltsernst, Lorem-artige Platzhalter.
- Keinerlei Marken-Eigenheit: austauschbar auf jede beliebige Firma.

### Anti-Slop-Signale (senken den KI-Score)
- Eigenständige, konsistente Bildsprache; bewusste, ungewöhnliche Layout-Entscheidungen.
- Echte Inhalte/Fotos/Zahlen/Namen; spezifische, menschliche Copy.
- Marken-Details, die nur zu dieser Firma passen.

## Anker-Bänder (KI-Score 0–10)

| KI-Score | Anker | → Dimension `slop` |
|---|---|---|
| **0–1** | Klar handgebaut, distinktiv, keine Baukasten-Signale. | 90–100 |
| **2–3** | Überwiegend eigenständig, 1–2 generische Muster. | 70–80 |
| **4–6** | Gemischt: erkennbar Template-nah, aber mit eigenen Inhalten. | 40–60 |
| **7–8** | Deutlich generisch: mehrere Slop-Signale, austauschbar. | 20–30 |
| **9–10** | Reiner Baukasten-/KI-Look, keine gestalterische Entscheidung erkennbar. | 0–10 |

## Befunde (Pflicht)
Je Befund: **title**, **severity**, **evidence** (welches Slop-Signal konkret wo),
**location** (Sektion + Viewport), **source** = `slop`.
