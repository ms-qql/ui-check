# PROJ-9: Nachher-Scoring (Score-Delta)

## Status: Approved
**Created:** 2026-07-02
**Last Updated:** 2026-07-03

## Dependencies
- Requires: PROJ-4 (Scoring-Engine), PROJ-7 (gebautes Mockup als Bewertungsobjekt)

## Beschreibung
Jagt die generierten Varianten durch dieselbe Scoring-Pipeline wie das Original. Das Delta („38 → 86") ist zugleich QA-Gate der Generierung und zentrales Verkaufsargument im Report/Mockup.

## User Stories
- Als Auxevo-Nutzer möchte ich belegen können, dass das Redesign messbar besser ist — mit derselben Methodik wie beim Audit.
- Als Pipeline möchte ich schwache Generierungen erkennen und neu anstoßen, bevor der Kunde sie sieht.

## Acceptance Criteria
- [ ] Beide Varianten werden lokal gerendert (headless) und mit identischer Rubrik-Version bewertet wie das Original; Ergebnis in `scores-safe.json` / `scores-bold.json`
- [ ] QA-Gate: Variante mit Gesamtscore < Original + 15 wird als „nicht ausgeliefert" markiert; ein automatischer Retry mit Feedback aus den Befunden (max. 1 Retry pro Variante)
- [ ] Score-Delta erscheint in `report.md` und im Mockup (Badge „38 → 86")
- [ ] Lighthouse-Dimension wird für lokale Mockups als „nicht vergleichbar" behandelt (kein echtes Hosting) und aus dem Delta-Vergleich renormiert — Vergleich läuft über die 4 übrigen Dimensionen

## Edge Cases
- Beide Varianten scheitern am Gate auch nach Retry: Lauf endet mit Audit-only-Ergebnis + Fehlerbericht statt schlechtem Mockup
- Judge bewertet eigenes Werk (Bias): Nachher-Scoring läuft mit frischem Kontext (kein Zugriff auf Generierungs-Verlauf), Rubrik-Anker identisch

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
**Erstellt:** 2026-07-03 · **Stack:** Claude-Code-Skill-Pipeline + lokale Render-/Scoring-Skripte + Run-Ordner-Artefakte · **Branch:** dev

### Struktur
PROJ-9 baut keine neue Bewertungsmethodik, sondern wendet die vorhandene PROJ-4-Rubrik auf die fertigen PROJ-7-Mockups an. Der Ablauf ist ein Gate zwischen Redesign-Erzeugung und Kundenauslieferung:

```
Nachher-Scoring
├── Input-Gate
│   ├── Original-Score vorhanden (`scores.json`)
│   ├── Mockup vorhanden (`mockup.html`)
│   └── Redesign-Varianten Safe/Bold vollständig und exportfähig
├── Lokales Rendering
│   ├── Variante Safe als frischer Screenshot-Kontext
│   └── Variante Bold als frischer Screenshot-Kontext
├── Judge-Pass je Variante
│   ├── gleiche Rubrik-Version wie Original
│   ├── kein Zugriff auf Generierungs-Verlauf
│   └── Lighthouse-Dimension als "nicht vergleichbar" markiert
├── Delta-Vergleich
│   ├── Original vs. Safe
│   ├── Original vs. Bold
│   └── Renormierung auf die 4 vergleichbaren Dimensionen
├── QA-Gate
│   ├── Score >= Original + 15 → auslieferbar
│   └── Score < Original + 15 → ein Retry mit Befund-Feedback
└── Report-/Mockup-Anreicherung
    ├── `report.md` bekommt Score-Delta und Gate-Status
    └── `mockup.html` bekommt Delta-Badge je auslieferbarer Variante
```

### Datenmodell
Es werden keine Kundendaten in einer Datenbank gespeichert. PROJ-9 erweitert den bestehenden Run-Ordner um maschinenlesbare Nachher-Bewertungen:

```
<run-dir>/scores.json              Original-Score aus PROJ-4, bleibt Quelle für den Vorher-Wert
<run-dir>/mockup.html              gebündeltes Mockup aus PROJ-7, wird als Bewertungsobjekt gerendert
<run-dir>/scores-safe.json         Score, Dimensionen, Befunde, Rubrik-Version, Gate-Status für Safe
<run-dir>/scores-bold.json         Score, Dimensionen, Befunde, Rubrik-Version, Gate-Status für Bold
<run-dir>/after-scoring.json       Zusammenfassung: Gewinner, Deltas, Retry-Status, Auslieferbarkeit
<run-dir>/report.md                wird um Delta-Zeile und ggf. Fehlerbericht ergänzt
```

Jede Nachher-Bewertung enthält:
- Variante: Safe oder Bold
- Rubrik-Version und Score-Gewichte
- Gesamtscore auf den 4 vergleichbaren Dimensionen
- Dimensionen Visuell, KI-Generik, Accessibility und Conversion
- Performance/Lighthouse als "nicht vergleichbar", nicht als schlechter Score
- Befunde mit Quelle und Fundort
- Delta zum Original und Entscheidung "auslieferbar / nicht ausgeliefert / nach Retry gescheitert"

MinIO ist für dieses Feature nicht nötig: Screenshots und HTML-Dateien bleiben lokale Run-Artefakte. Neon/Postgres ist ebenfalls nicht nötig, weil der MVP weiterhin dateibasiert arbeitet.

### CLI-/API-Form
Es entstehen keine FastAPI-Endpunkte. Der fachliche Vertrag ist ein lokaler Pipeline-Schritt:

```
scripts/after-score.sh <run-dir>
```

Der Schritt läuft nach PROJ-7 und vor der finalen Kundenübergabe. Für spätere Jupiter-/FastAPI-Integration kann PROJ-14 denselben Schritt als Run-Aktion auslösen und nur die erzeugten Artefakte anzeigen.

Exit-Verhalten aus PM-Sicht:
- Erfolgreich: mindestens eine Variante besteht das Delta-Gate; Report und Mockup zeigen das Score-Delta.
- Degradiert: eine Variante scheitert, die andere ist auslieferbar; Report nennt beide Ergebnisse.
- Abbruch: beide Varianten scheitern auch nach Retry; es wird kein schlechtes Mockup ausgeliefert, sondern ein Audit-only-Ergebnis mit Fehlerbericht.

### Tech-Entscheidungen
- **Gleiche Rubrik-Version wie beim Original:** Das Verkaufsargument "38 → 86" ist nur belastbar, wenn Vorher und Nachher nach derselben Bewertungslogik gemessen werden.
- **Frischer Judge-Kontext:** Der Nachher-Judge sieht das fertige Mockup, aber nicht den Generierungs-Verlauf. Das reduziert Bias, weil die Bewertung nicht die eigene Entstehungsgeschichte verteidigt.
- **Lighthouse aus dem Delta entfernen:** Lokale Mockups haben kein echtes Hosting, CDN, Caching oder Serververhalten. Ein Performancevergleich wäre irreführend, deshalb wird das Delta auf die übrigen Dimensionen renormiert.
- **QA-Gate statt bloßer Kennzahl:** Ein Redesign, das weniger als 15 Punkte besser ist, soll nicht zum Kunden. Der Score ist damit nicht nur Marketing, sondern ein Auslieferungs-Gate.
- **Ein Retry pro Variante:** Ein automatischer Verbesserungsversuch ist sinnvoll, aber eine offene Retry-Schleife würde Laufzeit und Kosten unkalkulierbar machen. Nach einem Scheitern wird transparent abgebrochen.
- **Separate Nachher-Dateien:** `scores.json` bleibt das Original aus PROJ-4. Nachher-Scores liegen getrennt, damit spätere Auswertung, QA und Report-Diffs nicht vermischen, welche Bewertung wozu gehört.
- **Report und Mockup als primäre Oberflächen:** Nutzer sollen den Delta-Beleg dort sehen, wo sie ohnehin arbeiten: im Report für Argumentation und im Mockup als schneller Badge.

### Dependencies
- **Vorhanden:** PROJ-4-Scoring-Kontrakt (`scores.json`, Rubriken), PROJ-7-Mockup (`mockup.html`), lokaler Browser/Headless-Renderer aus der bestehenden Pipeline, `jq` für Artefaktprüfung.
- **Keine neuen Backend-/DB-Abhängigkeiten:** kein FastAPI-Endpunkt, keine Neon-Tabelle, kein MinIO-Bucket.
- **Optional später:** Jupiter/PROJ-14 kann die Nachher-Artefakte visualisieren, ohne den Bewertungsvertrag zu ändern.

## Implementation Notes (Backend/CLI)
**Umgesetzt:** 2026-07-03 · **Branch:** `dev`

### Gelieferte Artefakte
- `scripts/after-score.sh` — deterministischer Nachher-Scoring-Schritt für den Run-Ordner.
- `scripts/tests/after_score_test.sh` — hermetische Black-Box-Suite ohne Browser/LLM.
- `scripts/README.md` — PROJ-9-CLI-Vertrag, Artefakte, Exit-Codes und Judge-Kontrakt.

### Implementierter Vertrag
- Input-Gates: `scores.json`, `report.md`, `mockup.html`, `after-judge-safe.json` und `after-judge-bold.json` müssen vorhanden und rubrik-kompatibel sein.
- Outputs: `scores-safe.json`, `scores-bold.json`, `after-scoring.json` sowie Diagnose-/Retry-Dateien unter `after-score/`.
- Performance/Lighthouse wird für lokale Mockups als `measurable:false` und `comparable:false` markiert; das Delta wird über Visuell, Slop, Accessibility und Conversion renormiert.
- Delta-Gate: Default `+15` Punkte gegen den renormierten Originalscore; mindestens eine bestandene Variante ergibt Exit 0.
- Retry: Bei initialem Gate-Fail schreibt das Skript einen `retry-<variant>.md`-Brief aus den Befunden. Liegt keine Retry-Judge-Datei vor, kann `--retry-cmd` / `AFTER_SCORE_RETRY_CMD` automatisch genau einen Retry anstoßen und die erzeugte Retry-Judge-Datei wird bewertet.
- Report/Mockup: `report.md` bekommt einen idempotenten Abschnitt `Nachher-Scoring (Score-Delta)`, `mockup.html` ein idempotentes Score-Delta-Badge.
- `status.json`: falls vorhanden, wird `phases.after_scoring` für PROJ-14 fortgeschrieben.

### Bewusste Abgrenzung
Der eigentliche visuelle Judge bleibt ein frischer externer Judge-Pass gegen das fertige Mockup. Das Skript ruft keinen LLM- oder Browser-Judge selbst auf, sondern macht die deterministische Auswertung, Gate-Entscheidung und Artefakt-Anreicherung. Dadurch bleibt der Schritt hermetisch testbar und passt zum bestehenden PROJ-4-Muster (`score-report.sh` konsumiert ebenfalls Judge-JSON statt selbst zu urteilen).

### Tests
```bash
bash scripts/tests/after_score_test.sh
```

2026-07-03: **26 bestanden, 0 fehlgeschlagen**.

## QA Test Results
**Getestet:** 2026-07-03 · **Tester:** QA/Red-Team · **Branch:** `dev`
**Methode:** hermetische CLI-Suites (`after_score_test.sh`, `score_report_test.sh`, `mockup_export_test.sh`) + adversariale Probe gegen fehlende Nachher-A11y-Dimension. Kein FastAPI/Flutter vorhanden; Tenant/Auth/MinIO-Aspekte nicht anwendbar.

### Test Summary
| Suite | Ergebnis |
|---|---|
| `bash scripts/tests/after_score_test.sh` | 26 bestanden, 0 fehlgeschlagen |
| `bash scripts/tests/score_report_test.sh` | 50 bestanden, 0 fehlgeschlagen |
| `bash scripts/tests/mockup_export_test.sh` | 68 bestanden, 0 fehlgeschlagen |
| `bash -n scripts/after-score.sh scripts/tests/after_score_test.sh` | OK |

### Acceptance Criteria
| # | Kriterium | Ergebnis | Beleg |
|---|---|---|---|
| 1 | Beide Varianten werden als Nachher-Score mit identischer Rubrik-Version bewertet; `scores-safe.json` / `scores-bold.json` entstehen | Pass | Suite A erzeugt beide Dateien und prüft Rubrik-Kompatibilität; Suite D prüft, dass fehlende Nachher-A11y jetzt hart mit Exit 2 abbricht. |
| 2 | QA-Gate `< Original + 15` markiert nicht ausgeliefert; Retry mit Befund-Feedback max. 1x | Pass | Suite A/C prüft Gate-Fail und Audit-only; Suite B prüft automatischen Retry via `--retry-cmd`, Retry-Brief und genau eine Retry-Auswertung. |
| 3 | Score-Delta erscheint in `report.md` und im Mockup-Badge | Pass | Suite A prüft Report-Erweiterung und `UI-CHECK-AFTER-SCORING-BADGE` in `mockup.html`. |
| 4 | Lighthouse/Performance ist lokal nicht vergleichbar und wird aus dem Delta renormiert | Pass | Suite A prüft `dimensions.performance.measurable == false`; adversariale Probe bestätigt Renormierung ohne Lighthouse. |

### Edge Cases
- **Beide Varianten scheitern:** Pass. Suite C erzeugt Exit 1, `after-scoring.status == failed`, `status.json.phases.after_scoring.status == failed` und Audit-only-Hinweis im Report.
- **Judge-Bias / frischer Kontext:** Teilweise prüfbar. Das Skript konsumiert separate `after-judge-*.json`-Dateien und nutzt nicht den Generierungsverlauf. Es kann aber nicht beweisen, dass der externe Judge tatsächlich frisch/headless gegen das Mockup lief; das bleibt Orchestrierungsverantwortung.
- **Rubrik-Version-Konflikt:** Pass. Suite D bricht bei abweichender `rubric_version` mit Exit 2 ab.
- **Fehlendes `mockup.html`:** Pass. Suite D bricht mit Exit 2 ab.

### Security / Red-Team
- **Auth/Tenant/RLS:** Nicht anwendbar; PROJ-9 hat keine FastAPI-Endpunkte, keine DB und kein MinIO.
- **Command Injection:** Keine Shell-Ausführung aus Judge-Feldern; Dateipfade werden quoted. Keine Critical/High-Findings.
- **HTML/Markdown Injection:** Score-Delta-Badge rendert nur berechnete Zahlen/Labels. Retry-Briefs enthalten Judge-Befunde als Markdown; aktuell lokales Diagnoseartefakt, nicht kundenseitig gerendert. Residual Low-Risk, falls diese Dateien später ungefiltert als HTML ausgeliefert werden.
- **Artefakt-Idempotenz:** Report- und Mockup-Marker werden vor erneutem Schreiben entfernt; `--force` schützt vor versehentlicher Neu-Auswertung vorhandener `after-scoring.json`.

### Gefundene Bugs — behoben am 2026-07-03
| ID | Severity | Befund | Fix / Regression |
|---|---|---|---|
| PROJ-9-BUG-1 | Medium | `accessibility.score` im Nachher-Judge war nicht verpflichtend; dadurch konnte ein 3-Dimensionen-Delta durch das Gate kommen. | `validate_judge` verlangt jetzt `.accessibility.score` oder `.a11y.score`; Suite D prüft fehlende Nachher-A11y mit Exit 2. |
| PROJ-9-BUG-2 | Medium | Retry wurde nur ausgewertet, falls eine Retry-Judge-Datei bereits existierte; automatisches Neuanstoßen fehlte. | `--retry-cmd` / `AFTER_SCORE_RETRY_CMD` ergänzt. Bei initialem Gate-Fail wird der Retry-Brief an das Kommando übergeben, das genau eine Retry-Judge-Datei schreibt; Suite B prüft den automatischen Hook. |

### Regression
- PROJ-4-Scoring-Vertrag: grün (50/50).
- PROJ-7/8-Mockup-Export-Vertrag: grün (68/68).
- Keine Flutter-/Browser-QA für PROJ-14 durchgeführt, da der Nutzer Frontend bewusst später behandelt und PROJ-14 parallel läuft.

### Production-Ready-Bewertung
**READY.** Keine offenen Critical/High/Medium-Bugs gefunden. Status auf **Approved** gesetzt; nächster Schritt ist Deploy/Handoff in die Gesamtpipeline.

## Deployment
_To be added by /abc-deploy_
