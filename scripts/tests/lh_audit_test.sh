#!/usr/bin/env bash
#
# lh_audit_test.sh — Black-Box-QA-Suite für scripts/lh-audit.sh (PROJ-2)
#
# Läuft echtes Lighthouse gegen lokale Fixtures (serve_fixtures.py) — kein
# Internet, aber echter Chrome. Prüft Acceptance Criteria + Edge Cases von
# PROJ-2. Lighthouse-Läufe sind langsam (~15–25 s), daher wenige, gezielte Fälle.
#
# Nutzung:  scripts/tests/lh_audit_test.sh
# Exit 0 = alle Tests bestanden · 1 = mindestens ein Fehlschlag.

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
LH="$ROOT/scripts/lh-audit.sh"
SERVER="$HERE/serve_fixtures.py"
PORT="${FIXTURE_PORT:-8977}"
BASE="http://127.0.0.1:$PORT"
WORK="$(mktemp -d)"

if [[ -x "$HOME/miniconda3/envs/Dashboard/bin/python3" ]]; then
  PY="$HOME/miniconda3/envs/Dashboard/bin/python3"
elif command -v conda >/dev/null 2>&1; then
  PY="conda run -n Dashboard --no-capture-output python"
else
  PY="python3"
fi

# Chrome für Lighthouse (falls nicht gesetzt) — Playwright-Chromium bevorzugen.
if [[ -z "${CHROME_PATH:-}" ]]; then
  for c in chrome google-chrome chromium chromium-browser; do
    command -v "$c" >/dev/null 2>&1 && { export CHROME_PATH="$(command -v "$c")"; break; }
  done
fi

PASS=0; FAIL=0
declare -a FAILURES=()
ok()  { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $*" >&2; FAIL=$((FAIL+1)); FAILURES+=("$*"); }
assert_eq()   { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }
assert_file() { [[ -s "$1" ]] && ok "$2" || bad "$2 — Datei fehlt/leer: $1"; }
sj() { jq -r "$1" "$2/lighthouse/lh-summary.json" 2>/dev/null; }

# ── Preflight: Tools vorhanden? ────────────────────────────────────────────
command -v lighthouse >/dev/null 2>&1 || { echo "✗ lighthouse nicht installiert (npm i -g lighthouse)"; exit 1; }
[[ -n "${CHROME_PATH:-}" ]] || { echo "✗ Kein Chrome gefunden (CHROME_PATH setzen)"; exit 1; }

# ── Fixture-Server starten ─────────────────────────────────────────────────
echo "→ Starte Fixture-Server ($BASE) …"
SRV_LOG="$WORK/server.log"
$PY "$SERVER" "$PORT" >"$SRV_LOG" 2>&1 &
SRV_PID=$!
cleanup() { kill "$SRV_PID" >/dev/null 2>&1; rm -rf "$WORK"; }
trap cleanup EXIT
for _ in $(seq 1 50); do grep -q "READY" "$SRV_LOG" 2>/dev/null && break; sleep 0.2; done
grep -q "READY" "$SRV_LOG" || { echo "✗ Server nicht gestartet:"; cat "$SRV_LOG"; exit 1; }
curl -sf "$BASE/normal" >/dev/null || { echo "✗ Server antwortet nicht"; exit 1; }

# ── AC-Gruppe A: Happy Path (Mobile + Desktop) ─────────────────────────────
echo; echo "▶ A: Happy Path /normal (--desktop)"
R="$WORK/normal"
# capture-meta mit undismissed Cookie-Banner vorbereiten → Spiegelung prüfen
mkdir -p "$R"; echo '{"cookie_banner":{"dismissed":false,"method":null}}' > "$R/meta.json"
bash "$LH" "$BASE/normal" --out "$R" --desktop --timeout 90 >"$WORK/normal.out" 2>&1
assert_eq "$?" "0" "Exit-Code 0"
assert_file "$R/lighthouse/lighthouse-mobile.json"  "lighthouse-mobile.json erzeugt"
assert_file "$R/lighthouse/lighthouse-desktop.json" "lighthouse-desktop.json erzeugt (--desktop)"
assert_file "$R/lighthouse/lh-summary.json"         "lh-summary.json erzeugt"
assert_eq "$(sj '.status' "$R")" "ok" "status == ok"
# 4 Kategorie-Scores 0–100
for k in performance accessibility best_practices seo; do
  v="$(sj ".scores.$k" "$R")"
  [[ "$v" =~ ^[0-9]+$ ]] && [[ "$v" -ge 0 && "$v" -le 100 ]] && ok "scores.$k in 0–100 ($v)" || bad "scores.$k ungültig: $v"
done
# CWV-Rohwerte + Bewertung
for m in lcp cls tbt fcp speed_index; do
  r="$(sj ".core_web_vitals.$m.rating" "$R")"
  [[ "$r" == "good" || "$r" == "needs-improvement" || "$r" == "poor" || "$r" == "unknown" ]] \
    && ok "core_web_vitals.$m.rating gültig ($r)" || bad "core_web_vitals.$m.rating ungültig: $r"
done
[[ "$(sj '.core_web_vitals.lcp.value_ms' "$R")" =~ ^[0-9]+$ ]] && ok "lcp.value_ms numerisch" || bad "lcp.value_ms fehlt"
# Opportunities max. 5
opp="$(sj '(.opportunities | length)' "$R")"
[[ "$opp" =~ ^[0-9]+$ ]] && [[ "$opp" -le 5 ]] && ok "opportunities ≤ 5 ($opp)" || bad "opportunities-Anzahl ungültig: $opp"
# form_factors + Desktop-Block
assert_eq "$(sj '(.form_factors | join(","))' "$R")" "mobile,desktop" "form_factors == mobile,desktop"
[[ "$(sj '.desktop.scores.performance' "$R")" =~ ^[0-9]+$ ]] && ok "desktop.scores vorhanden" || bad "desktop.scores fehlt"
# Meta-Felder
[[ "$(sj '.timestamp' "$R")" =~ ^2[0-9]{3}-[0-9]{2}-[0-9]{2}T ]] && ok "timestamp ISO-8601" || bad "timestamp fehlt"
[[ "$(sj '.duration_seconds' "$R")" =~ ^[0-9]+$ ]] && ok "duration_seconds numerisch" || bad "duration_seconds fehlt"
[[ -n "$(sj '.lighthouse_version' "$R")" && "$(sj '.lighthouse_version' "$R")" != "null" ]] && ok "lighthouse_version gesetzt" || bad "lighthouse_version fehlt"
# Cookie-Banner-Spiegelung aus PROJ-1
assert_eq "$(sj '.cookie_banner.dismissed' "$R")" "false" "cookie_banner.dismissed gespiegelt (false)"
[[ -n "$(sj '.cookie_banner.note' "$R")" && "$(sj '.cookie_banner.note' "$R")" != "null" ]] && ok "cookie_banner.note gesetzt (Consent-Warnung)" || bad "cookie_banner.note fehlt"

# ── AC-Gruppe B: Nur Mobile (kein --desktop) ───────────────────────────────
echo; echo "▶ B: Nur Mobile /normal (ohne --desktop, ohne capture-meta)"
R="$WORK/mobileonly"
bash "$LH" "$BASE/normal" --out "$R" --timeout 90 >"$WORK/mobileonly.out" 2>&1
assert_eq "$?" "0" "Exit-Code 0"
assert_file "$R/lighthouse/lighthouse-mobile.json" "lighthouse-mobile.json erzeugt"
[[ ! -e "$R/lighthouse/lighthouse-desktop.json" ]] && ok "kein lighthouse-desktop.json ohne --desktop" || bad "desktop.json fälschlich erzeugt"
assert_eq "$(sj '(.form_factors | join(","))' "$R")" "mobile" "form_factors == mobile"
assert_eq "$(sj '.desktop' "$R")" "null" "kein desktop-Block im Summary"
assert_eq "$(sj '.cookie_banner' "$R")" "null" "cookie_banner null ohne capture-meta"

# ── Edge: Lighthouse-Fehler (unerreichbar) → status failed, Exit 1 ─────────
echo; echo "▶ C: Unerreichbare URL → status failed, Exit 1 (Pipeline degradiert)"
R="$WORK/failed"
bash "$LH" "https://nichtexistent-$RANDOM-xyz.invalid" --out "$R" --timeout 60 >"$WORK/failed.out" 2>&1
assert_eq "$?" "1" "Exit-Code 1 bei Fehler"
assert_file "$R/lighthouse/lh-summary.json" "lh-summary.json trotz Fehler geschrieben"
assert_eq "$(sj '.status' "$R")" "failed" "status == failed"
[[ -n "$(sj '.error' "$R")" && "$(sj '.error' "$R")" != "null" ]] && ok "error-Grund gesetzt" || bad "error-Grund fehlt"
grep -qi "degradiert" "$WORK/failed.out" && ok "Hinweis 'Pipeline degradiert' deutsch" || bad "Degradations-Hinweis fehlt"

# ── Argument-Validierung ───────────────────────────────────────────────────
echo; echo "▶ D: Argument-Validierung (Exit 1)"
bash "$LH" >"$WORK/noarg.out" 2>&1
assert_eq "$?" "1" "Keine URL → Exit 1"
grep -qi "Keine URL angegeben" "$WORK/noarg.out" && ok "Meldung 'Keine URL' deutsch" || bad "URL-Meldung fehlt"
bash "$LH" "$BASE/normal" --unknown x >"$WORK/badopt.out" 2>&1
assert_eq "$?" "1" "Unbekannte Option → Exit 1"
grep -qi "Unbekannte Option" "$WORK/badopt.out" && ok "Meldung 'Unbekannte Option' deutsch" || bad "Options-Meldung fehlt"

# ── Zusammenfassung ────────────────────────────────────────────────────────
echo; echo "──────────────────────────────────────────"
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}" >&2
  exit 1
fi
echo "✓ Alle Tests bestanden"
