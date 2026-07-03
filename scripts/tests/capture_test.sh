#!/usr/bin/env bash
#
# capture_test.sh — Black-Box-QA-Suite für scripts/capture.sh (PROJ-1)
#
# Deterministisch gegen lokale Fixtures (serve_fixtures.py) — kein Internet,
# keine Flakiness. Prüft Acceptance Criteria + Edge Cases von PROJ-1.
#
# Nutzung:  scripts/tests/capture_test.sh
# Exit 0 = alle Tests bestanden · 1 = mindestens ein Fehlschlag.

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CAPTURE="$ROOT/scripts/capture.sh"
SERVER="$HERE/serve_fixtures.py"
PORT="${FIXTURE_PORT:-8973}"
BASE="http://127.0.0.1:$PORT"
WORK="$(mktemp -d)"
# Fixture-Server braucht nur die Python-Stdlib. Dashboard-Env bevorzugen
# (Haus-Konvention), sonst irgendein python3 im PATH.
if [[ -x "$HOME/miniconda3/envs/Dashboard/bin/python3" ]]; then
  PY="$HOME/miniconda3/envs/Dashboard/bin/python3"
elif command -v conda >/dev/null 2>&1; then
  PY="conda run -n Dashboard --no-capture-output python"
else
  PY="python3"
fi

PASS=0; FAIL=0
declare -a FAILURES=()

ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad()  { echo "  ✗ $*" >&2; FAIL=$((FAIL+1)); FAILURES+=("$*"); }

# assert_eq <actual> <expected> <label>
assert_eq() { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }
# assert_file <path> <label>
assert_file() { [[ -s "$1" ]] && ok "$2" || bad "$2 — Datei fehlt/leer: $1"; }
# jqf <run>/meta.json <filter>
mj() { jq -r "$1" "$2/meta.json" 2>/dev/null; }

# ── Fixture-Server starten ─────────────────────────────────────────────────
echo "→ Starte Fixture-Server ($BASE) …"
SRV_LOG="$WORK/server.log"
$PY "$SERVER" "$PORT" >"$SRV_LOG" 2>&1 &
SRV_PID=$!
cleanup() { kill "$SRV_PID" >/dev/null 2>&1; rm -rf "$WORK"; }
trap cleanup EXIT

for _ in $(seq 1 50); do grep -q "READY" "$SRV_LOG" 2>/dev/null && break; sleep 0.2; done
if ! grep -q "READY" "$SRV_LOG"; then echo "✗ Server nicht gestartet:"; cat "$SRV_LOG"; exit 1; fi
curl -sf "$BASE/normal" >/dev/null || { echo "✗ Server antwortet nicht"; exit 1; }

run() { bash "$CAPTURE" "$1" --out "$2" --timeout 15 >"$3" 2>&1; echo $?; }

# ── AC-Gruppe A: Happy Path (Artefakte + meta.json) ────────────────────────
echo; echo "▶ A: Happy Path (/normal)"
R="$WORK/normal"; rc="$(run "$BASE/normal" "$R" "$WORK/normal.out")"
assert_eq "$rc" "0" "Exit-Code 0"
assert_file "$R/capture/shot-375.png"  "shot-375.png erzeugt"
assert_file "$R/capture/shot-768.png"  "shot-768.png erzeugt"
assert_file "$R/capture/shot-1440.png" "shot-1440.png erzeugt"
assert_file "$R/capture/snapshot.txt"  "snapshot.txt erzeugt"
assert_file "$R/capture/dom-meta.json" "dom-meta.json erzeugt"
assert_file "$R/meta.json"             "meta.json erzeugt"
# Bild-Dimensionen prüfen
for vw in 375 768 1440; do
  w="$(file "$R/capture/shot-$vw.png" | grep -oE '[0-9]+ x [0-9]+' | head -1 | cut -d' ' -f1)"
  assert_eq "$w" "$vw" "shot-$vw Breite == $vw"
done
# meta.json Pflichtfelder
assert_eq "$(mj '.status' "$R")" "ok" "meta.status == ok"
assert_eq "$(mj '.http_status' "$R")" "200" "meta.http_status == 200"
[[ "$(mj '.final_url' "$R")" == "$BASE/normal" ]] && ok "meta.final_url korrekt" || bad "meta.final_url falsch: $(mj '.final_url' "$R")"
[[ "$(mj '.timestamp' "$R")" =~ ^2[0-9]{3}-[0-9]{2}-[0-9]{2}T ]] && ok "meta.timestamp ISO-8601" || bad "meta.timestamp fehlt"
[[ "$(mj '.duration_seconds' "$R")" =~ ^[0-9]+$ ]] && ok "meta.duration_seconds numerisch" || bad "meta.duration_seconds fehlt"
[[ -n "$(mj '.agent_browser_version' "$R")" && "$(mj '.agent_browser_version' "$R")" != "null" ]] && ok "meta.agent_browser_version gesetzt" || bad "meta.agent_browser_version fehlt"
assert_eq "$(mj '(.screenshots | length)' "$R")" "3" "meta.screenshots hat 3 Einträge"
# dom-meta Inhalte
assert_eq "$(jq -r '.meta_description' "$R/capture/dom-meta.json")" "Testseite für UI-Check Capture QA." "dom-meta.meta_description"
assert_eq "$(jq -r '.og["og:title"]' "$R/capture/dom-meta.json")" "UI-Check Normal Fixture" "dom-meta.og:title"
[[ "$(jq -r '.sections_detected' "$R/capture/dom-meta.json")" -ge 5 ]] && ok "dom-meta.sections_detected >= 5" || bad "dom-meta.sections_detected zu klein"
[[ "$(jq -r '.favicon' "$R/capture/dom-meta.json")" == "$BASE/favicon.ico" ]] && ok "dom-meta.favicon absolut aufgelöst" || bad "dom-meta.favicon falsch: $(jq -r '.favicon' "$R/capture/dom-meta.json")"

# ── AC: Redirect-Kette ─────────────────────────────────────────────────────
echo; echo "▶ B: Redirect-Kette (/redirect -> /normal)"
R="$WORK/redir"; rc="$(run "$BASE/redirect" "$R" "$WORK/redir.out")"
assert_eq "$rc" "0" "Exit-Code 0"
[[ "$(mj '.final_url' "$R")" == "$BASE/normal" ]] && ok "finale URL dokumentiert (/normal)" || bad "finale URL falsch: $(mj '.final_url' "$R")"
[[ "$(mj '.redirects' "$R")" -ge 1 ]] && ok "redirects >= 1" || bad "redirects nicht gezählt"

# ── Edge: Höhenkappung ─────────────────────────────────────────────────────
echo; echo "▶ C: Höhenkappung (/tall, --max-height Standard 20000)"
R="$WORK/tall"; rc="$(run "$BASE/tall" "$R" "$WORK/tall.out")"
assert_eq "$rc" "0" "Exit-Code 0"
assert_eq "$(mj '.screenshots[0].capped' "$R")" "true" "screenshots[0].capped == true"
h="$(file "$R/capture/shot-1440.png" | grep -oE 'x [0-9]+' | head -1 | cut -d' ' -f2)"
assert_eq "$h" "20000" "shot-1440 Höhe auf 20000 gekappt"
mj '.notes[]' "$R" | grep -qi "gekappt" && ok "Kappungs-Vermerk in notes" || bad "kein Kappungs-Vermerk"

# ── AC: Cookie-Banner ──────────────────────────────────────────────────────
echo; echo "▶ D: Cookie-Banner Dismiss (/cookie)"
R="$WORK/cookie"; rc="$(run "$BASE/cookie" "$R" "$WORK/cookie.out")"
assert_eq "$rc" "0" "Exit-Code 0"
assert_eq "$(mj '.cookie_banner.dismissed' "$R")" "true" "cookie_banner.dismissed == true"
[[ "$(mj '.cookie_banner.method' "$R")" == selector:#onetrust* ]] && ok "cookie_banner.method dokumentiert" || bad "cookie_banner.method falsch: $(mj '.cookie_banner.method' "$R")"

# ── Edge: SPA-Leerverdacht ─────────────────────────────────────────────────
echo; echo "▶ E: SPA-Leerverdacht (/spa)"
R="$WORK/spa"; rc="$(run "$BASE/spa" "$R" "$WORK/spa.out")"
assert_eq "$rc" "0" "Exit-Code 0 (kein Abbruch)"
assert_eq "$(mj '.content_suspicion' "$R")" "spa_empty" "content_suspicion == spa_empty"

# ── AC: Fehlerpfade (Exit 2 + deutsche Meldung + aborted meta) ─────────────
echo; echo "▶ F: Nicht erreichbar / kein HTML / Bot-Schutz (Exit 2)"

R="$WORK/notfound"; rc="$(run "$BASE/notfound" "$R" "$WORK/notfound.out")"
assert_eq "$rc" "2" "HTTP 404 -> Exit 2"
grep -qi "nicht erreichbar: HTTP 404" "$WORK/notfound.out" && ok "404-Meldung deutsch" || bad "404-Meldung fehlt"
assert_eq "$(mj '.status' "$R")" "aborted" "404 meta.status == aborted"

R="$WORK/pdf"; rc="$(run "$BASE/doc.pdf" "$R" "$WORK/pdf.out")"
assert_eq "$rc" "2" "PDF -> Exit 2"
grep -qi "Kein HTML-Dokument" "$WORK/pdf.out" && ok "Non-HTML-Meldung deutsch" || bad "Non-HTML-Meldung fehlt"

R="$WORK/bot"; rc="$(run "$BASE/botwall" "$R" "$WORK/bot.out")"
assert_eq "$rc" "2" "Bot-Wall -> Exit 2"
grep -qi "bot-geschützt" "$WORK/bot.out" && ok "Bot-Schutz-Meldung deutsch" || bad "Bot-Schutz-Meldung fehlt"
# Bot-Pfad darf NICHT als 'HTTP 403' abgebrochen werden (Reihenfolge korrekt)
grep -qi "HTTP 403" "$WORK/bot.out" && bad "Bot-Wall fälschlich als HTTP 403 gemeldet" || ok "Bot-Erkennung vor HTTP-Statuspfad"

R="$WORK/dns"; rc="$(bash "$CAPTURE" "https://nichtexistent-$RANDOM-xyz.invalid" --out "$R" --timeout 10 >"$WORK/dns.out" 2>&1; echo $?)"
assert_eq "$rc" "2" "DNS-Fehler -> Exit 2"
grep -qi "nicht erreichbar" "$WORK/dns.out" && ok "DNS-Meldung deutsch" || bad "DNS-Meldung fehlt"

# ── Fehlerpfad: fehlende Argumente ─────────────────────────────────────────
echo; echo "▶ G: Argument-Validierung"
rc="$(bash "$CAPTURE" >"$WORK/noarg.out" 2>&1; echo $?)"
assert_eq "$rc" "1" "Keine URL -> Exit 1 (interner Fehler)"
rc="$(bash "$CAPTURE" "$BASE/normal" --unknown x >"$WORK/badopt.out" 2>&1; echo $?)"
assert_eq "$rc" "1" "Unbekannte Option -> Exit 1"

# ── Zusammenfassung ────────────────────────────────────────────────────────
echo; echo "──────────────────────────────────────────"
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}" >&2
  exit 1
fi
echo "✓ Alle Tests bestanden"
