# PROJ-8: Vorher/Nachher-Ansicht & Varianten-Voting

## Status: In Review
**Created:** 2026-07-02
**Last Updated:** 2026-07-03

## Dependencies
- Requires: PROJ-1 (Original-Screenshots), PROJ-7 (Mockup-Export als Träger)

## Beschreibung
Erweitert das exportierte Mockup um die Verkaufs-Ansichten: A/B-Voting-Screen (Safe vs. Bold) als Einstieg, Vorher/Nachher-Split-Slider und sektionsweisen Vergleich mit Begründungen.

## User Stories
- Als Kunde möchte ich zuerst mit einem Klick sagen, welche Richtung mir gefällt, bevor ich Details sehe.
- Als Kunde möchte ich Original und Redesign nebeneinander schieben können, um den Unterschied sofort zu erfassen.
- Als Auxevo-Nutzer möchte ich pro Sektion eine 1-Satz-Begründung zeigen, um Design-Entscheidungen verhandelbar zu machen.

## Acceptance Criteria
- [ ] Einstiegs-Screen: „Welche Richtung gefällt Ihnen?" — Safe/Bold nebeneinander, Auswahl wird lokal gespeichert und auf der Detailseite vorausgewählt
- [ ] Split-Slider: Original-Screenshot vs. Redesign, synchron scrollend, Viewport-Umschalter 375/768/1440
- [ ] Sektionsvergleich: je Sektion Vorher-Ausschnitt, Nachher-Ausschnitt, Begründung (aus `brief.md`)
- [ ] Alles innerhalb der einen `mockup.html` (kein zweites Artefakt); Voting-Ergebnis exportierbar (sichtbarer „Antwort kopieren"-Button → strukturierter Text für Mail)
- [ ] Deutsche UI-Texte, verständlich für Nicht-Techniker

## Edge Cases
- Original-Screenshot deutlich länger/kürzer als Redesign: Slider alignt an Sektionsgrenzen, nicht pixelweise
- Kunde ohne JS: statische Vorher/Nachher-Bilder als Fallback sichtbar
- Nur eine Variante generiert (Safe fehlgeschlagen): Voting-Screen entfällt automatisch

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
**Erstellt:** 2026-07-03 · **Stack:** Erweiterung der PROJ-7-Viewer-Shell (React/Tailwind, Parcel-Bundle) — rein clientseitig, kein Backend · **Branch:** dev

### Struktur (Erweiterung, kein neuer Baustein)
PROJ-8 ist **kein eigener Treiber und kein eigener Skill**: Die Verkaufs-Ansichten
werden Teil der versionierten Viewer-Shell (`scripts/lib/mockup-shell/`), die
`mockup-export.sh` (PROJ-7) ohnehin bündelt. Die Shell hat dafür bereits die
Erweiterungs-Slots reserviert. Es kommen nur **neue Inputs** in den Build und
**neue Publish-Gates** in `gates.json` hinzu — Ablauf, Exit-Codes und
Artefakt (`mockup.html`) bleiben unverändert (AC: „kein zweites Artefakt").

### Aufbau der erweiterten `mockup.html` (PM-Sicht)
```
mockup.html (weiterhin eine Datei, offline lauffähig)
├── Voting-Screen (Einstieg): „Welche Richtung gefällt Ihnen?"
│   ├── Vorschau Safe · Vorschau Bold  (verkleinerte Live-Vorschauen der
│   │   Varianten — keine zusätzlichen Screenshots nötig)
│   └── Auswahl merkt sich die Wahl lokal und öffnet die Detailansicht
│       mit der gewählten Variante vorausgewählt
├── Detailansicht (drei Reiter)
│   ├── „Redesign"          bestehender Safe/Bold-Umschalter aus PROJ-7
│   ├── „Vorher / Nachher"  Split-Slider Original-Screenshot ↔ Redesign,
│   │   synchron scrollend · Viewport-Umschalter 375 / 768 / 1440 ·
│   │   Ausrichtung an Sektionsgrenzen (nicht pixelweise)
│   └── „Sektionsvergleich" je Sektion: Vorher-Ausschnitt · Nachher-
│       Ausschnitt · 1-Satz-Begründung (aus dem Redesign-Brief)
└── „Antwort kopieren"-Leiste: baut einen strukturierten deutschen
    Mail-Text (gewählte Richtung, Domain, Datum) und kopiert ihn
```

### Daten (was der Build neu konsumiert)
```
Inputs beim Mockup-Export (zusätzlich zu PROJ-6/7):
<run-dir>/capture/shot-{375,768,1440}.png   Original-Screenshots (PROJ-1) —
                                            vor dem Einbetten rekomprimiert/skaliert
<run-dir>/capture/sections.json             NEU (additive PROJ-1-Erweiterung):
                                            Sektionsgrenzen je Viewport (Label + Y-Bereich)
<run-dir>/redesign/compare.json             NEU (PROJ-6-Brief-Pass): Zuordnung
                                            Original-Sektion ↔ Redesign-Sektion
                                            + 1-Satz-Begründung je Sektion
```
Gespeichert wird beim Kunden **nichts auf einem Server**: Die Richtungs-Wahl liegt
nur lokal im Browser (localStorage, je Lauf getrennt); der Export erfolgt über den
sichtbaren „Antwort kopieren"-Button. Kein Backend, keine API, kein MinIO — die
Rückkanal-Verdrahtung ist bewusst PROJ-15/19 vorbehalten.

### Cross-Feature-Kontrakt (zwei kleine Ergänzungen)
1. **PROJ-1 (Deployed, additive Erweiterung):** `capture.sh` schreibt zusätzlich
   `sections.json` mit den Pixel-Grenzen der ohnehin schon erkannten Sektionen
   (`sections_detected` existiert bereits) je Viewport. Bestehende Outputs bleiben
   unverändert; die Erweiterung wird im Rahmen von PROJ-8 implementiert und in der
   PROJ-1-Spec nachgetragen. **Alte Läufe ohne `sections.json`** degradieren
   kontrolliert: Slider alignt dann pixelweise, Sektionsvergleich entfällt,
   Gate meldet gelb — oder der Capture-Schritt wird neu ausgeführt.
2. **PROJ-6 (Architected, noch nicht gebaut):** Der Brief-Pass schreibt seinen
   Sektionsplan zusätzlich maschinenlesbar als `redesign/compare.json`
   (Zuordnung + Begründung je Sektion). In der PROJ-6-Spec als Einzeiler ergänzt.

### Neue Publish-Gates (in `gates.json`, gleiche Mechanik wie PROJ-7)
| Gate | Prüfweise | Bei Verstoß |
|---|---|---|
| Voting-Screen vorhanden — oder begründet entfallen (nur 1 Variante generiert) | statisch | rot → Abbruch |
| Jede Vergleichs-Sektion hat eine Begründung | statisch (compare.json) | rot → Abbruch |
| Split-Slider funktioniert bei 375 / 768 / 1440 | Browser (agent-browser) | rot → Abbruch |
| „Antwort kopieren" liefert strukturierten Text | Browser | rot → Abbruch |
| No-JS-Fallback: statische Vorher/Nachher-Bilder im HTML sichtbar | statisch | rot → Abbruch |
| Sektionsgrenzen verfügbar (`sections.json`) | statisch | gelb → Degradation (s. o.) |

Das bestehende Größen-Warn-Gate (< 5 MB) wird durch die eingebetteten
Original-Screenshots erstmals real beansprucht — siehe Tech-Entscheidungen.

### Tech-Entscheidungen
- **Shell-Erweiterung statt neues Artefakt:** Die Spec verlangt alles in der einen
  `mockup.html`; PROJ-7 hat die Slots dafür bewusst vorgesehen. So gibt es keinen
  zweiten Build-Weg, keine zweite Gate-Infrastruktur und keinen neuen CLI-Einstieg.
- **Ein Bild, viele Ansichten:** Jeder Original-Screenshot wird genau **einmal**
  eingebettet; Split-Slider und Sektions-Ausschnitte sind Zuschnitte per CSS auf
  dasselbe eingebettete Bild. Physische Crop-Dateien würden dieselben Pixel mehrfach
  in die Datei kopieren und das 5-MB-Budget sprengen.
- **Rekompression vor dem Einbetten:** Die Capture-PNGs (je ~0,4–0,5 MB) werden beim
  Build zu komprimierten Web-Formaten gewandelt und in der Breite gedeckelt — die
  in PROJ-7 angelegte Auto-Kompression wird damit konkret. Erwartete Mehrgröße nach
  Kompression: unter 1 MB für alle drei Viewports zusammen.
- **Sektionsgrenzen aus dem Capture-Schritt, nicht aus Bild-Analyse:** Der
  Capture-Schritt kennt das echte DOM und erkennt Sektionen bereits — die Grenzen
  dort mitzuschreiben ist deterministisch und billig. Bildbasierte Erkennung
  (Screenshot zerschneiden) wäre heuristisch und unzuverlässig. Damit erfüllt der
  Slider den Edge-Case „an Sektionsgrenzen alignen" mit exakten Werten.
- **Begründungen maschinenlesbar statt Prosa-Parsing:** `brief.md` bleibt das
  menschenlesbare Dokument; der Sektionsvergleich liest `compare.json`. Prosa
  automatisiert zu parsen wäre fragil — und PROJ-6 ist noch nicht gebaut, die
  Ergänzung kostet dort nichts.
- **localStorage + Copy-Button statt Server:** Null Infrastruktur, funktioniert
  offline und per Mail-Anhang, DSGVO-unkritisch (nichts verlässt den Browser).
  Der Kopier-Mechanismus hat einen Fallback (Text sichtbar markieren), weil die
  moderne Zwischenablage-API bei lokal geöffneten Dateien nicht überall verfügbar
  ist — der Button funktioniert also auch im „Datei per Mail"-Szenario.
- **Voting-Vorschauen sind verkleinerte Live-Ansichten:** Die Varianten stecken
  ohnehin vorgerendert in der Datei; sie skaliert anzuzeigen kostet null Bytes.
  Extra-Vorschau-Screenshots würden nur Größe und einen Renderschritt addieren.
- **Nur-eine-Variante-Fall wird beim Build entschieden:** Fehlt eine Variante
  (z. B. Safe fehlgeschlagen), baut der Export ohne Voting-Screen und vermerkt das
  in `gates.json` — kein toter Auswahl-Screen beim Kunden (Edge-Case der Spec).
- **No-JS wie in PROJ-7, konsequent weitergeführt:** Ohne JS zeigt die Datei die
  statischen Vorher/Nachher-Bilder gestapelt; Slider, Voting und Kopieren sind
  reine Verbesserungen obendrauf. Das bleibt statisch prüfbar (Gate).

### Dependencies
- **Neu (npm, nur im Build-Workspace):** `sharp` (Bild-Rekompression/-Skalierung
  vor dem Einbetten)
- **Vorhanden:** Parcel-Build-Harness + Viewer-Shell (PROJ-7), `agent-browser`
  (Browser-Gates), `jq`, `node` v22

## Implementation Notes
**Umgesetzt:** 2026-07-03 · **Branch:** dev · **Scope:** PROJ-8 Shell-Erweiterung in `scripts/lib/mockup-shell/`

- `scripts/mockup-export.sh` kopiert additive PROJ-8-Inputs in den Build-Workspace:
  `capture/shot-{375,768,1440}.png`, optional `capture/sections.json` sowie
  `redesign/compare.json`.
- `scripts/lib/mockup-shell/build.mjs` bettet Original-Screenshots als komprimierte
  Data-URIs ein (`sharp`, Fallback auf Original), normalisiert Sektionsgrenzen und
  schreibt die PROJ-8-Daten direkt in dieselbe `mockup.html`.
- `scripts/lib/mockup-shell/chrome.js` ergänzt Voting-Screen, Detail-Reiter,
  Split-Slider mit Viewport-Umschalter, Sektionsvergleich und den sichtbaren
  „Antwort kopieren"-Flow.
- `scripts/lib/mockup-shell/template.html` enthält zusätzlich einen statischen
  No-JS-Fallback für Vorher/Nachher, damit Original und Redesign auch ohne
  Interaktions-JS sichtbar bleiben.
- Neue Publish-Gates M12-M17 prüfen Voting, `compare.json`-Begründungen,
  Split-Slider, Copy-Text, No-JS-Fallback und Sektionsgrenzen-Degradation.
- `scripts/tests/mockup_export_test.sh` wurde um PROJ-8-Fixtures, Rot-/Warnfälle
  und echte E2E-Assertions erweitert.

**Getestet:** 2026-07-03
- `bash scripts/tests/mockup_export_test.sh` → 68 bestanden, 0 fehlgeschlagen.
- `MOCKUP_EXPORT_E2E=1 bash scripts/tests/mockup_export_test.sh` → 70 bestanden,
  0 fehlgeschlagen; echter Build erzeugte `mockup.html` mit 345639 Bytes und allen
  Publish-Gates grün.
- Regression ergänzt: Läufe ohne `capture/shot-*.png` degradieren M14-M17 gelb
  (`mockup.html` wird trotzdem promotet) statt durch rote Browser-Gates abzubrechen.

## QA Test Results
**Getestet:** 2026-07-03 · **Tester:** QA Engineer / Red-Team · **Branch:** dev  
**Ergebnis:** NOT READY wegen 1 High-Bug. Automatisierte Gates sind grün, aber
ein zentrales Akzeptanzkriterium ist in der Implementierung nur oberflächlich
geprüft.

### Scope
- PROJ-8-Spec inkl. Tech Design, Implementation Notes und Edge Cases gelesen.
- Geprüfte Dateien: `scripts/mockup-export.sh`, `scripts/lib/mockup-shell/*`,
  `scripts/tests/mockup_export_test.sh`.
- Projekt ist CLI/Bash/Node-Pipeline, kein FastAPI/Flutter-Projekt. Backend-/Flutter-
  Schritte aus `abc-qa` sind nicht anwendbar; `conda` ist in dieser Shell nicht
  verfügbar (`conda: command not found`).

### Acceptance Criteria
| # | Kriterium | Status | Nachweis |
|---|---|---|---|
| 1 | Einstiegs-Screen Safe/Bold, Auswahl lokal gespeichert und Detail vorausgewählt | Pass mit Low-Bug | Voting wird gebaut, `setVariant()` schreibt `localStorage`; Copy/Text nutzt aktive Variante. UI-Text weicht orthografisch ab (`gefaellt`). |
| 2 | Split-Slider Original vs. Redesign, synchron scrollend, Viewports 375/768/1440 | **Fail** | Viewport-Tabs vorhanden und Gate M14 grün; Scroll-Synchronisation/Sektions-Snap fehlt im Code. |
| 3 | Sektionsvergleich: Vorher, Nachher, Begründung | Pass | `compare.json` wird gegated (M13); UI baut Vorher-Ausschnitt, Nachher-Clone und Begründung. |
| 4 | Alles in einer `mockup.html`; Antwort kopierbar | Pass mit Low-Bug | E2E-Build erzeugt eine Datei; M15 grün. Strukturierter Text enthält Richtung/Domain/Run, aber kein Datum trotz Tech-Design. |
| 5 | Deutsche UI-Texte, nicht-technisch verständlich | Pass mit Low-Bug | Texte sind verständlich, aber teils ASCII-transliteriert (`Rueckmeldung`, `Gewaehlte`, `gefaellt`). |

### Edge Cases
| Fall | Status | Nachweis |
|---|---|---|
| Original deutlich länger/kürzer: Slider alignt an Sektionsgrenzen | **Fail** | `sections.json` wird geladen, aber im Split-Slider nicht für Scroll-/Snap-Logik genutzt. |
| Ohne JS: statische Vorher/Nachher-Bilder sichtbar | Pass | M16 grün; `shell-proj8-fallback` wird in HTML eingebettet und nur bei `html.js` versteckt. |
| Nur eine Variante generiert: Voting-Screen entfällt automatisch | **Fail** | PROJ-7/8-Preflight verlangt weiterhin `safe/manifest.json` und `bold/manifest.json`; ein Ein-Varianten-Lauf bricht vor dem Build ab. |

### Automatisierte Tests
| Suite | Ergebnis |
|---|---|
| `MOCKUP_EXPORT_E2E=1 bash scripts/tests/mockup_export_test.sh` | 70 bestanden, 0 fehlgeschlagen |
| `bash scripts/tests/mockup_export_test.sh` | 68 bestanden, 0 fehlgeschlagen |
| `bash scripts/tests/redesign_test.sh` | 48 bestanden, 0 fehlgeschlagen |
| `bash scripts/tests/capture_test.sh` | 45 bestanden, 0 fehlgeschlagen |
| `bash scripts/tests/lh_audit_test.sh` | 38 bestanden, 0 fehlgeschlagen |
| `bash scripts/tests/brand_extract_test.sh` | 60 bestanden, 0 fehlgeschlagen |
| `bash scripts/tests/score_report_test.sh` | 50 bestanden, 0 fehlgeschlagen |
| `bash scripts/tests/ui_check_test.sh` | 48 bestanden, 0 fehlgeschlagen |

### Security / Red-Team
- Keine Serverpersistenz, keine API, keine Mandanten-/JWT-/MinIO-Fläche für PROJ-8.
- Keine externen Requests außer Bunny Fonts; M4/M5 prüfen Google-Fonts und fremde
  Assets, E2E war grün.
- Keine `fetch`, `XMLHttpRequest`, `eval` oder `document.write` in der Shell.
- `innerHTML` wird nur für die lokale Voting-Vorschau aus bereits gerendertem
  Variant-Markup genutzt; kein Critical/High-XSS-Fund, aber `cloneNode(true)` wäre
  robuster und konsistenter.

### Bugs
| ID | Severity | Titel | Beschreibung / Reproduktion | Empfehlung |
|---|---|---|---|---|
| PROJ-8-BUG-1 | **High** | Split-Slider scrollt nicht synchron und nutzt Sektionsgrenzen nicht | `chrome.js` setzt nur das Original als statischen Hintergrund (`renderSlider`, Zeilen 86–99) und baut getrennte Layer (`shell-split-after`/`shell-split-before`, Zeilen 172–175). Es gibt keinen `scroll`-Handler und keinen Snap/Align gegen `sections.json`. Gate M14 prüft nur Existenz von Slider + Viewport-Tabs (`mockup-export.sh`, Zeile 328). | Scroll-Events der Redesign-/Original-Layer synchronisieren; Sektionsgrenzen für Snap/Alignment nutzen; M14 um echte Interaktionsprüfung erweitern. |
| PROJ-8-BUG-2 | Medium | Ein-Varianten-Edge-Case wird vor dem Build blockiert | `mockup-export.sh` verlangt `safe/manifest.json` und `bold/manifest.json` sowie beide Entry-Dateien (Zeilen 77–85). Damit kann ein Lauf mit nur Safe oder nur Bold nicht bis zur Logik kommen, die Voting entfallen lassen soll. | Preflight auf mindestens eine gültige Variante umbauen; Build/Gates für fehlende zweite Variante degradieren statt abbrechen. |
| PROJ-8-BUG-3 | Low | Deutsche UI-/Mail-Texte sind teils transliteriert und Copy-Text enthält kein Datum | Sichtbar sind `Welche Richtung gefaellt Ihnen?`, `Rueckmeldung`, `Gewaehlte Richtung`; Tech-Design nennt Domain und Datum für den Mail-Text. | UI- und Copy-Texte mit Umlauten ausgeben und Datum ergänzen; Gates nicht auf ASCII-Schreibweise pinnen. |

### Bugfix-Nachtest
**2026-07-03:** Export-Degradation bei fehlenden Capture-Screenshots korrigiert.
Vor dem Fix meldeten M16/M17 zwar Warnungen, M14/M15 konnten denselben Lauf aber
hart abbrechen, weil Browser-Elemente für den Split-Slider immer erwartet wurden.
Jetzt zählt `mockup-export.sh` vorhandene `shot-{375,768,1440}.png`: ohne Shots
werden M14-M17 gelb, bei Teilsets wird M14 gelb, und nur echte Browser-/Markup-
Fehler mit vorhandenen Capture-Daten bleiben rot. Abgesichert durch den neuen
Regressionsfall `r-nocapture` in `scripts/tests/mockup_export_test.sh`.

**Nachtest-Ergebnis:** komplette lokale Suite am 2026-07-03 grün:
`brand_extract` 60/60, `capture` 45/45, `lh_audit` 38/38, `mockup_export` 68/68,
`redesign` 48/48, `score_report` 50/50, `ui_check` 48/48.

### Production-Ready Decision
**NOT READY.** Keine Critical-Security-Bugs und die automatisierten Regressionen sind
grün, aber ein High-Bug betrifft weiterhin ein zentrales Akzeptanzkriterium. Status
bleibt **In Review** bis PROJ-8-BUG-1 behoben und erneut per `/abc-qa 8` geprüft ist.

## Deployment
_To be added by /abc-deploy_
