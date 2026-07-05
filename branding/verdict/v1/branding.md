# Branding-Guide — Profil „verdict"

Premium-Kanzlei/Agentur-Handschrift: **hell mit dunklen Foto-Sektionen**, warmer Amber-Akzent, große editorial Geist-Typo, Pill-Buttons, Mono-Labels. Abgeleitet aus `verdict-nextjs-template.vercel.app` (Clean-Room). Token-agnostisch — jeder Registry-Block rendert damit die Verdict-Optik, ohne Kundendaten.

## Farben (Rollen → Hex)

| Token | Hex | Rolle / Einsatz |
|---|---|---|
| `paper` | `#ffffff` | Seiten-Hintergrund (hell) |
| `ink` | `#0a0a0a` | Text; **Fläche dunkler Sektionen** (Hero, Nav, Footer, Prozess) |
| `ink-soft` | `#171717` | dunkler Hover / leicht aufgehellte dunkle Fläche |
| `muted` | `#737373` | sekundärer Text, Fließtext |
| `surface` | `#f5f5f5` | dezent erhabene Fläche, Formular-Inputs, Platzhalter |
| `line` | `#e3ddd6` | Rahmen, Divider (warmes Grau) |
| `accent` | `#c87f2c` | **Marken-Akzent** — Eyebrow-Punkte, Fokus-Ring, Akzent-Linien, CTA-Gradient |
| `accent-soft` | `#e8a95c` | hellerer Akzent, Verlaufs-Mittelton |
| `sand` | `#c9b191` | warme Kennzahl-Kachel (z. B. „$1.2B recovered") |

**Kontrast-Prinzip:** Text auf dunkler Fläche = `paper`, sekundär = `paper/70`. Keine Roh-Hex in Blocks, keine Tailwind-Default-Palette (`blue-500` etc.).

## Typografie

- **Familie:** Geist (Sans) + Geist Mono — self-hosted (OFL, DSGVO, **kein** Google-CDN).
- **Display/Headlines** (`.display`): Weight **500**, Tracking **−0.02em**, Leading **1.02**.
  - Hero: `clamp(2.75rem, 6vw, 5rem)` · Section-H2: `clamp(2rem, 4.6vw, 3.5rem)`.
- **Body:** `~1.05rem`, `leading-relaxed`, Farbe `muted`.
- **Mono-Label** (`.mono-label`): Geist Mono, `uppercase`, Tracking **0.18em**, `~0.68rem` — für Eyebrows-Zusatz, „STEP 1", „SELECTED I", „PRIVATE & SECURE", Kennzahl-Captions.

## Form & Komponenten

- **Radius:** Basis `0.625rem`; Karten `rounded-2xl`/`rounded-3xl`; Buttons/Chips `rounded-full`.
- **Buttons (Pill):** `primary` = `bg-ink text-paper` · `invert` = `bg-paper text-ink` · `soft` = `bg-surface` · `ghostDark` = `bg-paper/10` + Ring (auf dunkel).
- **Eyebrow-Pill:** `border-line`, `rounded-full`, mit zwei Akzent-Punkten (`• Label •`).
- **Nav:** schwebende, abgerundete **dunkle** Leiste (`bg-ink/90`, `backdrop-blur`, Ring), zentriert.
- **Sektions-Rhythmus:** `.section-padding` = `clamp(4rem, 8vw, 8rem)`; Container `max-w-80rem`.
- **Grid-Signatur:** Header oft 12-Spalten (Eyebrow links 3, Inhalt rechts 9); versetzte Team-Karten; Bento-Testimonials; Sticky-Stack bei Case-Studies.

## Do / Don't

- ✅ Dunkle Foto-Sektionen sparsam als Anker (Hero/Prozess/Footer), dazwischen viel Weißraum.
- ✅ Akzent `accent` dosiert (Linien, Punkte, ein CTA-Gradient) — nicht flächig.
- ❌ Keine Google-Fonts-CDN, keine Roh-Hex/Default-Palette in Blocks, keine Kundendaten/‑fotos in der Registry (nur `data-image-slot`-Platzhalter).

## Dateien im Profil

- `tailwind-theme.css` — `@theme`-Tokens + `@font-face` (Konsument importiert dies statt `registry/styles/tokens.css`).
- `tokens.json` — DTCG-Tokens (maschinenlesbar).
- `fonts/` — Geist/Geist-Mono woff2 (self-hosted).
- `logo.svg` — generalisierte V-Marke.
