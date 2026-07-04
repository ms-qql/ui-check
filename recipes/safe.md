# Rezept: Safe — konservatives Facelift

**Rezept-Version:** siehe `VERSION` · **Variante:** `safe` · **Ziel:** Der Kunde
erkennt seine Seite sofort wieder — nur aufgeräumt, hierarchisch klar und auf das
Conversion-Ziel aus `brief.md` ausgerichtet. Kein Risiko, kein Effekt-Feuerwerk.

## Dials (bindend, ins `manifest.json` schreiben)

| Dial | Wert | Bedeutung |
|---|---|---|
| `variance` | **3** (2–4) | symmetrisches 12-Spalten-Grid, ruhige Ausrichtung; Asymmetrie nur als leichter Versatz |
| `motion` | **2** (1–3) | keine Auto-Animationen; nur `:hover`/`:active`/Focus-Übergänge (200–300 ms, transform/opacity) |
| `density` | Original ± 1 | Informationsdichte der Original-Seite beibehalten |

## Layout-Rezept

- **Sektionsreihenfolge = Sektionsplan aus `brief.md`** (aus dem Original
  abgeleitet). Keine Sektionen erfinden, keine wegwerfen — nur zusammenlegen,
  wenn der Brief es begründet.
- **Hero:** passt in den Initial-Viewport. Max. 4 Text-Elemente (Eyebrow ODER
  Badge, Headline ≤ 2 Zeilen, Subtext ≤ 20 Wörter, CTAs). Headline-Skala
  `text-4xl md:text-6xl`; primärer CTA ohne Scrollen sichtbar.
- **Erlaubte Layout-Familien:** `full-bleed`, `stack`, `split`, `grid`,
  `logo-wall`, `accordion`. Je Familie max. 2 Einsätze pro Seite;
  `split` nie mehr als 2× in Folge (Zigzag-Gate).
- **Container:** `max-w-7xl mx-auto`; Sektionsabstände gleichmäßig
  (`py-16`–`py-24`). Volle Viewport-Höhen mit `min-h-[100dvh]`, nie `h-screen`.
- **Karten nur bei echter Hierarchie** — sonst `border-t`/`divide-y`/Weißraum.
  Ein Radius-System für die ganze Seite (aus `tokens.json`-Radius abgeleitet).

## Typografie & Farbe (Token-Treue)

- **Fonts, Farben, Radius, Schatten ausschließlich aus `shared/tokens.json` /
  `tailwind-theme.css`.** Kein Font-Swap, keine neuen Akzente. Anpassungen
  (z. B. Kontrast-Fix) nur, wenn `brief.md` sie begründet und
  `shared/tokens-extra.json` sie deklariert.
- Body-Text `max-w-[65ch]`, Zeilenhöhe großzügig; Headlines über Gewicht und
  Größe differenzieren, nicht über zusätzliche Farben.
- Fonts via Bunny Fonts oder self-hosted (`@font-face`, `font-display: swap`) —
  **nie** Google-Fonts-CDN (Gate).

## Interaktion & Zustände

- Jede interaktive Fläche: Hover- (Hintergrund/1 px-Translate), Active-
  (`scale-[0.98]`) und sichtbarer Focus-Zustand.
- Button-Text muss auf Desktop einzeilig bleiben (primärer CTA ≤ 3 Wörter — Gate).
- WCAG AA auf jedem CTA und Formular-Element; im Brief gemeldete
  Kontrast-Verstöße des Originals werden hier behoben (mit Token-Begründung).

## Dynamik / Ambient (Default, zurückhaltend — Motion-Dial 3)

Auch Safe darf leben — aber dezent, nie als Effekt-Feuerwerk. Alle Effekte
**token-only** (nur `--color-primary`/`--color-surface` via `color-mix`), **kein
Bild neu erzeugt**, und in `@media (prefers-reduced-motion: reduce)` abgeschaltet.

- **Ambient-Verlauf** (`effects/Ambient`, CSS): sehr langsamer, driftender
  Token-Verlauf hinter Hero/CTA (`tone="light"` auf Weiß, `tone="dark"` auf Navy).
  Geringe Amplitude/Deckkraft — spürbar, nicht ablenkend.
- **Bild-Slot-Sheen** (CSS): leiser Licht-Sweep über Platzhaltern; `uic-kenburns`
  liegt für echte Fotos bereit (Platzhalter uniform ⇒ erst mit Bild sichtbar).
- **Dezente Reveals** (`effects/Reveal`, `motion/react`): kurzes Fade-up beim
  Scrollen (≤ 14 px, ~0.5 s). Motion-`initial`-Styles (opacity 0) sind erlaubt —
  der Mockup-Export macht sie in statischen Klonen (Vorschau/Vergleich) sichtbar.
- Kein Glas, kein Auto-Karussell, keine Parallax-Hijacks — das bleibt Bold.

## Anti-Slop (Pflicht, Auswahl mechanisch per Gate geprüft)

- Ein CTA-Label pro Absicht (`intent`) auf der ganzen Seite (Gate).
- Keine drei identischen Feature-Karten nebeneinander — 2-Spalten-Gruppierung
  oder Liste mit Gewichtung.
- Max. 1 Eyebrow pro 3 Sektionen; keine Sektionsnummern (`01 /`), keine
  Deko-Statuspunkte, keine Scroll-Cues, keine Versions-Labels.
- Deutsche Copy aus `shared/content.json` unverändert übernehmen — Original-Copy
  wurde dort bereits verbessert; nichts erfinden, keine Lorem-Reste (Gate).
- Zahlen/Claims nur aus dem Original; keine ausgedachten Kennzahlen oder
  Testimonials.

## Komponenten

- Basis: **shadcn/ui-Kopien** (Copy-Paste-Vendoring nach
  `<variante>/components/ui/`), an Tokens angepasst — nie im Default-Zustand
  lassen. Keine Registry-Fetches zur Buildzeit.
- **`cn()`-Utility Pflicht mit `tailwind-merge`** (shadcn-Standard:
  `twMerge(clsx(inputs))`, Deps `clsx` + `tailwind-merge`). Reines Zusammenketten
  von Klassen löst Konflikte NICHT auf — Override-Klassen (`bg-surface text-primary`
  über der Variante `bg-primary text-surface`) gewinnen sonst unvorhersehbar
  (weißer Text auf weißem Button). Buttons mit farblichem Override immer über `cn`.
- **Kein Kontrast-Blindflug bei Overrides:** wird ein Button/Element gegenüber
  seiner Default-Variante umgefärbt, Vorder- UND Hintergrund gemeinsam setzen
  (nie nur `bg-*` ohne passendes `text-*`).
- Framework-agnostisches Client-React: kein `next/*`-Import, Motion nur aus
  `motion/react` (hier kaum nötig), Icons aus **einer** Familie
  (`@phosphor-icons/react` bevorzugt).
- Bild-Slots als neutraler Platzhalter (Token-Fläche + Slot-Label) mit
  `data-image-slot="<id>"` — jeder Slot in `images.md` (Gate).
