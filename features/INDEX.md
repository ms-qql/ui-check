# Feature Index — UI-Check

**Projekt:** UI-Check — Website-Audit- & Redesign-Pipeline (Jupiter-MicroApp)
**PRD:** `docs/PRD.md` · **Brainstorm:** `docs/Brainstorm.md` · **UI-Referenz:** `design/ui-mockup.html`

| ID | Feature | Prio | Stufe | Status | Abhängigkeiten |
|---|---|---|---|---|---|
| PROJ-1 | [Seiten-Erfassung (Capture)](PROJ-1-seiten-erfassung.md) | P0 | 1 | Deployed | — |
| PROJ-2 | [Lighthouse-Audit](PROJ-2-lighthouse-audit.md) | P0 | 1 | Deployed | — |
| PROJ-3 | [Branding-Extraktion](PROJ-3-branding-extraktion.md) | P0 | 1 | Deployed | PROJ-1 |
| PROJ-4 | [Design-Scoring & Report](PROJ-4-design-scoring-report.md) | P0 | 1 | Deployed | PROJ-1, PROJ-2, PROJ-3 |
| PROJ-5 | [Skill-Orchestrierung (`ui-check`)](PROJ-5-skill-orchestrierung.md) | P0 | 1 | Deployed | PROJ-1–4 |
| PROJ-6 | [Redesign-Generierung Safe+Bold](PROJ-6-redesign-generierung.md) | P1 | 2 | In Review | PROJ-3, PROJ-4, PROJ-5 |
| PROJ-7 | [Mockup-Export (HTML)](PROJ-7-mockup-export-html.md) | P1 | 2 | In Review | PROJ-6 |
| PROJ-8 | [Vorher/Nachher & Voting](PROJ-8-vorher-nachher-voting.md) | P1 | 2 | In Review (QA: autom. grün, High offen) | PROJ-1, PROJ-7 |
| PROJ-9 | [Nachher-Scoring (Score-Delta)](PROJ-9-nachher-scoring.md) | P1 | 2 | Approved | PROJ-4, PROJ-7 |
| PROJ-10 | [Batch-Audit (Kaltakquise)](PROJ-10-batch-audit.md) | P1 | 2 | Planned | PROJ-5 |
| PROJ-11 | [Komponenten-Registry & Recycling](PROJ-11-komponenten-registry.md) | P2 | 3 | In Review (alle 5 AC ✓ & verifiziert; Profile „verdict" & „meridian" + hero45; Selektor/Browser/Dedupe/Recycling; shadcn-build grün) | PROJ-6 |
| PROJ-12 | [Branding-Profil-Bibliothek](PROJ-12-branding-bibliothek.md) | P2 | 3 | Architected | PROJ-3 |
| PROJ-13 | [Portfolio-Assembler](PROJ-13-portfolio-assembler.md) | P2 | 3 | Architected | PROJ-7, PROJ-11, PROJ-12 |
| PROJ-14 | [Jupiter-MicroApp-UI](PROJ-14-jupiter-microapp-ui.md) | P2 | 3 | In Review (QA: 3 High, 1 Medium offen) | PROJ-5 (+6–9 sinnvoll) |
| PROJ-15 | [Feedback-Pins im Mockup](PROJ-15-feedback-pins.md) | P3 | 4 | Architected | PROJ-7, PROJ-8 |
| PROJ-16 | [Kunden-PDF](PROJ-16-kunden-pdf.md) | P3 | 4 | Planned | PROJ-4 |
| PROJ-17 | [App-Modus (Flow-Walk)](PROJ-17-app-modus.md) | P3 | 4 | Planned | PROJ-1, PROJ-4 |
| PROJ-18 | [Design-Trend-Radar](PROJ-18-trend-radar.md) | P3 | 4 | Planned | PROJ-11 |
| PROJ-19 | [Backend-Verdrahtung & Deploy](PROJ-19-backend-deploy.md) | P3 | 4 | Planned | PROJ-6, PROJ-7, PROJ-15 |
| PROJ-20 | [Auto-Bildbefüllung der Slots](PROJ-20-auto-bildbefuellung.md) | P1 | 2 | Deployed (v0.2.0; 2 Low offen) | PROJ-6, PROJ-1 (→ PROJ-7) |

**Next Available ID:** PROJ-21

## Empfohlene Build-Reihenfolge

1. **Stufe 1 (P0):** PROJ-1 → PROJ-2 (parallel zu 1 möglich) → PROJ-3 → PROJ-4 → PROJ-5
2. **Stufe 2 (P1):** PROJ-6 → **PROJ-20 (Bild-Slots füllen)** → PROJ-7 → PROJ-8 → PROJ-9; PROJ-10 unabhängig nach PROJ-5
3. **Stufe 3 (P2):** PROJ-12 → PROJ-11 → PROJ-13; PROJ-14 sobald 6–9 stehen
4. **Stufe 4 (P3):** PROJ-15/16 nach Bedarf; PROJ-17/18 opportunistisch; PROJ-19 pro Kundenauftrag

## Status-Legende
Planned → Architected → In Progress → In Review → Approved → Deployed

## QA-Notizen
- **2026-07-03 · PROJ-8:** Nach Bugfix für fehlende Capture-Screenshots läuft
  `scripts/tests/mockup_export_test.sh` mit **68/68** Assertions grün; der echte
  `MOCKUP_EXPORT_E2E=1`-Build läuft mit **70/70** grün. Status bleibt **In Review**,
  weil der Red-Team-QA-Befund `PROJ-8-BUG-1` (Split-Slider ohne echte
  Scroll-Synchronisation/Sektions-Snap) noch offen ist.
