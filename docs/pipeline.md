# UI-Check Pipeline — Ende-zu-Ende (URL → teilbares Mockup)

Kompletter Weg von einer Website-URL zu einer teilbaren HTML-Vorschau mit echten
Bildern. Vier Skill-Aufrufe in fester Reihenfolge, immer auf **denselben Run-Ordner**.

## Skills sind jetzt global installiert

Alle acht UI-Check-Skills liegen seit 2026-07-05 nicht mehr projektlokal unter
`.claude/skills/`, sondern **global** unter `~/.claude/skills/<name>/` — sie sind damit
in **jeder** Claude-Code-Sitzung per Slash-Command aufrufbar, unabhängig davon, in
welchem Projektverzeichnis Claude Code gerade läuft. Inhaltlich bleiben sie aber an
dieses Repo gebunden (Treiber-Skripte, `runs/`, `registry/`, `rubrics/`, `.env` liegen
nur hier) — jeder Skill stellt seinen Bash-Befehlen deshalb ein
`cd /home/dev/projects/design/ui-check &&` voran.

## Alle Skills im Überblick

| Skill | Rolle |
|---|---|
| `/ui-check <url>` | Stufe-1-Audit (PROJ-5): Screenshots, Lighthouse, Branding, Design-Score |
| `/ui-redesign <run-dir>` | Stufe-2-Redesign (PROJ-6): Safe- & Bold-Variante + Bild-Slots |
| `/ui-images-fill <run-dir>` | Bild-Slots befüllen (PROJ-20): Stock → Website → KI-Generierung |
| `/ui-mockup-export <run-dir>` | Self-contained `mockup.html` bauen (PROJ-7) |
| `/ui-pipeline <url>` | Fährt die vier Schritte oben automatisch nacheinander |
| `/ui-template-ingest <url>` | Externes Template clean-room in die Komponenten-Registry (PROJ-11) aufnehmen |
| `/ui-block-ingest <name\|url>` | Einzelnen kostenlosen shadcnblocks-Block in die Registry importieren (PROJ-11) |
| `/ui-recycle <run-dir>` | Portfoliowürdige Sektionen eines Redesign-Laufs in die Registry übernehmen (PROJ-11) |

Die ersten fünf bilden den **Kern-Flow** unten (URL → Mockup); die letzten drei
speisen unabhängig davon die **Komponenten-Registry** (`registry/`, PROJ-11) — entweder
aus externen Templates/Blocks oder aus guten Redesign-Läufen heraus.

## Einmalig: Setup

API-Keys in `.env` (Repo-Root, gitignored) eintragen — Vorlage: `.env.example`.

```
UNSPLASH_ACCESS_KEY=…   # Access Key (Client-ID), nicht der Secret Key
PEXELS_API_KEY=…
# optional für KI-Generierung als letzter Fallback:
OPENAI_API_KEY=…        # bzw. FAL_KEY / RECRAFT_API_KEY
```

Ohne Keys läuft alles trotzdem — die Bild-Slots bleiben dann Platzhalter (0 €).

## Der Flow

| # | Skill | Eingabe | Ergebnis |
|---|---|---|---|
| 1 | `/ui-check <url>` | die URL | Stufe-1-Audit: Screenshots, Lighthouse, Branding, Design-Score → **Run-Ordner** `runs/JJJJ-MM-TT-<domain>-NNN/` |
| 2 | `/ui-redesign <run-dir>` | Run-Ordner aus 1 | Safe- & Bold-Variante + Bild-**Slots** (Platzhalter) + Prompts |
| 3 | `/ui-images-fill <run-dir>` | derselbe Run-Ordner | **PROJ-20**: füllt die Slots mit echten Bildern (Stock → Website → Generierung) |
| 4 | `/ui-mockup-export <run-dir>` | derselbe Run-Ordner | **PROJ-7**: eine self-contained `mockup.html` (Bilder base64, Vorher/Nachher-Voting) |

Oder in **einem** Schritt: `/ui-pipeline <url>` fährt 1–4 automatisch nacheinander.

## Beispiel

```
/ui-check auxevo.tech
# → runs/2026-07-04-auxevo.tech-001
/ui-redesign     runs/2026-07-04-auxevo.tech-001
/ui-images-fill  runs/2026-07-04-auxevo.tech-001
/ui-mockup-export runs/2026-07-04-auxevo.tech-001
# → runs/2026-07-04-auxevo.tech-001/mockup.html  (im Browser öffnen / verschicken)
```

## Wichtig

- **Reihenfolge ist Pflicht** — jeder Schritt baut auf dem vorigen auf; immer derselbe Run-Ordner.
- **Bilder (Schritt 3): den Skill nehmen, nicht `scripts/images-fill.sh` direkt.** Der Skill
  schreibt vorher englische Suchqueries je Slot (`images-fill-queries.json`) — sonst nutzt der
  Treiber nur eine schwache deutsche Fallback-Query (Unsplash findet damit oft nichts). Der Skill
  lädt außerdem die `.env` selbst.
- **KI-Generierung** (OpenAI/fal/Recraft) springt in Schritt 3 nur an, wenn Stock **und** Website
  nichts Passendes ≥ Schwelle liefern — bezahlter Last-Resort (Cents/Bild).
- **DSGVO**: Das finale `mockup.html` bettet alle Bilder base64 ein → keine externen Requests
  (außer Bunny-Fonts). Nur Bilder der auditierten Domain werden wiederverwendet; Stock ist lizenzfrei.

## Ergebnis-Dateien im Run-Ordner

```
runs/<lauf>/
├── capture/            Screenshots, page-images.json, snapshot, sections
├── scores.json         Design-Score (Stufe 1)
├── report.md           Audit-Report
├── branding/           Tokens, Tailwind-Theme, Logo
├── redesign/
│   ├── safe/  bold/     die zwei Varianten
│   ├── images.md        Slot-Prompts
│   ├── images-fill.json Herkunft/Lizenz/Attribution je gefülltem Bild
│   └── assets/          die eingesetzten Bilder
└── mockup.html          teilbare Endvorschau
```

## Fehlerbilder (Kurz)

- **Schritt 1 bricht mit Bot-Schutz/kein HTML ab** → Seite nicht öffentlich erreichbar; kein Umgehen.
- **Schritt 3 „0 gefüllt, nur Platzhalter"** → keine Keys geladen bzw. nichts ≥ Schwelle; Lauf bleibt
  gültig, Slots bleiben Platzhalter.
- **Schritt 4 „mockup.html existiert bereits"** → erneuter Export mit `--force` bzw. der Skill fragt.
- **Headless (Jupiter/PROJ-14)**: dafür gibt es die `scripts/*-auto.sh`-Treiber; im interaktiven
  Gebrauch die Skills oben nutzen.
