#!/usr/bin/env bash
# ui-check-auto.sh — End-to-End-Treiber für Jupiter (PROJ-14).
#
# Verkettet die drei Stufen des UI-Checks in EINEM detached Prozess, den Jupiter
# startet und nur über status.json verfolgt:
#
#   1. COLLECT   ui-check.sh <url> …        → Artefakte, status = awaiting_judge
#   2. JUDGE     headless Claude            → <run-dir>/judge.json (Bewertung)
#   3. FINALIZE  ui-check.sh --finalize …   → scores.json + report.md, status = done
#
# Grund: der Judge-Pass (Claude) war bislang NICHT verdrahtet — Läufe blieben in
# der Jupiter-UI ewig auf „Läuft" (status.json = awaiting_judge). Dieses Skript
# löst den Judge-Pass headless aus. Schlägt er fehl, wird status = error gesetzt
# (kein stiller Hänger mehr).
#
# Fehlerpolitik / Exit-Codes (durchgereicht vom jeweiligen Schritt):
#   0  ok          · 1  degradiert (nutzbar) · 2  Abbruch (Collect-Gate)
#   3  Judge-Pass fehlgeschlagen (status = error)
#
# Testbarkeit:
#   UI_CHECK_SH         Pfad zu ui-check.sh (Default: neben diesem Skript)
#   UI_CHECK_JUDGE_CMD  ausführbares Kommando statt echtem Claude; erhält <run-dir>
#                       als $1 und muss judge.json schreiben.
#   CLAUDE_BIN          Claude-CLI (Default: claude)
#   UI_CHECK_JUDGE_MODEL / UI_CHECK_JUDGE_TIMEOUT  Modell / Timeout (s) des Judge-Laufs.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
UC="${UI_CHECK_SH:-$HERE/ui-check.sh}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
JUDGE_MODEL="${UI_CHECK_JUDGE_MODEL:-sonnet}"
JUDGE_TIMEOUT="${UI_CHECK_JUDGE_TIMEOUT:-600}"

die() { echo "✗ $*" >&2; exit 2; }

# ── Argumente: alles an Collect durchreichen, Auto-Flags herausfiltern ───────
COLLECT_ARGS=()
RUN_DIR=""
INDUSTRY=""
DO_JUDGE=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)          RUN_DIR="${2:-}"; COLLECT_ARGS+=(--out "${2:-}"); shift 2 ;;
    --industry)     INDUSTRY="${2:-}"; COLLECT_ARGS+=(--industry "${2:-}"); shift 2 ;;
    --judge-model)  JUDGE_MODEL="${2:-}"; shift 2 ;;
    --no-judge)     DO_JUDGE=false; shift ;;
    *)              COLLECT_ARGS+=("$1"); shift ;;
  esac
done

# ── status.json → error (kein Hänger, wenn der Judge-Pass scheitert) ─────────
mark_error() { # $1 = Meldung
  local dir="$RUN_DIR" msg="$1"
  [[ -n "$dir" && -f "$dir/status.json" ]] || return 0
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq --arg ts "$ts" --arg msg "$msg" '
    .status="error" | .phase="judge_failed" | .updated_at=$ts |
    .phases.scoring.status="failed" | .phases.scoring.error=$msg
  ' "$dir/status.json" > "$dir/status.json.tmp" 2>/dev/null \
    && mv "$dir/status.json.tmp" "$dir/status.json"
}

# ── 1. COLLECT ──────────────────────────────────────────────────────────────
bash "$UC" "${COLLECT_ARGS[@]}"
collect_rc=$?

# Run-Ordner ableiten, falls ohne --out gelaufen (ui-check.sh legt runs/… an).
if [[ -z "$RUN_DIR" ]]; then
  RUN_DIR="$(ls -dt "$ROOT"/runs/*/ 2>/dev/null | head -1)"
  RUN_DIR="${RUN_DIR%/}"
fi

# Collect-Abbruch (Gate: leere/Wartungsseite, Capture-Fehler, Tool fehlt) → Stopp.
if [[ $collect_rc -eq 2 ]]; then
  echo "✗ Collect abgebrochen (Exit 2) — kein Judge-Pass." >&2
  exit 2
fi

phase="$(jq -r '.phase // empty' "$RUN_DIR/status.json" 2>/dev/null)"
if [[ "$phase" != "awaiting_judge" ]]; then
  echo "✗ Unerwarteter Zustand nach Collect (phase=$phase) — kein Judge-Pass." >&2
  exit "${collect_rc:-1}"
fi

if [[ "$DO_JUDGE" != true ]]; then
  echo "→ --no-judge: Lauf bleibt bei awaiting_judge (manueller Judge-Pass)."
  exit "$collect_rc"
fi

# ── 2. JUDGE (headless Claude → judge.json) ─────────────────────────────────
echo "→ Judge-Pass (headless Claude, Modell: $JUDGE_MODEL) …"
judge_prompt="Du bist der Judge-Pass des UI-Check-Skills (.claude/skills/ui-check/SKILL.md, Abschnitt 3). \
Bewerte den bereits erfassten Lauf im Ordner '$RUN_DIR' gegen die Rubriken in 'rubrics/' und schreibe das \
Ergebnis nach '$RUN_DIR/judge.json'.

Vorgehen:
1. Lies rubrics/VERSION, rubrics/visual.md, rubrics/slop.md, rubrics/conversion.md — die Anker-Bänder sind bindend, streng zuordnen.
2. Lies die Artefakte: '$RUN_DIR/capture/shot-375.png', 'shot-768.png', 'shot-1440.png' (Screenshots), '$RUN_DIR/capture/snapshot.txt', '$RUN_DIR/capture/dom-meta.json', '$RUN_DIR/branding/branding.md' und '$RUN_DIR/ui-check.json' (Nutzer-Kontext im Feld user_prompt berücksichtigen).
3. Schreibe EXAKT den Kontrakt nach '$RUN_DIR/judge.json': rubric_version (MUSS rubrics/VERSION entsprechen), language_confident, app_mode, cta_present, visual{score 0-100, findings[]}, ki_score 0-10 (roh), slop{findings[]}, conversion{clarity,credibility,logic,action,emotion je 0-100, findings[]}. Jeder Befund: {title, severity: hoch|mittel|niedrig, evidence, location, source}. KEIN Befund ohne sichtbaren Beleg + Fundort.
4. Führe KEIN Finalize aus. Nutze echte deutsche Umlaute (ä ö ü Ä Ö Ü ß), keine ASCII-Umschreibungen. Antworte am Ende nur mit 'JUDGE_OK' oder 'JUDGE_FEHLER: <grund>'."

if [[ -n "${UI_CHECK_JUDGE_CMD:-}" ]]; then
  # Test-/Ersatz-Judge: erhält den Run-Ordner, schreibt judge.json selbst.
  "$UI_CHECK_JUDGE_CMD" "$RUN_DIR"
  judge_rc=$?
else
  # stdout UND stderr ins Log — die claude-CLI meldet z. B. ein unbekanntes Modell
  # auf stdout; ginge das nach /dev/null, wäre die Fehlerursache unsichtbar.
  timeout "$JUDGE_TIMEOUT" "$CLAUDE_BIN" -p "$judge_prompt" \
    --model "$JUDGE_MODEL" --dangerously-skip-permissions >"$RUN_DIR/.judge.log" 2>&1
  judge_rc=$?
fi

# Judge-Ergebnis prüfen: judge.json muss existieren, gültiges JSON, rubric_version passen.
rubric_v="$(head -1 "$ROOT/rubrics/VERSION" 2>/dev/null)"
if [[ $judge_rc -ne 0 ]]; then
  mark_error "Judge-Pass fehlgeschlagen (Exit $judge_rc). Details: $RUN_DIR/.judge.log"
  echo "✗ Judge-Pass fehlgeschlagen (Exit $judge_rc)." >&2; exit 3
fi
if ! jq -e . "$RUN_DIR/judge.json" >/dev/null 2>&1; then
  mark_error "Judge-Pass erzeugte kein gültiges judge.json."
  echo "✗ judge.json fehlt oder ungültig." >&2; exit 3
fi
judge_v="$(jq -r '.rubric_version // empty' "$RUN_DIR/judge.json" 2>/dev/null)"
if [[ -n "$rubric_v" && "$judge_v" != "$rubric_v" ]]; then
  mark_error "judge.json rubric_version ($judge_v) ≠ rubrics/VERSION ($rubric_v)."
  echo "✗ Rubrik-Version passt nicht ($judge_v ≠ $rubric_v)." >&2; exit 3
fi
echo "  ✓ judge.json erzeugt"

# ── 3. FINALIZE (Scoring & Report) ──────────────────────────────────────────
echo "→ Finalize (Scoring & Report) …"
finalize_args=(--finalize "$RUN_DIR")
[[ -n "$INDUSTRY" ]] && finalize_args+=(--industry "$INDUSTRY")
bash "$UC" "${finalize_args[@]}"
exit $?
