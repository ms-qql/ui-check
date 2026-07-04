---
name: ui-images-fill
description: Stufe-2-Bild-Befüllung (PROJ-20) — füllt die von ui-redesign (PROJ-6) angelegten Bild-Slots eines Laufs vollautomatisch mit thematisch passenden Bildern über die feste Kette Stock (Unsplash/Pexels) → Website-eigene Bilder → KI-Generierung (OpenAI/Flux/Recraft), mit Claude-Judge-Gate für Stock/Website. Nutze diesen Skill, wenn der Nutzer "ui-images-fill <run-dir>", "Bilder in Safe/Bold einsetzen", "Bild-Slots füllen", "PROJ-20 fahren" oder nach einem Redesign echte Bilder statt Platzhalter möchte. Läuft ZWISCHEN ui-redesign (PROJ-6) und ui-mockup-export (PROJ-7). Ohne API-Keys bleibt es beim 0-€-Platzhalter-Verhalten. Headless aufrufbar (Jupiter/PROJ-14).
---

# UI-Images-Fill (PROJ-20)

Füllt die Bild-Slots (`data-image-slot`) der Redesign-Varianten aus **PROJ-6** mit
echten Bildern. Feste Fallback-Kette je Slot:

1. **Stock** — Unsplash + Pexels (Gratis-API, lizenzfrei/kommerziell) · opt-in per Key
2. **Website** — kunden-eigene Bilder der auditierten Domain (`capture/page-images.json`)
3. **Generierung** — OpenAI gpt-image / fal.ai Flux / Recraft-SVG · opt-in per Key

Stock- und Website-Kandidaten durchlaufen ein **Judge-Gate** (thematische Passung
gegen Section-Kontext + Branding-Tokens); generierte Bilder gelten ohne Judge als
passend. **Ohne jeglichen Key** bleibt jeder Slot Platzhalter → 0-€-Baseline, Lauf
bricht nie ab. Position in der Pipeline: **ui-redesign → `ui-images-fill` → ui-mockup-export**.

Der Skill ist ein dünner Sandwich-Wrapper: der deterministische Treiber
**`scripts/images-fill.sh`** macht Fetch/Kette/Vorverarbeitung/Manifest; du (Claude)
lieferst optional zwei Dinge, die die Bildqualität heben — bessere Stock-Queries und
den semantischen Judge.

## Aufruf

```
/ui-images-fill <run-dir | domain | run-id>
```

Run-Ordner-Auflösung wie bei `ui-mockup-export` (Fragment → `runs/*<fragment>*/` mit
vorhandenem `redesign/shared/content.json`; bei mehreren nachfragen).

## Ablauf

### 0. API-Keys laden
Der Treiber liest die Keys aus der Umgebung. Lade die `.env` des Projekts (gitignored),
damit Stock/Generierung greifen — überschreibt keine bereits gesetzten Variablen:
```bash
set -a; [ -f .env ] && . ./.env; set +a
```

### 1. Voraussetzungen prüfen
- `<run-dir>/redesign/shared/content.json` + `redesign/images.md` müssen existieren
  (PROJ-6 gelaufen). Sonst: auf `/ui-redesign` verweisen.
- Verfügbare Quellen aus der Umgebung ableiten (welche Keys gesetzt sind):
  `UNSPLASH_ACCESS_KEY`, `PEXELS_API_KEY`, `OPENAI_API_KEY` / `FAL_KEY` /
  `RECRAFT_API_KEY`. Fehlt alles → dem Nutzer sagen, dass ohne Key nur Website
  (falls `capture/page-images.json` vorhanden) bzw. Platzhalter greift.

### 2. (bei aktivem Stock: DRINGEND empfohlen) Stock-Queries schärfen
Die deutschen Prompts/Headings sind für Stock-Suchen schwach — **Unsplash ist
englisch-zentriert und liefert für deutsche Queries oft 0 Treffer**. Wenn Stock aktiv
ist, schreibe daher je Slot eine knappe **englische** Suchquery nach
`<run-dir>/redesign/images-fill-queries.json`:

```json
{ "hero-bild": {"query": "modern dental practice bright reception", "orientation": "landscape"},
  "team-foto": {"query": "professional medical team portrait white coats", "orientation": "squarish"} }
```

Basis: Section-Heading + Bild-Prompt, ins Englische übersetzt, ohne Füllwörter. **Der
Treiber liest diese Datei und übergibt die Query 1:1 an Unsplash/Pexels.** Fehlt sie,
baut er nur eine bereinigte Fallback-Query aus dem deutschen Heading (Stopwörter +
Slot-Wörter raus) — funktioniert, ist aber deutlich schwächer.

### 3. (optional, empfohlen) Als Judge fungieren
Setze `IMAGES_FILL_JUDGE_CMD` auf einen Befehl, der **ein Kandidat-JSON auf stdin**
liest (`{tmp,source,width,height,attribution,target,prompt}`) und **einen Score 0–100**
auf stdout schreibt — so bewertest du die thematische Passung (Bild ↔ Prompt/Branding)
statt der reinen Auflösungs-Heuristik. Ohne den Env-Hook nutzt der Treiber die
deterministische Heuristik (Auflösung + Seitenverhältnis, Schwelle 70).

### 4. Treiber ausführen
```bash
scripts/images-fill.sh <run-dir> [--force] [--threshold 70] [--only safe|bold]
```
- **Exit 0** — alle Slots verarbeitet (gefüllt oder bewusst Platzhalter mangels Quelle).
- **Exit 1** — degradiert: Platzhalter-Reste trotz aktiver Quelle oder API-Fehler
  (Vermerke in `images-fill.json.notes`). Lauf bleibt nutzbar.
- **Exit 2** — Abbruch: kein Redesign / ungültige Argumente.

### 5. Ergebnis + Bericht
- `<run-dir>/redesign/assets/<slot>.<ext>` — gefüllte Bilder
- `<run-dir>/redesign/images-fill.json` — Manifest (Quelle, Lizenz, Attribution, Score, Datei)
- `<run-dir>/redesign/images-fill.md` — menschenlesbarer Bericht

Auf Deutsch berichten: je Slot Quelle + Lizenz/Attribution + Score; welche Slots
Platzhalter blieben und warum; **Lizenz-Hinweis** (Unsplash/Pexels verlangen
Fotografen-Credit — steht im Manifest). Verweis: weiter mit **PROJ-7**
(`/ui-mockup-export`), das die Bilder base64 ins finale HTML einbettet.

## Kosten & DSGVO
- Basisbetrieb 0 € (ohne Key = Platzhalter). Stock gratis. Generierung Cents/Bild nur
  bei gesetztem Key.
- Nur Bilder der **auditierten Domain** werden wiederverwendet (Kunden-Copyright);
  Stock ist lizenzfrei. Das finale HTML macht **keine** externen Bild-Requests
  (PROJ-7 bettet base64 ein).

## Headless (Jupiter / PROJ-14)
Bei vollständigen Parametern keine Rückfragen. `status.json` führt
`phases.images_fill` (`ok|degraded`); Exit-Codes 0/1/2 steuern den Aufrufer.
