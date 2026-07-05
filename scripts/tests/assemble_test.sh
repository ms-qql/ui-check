#!/usr/bin/env bash
#
# assemble_test.sh — Black-Box-QA fuer scripts/assemble.sh (PROJ-13)
#
# Hermetisch: nutzt ein temporaeres Branding-Profil im Repo und die echte
# Registry-Auswahl, aber keinen Browser, kein Netz und kein Claude.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ASM="$ROOT/scripts/assemble.sh"
UC="$ROOT/scripts/ui-check.sh"
WORK="$(mktemp -d)"

cleanup() {
  rm -rf "$ROOT/branding/assemble-test" "$WORK"
}
trap cleanup EXIT

command -v jq >/dev/null 2>&1 || { echo "✗ jq nicht installiert"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "✗ node nicht installiert"; exit 1; }
chmod +x "$ASM"

PASS=0; FAIL=0; FAILURES=()
ok()  { PASS=$((PASS+1)); echo "  ✓ $*"; }
bad() { FAIL=$((FAIL+1)); FAILURES+=("$*"); echo "  ✗ $*" >&2; }
assert_eq() { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }
assert_file() { [[ -s "$1" ]] && ok "$2" || bad "$2 fehlt: $1"; }

mkdir -p "$ROOT/branding/assemble-test/v1"
jq -n '{color:{palette:{a:{"$value":"#112233","$extensions":{"uicheck.neutral":true}},
                         b:{"$value":"#f8fafc","$extensions":{"uicheck.neutral":true}}},
                 primary:{"$value":"#2563eb"},surface:{"$value":"#ffffff"},text:{"$value":"#111827"}},
        font:{display:{"$value":["Inter"]}}}' > "$ROOT/branding/assemble-test/v1/tokens.json"
printf '@theme {\n  --color-primary: #2563eb;\n  --color-surface: #ffffff;\n  --color-text: #111827;\n  --font-sans: Inter, sans-serif;\n}\n' \
  > "$ROOT/branding/assemble-test/v1/tailwind-theme.css"
printf '# Assemble Test\n' > "$ROOT/branding/assemble-test/v1/branding.md"
ln -sfn v1 "$ROOT/branding/assemble-test/current"

run_asm() { (cd "$ROOT" && bash "$ASM" "$@" >"$WORK/assemble.out" 2>&1); }

FAKE_EXPORT="$WORK/mockup-export.sh"
cat > "$FAKE_EXPORT" <<'EOF'
#!/usr/bin/env bash
run="$1"
printf '<!doctype html><title>Mockup</title><main>ok</main>\n' > "$run/mockup.html"
mkdir -p "$run/mockup"
jq -n '{summary:{fail:0,warn:0},gates:[]}' > "$run/mockup/gates.json"
exit 0
EOF
chmod +x "$FAKE_EXPORT"

echo "═══ A) Happy Path: Scaffold, Content, Registry-Auswahl ═══"
R="$WORK/run-a"
run_asm --branding assemble-test --industry saas --sections hero,trust,pricing,cta --prompt "B2B SaaS fuer Incident-Teams" --out "$R" --no-export
assert_eq "$?" "1" "assemble Exit 1 bei Generierungs-Fallback"
assert_file "$R/redesign/shared/content.json" "content.json erzeugt"
assert_file "$R/redesign/shared/tokens.json" "tokens kopiert"
assert_file "$R/redesign/redesign-context.json" "redesign-context.json erzeugt"
assert_file "$R/redesign/registry-selection.safe.json" "safe registry-selection"
assert_file "$R/redesign/registry-selection.bold.json" "bold registry-selection"
assert_file "$R/redesign/registry/registry-tokens.css" "registry Token-Alias"
assert_file "$R/redesign/verify.json" "verify.json erzeugt"
assert_file "$R/redesign/safe/App.jsx" "safe Starter-App erzeugt"
assert_file "$R/redesign/bold/App.jsx" "bold Starter-App erzeugt"
assert_eq "$(jq -r '.mode' "$R/redesign/redesign-context.json")" "assemble" "Kontext mode=assemble"
assert_eq "$(jq -r '.branding' "$R/ui-check.json")" "assemble-test" "ui-check.json Branding"
assert_eq "$(jq -r '.sections | length' "$R/redesign/shared/content.json")" "4" "vier Sektionen im Plan"
assert_eq "$(jq -r '.status' "$R/status.json")" "awaiting_generation" "status awaiting_generation"
assert_eq "$(jq -r '.stats.registry > 0' "$R/redesign/registry-selection.bold.json")" "true" "bold nutzt Registry"
[[ ! -e "$R/mockup.html" ]] && ok "--no-export erzeugt kein mockup.html" || bad "--no-export hat mockup.html erzeugt"

echo "═══ B) Registry-only: fehlende Sektion bricht hart ab ═══"
R="$WORK/run-b"
run_asm --branding assemble-test --industry saas --sections definitely-missing --registry-only --out "$R" --no-export
assert_eq "$?" "2" "registry-only ohne Block → Exit 2"
assert_file "$R/redesign/registry-selection.safe.json" "Fehler-Auswahl dokumentiert"

echo "═══ C) Industrie-Filter: unbekannte Industrie fällt komplett zurück ═══"
R="$WORK/run-c"
(cd "$ROOT" && bash "$ASM" --branding assemble-test --industry unknown-industry --sections hero,cta --out "$R" --no-export >"$WORK/unknown.out" 2>&1)
assert_eq "$?" "1" "unbekannte Industrie → Exit 1 (Fallback)"
assert_eq "$(jq -r '.stats.generate' "$R/redesign/registry-selection.safe.json")" "2" "safe: alle Sektionen generieren"
assert_eq "$(jq -r '.stats.generate' "$R/redesign/registry-selection.bold.json")" "2" "bold: alle Sektionen generieren"

echo "═══ D) ui-check --assemble delegiert korrekt ═══"
R="$WORK/run-d"
(cd "$ROOT" && bash "$UC" --assemble --branding assemble-test --industry saas --sections hero,cta --out "$R" --no-export >"$WORK/ui-assemble.out" 2>&1)
assert_eq "$?" "1" "ui-check --assemble reicht Fallback-Exit 1 durch"
assert_file "$R/redesign/shared/content.json" "ui-check Delegation erzeugt Run"
assert_eq "$(jq -r '.mode' "$R/ui-check.json")" "assemble" "Delegation schreibt assemble-Kontext"

echo "═══ E) Default: Verify + Mockup-Export laufen ═══"
R="$WORK/run-e"
(cd "$ROOT" && MOCKUP_EXPORT_SH="$FAKE_EXPORT" bash "$ASM" --branding assemble-test --industry saas --sections hero,cta --out "$R" >"$WORK/export.out" 2>&1)
assert_eq "$?" "1" "Default mit Export-Stub → Exit 1 bei Fallback"
assert_file "$R/redesign/verify.json" "Default erzeugt verify.json"
assert_file "$R/mockup.html" "Default erzeugt mockup.html"

echo
echo "════════════════════════════════════════"
echo "  Ergebnis: $PASS bestanden · $FAIL fehlgeschlagen"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}" >&2
  exit 1
fi
echo "  ✓ Alle Tests gruen."
