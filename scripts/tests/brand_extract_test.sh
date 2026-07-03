#!/usr/bin/env bash
#
# brand_extract_test.sh — Black-Box-QA-Suite für scripts/brand-extract.sh (PROJ-3)
#
# Läuft echtes agent-browser (Chromium) gegen lokale Fixtures (serve_fixtures.py)
# — kein Internet. Prüft Acceptance Criteria + Edge Cases von PROJ-3.
#
# Nutzung:  scripts/tests/brand_extract_test.sh
# Exit 0 = alle Tests bestanden · 1 = mindestens ein Fehlschlag.

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BE="$ROOT/scripts/brand-extract.sh"
SERVER="$HERE/serve_fixtures.py"
PORT="${FIXTURE_PORT:-8981}"
BASE="http://127.0.0.1:$PORT"
WORK="$(mktemp -d)"

if [[ -x "$HOME/miniconda3/envs/Dashboard/bin/python3" ]]; then
  PY="$HOME/miniconda3/envs/Dashboard/bin/python3"
elif command -v conda >/dev/null 2>&1; then
  PY="conda run -n Dashboard --no-capture-output python"
else
  PY="python3"
fi

# Chromium für agent-browser bereitstellen (falls nicht ohnehin gefunden).
if [[ -z "${CHROME_PATH:-}" ]]; then
  for c in chromium chromium-browser google-chrome chrome; do
    command -v "$c" >/dev/null 2>&1 && { export CHROME_PATH="$(command -v "$c")"; break; }
  done
fi

PASS=0; FAIL=0
declare -a FAILURES=()
ok()  { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $*" >&2; FAIL=$((FAIL+1)); FAILURES+=("$*"); }
assert_eq()   { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }
assert_file() { [[ -s "$1" ]] && ok "$2" || bad "$2 — Datei fehlt/leer: $1"; }
assert_has()  { printf '%s' "$1" | grep -qF -e "$2" && ok "$3" || bad "$3 — '$2' fehlt in Ausgabe"; }
tj() { jq -r "$1" "$2/branding/tokens.json" 2>/dev/null; }
rj() { jq -r "$1" "$2/branding/raw-extract.json" 2>/dev/null; }
mj() { jq -r "$1" "$2/branding/branding-meta.json" 2>/dev/null; }

# ── Preflight ──────────────────────────────────────────────────────────────
command -v agent-browser >/dev/null 2>&1 || { echo "✗ agent-browser nicht installiert (npm i -g agent-browser)"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "✗ jq nicht installiert"; exit 1; }
[[ -n "${CHROME_PATH:-}" ]] || echo "· Hinweis: kein CHROME_PATH gesetzt — agent-browser nutzt sein eigenes Chromium"

# ── Fixture-Server starten ─────────────────────────────────────────────────
echo "→ Starte Fixture-Server ($BASE) …"
SRV_LOG="$WORK/server.log"
$PY "$SERVER" "$PORT" >"$SRV_LOG" 2>&1 &
SRV_PID=$!
cleanup() { kill "$SRV_PID" >/dev/null 2>&1; agent-browser close --all >/dev/null 2>&1; rm -rf "$WORK"; }
trap cleanup EXIT
for _ in $(seq 1 50); do grep -q "READY" "$SRV_LOG" 2>/dev/null && break; sleep 0.2; done
grep -q "READY" "$SRV_LOG" || { echo "✗ Server nicht gestartet:"; cat "$SRV_LOG"; exit 1; }
curl -sf "$BASE/branding" >/dev/null || { echo "✗ Server antwortet nicht"; exit 1; }

# ── AC-Gruppe A: Happy Path /branding ──────────────────────────────────────
echo; echo "▶ A: Happy Path /branding (bekanntes Design-System)"
R="$WORK/branding"
bash "$BE" "$BASE/branding" --out "$R" --timeout 60 >"$WORK/branding.out" 2>&1
assert_eq "$?" "0" "Exit-Code 0 (ok)"
# Pflicht-Outputs
assert_file "$R/branding/tokens.json"        "tokens.json erzeugt"
assert_file "$R/branding/tailwind-theme.css" "tailwind-theme.css erzeugt"
assert_file "$R/branding/branding.md"        "branding.md erzeugt"
assert_file "$R/branding/branding-meta.json" "branding-meta.json erzeugt"
assert_eq "$(mj '.status' "$R")" "ok" "status == ok"

# AC: Farben mit Rollenvermutung (primary/accent/surface/text)
assert_eq "$(tj '.color.surface["$value"]' "$R")" "#ffffff" "surface == #ffffff"
assert_eq "$(tj '.color.text["$value"]' "$R")"    "#111827" "text == #111827"
brand="$(tj '[.color.primary["$value"], .color.accent["$value"]] | sort | join(",")' "$R")"
assert_eq "$brand" "#1d4ed8,#f59e0b" "primary+accent == Markenfarben (Blau+Amber)"
# AC: Rollen-Methode als Heuristik markiert
assert_eq "$(tj '.color.primary["$extensions"]["uicheck.role_method"]' "$R")" "heuristic" "role_method == heuristic (markiert)"
assert_eq "$(tj '."$meta".role_method' "$R")" "heuristic" "meta.role_method == heuristic"

# AC: Palette enthält die Kernfarben, Radius/Shadow deterministisch
pal="$(tj '[.color.palette[]["$value"]] | join(",")' "$R")"
for hex in "#111827" "#ffffff" "#1d4ed8" "#f59e0b"; do
  printf '%s' "$pal" | grep -qF "$hex" && ok "Palette enthält $hex" || bad "Palette ohne $hex ($pal)"
done
assert_eq "$(tj '[.radius[]["$value"]] | join(",")' "$R")" "12px" "radius == 12px"
[[ "$(tj '.shadow | length' "$R")" -ge 1 ]] && ok "mind. 1 Schatten-Token" || bad "kein Schatten-Token"

# AC: Fonts mit Einsatz (Display/Text)
assert_eq "$(tj '.font.display["$value"][0]' "$R")" "Georgia" "Display-Font == Georgia"
assert_eq "$(tj '.font.text["$value"][0]' "$R")"    "Arial"   "Text-Font == Arial"
[[ -n "$(tj '.font.display["$extensions"]["uicheck.found_in"][0]' "$R")" ]] && ok "Display-Font mit Fundstellen (found_in)" || bad "found_in fehlt"

# AC: WCAG-AA-Kontrastverstöße erkannt
nviol="$(rj '(.contrast_violations // []) | length' "$R")"
[[ "$nviol" =~ ^[0-9]+$ && "$nviol" -ge 1 ]] && ok "mind. 1 Kontrastverstoß ($nviol)" || bad "kein Kontrastverstoß erkannt"
rj '.contrast_violations[].fg' "$R" | grep -qiF "#bbbbbb" && ok "Verstoß #bbbbbb auf Weiß erkannt" || bad "#bbbbbb-Verstoß fehlt"
grep -qi "WCAG-AA-Kontrast" "$R/branding/branding.md" && ok "branding.md hat Kontrast-Abschnitt" || bad "Kontrast-Abschnitt fehlt in branding.md"

# AC: Tailwind-4-@theme aus Tokens generiert
css="$(cat "$R/branding/tailwind-theme.css")"
assert_has "$css" "@theme {"              "CSS hat @theme-Block"
assert_has "$css" "--color-primary:"      "CSS hat --color-primary"
assert_has "$css" "--color-surface: #ffffff" "CSS hat --color-surface"
assert_has "$css" "--font-display: Georgia"  "CSS hat --font-display (generische Keywords ungequotet)"
assert_has "$css" "--radius-sm: 12px"     "CSS hat --radius-sm"

# AC: Logo via DOM-Fallback (Brandfetch ohne Key übersprungen)
assert_file "$R/branding/logo.png" "logo.png heruntergeladen"
assert_eq "$(mj '.logo.source' "$R")" "dom" "logo.source == dom"

# AC: Tonalität als LLM-Anteil markiert + Copy-Sample geliefert
grep -qi "Tonalität" "$R/branding/branding.md" && ok "branding.md hat Tonalitäts-Abschnitt" || bad "Tonalitäts-Abschnitt fehlt"
grep -qi "LLM-Anteil" "$R/branding/branding.md" && ok "Tonalität als LLM-Anteil markiert" || bad "LLM-Markierung fehlt"
[[ -n "$(rj '.copy_sample' "$R")" && "$(rj '.copy_sample' "$R")" != "null" ]] && ok "copy_sample für LLM-Ableitung vorhanden" || bad "copy_sample fehlt"

# ── AC-Gruppe B: Determinismus (zweiter Lauf identisch) ────────────────────
echo; echo "▶ B: Determinismus — zweiter Lauf liefert identische Tokens"
R2="$WORK/branding2"
bash "$BE" "$BASE/branding" --out "$R2" --timeout 60 >"$WORK/branding2.out" 2>&1
a="$(jq -S 'del(.["$meta"].generated, .["$meta"].source)' "$R/branding/tokens.json" 2>/dev/null)"
b="$(jq -S 'del(.["$meta"].generated, .["$meta"].source)' "$R2/branding/tokens.json" 2>/dev/null)"
[[ -n "$a" && "$a" == "$b" ]] && ok "tokens.json deterministisch (identisch ohne Zeitstempel)" || bad "tokens.json nicht deterministisch"

# ── Edge C: kein Logo → Teilausfall (Exit 1), Tokens trotzdem da ───────────
echo; echo "▶ C: /normal ohne Logo → Teilausfall (Exit 1), Outputs trotzdem"
R="$WORK/nologo"
bash "$BE" "$BASE/normal" --out "$R" --timeout 60 >"$WORK/nologo.out" 2>&1
assert_eq "$?" "1" "Exit-Code 1 (Teilausfall)"
assert_eq "$(mj '.status' "$R")" "partial" "status == partial"
assert_eq "$(mj '.logo.source' "$R")" "null" "logo.source == null"
assert_file "$R/branding/tokens.json" "tokens.json trotz fehlendem Logo erzeugt"
grep -qi "logo: null" "$R/branding/branding.md" && ok "branding.md vermerkt logo: null (kein Fehler)" || bad "logo-null-Vermerk fehlt"

# ── Edge E: Clustering / Extended-Palette (>12 Farben) ─────────────────────
echo; echo "▶ E: /manycolors → Kern-Palette ≤ 8, Rest als extended"
R="$WORK/many"
bash "$BE" "$BASE/manycolors" --out "$R" --timeout 60 >"$WORK/many.out" 2>&1
[[ "$(rj '(.colors // []) | length' "$R")" -gt 12 ]] && ok "mehr als 12 Farben erkannt ($(rj '(.colors // []) | length' "$R"))" || bad "erwartete >12 Farben"
palN="$(tj '.color.palette | length' "$R")"
[[ "$palN" =~ ^[0-9]+$ && "$palN" -le 8 ]] && ok "Kern-Palette ≤ 8 ($palN)" || bad "Kern-Palette > 8: $palN"
[[ "$(tj '.color.extended | length' "$R")" -ge 1 ]] && ok "extended-Palette befüllt" || bad "extended-Palette leer trotz >12 Farben"
jq -e . "$R/branding/tokens.json" >/dev/null 2>&1 && ok "tokens.json gültiges JSON" || bad "tokens.json ungültig"

# ── Edge F: Inline-SVG-Logo (DOM-SVG-Pfad, kein <img>) ─────────────────────
echo; echo "▶ F: /svglogo → Inline-SVG als logo.svg gesichert"
R="$WORK/svg"
bash "$BE" "$BASE/svglogo" --out "$R" --timeout 60 >"$WORK/svg.out" 2>&1
assert_eq "$?" "0" "Exit-Code 0 (Logo gefunden)"
assert_file "$R/branding/logo.svg" "logo.svg aus Inline-SVG geschrieben"
assert_eq "$(mj '.logo.source' "$R")" "dom" "logo.source == dom (SVG)"
grep -qi "<svg" "$R/branding/logo.svg" && ok "logo.svg enthält SVG-Markup" || bad "logo.svg ohne SVG-Markup"

# ── Edge G: Dark-Mode-Default erkannt + vermerkt ───────────────────────────
echo; echo "▶ G: /darkmode → dark_mode-Vermerk (Default-Zustand extrahiert)"
R="$WORK/dark"
bash "$BE" "$BASE/darkmode" --out "$R" --timeout 60 >"$WORK/dark.out" 2>&1
assert_eq "$(mj '.dark_mode' "$R")" "true" "branding-meta.dark_mode == true"
assert_eq "$(rj '.dark_mode_hint' "$R")" "true" "raw dark_mode_hint == true"
grep -qi "Dark-Mode" "$R/branding/branding.md" && ok "branding.md vermerkt Dark-Mode" || bad "Dark-Mode-Vermerk fehlt"
jq -e . "$R/branding/tokens.json" >/dev/null 2>&1 && ok "tokens.json trotz Dark-Mode gültig" || bad "tokens.json ungültig (Dark-Mode)"
# BUG-1-Fix: Rollen-Polarität am Hintergrund ausgerichtet → im Dark-Mode ist
# surface dunkel und text hell (nicht mehr leer).
s_hex="$(tj '.color.surface["$value"]' "$R")"
t_hex="$(tj '.color.text["$value"]' "$R")"
lum_of() { jq -r --arg h "$2" '.colors[]|select(.hex==$h)|.l' "$1/branding/raw-extract.json" 2>/dev/null | head -1; }
s_l="$(lum_of "$R" "$s_hex")"; t_l="$(lum_of "$R" "$t_hex")"
[[ -n "$s_hex" && "$s_hex" != "null" ]] && ok "surface-Rolle im Dark-Mode gesetzt ($s_hex)" || bad "surface-Rolle im Dark-Mode leer (BUG-1)"
[[ -n "$t_hex" && "$t_hex" != "null" ]] && ok "text-Rolle im Dark-Mode gesetzt ($t_hex)" || bad "text-Rolle im Dark-Mode leer (BUG-1)"
[[ -n "$s_l" ]] && awk "BEGIN{exit !($s_l < 0.4)}" && ok "surface ist dunkel (l=$s_l < 0.4)" || bad "surface nicht dunkel im Dark-Mode: l=$s_l"
[[ -n "$t_l" ]] && awk "BEGIN{exit !($t_l > 0.5)}" && ok "text ist hell (l=$t_l > 0.5)" || bad "text nicht hell im Dark-Mode: l=$t_l"
grep -q -- "--color-surface" "$R/branding/tailwind-theme.css" && grep -q -- "--color-text" "$R/branding/tailwind-theme.css" && ok "Theme hat --color-surface + --color-text (Dark-Mode)" || bad "Theme-Farbvariablen fehlen im Dark-Mode"

# ── Edge D: Argument-Validierung (Exit 2) ──────────────────────────────────
echo; echo "▶ D: Argument-Validierung (interner Fehler → Exit 2)"
bash "$BE" >"$WORK/noarg.out" 2>&1
assert_eq "$?" "2" "Keine URL → Exit 2"
grep -qi "Keine URL angegeben" "$WORK/noarg.out" && ok "Meldung 'Keine URL' deutsch" || bad "URL-Meldung fehlt"
bash "$BE" "$BASE/branding" --unknown x >"$WORK/badopt.out" 2>&1
assert_eq "$?" "2" "Unbekannte Option → Exit 2"
grep -qi "Unbekannte Option" "$WORK/badopt.out" && ok "Meldung 'Unbekannte Option' deutsch" || bad "Options-Meldung fehlt"

# ── Zusammenfassung ────────────────────────────────────────────────────────
echo; echo "──────────────────────────────────────────"
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}" >&2
  exit 1
fi
echo "✓ Alle Tests bestanden"
