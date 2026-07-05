# Template „meridian"

Dunkles, editoriales Observability-/Dev-Tool-SaaS im „Blueprint"-Stil. 12 token-agnostische Blocks (`registry/blocks/meridian-*.jsx`), komponiert über `content.json`. Branding-Profil: `branding/meridian/`. Clean-Room aus `meridian-nextjs-template.vercel.app` (kein Fremdcode/Assets).

## Signatur
- **Dunkel-default** (`bg-ink text-paper`), zweifarbige Display-Headlines (paper + muted).
- Space Grotesk (Display) · DM Sans (Body) · JetBrains Mono (Labels) — self-hosted (OFL).
- Mono-„Dispatch"-Kopfzeilen, Spec-Karten (`§ MRD / 01`), Incident-Log-Tabelle, Ticket/Receipt-Preise, roter Signal-Akzent, irisierender CTA-Glow, Riesen-Footer-Wortmarke.

## Sektionen (12)
nav · hero · glance (feature-list A–F) · bulletin (stats) · flow (steps + Device) · incidents (log-table) · testimonials · compare · island (showcase) · logos · pricing · footer

## Bild-Slots (5)
`hero-visual`, `glance-visual`, `testimonial-1..3` — Platzhalter über `Slot`; `ui-images-fill` (PROJ-20) füllt sie. Watch-/Phone-Mockups sind code-gerendertes UI (keine Slots); Logo-Wand nutzt Text-Wortmarken.

## Verwenden
```css
@import "tailwindcss";
@import ".../branding/meridian/tailwind-theme.css";
@import ".../registry/styles/base.css";
```
```jsx
import App from ".../registry/templates/meridian/App.jsx";   // rendert content.json
```

## Verifikation
`preview/` (esbuild + Tailwind) baut das komponierte Template gegen das Meridian-Branding — siehe `preview/build.mjs`.
