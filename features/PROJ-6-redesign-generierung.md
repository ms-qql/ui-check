# PROJ-6: Redesign-Generierung Safe + Bold

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-3 (Branding-Tokens), PROJ-4 (Befunde + Cai-Teilscores als Redesign-Input), PROJ-5 (Orchestrierung, `--prompt`)

## Beschreibung
Erzeugt aus Audit + Branding zwei Redesign-Varianten als React/Tailwind/shadcn-Code: **Bold** (mutige Neuinterpretation, unkonventionelle Layouts) und **Safe** (konservatives Facelift). Beide teilen Tokens und Content-Struktur; nur Layout-Rezept und Animations-Level unterscheiden sich.

## User Stories
- Als Auxevo-Nutzer möchte ich pro Lauf eine mutige und eine konservative Variante erhalten, um dem Kunden eine Richtungs-Wahl zu geben.
- Als Auxevo-Nutzer möchte ich, dass das Redesign auf ein explizites Conversion-Ziel optimiert (CTA-First-Brief), nicht nur „schöner" ist.
- Als Auxevo-Nutzer möchte ich mein `--prompt` (Zielgruppe, Ton, Constraints) im Ergebnis berücksichtigt sehen.

## Acceptance Criteria
- [ ] Vor der Generierung entsteht `brief.md`: Conversion-Ziel, primärer CTA, Sektionsplan (aus Original abgeleitet), beibehaltene vs. angepasste Brand-Entscheidungen mit Begründung
- [ ] Generierungs-Reihenfolge: Struktur → Content → Visuals (Cai-Iterationsmodell)
- [ ] Skill-Sandwich aktiv: frontend-design-Skill + taste-Skill (Bold: Varianz hoch / Safe: niedrig) + Anti-Slop-Constraints aus der design-ai-check-Rubrik (dokumentiert in `brief.md`)
- [ ] Beide Varianten nutzen ausschließlich extrahierte Tokens (PROJ-3) bzw. im Brief begründete Anpassungen; deutsche Texte, Original-Copy wird verbessert, nicht erfunden (keine falschen Fakten/Claims)
- [ ] Komponenten aus shadcn/Magic UI/Aceternity-Registries; animierte Backgrounds nur assetfrei (Paper Shaders/CSS) — keine Bild-API-Pflicht
- [ ] Output: `redesign/safe/` und `redesign/bold/` als buildfähige React-Komponenten (Input für PROJ-7)
- [ ] Bild-Slots: Platzhalter + fertiger Bild-Prompt pro Slot (`images.md`) — keine automatische Bild-Generierung im MVP

## Edge Cases
- Original hat keinen CTA: Brief schlägt Conversion-Ziel vor, markiert es als Annahme
- Extrahierte Marke kollidiert mit Lesbarkeit (z. B. Neon auf Weiß): Anpassung erlaubt, muss im Brief begründet sein
- Sehr wenig Original-Content: Sektionsplan reduziert sich; keine erfundenen Leistungen/Testimonials
- `--prompt` widerspricht Branding (z. B. „mach es lila"): Nutzer-Prompt gewinnt, Abweichung wird im Brief dokumentiert

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
_To be added by /abc-architecture_

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
