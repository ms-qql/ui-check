#!/usr/bin/env bash
# Tests für redesign-auto.sh — Verkettung INIT → Generierung → Verify (PROJ-14).
# Fake redesign.sh + injizierter Generator (UI_REDESIGN_GEN_CMD).
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
AUTO="$ROOT/scripts/redesign-auto.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0; FAILURES=()
ok()  { PASS=$((PASS+1)); echo "  ✓ $1"; }
bad() { FAIL=$((FAIL+1)); FAILURES+=("$1"); echo "  ✗ $1"; }
assert_eq() { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }

FAKEBIN="$WORK/bin"; mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/redesign.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
mode="init"; dir=""
if [[ "${1:-}" == "--verify" ]]; then mode="verify"; dir="${2:-}"; else
  for a in "$@"; do [[ "$a" == --* ]] || { dir="$a"; break; }; done
fi
mkdir -p "$dir/redesign"
if [[ "$mode" == "init" ]]; then
  if [[ "${STUB_INIT_RC:-0}" -eq 2 ]]; then
    jq -n '{phases:{redesign:{status:"aborted"}}}' > "$dir/status.json"; exit 2
  fi
  jq -n '{phases:{redesign:{status:"awaiting_generation",error:null}}}' > "$dir/status.json"
  exit "${STUB_INIT_RC:-0}"
fi
jq -n '{phases:{redesign:{status:"ok",error:null}}}' > "$dir/status.json"
jq -n '{ok:8,warn:0,fail:0}' > "$dir/redesign/verify.json"
exit "${STUB_VERIFY_RC:-0}"
EOF
chmod +x "$FAKEBIN/redesign.sh"

cat > "$FAKEBIN/gen-ok.sh" <<'EOF'
#!/usr/bin/env bash
mkdir -p "$1/redesign/safe" "$1/redesign/bold"
echo "x" > "$1/redesign/safe/App.tsx"; echo "x" > "$1/redesign/bold/App.tsx"; exit 0
EOF
cat > "$FAKEBIN/gen-fail.sh" <<'EOF'
#!/usr/bin/env bash
echo "REDESIGN_FEHLER" >&2; exit 1
EOF
cat > "$FAKEBIN/gen-empty.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FAKEBIN"/gen-*.sh

run() { ( env REDESIGN_SH="$FAKEBIN/redesign.sh" "$@" bash "$AUTO" "${RUN_ARGS[@]}" ); }

echo "▶ A: Happy Path — INIT → Gen → Verify ok, Exit 0"
RUN_ARGS=("$WORK/a")
run UI_REDESIGN_GEN_CMD="$FAKEBIN/gen-ok.sh" >"$WORK/a.out" 2>&1
assert_eq "$?" "0" "Exit 0"
assert_eq "$(jq -r '.phases.redesign.status' "$WORK/a/status.json")" "ok" "phases.redesign = ok"
[[ -d "$WORK/a/redesign/safe" && -d "$WORK/a/redesign/bold" ]] && ok "safe/ + bold/ erzeugt" || bad "Varianten fehlen"
[[ -s "$WORK/a/redesign/verify.json" ]] && ok "verify.json vorhanden" || bad "verify.json fehlt"

echo; echo "▶ B: INIT-Abbruch (Exit 2) — keine Generierung"
RUN_ARGS=("$WORK/b")
run STUB_INIT_RC=2 UI_REDESIGN_GEN_CMD="$FAKEBIN/gen-ok.sh" >"$WORK/b.out" 2>&1
assert_eq "$?" "2" "Exit 2"
[[ ! -d "$WORK/b/redesign/safe" ]] && ok "keine Generierung nach Abbruch" || bad "Generierung trotz Abbruch"

echo; echo "▶ C: Generierung scheitert (Exit≠0) — phases.redesign=failed, Exit 3"
RUN_ARGS=("$WORK/c")
run UI_REDESIGN_GEN_CMD="$FAKEBIN/gen-fail.sh" >"$WORK/c.out" 2>&1
assert_eq "$?" "3" "Exit 3"
assert_eq "$(jq -r '.phases.redesign.status' "$WORK/c/status.json")" "failed" "phases.redesign = failed"

echo; echo "▶ D: Generierung ok, aber keine Varianten — failed, Exit 3"
RUN_ARGS=("$WORK/d")
run UI_REDESIGN_GEN_CMD="$FAKEBIN/gen-empty.sh" >"$WORK/d.out" 2>&1
assert_eq "$?" "3" "Exit 3"
assert_eq "$(jq -r '.phases.redesign.status' "$WORK/d/status.json")" "failed" "phases.redesign = failed"

echo; echo "▶ E: --no-gen — bleibt awaiting_generation, Exit 0"
RUN_ARGS=("$WORK/e" --no-gen)
run UI_REDESIGN_GEN_CMD="$FAKEBIN/gen-ok.sh" >"$WORK/e.out" 2>&1
assert_eq "$?" "0" "Exit 0"
assert_eq "$(jq -r '.phases.redesign.status' "$WORK/e/status.json")" "awaiting_generation" "bleibt awaiting_generation"

echo; echo "▶ F: Verify rot (Exit 2) — durchgereicht"
RUN_ARGS=("$WORK/f")
run STUB_VERIFY_RC=2 UI_REDESIGN_GEN_CMD="$FAKEBIN/gen-ok.sh" >"$WORK/f.out" 2>&1
assert_eq "$?" "2" "Verify-Exit 2 durchgereicht"

echo; echo "──────────────────────────────────────────"
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}" >&2
  exit 1
fi
echo "✓ Alle Tests bestanden"
