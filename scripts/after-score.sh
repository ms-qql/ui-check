#!/usr/bin/env bash
#
# after-score.sh — Nachher-Scoring / Score-Delta (PROJ-9)
#
# Deterministischer Pipeline-Schritt nach mockup-export.sh: wertet frische
# Judge-Ausgaben für Safe/Bold gegen dieselbe Rubrik-Version aus, entfernt
# Lighthouse/Performance aus dem Vergleich, entscheidet das Delta-Gate und
# reichert report.md + mockup.html an.
#
# Nutzung:
#   after-score.sh <run-dir> [--judge-safe <file>] [--judge-bold <file>]
#                            [--retry-safe <file>] [--retry-bold <file>]
#                            [--retry-cmd <executable>] [--threshold 15] [--force]
#
# Default-Judge-Dateien:
#   <run-dir>/after-judge-safe.json
#   <run-dir>/after-judge-bold.json
#   <run-dir>/after-judge-safe-retry.json   (optional)
#   <run-dir>/after-judge-bold-retry.json   (optional)
#
# Exit-Codes:
#   0  mindestens eine Variante besteht das Delta-Gate
#   1  beide Varianten scheitern; Audit-only-Ergebnis + Fehlerbericht erzeugt
#   2  Input-Gate/intern: fehlende Pflichtdatei, ungültiges JSON, Versionskonflikt

set -uo pipefail

RUN_DIR=""
JUDGE_SAFE=""
JUDGE_BOLD=""
RETRY_SAFE=""
RETRY_BOLD=""
RETRY_CMD="${AFTER_SCORE_RETRY_CMD:-}"
THRESHOLD=15
FORCE=false

update_status() { # $1=status $2=fehlertext
  local sf="${RUN_DIR:-}/status.json" tmp
  [[ -n "${RUN_DIR:-}" && -s "$sf" ]] || return 0
  tmp="$(mktemp)"
  jq --arg s "$1" --arg e "${2:-}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.phases.after_scoring = {status:$s, error:($e|if .=="" then null else . end)} | .updated_at=$now' \
     "$sf" > "$tmp" 2>/dev/null && mv "$tmp" "$sf" || rm -f "$tmp"
}

die() { echo "✗ $*" >&2; update_status failed "$*"; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --judge-safe) JUDGE_SAFE="${2:-}"; shift 2 ;;
    --judge-bold) JUDGE_BOLD="${2:-}"; shift 2 ;;
    --retry-safe) RETRY_SAFE="${2:-}"; shift 2 ;;
    --retry-bold) RETRY_BOLD="${2:-}"; shift 2 ;;
    --retry-cmd)  RETRY_CMD="${2:-}"; shift 2 ;;
    --threshold)  THRESHOLD="${2:-}"; shift 2 ;;
    --force)      FORCE=true; shift ;;
    -h|--help)    sed -n '2,31p' "$0"; exit 0 ;;
    -*)           echo "✗ Unbekannte Option: $1" >&2; exit 2 ;;
    *)            [[ -z "$RUN_DIR" ]] && RUN_DIR="$1" || { echo "✗ Zu viele Argumente: $1" >&2; exit 2; }; shift ;;
  esac
done

[[ -n "$RUN_DIR" ]] || { echo "✗ Kein Run-Ordner angegeben. Nutzung: after-score.sh <run-dir>" >&2; exit 2; }
[[ -d "$RUN_DIR" ]] || { echo "✗ Run-Ordner nicht gefunden: $RUN_DIR" >&2; exit 2; }
[[ "$THRESHOLD" =~ ^[0-9]+$ ]] || { echo "✗ --threshold erwartet eine ganze Zahl, war: $THRESHOLD" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "✗ jq nicht gefunden." >&2; exit 2; }

RUN_DIR="$(cd "$RUN_DIR" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
RUBRIC_VERSION="$(head -1 "$ROOT/rubrics/VERSION" 2>/dev/null || true)"
[[ -n "$RUBRIC_VERSION" ]] || die "rubrics/VERSION fehlt oder leer."

SCORES_ORIG="$RUN_DIR/scores.json"
REPORT="$RUN_DIR/report.md"
MOCKUP="$RUN_DIR/mockup.html"
OUT_SUMMARY="$RUN_DIR/after-scoring.json"
OUT_SAFE="$RUN_DIR/scores-safe.json"
OUT_BOLD="$RUN_DIR/scores-bold.json"
AFTER_DIR="$RUN_DIR/after-score"

[[ -s "$SCORES_ORIG" ]] || die "Original-Score fehlt ($SCORES_ORIG) — PROJ-4 zuerst laufen lassen."
[[ -s "$REPORT" ]] || die "report.md fehlt ($REPORT) — PROJ-4 zuerst laufen lassen."
[[ -s "$MOCKUP" ]] || die "mockup.html fehlt ($MOCKUP) — PROJ-7 zuerst laufen lassen."
jq -e . "$SCORES_ORIG" >/dev/null 2>&1 || die "scores.json ist kein gültiges JSON."
[[ "$(jq -r '.rubric_version // ""' "$SCORES_ORIG")" == "$RUBRIC_VERSION" ]] \
  || die "Rubrik-Version-Konflikt: scores.json='$(jq -r '.rubric_version // ""' "$SCORES_ORIG")' != rubrics/VERSION='$RUBRIC_VERSION'."

[[ -z "$JUDGE_SAFE" ]] && JUDGE_SAFE="$RUN_DIR/after-judge-safe.json"
[[ -z "$JUDGE_BOLD" ]] && JUDGE_BOLD="$RUN_DIR/after-judge-bold.json"
[[ -z "$RETRY_SAFE" ]] && RETRY_SAFE="$RUN_DIR/after-judge-safe-retry.json"
[[ -z "$RETRY_BOLD" ]] && RETRY_BOLD="$RUN_DIR/after-judge-bold-retry.json"

[[ -s "$JUDGE_SAFE" ]] || die "Nachher-Judge für Safe fehlt: $JUDGE_SAFE"
[[ -s "$JUDGE_BOLD" ]] || die "Nachher-Judge für Bold fehlt: $JUDGE_BOLD"

if [[ -e "$OUT_SUMMARY" && "$FORCE" != true ]]; then
  die "after-scoring.json existiert bereits — erneuter Nachher-Score nur mit --force."
fi

validate_judge() { # $1=file $2=label
  local f="$1" label="$2" rv
  [[ -s "$f" ]] || die "Judge-Datei fehlt ($label): $f"
  jq -e . "$f" >/dev/null 2>&1 || die "Judge-Datei ist kein gültiges JSON ($label): $f"
  rv="$(jq -r '.rubric_version // ""' "$f")"
  [[ -z "$rv" || "$rv" == "$RUBRIC_VERSION" ]] || die "Rubrik-Version-Konflikt ($label): '$rv' != '$RUBRIC_VERSION'"
  jq -e '.visual.score != null and .ki_score != null and .conversion != null' "$f" >/dev/null 2>&1 \
    || die "Judge-Datei unvollständig ($label): benötigt .visual.score, .ki_score und .conversion."
  jq -e '(.accessibility.score != null) or (.a11y.score != null)' "$f" >/dev/null 2>&1 \
    || die "Judge-Datei unvollständig ($label): benötigt .accessibility.score oder .a11y.score für den 4-Dimensionen-Vergleich."
}

score_variant() { # $1=variant $2=judge $3=attempt $4=out
  local variant="$1" judge="$2" attempt="$3" out="$4"
  validate_judge "$judge" "$variant/$attempt"
  jq -n \
    --slurpfile orig "$SCORES_ORIG" \
    --slurpfile judge "$judge" \
    --arg variant "$variant" \
    --arg attempt "$attempt" \
    --arg judge_file "$judge" \
    --arg rv "$RUBRIC_VERSION" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson threshold "$THRESHOLD" '
    def clamp: if . < 0 then 0 elif . > 100 then 100 else . end;
    def rnd: (.*1|round);
    def num: if type == "number" then . else null end;
    def renorm_total($dims; $w):
      ([ $dims | to_entries[] | select(.value != null) | .key ]) as $keys
      | ([ $keys[] | $w[.] ] | add) as $wsum
      | if ($keys|length)==0 or $wsum == null or $wsum == 0 then null
        else ([ $keys[] | $dims[.] * $w[.] ] | add) / $wsum | rnd end;
    def renorm_weights($dims; $w):
      ([ $dims | to_entries[] | select(.value != null) | .key ]) as $keys
      | ([ $keys[] | $w[.] ] | add) as $wsum
      | if ($keys|length)==0 or $wsum == null or $wsum == 0 then {}
        else reduce $keys[] as $k ({}; .[$k] = (($w[$k] / $wsum * 100) | round)) end;
    def findings($j):
      ([ ($j.visual.findings // [])[] | . + {source:(.source // "visual")} ]
       + [ ($j.slop.findings // [])[] | . + {source:(.source // "slop")} ]
       + [ ($j.conversion.findings // [])[] | . + {source:(.source // "conversion")} ])
      | map(select((.evidence // "" | length) > 0 and (.location // "" | length) > 0))
      | map({
          title: (.title // "(ohne Titel)"),
          severity: (if (.severity // "mittel") == "hoch" then "hoch"
                     elif (.severity // "mittel") == "niedrig" then "niedrig" else "mittel" end),
          evidence: .evidence,
          location: .location,
          source: (.source // "judge")
        });
    ($orig[0]) as $o |
    ($judge[0]) as $j |
    ($o.weights // {visuell:25, slop:15, performance:15, accessibility:15, conversion:30}) as $w |
    {
      visuell: (($j.visual.score | num) | if .==null then null else (clamp|rnd) end),
      slop: (($j.ki_score | num) | if .==null then null else ((10 - .) * 10 | clamp | rnd) end),
      performance: null,
      accessibility: (($j.accessibility.score // $j.a11y.score // null | num) | if .==null then null else (clamp|rnd) end),
      conversion: (
        ($j.conversion) as $cv
        | ([$cv.clarity, $cv.credibility, $cv.logic, $cv.action, $cv.emotion] | map(num) | map(select(. != null))) as $vals
        | if ($vals|length)==0 then null else (($vals|add) / ($vals|length) | clamp | rnd) end
      )
    } as $after_dims |
    {
      visuell: $o.dimensions.visuell.score,
      slop: $o.dimensions.slop.score,
      performance: null,
      accessibility: $o.dimensions.accessibility.score,
      conversion: $o.dimensions.conversion.score
    } as $orig_dims |
    (renorm_total($orig_dims; $w)) as $orig_total |
    (renorm_total($after_dims; $w)) as $after_total |
    (($after_total // 0) - ($orig_total // 0)) as $delta |
    {
      variant: $variant,
      attempt: $attempt,
      timestamp: $ts,
      rubric_version: $rv,
      source: {
        judge_file: $judge_file,
        original_scores: "scores.json",
        mockup: "mockup.html"
      },
      weights: $w,
      weights_effective: renorm_weights($after_dims; $w),
      dimensions: {
        visuell: {score:$after_dims.visuell, source:"claude-judge (visuell)", measurable:($after_dims.visuell != null)},
        slop: {score:$after_dims.slop, source:"design-ai-check (invertiert)", ki_score:$j.ki_score, measurable:($after_dims.slop != null)},
        performance: {score:null, source:"lokales mockup: nicht vergleichbar", measurable:false, comparable:false},
        accessibility: {score:$after_dims.accessibility, source:"claude-judge/local accessibility", measurable:($after_dims.accessibility != null)},
        conversion: {score:$after_dims.conversion, source:"cai-modell", measurable:($after_dims.conversion != null),
          subscores: {clarity:$j.conversion.clarity, credibility:$j.conversion.credibility,
                      logic:$j.conversion.logic, action:$j.conversion.action, emotion:$j.conversion.emotion}}
      },
      total: $after_total,
      original_total_comparable: $orig_total,
      delta: $delta,
      gate: {
        threshold: $threshold,
        required_total: (($orig_total // 0) + $threshold),
        status: (if $after_total != null and $delta >= $threshold then "passed" else "failed" end),
        deliverable: ($after_total != null and $delta >= $threshold)
      },
      findings: findings($j)
    }
  ' "$judge" > "$out" || die "Score-Erzeugung fehlgeschlagen für $variant/$attempt."
}

write_retry_brief() { # $1=variant $2=score-file
  local variant="$1" sf="$2" brief="$AFTER_DIR/retry-$variant.md"
  mkdir -p "$AFTER_DIR"
  jq -r --arg variant "$variant" '
    "# Retry-Brief " + ($variant|ascii_upcase) + "\n\n" +
    "Die Variante scheitert am PROJ-9-Delta-Gate.\n\n" +
    "- Original vergleichbar: " + (.original_total_comparable|tostring) + "\n" +
    "- Nachher: " + (.total|tostring) + "\n" +
    "- Delta: " + (.delta|tostring) + "\n" +
    "- Erforderlich: +" + (.gate.threshold|tostring) + "\n\n" +
    "## Befund-Feedback für den Retry\n\n" +
    (if (.findings|length)==0 then "- Keine belegten Befunde geliefert; Judge-Kontext prüfen.\n"
     else ([.findings[0:8][] | "- **" + .title + "**: " + .evidence + " _(Fundort: " + .location + ")_"] | join("\n")) end)
  ' "$sf" > "$brief"
  printf '%s\n' "$brief"
}

score_with_retry() { # $1=variant $2=judge $3=retry $4=out
  local variant="$1" judge="$2" retry="$3" out="$4" first brief
  first="$AFTER_DIR/$variant-first.json"
  mkdir -p "$AFTER_DIR"
  score_variant "$variant" "$judge" "initial" "$first"
  if [[ "$(jq -r '.gate.status' "$first")" == "passed" ]]; then
    cp "$first" "$out"
    return 0
  fi
  brief="$(write_retry_brief "$variant" "$first")"
  if [[ ! -s "$retry" && -n "$RETRY_CMD" ]]; then
    [[ -x "$RETRY_CMD" ]] || die "Retry-Kommando nicht ausführbar: $RETRY_CMD"
    "$RETRY_CMD" "$variant" "$RUN_DIR" "$brief" "$retry" \
      || die "Retry-Kommando für $variant fehlgeschlagen: $RETRY_CMD"
  fi
  if [[ -s "$retry" ]]; then
    score_variant "$variant" "$retry" "retry" "$out"
    jq --slurpfile first "$first" --arg cmd "${RETRY_CMD:-}" \
      '.retry = {used:true, previous_delta:$first[0].delta, previous_total:$first[0].total,
                 command: ($cmd|if .=="" then null else . end)}' \
      "$out" > "$out.tmp" && mv "$out.tmp" "$out"
  else
    cp "$first" "$out"
    jq '.retry = {used:false, required:true, reason:"retry judge not provided and no retry command configured"}' "$out" > "$out.tmp" && mv "$out.tmp" "$out"
  fi
}

render_summary() {
  jq -n --slurpfile safe "$OUT_SAFE" --slurpfile bold "$OUT_BOLD" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    ($safe[0]) as $s | ($bold[0]) as $b |
    ([ $s, $b ] | map(select(.gate.status=="passed")) | sort_by(-.total)) as $passed |
    {
      timestamp: $ts,
      status: (if ($passed|length) > 0 then "ok" else "failed" end),
      winner: (if ($passed|length) > 0 then $passed[0].variant else null end),
      variants: {safe:$s, bold:$b},
      deliverable_variants: ($passed | map(.variant)),
      message: (if ($passed|length) > 0
        then "Mindestens eine Variante besteht das Delta-Gate."
        else "Beide Varianten scheitern am Delta-Gate; Audit-only-Ergebnis ausliefern." end)
    }
  ' > "$OUT_SUMMARY" || die "after-scoring.json konnte nicht geschrieben werden."
}

update_report() {
  local tmp body
  tmp="$(mktemp)"
  body="$(mktemp)"
  jq -r '
    def line($v):
      "- **" + ($v.variant|ascii_upcase) + ":** " +
      (($v.original_total_comparable|tostring) + " -> " + ($v.total|tostring) +
       " (Delta " + (if $v.delta >= 0 then "+" else "" end) + ($v.delta|tostring) + ") · " +
       (if $v.gate.status=="passed" then "auslieferbar" else "nicht ausgeliefert" end) +
       (if $v.retry.used == true then " nach Retry" elif $v.retry.required == true then " · Retry-Brief erzeugt" else "" end));
    . as $r |
    [
      "",
      "<!-- UI-CHECK-AFTER-SCORING:START -->",
      "## Nachher-Scoring (Score-Delta)",
      "",
      "**Status:** " + (if $r.status=="ok" then "mindestens eine Variante auslieferbar" else "Audit-only: beide Varianten scheitern am Gate" end),
      "",
      line($r.variants.safe),
      line($r.variants.bold),
      "",
      "_Performance/Lighthouse ist für lokale Mockups nicht vergleichbar und wurde aus dem Delta renormiert._",
      "<!-- UI-CHECK-AFTER-SCORING:END -->"
    ] | .[]
  ' "$OUT_SUMMARY" > "$body"
  awk '
    /<!-- UI-CHECK-AFTER-SCORING:START -->/ {skip=1; next}
    /<!-- UI-CHECK-AFTER-SCORING:END -->/ {skip=0; next}
    skip==0 {print}
  ' "$REPORT" > "$tmp"
  cat "$body" >> "$tmp"
  mv "$tmp" "$REPORT"
  rm -f "$body"
}

update_mockup() {
  local tmp badge_file safe_line bold_line
  tmp="$(mktemp)"
  badge_file="$(mktemp)"
  safe_line="$(jq -r '.variants.safe | "Safe: " + (.original_total_comparable|tostring) + " -> " + (.total|tostring) + " (" + (if .delta >= 0 then "+" else "" end) + (.delta|tostring) + ")"' "$OUT_SUMMARY")"
  bold_line="$(jq -r '.variants.bold | "Bold: " + (.original_total_comparable|tostring) + " -> " + (.total|tostring) + " (" + (if .delta >= 0 then "+" else "" end) + (.delta|tostring) + ")"' "$OUT_SUMMARY")"
  {
    printf '<!-- UI-CHECK-AFTER-SCORING-BADGE:START -->\n'
    printf '<aside class="ui-check-score-delta" data-after-scoring="true" style="position:fixed;right:16px;bottom:16px;z-index:2147483647;padding:10px 12px;border-radius:8px;background:#111827;color:#fff;font:600 12px/1.4 system-ui,sans-serif;box-shadow:0 10px 30px rgba(0,0,0,.25)">'
    printf '<div>Score-Delta</div><div>%s</div><div>%s</div></aside>\n' "$safe_line" "$bold_line"
    printf '<!-- UI-CHECK-AFTER-SCORING-BADGE:END -->\n'
  } > "$badge_file"
  awk '
    /<!-- UI-CHECK-AFTER-SCORING-BADGE:START -->/ {skip=1; next}
    /<!-- UI-CHECK-AFTER-SCORING-BADGE:END -->/ {skip=0; next}
    skip==0 {print}
  ' "$MOCKUP" > "$tmp"
  if grep -qi '</body>' "$tmp"; then
    awk -v badge_file="$badge_file" '
      BEGIN{done=0}
      /<\/body>/ && done==0 {while ((getline line < badge_file) > 0) print line; close(badge_file); done=1}
      {print}
    ' "$tmp" > "$tmp.2" && mv "$tmp.2" "$MOCKUP"
  else
    {
      cat "$tmp"
      cat "$badge_file"
    } > "$MOCKUP"
  fi
  rm -f "$tmp" "$badge_file"
}

echo "→ Nachher-Scoring für $(basename "$RUN_DIR") …"
score_with_retry "safe" "$JUDGE_SAFE" "$RETRY_SAFE" "$OUT_SAFE"
score_with_retry "bold" "$JUDGE_BOLD" "$RETRY_BOLD" "$OUT_BOLD"
render_summary
update_report
update_mockup

status="$(jq -r '.status' "$OUT_SUMMARY")"
if [[ "$status" == "ok" ]]; then
  update_status ok ""
  echo "✓ Nachher-Scoring ok → $OUT_SUMMARY"
  jq -r '"  Safe: \(.variants.safe.original_total_comparable) -> \(.variants.safe.total) (Δ \(.variants.safe.delta)) · \(.variants.safe.gate.status)\n  Bold: \(.variants.bold.original_total_comparable) -> \(.variants.bold.total) (Δ \(.variants.bold.delta)) · \(.variants.bold.gate.status)"' "$OUT_SUMMARY"
  echo "  scores-safe.json · scores-bold.json · report.md · mockup.html"
  exit 0
fi

update_status failed "Beide Varianten scheitern am Delta-Gate; Audit-only-Ergebnis ausliefern."
echo "⚠ Nachher-Scoring gescheitert: beide Varianten unter Delta-Gate → Audit-only-Ergebnis" >&2
echo "  Diagnose: $OUT_SUMMARY" >&2
exit 1
