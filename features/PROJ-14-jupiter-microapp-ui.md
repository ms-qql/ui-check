# PROJ-14: Jupiter-MicroApp-UI

## Status: In Review
**Created:** 2026-07-02
**Last Updated:** 2026-07-03

## Dependencies
- Requires: PROJ-5 (headless aufrufbarer Skill); sinnvoll erst mit PROJ-6–9 (sonst nur Audit-Ansichten)
- Referenz: `design/ui-mockup.html` (v0.2 — genehmigtes UI-Design)

## Frontend Implementation Notes
**2026-07-03 · ABC-Frontend:** Native Jupiter-MicroApp gebaut unter
`/home/dev/projects/jupiter/nextjs_app/components/microapps/ui_check/`.
Die App ist in `lib/microapps-registry.ts` registriert und in
`backend/config/engines.yaml` sowie `backend/config/engines.example.yaml` als
`ui_check` sichtbar gemacht. Umgesetzt sind Dashboard mit URL/Modus/Tiefe,
KI-Anbieter-/Modell-Auswahl, Prompt, Desktop-Option, Start/Abbruch,
Polling-basierte Lauf-Historie, Fortschritt, Audit-Report, Branding,
Vorher/Nachher-Aktionen und Portfolio-/Artefaktansichten.

**Offen für Backend:** Die UI nutzt die in dieser Spec definierten
`/ui-check/runs`-Endpunkte. Die produktive Runner-Schicht muss noch gebaut
werden, bevor QA echte Headless-Läufe abnehmen kann.

**2026-07-03 · ABC-Backend:** Lokale Jupiter-Runner-API umgesetzt in
`/home/dev/projects/jupiter/backend/app/routes/ui_check.py` +
`app/engine/ui_check.py`. Die Endpunkte lesen bestehende Run-Ordner defensiv,
liefern Lauf-Liste, Details, Status, Artefakte, Start/Abbruch und
Redesign-Nachzug aus. Konfigurierbarer Projektpfad:
`JUPITER_UI_CHECK_PROJECT_PATH` (Default `/home/dev/projects/design/ui-check`).
Verifiziert mit `tests/test_proj14_ui_check.py` plus Regression
`test_proj18_engines.py`, `test_proj40_microapps.py`, `test_proj53_book_nuggets.py`
im Jupiter-Backend: **64 passed**.

**2026-07-03 · Fix (Deploy-Gap):** UI-Check-Seite zeigte auf `jupiter.auxevo.tech`
den Banner „Not Found" — alle `/api/ui-check/runs`-Calls 404. Ursache war **kein
Code-Bug**, sondern dass die komplette PROJ-14-Implementierung im Jupiter-Repo
untracked/uncommitted war; Prod lief auf `main` (v0.26.4) ganz ohne `/ui-check`-Router.
Pfad-Contract (`API_BASE=/api` + Router-Prefix `/ui-check`) war korrekt. Behoben:
PROJ-14 als Commit `23b993b` auf Jupiter-`dev` gebündelt (Backend-Route/Engine/Schema,
`main.py`/`config.py`, Frontend + `api.ts`/`types.ts`/Registry, Test 3 passed) inkl.
Umlaut-Fix (`fuer`→`für`). **Offen:** `dev`→`main` mergen + Jupiter via `/abc-deploy`
neu deployen, damit die Route in Prod verfügbar wird.

## User Stories
- Als Auxevo-Nutzer möchte ich UI-Check aus Jupiter heraus starten (URL + Modus + KI-Anbieter + Modell + Prompt-Feld) und Ergebnisse dort ansehen, statt im Terminal zu arbeiten.

## Acceptance Criteria
- [ ] Integration nach PROJ-53-Muster (Buch-Nuggets): MicroApp ruft den Skill headless auf, zeigt Fortschritt und Ergebnis
- [ ] Screens gemäß Mockup: Dashboard (URL, Modi, KI-Anbieter-/Modell-Auswahl, Prompt-Feld, Lauf-Historie), Audit-Report (Score-Ring, 5 Dimensionen, Befunde), Branding (Scraped-Karte), Vorher/Nachher, Portfolio
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
PROJ-14 baut keine neue Audit-Engine, sondern die bedienbare Jupiter-Oberfläche für die bestehende UI-Check-Pipeline. Die MicroApp startet Läufe mit URL, Modus, KI-Anbieter, Modell und Prompt, zeigt deren Fortschritt, liest fertige Artefakte aus dem Run-Ordner und macht die fünf Mockup-Screens aus `design/ui-mockup.html` produktiv nutzbar.

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
│   ├── RunStartPanel (URL, Modus, KI-Anbieter, Modell, Prompt, Desktop-Option, Start/Abbruch)
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
- **KI-Modellwahl:** neue Läufe speichern `ai_provider` und `ai_model` in `ui-check.json`/`status.json`. MVP-Anbieter: `claude`, `codex`, `openrouter`. Die konkreten Modelloptionen kommen aus der lokalen Konfiguration; das Mockup zeigt je Anbieter eine passende Modellliste.
- **Rubrik-/Rezept-Versionen:** Versionen werden sichtbar gemacht. Alte Scores werden nicht automatisch mit neuen Rubriken vermischt; die UI zeigt einen Versionshinweis.
- **Keine Klar-URL im Listenindex:** `runs.jsonl` enthält bewusst nur URL-Hashes. Die volle URL steht nur im lokalen Run-Ordner (`meta.json`/`ui-check.json`) und wird nur beim Öffnen eines konkreten Laufs gelesen.
- **Dateien:** Screenshots, Logos und `mockup.html` bleiben lokale Artefakte im Run-Ordner. MinIO ist für diesen MVP nicht nötig.

### Runner-/API-Form (nur Vertrag, keine Implementierung)
Die Jupiter-MicroApp braucht eine kleine lokale Runner-Schicht, weil Browser-UI und Shell-Pipeline getrennte Welten sind. Diese Schicht darf dünn bleiben und reicht Befehle an die bestehenden headless Treiber weiter:

- `GET /ui-check/runs` → Liste der Läufe aus `data/runs.jsonl`, angereichert um sichtbare Metadaten aus den Run-Ordnern.
- `GET /ui-check/runs/{run_id}` → Detaildaten eines Laufs: Status, Scores, Report-Auszug, Branding, verfügbare Artefakte.
- `POST /ui-check/runs` → neuen Lauf starten mit URL, Modus, KI-Anbieter, Modell, Prompt, Industrie optional, Desktop optional und gewünschter Tiefe `audit` oder `redesign`.
- `GET /ui-check/runs/{run_id}/status` → Fortschritt aus `status.json`; Polling reicht, Echtzeit-Websocket ist nicht nötig.
- `POST /ui-check/runs/{run_id}/cancel` → laufenden Prozess abbrechen; der Run bleibt mit Abbruchstatus sichtbar.
- `POST /ui-check/runs/{run_id}/redesign` → Redesign/Mockup für einen vorhandenen Audit-Lauf nachziehen, sobald PROJ-6/7/8 verfügbar sind.
- `GET /ui-check/runs/{run_id}/artifacts/{kind}` → bekannte Artefakte öffnen oder als Datei ausliefern: Report, Scores, Tokens, Screenshots, `mockup.html`, Gate-Ergebnisse.

Alle Endpunkte sind lokal/Jupiter-intern. Es gibt im MVP keine Fremdnutzer, kein Mandantenmodell, keine öffentliche API und keine eigene Auth-Schicht; Jupiter liefert den Anwendungskontext.

### Ablauf pro Lauf
```
1. Nutzer gibt URL, Modus, KI-Anbieter, Modell und optionalen Prompt ein.
2. Runner startet den passenden headless Ablauf und legt/ermittelt den Run-Ordner.
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
**QA-Datum:** 2026-07-03  
**Tester:** Codex `/abc-qa`  
**Getesteter Stand:** `dev`, aktueller Worktree in `/home/dev/projects/design/ui-check` +
Jupiter-Integration in `/home/dev/projects/jupiter`

### Ergebnis
- **Akzeptanzkriterien:** 2 bestanden, 3 fehlgeschlagen
- **Bugs:** 4 offen (3 High, 1 Medium)
- **Security-/Privacy-Befund:** 1 Medium
- **Produktionsentscheidung:** **NOT READY** — High-Bugs blockieren die Freigabe.

### Akzeptanzkriterien
| Kriterium | Status | Nachweis |
|---|---:|---|
| Integration nach PROJ-53-Muster: native MicroApp + Runner-API + Fortschritt | ⚠ Teilweise | Native Registry, Backend-Router und Polling existieren; `python -m pytest backend/tests/test_proj14_ui_check.py backend/tests/test_proj18_engines.py backend/tests/test_proj40_microapps.py backend/tests/test_proj53_book_nuggets.py` läuft grün. Start mit Tiefe `redesign` führt aber nur Audit aus, siehe `PROJ-14-BUG-1`. |
| Screens gemäß Mockup | ✅ Pass | Dashboard, Audit-Report, Branding, Vorher/Nachher und Portfolio sind in `ui-check-app.tsx` umgesetzt; Next-Build/TypeScript erfolgreich. |
| Light/Dark-Toggle konsistent mit Jupiter | ✅ Pass | Nutzt `ThemeToggle` aus Jupiter; Next-Build/TypeScript erfolgreich. |
| Lauf-Historie aus `runs.jsonl`; Öffnen eines Laufs zeigt Artefakte | ❌ Fail | Liste wird aus Run-Ordnern gelesen statt aus `data/runs.jsonl`; Artefakt-Buttons sind teils nicht nutzbar, siehe `PROJ-14-BUG-2` und `PROJ-14-BUG-3`. |
| Deutsche UI durchgängig | ⚠ Teilweise | Nutzertexte sind überwiegend deutsch, aber einzelne Source-Kommentare/technische Fallbacks enthalten ASCII-Umschreibungen (`fuer`). Für die UI selbst kein Blocker gefunden. |

### Edge Cases
| Edge Case | Status | Nachweis |
|---|---:|---|
| Lauf läuft noch: Fortschritt, kein UI-Freeze, Abbruch möglich | ⚠ Teilweise | Backend-Test `test_ui_check_start_and_cancel_run` grün; Polling ist implementiert. Kein Browser-Smoke gegen laufenden echten Jupiter-Server durchgeführt. |
| Alte Läufe mit älterer Rubrik-Version | ✅ Pass | `rubric_version` wird in Liste und Auditkopf angezeigt; keine automatische Score-Normalisierung gefunden. |

### Automatisierte Tests
- ✅ Backend/Jupiter: `64 passed` mit `python -m pytest backend/tests/test_proj14_ui_check.py backend/tests/test_proj18_engines.py backend/tests/test_proj40_microapps.py backend/tests/test_proj53_book_nuggets.py`
- ✅ Frontend Lint: `npm run lint -- --max-warnings=0`
- ✅ Frontend Build/TypeScript: `npm run build`
- ❌ Frontend Vitest Gesamt-Suite: `173 passed, 1 failed`; Fail in `components/cockpit/file-preview.test.tsx` (`rendert Bilder als <img>...`) ist eine bestehende Shared-UI-Regression außerhalb PROJ-14, aber vor Release weiter beobachten.

### Bugs

#### PROJ-14-BUG-1 — High — Tiefe `Audit + Redesign` startet keinen Redesign-/Mockup-Lauf
**Reproduktion:** In der MicroApp die Tiefe `Audit + Redesign` wählen und Lauf starten.  
**Ist:** Backend `UiCheckService.start_run()` ruft nur `scripts/ui-check.sh <url> --out <run_dir>` auf; `payload.depth` wird beim Kommando nicht ausgewertet. `redesign.sh`/`mockup-export.sh` werden nicht nachgezogen.  
**Soll:** Bei Tiefe `redesign` muss nach abgeschlossenem Audit der Redesign-/Mockup-Pfad angestoßen oder klar als separater, manueller Schritt angezeigt werden.  
**Referenz:** `/home/dev/projects/jupiter/backend/app/engine/ui_check.py:97`

#### PROJ-14-BUG-2 — High — Artefakt-Buttons öffnen geschützte API ohne Authorization
**Reproduktion:** In einer Jupiter-Installation mit Auth einen Report-/Scores-/Mockup-Button klicken.  
**Ist:** `ArtifactButton` nutzt `window.open(uiCheckArtifactUrl(...))`. Der neue Request trägt keinen `Authorization: Bearer ...` Header; `/ui-check/*` hängt am `auth_gate`. Ein direkter API-Test ohne Token liefert `401 Nicht angemeldet`.  
**Soll:** Artefakte müssen über einen authentifizierten Fetch/Blob-Download, einen kurzlebigen Download-Token oder eine Backend-Route mit passender Cookie-/Session-Strategie geöffnet werden.  
**Referenz:** `/home/dev/projects/jupiter/nextjs_app/components/microapps/ui_check/ui-check-app.tsx:154`, `/home/dev/projects/jupiter/nextjs_app/lib/api.ts:1208`

#### PROJ-14-BUG-3 — High — Screenshot-Artefaktbutton verwendet falschen `kind`
**Reproduktion:** Einen Lauf mit Screenshot-Artefakten öffnen und im Vorher/Nachher-Tab auf `Screenshots` klicken.  
**Ist:** Die API liefert Artefakt-Kinds wie `screenshot-0`; die UI sendet aber literal `screenshots`, was im Backend 404 ergibt. Ad-hoc-Test: `artifact_path("r1", "screenshots") -> 404`, `artifact_path("r1", "screenshot-0") -> Pfad`.  
**Soll:** UI muss die `detail.artifacts.screenshots[]`-Kinds einzeln nutzen oder eine Sammelansicht bereitstellen.  
**Referenz:** `/home/dev/projects/jupiter/nextjs_app/components/microapps/ui_check/ui-check-app.tsx:882`

#### PROJ-14-BUG-4 — Medium — Lauf-Historie ignoriert `data/runs.jsonl` und zeigt Klar-URLs im Listenindex
**Reproduktion:** `data/runs.jsonl` leer lassen und Run-Ordner anlegen; `UiCheckService.list_runs()` liefert trotzdem den Run aus dem Ordner.  
**Ist:** `_run_dirs()` enumeriert `runs/`; `_summary()` setzt `display_url` aus `status.json`/`ui-check.json`/`meta.json`. Damit ist die Historie nicht aus `runs.jsonl`, und die im Tech Design geforderte Trennung "Hash im Listenindex, Klar-URL erst beim Öffnen" wird verletzt.  
**Soll:** `GET /ui-check/runs` muss `data/runs.jsonl` als Index nutzen und Klar-URLs erst in `GET /ui-check/runs/{run_id}` laden, oder das Tech Design muss bewusst angepasst werden.  
**Referenz:** `/home/dev/projects/jupiter/backend/app/engine/ui_check.py:201`

### Security Audit
- ✅ Geschützte Endpunkte: Ohne Token geben `/ui-check/runs` und `/ui-check/runs/{run_id}` `401` zurück.
- ✅ Path Traversal: Bestehender Test `test_ui_check_serves_artifacts_and_404s_path_traversal` grün.
- ⚠ Privacy/Data Contract: `GET /ui-check/runs` gibt Klar-URLs aus Run-Ordnern zurück, obwohl der Listenindex laut Design nur Hashes enthalten soll (`PROJ-14-BUG-4`).
- Nicht anwendbar im MVP: Mandanten-Isolation, MinIO-Presigned-URL-Angriffe.

### Empfehlung
Status bleibt **In Review**. Vor Approval zuerst `PROJ-14-BUG-1`, `PROJ-14-BUG-2` und `PROJ-14-BUG-3` fixen, danach `/abc-qa 14` erneut ausführen.

## Deployment
_To be added by /abc-deploy_

## QA Test Results (Nachtrag: Listen-Verwaltung — Ausblenden & Löschen)
**QA-Datum:** 2026-07-05
**Tester:** Claude `/abc-qa`
**Getesteter Stand:** Jupiter-Worktree (Branch `dev`), uncommittete Änderungen an
`backend/app/routes/ui_check.py`, `backend/app/engine/ui_check.py`,
`backend/tests/test_proj14_ui_check.py`,
`nextjs_app/components/microapps/ui_check/ui-check-app.tsx`,
`nextjs_app/lib/api.ts`.

### Ergebnis
- **Neue Funktionalität:** 2/2 Akzeptanzkriterien bestanden (Ausblenden per Auge, Löschen per Papierkorb inkl. Server-Löschung)
- **Bugs neu:** 0 High/Critical, 1 Low
- **Regression:** keine — `pytest` 1051 passed/1 pre-existing Fail (`test_proj50_codex_abc` skill-drift, unabhängig); PROJ-14/18/40/53 gemeinsam **69 passed**
- **Produktionsentscheidung für diesen Nachtrag:** **READY** — bestehende `PROJ-14-BUG-1..4` bleiben unberührt offen.

### Akzeptanzkriterien (Nachtrag)
| Kriterium | Status | Nachweis |
|---|---:|---|
| Läufe einzeln ausblenden (Auge), persisted über Reloads | ✅ Pass | `RunHistory` togglet `hidden`-Set, schreibt `localStorage["ui-check:hidden-runs"]`; `useEffect` re-persistiert. Umschalter "Ausgeblendete (N)" zeigt sie wieder. |
| Läufe komplett vom Server löschen (Papierkorb) | ✅ Pass | `DELETE /ui-check/runs/{run_id}` → 204; `shutil.rmtree` entfernt den Run-Ordner; 2 neue Tests `test_delete_run_removes_folder_and_404s_after`, `test_delete_run_refuses_running_process` grün. Frontend: Bestätigungs-Dialog, danach Refresh + aktive Auswahl cleared. |

### Bugs (Nachtrag)
#### PROJ-14-BUG-5 — Low — Ausgeblendete Läufe verbleiben in `localStorage` nach Server-Löschung
**Reproduktion:** Lauf A ausblenden (Auge). Lauf A auf anderem Weg vom Server löschen (z. B. zweites Gerät oder direkter Ordner-Weg). Auf dem ersten Gerät_reload. **Ist:** `run_id` bleibt ewig im `localStorage["ui-check:hidden-runs"]`-Set, da das Set nicht gegen die frische Run-Liste abgeglichen wird. **Soll:** Beim Laden oder nach `refresh()` sollten IDs, die nicht mehr in `runs` existieren, aus dem Hidden-Set entfernt werden. **Auswirkung:** rein kosmetisch (keinlaufender Toggle-Schaden, nur langsam wachsender Storage). **Referenz:** `nextjs_app/components/microapps/ui_check/ui-check-app.tsx` (`loadHiddenRuns`/`RunHistory`).

### Security Audit (Nachtrag)
- ✅ Path-Traversal beim Löschen: `_safe_run_id` (`/`, `..` verboten) + zusätzlicher Guard `path.resolve() == runs_dir.resolve() → UiCheckNotFound`; Test `test_delete_run_removes_folder_and_404s_after` deckt `DELETE /../..`-Fall ab.
- ✅ Kein Löschen laufender Läufe: Engine wirft `UiCheckConflict` (409), Frontend deaktiviert den Papierkorb-Button für Status `queued`/`running`.
- ⚠ Kein Mandanten-Schutz auf `DELETE` (wie auch nicht auf den anderen UI-Check-Routes) — vorbestehend, nicht durch diesen Nachtrag eingeführt.
- ✅ Kein CSRF-Risiko: API nutzt Bearer-Token, keine Cookies.

### Automatisierte Tests (Nachtrag)
- ✅ Backend: `python -m pytest backend/tests/test_proj14_ui_check.py` → **8 passed** (6 bestehend + 2 neu).
- ✅ Regression: `test_proj14 + test_proj18 + test_proj40 + test_proj53` → **69 passed**.
- ✅ Frontend Lint: `npm run lint` clean.
- ✅ Frontend TypeScript: `npx tsc --noEmit` — nur vorbestehender, unabhängiger Fehler in `lib/md-tree.test.ts` (nicht PROJ-14).

### Empfehlung
Nachtrag ist freigegeben. `PROJ-14-BUG-1..3` (High) bleiben der Blocker für das Gesamt-Approval und sind von diesem Nachtrag unberührt. BUG-5 (Low) kann opportunistisch mitgenommen werden.
