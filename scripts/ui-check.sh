#!/usr/bin/env bash
#
# ui-check — Skill-Orchestrierung (PROJ-5) für die UI-Check-Pipeline
#
# Deterministischer Treiber, den der Claude-Code-Skill `ui-check` aufruft. Führt
# die vier Schritt-CLIs aus PROJ-1–4 in korrekter Reihenfolge (parallel wo
# möglich) aus, verwaltet den Run-Ordner-Kontrakt, protokolliert den Fortschritt
# in status.json und wendet die zentrale Fehlerpolitik an.
#
# Zwei Modi (der Judge dazwischen ist Claude selbst — siehe SKILL.md):
#
#   1) COLLECT   ui-check.sh <url> [--industry <tag>] [--prompt "…"] [--desktop]
#                             [--out <run-dir>] [--timeout <s>]
#      Preflight → Run-Ordner → Capture ∥ Lighthouse → Branding.
#      Danach steht der Run-Ordner bereit für den Judge-Pass (judge.json).
#
#   2) FINALIZE  ui-check.sh --finalize <run-dir> [--industry <tag>]
#                             [--weights v,s,p,a,c]
#      Erwartet ein von Claude erzeugtes <run-dir>/judge.json und ruft
#      score-report.sh (PROJ-4) auf → scores.json + report.md + runs.jsonl.
#      Gibt die Terminal-Zusammenfassung aus (Gesamtscore, Top-3, Report-Pfad).
#
#   3) ASSEMBLE  ui-check.sh --assemble --branding <slug> --industry <tag>
#                             [--sections hero,trust,features,pricing,cta]
#                             [--prompt "…"]
#      Delegiert an scripts/assemble.sh (PROJ-13): greenfield Portfolio-Mockup
#      aus Branding-Profil × Registry statt aus Capture/Audit.
#
# Exit-Codes (headless-tauglich, Jupiter/PROJ-14):
#   0  ok            — Lauf vollständig, alle Dimensionen messbar
#   1  Teilfehler    — Lauf nutzbar, aber degradiert (Lighthouse/Logo/Dimension
#                      nicht messbar) oder Judge-/Report-Warnung
#   2  Abbruch       — nichts zu bewerten (Capture-Fehler, Input-Gate, ungültige
#                      Argumente, fehlendes Tool)
#
# Fehlerpolitik (zentral hier, die Schritte selbst bleiben „dumm"):
#   Capture-Fehler        ⇒ Abbruch des Laufs (Exit 2), status.json = aborted.
#   Lighthouse-/Logo-/
#   Extraktor-Fehler      ⇒ weiterlaufen, „nicht messbar"-Vermerk (Exit 1).
#
# Alle Meldungen auf Deutsch. Maschinenlesbarer Fortschritt in status.json.

set -uo pipefail

# ── Verortung der Schritt-CLIs ─────────────────────────────────────────────
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# Testbarkeit: UI_CHECK_BIN kann auf ein Verzeichnis mit Stub-Schritten zeigen.
BIN="${UI_CHECK_BIN:-$HERE}"
CAPTURE="$BIN/capture.sh"
LH_AUDIT="$BIN/lh-audit.sh"
BRAND="$BIN/brand-extract.sh"
SCORE="$BIN/score-report.sh"
ASSEMBLE="$BIN/assemble.sh"

DEFAULT_TIMEOUT=60

die_intern() { echo "✗ $*" >&2; exit 2; }

# PROJ-13 nutzt eigene Flags (--branding, --sections, Registry-Overrides).
if [[ "${1:-}" == "--assemble" ]]; then
  shift
  [[ -f "$ASSEMBLE" ]] || die_intern "assemble.sh nicht gefunden ($ASSEMBLE)."
  exec bash "$ASSEMBLE" "$@"
fi

# ── Argumente ──────────────────────────────────────────────────────────────
MODE="collect"
URL=""
RUN_DIR=""
INDUSTRY=""
INDUSTRY_SOURCE="explicit"
USER_PROMPT=""
DESKTOP=false
WEIGHTS=""
TIMEOUT=$DEFAULT_TIMEOUT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --finalize) MODE="finalize"; RUN_DIR="${2:-}"; shift 2 ;;
    --industry) INDUSTRY="${2:-}"; shift 2 ;;
    --prompt)   USER_PROMPT="${2:-}"; shift 2 ;;
    --desktop)  DESKTOP=true; shift ;;
    --out)      RUN_DIR="${2:-}"; shift 2 ;;
    --weights)  WEIGHTS="${2:-}"; shift 2 ;;
    --timeout)  TIMEOUT="${2:-}"; shift 2 ;;
    -h|--help)  sed -n '2,40p' "$0"; exit 0 ;;
    -*)         die_intern "Unbekannte Option: $1" ;;
    *)          [[ "$MODE" == "collect" && -z "$URL" ]] && URL="$1" \
                  || die_intern "Zu viele Argumente: $1"; shift ;;
  esac
done

[[ -n "$INDUSTRY" ]] || INDUSTRY_SOURCE="auto"

# ── status.json ────────────────────────────────────────────────────────────
# Fortschrittsquelle für Jupiter (PROJ-14). Wird nach jeder Phase neu geschrieben.
declare -A PH_STATUS=( [capture]=pending [lighthouse]=pending [branding]=pending [scoring]=pending )
declare -A PH_DUR=( [capture]=0 [lighthouse]=0 [branding]=0 [scoring]=0 )
declare -A PH_ERR=( [capture]="" [lighthouse]="" [branding]="" [scoring]="" )
STARTED_AT=""
CURRENT_PHASE="init"
STATUS_FINAL_URL=""

write_status() {
  # $1 = Lauf-Status (running|awaiting_judge|done|aborted)
  [[ -n "${RUN_DIR:-}" && -d "${RUN_DIR:-}" ]] || return 0
  local run_status="$1"
  local now; now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local phases_json
  phases_json="$(jq -n \
    --arg cs "${PH_STATUS[capture]}"    --argjson cd "${PH_DUR[capture]}"    --arg ce "${PH_ERR[capture]}" \
    --arg ls "${PH_STATUS[lighthouse]}" --argjson ld "${PH_DUR[lighthouse]}" --arg le "${PH_ERR[lighthouse]}" \
    --arg bs "${PH_STATUS[branding]}"   --argjson bd "${PH_DUR[branding]}"   --arg be "${PH_ERR[branding]}" \
    --arg ss "${PH_STATUS[scoring]}"    --argjson sd "${PH_DUR[scoring]}"    --arg se "${PH_ERR[scoring]}" '
    def ph($s;$d;$e): { status:$s, duration_seconds:$d, error:($e|if .=="" then null else . end) };
    { capture:    ph($cs;$cd;$ce),
      lighthouse: ph($ls;$ld;$le),
      branding:   ph($bs;$bd;$be),
      scoring:    ph($ss;$sd;$se) }')"
  jq -n \
    --arg run_id "$(basename "$RUN_DIR")" \
    --arg url "$URL" \
    --arg final_url "$STATUS_FINAL_URL" \
    --arg run_status "$run_status" \
    --arg phase "$CURRENT_PHASE" \
    --arg industry "$INDUSTRY" \
    --arg industry_source "$INDUSTRY_SOURCE" \
    --arg prompt "$USER_PROMPT" \
    --argjson desktop "$DESKTOP" \
    --arg started "$STARTED_AT" \
    --arg updated "$now" \
    --argjson phases "$phases_json" '
    { run_id: $run_id,
      url: ($url|if .=="" then null else . end),
      final_url: ($final_url|if .=="" then null else . end),
      status: $run_status,
      phase: $phase,
      industry_tag: ($industry|if .=="" then null else . end),
      industry_source: $industry_source,
      user_prompt: ($prompt|if .=="" then null else . end),
      desktop: $desktop,
      started_at: ($started|if .=="" then null else . end),
      updated_at: $updated,
      phases: $phases }' > "$RUN_DIR/status.json" 2>/dev/null || true
}

# Ctrl-C / Abbruch durch Nutzer → Run-Ordner bleibt mit status: aborted erhalten.
on_signal() {
  CURRENT_PHASE="aborted"
  [[ "${PH_STATUS[capture]}"    == "running" ]] && PH_STATUS[capture]=aborted
  [[ "${PH_STATUS[lighthouse]}" == "running" ]] && PH_STATUS[lighthouse]=aborted
  [[ "${PH_STATUS[branding]}"   == "running" ]] && PH_STATUS[branding]=aborted
  write_status "aborted"
  echo "✗ Abbruch durch Nutzer — Run-Ordner bleibt erhalten ($RUN_DIR)" >&2
  exit 2
}

# ════════════════════════════════════════════════════════════════════════════
# FINALIZE-Modus
# ════════════════════════════════════════════════════════════════════════════
if [[ "$MODE" == "finalize" ]]; then
  [[ -n "$RUN_DIR" ]] || die_intern "--finalize erwartet einen Run-Ordner."
  [[ -d "$RUN_DIR" ]] || die_intern "Run-Ordner nicht gefunden: $RUN_DIR"
  command -v jq >/dev/null 2>&1 || die_intern "jq nicht gefunden."
  [[ -x "$SCORE" || -f "$SCORE" ]] || die_intern "score-report.sh nicht gefunden ($SCORE)."
  [[ -s "$RUN_DIR/judge.json" ]] || die_intern "judge.json fehlt ($RUN_DIR/judge.json) — der Judge-Pass (Claude) muss vor --finalize laufen. Kontrakt: scripts/README.md."

  # Kontext aus dem Collect-Lauf übernehmen (Industrie/Prompt), falls nicht neu gesetzt.
  CTX="$RUN_DIR/ui-check.json"
  if [[ -s "$CTX" ]]; then
    [[ -z "$INDUSTRY" ]] && INDUSTRY="$(jq -r '.industry_tag // ""' "$CTX")"
    STARTED_AT="$(jq -r '.started_at // ""' "$CTX")"
    STATUS_FINAL_URL="$(jq -r '.final_url // ""' "$CTX")"
    URL="$(jq -r '.url // ""' "$CTX")"
  fi
  [[ -n "$INDUSTRY" ]] || INDUSTRY="unknown"

  # Bereits gelaufene Phasen aus status.json spiegeln (für konsistentes Update).
  if [[ -s "$RUN_DIR/status.json" ]]; then
    for p in capture lighthouse branding; do
      PH_STATUS[$p]="$(jq -r --arg p "$p" '.phases[$p].status // "pending"' "$RUN_DIR/status.json")"
      PH_DUR[$p]="$(jq -r --arg p "$p" '.phases[$p].duration_seconds // 0' "$RUN_DIR/status.json")"
    done
  fi

  CURRENT_PHASE="scoring"; PH_STATUS[scoring]=running; write_status "running"
  echo "→ Scoring & Report (score-report.sh) …"
  s_start="$(date +%s)"
  score_args=("$RUN_DIR" --industry "$INDUSTRY")
  [[ -n "$WEIGHTS" ]] && score_args+=(--weights "$WEIGHTS")
  bash "$SCORE" "${score_args[@]}"
  score_rc=$?
  PH_DUR[scoring]=$(( $(date +%s) - s_start ))

  case $score_rc in
    0) PH_STATUS[scoring]=ok ;;
    1) PH_STATUS[scoring]=degraded ;;
    *) PH_STATUS[scoring]=failed; PH_ERR[scoring]="score-report Exit $score_rc (Input-Gate/intern)" ;;
  esac
  CURRENT_PHASE="done"
  write_status "$([[ $score_rc -eq 2 ]] && echo aborted || echo done)"

  # ── Terminal-Zusammenfassung ──
  SCORES="$RUN_DIR/scores.json"
  if [[ $score_rc -ne 2 && -s "$SCORES" ]]; then
    echo
    echo "════════════════════════════════════════════════════"
    echo "  UI-Check abgeschlossen — $(basename "$RUN_DIR")"
    echo "════════════════════════════════════════════════════"
    jq -r '
      def band($s): if $s==null then "—" elif $s>=85 then "🟢" elif $s>=60 then "🟡" else "🔴" end;
      "  Gesamtscore: \(band(.total)) \(.total // "—")/100"' "$SCORES"
    echo "  Top-Befunde:"
    jq -r '.findings[0:3][] | "    • [\(.severity)] \(.title) — \(.evidence)"' "$SCORES" 2>/dev/null
    unmeas="$(jq -r '[.dimensions|to_entries[]|select(.value.measurable|not)|.key]|join(", ")' "$SCORES")"
    [[ -n "$unmeas" ]] && echo "  ⚠ Nicht messbar (renormiert): $unmeas"
    echo "  Report: $RUN_DIR/report.md"
    echo "  Daten:  $RUN_DIR/scores.json · Benchmark-Zeile → data/runs.jsonl"
    echo "════════════════════════════════════════════════════"
  fi

  # score-report Exit → Orchestrator-Exit (0 ok · 1 degradiert · 2 Gate)
  exit $score_rc
fi

# ════════════════════════════════════════════════════════════════════════════
# COLLECT-Modus
# ════════════════════════════════════════════════════════════════════════════
[[ -n "$URL" ]] || die_intern "Keine URL angegeben. Nutzung: ui-check.sh <url> [--industry <tag>] [--prompt \"…\"] [--desktop]"
[[ "$URL" =~ ^https?:// ]] || URL="https://$URL"

# ── Preflight: alle Tools vorab prüfen (kein Crash mitten im Lauf) ──────────
echo "→ Preflight: Werkzeuge prüfen …"
declare -a MISSING=()
command -v jq   >/dev/null 2>&1 || MISSING+=("jq — Standard-CLI (apt install jq / brew install jq)")
command -v curl >/dev/null 2>&1 || MISSING+=("curl — Standard-CLI (apt install curl)")
command -v agent-browser >/dev/null 2>&1 || MISSING+=("agent-browser — npm i -g agent-browser && agent-browser install")
command -v lighthouse >/dev/null 2>&1 || MISSING+=("lighthouse — npm i -g lighthouse")
for f in "$CAPTURE" "$LH_AUDIT" "$BRAND" "$SCORE"; do
  [[ -f "$f" ]] || MISSING+=("Schritt-Skript fehlt: $f")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "✗ Voraussetzungen fehlen — Lauf nicht möglich. Bitte installieren:" >&2
  printf '   • %s\n' "${MISSING[@]}" >&2
  exit 2
fi
echo "  ✓ agent-browser · lighthouse · jq · curl"

# ── Run-Ordner bestimmen (NNN-Konvention wie capture.sh) ───────────────────
domain="$(printf '%s' "$URL" | sed -E 's#^https?://##; s#/.*$##; s#^www\.##; s#[^a-zA-Z0-9.-]#-#g')"
if [[ -z "$RUN_DIR" ]]; then
  today="$(date +%F)"
  n=1
  while :; do
    cand="runs/${today}-${domain}-$(printf '%03d' "$n")"
    [[ -e "$cand" ]] || { RUN_DIR="$cand"; break; }
    n=$((n+1))
  done
fi
mkdir -p "$RUN_DIR" || die_intern "Run-Ordner nicht anlegbar: $RUN_DIR"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STATUS_FINAL_URL="$URL"
trap on_signal INT TERM
echo "→ Run-Ordner: $RUN_DIR"
[[ "$INDUSTRY_SOURCE" == "auto" ]] && echo "  · Industrie-Tag nicht gesetzt — Claude schlägt ihn aus dem Seiteninhalt vor (Markierung: auto)."
[[ -n "$USER_PROMPT" ]] && echo "  · Nutzer-Kontext (--prompt): $USER_PROMPT"

CURRENT_PHASE="collect"
PH_STATUS[capture]=running; PH_STATUS[lighthouse]=running
write_status "running"

# ── Capture ∥ Lighthouse (beide brauchen nur die URL, gleicher Run-Ordner) ──
echo "→ Capture ∥ Lighthouse (parallel) …"
CAP_LOG="$RUN_DIR/.capture.log"; LH_LOG="$RUN_DIR/.lighthouse.log"
c_start="$(date +%s)"

bash "$CAPTURE" "$URL" --out "$RUN_DIR" --timeout "$TIMEOUT" >"$CAP_LOG" 2>&1 &
cap_pid=$!
lh_args=("$URL" --out "$RUN_DIR")
[[ "$DESKTOP" == true ]] && lh_args+=(--desktop)
bash "$LH_AUDIT" "${lh_args[@]}" >"$LH_LOG" 2>&1 &
lh_pid=$!

wait "$cap_pid"; cap_rc=$?
wait "$lh_pid"; lh_rc=$?
PH_DUR[capture]=$(( $(date +%s) - c_start ))
PH_DUR[lighthouse]=${PH_DUR[capture]}

# Finale URL aus capture meta.json übernehmen (für status/Kontext).
[[ -s "$RUN_DIR/meta.json" ]] && STATUS_FINAL_URL="$(jq -r '.final_url // .url // empty' "$RUN_DIR/meta.json")"

# ── Fehlerpolitik: Capture-Fehler ⇒ Abbruch ────────────────────────────────
if [[ $cap_rc -ne 0 ]]; then
  PH_STATUS[capture]=aborted
  cap_err="$(jq -r '.error // empty' "$RUN_DIR/meta.json" 2>/dev/null)"
  [[ -z "$cap_err" ]] && cap_err="$(tail -1 "$CAP_LOG" 2>/dev/null)"
  PH_ERR[capture]="${cap_err:-Capture fehlgeschlagen (Exit $cap_rc)}"
  PH_STATUS[lighthouse]=aborted
  CURRENT_PHASE="aborted"
  write_status "aborted"
  echo "✗ Capture fehlgeschlagen — nichts zu bewerten, Lauf abgebrochen." >&2
  echo "  Grund: ${PH_ERR[capture]}" >&2
  echo "  (Details: $CAP_LOG)" >&2
  exit 2
fi
PH_STATUS[capture]=ok
echo "  ✓ Capture ok"

# ── Inhalts-Gate: leere / Wartungs- / nicht-gerenderte Seite ⇒ Abbruch ──────
# Capture liefert HTTP 200, aber ohne sichtbaren Inhalt (Wartungsmodus,
# Coming-Soon, SPA ohne SSR) gibt es nichts zu bewerten. Bricht hier ab, statt
# in den Judge-Pausenpunkt zu laufen und dort endlos zu hängen.
cap_suspicion="$(jq -r '.content_suspicion // empty' "$RUN_DIR/meta.json" 2>/dev/null)"
if [[ "$cap_suspicion" == "spa_empty" ]]; then
  cap_note="$(jq -r '.notes[0] // empty' "$RUN_DIR/meta.json" 2>/dev/null)"
  PH_STATUS[capture]=aborted; PH_STATUS[lighthouse]=aborted
  PH_ERR[capture]="Seite ohne bewertbaren Inhalt (Wartungsmodus / Coming-Soon / SPA ohne SSR). ${cap_note}"
  CURRENT_PHASE="aborted"
  write_status "aborted"
  echo "✗ Seite ohne bewertbaren Inhalt — nichts zu bewerten, Lauf abgebrochen." >&2
  echo "  Grund: ${cap_note:-content_suspicion=spa_empty}" >&2
  echo "  (Screenshots liegen in $RUN_DIR/capture zur Sichtkontrolle.)" >&2
  exit 2
fi

# Lighthouse-Fehler ⇒ degradieren, weiterlaufen.
DEGRADED=false
lh_status="$(jq -r '.status // "failed"' "$RUN_DIR/lighthouse/lh-summary.json" 2>/dev/null)"
if [[ $lh_rc -ne 0 || "$lh_status" != "ok" ]]; then
  PH_STATUS[lighthouse]=degraded
  PH_ERR[lighthouse]="$(jq -r '.error // "Lighthouse fehlgeschlagen"' "$RUN_DIR/lighthouse/lh-summary.json" 2>/dev/null)"
  DEGRADED=true
  echo "  ⚠ Lighthouse nicht messbar — Performance/A11y werden im Report renormiert." >&2
else
  PH_STATUS[lighthouse]=ok
  echo "  ✓ Lighthouse ok"
fi
write_status "running"

# ── Branding (nach Capture — braucht die gerenderte Seite) ─────────────────
echo "→ Branding-Extraktion …"
CURRENT_PHASE="branding"; PH_STATUS[branding]=running; write_status "running"
BR_LOG="$RUN_DIR/.branding.log"
b_start="$(date +%s)"
brand_args=("$URL" --out "$RUN_DIR" --timeout "$TIMEOUT")
[[ -n "${BRANDFETCH_CLIENT_ID:-}" ]] && brand_args+=(--brandfetch-key "$BRANDFETCH_CLIENT_ID")
bash "$BRAND" "${brand_args[@]}" >"$BR_LOG" 2>&1
brand_rc=$?
PH_DUR[branding]=$(( $(date +%s) - b_start ))
if [[ $brand_rc -eq 0 ]]; then
  PH_STATUS[branding]=ok; echo "  ✓ Branding ok"
else
  PH_STATUS[branding]=degraded
  PH_ERR[branding]="$(jq -r '.error // .note // "Branding-Teilausfall"' "$RUN_DIR/branding/branding-meta.json" 2>/dev/null)"
  DEGRADED=true
  echo "  ⚠ Branding degradiert (kein Logo / leere Tokens) — Lauf läuft weiter." >&2
fi

# ── Kontext für den Judge-Pass + Finalize ablegen ──────────────────────────
CURRENT_PHASE="awaiting_judge"
write_status "awaiting_judge"
jq -n \
  --arg url "$URL" \
  --arg final_url "$STATUS_FINAL_URL" \
  --arg run_id "$(basename "$RUN_DIR")" \
  --arg industry "$INDUSTRY" \
  --arg industry_source "$INDUSTRY_SOURCE" \
  --arg prompt "$USER_PROMPT" \
  --arg started "$STARTED_AT" \
  --argjson desktop "$DESKTOP" \
  --arg rubric "$(cat "$ROOT/rubrics/VERSION" 2>/dev/null | head -1)" '
  { run_id: $run_id, url: $url, final_url: $final_url,
    industry_tag: ($industry|if .=="" then null else . end),
    industry_source: $industry_source,
    user_prompt: ($prompt|if .=="" then null else . end),
    desktop: $desktop, started_at: $started,
    rubric_version: $rubric }' > "$RUN_DIR/ui-check.json" 2>/dev/null || true

trap - INT TERM
dur=$(( $(date +%s) - $(date -d "$STARTED_AT" +%s 2>/dev/null || echo "$(date +%s)") ))
echo
echo "✓ Datenerfassung abgeschlossen → $RUN_DIR"
echo "  Bereit für den Judge-Pass (Claude erzeugt judge.json gegen rubrics/)."
echo "  Danach: ui-check.sh --finalize $RUN_DIR"
if [[ -s "$RUN_DIR/branding/tokens.json" ]]; then
  default_slug="$(jq -r '.final_url // .url // empty' "$RUN_DIR/ui-check.json" 2>/dev/null \
    | sed -E 's#^https?://##; s#^www\.##; s#/.*$##; s#[^A-Za-z0-9]+#-#g; s#^-+|-+$##' \
    | tr '[:upper:]' '[:lower:]')"
  [[ -z "$default_slug" ]] && default_slug="$(basename "$RUN_DIR" | sed -E 's#^[0-9]{4}-[0-9]{2}-[0-9]{2}-##; s#-[0-9]+$##')"
  echo "  Branding als Profil speichern:"
  echo "    node scripts/brand-lib.mjs save $RUN_DIR --slug $default_slug"
fi
[[ "$DEGRADED" == true ]] && exit 1
exit 0
