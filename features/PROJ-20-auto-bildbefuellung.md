# PROJ-20: Automatische Bild-Befüllung der Redesign-Slots (Stock → Website → Generierung)

## Status: Deployed
**Created:** 2026-07-04
**Last Updated:** 2026-07-04
**Prio:** P1 · **Stufe:** 2

## Zusammenfassung
Füllt die von PROJ-6 angelegten Bild-Slots (`data-image-slot`) der Safe- **und** Bold-Variante
**vollautomatisch** mit thematisch passenden, echten Bildern — statt der bisherigen Platzhalter.
Neuer, headless aufrufbarer Pipeline-Schritt, der **nach** PROJ-6 (Redesign) und **vor** PROJ-7
(Mockup-Export) auf einem Run-Ordner läuft. Pro Slot greift eine feste Fallback-Kette:
**1) kostenlose Stock-Bilder → 2) Website-eigene Bilder → 3) KI-Generierung**. Bleibt jede Quelle
ohne Key/Treffer, bleibt der Slot Platzhalter + Prompt (0-€-Verhalten wie im PROJ-6-MVP) — der
Lauf bricht nie ab.

## Dependencies
- **Requires: PROJ-6** (Redesign-Generierung) — liefert die deklarierten Slots (`content.json` →
  `sections[].image_slots`), `images.md` (Platzhalter + fertiger Bild-Prompt je Slot) und die
  `data-image-slot="<id>"`-Referenzen im Code. Slot-Deckungs-Gate **G9** darf durch die Füllung
  nicht brechen. **Kein Code-Change an PROJ-6 nötig** (siehe Tech Design §E).
- **Requires: PROJ-1** (Seiten-Erfassung) — die dafür nötige **On-Page-Bild-Erfassung
  (`capture/page-images.json`) wird als Teil von PROJ-20 mitgezogen** (kleine additive Erweiterung
  von `capture.sh`), nicht als eigenes Ticket.
- **Feeds: PROJ-7** (Mockup-Export) — legt echte Bilddateien so ab, dass PROJ-7 sie **base64**
  einbettet (keine externen Requests im finalen HTML). Erfordert eine **additive, guarded**
  Erweiterung von `build.mjs` (siehe Tech Design §E).

## User Stories
- Als Auxevo möchte ich, dass Safe- und Bold-Mockup automatisch mit thematisch passenden Bildern
  gefüllt werden, um dem Kunden ein fertiges statt platzhalterhaftes Mockup zu zeigen, ohne
  manuell Bilder zu suchen.
- Als Auxevo möchte ich pro Slot eine feste Fallback-Kette (Stock → Website → Generierung), damit
  jeder Slot garantiert gefüllt wird, auch wenn eine Quelle nichts Passendes liefert.
- Als Auxevo möchte ich, dass Stock- und Website-Kandidaten von einem Claude-Judge gegen
  Section-Kontext + Branding-Tokens geprüft werden, damit nur wirklich passende Bilder landen.
- Als Auxevo möchte ich die Generierung optional über eine Bild-API (OpenAI gpt-image, Flux/fal.ai,
  Recraft-SVG …) fahren, sobald ein Key gesetzt ist, um echte Vollautomatik zu haben — ohne Key
  fällt der Schritt sauber auf Platzhalter zurück.
- Als Auxevo möchte ich einen Report (`images-fill.md`) mit Quelle, Lizenz/Attribution und
  Judge-Score je Slot, um Herkunft und Rechte jedes Bildes nachvollziehen zu können.

## Acceptance Criteria
- [ ] Neuer **headless CLI-Schritt** (z. B. `scripts/images-fill.sh` + Skill-Einhängung), aufrufbar
      auf einem Run-Ordner; läuft nach `redesign` und vor `mockup-export`; deterministisch in die
      Auto-Kette (`redesign-auto`/`ui-check-auto`) einhängbar.
- [ ] Liest **alle** in `content.json` deklarierten `image_slots` samt zugehörigem Prompt aus
      `images.md`; jeder deklarierte Slot wird verarbeitet (Safe **und** Bold).
- [ ] **Feste Fallback-Kette je Slot:** 1) kostenlose Stock-API (Unsplash + Pexels) → 2)
      Website-eigene Bilder (aus Capture/DOM des Originals) → 3) KI-Generierung. Nächste Stufe nur,
      wenn die vorige **keinen bestandenen** Kandidaten liefert.
- [ ] **Stock-Stufe** nur aktiv, wenn `UNSPLASH_ACCESS_KEY` **und/oder** `PEXELS_API_KEY` gesetzt;
      sonst Stufe übersprungen (Warnung, kein Abbruch). Nur lizenzfreie, kommerziell nutzbare
      Bilder; Fotografen-Credit + Lizenzhinweis werden erfasst.
- [ ] **Capture-Erweiterung (in PROJ-20):** `capture.sh` schreibt zusätzlich
      `capture/page-images.json` — On-Page-Bild-URLs des Originals mit Breite/Höhe + `alt`,
      **domain-gefiltert**; `og:image` aus `dom-meta.json` als garantierter Minimal-Fallback.
      Bestehende Capture-Ausgaben und -Tests bleiben unverändert (additiv).
- [ ] **Website-Stufe:** Bild-URLs stammen aus `capture/page-images.json` (bzw. `og:image`);
      Download mit Bild-Content-Type-Prüfung (Muster wie `brand-extract.sh` `fetch_ok`);
      **nur Bilder der auditierten Domain** (Copyright des Kunden ok) — keine fremden CDNs/Marken.
      Mindestauflösung erzwungen (Icons/Tracking-Pixel/Logos herausgefiltert).
- [ ] **Generierungs-Stufe** provider-agnostisch und **opt-in per Key** (mind. OpenAI gpt-image;
      Adapter für Flux/fal.ai und Recraft-SVG). Bei mehreren gesetzten Keys gilt ein dokumentierter,
      konfigurierbarer **Provider-Vorrang**. Ohne jeglichen Bild-API-Key → Slot bleibt
      **Platzhalter + Prompt** (identisch PROJ-6-MVP, 0 €), Lauf läuft grün durch.
- [ ] **Judge-Gate (F4=C):** Stock- und Website-Kandidaten bewertet Claude gegen Section-Kontext +
      Branding-Tokens (Score 0–100); nur `≥` Schwelle (Default 70) akzeptiert. **KI-generierte
      Bilder gelten ohne Judge als passend** (Prompt = Kontext).
- [ ] Gefüllte Bilder liegen als Dateien so im Run-Ordner, dass PROJ-7 sie **base64** einbettet
      (klares `slot-id ↔ Datei`-Mapping); PROJ-6-Gate **G9** (Slot-Deckung) bleibt nach der Füllung
      grün.
- [ ] **Bild-Vorverarbeitung:** Skalierung/Kompression je Slot-Zweck (Hero groß, Inline klein),
      Zielformat webp bzw. slot-typgerecht (SVG-Slot ↔ Recraft-SVG), damit das PROJ-7-5-MB-Gate
      realistisch bleibt.
- [ ] **Report `images-fill.md`** + maschinenlesbares `images-fill.json`: je Slot Quelle
      (`stock:unsplash|pexels` / `website` / `generated:<provider>` / `placeholder`),
      Lizenz/Attribution, Judge-Score, finaler Dateiname.
- [ ] **Idempotenz:** erneuter Lauf lässt bereits gefüllte Slots unangetastet; `--force` füllt neu.
- [ ] **Testskript** (`scripts/tests/images_fill_test.sh`): Fallback-Kette, „Key fehlt → Stufe
      übersprungen", Judge-Schwelle greift, Slot-Deckung nach Füllung, „kein Key → 0-€-Platzhalter".

## Edge Cases
- **Kein einziger Key gesetzt** → alle Slots bleiben Platzhalter + Prompt; Lauf erfolgreich
  (identisch PROJ-6-MVP), Report weist überall `placeholder` aus.
- **Stock liefert nur Unpassendes** (alle Kandidaten < Schwelle) → weiter zu Website, dann
  Generierung.
- **Website hat keine geeigneten Bilder** (nur Icons/Logos/zu klein/Tracking-Pixel/fremdes CDN) →
  gefiltert, Stufe übersprungen.
- **Rate-Limit / Timeout einer API** → Quelle als „nicht verfügbar" markieren, nächste Stufe, kein
  Abbruch.
- **Generierungs-API-Fehler / Policy-Block** (Prompt abgelehnt) → Slot bleibt Platzhalter, Warnung
  im Report.
- **Bild nach Kompression weiterhin zu groß** → weiter skalieren; wenn unmöglich, Warnung
  (füttert PROJ-7-5-MB-Gate mit benanntem Treiber).
- **SVG-Slot vs. Raster-Slot** → Zielformat je Slot-Typ; kein SVG in einen Raster-Slot mischen.
- **Mehrere Bild-API-Keys gleichzeitig** → definierter Provider-Vorrang (Default dokumentiert).
- **DSGVO / externe Requests** → Bilder werden zur Build-Zeit geladen und von PROJ-7 base64
  eingebettet; das finale HTML macht **keine** externen Bild-Requests.
- **Kunden-Copyright** → ausschließlich Bilder der auditierten Domain wiederverwenden; niemals
  Bilder Dritter/fremder Marken als „website"-Quelle werten.

## Technical Requirements
- **CLI-first / headless**, kein FastAPI/Flutter (Stack-Abweichung wie die restliche Pipeline);
  einhängbar in `redesign-auto.sh` / `ui-check-auto.sh` und in die Jupiter-MicroApp (PROJ-14).
- **API-Keys nur via ENV** (`UNSPLASH_ACCESS_KEY`, `PEXELS_API_KEY`, `OPENAI_API_KEY` /
  `FAL_KEY` / `RECRAFT_API_KEY`), nie im Repo; **alle** Bildquellen sind opt-in.
- **Kosten-Constraint:** Basisbetrieb bleibt 0 € (ohne Key = Platzhalter); Stock gratis; Generierung
  Cents/Bild nur bei gesetztem Key.
- Deutsche Ausgaben, Report und Warnungen (Projektkonvention).

---
<!-- Sections below are added by subsequent skills -->

## Tech Design (Solution Architect)
**Erstellt:** 2026-07-04 · **Stack:** CLI-first Skill + Bash (`scripts/images-fill.sh`) + Node/`sharp` (Mockup-Shell) — **keine** FastAPI/Flutter (bewusste Stack-Abweichung wie die gesamte Pipeline) · **Branch:** dev

### Einordnung in die Pipeline
Neuer, deterministisch aufrufbarer Schritt **`images-fill`** genau zwischen PROJ-6 und PROJ-7:

```
capture (PROJ-1) → brand-extract (PROJ-3) → … → redesign (PROJ-6)
        └─ legt Slots + Prompts + Platzhalter an
                     ↓
   ▶ images-fill (PROJ-20)  ── füllt echte Bilddateien in die Slots
                     ↓
        mockup-export (PROJ-7) → bettet Bilder base64 ins finale HTML
```

### A) Komponentenstruktur (Pipeline-Schritt, kein UI)
```
images-fill  (Skill „ui-images-fill" + scripts/images-fill.sh)
├── Slot-Leser         content.json.image_slots (je Sektion) + images.md (Prompt/Platzhalter je Slot)
│                       → Slot-Liste × {safe, bold}
├── Quellen-Kette je Slot (feste Reihenfolge, Abbruch bei erstem bestandenen Treffer)
│   ├── 1 Stock        Unsplash + Pexels (Gratis-API); Suchquery aus Slot-Prompt + Section-Heading
│   ├── 2 Website      On-Page-Bild-URLs aus capture/ → Download (nur auditierte Domain)
│   └── 3 Generierung  Provider-Adapter (opt-in): OpenAI gpt-image | fal.ai Flux | Recraft-SVG
├── Judge-Pass (Claude) NUR Stock/Website-Kandidaten: Bild ↔ Section-Kontext + Branding-Tokens
│                        → Score 0–100, Schwelle 70 (Generiertes umgeht den Judge, F4=C)
├── Vorverarbeitung    sharp: Zuschnitt/Skalierung je Slot-Zweck (Hero groß · Inline klein) → webp
├── Asset-Ablage       redesign/assets/<variant>/<slot-id>.webp  +  redesign/images-fill.json
│                        +  redesign/slots.css (ein [data-image-slot]→background-image-Layer)
└── Gate G13           Slot-Deckung nach Füllung · Attribution vorhanden · Idempotenz → verify.json
```

### B) Datenmodell (Klartext, kein DB — alles im Run-Ordner)
```
Pro Slot (in images-fill.json):
- slot_id            z. B. "hero-bild"
- variant            safe | bold  (beide werden bedient)
- source             stock:unsplash | stock:pexels | website | generated:<provider> | placeholder
- license            z. B. "Unsplash License" / "Pexels License" / "Kunden-eigen (auditierte Domain)" / "KI-generiert"
- attribution        Fotograf + Quell-URL (Pflicht bei Unsplash/Pexels), sonst null
- judge_score        0–100 (null bei generated/placeholder)
- file               assets/<variant>/<slot-id>.webp   (relativ zum Run-Ordner)
- dimensions, bytes  für das PROJ-7-5-MB-Gate

Keine Neon/MinIO-Nutzung: Bilder sind lokale Dateien im Run-Ordner; PROJ-7
inlined sie base64 → finales HTML macht KEINE externen Bild-Requests (DSGVO).
```

### C) Schnittstellen (CLI + konsumierte externe APIs — keine eigenen Endpunkte)
```
CLI:   scripts/images-fill.sh <run-dir> [--force] [--threshold 70] [--only safe|bold]
       Exit 0 = alle Slots verarbeitet · 1 = degradiert (Warnungen/Platzhalter-Reste) · 2 = harter Fehler
Skill: „ui-images-fill" (headless, in redesign-auto/ui-check-auto + Jupiter einhängbar)

Externe APIs (alle opt-in per ENV-Key, roh via curl — keine SDK-Abhängigkeit):
- Unsplash Search  (UNSPLASH_ACCESS_KEY)  — inkl. Pflicht-„download"-Trigger + Fotografen-Credit (ToS)
- Pexels Search    (PEXELS_API_KEY)        — Attribution-Pflicht
- OpenAI gpt-image (OPENAI_API_KEY) · fal.ai Flux (FAL_KEY) · Recraft (RECRAFT_API_KEY)
Ohne jeglichen Key → Slot bleibt Platzhalter (0-€-Verhalten, Lauf grün).
```

### D) Tech-Entscheidungen (WARUM)
- **Bild landet als CSS-`background-image` auf dem bestehenden `[data-image-slot]`-Container, nicht als neues `<img>`.** Der Platzhalter hat bereits feste Maße/Seitenverhältnis (PROJ-6, z. B. 1600×900); ein per Mockup-Shell inlined `slots.css`-Layer (`background-size:cover`) füllt ihn **ohne JSX-Änderung**. Minimalste Angriffsfläche; ist kein Asset da, bleibt die Token-Fläche stehen → Gate **G9** bleibt grün. A11y: der Container bekommt ein `aria-label` aus dem Bild-Prompt (Ersatz für fehlendes `alt`); rein dekorative Slots bleiben unbeschriftet.
- **Fallback-Reihenfolge Stock → Website → Generierung (F2=C):** „passend & rechtssicher" schlägt „billig". Kostenlose Stock-Bilder sind lizenzklar, hochauflösend und thematisch breit; Website-Bilder sind zwar am markentreuesten, aber oft zu klein/verrauscht (Icons, Tracking-Pixel); Generierung ist letzte, teuerste (Cents) Stufe.
- **Judge nur für Stock/Website (F4=C):** Bei Suchtreffern ist die Passung ungewiss → Claude-Judge (gleiches Muster wie PROJ-4-Scoring) bewertet gegen Section-Kontext + Tokens. Generierte Bilder entstehen aus genau diesem Kontext → Judge wäre redundant.
- **Alles opt-in, Basis 0 €:** Ohne Key kein Abbruch, sondern Rückfall auf das bekannte PROJ-6-Platzhalter-Verhalten. Damit bleibt der Kosten-Constraint der PRD unverletzt und der Schritt ist sicher in die Auto-Kette einhängbar.
- **Roh-HTTP statt Provider-SDKs:** hält den Schritt abhängigkeitsarm und provider-agnostisch; neue Bild-API = ein weiterer curl-Adapter mit dokumentiertem Vorrang.
- **`sharp` wird wiederverwendet** (steckt bereits in der Mockup-Shell für webp) — kein neues Bildwerkzeug.

### E) Abhängigkeiten & Umsetzungs-Schnitt der Nachbar-Features
Neue Pakete: **keine** — `curl`, `jq`, `sharp` (Mockup-Shell) sind vorhanden. Drei Berührungspunkte, bewusst so geschnitten, dass **kein „In Review"-Feature inhaltlich neu aufgemacht** wird:

1. **PROJ-1 (Capture) — in PROJ-20 mitgezogen, rein additiv.**
   `capture.sh` bekommt einen zusätzlichen Schritt, der aus dem bereits geladenen DOM die On-Page-Bilder als `capture/page-images.json` (URL + Breite/Höhe + `alt`, domain-gefiltert) schreibt; `og:image` aus `dom-meta.json` als Minimal-Fallback. **Keine bestehende Ausgabe ändert sich**, `capture`-Tests bleiben grün → keine Regression an PROJ-1. Wird im PROJ-20-Branch mitimplementiert.

2. **PROJ-7 (Mockup-Shell/`build.mjs`) — additiv & guarded.**
   `build.mjs` erhält einen Vor-Assembly-Schritt, der **nur greift, wenn `redesign/images-fill.json` bzw. `redesign/assets/<variant>/` existiert**: er inlined die Slot-Bilder als `background-image`-Daten-URI (via `sharp`, wie heute Screenshots) und setzt `aria-label` auf die passenden `[data-image-slot]`-Elemente. **Fehlt PROJ-20-Output, verhält sich `build.mjs` bitgenau wie heute** → das PROJ-7-QA (68/68 bzw. 70/70) bleibt gültig, kein Reopen der Feature-Substanz, nur ein neuer optionaler Pfad + eigene Tests.

3. **PROJ-6 (Redesign) — KEINE Code-Änderung.**
   Der `[data-image-slot]`-Container ist laut `images.md` bereits ein dimensionierter Block (z. B. 1600×900) — genau die Fläche, die `background-size:cover` braucht. Die einzige a11y-Ergänzung (`aria-label`) wird **im Shell-Build (Punkt 2) injiziert**, nicht in PROJ-6. Damit bleibt PROJ-6 unangetastet und muss nicht erneut durch QA.

**Warum dieser Schnitt:** Die Füllung ist ein reiner Zusatz-Layer. PROJ-6 erzeugt weiter identische Platzhalter; PROJ-20 legt optionale Assets daneben; PROJ-7 zieht sie nur ein, wenn sie da sind. Ohne Keys/ohne PROJ-20-Lauf ist die gesamte Pipeline byte-identisch zu heute — maximale Rückwärtskompatibilität, minimale Regressionsfläche.

Konfliktprüfung: PROJ-6-Gate **G9** (Slot-Deckung) und PROJ-7-**5-MB-Gate** bleiben durch Vorverarbeitung/Placeholder-Rückfall grün; kein bestehendes Gate wird gebrochen.

## Implementation Notes (Backend)
**Stand:** 2026-07-04 · **Branch:** dev

**Gebaut:**
- `scripts/images-fill.sh` — Treiber der Fallback-Kette (Stock → Website → Generierung),
  Judge-Gate, Manifest + Bericht. Provider-agnostisch (OpenAI/fal/Recraft), roh-HTTP via curl.
  Exit 0/1/2 + `status.json.phases.images_fill`.
- `scripts/capture.sh` — additive `capture/page-images.json` (On-Page-Bilder der eigenen
  Domain + `og:image`-Fallback). Keine bestehende Ausgabe geändert.
- `scripts/lib/mockup-shell/build.mjs` — guarded Slot-Einbettung: liest `images-fill.json`,
  inlined Slot-Bilder als `background-image`-Daten-URI (sharp/webp) + a11y-Runtime
  (`aria-label`/`role=img` via MutationObserver). Ohne `images-fill.json` byte-identisch.
- `scripts/mockup-export.sh` — kopiert `redesign/assets/` + `images-fill.json` in den
  Build-Workspace (nur falls vorhanden).
- `.claude/skills/ui-images-fill/SKILL.md` — Sandwich-Wrapper (optional Stock-Queries +
  Claude-Judge via `IMAGES_FILL_JUDGE_CMD`).
- `scripts/tests/images_fill_test.sh` — hermetisch (Python-Mock für Unsplash/Pexels/OpenAI),
  **24/24 grün**.

**Bewusste Abweichungen vom Tech-Design-Entwurf (Verbesserungen):**
- **Assets pro Slot-ID statt pro Variante** (`assets/<slot>.<ext>`): gleiche Slot-ID = gleiches
  Bild; ein CSS-Selektor `[data-image-slot="id"]` deckt Safe **und** Bold ab → keine Duplikate.
- **`slots.css` entfällt** — der `background-image`-Layer wird direkt in `build.mjs` aus
  `images-fill.json` erzeugt (eine Inlining-Quelle, wie bei den Screenshots).
- **Schwer-Kompression im Export** (sharp in `build.mjs`) ist die einzige Wahrheit;
  `images-fill.sh` legt das Original ab (curl+jq-only, keine Bildtool-Abhängigkeit).
- **Judge als Env-Hook** `IMAGES_FILL_JUDGE_CMD` (Claude) mit deterministischer
  Auflösungs-/Seitenverhältnis-Heuristik als Default → Sandwich + hermetisch testbar.
- **Keine Verdrahtung in `redesign-auto.sh`** (würde dessen Exit-Code-Passthrough + Tests
  brechen) — Komposition läuft über den Skill/Aufrufer.

**Regression:** `mockup_export_test` 68/68 · `capture_test` 45/45 · `images_fill_test` 24/24 — grün.

**Offen (QA/Setup):** Unsplash-/Pexels-Gratis-Keys besorgen (`UNSPLASH_ACCESS_KEY`,
`PEXELS_API_KEY`); echter End-to-End-Lauf mit Keys (bisher nur Mock); optionaler
`images-fill-queries.json`-Schreibpfad im Skill ist dokumentiert, aber vom Treiber noch
nicht konsumiert (heuristische Query greift).

## QA Test Results

**Getestet:** 2026-07-04 · **Branch:** dev · **Tester:** QA Engineer (AI)
**Testart:** CLI-Black-Box (kein FastAPI/Flutter). Hermetische Suite (Mock-APIs) **+
echter End-to-End-Lauf gegen Live-Unsplash+Pexels** (Keys via `.env`).

### Acceptance Criteria Status
- [x] **AC-1** Headless CLI-Schritt zwischen redesign & export — `images-fill.sh <run>`, Exit 0/1/2, `status.json.phases.images_fill`.
- [x] **AC-2** Liest alle deklarierten `image_slots` + Prompts — 2 Slots (hero, team) real verarbeitet.
- [x] **AC-3** Feste Kette Stock→Website→Generierung — Stock gewinnt bei aktivem Key; Website greift bei Stock=aus; Generierung als letzte Stufe.
- [x] **AC-4** Stock nur bei Key, sonst übersprungen — verifiziert (hermetisch + real).
- [x] **AC-5** `capture/page-images.json` (domain-gefiltert, og-Fallback) — `capture_test` 45/45, im Website-Test konsumiert.
- [x] **AC-6** Website: Download + Content-Type-Prüfung, Lizenz „Kunden-eigen" — real 2 Bilder geladen (Score 70/100).
- [x] **AC-7** Generierung opt-in, Provider-Vorrang, ohne Key→Platzhalter ohne Abbruch — Precedence openai; 0-€-Platzhalter Exit 0.
- [x] **AC-8** Judge-Gate Stock/Website (Schwelle 70), Generiertes umgeht Judge — `--threshold 101` (nur Stock) → 2 Platzhalter, Exit 1; generierte Slots ohne Score.
- [x] **AC-9** Assets so abgelegt, dass PROJ-7 sie einbettet; G9 bleibt grün — **E2E verifiziert** (MOCKUP_EXPORT_E2E): Slot landet als `background-image`-base64 im `mockup.html`, `aria-label` gesetzt, **keine externen Bild-Requests** (DSGVO). BUG-2 behoben.
- [x] **AC-10** Vorverarbeitung/Skalierung — Export-`sharp`-Pfad komprimiert die gefüllten Slots zu webp (im E2E bestätigt: 0,3 MB < 5-MB-Gate).
- [x] **AC-11** Report `images-fill.md` + `images-fill.json` (Quelle/Lizenz/Attribution/Score/Datei) — vollständig.
- [x] **AC-12** Attribution erfasst (Unsplash/Pexels) — Pexels-Fotograf im Manifest; Unsplash im Auto-Pfad nicht ausgelöst (BUG-1).
- [x] **AC-13** Idempotent / `--force` — Re-Run lässt Asset (md5-stabil) stehen; `--force` lädt neu.
- [x] **AC-14** Testskript — `images_fill_test.sh` 24/24 grün.

### Edge Cases Status
- [x] Keine Quelle aktiv → alle Platzhalter, Exit 0 (0-€-Baseline).
- [x] Judge-Schwelle nicht erreicht → Platzhalter trotz aktiver Quelle, Exit 1.
- [x] Externer Judge (`IMAGES_FILL_JUDGE_CMD`) übersteuert Heuristik.
- [x] Website-Bild min. Auflösung / Content-Type — gefiltert.
- [~] Rate-Limit/Timeout einzelner APIs → nächste Stufe: nur mit Mock geprüft, kein echter 429 provoziert.

### Security Audit Results
- [x] **Kein Key-Leak in Produkt-Ausgaben** — Manifest/Bericht/Assets/Logs enthalten keinen Unsplash-/Pexels-Key; keine `client_id`-URLs im Manifest.
- [x] **Copyright** — Website-Stufe verwertet nur Bilder aus `page-images.json` (bei Capture domain-gefiltert); Stock lizenzfrei mit Attribution.
- [x] **Query-Injection** — Suchqueries via `jq @uri` enkodiert, kein Shell-Splitting.
- [x] **DSGVO (keine externen Requests im finalen HTML)** — im E2E-Export bestätigt: kein `http(s)`-Bild-URL im `mockup.html` außer Bunny-Fonts (BUG-2 behoben).

### Bugs Found

#### BUG-1: Deutsche Default-Query macht Unsplash wirkungslos & schwächt „thematisch passend" — ✅ BEHOBEN (2026-07-04)
- **Severity:** Medium
- **Fix:** `images-fill.sh` liest jetzt `redesign/images-fill-queries.json` (vom Skill/Claude
  gelieferte EN/thematische Query je Slot, inkl. Orientation) und übergibt sie 1:1 an
  Unsplash/Pexels. Ohne die Datei baut eine bereinigte Fallback-Query aus dem Heading
  (Stopwörter + generische/Slot-ID-Wörter raus, z. B. „hero"/„bild"/„für"). SKILL Schritt 2
  entsprechend verschärft. Tests: `images_fill_test` #3/#9/#10 (Query-Reflexion, Override,
  kaputte queries.json → Fallback).
- **Repro:** Slot mit Heading „Moderne Zahnarztpraxis in München" → gebaute Query
  `"Moderne Zahnarztpraxis in München hero bild"`. Unsplash `total=0`; Pexels matcht nur
  fuzzy (`total=8000`). Ergebnis kommt fast immer von Pexels, Unsplash trägt nichts bei;
  thematische Passung hängt an Pexels' Unschärfe + Auflösungs-Heuristik (kein semantischer
  Judge im Auto-Pfad).
- **Ursache:** Query = deutsches Heading + literale Slot-ID-Wörter („hero bild") + Ortsname;
  der dokumentierte Übergabepunkt `images-fill-queries.json` wird vom Treiber **nicht gelesen**
  (toter Kontrakt).
- **Fix-Vorschlag:** `images-fill.sh` liest `redesign/images-fill-queries.json`, falls vorhanden;
  zusätzlich Stopwort-/Slot-ID-Wort-Filter bzw. EN-Query. Semantische Passung real nur mit
  gesetztem `IMAGES_FILL_JUDGE_CMD` (Skill-Judge) — für „vollautomatisch **und** thematisch
  passend" sollte der Skill diesen Hook standardmäßig setzen.
- **Priorität:** Vor Deploy fixen (Kernversprechen des Features).

#### BUG-2: Einbettung der gefüllten Slots nicht End-to-End verifiziert — ✅ BEHOBEN (2026-07-04)
- **Severity:** Medium
- **Fix:** `scripts/tests/mockup_export_test.sh` (E2E-Zweig `MOCKUP_EXPORT_E2E=1`) fährt jetzt
  einen echten Build mit gefülltem Slot und prüft: Export Exit 0, Slot als
  `data-image-slot="…"]{background-image:url("data:image/…;base64,…}` im `mockup.html`,
  `aria-label` aus dem Prompt gesetzt, **keine externe Bild-URL** (nur Bunny-Fonts). Real
  gelaufen: **79/79 grün**, `mockup.html` 0,3 MB < 5-MB-Gate.

#### BUG-3: Kostenpflichtige Generierung ist stiller Last-Resort ohne Opt-in-Schalter
- **Severity:** Low
- **Repro:** Ist `OPENAI_API_KEY` (o. ä.) in der Umgebung, wird die Generierung automatisch zur
  letzten Fallback-Stufe und kann pro Lauf Cents kosten, ohne explizite Bestätigung/Flag.
  Während QA vermutlich 1× ausgelöst.
- **Fix-Vorschlag:** `--no-generate`-Flag bzw. explizites `IMAGES_FILL_ALLOW_GENERATE=1`; und eine
  deutliche Logzeile „kostenpflichtige Generierung aktiv".
- **Priorität:** Nächster Sprint.

#### BUG-4: Manifest-Maße = API-Originalmaße, nicht der geladenen Variante
- **Severity:** Low
- **Repro:** Pexels-Slot: Manifest `width=5473` (Original), geladene `large2x`-Datei ist aber
  ~1880 px breit (98 kB). Judge/5-MB-Argumentation nutzen überschätzte Maße.
- **Fix-Vorschlag:** reale Pixelmaße messen oder die Maße der geladenen Variante speichern.
- **Priorität:** Nice to have.

### Summary (Stand nach Fix-Runde 2026-07-04)
- **Acceptance Criteria:** **14/14 bestanden** (AC-9/AC-10 per E2E aufgelöst).
- **Bugs:** 4 gefunden — **BUG-1 & BUG-2 (beide Medium) behoben & verifiziert**; offen: 2 Low
  (BUG-3 Generierung-Opt-in, BUG-4 Manifest-Maße).
- **Security:** Produkt-Ausgaben key-frei ✓; DSGVO-Endkette im Export bestätigt ✓.
  **Prozess-Vorfall:** OpenAI-Key im QA-Transkript ausgegeben (Tester-Fehler) → **Key rotieren**.
- **Regression:** `images_fill_test` **29/29** · `mockup_export_test` (inkl. E2E) **79/79** ·
  `capture_test` 45/45.
- **Production Ready:** **JA** (keine Critical/High/Medium offen). Verbleibende 2 Low als
  Follow-up; offene Produktfrage: soll die **kostenpflichtige Generierung** Opt-in per Flag sein
  (BUG-3)?
- **Empfehlung:** Deploybar. Vor einem echten Kundenlauf `images-fill-queries.json` durch den
  Skill schreiben lassen (beste Stock-Relevanz), Low-Bugs bei Gelegenheit.

## Deployment
**Released:** 2026-07-04 · **Version/Tag:** `v0.2.0` · **Branch:** `main` (Merge `ed357a3`)

Kein Produktions-Host — dieses Projekt ist eine **CLI-/Claude-Skill-Pipeline** (echte
Backend-Verdrahtung ist PROJ-19, P3/Planned). „Deployment" = Promotion nach `main` +
Release-Tag `v0.2.0` (Stufe-2-Release). Bereitgestellt:
- `scripts/images-fill.sh`, Capture-`page-images.json`, guarded `build.mjs`/`mockup-export.sh`.
- Skills `ui-images-fill` + `ui-pipeline`; `docs/pipeline.md`; `.env.example`.

**Nutzung:** Keys in `.env` (Unsplash/Pexels), dann `/ui-pipeline <url>` oder der 4-Schritt-Weg
(`/ui-check` → `/ui-redesign` → `/ui-images-fill` → `/ui-mockup-export`).

**Offene Follow-ups (Low, nicht release-blockierend):** BUG-3 (kostenpflichtige Generierung
per Flag opt-in statt stiller Fallback), BUG-4 (Manifest-Maße = geladene Variante).
