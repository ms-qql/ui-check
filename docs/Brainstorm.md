# Brainstorm: UI-Audit- & Redesign-Pipeline („UI-Check") als Jupiter-MicroApp

**Datum:** 2026-07-02
**Status:** Abgeschlossen — bereit für `/abc-requirements`

## Session-Setup

- **Topic:** URL rein → visuelles + technisches Scoring → automatisiertes Redesign (Next.js/Tailwind/shadcn + Motion) → Branding-Extraktion → wiederverwendbares Portfolio → Assets → später Backend + Dokploy-Deploy. Einbindung als Jupiter-MicroApp.
- **Goals:** (a) Tool-Stack validieren, (b) Feature-Ideen, (c) priorisierter Fahrplan
- **Constraints:** Auch fremde Kunden-URLs; Ziel-Stack Next.js + Tailwind + shadcn/ui + Motion (ex Framer Motion); Paid-Tools minimieren, Optionen mit Pro/Contra; Jupiter-MicroApp-Muster: Video-Summary & Buch-Nuggets (PROJ-53, Skill headless aufgerufen)
- **User-Kontext:** OpenAI-Pro-Abo vorhanden (Bilder via ChatGPT/Codex „quasi kostenlos"; Achtung: deckt NICHT die OpenAI-API ab). Auxevo-Branding-Dokumente: `/home/dev/tools/Hal/00 Context/` (Branding.md, brand-book-a4.html, design-system.html, ICP.md, Offer.md, Writing Style.md)
- **Energie:** Mix — praktisch + einige wilde Ideen

## Traum-Durchlauf (Zielbild)

Kunden-URL rein, 20 Min später liegen vor: **Scoring-Report + klickbarer Redesign-Prototyp + Vorher/Nachher-Ansicht**. Mail-fertiges Kunden-PDF später. Redesign-Default: **mutige Neuinterpretation**, zusätzlich eine konservativere zweite Variante. Ergebnisse als **einfach teilbares HTML-Mockup** (keine Funktionalität nötig). Portfolio-Einheit: **Komponenten** + Brandings, getaggt nach Industrie/Kundensegment → Basis für Low-Cost-Angebote. Audit-only-Modus (z. B. Kaltakquise) ausdrücklich gewünscht.

---

## Phase (a): Tool-Stack-Validierung (Stand Juli 2026)

### Verdikt zum Agenten-Vorschlag

| Behauptung | Verdikt | Fakten |
|---|---|---|
| `agent-browser` (Vercel) | ✅ Real | [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) — Rust-CLI über CDP, A11y-Tree-Snapshots (~200–400 Tokens), Screenshots, Chrome-Profile (Login möglich), läuft als CLI ohne MCP. `npm i -g agent-browser`. Kostenlos. |
| PageSpeed MCP | ✅ Real (Community) | [ruslanlap/pagespeed-insights-mcp](https://github.com/ruslanlap/pagespeed-insights-mcp), [google-psi-mcp](https://github.com/ncosentino/google-psi-mcp). PSI-API kostenlos (~25k Req/Tag, API-Key). Alternative: **Lighthouse direkt als CLI** (`lighthouse <url> --output=json`, npm, gratis) — empfohlen. |
| „shadcn-space-mcp" / „shadcn.io MCP, 6000+ Komponenten" | ❌ Halluziniert | Real: **offizieller shadcn-MCP** ([Docs](https://ui.shadcn.com/docs/registry/mcp)) inkl. Dritt-Registries; [shadcnblocks MCP](https://www.shadcnblocks.com/shadcn-mcp) (paid, ~600 Blocks). |
| Relume CLI/API | ❌ Existiert nicht öffentlich | Nur Web-App + Figma/Webflow-Export; API ist [offener Community-Wunsch](https://community.relume.io/plans-for-api-access-for-sitemap-and-wireframe-creation-xSkjXXnFCsgF). → Ersatz: Claude generiert Wireframe-JSON selbst; Zukauf-Option [v0 Platform API](https://vercel.com/changelog/v0-platform-api-now-in-beta) (Beta, Credits, $5 frei/Monat). |

### Validierte Bausteine

**Scoring:**
- **Lighthouse/PSI** — Performance/A11y/SEO/Best-Practices, JSON, kostenlos ✅
- **Claude als Design-Judge** über Screenshots — vorhandener Skill **`design-ai-check`** (KI-Score 0–10) als Rubrik-Kern wiederverwendbar ✅. Kommerzielle Tools (UXAudit.Now, 1.450+ UX-Regeln via Claude Vision) machen intern genau das → Ansatz marktvalidiert.
- [Attention Insight](https://attentioninsight.com/pricing/) — Predictive-Eye-Tracking + Clarity Score; API erst ab **Pro €119/Mo** (800 API-Calls). Optional später. [Brainsight](https://www.brainsight.app/features/api): API nur via Sales. VisualEyes: tot (2023). Silktide/Baymard/Talos: keine API.

**Branding-Extraktion (alle kostenlos/lokal):**
- [dembrandt](https://github.com/dembrandt/dembrandt) — CLI: URL → Logo, Farben, Typo, Borders
- [extract-design-system](https://github.com/arvindrk/extract-design-system) — CLI + **Claude-Code-Skill**, JSON + CSS Custom Properties
- [design-extract](https://github.com/manavarya09/design-extract) — CLI + **MCP**, DTCG-konforme Tokens
- [@projectwallace/css-analyzer](https://www.npmjs.com/package/@projectwallace/css-analyzer) — npm/MIT, deterministische Token-Extraktion aus Live-CSS
- [Brandfetch](https://brandfetch.com/developers/pricing) — Logo-API gratis (500k/Mo); Brand-API $99/Mo → nur Logo-Fallback
- Paletten-Ausbau: [tints.dev](https://www.tints.dev/)-API (50–950-Stufen aus Hex)

**UI-Generierung:**
- Offizieller **shadcn-MCP** + freie Registries: [Magic UI](https://magicui.design/) (150+ animierte Komponenten, MIT), [Aceternity UI](https://ui.aceternity.com/) (200+, animierte Backgrounds, gratis; Pro $199 einmalig)
- **Skills:** [frontend-design](https://github.com/anthropics/claude-code/blob/main/plugins/frontend-design/skills/frontend-design/SKILL.md) (Anthropic, Anti-Generik-Designphilosophie), [taste-skill](https://github.com/Leonxlnx/taste-skill) (MIT; Regler: Design-Varianz, Bewegungsintensität, Dichte; Stile Soft/Minimalist/Brutalist), [web-artifacts-builder](https://github.com/anthropics/skills/blob/main/skills/web-artifacts-builder/SKILL.md) (Anthropic; React+Tailwind+shadcn → **eine self-contained HTML-Datei** via Parcel)
- **Motion** (motion.dev, ex Framer Motion): MIT, kostenlos; Import `motion/react`

**Assets:**
- Ohne Bildkosten: [Paper Shaders](https://github.com/paper-design/shaders) (`@paper-design/shaders-react`, MIT, 30+ Effekte als eine JSX-Zeile), [tsParticles](https://github.com/tsparticles/tsparticles) (MIT, JSON-Config), [Vanta.js](https://github.com/tengbao/vanta) (MIT), Magic UI/Aceternity-Backgrounds
- Bilder: [Recraft](https://www.recraft.ai/docs/api-reference/pricing) $0.04/Raster, **$0.08/SVG (einziger nativer SVG-Generator)**; Flux via fal.ai ~$0.015–0.05/Bild; gpt-image-1.5 $0.009–0.20; Gemini Flash Image $0.039 (Batch −50 %)
- Micro-Animationen: [LottieFiles](https://developers.lottiefiles.com/) 800k+ freie Assets, [LottieFiles MCP](https://mcpmarket.com/server/lottiefiles) (Suche), dotLottie-Player (MIT)
- **Meiden** (nicht automatisierbar): Unicorn Studio (GUI-only, $20/Mo), Rive-Erstellung (Editor-only)

### Architektur-Skizze (kostenminimal)

```
Jupiter MicroApp "UI-Check"  (Wrapper, wie PROJ-53 Buch-Nuggets)
  │  URL + Optionen (mode: landing|app, depth: audit|redesign)
  ▼
Claude Code headless (Skill "ui-check")
  ├─ 1. SEHEN    agent-browser → Screenshots 375/768/1440 + DOM/A11y-Snapshot
  │              (App-Modus: Flow-Walk, Snapshot pro Screen)
  ├─ 2. MESSEN   Lighthouse CLI → CWV, A11y, SEO, Best Practices (JSON)
  ├─ 3. BRANDING design-extract/dembrandt + css-analyzer → tokens.json
  │              (DTCG) → Tailwind-@theme; Logo via Brandfetch-Logo-API
  ├─ 4. SCOREN   Claude-Judge (design-ai-check-Rubrik + Cai-5-Teile +
  │              Conversion-/Usability-Heuristiken) + Lighthouse → Report
  ├─ 5. REDESIGN CTA-First-Mini-PRD → Wireframe-JSON → Skill-Sandwich
  │              (frontend-design + taste + Anti-Slop) → shadcn-MCP +
  │              Magic UI/Aceternity → Safe- & Bold-Variante
  ├─ 6. MOCKUP   web-artifacts-builder → EINE HTML-Datei:
  │              Voting-Screen + Vorher/Nachher-Slider + Sektionsvergleich
  ├─ 7. ASSETS   Paper Shaders/Magic UI (gratis) | Bilder optional
  └─ 8. PORTFOLIO Registry-Übernahme kuratierter Sektionen + Branding-Profil
```

**Basiskosten: ~0 €** (Claude-Tokens + optional Cents für Bilder).

---

## Phase (b): Ideen (26)

### Domain 1 — Output/Workflow

**[Output #1] Triple-Deliverable pro Lauf** — _Concept:_ `report.md` + lauffähiges Mockup + Vorher/Nachher, alles in einem Run-Ordner, aus Jupiter verlinkt. _Novelty:_ Nicht nur Analyse — anfassbares Ergebnis.

**[Output #2] Vorher/Nachher als Split-View mit Slider** — _Concept:_ Original-Screenshot vs. neues UI, synchron scrollend, Drag-Slider, umschaltbar pro Viewport. _Novelty:_ Unterschied in 5 Sekunden sichtbar.

**[Output #3] Sektionsweiser Vergleich** — _Concept:_ Seite wird in Sektionen zerlegt; Vergleich + 1-Satz-Begründung pro Sektion. _Novelty:_ Redesign-Entscheidungen werden einzeln verhandelbar.

**[Output #4] Score-Delta als Verkaufsargument** — _Concept:_ Prototyp durchläuft dieselbe Scoring-Pipeline („45 → 87/100"). _Novelty:_ Selbst-validierend; zugleich QA-Gate.

**[Output #5] ChatGPT-Pro als Bild-Kanal** — _Concept:_ Pipeline generiert fertige Bild-Prompts + Platzhalter; Bilder via Pro-Abo (ChatGPT/Codex) manuell/halbautomatisch. _Novelty:_ Null Zusatzkosten. ⚠️ Pro-Abo ≠ API-Credits.

### Domain 2 — Redesign-Strategie

**[Redesign #6] Zwei-Varianten-Lauf „Bold" + „Safe"** — _Concept:_ Default mutige Neuinterpretation + konservatives Facelift; Ansicht Original/Safe/Bold. _Novelty:_ Wahl statt Ultimatum.

**[Redesign #7] Geteilter Kern, divergente Präsentation** — _Concept:_ Beide Varianten teilen Tokens + Content-Struktur; nur Layout-Rezept/Animations-Level differiert (~40 % Token-Ersparnis). _Novelty:_ Echte Vergleichbarkeit.

**[Redesign #8] Anti-Slop-Regelwerk für „Bold"** — _Concept:_ design-ai-check-Rubrik invertiert als Generierungs-Constraints (kein Hero-3-Cards-Standard, kein Purple-Gradient, asymmetrische Grids bevorzugt). _Novelty:_ Bewertungs- = Bau-Maßstab.

**[Redesign #25] CTA-First-Redesign-Brief** — _Concept:_ Erst Conversion-Ziel + primärer CTA + Mini-PRD (nach Aliena Cai), dann Design; Iterationsreihenfolge Struktur → Content → Visuals. _Novelty:_ Optimiert auf ein Ziel, nicht nur „schöner".

### Domain 3 — Portfolio & Sharing

**[Portfolio #9] Komponenten-Registry im shadcn-Format** — _Concept:_ Lokale `registry.json`; Metadaten: Industrie, Segment, Sektionstyp, Stil, Herkunfts-Run. Offizieller shadcn-MCP liest sie wie jede Registry. _Novelty:_ shadcn-Infrastruktur als Portfolio-Backend.

**[Portfolio #10] Branding-Bibliothek als Token-Profile** — _Concept:_ `branding/<name>/` mit DTCG-Tokens + Tailwind-Theme + Logo + Fonts + Tonalität. **Auxevo = Eintrag #1** (aus `/home/dev/tools/Hal/00 Context/`). Jeder Kunden-Lauf füllt automatisch nach. _Novelty:_ Extraktion ist zugleich Zulieferer.

**[Portfolio #11] Matrix-Auswahl für Low-Cost-Angebote** — _Concept:_ Angebot = Branding-Profil × Komponenten-Set (industrie-gefiltert) → Mockup in Minuten; Festpreisprodukt („Landing-Page-Entwurf in 24h"). _Novelty:_ Fallende Grenzkosten.

**[Portfolio #12] Self-contained HTML-Export** — _Concept:_ Mockup als eine statische HTML-Datei (Tailwind inlined, Bilder base64) — per Mail oder Ein-Klick-Link, ohne Deployment. _Novelty:_ Kunde braucht nur einen Browser. → Umsetzung: web-artifacts-builder (#19).

**[Portfolio #13] Best-of-Recycling aus Kundenläufen** — _Concept:_ Nach jedem Lauf: „Welche Sektionen sind portfoliowürdig?" → Ein-Klick-Übernahme, generalisiert (Platzhalter statt Kundentexte). _Novelty:_ Kuratiertes Wachstum statt Datenfriedhof.

**[Feedback #14] Kommentar-Pins im Mockup** — _Concept:_ Eingebettetes JS: Klick auf Sektion → Kommentar + 👍/👎; JSON per POST (oder mailto-Fallback), Format kompatibel zum Drawbridge-`.moat`-Taskformat. _Novelty:_ Kundenfeedback wird ohne Meeting maschinenlesbar.

**[Feedback #15] Varianten-Voting als A/B-Screen** — _Concept:_ Erste Seite des Links: Safe vs. Bold, ein Klick, dann Details; Antwort steuert Ausarbeitung. _Novelty:_ Teuerste Entscheidung zuerst, minimale Kundenzeit.

### Domain 4 — Scoring

**[Scoring #16] Mehrdimensionales Score-Panel** — _Concept:_ 5 Dimensionen: Visuelle Qualität (Claude-Judge), KI-Generik (design-ai-check), Performance (Lighthouse), Accessibility, Conversion-Heuristiken; gewichteter Gesamtscore. _Novelty:_ Jede Dimension belegbar.

**[Scoring #17] Benchmark gegen Industrie-Nachbarn** — _Concept:_ „Typische Handwerker-Sites: 35–55. Sie: 42." Datenbasis aus eigenen Läufen pro Industrie-Tag. _Novelty:_ Lauf-Archiv wird proprietärer Benchmark.

**[Scoring #24] Cai-Fünf-Teile-Modell als Rubrik-Ebene** — _Concept:_ Clarity („verstanden in 5 Sek?"), Credibility („vertraut in 5 Sek?"), Logic („Handlungsgrund sichtbar?") + 2 weitere Teile aus dem Guide als Conversion-Dimension im Score-Panel. _Novelty:_ Report spricht Marketer-Sprache.

### Domain 5 — Skills, Akquise, Scope

**[Stack #18] Skill-Sandwich für die Generierung** — _Concept:_ frontend-design (Philosophie) + taste-skill (Parameter je Modus: Safe = Varianz niedrig, Bold = hoch) + Anti-Slop-Constraints (#8). _Novelty:_ Safe/Bold = ein Parameter-Set.

**[Stack #19] Artifacts-Builder als Mockup-Engine** — _Concept:_ Mockup-Stufe komplett via web-artifacts-builder (React+shadcn → 1 HTML); volles Next.js-Projekt erst bei Zuschlag. _Novelty:_ Billige Angebotsphase, teure Struktur nur bei Auftrag.

**[Akquise #20] Batch-Audit für Kaltakquise** — _Concept:_ URL-Liste (20 Handwerker einer Stadt) über Nacht scannen, nach Score sortieren, 1-Seiten-Teaser pro Kandidat. _Novelty:_ Auditor = Lead-Maschine, Cents pro Lead.

**[Akquise #21] Teaser mit Redesign-Appetizer** — _Concept:_ Für die 3 schlechtesten: nur Hero-Sektion neu, als Vorher/Nachher-Bild in den Teaser. _Novelty:_ Mail zeigt das Produkt statt es zu beschreiben.

**[Wild #22] Design-Trend-Radar** — _Concept:_ Wöchentlicher Cron scannt Award-Seiten (awwwards, godly.website), extrahiert Layout-Muster als Registry-Kandidaten mit Trend-Tag. _Novelty:_ Portfolio lernt von der Avantgarde.

**[Scope #23] Zwei Analyse-Modi: „Landing" & „App"** — _Concept:_ `mode`-Parameter schaltet Rubrik (Conversion- vs. Nielsen-Usability-Heuristiken), Erfassung (Fullpage vs. Flow-Walk pro Screen, Login via Chrome-Profil) und Registry-Filter (Marketing-Blocks vs. App-Primitives); Auto-Detection. shadcn/ui ist App-first — der Stack trägt beides. _Novelty:_ Ein Produkt, zwei Märkte.

**[QA #26] Publish-Checklisten als Gates** — _Concept:_ Cais Responsive-/SEO-Checklisten (Title, Meta, Favicon 32×32, Social Banner 1200×630, tap-friendly) maschinell geprüft vor dem Teilen. _Novelty:_ Kein Mockup mit fehlendem Favicon.

---

## Phase (c): Konvergenz

### Themen-Cluster

- **T1 Audit-Engine:** #4, #16, #17, #23, #24 — komplett kostenlos
- **T2 Redesign-Generierung:** #6, #7, #8, #18, #25
- **T3 Output & Sharing:** #1, #2, #3, #12, #14, #15, #19, #26
- **T4 Portfolio:** #9, #10, #11, #13, #22
- **T5 Business/Akquise:** #20, #21, Low-Cost-Festpreisprodukt
- **T6 Assets & Später:** #5, Paper Shaders/Lottie, Kunden-PDF, Backend + Dokploy

### Priorisierter Fahrplan

| Stufe | Inhalt | Begründung |
|---|---|---|
| **1 — Audit-Core (MVP)** | Skill `ui-check`: URL → agent-browser-Screenshots (3 Viewports) + Lighthouse CLI + Branding-Tokens (design-extract/dembrandt) + Score-Panel-Report (#16 + #24). Audit-only-Modus. Jupiter-Wrapper nach PROJ-53-Muster danach. | 0 € Betrieb, sofort akquise-tauglich, Fundament für alles. |
| **2 — Redesign-Mockup** | Safe+Bold (#6/#7/#8/#18/#25) → web-artifacts-builder → 1 teilbare HTML mit Voting (#15), Vorher/Nachher-Slider (#2/#3), Score-Delta (#4), Publish-Gates (#26). | Wow-Effekt & Verkaufsmoment. |
| **3 — Portfolio + Jupiter-UI** | shadcn-Registry (#9), Branding-Bibliothek mit Auxevo-Seed (#10), Best-of-Recycling (#13), Matrix-Angebote (#11), MicroApp-Oberfläche. | Compounding — jeder Lauf macht den nächsten billiger. |
| **4 — Ausbau** | Batch-Akquise (#20/#21), Feedback-Pins (#14), Kunden-PDF, App-Modus voll (#23), Trend-Radar (#22), Backend-Verdrahtung + Dokploy-Deploy. | Erst wertvoll, wenn 1–3 laufen. |

### Aktionspläne Top 3

**Stufe 1 — Audit-Core**
- Nächster Schritt: `/abc-requirements` — Feature-Spec „UI-Check Audit-Core"
- Ressourcen: `npm i -g agent-browser lighthouse`, design-extract oder dembrandt, Google-PSI-Key (optional), vorhandener `design-ai-check`-Skill als Rubrik-Basis
- Risiken: JS-lastige/Bot-geschützte Seiten (Cloudflare) → agent-browser mit echtem Chrome-Profil als Fallback; Score-Konsistenz des Claude-Judge → feste Rubrik + Beispiel-Anker
- Erfolgsmetrik: 10 fremde URLs → Report in < 10 Min/URL, Scores plausibel & reproduzierbar (±5 Punkte bei Wiederholung)
- Timeline: 1 Woche

**Stufe 2 — Redesign-Mockup**
- Nächster Schritt: frontend-design-, taste- und web-artifacts-builder-Skills installieren und an einem Auxevo-Testfall proben
- Ressourcen: shadcn-MCP, Magic UI/Aceternity, Paper Shaders, Motion
- Risiken: Bold-Variante kippt in Slop → Anti-Slop-Constraints (#8) + Nachher-Scoring als Gate (#4); Token-Kosten pro Lauf → geteilter Kern (#7)
- Erfolgsmetrik: Nachher-Score ≥ Vorher + 25 Punkte; HTML-Datei < 5 MB, offline lauffähig
- Timeline: 1–2 Wochen nach Stufe 1

**Stufe 3 — Portfolio + Jupiter**
- Nächster Schritt: Registry-Schema definieren (Metadaten: Industrie, Segment, Sektionstyp, Stil); Auxevo-Branding als erstes Profil importieren
- Ressourcen: shadcn-Registry-Spec, Jupiter-MicroApp-Muster (PROJ-53)
- Risiken: Registry verkommt ohne Kuration → Recycling-Schritt (#13) als Pflicht-Gate am Run-Ende
- Erfolgsmetrik: Neues Angebot aus Portfolio-Bausteinen in < 30 Min
- Timeline: nach Stufe 2

### Offene Entscheidungspunkte

1. **Lighthouse CLI vs. PageSpeed-MCP** — Empfehlung: CLI (weniger Infrastruktur, kein Key nötig); PSI-API nur für CrUX-Felddaten.
2. **Hosting geteilter Mockups** — reine Mail-Datei vs. statischer Dokploy-Host mit Kurz-URLs (+ Feedback-POST-Endpoint für #14). Entscheidung bei Stufe 2.
3. **Bild-Kanal** — manuell via ChatGPT-Pro (0 €) vs. API-Cents (Flux ~$0.03, Recraft-SVG $0.08) für Vollautomatik. Vorschlag: Platzhalter + Prompts im MVP, API optional.
4. **App-Modus-Umfang in Stufe 1** — nur Auto-Detection + Hinweis, oder schon Flow-Walk? Vorschlag: Detection only, Flow-Walk in Stufe 4.
5. **Cai-Rubrik vervollständigen** — Teile 4+5 des Fünf-Teile-Modells aus dem PDF/Video präzise übernehmen (PDF: `/home/dev/projects/clipboard/How to Build a Landing Page Website with AI by Aliena Cai (V1.1).pdf`).
6. **Benchmark-Datenhaltung (#17)** — einfache JSONL pro Lauf vs. SQLite; ab wann Industrie-Mediane anzeigen (Vorschlag: ab 10 Läufen pro Tag-Gruppe).

### Empfohlene Reihenfolge

Stufe 1 → 2 → 3 strikt sequenziell (jede Stufe nutzt Artefakte der vorigen). Innerhalb Stufe 4 zuerst Batch-Akquise (#20/#21, monetarisiert sofort), dann Feedback-Pins (#14), dann Rest.

**Nächster Schritt nach dieser Session:** `/abc-requirements` mit Stufe 1 („UI-Check Audit-Core") als erste Feature-Spec.
