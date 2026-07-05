#!/usr/bin/env bash
#
# brand_lib_test.sh — Black-Box-QA fuer scripts/brand-lib.mjs (PROJ-12)
#
# Nutzung: scripts/tests/brand_lib_test.sh

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BL="$ROOT/scripts/brand-lib.mjs"
WORK="$(mktemp -d)"
BACKUP="$WORK/branding.backup"

command -v jq >/dev/null 2>&1 || { echo "✗ jq nicht installiert"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "✗ node nicht installiert"; exit 1; }

restore() {
  rm -rf "$ROOT/branding"
  if [[ -d "$BACKUP" ]]; then
    cp -a "$BACKUP" "$ROOT/branding"
  fi
  rm -rf "$WORK"
}
trap restore EXIT

cp -a "$ROOT/branding" "$BACKUP"

PASS=0; FAIL=0
declare -a FAILURES=()
ok()  { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $*" >&2; FAIL=$((FAIL+1)); FAILURES+=("$*"); }
assert_eq() { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }
assert_file() { [[ -s "$1" ]] && ok "$2" || bad "$2 fehlt: $1"; }

run_bl() { (cd "$ROOT" && node "$BL" "$@" >"$WORK/brand-lib.out" 2>&1); }

mk_run() {
  local r="$1"
  mkdir -p "$r/branding"
  jq -n '{run_id:"x",url:"https://example.test",final_url:"https://example.test/",industry_tag:"saas"}' > "$r/ui-check.json"
  jq -n '{color:{palette:[{hex:"#112233"}],primary:{"$value":"#112233"},surface:{"$value":"#ffffff"},text:{"$value":"#111827"}},
          font:{display:"Inter"}}' > "$r/branding/tokens.json"
  printf '@theme {\n  --color-primary: #112233;\n  --color-surface: #ffffff;\n  --color-text: #111827;\n}\n' > "$r/branding/tailwind-theme.css"
  printf '# Branding\n\nTonalitaet test.\n' > "$r/branding/branding.md"
  printf '<svg xmlns="http://www.w3.org/2000/svg"></svg>\n' > "$r/branding/logo.svg"
  jq -n '{status:"ok",logo:{source:"dom"}}' > "$r/branding/branding-meta.json"
}

echo "═══ A) list: migriert bestehende flache Profile ═══"
run_bl list
assert_eq "$?" "0" "list Exit 0"
assert_file "$ROOT/branding/index.json" "index.json erzeugt"
assert_file "$ROOT/branding/index.html" "index.html erzeugt"
assert_file "$ROOT/branding/verdict/profile.json" "verdict profile.json"
[[ -L "$ROOT/branding/verdict/current" ]] && ok "verdict current-Symlink" || bad "verdict current-Symlink fehlt"
assert_file "$ROOT/branding/verdict/v1/tokens.json" "verdict v1 tokens"
assert_eq "$(jq -r '.profiles[] | select(.slug=="verdict") | .active_version' "$ROOT/branding/index.json")" "v1" "index: verdict aktiv v1"

echo "═══ A2) list: index.html escaped Profilmetadaten script-sicher ═══"
mkdir -p "$ROOT/branding/xss-test/v1"
jq -n '{color:{primary:{"$type":"color","$value":"#112233"}}}' > "$ROOT/branding/xss-test/v1/tokens.json"
printf '@theme { --color-primary: #112233; }\n' > "$ROOT/branding/xss-test/v1/tailwind-theme.css"
ln -sfn v1 "$ROOT/branding/xss-test/current"
jq -n --arg name '</script><script>window.__qa_xss=1</script>' \
  '{slug:"xss-test",name:$name,source:"manuell",active_version:"v1",versions:[{version:"v1"}],tags:[]}' \
  > "$ROOT/branding/xss-test/profile.json"
run_bl list
if grep -F '</script><script>window.__qa_xss=1</script>' "$ROOT/branding/index.html" >/dev/null; then
  bad "index.html enthält rohes </script> aus Profilmetadaten"
else
  ok "index.html escaped </script> in Profilmetadaten"
fi
grep -F '\u003c/script\u003e' "$ROOT/branding/index.html" >/dev/null \
  && ok "index.html enthält escaped Script-Sequenz" || bad "escaped Script-Sequenz fehlt"
rm -rf "$ROOT/branding/xss-test"
run_bl list >/dev/null

echo "═══ B) seed: Auxevo aus Hal 00 Context ═══"
run_bl seed
assert_eq "$?" "0" "seed Exit 0"
assert_file "$ROOT/branding/auxevo/profile.json" "auxevo profile.json"
assert_file "$ROOT/branding/auxevo/current/tokens.json" "auxevo tokens"
assert_file "$ROOT/branding/auxevo/current/logo.svg" "auxevo logo"
assert_eq "$(jq -r '.source' "$ROOT/branding/auxevo/profile.json")" "seed" "auxevo source seed"
assert_eq "$(jq -r '.profiles[] | select(.slug=="auxevo") | .name' "$ROOT/branding/index.json")" "Auxevo" "index: auxevo"

echo "═══ C) save: Run-Branding als versioniertes Profil ═══"
R="$WORK/run-a"; mk_run "$R"
run_bl save "$R" --slug customer
assert_eq "$?" "0" "save Exit 0"
assert_file "$ROOT/branding/customer/v1/tokens.json" "customer v1 tokens"
assert_eq "$(jq -r '.active_version' "$ROOT/branding/customer/profile.json")" "v1" "customer active v1"
run_bl save "$R" --slug customer
assert_eq "$?" "0" "save zweiter Lauf Exit 0"
assert_file "$ROOT/branding/customer/v2/tokens.json" "customer v2 tokens"
assert_eq "$(jq -r '.active_version' "$ROOT/branding/customer/profile.json")" "v2" "customer active v2"

echo "═══ D) save: kein stilles Überschreiben bei expliziter Version ═══"
run_bl save "$R" --slug customer --as v2
assert_eq "$?" "2" "save --as bestehende Version bricht ab"

echo
echo "════════════════════════════════════════"
echo "  Ergebnis: $PASS bestanden · $FAIL fehlgeschlagen"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}"
  exit 1
fi
echo "  ✓ Alle Tests grün."
exit 0
