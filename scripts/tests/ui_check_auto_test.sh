#!/usr/bin/env bash
# Tests für ui-check-auto.sh — die End-to-End-Verkettung Collect → Judge → Finalize
# (PROJ-14). Fake-ui-check.sh + injizierter Judge (UI_CHECK_JUDGE_CMD), damit kein
# echter Browser / kein echtes LLM nötig ist. Die reale Collect/Finalize-Logik ist
# in ui_check_test.sh abgedeckt.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
AUTO="$ROOT/scripts/ui-check-auto.sh"
RV="$(head -1 "$ROOT/rubrics/VERSION")"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0; FAILURES=()
ok()  { PASS=$((PASS+1)); echo "  ✓ $1"; }
bad() { FAIL=$((FAIL+1)); FAILURES+=("$1"); echo "  ✗ $1"; }
assert_eq() { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }

# ── Fake ui-check.sh: emuliert Collect (awaiting_judge) und Finalize (done) ──
FAKEBIN="$WORK/bin"; mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/ui-check.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
mode="collect"; out=""
args=("$@")
for ((i=0;i<${#args[@]};i++)); do
  case "${args[$i]}" in
    --finalize) mode="finalize"; out="${args[$((i+1))]}" ;;
    --out)      out="${args[$((i+1))]}" ;;
  esac
done
mkdir -p "$out"
if [[ "$mode" == "collect" ]]; then
  if [[ "${STUB_COLLECT_RC:-0}" -eq 2 ]]; then
    jq -n '{status:"aborted",phase:"aborted",phases:{scoring:{status:"skipped"}}}' > "$out/status.json"
    exit 2
  fi
  jq -n '{status:"awaiting_judge",phase:"awaiting_judge",phases:{scoring:{status:"pending",error:null}}}' > "$out/status.json"
  exit "${STUB_COLLECT_RC:-0}"
fi
# finalize
jq -n '{status:"done",phase:"done",phases:{scoring:{status:"ok"}}}' > "$out/status.json"
jq -n '{total:71}' > "$out/scores.json"
exit "${STUB_FINALIZE_RC:-0}"
EOF
chmod +x "$FAKEBIN/ui-check.sh"

# ── Injizierter Judge: schreibt (valides) judge.json ────────────────────────
cat > "$FAKEBIN/judge-ok.sh" <<EOF
#!/usr/bin/env bash
jq -n --arg rv "$RV" '{rubric_version:\$rv,language_confident:true,app_mode:false,cta_present:true,
  visual:{score:70,findings:[]},ki_score:3,slop:{findings:[]},
  conversion:{clarity:70,credibility:70,logic:70,action:70,emotion:70,findings:[]}}' > "\$1/judge.json"
exit 0
EOF
cat > "$FAKEBIN/judge-fail.sh" <<'EOF'
#!/usr/bin/env bash
echo "JUDGE_FEHLER: absichtlich" >&2; exit 1
EOF
cat > "$FAKEBIN/judge-badjson.sh" <<'EOF'
#!/usr/bin/env bash
echo "kaputt {" > "$1/judge.json"; exit 0
EOF
cat > "$FAKEBIN/judge-wrongver.sh" <<'EOF'
#!/usr/bin/env bash
jq -n '{rubric_version:"1999.01-9",visual:{score:1},ki_score:1,
  conversion:{clarity:1,credibility:1,logic:1,action:1,emotion:1}}' > "$1/judge.json"; exit 0
EOF
chmod +x "$FAKEBIN"/judge-*.sh

run() { ( env UI_CHECK_SH="$FAKEBIN/ui-check.sh" "$@" bash "$AUTO" "${RUN_ARGS[@]}" ); }

echo "▶ A: Happy Path — Collect → Judge → Finalize, Exit 0, status=done"
RUN_ARGS=(https://ex.test --out "$WORK/a")
run UI_CHECK_JUDGE_CMD="$FAKEBIN/judge-ok.sh" >"$WORK/a.out" 2>&1
assert_eq "$?" "0" "Exit 0"
assert_eq "$(jq -r '.status' "$WORK/a/status.json")" "done" "status = done"
[[ -s "$WORK/a/judge.json" ]] && ok "judge.json erzeugt" || bad "judge.json fehlt"
[[ -s "$WORK/a/scores.json" ]] && ok "scores.json (Finalize lief)" || bad "scores.json fehlt"

echo; echo "▶ B: Collect-Abbruch (Exit 2) — kein Judge, kein Finalize"
RUN_ARGS=(https://ex.test --out "$WORK/b")
run STUB_COLLECT_RC=2 UI_CHECK_JUDGE_CMD="$FAKEBIN/judge-ok.sh" >"$WORK/b.out" 2>&1
assert_eq "$?" "2" "Exit 2 durchgereicht"
[[ ! -f "$WORK/b/judge.json" ]] && ok "kein judge.json nach Abbruch" || bad "judge.json trotz Abbruch"
[[ ! -f "$WORK/b/scores.json" ]] && ok "kein Finalize nach Abbruch" || bad "Finalize trotz Abbruch"

echo; echo "▶ C: Judge scheitert (Exit≠0) — status=error, Exit 3"
RUN_ARGS=(https://ex.test --out "$WORK/c")
run UI_CHECK_JUDGE_CMD="$FAKEBIN/judge-fail.sh" >"$WORK/c.out" 2>&1
assert_eq "$?" "3" "Exit 3"
assert_eq "$(jq -r '.status' "$WORK/c/status.json")" "error" "status = error (kein Hänger)"
assert_eq "$(jq -r '.phase' "$WORK/c/status.json")" "judge_failed" "phase = judge_failed"
[[ ! -f "$WORK/c/scores.json" ]] && ok "kein Finalize bei Judge-Fehler" || bad "Finalize trotz Judge-Fehler"

echo; echo "▶ D: Judge liefert ungültiges JSON — status=error, Exit 3"
RUN_ARGS=(https://ex.test --out "$WORK/d")
run UI_CHECK_JUDGE_CMD="$FAKEBIN/judge-badjson.sh" >"$WORK/d.out" 2>&1
assert_eq "$?" "3" "Exit 3"
assert_eq "$(jq -r '.status' "$WORK/d/status.json")" "error" "status = error"

echo; echo "▶ E: Judge mit falscher Rubrik-Version — status=error, Exit 3"
RUN_ARGS=(https://ex.test --out "$WORK/e")
run UI_CHECK_JUDGE_CMD="$FAKEBIN/judge-wrongver.sh" >"$WORK/e.out" 2>&1
assert_eq "$?" "3" "Exit 3"
grep -qi "Rubrik-Version" "$WORK/e.out" && ok "Meldung zur Rubrik-Version" || bad "Rubrik-Versions-Meldung fehlt"

echo; echo "▶ F: --no-judge — bleibt awaiting_judge, kein Judge, Exit 0"
RUN_ARGS=(https://ex.test --out "$WORK/f" --no-judge)
run UI_CHECK_JUDGE_CMD="$FAKEBIN/judge-ok.sh" >"$WORK/f.out" 2>&1
assert_eq "$?" "0" "Exit 0"
assert_eq "$(jq -r '.phase' "$WORK/f/status.json")" "awaiting_judge" "bleibt awaiting_judge"
[[ ! -f "$WORK/f/judge.json" ]] && ok "kein Judge bei --no-judge" || bad "Judge trotz --no-judge"

echo; echo "▶ G: Collect degradiert (Exit 1) — Judge läuft trotzdem, Exit 0"
RUN_ARGS=(https://ex.test --out "$WORK/g")
run STUB_COLLECT_RC=1 UI_CHECK_JUDGE_CMD="$FAKEBIN/judge-ok.sh" >"$WORK/g.out" 2>&1
assert_eq "$?" "0" "Exit 0 (Finalize ok)"
assert_eq "$(jq -r '.status' "$WORK/g/status.json")" "done" "status = done trotz degradiertem Collect"

echo; echo "──────────────────────────────────────────"
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}" >&2
  exit 1
fi
echo "✓ Alle Tests bestanden"
