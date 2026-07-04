# Rezept: Bold — mutige Neuinterpretation

**Rezept-Version:** siehe `VERSION` · **Variante:** `bold` · **Ziel:** Zeigen,
was die Marke sein könnte — unkonventionelles Layout, spürbare Motion, aber
dieselben Tokens, derselbe Content und dasselbe Conversion-Ziel wie Safe.
Mut heißt Komposition, nicht Effekt-Overkill.

## Dials (bindend, ins `manifest.json` schreiben)

| Dial | Wert | Bedeutung |
|---|---|---|
| `variance` | **8** (7–9) | asymmetrische Grids (`2fr 1fr 1fr`), Überlappungen, große Leerzonen, gebrochene Raster |
| `motion` | **7** (6–8) | Scroll-getriebene Reveals, gestaffelte Einblendungen, ein Scroll-Narrativ-Effekt |
| `density` | Original − 1 | großzügiger als das Original (`py-24`–`py-40`), Fokus je Sektion |

Mobile-Override (Pflicht): Asymmetrie kollabiert unter 768 px auf strikt
einspaltig; Motion reduziert sich auf Fades; `prefers-reduced-motion`
deaktiviert alle Scroll-Effekte.

## Layout-Rezept

- **Sektionsplan aus `brief.md` bleibt bindend** — Bold interpretiert die
  *Anordnung* neu, nicht den Inhalt. CTA-First: das Conversion-Ziel bekommt die
  auffälligste Position der Seite.
- **Erlaubte Layout-Familien:** `full-bleed`, `stack`, `split`, `bento`,
  `sticky-stack`, `horizontal-scroll`, `marquee`, `curtain`, `split-scroll`,
  `color-shift`. Mindestens 4 verschiedene Familien pro Seite; keine Familie
  mehr als 2×; `split` nie mehr als 2× in Folge (Zigzag-Gate). Max. **ein**
  Scroll-Hijack (`horizontal-scroll` ODER `curtain`) pro Seite.
- **Hero:** darf brechen (Split-Screen, Asymmetrie, animierter Hintergrund),
  aber Headline ≤ 2 Zeilen und primärer CTA ohne Scrollen sichtbar bleiben
  Pflicht.
- Bento-Grids: exakt so viele Zellen wie Inhalte; 2–3 Zellen mit visueller
  Variation (Token-Gradient, Muster, Bild-Slot) — kein Weiß-auf-Weiß-Raster.

## Effekt-Vokabular (kuratiert — nach React/Motion portieren, nie per CDN)

Quelle: cinematic-site-components (MIT), Paper Shaders, Magic UI/Aceternity.
Alle Effekte assetfrei, Farben ausschließlich über Token-Variablen.

| Effekt | Einsatz | Umsetzung |
|---|---|---|
| Sticky-Stack-Narrativ | Leistungen/Features als gepinnte Erzählung | Motion `useScroll` + sticky |
| Scroll-Color-Shift | Hintergrundwechsel je Sektion (Token-Farben) | CSS/Motion |
| Text-Mask-Reveal | Headline füllt sich beim Scrollen | CSS `background-clip` + Scroll-Progress |
| Horizontal-Scroll-Galerie | Portfolio/Referenzen | Motion `useScroll` + translate |
| Curtain-Reveal | Hero-Einstieg | Motion, einmalig |
| Kinetic Marquee | Logo-Wall/Keywords | CSS-Animation, pausiert bei Hover |
| Mesh-Gradient / Paper Shaders | Ambient-Hintergrund (max. 1 Sektion) | `@paper-design/shaders-react` oder CSS |
| Spotlight-Border-Cards | Karten-Hover | CSS Custom Properties |

**Nicht verwenden** (Gimmick ohne Conversion-Motiv): Glitch, Image-Trail,
Typewriter, Text-Scramble, Custom-Cursor, Drag-to-Pan.

**Motion muss motiviert sein:** jede Animation beantwortet in einem Satz, was
sie kommuniziert (Hierarchie, Erzählung, Feedback, Zustandswechsel). Kontinuierliche
Werte (Scroll, Pointer) nie über `useState`/`addEventListener('scroll')` —
Motion-Hooks (`useScroll`, `useMotionValue`, `useTransform`) verwenden.

## Typografie & Farbe (Token-Treue — auch für Bold)

- Gleiche Regel wie Safe: **alles aus `shared/tokens.json` /
  `tailwind-theme.css`**; Abweichungen nur mit Brief-Begründung +
  `shared/tokens-extra.json`. Bold differenziert über Skala, Gewicht,
  Komposition und Motion — nicht über neue Farben.
- Display-Typo darf größer (`text-6xl md:text-8xl` bei ≤ 5 Wörtern), Emphase
  über Italic/Bold derselben Familie — keine Fremd-Serif als Schmuckwort.
- Fonts via Bunny Fonts oder self-hosted — nie Google-Fonts-CDN (Gate).

## Dynamik / Ambient (Default) + Glass

Alle Effekte **token-only** (`color-mix` aus `--color-primary`/`--color-surface`),
**assetfrei** (kein neues Bild), reduced-motion abgeschaltet.

- **Ambient + Mesh** (`effects/Ambient`, CSS statt WebGL): driftender Token-Verlauf;
  `mesh` fügt einen langsam rotierenden Conic-Layer hinzu (max. 1 Sektion, i. d. R.
  Hero). Statt `@paper-design/shaders-react` reicht der CSS-Mesh — robuster im
  Offline-Bundle; die Dependency nur nehmen, wenn wirklich WebGL nötig ist.
- **Thematische Silhouette** (`effects/Skyline`, Inline-SVG, `currentColor` +
  `text-surface/10`): dezente, marken-/branchenpassende Form im Hero (hier
  Gebäude). Für andere Branchen ein neutrales Pendant — nie ein Fremd-Motiv.
- **Spotlight-Cards** (`effects/Spotlight`, CSS `--mx/--my`): Token-Glow folgt dem
  Cursor — Interaktion, keine Dauerbewegung.
- **Parallax** (`effects/Parallax`, Motion `useScroll`): Bild-Slots/Formen bewegen
  sich minimal gegen den Scroll. **Ken-Burns** (`uic-kenburns`) für echte Fotos.
- **Glass — erlaubt, aber diszipliniert:** nur **funktional begründet** (etwas liegt
  sichtbar über etwas: sticky Nav, ein Panel über Hero/Color-Shift), **nur Token-
  Farben** (Navy-Glas: `bg-surface/10 backdrop-blur-md border-surface/25`), **max.
  1–2 Flächen**, Kontrast/Lesbarkeit gewahrt. **Verboten** (= KI-Slop): Glas ohne
  Grund, Glas über bunten/Fremdfarben-Blobs, flächendeckendes Glassmorphism.
  Kein Glas in Safe.

## Anti-Slop (Pflicht, Auswahl mechanisch per Gate geprüft)

- Ein CTA-Label pro Absicht; primärer CTA ≤ 3 Wörter, einzeilig (Gates).
- Kein AI-Lila/Neon-Glow, keine generischen Mesh-Blobs in Fremdfarben — Ambient
  nur aus Token-Farben.
- Max. 1 Eyebrow pro 3 Sektionen; keine Sektionsnummern, Deko-Statuspunkte,
  Scroll-Cues („Scroll to explore"), Locale-/Wetter-Strips, Versions-Labels,
  Fake-Screenshots aus `<div>`s.
- Deutsche Copy aus `shared/content.json`; nichts erfinden (Gate: Lorem/TODO).

## Komponenten

- Wie Safe: shadcn/ui-Vendoring + portierte Effekt-Komponenten unter
  `<variante>/components/` (Effekte unter `components/effects/`).
- **`cn()` Pflicht mit `tailwind-merge`** (`twMerge(clsx(inputs))`, Deps `clsx` +
  `tailwind-merge`) — Farb-Overrides (z. B. heller CTA auf dunklem Hero) müssen
  Konflikte deterministisch auflösen, sonst weiß-auf-weiß. Vorder- und
  Hintergrundfarbe bei Overrides immer gemeinsam setzen.
- Framework-agnostisches Client-React (kein `next/*`); Motion aus
  `motion/react`; interaktive Effekte als isolierte Leaf-Komponenten.
- **Motion-Startzustände** (`initial`/`whileInView` mit opacity 0) sind erlaubt —
  der Mockup-Export macht statische Klone (Vorschau/Vorher-Nachher) über die
  Shell wieder sichtbar; keine Extra-Vorkehrung im Varianten-Code nötig.
- Bild-Slots wie Safe (`data-image-slot`, `images.md`-Pflicht) — Bold darf
  Slots großflächiger inszenieren (Masken, Parallax), erfindet aber keine
  zusätzlichen Bilder ohne Slot.
