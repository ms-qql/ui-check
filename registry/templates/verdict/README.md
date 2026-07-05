# Template „verdict"

Komplett-Template für **Premium-Kanzlei/Agentur**: helle Seite mit dunklen Foto-Sektionen (Hero/Prozess/Footer), warmer Amber-Akzent, große editorial Geist-Typografie, Pill-Buttons, Mono-Labels.

**Herkunft:** Clean-Room-Nachbau von `verdict-nextjs-template.vercel.app` (shadcnblocks, kommerziell). Es wurde nur Struktur/Look nachgebaut — kein proprietärer Code, keine Original-Assets. Fotos sind Platzhalter (`data-image-slot`).

## Bausteine (Reihenfolge)

`verdict-nav` → `hero` → `about` → `services` → `cases` → `process` → `team` → `awards` → `testimonials` → `faq` → `contact` → `footer`

## Dateien

- `template.json` — Manifest (Block-Reihenfolge, Branding-Ref, Industrie/Mood).
- `content.json` — generalisierte Platzhalter-Copy + `image_slots` (keine Kundendaten).
- `App.jsx` — Kompositions-Entry (`content.sections[].block` → Registry-Block). Dient zugleich als Vorlage für den `ui-redesign`-`App.jsx`.
- `preview/` — lokaler Verifikations-Build.

## Branding

Nutzt Profil **`branding/verdict/`** (Farben/Fonts/Radius). Für ein anderes Branding einfach ein anderes Profil importieren — Struktur bleibt gleich.

## Lokal ansehen (Preview)

```bash
cd registry/templates/verdict/preview
ln -sfn ../../../../templates/verdict/poc/node_modules node_modules   # Build-Deps (esbuild + tailwind)
node build.mjs                                                        # → dist/index.html
```
Dann `dist/index.html` öffnen (Fotos erscheinen als Slot-Platzhalter).
