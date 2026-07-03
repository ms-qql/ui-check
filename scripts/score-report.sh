#!/usr/bin/env bash
#
# score-report — Design-Scoring & Report (PROJ-4) für die UI-Check-Pipeline
#
# Deterministische Scoring-/Report-Engine: mergt die Claude-Judge-Ausgabe
# (judge.json — visuell / KI-Generik / Conversion) mit den Lighthouse- und
# Branding-Dimensionen zum zentralen Stufe-1-Deliverable:
#   <run-dir>/scores.json   maschinenlesbar (5 Dimensionen + Cai-Teilscores +
#                           Gesamtscore + Gewichte + Rubrik-Version + Befunde)
#   <run-dir>/report.md     deutsch, kundentauglich (Score-Panel, Befunde,
#                           Empfehlungen, Benchmark, Meta)
#
# Der Judge ist Claude selbst (PROJ-5 erzeugt judge.json anhand rubrics/); dieses
# Skript bewertet NICHT, es rechnet & rendert deterministisch — damit reproduzierbar.
#
# Nutzung:
#   score-report.sh <run-dir> [--judge <file>] [--industry <tag>]
#                             [--weights v,s,p,a,c]
#
#   <run-dir>       Run-Ordner aus PROJ-1 (mit meta.json). Pflicht.
#   --judge <file>  Judge-Ausgabe (Default: <run-dir>/judge.json).
#   --industry <t>  Industrie-Tag für Benchmark/runs.jsonl (Default: "unknown").
#   --weights       Gewichte visuell,slop,performance,a11y,conversion
#                   (Default 25,15,15,15,30). Nicht messbare Dims werden renormiert.
#
# Exit-Codes:
#   0  Report erzeugt, alle 5 Dimensionen messbar
#   1  Report erzeugt, aber degradiert (≥1 Dimension „nicht messbar" ODER
#      Befund-Minimum unterschritten) — Pipeline läuft weiter
#   2  Input-Gate/intern (kein Capture, kein/ungültiges judge.json,
#      Rubrik-Version-Konflikt, ungültige Argumente, fehlendes Tool)
#
# Alle Meldungen auf Deutsch.

set -uo pipefail

die_intern() { echo "✗ $*" >&2; exit 2; }

# ── Argumente ──────────────────────────────────────────────────────────────
RUN_DIR=""
JUDGE=""
INDUSTRY="unknown"
WEIGHTS="25,15,15,15,30"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --judge)    JUDGE="${2:-}"; shift 2 ;;
    --industry) INDUSTRY="${2:-}"; shift 2 ;;
    --weights)  WEIGHTS="${2:-}"; shift 2 ;;
    -h|--help)  sed -n '2,38p' "$0"; exit 0 ;;
    -*)         die_intern "Unbekannte Option: $1" ;;
    *)          [[ -z "$RUN_DIR" ]] && RUN_DIR="$1" || die_intern "Zu viele Argumente: $1"; shift ;;
  esac
done

[[ -n "$RUN_DIR" ]] || die_intern "Kein Run-Ordner angegeben. Nutzung: score-report.sh <run-dir> [--judge <file>]"
[[ -d "$RUN_DIR" ]] || die_intern "Run-Ordner nicht gefunden: $RUN_DIR"
command -v jq >/dev/null 2>&1 || die_intern "jq nicht gefunden."

# Gewichte validieren.
IFS=',' read -r W_VIS W_SLOP W_PERF W_A11Y W_CONV <<<"$WEIGHTS"
for w in "$W_VIS" "$W_SLOP" "$W_PERF" "$W_A11Y" "$W_CONV"; do
  [[ "$w" =~ ^[0-9]+$ ]] || die_intern "--weights erwartet 5 Zahlen (v,s,p,a,c), war: $WEIGHTS"
done

# ── Input-Gate: Capture (Pflicht) ──────────────────────────────────────────
META="$RUN_DIR/meta.json"
[[ -s "$META" ]] || die_intern "Capture fehlt ($META) — PROJ-1 zuerst laufen lassen (Capture ist Pflicht)."
cap_status="$(jq -r '.status // "unknown"' "$META" 2>/dev/null)"
[[ "$cap_status" == "ok" ]] || die_intern "Capture-Status ist '$cap_status' (nicht 'ok') — keine Grundlage zum Bewerten."

# ── Input-Gate: Judge (Pflicht) ────────────────────────────────────────────
[[ -z "$JUDGE" ]] && JUDGE="$RUN_DIR/judge.json"
[[ -s "$JUDGE" ]] || die_intern "Judge-Ausgabe fehlt ($JUDGE) — PROJ-5 erzeugt sie aus rubrics/. Kontrakt: siehe scripts/README.md."
jq -e . "$JUDGE" >/dev/null 2>&1 || die_intern "Judge-Ausgabe ist kein gültiges JSON: $JUDGE"

# Rubrik-Version bestimmen + Abgleich (Benchmark-Vergleichbarkeit).
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
RUBRIC_VERSION="$(cat "$ROOT/rubrics/VERSION" 2>/dev/null | head -1)"
[[ -n "$RUBRIC_VERSION" ]] || die_intern "rubrics/VERSION fehlt oder leer."
JUDGE_RV="$(jq -r '.rubric_version // ""' "$JUDGE")"
if [[ -n "$JUDGE_RV" && "$JUDGE_RV" != "$RUBRIC_VERSION" ]]; then
  die_intern "Rubrik-Version-Konflikt: judge.json='$JUDGE_RV' ≠ rubrics/VERSION='$RUBRIC_VERSION'. Judge mit aktueller Rubrik neu laufen lassen."
fi

# Pflicht-Judge-Felder grob prüfen.
jq -e '.visual.score != null and .ki_score != null and .conversion != null' "$JUDGE" >/dev/null 2>&1 \
  || die_intern "judge.json unvollständig: benötigt .visual.score, .ki_score und .conversion (Cai-Teilscores)."

# ── Optionale Eingänge ─────────────────────────────────────────────────────
LH="$RUN_DIR/lighthouse/lh-summary.json"
BR_META="$RUN_DIR/branding/branding-meta.json"
BR_RAW="$RUN_DIR/branding/raw-extract.json"
EMPTY="$(mktemp)"; echo 'null' > "$EMPTY"
LH_SRC="$EMPTY";      [[ -s "$LH" ]]      && jq -e '.status=="ok"' "$LH" >/dev/null 2>&1 && LH_SRC="$LH"
BRM_SRC="$EMPTY";     [[ -s "$BR_META" ]] && BRM_SRC="$BR_META"
BRR_SRC="$EMPTY";     [[ -s "$BR_RAW" ]]  && BRR_SRC="$BR_RAW"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RUN_ID="$(basename "$RUN_DIR")"
GENERATOR_VERSION="1.0"

# URL-Hash (keine Klardaten in runs.jsonl).
FINAL_URL="$(jq -r '.final_url // .url // ""' "$META")"
URL_HASH="$(printf '%s' "$FINAL_URL" | sha256sum 2>/dev/null | cut -c1-16)"
[[ -n "$URL_HASH" ]] || URL_HASH="$(printf '%s' "$FINAL_URL" | cksum | cut -d' ' -f1)"

# ── Benchmark vorbereiten (vor dem Anhängen des aktuellen Laufs) ────────────
RUNS="$ROOT/data/runs.jsonl"
BENCH="null"
if [[ -s "$RUNS" ]]; then
  # BUG-5: zeilenweise robust parsen (fromjson?) — eine kaputte Zeile darf den
  #        Benchmark nicht kippen. BUG-2: nur gleiche rubric_version vergleichen
  #        (sonst mischt der Durchschnitt inkompatible Rubrik-Generationen).
  BENCH="$(jq -R 'fromjson?' "$RUNS" 2>/dev/null | jq -s -c \
      --arg tag "$INDUSTRY" --arg rv "$RUBRIC_VERSION" '
      map(select(.industry_tag == $tag
                 and .rubric_version == $rv
                 and (.total|type=="number")))
      | if length >= 10
        then { industry_tag: $tag, rubric_version: $rv, n: length,
               average_total: ((map(.total)|add / length)|round) }
        else null end' 2>/dev/null)"
  [[ -z "$BENCH" ]] && BENCH="null"
fi

# ── scores.json bauen ──────────────────────────────────────────────────────
SCORES="$RUN_DIR/scores.json"
jq -n \
  --slurpfile judge "$JUDGE" \
  --slurpfile lh "$LH_SRC" \
  --slurpfile brm "$BRM_SRC" \
  --slurpfile brr "$BRR_SRC" \
  --arg url "$(jq -r '.url // ""' "$META")" \
  --arg final_url "$FINAL_URL" \
  --arg run_id "$RUN_ID" \
  --arg ts "$TIMESTAMP" \
  --arg rv "$RUBRIC_VERSION" \
  --arg genv "$GENERATOR_VERSION" \
  --arg industry "$INDUSTRY" \
  --arg suspicion "$(jq -r '.content_suspicion // ""' "$META")" \
  --argjson wv "$W_VIS" --argjson ws "$W_SLOP" --argjson wp "$W_PERF" \
  --argjson wa "$W_A11Y" --argjson wc "$W_CONV" \
  --argjson bench "$BENCH" '
  def clamp: if . < 0 then 0 elif . > 100 then 100 else . end;
  def rnd: (.*1|round);
  # BUG-1: nur echte Zahlen zulassen — String/anderer Typ ⇒ null (nicht messbar),
  # statt in jq still zu 100 zu clampen ("72" > 100 ist in jq true).
  def num: if type == "number" then . else null end;
  # BUG-4: ganzzahlige Prozentgewichte, die exakt auf 100 summieren
  # (Largest-Remainder / Hare-Quote statt unabhängigem Runden).
  def renorm($keys; $w; $wsum):
    if ($keys|length) == 0 or $wsum == 0 then {}
    else
      ([ $keys[] | { k: ., f: ($w[.] / $wsum * 100) } ]) as $raw
      | ([ $raw[] | (.f|floor) ] | add) as $flsum
      | (100 - $flsum) as $rem
      | ($raw | to_entries
          | sort_by(-(.value.f - (.value.f|floor)))) as $sorted
      | reduce range(0; ($raw|length)) as $i ({};
          .[$sorted[$i].value.k] =
            (($sorted[$i].value.f|floor) + (if $i < $rem then 1 else 0 end)))
    end;

  ($judge[0])            as $j |
  ($lh[0])              as $L |
  ($brm[0])             as $B |
  ($brr[0])             as $R |

  # ── Dimensionen ── (alle Judge-Eingänge über num: Nicht-Zahl ⇒ nicht messbar)
  ($j.visual.score | num | if .==null then null else (clamp|rnd) end)  as $vis |
  ($j.ki_score | num | if .==null then null else ((10 - .) * 10 | clamp | rnd) end) as $slop |

  ($L.scores.performance | num)                                       as $perf |

  ((($B.counts.contrast_violations | num) // 0))                      as $viol |
  (($L.scores.accessibility | num) as $lha
   | if $lha == null then null
     else ($lha - ([($viol * 4), 40] | min) | clamp | rnd) end)       as $a11y |

  ($j.conversion) as $cv |
  ([$cv.clarity, $cv.credibility, $cv.logic, $cv.action, $cv.emotion]
     | map(num) | map(select(. != null))) as $cvals |
  (if ($cvals|length) == 0 then null else (($cvals|add) / ($cvals|length) | clamp | rnd) end) as $conv |

  # ── Gewichte + Renormierung ──
  { visuell:$wv, slop:$ws, performance:$wp, accessibility:$wa, conversion:$wc } as $w |
  { visuell:$vis, slop:$slop, performance:$perf, accessibility:$a11y, conversion:$conv } as $dim |
  ([ $dim | to_entries[] | select(.value != null) | .key ]) as $measurable |
  ([ $measurable[] | $w[.] ] | add) as $wsum |
  ( renorm($measurable; $w; ($wsum // 0)) ) as $weff |
  ( if $wsum == null or $wsum == 0 then null
    else ([ $measurable[] | $dim[.] * $w[.] ] | add) / $wsum | rnd end ) as $total |

  # ── Befunde einsammeln ──
  ( [ ($j.visual.findings // [])[]     | . + {source:"visual"} ]
    + [ ($j.slop.findings // [])[]     | . + {source:"slop"} ]
    + [ ($j.conversion.findings // [])[] | . + {source:"conversion"} ]
    + [ (if $L == null then [] else ($L.opportunities // []) end)[]
        | { title: .title,
            severity: (if (.savings_ms // 0) >= 1000 then "hoch"
                       elif (.savings_ms // 0) >= 300 then "mittel" else "niedrig" end),
            evidence: ("Lighthouse-Einsparpotenzial ≈ \(.savings_ms // 0) ms (\(.id))"),
            location: "Technik (Lighthouse mobile)",
            source: "lighthouse" } ]
    + [ (if $R == null then [] else ($R.contrast_violations // []) end)[]
        | { title: "Zu geringer Textkontrast",
            severity: (if (.ratio // 99) < 3 then "hoch" else "mittel" end),
            evidence: ("Kontrast \(.fg) auf \(.bg) = \(.ratio):1 < \(.required):1 (WCAG-AA, \(.font_px)px)"),
            location: "Kontrast (WCAG-AA)",
            source: "contrast" } ]
  ) as $all |

  # Validierung: Beleg + Fundort + Quelle Pflicht.
  ( [ $all[] | select((.evidence // "" | length) > 0
                       and (.location // "" | length) > 0
                       and (.source // "" | length) > 0)
      | { title: (.title // "(ohne Titel)"),
          severity: (if (.severity // "mittel") == "hoch" then "hoch"
                     elif (.severity // "mittel") == "niedrig" then "niedrig" else "mittel" end),
          evidence: .evidence, location: .location, source: .source } ]
  ) as $valid |
  ($all | length) as $found_n |
  ({hoch:0, mittel:1, niedrig:2}) as $ord |
  ( $valid | sort_by($ord[.severity]) | .[0:15] ) as $findings |

  # Mindestanzahl: 3 bei Gesamtscore ≥ 85 (sehr gute Seite), sonst 5.
  (if ($total != null and $total >= 85) then 3 else 5 end) as $min_findings |

  {
    run_id: $run_id,
    url: $url,
    final_url: $final_url,
    timestamp: $ts,
    rubric_version: $rv,
    generator_version: $genv,
    weights: $w,
    weights_effective: $weff,
    dimensions: {
      visuell: { score: $vis, source: "claude-judge (visuell)", measurable: ($vis != null) },
      slop: { score: $slop, source: "design-ai-check (invertiert)",
              ki_score: ($j.ki_score), measurable: ($slop != null) },
      performance: { score: $perf, source: "lighthouse", measurable: ($perf != null) },
      accessibility: { score: $a11y, source: "lighthouse a11y + kontrast (PROJ-3)",
                       contrast_violations: $viol, measurable: ($a11y != null) },
      conversion: { score: $conv, source: "cai-modell", measurable: ($conv != null),
                    subscores: { clarity: $cv.clarity, credibility: $cv.credibility,
                                 logic: $cv.logic, action: $cv.action, emotion: $cv.emotion } }
    },
    total: $total,
    findings: $findings,
    findings_meta: { found: $found_n, valid: ($valid|length),
                     dropped: ($found_n - ($valid|length)),
                     shown: ($findings|length), minimum: $min_findings,
                     below_minimum: (($findings|length) < $min_findings) },
    benchmark: (if $bench == null then null
                else $bench + { delta: (if $total==null then null else ($total - $bench.average_total) end) } end),
    meta: {
      industry_tag: $industry,
      app_mode: (if $j.app_mode == null then false else $j.app_mode end),
      cta_present: (if $j.cta_present == null then true else $j.cta_present end),
      language_confident: (if $j.language_confident == null then true else $j.language_confident end),
      content_suspicion: ($suspicion | if .=="" then null else . end)
    }
  }
' > "$SCORES" || die_intern "scores.json-Erzeugung fehlgeschlagen (ungültiges judge.json?)."

[[ -s "$SCORES" ]] || die_intern "scores.json wurde nicht geschrieben."

# ── report.md rendern ──────────────────────────────────────────────────────
REPORT="$RUN_DIR/report.md"
jq -r '
  def band($s): if $s==null then "—" elif $s>=85 then "🟢" elif $s>=60 then "🟡" else "🔴" end;
  def dim($k; $label; $d):
    "| \($label) | \(if $d.score==null then "_nicht messbar_" else "\(band($d.score)) \($d.score)" end) | \($d.source) |";
  # BUG-3: von der Zielseite kontrollierte URL neutralisieren, bevor sie roh in
  # Markdown/HTML (PROJ-7/16) landet — Steuerzeichen und <>[]`() strippen.
  def md_safe: (. // "") | tostring | gsub("[\\n\\r\\t<>\\[\\]`()]"; "") | gsub("  +"; " ");
  . as $r |
  [
    "# UI-Check Report — \($r.final_url // $r.url | md_safe)",
    "",
    "**Lauf-ID:** `\($r.run_id)` · **Datum:** \($r.timestamp) · **Rubrik:** `\($r.rubric_version)` · **Generator:** `\($r.generator_version)`",
    "",
    "## Gesamtscore: \(if $r.total==null then "—" else "\(band($r.total)) **\($r.total)/100**" end)",
    "",
    (if $r.benchmark != null then
       "> **Benchmark (\($r.benchmark.industry_tag), n=\($r.benchmark.n)):** Ø \($r.benchmark.average_total) · " +
       "dieser Lauf \(if $r.benchmark.delta >= 0 then "+\($r.benchmark.delta)" else "\($r.benchmark.delta)" end) Punkte\n"
     else empty end),
    "## Score-Panel",
    "",
    "| Dimension | Score | Quelle |",
    "|---|---|---|",
    dim("visuell"; "Visuelle Qualität"; $r.dimensions.visuell),
    dim("slop"; "KI-Generik / Slop"; $r.dimensions.slop),
    dim("performance"; "Performance"; $r.dimensions.performance),
    dim("accessibility"; "Accessibility"; $r.dimensions.accessibility),
    dim("conversion"; "Conversion"; $r.dimensions.conversion),
    "",
    "_Gewichte (nach Renormierung fehlender Dimensionen): " +
      ([$r.weights_effective | to_entries[] | "\(.key) \(.value)%"] | join(" · ")) + "._",
    "",
    (if $r.dimensions.conversion.measurable then
      "**Conversion-Teilscores (Cai):** " +
      ([$r.dimensions.conversion.subscores | to_entries[] | "\(.key) \(.value // "—")"] | join(" · "))
     else empty end),
    "",
    (if ($r.dimensions | to_entries | map(select(.value.measurable|not)) | length) > 0 then
      "> ⚠️ Nicht messbare Dimensionen aus der Gewichtung entfernt (renormiert): " +
      ([$r.dimensions | to_entries[] | select(.value.measurable|not) | .key] | join(", ")) + "."
     else empty end),
    (if $r.meta.app_mode then "> ℹ️ **App-Modus empfohlen** (Stufe-4-Feature) — Seite wirkt wie eine App/Tool-Oberfläche; Bewertung mit Landing-Rubrik + Disclaimer." else empty end),
    (if ($r.meta.cta_present|not) then "> ℹ️ Kein primärer CTA erkannt — Cai-Achsen *Action/Logic* auf die Info-Aufgabe bezogen bewertet." else empty end),
    (if ($r.meta.language_confident|not) then "> ℹ️ Seitensprache nicht sicher verstanden — Copy-bezogene Befunde weggelassen." else empty end),
    (if $r.meta.content_suspicion=="spa_empty" then "> ⚠️ Verdacht auf SPA ohne SSR (wenig sichtbarer Text bei der Erfassung) — Bewertung ggf. eingeschränkt." else empty end),
    "",
    "## Befunde (\($r.findings|length))",
    ""
  ]
  + (if ($r.findings|length)==0 then ["_Keine belegten Befunde._"] else
      ([ "hoch", "mittel", "niedrig" ] | map(. as $sev |
        ($r.findings | map(select(.severity==$sev))) as $grp |
        if ($grp|length)==0 then empty else
          (["### Severity: \($sev) (\($grp|length))", ""] +
           ($grp | map("- **\(.title)** — \(.evidence) _(Fundort: \(.location) · Quelle: `\(.source)`)_")) + [""])
        end
      ) | add)
    end)
  + (if $r.findings_meta.below_minimum then
       ["> ⚠️ Nur \($r.findings|length) belegte Befunde (Minimum \($r.findings_meta.minimum)). " +
        "\($r.findings_meta.dropped) unbelegte Befunde wurden verworfen (Beleg ist Pflicht)." , ""]
     else [] end)
  + [
    "## Kurzempfehlungen",
    ""
  ]
  + ( ($r.dimensions | to_entries
       | map(select(.value.measurable and .value.score != null and .value.score < 60))
       | sort_by(.value.score))
      as $weak |
      if ($weak|length)==0 then ["- Solide Basis — Feinschliff statt Grundsanierung: stärkste Befunde oben zuerst adressieren."]
      else ($weak | map("- **\(.key)** (\(.value.score)/100) priorisiert angehen — schwächste Dimension zuerst.")) end)
  + [
    "",
    "---",
    "_Erzeugt von UI-Check `score-report` v\($r.generator_version) · Rubrik `\($r.rubric_version)`. Technische Dimensionen aus Lighthouse; visuelle/Conversion/Slop-Bewertung durch Claude-Judge gegen versionierte Rubrik. Widersprüche zwischen Judge und Lighthouse werden bewusst nicht geglättet._"
  ]
  | map(select(. != null)) | .[]
' "$SCORES" > "$REPORT" || die_intern "report.md-Rendern fehlgeschlagen."

# ── runs.jsonl anhängen (append-only, nur URL-Hash — keine Klardaten) ───────
mkdir -p "$ROOT/data"
jq -c -n \
  --arg date "$(date -u +%F)" \
  --arg hash "$URL_HASH" \
  --arg tag "$INDUSTRY" \
  --arg rv "$RUBRIC_VERSION" \
  --arg run_id "$RUN_ID" \
  --slurpfile s "$SCORES" '
  ($s[0]) as $r |
  { date: $date, url_hash: $hash, industry_tag: $tag, rubric_version: $rv, run_id: $run_id,
    total: $r.total,
    dimensions: ($r.dimensions | to_entries | map({ (.key): .value.score }) | add) }
  ' >> "$RUNS" 2>/dev/null || echo "  · Hinweis: runs.jsonl nicht aktualisierbar ($RUNS)" >&2

# ── Ausgabe + Exit-Code ────────────────────────────────────────────────────
TOTAL="$(jq -r '.total // "—"' "$SCORES")"
UNMEAS="$(jq -r '[.dimensions | to_entries[] | select(.value.measurable|not) | .key] | length' "$SCORES")"
BELOW="$(jq -r '.findings_meta.below_minimum' "$SCORES")"

echo "✓ Report erzeugt → $RUN_DIR"
echo "  Gesamtscore: $TOTAL/100 · Befunde: $(jq -r '.findings|length' "$SCORES") · Rubrik: $RUBRIC_VERSION"
jq -r '"  Panel  Vis:\(.dimensions.visuell.score // "—") Slop:\(.dimensions.slop.score // "—") Perf:\(.dimensions.performance.score // "—") A11y:\(.dimensions.accessibility.score // "—") Conv:\(.dimensions.conversion.score // "—")"' "$SCORES"
echo "  scores.json · report.md"

if [[ "$UNMEAS" -gt 0 || "$BELOW" == "true" ]]; then
  [[ "$UNMEAS" -gt 0 ]] && echo "  · Degradiert: $UNMEAS Dimension(en) nicht messbar (renormiert)" >&2
  [[ "$BELOW" == "true" ]] && echo "  · Degradiert: Befund-Minimum unterschritten" >&2
  exit 1
fi
exit 0
