#!/usr/bin/env bash
# redesign-auto.sh — End-to-End-Redesign für Jupiter (PROJ-14).
#
# Verkettet die Stufe-2-Redesign-Generierung in EINEM detached Prozess, den
# Jupiter startet und über status.json (phases.redesign) verfolgt:
#
#   1. INIT      redesign.sh <run-dir>        → Scaffold, phases.redesign = awaiting_generation
#   2. GENERATE  headless Claude (ui-redesign)→ brief/content/safe/bold/images
#   3. VERIFY    redesign.sh --verify <run-dir>→ verify.json + phases.redesign = ok|degraded|failed
#
# Grund: redesign.sh pausiert nach dem Scaffold bewusst bei awaiting_generation —
# die eigentliche Generierung macht Claude (Skill ui-redesign). Ohne diesen Treiber
# wurde sie headless nie ausgelöst, das Redesign blieb leer.
#
# Exit-Codes: 0 ok · 1 degradiert · 2 Abbruch (INIT-Gate) · 3 Generierung fehlgeschlagen.
#
# Testbarkeit:
#   REDESIGN_SH          Pfad zu redesign.sh (Default: neben diesem Skript)
#   UI_REDESIGN_GEN_CMD  Ersatz-Generator statt echtem Claude; erhält <run-dir> als $1.
#   CLAUDE_BIN / UI_REDESIGN_GEN_MODEL / UI_REDESIGN_GEN_TIMEOUT
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
RS="${REDESIGN_SH:-$HERE/redesign.sh}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
GEN_MODEL="${UI_REDESIGN_GEN_MODEL:-sonnet}"
GEN_TIMEOUT="${UI_REDESIGN_GEN_TIMEOUT:-1800}"

die() { echo "✗ $*" >&2; exit 2; }

INIT_ARGS=()
RUN_DIR=""
DO_GEN=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gen-model) GEN_MODEL="${2:-}"; shift 2 ;;
    --no-gen)    DO_GEN=false; shift ;;
    --force)     INIT_ARGS+=(--force); shift ;;
    *)           if [[ -z "$RUN_DIR" ]]; then RUN_DIR="$1"; INIT_ARGS=("$1" "${INIT_ARGS[@]}"); else INIT_ARGS+=("$1"); fi; shift ;;
  esac
done
[[ -n "$RUN_DIR" ]] || die "Kein Run-Ordner angegeben."

mark_failed() { # $1 = Meldung
  local dir="$RUN_DIR" msg="$1"
  [[ -f "$dir/status.json" ]] || return 0
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq --arg ts "$ts" --arg msg "$msg" '
    .phases.redesign = {status:"failed", error:$msg} | .updated_at=$ts
  ' "$dir/status.json" > "$dir/status.json.tmp" 2>/dev/null \
    && mv "$dir/status.json.tmp" "$dir/status.json"
}

# ── 1. INIT (Scaffold) ──────────────────────────────────────────────────────
bash "$RS" "${INIT_ARGS[@]}"
init_rc=$?
if [[ $init_rc -eq 2 ]]; then
  echo "✗ Redesign-INIT abgebrochen (Exit 2) — keine Generierung." >&2
  exit 2
fi

phase="$(jq -r '.phases.redesign.status // empty' "$RUN_DIR/status.json" 2>/dev/null)"
if [[ "$phase" != "awaiting_generation" ]]; then
  echo "✗ Unerwarteter Zustand nach INIT (redesign=$phase) — keine Generierung." >&2
  exit "${init_rc:-1}"
fi

if [[ "$DO_GEN" != true ]]; then
  echo "→ --no-gen: Scaffold steht, Generierung bleibt manuell."
  exit "$init_rc"
fi

# ── 2. GENERATE (headless Claude, ui-redesign-Skill) ────────────────────────
echo "→ Redesign-Generierung (headless Claude, Modell: $GEN_MODEL) …"
gen_prompt="Du führst die Stufe-2-Redesign-Generierung des Skills ui-redesign aus \
(.claude/skills/ui-redesign/SKILL.md). Das Scaffold für den Lauf '$RUN_DIR' ist bereits \
angelegt (INIT lief) — führe NICHT erneut 'redesign.sh <run-dir>' ohne --verify aus.

Erzeuge für '$RUN_DIR' beide buildfähigen Varianten strikt nach Skill + Rezepten (recipes/safe.md, recipes/bold.md):
1. Brief-Pass    → '$RUN_DIR/redesign/brief.md'
2. Content-Pass  → '$RUN_DIR/redesign/shared/content.json' + '$RUN_DIR/redesign/compare.json'
3. Visual-Pass ×2 → '$RUN_DIR/redesign/safe/' (konservatives Facelift) und '$RUN_DIR/redesign/bold/' (mutige Neuinterpretation) + '$RUN_DIR/redesign/images.md'
Kontext: '$RUN_DIR/redesign/redesign-context.json' (Scores, Befunde, Nutzer-Prompt, Branding-Tokens).

Danach laufe 'scripts/redesign.sh --verify $RUN_DIR' und behebe rote Pflicht-Gates im ZUSTÄNDIGEN Pass \
(Content-Fehler im Content, Farb-/Token-Fehler im Visual-Pass), bis alle Pflicht-Gates grün sind — Gates nie umgehen. \
Nutze echte deutsche Umlaute (ä ö ü Ä Ö Ü ß), keine Google-Fonts-CDN. Antworte am Ende nur mit 'REDESIGN_OK' oder 'REDESIGN_FEHLER: <grund>'."

if [[ -n "${UI_REDESIGN_GEN_CMD:-}" ]]; then
  "$UI_REDESIGN_GEN_CMD" "$RUN_DIR"
  gen_rc=$?
else
  timeout "$GEN_TIMEOUT" "$CLAUDE_BIN" -p "$gen_prompt" \
    --model "$GEN_MODEL" --dangerously-skip-permissions >"$RUN_DIR/.redesign.log" 2>&1
  gen_rc=$?
fi

if [[ $gen_rc -ne 0 ]]; then
  mark_failed "Redesign-Generierung fehlgeschlagen (Exit $gen_rc). Details: $RUN_DIR/.redesign.log"
  echo "✗ Redesign-Generierung fehlgeschlagen (Exit $gen_rc)." >&2; exit 3
fi
if [[ ! -d "$RUN_DIR/redesign/safe" || ! -d "$RUN_DIR/redesign/bold" ]]; then
  mark_failed "Redesign-Generierung erzeugte keine safe/- und bold/-Varianten."
  echo "✗ Varianten fehlen nach der Generierung." >&2; exit 3
fi

# ── 3. VERIFY (Gates, kanonischer Status) ───────────────────────────────────
echo "→ Redesign-Verify (Gates) …"
bash "$RS" --verify "$RUN_DIR"
exit $?
