# PRD: UI-Check — Website-Audit- & Redesign-Pipeline

**Stand:** 2026-07-02 · v1.0
**Quelle:** `docs/Brainstorm.md` (Session 2026-07-02)

## Vision

UI-Check macht aus einer beliebigen Website-URL in ~20 Minuten ein verkaufsfertiges Ergebnis: ein mehrdimensionaler Design-Score-Report, das automatisch extrahierte Branding der Seite und (Stufe 2) zwei klickbare Redesign-Varianten als teilbares HTML-Mockup. Über die Zeit entsteht daraus ein wiederverwendbares Portfolio aus Komponenten und Branding-Profilen — die Grundlage für Low-Cost-Festpreisangebote von Auxevo.

## Target Users

| Nutzer | Bedarf | Pain Point heute |
|---|---|---|
| **Auxevo (Manfred)** — einziger Direktnutzer | Kunden-Websites schnell bewerten, Redesigns anbieten, Portfolio aufbauen | Manuelle Audits & Designs dauern Stunden; kein systematisches Wiederverwenden |
| **Auxevo-Kunden (indirekt)** — KMU (Handwerk, Kanzlei, SaaS …) | Verständlicher Befund + anfassbarer Redesign-Vorschlag ohne Meeting | Agentur-Angebote sind teuer, langsam, abstrakt |

Kein Multi-Tenant, keine Fremdnutzer: internes Tool, später als Jupiter-MicroApp.

## Betriebsmodell & Stack (Abweichung vom Default-Stack)

- **Kern = Claude-Code-Skill** (`ui-check`), CLI-first, headless aufrufbar — kein FastAPI/Flutter im MVP.
- Jupiter-MicroApp-Wrapper (nach PROJ-53-Muster „Buch-Nuggets") als eigenes Feature in P2.
- Werkzeuge: agent-browser (Screenshots/Snapshots), Lighthouse CLI, design-extract/dembrandt + css-analyzer (Tokens), Claude-Judge (design-ai-check-Rubrik + Cai-Modell), shadcn-MCP + Magic UI/Aceternity + frontend-design/taste-Skills (Stufe 2), web-artifacts-builder (HTML-Export).
- Redesign-Zielstack der generierten Mockups/Sites: **Next.js + Tailwind + shadcn/ui + Motion**.
- **Kosten-Constraint:** Basisbetrieb 0 € (nur Claude-Tokens); Bild-APIs optional (Cents/Bild), via ChatGPT-Pro-Umweg vermeidbar.

## Core Features (Roadmap)

| Prio | Feature | Stufe | Kurzbeschreibung |
|---|---|---|---|
| P0 | PROJ-1 Seiten-Erfassung (Capture) | 1 | agent-browser: Screenshots 375/768/1440 + DOM/A11y-Snapshot → Run-Ordner |
| P0 | PROJ-2 Lighthouse-Audit | 1 | Lighthouse CLI: Performance/A11y/SEO/Best-Practices als JSON |
| P0 | PROJ-3 Branding-Extraktion | 1 | Design-Tokens (Farben, Fonts, Radius, Spacing) + Logo → tokens.json + Tailwind-Theme |
| P0 | PROJ-4 Design-Scoring & Report | 1 | Claude-Judge: 5 Dimensionen (Visuell, KI-Generik, Performance, A11y, Conversion/Cai) → report.md + scores.json |
| P0 | PROJ-5 Skill-Orchestrierung | 1 | `/ui-check <url>`-Skill: Run-Verwaltung, Modi (audit-only), Fehlerpfade |
| P1 | PROJ-6 Redesign-Generierung Safe+Bold | 2 | CTA-First-Brief → 2 Varianten (Skill-Sandwich, Anti-Slop) |
| P1 | PROJ-7 Mockup-Export (HTML) | 2 | web-artifacts-builder → eine self-contained HTML-Datei + Publish-Gates |
| P1 | PROJ-8 Vorher/Nachher & Voting | 2 | Split-Slider, Sektionsvergleich, Safe/Bold-A/B-Screen im Export |
| P1 | PROJ-9 Nachher-Scoring (Score-Delta) | 2 | Mockup durchläuft Scoring erneut; Delta als QA-Gate & Verkaufsargument |
| P1 | PROJ-10 Batch-Audit | 2 | URL-Liste → Ranking + 1-Seiten-Teaser pro Kandidat (Kaltakquise) |
| P2 | PROJ-11 Komponenten-Registry & Recycling | 3 | Eigene shadcn-Registry mit Industrie-/Segment-Tags; kuratierte Übernahme aus Läufen |
| P2 | PROJ-12 Branding-Profil-Bibliothek | 3 | Token-Profile pro Kunde/Industrie; Auxevo als Seed |
| P2 | PROJ-13 Portfolio-Assembler | 3 | Mockup aus Branding × Komponenten-Set (Matrix) für Low-Cost-Angebote |
| P2 | PROJ-14 Jupiter-MicroApp-UI | 3 | Wrapper-UI nach `design/ui-mockup.html` (5 Screens, Light/Dark, Prompt-Feld) |
| P3 | PROJ-15 Feedback-Pins im Mockup | 4 | Kunden-Kommentare + 👍/👎 → maschinenlesbare Task-Liste (.moat-kompatibel) |
| P3 | PROJ-16 Kunden-PDF | 4 | Mail-fertiger Report (pdf-Skill) |
| P3 | PROJ-17 App-Modus (Flow-Walk) | 4 | Login/Navigation durch WebApps, Screen-weises Audit, Nielsen-Rubrik |
| P3 | PROJ-18 Design-Trend-Radar | 4 | Cron: Award-Seiten scannen → Registry-Kandidaten |
| P3 | PROJ-19 Backend-Verdrahtung & Deploy | 4 | Gewinner-Mockup → Next.js-Projekt mit Backend, Dokploy-Deploy |

## Success Metrics

- **Stufe 1:** 10 fremde URLs auditierbar; < 10 Min/Lauf; Score reproduzierbar (±5 Punkte bei Wiederholung); 0 € API-Kosten
- **Stufe 2:** Nachher-Score ≥ Vorher + 25 Punkte; HTML-Mockup < 5 MB, offline lauffähig; Kunde kann ohne Anleitung bewerten
- **Stufe 3:** Neues Angebot aus Portfolio-Bausteinen in < 30 Min
- **Business:** Erster bezahlter Kundenauftrag, der über einen UI-Check-Teaser entstand

## Constraints

- **Kosten:** Paid-APIs nur opt-in (Attention Insight €119/Mo, Brandfetch Brand-API $99/Mo, Bild-APIs Cents — alle optional, Basis 0 €)
- **DSGVO:** Web-Fonts in generierten Mockups nur via Bunny Fonts/self-hosted; Kunden-URLs sind öffentliche Daten, Screenshots bleiben lokal
- **Fremde URLs:** Nur öffentlich erreichbare Seiten; Bot-Schutz (Cloudflare) kann Läufe verhindern → dokumentierter Fehlerpfad, kein Umgehen von Schutzmaßnahmen
- **Team/Zeit:** Solo; Stufe 1 in ~1 Woche
- **Kein Multi-Tenant, keine Auth im MVP** (internes CLI-Tool; Jupiter bringt eigenen Kontext)

## Non-Goals

- Kein öffentliches SaaS, kein Kunden-Login in Stufen 1–3
- Kein CMS/Website-Baukasten — Output sind Mockups bzw. (Stufe 4) ein Next.js-Projekt
- Keine Echt-Traffic-Analysen (Hotjar-Ersatz), kein A/B-Testing im Live-Betrieb
- Kein automatisches Publizieren/Kontaktieren — Akquise-Teaser werden manuell verschickt (Human-in-the-Loop)
- Keine Umgehung von Bot-/Zugriffsschutz fremder Seiten

## Referenzen

- `docs/Brainstorm.md` — validierter Tool-Stack mit Quellen, 26 Ideen, Entscheidungspunkte
- `design/ui-mockup.html` — UI-Design der MicroApp (v0.2: 5 Screens, Light/Dark, Prompt-Feld, Branding-Tab)
- Cai-Evaluationsmodell (vollständig): **Clarity** (verstanden in 5 s?), **Credibility** (vertraut in 5 s?), **Logic** (Grund für CTA sichtbar?), **Action** (CTA offensichtlich & einfach?), **Emotion** (fühlt sich passend an?)
