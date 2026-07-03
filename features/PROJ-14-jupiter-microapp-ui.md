# PROJ-14: Jupiter-MicroApp-UI

## Status: Planned
**Created:** 2026-07-02
**Last Updated:** 2026-07-02

## Dependencies
- Requires: PROJ-5 (headless aufrufbarer Skill); sinnvoll erst mit PROJ-6–9 (sonst nur Audit-Ansichten)
- Referenz: `design/ui-mockup.html` (v0.2 — genehmigtes UI-Design)

## User Stories
- Als Auxevo-Nutzer möchte ich UI-Check aus Jupiter heraus starten (URL + Modus + Prompt-Feld) und Ergebnisse dort ansehen, statt im Terminal zu arbeiten.

## Acceptance Criteria
- [ ] Integration nach PROJ-53-Muster (Buch-Nuggets): MicroApp ruft den Skill headless auf, zeigt Fortschritt und Ergebnis
- [ ] Screens gemäß Mockup: Dashboard (URL, Modi, Prompt-Feld, Lauf-Historie), Audit-Report (Score-Ring, 5 Dimensionen, Befunde), Branding (Scraped-Karte), Vorher/Nachher, Portfolio
- [ ] Light/Dark-Toggle konsistent mit Jupiter
- [ ] Lauf-Historie aus `runs.jsonl`; Öffnen eines Laufs zeigt dessen Artefakte
- [ ] Deutsche UI durchgängig

## Edge Cases
- Lauf läuft noch (bis 10 min): Fortschrittsanzeige mit Phasen, kein UI-Freeze; Abbruch möglich
- Alte Läufe mit älterer Rubrik-Version: Version wird angezeigt, Scores nicht stillschweigend vergleichbar gemacht

---
## Tech Design (Solution Architect)
**Erstellt:** 2026-07-03 · **Stack:** Jupiter-MicroApp-Frontend + lokaler Headless-Runner (`scripts/ui-check.sh`, optional `ui-redesign`/`mockup-export`) + Run-Ordner/JSONL · **Branch:** dev

### Zielbild
PROJ-14 baut keine neue Audit-Engine, sondern die bedienbare Jupiter-Oberfläche für die bestehende UI-Check-Pipeline. Die MicroApp startet Läufe mit URL, Modus und Prompt, zeigt deren Fortschritt, liest fertige Artefakte aus dem Run-Ordner und macht die fünf Mockup-Screens aus `design/ui-mockup.html` produktiv nutzbar.

Der fachliche Kern bleibt headless: `ui-check` erzeugt Audit-Artefakte, `ui-redesign` erzeugt Safe/Bold, `mockup-export` bündelt die teilbare HTML-Datei. Die MicroApp orchestriert und visualisiert, ersetzt diese Schritte aber nicht.

### Komponentenstruktur (PM-Sicht)
```
UiCheckMicroApp
├── AppShell
│   ├── JupiterHeader (Projektname, Light/Dark-Toggle, Status)
│   └── TabNavigation
│       ├── Dashboard
│       ├── Audit-Report
│       ├── Branding
│       ├── Vorher / Nachher
│       └── Portfolio
├── DashboardScreen
│   ├── RunStartPanel (URL, Modus, Prompt, Desktop-Option, Start/Abbruch)
│   ├── ProgressTimeline (Capture, Lighthouse, Branding, Scoring, Redesign, Mockup)
│   ├── RunStats (Anzahl Läufe, Durchschnittsscore, Delta, Portfolio-Bausteine)
│   └── RunHistoryTable (aus `data/runs.jsonl` + Run-Ordnern)
├── AuditReportScreen
│   ├── ScoreRing (Gesamtscore + Rubrik-Version)
│   ├── DimensionGrid (Visuell, KI-Generik, Performance, Accessibility, Conversion)
│   ├── FindingsList (Befunde mit Beleg/Fundort)
│   └── ArtifactActions (Report öffnen/exportieren, Score-Dateien öffnen)
├── BrandingScreen
│   ├── BrandSummaryCard (Logo, Farben, Fonts, Tonalität)
│   ├── TokenViewer (rollenbasierte Tokens, Tailwind-Theme)
│   └── BrandingNotes (Kontrast-/Logo-/Extraktionsvermerke)
├── CompareScreen
│   ├── VariantSelector (Original, Safe, Bold)
│   ├── BeforeAfterPreview (Screenshots/Mockup-Link)
│   ├── SectionComparison (aus `compare.json`, falls vorhanden)
│   └── MockupActions (`mockup.html` öffnen, Kundenlink/-Datei vorbereiten)
└── PortfolioScreen
    ├── ComponentCandidates (aus Runs/PROJ-11, sobald verfügbar)
    ├── BrandingProfiles (aus PROJ-12, sobald verfügbar)
    └── ReuseActions (Sektion/Profile als Kandidat markieren)
```

### Datenmodell (plain language)
Die MicroApp speichert im MVP keine eigene Produktdatenbank. Sie liest und schreibt an den bestehenden Pipeline-Orten:

- **Lauf-Historie:** `data/runs.jsonl` bleibt der schnelle Index für abgeschlossene Läufe: Datum, URL-Hash, Industrie, Rubrik-Version, Run-ID, Gesamtscore und Dimensionen. Die UI zeigt daraus Listen, Benchmarks und Metriken.
- **Run-Details:** der Run-Ordner `runs/YYYY-MM-DD-<domain>-NNN/` ist die Detailquelle. Er enthält `status.json` für Fortschritt, `ui-check.json` für Eingaben, `scores.json`/`report.md` für den Audit, `branding/` für Tokens/Logo, optional `redesign/` für Safe/Bold und optional `mockup.html`/`mockup/gates.json` für den Export.
- **Lauf-Zustand:** laufende und abgebrochene Jobs werden über `status.json` angezeigt. Die UI behandelt alte Läufe defensiv: fehlt ein neueres Artefakt, wird der passende Bereich ausgegraut statt fehlerhaft leer angezeigt.
- **Rubrik-/Rezept-Versionen:** Versionen werden sichtbar gemacht. Alte Scores werden nicht automatisch mit neuen Rubriken vermischt; die UI zeigt einen Versionshinweis.
- **Keine Klar-URL im Listenindex:** `runs.jsonl` enthält bewusst nur URL-Hashes. Die volle URL steht nur im lokalen Run-Ordner (`meta.json`/`ui-check.json`) und wird nur beim Öffnen eines konkreten Laufs gelesen.
- **Dateien:** Screenshots, Logos und `mockup.html` bleiben lokale Artefakte im Run-Ordner. MinIO ist für diesen MVP nicht nötig.

### Runner-/API-Form (nur Vertrag, keine Implementierung)
Die Jupiter-MicroApp braucht eine kleine lokale Runner-Schicht, weil Browser-UI und Shell-Pipeline getrennte Welten sind. Diese Schicht darf dünn bleiben und reicht Befehle an die bestehenden headless Treiber weiter:

- `GET /ui-check/runs` → Liste der Läufe aus `data/runs.jsonl`, angereichert um sichtbare Metadaten aus den Run-Ordnern.
- `GET /ui-check/runs/{run_id}` → Detaildaten eines Laufs: Status, Scores, Report-Auszug, Branding, verfügbare Artefakte.
- `POST /ui-check/runs` → neuen Lauf starten mit URL, Modus, Prompt, Industrie optional, Desktop optional und gewünschter Tiefe `audit` oder `redesign`.
- `GET /ui-check/runs/{run_id}/status` → Fortschritt aus `status.json`; Polling reicht, Echtzeit-Websocket ist nicht nötig.
- `POST /ui-check/runs/{run_id}/cancel` → laufenden Prozess abbrechen; der Run bleibt mit Abbruchstatus sichtbar.
- `POST /ui-check/runs/{run_id}/redesign` → Redesign/Mockup für einen vorhandenen Audit-Lauf nachziehen, sobald PROJ-6/7/8 verfügbar sind.
- `GET /ui-check/runs/{run_id}/artifacts/{kind}` → bekannte Artefakte öffnen oder als Datei ausliefern: Report, Scores, Tokens, Screenshots, `mockup.html`, Gate-Ergebnisse.

Alle Endpunkte sind lokal/Jupiter-intern. Es gibt im MVP keine Fremdnutzer, kein Mandantenmodell, keine öffentliche API und keine eigene Auth-Schicht; Jupiter liefert den Anwendungskontext.

### Ablauf pro Lauf
```
1. Nutzer gibt URL, Modus und optionalen Prompt ein.
2. Runner startet `ui-check` headless und legt/ermittelt den Run-Ordner.
3. Dashboard pollt `status.json` und zeigt Phasenfortschritt bis maximal ca. 10 Minuten.
4. Nach Audit-Finish lädt die UI Score, Report und Branding.
5. Wenn Tiefe `redesign` gewählt ist und die Vorfeatures verfügbar sind:
   ├── `ui-redesign` erzeugt Safe/Bold + `compare.json`
   ├── `mockup-export` erzeugt `mockup.html` + Gates
   └── optional PROJ-9 zeigt Score-Deltas, sobald gebaut
6. Run-Historie aktualisiert sich aus `runs.jsonl`; Detailtab bleibt auf dem neuen Lauf.
```

### Tech-Entscheidungen
- **Wrapper statt Neuimplementierung:** Die CLI-/Skill-Pipeline ist bereits getestet und deployed. Die MicroApp ruft diese Pipeline headless auf, damit es keine zweite Audit-Logik und keine abweichenden Ergebnisse zwischen Terminal und Jupiter gibt.
- **Polling statt Echtzeitkanal:** `status.json` ist bereits der Fortschrittsvertrag. Ein Polling-Intervall von wenigen Sekunden ist für 10-Minuten-Läufe ausreichend, einfacher zu testen und robust gegen Browser-Reloads.
- **Run-Ordner als Source of Truth:** Die Artefakte liegen dort schon vollständig vor. Eine zusätzliche Datenbank würde im MVP nur Synchronisationsprobleme erzeugen; ein späteres Dokploy-/Backend-Feature kann dieselben Artefakte immer noch indexieren.
- **Defensive Artefakt-Erkennung:** PROJ-6–9 sind teils in Review/geplant. Die UI zeigt Fähigkeiten nur dann aktiv, wenn die erwarteten Dateien existieren (`redesign/`, `mockup.html`, Nachher-Scores). So kann PROJ-14 schon mit Audit-only-Läufen sinnvoll arbeiten.
- **Light/Dark über Jupiter-Theme:** Der Toggle folgt dem Jupiter-Kontext und speichert nur eine lokale Präferenz. Die MicroApp erfindet kein separates Designsystem; `design/ui-mockup.html` ist die visuelle Referenz.
- **Abbruch ist sichtbar, nicht unsichtbar:** Ein Cancel beendet den laufenden Job bestmöglich und lässt den Run mit Status/Fehlergrund in der Historie. Das ist für spätere Diagnose wertvoller als ein gelöschter Lauf.
- **Versionen sichtbar machen:** Rubrik- und Rezept-Versionen stehen in den Artefakten und werden in Report/Detailkopf angezeigt. Damit bleibt klar, warum alte Läufe nicht 1:1 mit neuen Scores vergleichbar sind.
- **Deutsch als UI-Kontrakt:** Alle Labels, Empty States, Fehler und Gate-Hinweise sind deutsch, weil die MicroApp direkt im Auxevo-Arbeitsfluss und später in kundennahem Kontext genutzt wird.
- **Kein MinIO/Neon im MVP:** Die Daten sind lokale Arbeitsartefakte, keine gemeinsam genutzten SaaS-Daten. MinIO/Neon werden erst relevant, wenn PROJ-19 aus lokalen Läufen ein gehostetes Backend macht.

### Dependencies
- **Jupiter-MicroApp-Umgebung:** vorhandenes Jupiter-Shell-/MicroApp-Muster aus PROJ-53.
- **Vorhandene Pipeline:** `scripts/ui-check.sh`, `.claude/skills/ui-check`, `data/runs.jsonl`, Run-Ordner-Kontrakt.
- **Optional aktiv je Verfügbarkeit:** `.claude/skills/ui-redesign`, `scripts/redesign.sh`, `scripts/mockup-export.sh`, PROJ-8-Shell-Erweiterungen, PROJ-9-Nachher-Scores.
- **Lokale Tools:** dieselben Voraussetzungen wie die Pipeline (`agent-browser`, Lighthouse/Chrome, Node, jq); die MicroApp ergänzt keine neuen Analyse-Tools.
- **UI-Bausteine:** Jupiter-kompatible Controls für Tabs, Tabellen, Formulare, Badges, Progress/Timeline und Theme-Toggle.

## QA Test Results
_To be added by /abc-qa_

## Deployment
_To be added by /abc-deploy_
