# ui-assemble — Portfolio-Assembler (PROJ-13)

Nutze diesen Skill, wenn aus einem Branding-Profil und einer Registry-Industrie
ein teilbares Safe+Bold-Mockup ohne bestehende Kundenwebsite gebaut werden soll.

## Ziel

Ein `runs/*-assemble-*/`-Lauf wird zu einem PROJ-7-kompatiblen Mockup:

1. `scripts/assemble.sh` erzeugt Run, Branding-Kopie, `content.json`,
   `registry-selection.safe.json`, `registry-selection.bold.json`, einen
   exportierbaren Starter-Visual-Stand und `mockup.html`.
2. Du kuratierst bei Bedarf Brief, Copy und Visuals aus dem Kunden-Briefing.
3. Du ersetzt Starter-Sektionen durch echte Registry-Kompositionen oder
   polierst generierte Fallback-Sektionen.
4. Du führst danach erneut `scripts/redesign.sh --verify <run>` und
   `scripts/mockup-export.sh <run> --force` aus.

## Start

```bash
scripts/ui-check.sh --assemble --branding <slug> --industry <tag> \
  --sections hero,trust,features,pricing,cta \
  --prompt "<kurzes Kunden-Briefing>"
```

Der Default-Sektionsplan ist `hero,trust,features,pricing,cta`. Ohne
`--no-export` läuft der Export direkt mit.

## Arbeitsregeln

- `redesign/shared/tokens.json` und `tailwind-theme.css` sind führend. Ein
  Registry-Block wird umgefärbt, nicht wegen Stilkonflikten verworfen.
- Kundentext bleibt nur im Run. Niemals Briefing oder Kundendaten in
  `registry/` schreiben.
- `registry-selection.safe.json` und `registry-selection.bold.json` entscheiden
  pro Sektion:
  - `decision: "registry"`: Block aus `redesign/registry/blocks/` importieren.
  - `decision: "generate"`: Sektion wie in `ui-redesign` neu bauen und im
    Manifest/Fallback-Hinweis kennzeichnen.
- Safe und Bold sind zwei Angebotsvarianten, nicht Original gegen Redesign.
- Keine neuen FastAPI-, DB- oder Flutter-Artefakte anlegen.

## Pflichtartefakte

Der Assembler erzeugt diese Artefakte bereits. Aktualisiere sie nur, wenn der
Starter-Stand kuratiert oder ersetzt werden soll:

- `redesign/brief.md`
- `redesign/shared/content.json`
- `redesign/compare.json`
- `redesign/images.md`
- `redesign/safe/App.jsx`, `manifest.json`, `package.json`
- `redesign/bold/App.jsx`, `manifest.json`, `package.json`

Danach:

```bash
scripts/redesign.sh --verify <run>
scripts/mockup-export.sh <run> --force
```

## Fallback-Hinweis

Wenn eine Sektion generiert wurde, muss sie im Ergebnis nachvollziehbar bleiben:
`registry-selection.*.json` enthält `stats.generate`; zusätzlich im
`manifest.json` der Variante unter `sections[].source = "generated"` markieren.
