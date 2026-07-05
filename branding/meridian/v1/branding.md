# Branding-Guide — Profil „meridian"

Editoriale **Dark-SaaS-/Observability-Handschrift** im „Blueprint"-Stil: near-black Default-Fläche, zweifarbige (weiß + grau) Display-Headlines, technische Mono-„Dispatch"-Labels, Spec-Karten & Ticket/Receipt-Optik, roter Signal-Akzent und ein irisierender CTA-Glow. Abgeleitet aus `meridian-nextjs-template.vercel.app` (Clean-Room). Token-agnostisch — jeder Registry-Block rendert damit die Meridian-Optik, ohne Kundendaten.

> **Dunkel-default:** Anders als `verdict` (hell-default) ist Meridian dunkel. Der App-/Template-Wrapper nutzt `bg-ink text-paper`; Blocks setzen Flächen mit `bg-ink` / `bg-ink-soft` und Rahmen mit `border-paper/NN`. Helle Flächen (`paper`/`surface`) treten nur als **invertierte** Akzent-Karten auf (mittlere Kennzahl, Bridge-Ticket).

## Farben (Rollen → Hex)

| Token | Hex | Rolle / Einsatz |
|---|---|---|
| `paper` | `#ffffff` | heller Text auf Dunkel; **invertierte Karten** (Kennzahl „2", Bridge-Ticket) |
| `ink` | `#0a0a0a` | **Seiten-Hintergrund** (dunkel) |
| `ink-soft` | `#16161a` | erhabene dunkle Karte / Hover (Testimonial-Karten, Mockup-Rahmen) |
| `muted` | `#8f8f8f` | sekundärer Text, Fließtext, **zweiter Teil der Headline** (Grau-Ton) |
| `surface` | `#f5f5f5` | helle Sekundärfläche innerhalb invertierter Karten |
| `line` | `#e5e5e5` | Rahmen/Divider in **hellen** Flächen (auf Dunkel: `border-paper/10–15`) |
| `accent` | `#e5484d` | **Signal-Rot** — SEV-Badge, Budget-Burn-Bar, Live-Dot, Peak-Kennzahl |
| `accent-soft` | `#ff8a5c` | wärmerer Akzent — irisierender **CTA-Glow-Gradient** |
| `sand` | `#b9b09c` | warmer Neutralton (selten) |

**Kontrast-Prinzip:** Text auf `ink` = `paper`, sekundär `paper/60`, tertiär/Labels `paper/40`. Rahmen auf Dunkel = `paper/10`–`paper/15`. Keine Roh-Hex in Blocks, keine Tailwind-Default-Palette.

## Typografie (drei Familien)

- **Display/Headlines** (`.display` → `--font-display`): **Space Grotesk**, Weight 500–700, Tracking −0.02em, Leading ~1.0.
  - Hero `clamp(2.75rem, 7vw, 5.5rem)` · Section-H2 `clamp(2.25rem, 5vw, 4rem)` · Riesen-Footer-Wortmarke bis `16rem`.
  - Auch für große Zahlen (Kennzahlen 217/2/215, Ticket-Total, Uhr 9:41).
- **Body** (`--font-sans`): **DM Sans**, `~1.05rem`, `leading-relaxed`, Farbe `muted`.
- **Mono-Label** (`.mono-label` → `--font-mono`): **JetBrains Mono**, `uppercase`, Tracking 0.18em, `~0.68rem` — Dispatch-Kopfzeilen, Spec-Karten (`§ MRD / 01`), Tabellen-Header, Ticket-Zeilen, Fuß-Metadaten.
- Alle Schriften **self-hosted** (OFL, DSGVO, via Bunny geladen — **kein** Google-CDN).

### Signatur: zweifarbige Headline
Headlines in zwei Spans splitten — erster Teil `text-paper`, zweiter `text-muted`. Beispiel: „**Silence your** alerts, with confidence." Bei „Legacy." zusätzlich `line-through decoration-paper/30`.

## Form & Komponenten

- **Radius:** Basis `0.625rem`; Karten `rounded-xl`/`rounded-3xl`; Buttons/Chips `rounded-full`; Mockups bis `rounded-[3rem]`.
- **Buttons (Pill):** `primary` = `bg-paper text-ink` · `invert` = `bg-ink` + Ring · `quiet` = nur Text + „→" · `outline` = `border-paper/20`.
- **CTA-Glow:** wichtige Primary-Buttons erhalten hinter dem Pill einen weichgezeichneten `from-accent via-accent-soft to-accent`-Gradient (`blur-md`) — die irisierende Meridian-Signatur.
- **Dispatch-Bar:** wiederkehrende Kopf-Metazeile jeder Sektion: drei Mono-Labels (links mit ●, mittig, rechts) über einer Haarlinie, optional feines Punktraster (`.dot-grid`).
- **Spec-Karte:** bordierte Mono-Datenkarte (`§ MRD / 01 · REV A` + Label/Wert-Zeilen), `border-paper/15`, `bg-paper/[0.02]`.
- **Ticket/Receipt:** Preis-Karten als Belege — Mono-Font, gestrichelte Divider, Perforationskerben (`bg-ink`-Kreise an den Kanten), Faux-Barcode, Stempel („★ Teams' pick ★").
- **Registration-Marks:** Eck-Winkel (`border-l border-t` etc.) um Bild-Slots.
- **Sektions-Rhythmus:** `.section-padding` = `clamp(4rem, 8vw, 8rem)`; Container `max-w-82rem`.

## Do / Don't

- ✅ Dunkel als Basis, Weißraum großzügig; helle/invertierte Flächen nur als seltener Kontrast-Anker.
- ✅ `accent` (Rot) **nur** als Signal (SEV, Budget-Burn, Live, Peak) — nie flächig.
- ✅ CTA-Glow sparsam (Hero-Primary, Bridge-Ticket, Footer-Subscribe).
- ✅ Mono-Labels für alle technischen Meta-Infos; Headlines konsequent zweifarbig.
- ❌ Keine Google-Fonts-CDN, keine Roh-Hex/Default-Palette in Blocks, keine Kundendaten/-fotos in der Registry (nur `data-image-slot`-Platzhalter).

## Dateien im Profil

- `tailwind-theme.css` — `@theme`-Tokens + `@font-face` (Konsument importiert dies statt `registry/styles/tokens.css`).
- `tokens.json` — DTCG-Tokens (maschinenlesbar).
- `fonts/` — DM Sans / Space Grotesk / JetBrains Mono woff2 (self-hosted).
- `logo.svg` — generalisierte Globus-/Meridian-Marke.
