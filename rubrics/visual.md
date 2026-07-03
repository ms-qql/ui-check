# Rubrik: Visuelle Qualität — Judge-Pass „visuell"

**Version:** siehe `rubrics/VERSION` · **Skala:** 0–100 (ein Wert für die Seite)
**Input:** die drei Fullpage-Screenshots (375 / 768 / 1440 px) aus PROJ-1.

## Auftrag an den Judge

Bewerte die **handwerkliche visuelle Qualität** der gerenderten Seite über alle drei
Viewports. Bewerte, was du **siehst** — nicht Marke, Branche oder vermuteten Aufwand.
Kein Glätten, keine Höflichkeit: ordne streng dem passenden 20er-Band zu und wähle
innerhalb des Bandes den Feinwert.

### Kriterien (gleichgewichtet)
- **Layout & Raster:** Ausrichtung, konsistente Abstände, Spalten-Disziplin, keine Kollisionen/Überläufe.
- **Typografie-Hierarchie:** klare Skala (H1→Body), Zeilenlänge, Lesbarkeit, konsistente Schriften.
- **Farb- & Kontrastwirkung:** kohärente Palette, gezielte Akzente, ruhige Flächen (Ästhetik, nicht WCAG — das ist die A11y-Dimension).
- **Bild-/Asset-Qualität:** scharfe, konsistente Bilder/Icons, kein Stretch/Pixeln, stimmige Bildsprache.
- **Responsiveness:** hält das Layout über die drei Viewports, ohne zu brechen.
- **Politur/Detail:** Zustände, Rundungen, Schatten, Whitespace-Rhythmus, „fertig"-Anmutung.

## Anker-Bänder (0–100)

| Band | Anker-Beschreibung |
|---|---|
| **0–20** | Kaputt: überlappende/abgeschnittene Elemente, Fließtext ohne Hierarchie, kollidierende Farben, gestretchte Bilder. Wirkt unfertig/defekt. Bricht auf ≥ 1 Viewport. |
| **21–40** | Rohbau: erkennbares Layout, aber unruhige Abstände, schwache Hierarchie, willkürliche Farben, gemischte Icon-Stile. Auf Mobil sichtbar gequetscht. |
| **41–60** | Solider Durchschnitt: Raster hält meist, brauchbare Hierarchie, funktionierende, aber generische Palette. Kleinere Ausrichtungs-/Abstandsfehler. Responsiv ohne grobe Brüche. |
| **61–80** | Gut & poliert: konsistentes Raster, klare Typo-Skala, gezielte Akzentfarben, saubere Bilder, angenehmer Whitespace. Über alle Viewports stabil; nur Detail-Schwächen. |
| **81–100** | Exzellent: durchkomponiert, präzise Ausrichtung, souveräne Hierarchie, distinktive und kohärente Bildsprache, sichtbare Detail-Politur. Studio-/Award-Niveau, keine Schwächen. |

## Befunde (Pflicht)
Liefere je Befund: **title**, **severity** (`hoch`/`mittel`/`niedrig`), **evidence**
(1 Satz, was konkret auf dem Screenshot), **location** (Sektion + Viewport, z. B.
„Hero, 375px"), **source** = `visual`. Kein Befund ohne sichtbaren Beleg.
