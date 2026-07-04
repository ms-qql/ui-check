---
name: ui-mockup-export
description: Stufe-2-Mockup-Export (PROJ-7) — bündelt die Redesign-Varianten (Safe + Bold) eines abgeschlossenen ui-redesign-Laufs zu EINER self-contained, offline lauffähigen HTML-Datei (CSS/JS inline, Bilder base64, Vorher/Nachher-Voting). Nutze diesen Skill, wenn der Nutzer "ui-mockup-export <run-dir|domain>", "mockup export", "mockup-html erzeugen", "PROJ-7 fahren", "Redesign als HTML exportieren" oder nach einem Redesign eine teilbare Vorschau-Datei möchte. Rein deterministisch (kein LLM-Anteil); headless aufrufbar (Jupiter/PROJ-14).
---

# UI-Mockup-Export (PROJ-7)

Bündelt die zwei Redesign-Varianten aus **PROJ-6** (`redesign/safe` + `redesign/bold`)
zu **einer** statischen HTML-Datei — CSS/JS inline, Bilder base64, Fonts via Bunny,
Vorher/Nachher-Voting + Split-Slider. **Offline lauffähig, teilbar.**

Der Skill ist ein dünner Wrapper: die gesamte Arbeit macht der deterministische
Treiber **`scripts/mockup-export.sh`** (Pre-Render → Client-Bundle → Tailwind →
Assemble → Publish-Gates → Promote). Kein Judge, kein LLM-Anteil — du löst nur den
Lauf aus, deutest die Exit-Codes und berichtest auf Deutsch.

## Aufruf

```
/ui-mockup-export <run-dir | domain | run-id>
```

- **`<run-dir>`** — Pfad eines abgeschlossenen Stufe-2-Laufs
  (`runs/YYYY-MM-DD-<domain>-NNN/` mit `redesign/verify.json` **ohne rote Gates**).
- Alternativ genügt ein **Domain- oder Run-ID-Fragment** (z. B. `Auxevo`,
  `auxevo.tech`, `2026-07-04-auxevo.tech-001`) — dann zuerst den Run-Ordner auflösen
  (siehe Schritt 1). Fehlt das Argument ganz und es gibt genau einen Kandidaten mit
  fertigem Redesign, diesen nehmen; bei mehreren die Treffer auflisten und nachfragen.

## Ablauf (Schritt für Schritt)

### 1. Run-Ordner auflösen

Wenn das Argument kein existierender Ordner ist, im `runs/`-Verzeichnis suchen
(case-insensitive, jüngster zuerst) und auf **genau einen** Lauf mit vorhandenem
`redesign/verify.json` eingrenzen:

```bash
ls -1d runs/*<fragment>*/ 2>/dev/null   # Treffer; bei mehreren nach mtime sortieren
```

- **0 Treffer** → dem Nutzer melden, dass kein passender Lauf existiert, und auf
  `/ui-redesign <run-dir>` (bzw. `/ui-check <url>`) verweisen. Stoppen.
- **> 1 Treffer** → Kandidaten (Run-ID + Datum) auflisten und um Auswahl bitten.
- **1 Treffer** → als `<run-dir>` verwenden.

### 2. Export fahren

```bash
scripts/mockup-export.sh "<run-dir>"
```

Nur bei einem ausdrücklichen erneuten Export (`mockup.html` existiert schon und der
Nutzer will neu bauen) **`--force`** anhängen — sonst bricht der INIT-Gate bewusst ab.

### 3. Exit-Code deuten + berichten

| Exit | Bedeutung | Verhalten |
|---|---|---|
| **0** | ok — alle Publish-Gates grün | Erfolg melden: Pfad `<run-dir>/mockup.html` + Größe. |
| **1** | degradiert — nur gelbe Warn-Gates | Datei ist nutzbar; die **konkreten Warnungen** aus der Ausgabe (bzw. `<run-dir>/mockup/gates.json`) nennen und einordnen. |
| **2** | Abbruch — fehlender/roter PROJ-6-Stand, Build-Fehler oder rote Pflicht-Gates | Die Fehlermeldung des Treibers auf Deutsch weitergeben. Häufig: Redesign unvollständig/rote Gates → erst `/ui-redesign` bzw. `scripts/redesign.sh --verify` fahren. Nicht selbst am Build vorbeimurksen. |

Danach kurz zusammenfassen: Datei-Pfad, Größe, was drin ist (interaktive Ansicht mit
Safe + Bold, Vorher/Nachher-Voting, Vergleichs-Begründungen je Sektion, „Antwort
kopieren", No-JS-Baseline), offene Warnungen. Öffnen-Hinweis:
`xdg-open <run-dir>/mockup.html` bzw. Datei im Browser.

## Voraussetzungen (prüft der Treiber selbst)

`node` (≥ v20), `npm`, `jq`, `agent-browser` müssen vorhanden sein — fehlt etwas,
bricht der Treiber mit Exit 2 und einer klaren Meldung ab (an den Nutzer weitergeben).
Dependencies werden einmalig pro Set installiert und repo-übergreifend in
`~/.cache/ui-check/` gecacht.

## Headless (Jupiter / PROJ-14)

Bei vollständigem Run-Ordner keine Rückfragen. Der Treiber schreibt `phases.mockup`
in `status.json` (`ok|degraded|failed`); Exit-Codes 0/1/2 steuern den Aufrufer.

## Referenzen

- Treiber + Gates: `scripts/mockup-export.sh` · Build-Harness: `scripts/lib/mockup-shell/`
- Kontrakte/Artefakte: `scripts/README.md`
- Vorstufe (Pflicht-Input): `/ui-redesign` (PROJ-6) · Feature-Spec: `features/PROJ-7-mockup-export-html.md`
