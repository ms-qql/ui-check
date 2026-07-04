---
name: ui-pipeline
description: Ein-Knopf-Gesamtlauf der UI-Check-Pipeline — von einer Website-URL bis zur teilbaren Mockup-HTML mit echten Bildern. Fährt nacheinander ui-check (Stufe-1-Audit) → ui-redesign (Safe+Bold) → ui-images-fill (Bild-Slots füllen, PROJ-20) → ui-mockup-export (self-contained HTML, PROJ-7) auf demselben Run-Ordner. Nutze diesen Skill, wenn der Nutzer "ui-pipeline <url>", "kompletter Lauf für <url>", "URL rein Mockup raus", "mach die ganze Pipeline für <url>", "Audit + Redesign + Bilder + Export in einem" möchte. Bricht bei hartem Fehler eines Schritts kontrolliert ab und berichtet, wo er steht.
---

# UI-Pipeline (Gesamtlauf)

Orchestriert die vier Stufen-Skills **in fester Reihenfolge auf einem Run-Ordner**:

```
/ui-check <url>  →  /ui-redesign <run>  →  /ui-images-fill <run>  →  /ui-mockup-export <run>
   Stufe-1-Audit     Safe + Bold           Bild-Slots füllen         teilbare mockup.html
```

Du (Claude) rufst die einzelnen Skills der Reihe nach auf und reichst den **Run-Ordner**
weiter. Dieser Skill re-implementiert nichts — er delegiert an die bestehenden Skills und
kümmert sich um Reihenfolge, Run-Ordner-Weitergabe und Abbruch-Logik.

## Aufruf

```
/ui-pipeline <url> [Nutzer-Prompt / Fokus]
```

- `<url>` — die zu auditierende, öffentlich erreichbare Website.
- optionaler Fokus (z. B. „Fokus auf Terminbuchung") wird an ui-redesign durchgereicht.

## Ablauf

### 0. Keys laden (einmal)
```bash
set -a; [ -f .env ] && . ./.env; set +a
```
Damit sieht der Bild-Schritt die Stock-/Generierungs-Keys. Ohne Keys läuft die Pipeline
trotzdem — die Bild-Slots bleiben Platzhalter.

### 1. Stufe-1-Audit — Skill `ui-check`
Führe den **ui-check**-Skill mit `<url>` aus (`.claude/skills/ui-check/SKILL.md`).
- **Merke dir den erzeugten Run-Ordner** `runs/JJJJ-MM-TT-<domain>-NNN/` (aus der Skill-Ausgabe;
  im Zweifel der jüngste `runs/*<domain>*`-Ordner).
- Bricht ui-check ab (Exit 2 — nicht erreichbar / Bot-Schutz / kein HTML): **Pipeline hier
  stoppen**, dem Nutzer den Grund nennen, nichts Weiteres fahren.

### 2. Redesign — Skill `ui-redesign`
Führe **ui-redesign** auf dem Run-Ordner aus (optionalen Fokus als Nutzer-Prompt mitgeben).
- Ergebnis: `redesign/safe/` + `redesign/bold/` + `redesign/images.md`, Gates grün/gelb.
- Rote Pflicht-Gates (Exit 2): stoppen und berichten; gelbe Warnungen: weiterlaufen, vermerken.

### 3. Bilder — Skill `ui-images-fill` (PROJ-20)
Führe **ui-images-fill** auf dem Run-Ordner aus. Wenn Stock aktiv ist, schreibe dabei — wie im
Skill beschrieben — die englischen Suchqueries nach `redesign/images-fill-queries.json`, bevor
der Treiber läuft. Exit 0/1 beide ok (1 = einzelne Slots blieben Platzhalter); nur Exit 2 stoppt.

### 4. Export — Skill `ui-mockup-export` (PROJ-7)
Führe **ui-mockup-export** auf dem Run-Ordner aus → `mockup.html`.
- Existiert schon eine `mockup.html`, mit `--force` bzw. laut Skill neu bauen.

### 5. Abschlussbericht (Deutsch)
Fasse zusammen:
- Run-Ordner + `mockup.html`-Pfad (im Browser öffnen / verschicken),
- Design-Score aus Stufe 1,
- was Safe vs. Bold unterscheidet,
- je Bild-Slot: Quelle + Lizenz/Attribution (aus `redesign/images-fill.json`), welche Slots
  Platzhalter blieben,
- offene Warnungen der Einzelschritte.

## Abbruch-Regeln (Kurz)
- **Harter Fehler (Exit 2) in Schritt 1, 2 oder 4** → Pipeline stoppen, Zustand + Grund nennen,
  den bereits erreichten Run-Ordner angeben (Wiederaufsetzen ab dem nächsten Skill ist möglich).
- **Schritt 3 Exit 1** (Platzhalter-Reste) ist **kein** Abbruch — weiter zum Export, im Bericht vermerken.
- Nie einen Schritt überspringen oder die Reihenfolge ändern.

## Headless-Hinweis
Für vollautomatische, nicht-interaktive Läufe (Jupiter/PROJ-14) gibt es die
`scripts/*-auto.sh`-Treiber. Dieser Skill ist der **interaktive** Ein-Knopf-Weg.
Siehe auch `docs/pipeline.md`.
