#!/usr/bin/env bash
#
# brand-extract — Branding-Extraktion (PROJ-3) für die UI-Check-Pipeline
#
# Extrahiert das faktische Design-System der gerenderten Ziel-Seite als
# strukturierte Tokens (Farben mit Rollen-Vermutung, Fonts, Radius, Spacing,
# Schatten) + Tailwind-4-Theme + Logo + Kurzprofil mit WCAG-AA-Kontrastverstößen.
#
# Nutzung:
#   brand-extract.sh <url> [--out <run-dir>] [--timeout 60] [--brandfetch-key <id>]
#
# Erzeugt (Run-Ordner-Kontrakt):
#   <run-dir>/branding/tokens.json         DTCG-orientierte Tokens (deterministisch)
#   <run-dir>/branding/tailwind-theme.css  @theme-Variablen (Tailwind 4)
#   <run-dir>/branding/branding.md         Kurzprofil: Palette, Fonts, Kontrast, Tonalität
#   <run-dir>/branding/logo.*              Logo + Quellenvermerk (brandfetch|dom|null)
#   <run-dir>/branding/branding-meta.json  Status, Werkzeug, Extraktor-Stats, Logo-Quelle
#   <run-dir>/branding/raw-extract.json    Roh-Extrakt des Browser-Laufs (Beweis/Archiv)
#
# Exit-Codes:  0 = ok · 1 = Teilausfall (kein Logo / Seite nicht ladbar / leere
#              Tokens — Pipeline läuft degradiert weiter, Outputs stehen trotzdem)
#              2 = interner Fehler (fehlendes Tool, ungültige Argumente)
#
# Deterministik-Grenze: Farben/Fonts/Radius/Spacing/Schatten + WCAG-Kontrast
# stammen aus computed styles (reproduzierbar). Die Rollen-Vermutung ist ein
# markierter Heuristik-Schritt (role_method: "heuristic"); die Tonalität ist der
# LLM-Anteil und wird von der Orchestrierung (PROJ-5) aus copy_sample ergänzt.
#
# Alle Meldungen auf Deutsch. Maschinenlesbares Ergebnis in branding-meta.json.

set -uo pipefail

# ── Konfiguration ──────────────────────────────────────────────────────────
DEFAULT_TIMEOUT=60
EXTRACTOR_VERSION="1.0"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXTRACTOR_JS="$HERE/lib/brand-extract.js"

# Cookie-Banner best-effort (gleiche Kaskade wie capture.sh).
COOKIE_SELECTORS=(
  "#onetrust-accept-btn-handler"
  "#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll"
  "#CybotCookiebotDialogBodyButtonAccept"
  "#didomi-notice-agree-button"
  ".fc-cta-consent"
  ".cc-allow"
  "button[data-testid='uc-accept-all-button']"
)
COOKIE_TEXTS=("Alle akzeptieren" "Alle Cookies akzeptieren" "Akzeptieren" "Zustimmen" "Einverstanden" "Accept all" "I agree")

export AGENT_BROWSER_ARGS="${AGENT_BROWSER_ARGS:---no-sandbox,--disable-dev-shm-usage}"
export AGENT_BROWSER_SESSION="${AGENT_BROWSER_SESSION:-ui-check-brand-$$}"

# ── Hilfsfunktionen ────────────────────────────────────────────────────────
die_intern() { echo "✗ $*" >&2; exit 2; }
ab_cleanup() { agent-browser close --session "$AGENT_BROWSER_SESSION" >/dev/null 2>&1 || true; }
trap 'ab_cleanup' EXIT
ab() { agent-browser --session "$AGENT_BROWSER_SESSION" "$@"; }
ab_eval() { ab eval "$1" --json 2>/dev/null | jq -c '.data.result // empty' 2>/dev/null; }

declare -a NOTES=()

# ── Argumente parsen ───────────────────────────────────────────────────────
URL=""; OUT=""; TIMEOUT=$DEFAULT_TIMEOUT
BRANDFETCH_KEY="${BRANDFETCH_CLIENT_ID:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)            OUT="${2:-}"; shift 2 ;;
    --timeout)        TIMEOUT="${2:-}"; shift 2 ;;
    --brandfetch-key) BRANDFETCH_KEY="${2:-}"; shift 2 ;;
    -h|--help)        sed -n '2,33p' "$0"; exit 0 ;;
    -*)               die_intern "Unbekannte Option: $1" ;;
    *)                [[ -z "$URL" ]] && URL="$1" || die_intern "Zu viele Argumente: $1"; shift ;;
  esac
done

[[ -z "$URL" ]] && die_intern "Keine URL angegeben. Nutzung: brand-extract.sh <url> [--out <run-dir>]"
[[ "$TIMEOUT" =~ ^[0-9]+$ ]] || die_intern "--timeout erwartet eine Zahl (Sekunden), war: $TIMEOUT"
[[ "$URL" =~ ^https?:// ]] || URL="https://$URL"

# Tool-Preflight.
command -v agent-browser >/dev/null 2>&1 || die_intern "agent-browser nicht gefunden (npm i -g agent-browser && agent-browser install)."
command -v curl >/dev/null 2>&1 || die_intern "curl nicht gefunden."
command -v jq   >/dev/null 2>&1 || die_intern "jq nicht gefunden."
[[ -s "$EXTRACTOR_JS" ]] || die_intern "Extraktor fehlt: $EXTRACTOR_JS"

# Run-Ordner bestimmen (auto, falls --out fehlt) — gleiche Konvention wie capture.sh.
domain="$(printf '%s' "$URL" | sed -E 's#^https?://##; s#/.*$##; s#^www\.##; s#[^a-zA-Z0-9.-]#-#g')"
if [[ -z "$OUT" ]]; then
  today="$(date +%F)"; n=1
  while :; do
    cand="runs/${today}-${domain}-$(printf '%03d' "$n")"
    [[ -e "$cand" ]] || { OUT="$cand"; break; }; n=$((n+1))
  done
fi
RUN_DIR="$OUT"
BR_DIR="$RUN_DIR/branding"
mkdir -p "$BR_DIR" || die_intern "Run-Ordner nicht anlegbar: $BR_DIR"

START_TS="$(date +%s)"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
AB_VERSION="$(agent-browser --version 2>/dev/null | awk '{print $2}')"
FINAL_URL="$URL"
STATUS="ok"          # ok | partial
EXIT_CODE=0
LOGO_SOURCE="null"
LOGO_FILE=""

# ── branding-meta.json schreiben ───────────────────────────────────────────
write_meta() {
  local end_ts duration notes_arr
  end_ts="$(date +%s)"; duration=$((end_ts - START_TS))
  notes_arr="$(printf '%s\n' "${NOTES[@]:-}" | jq -R . | jq -s -c 'map(select(length>0))')"
  local colors_n fonts_n viol_n dark
  colors_n="$(jq '.color.palette | length' "$BR_DIR/tokens.json" 2>/dev/null || echo 0)"
  fonts_n="$(jq '.font | keys | length' "$BR_DIR/tokens.json" 2>/dev/null || echo 0)"
  viol_n="$(jq '(.contrast_violations // []) | length' "$BR_DIR/raw-extract.json" 2>/dev/null || echo 0)"
  dark="$(jq '.dark_mode_hint // false' "$BR_DIR/raw-extract.json" 2>/dev/null || echo false)"
  jq -n \
    --arg url "$URL" --arg final "$FINAL_URL" --arg status "$STATUS" \
    --arg ts "$TIMESTAMP" --argjson duration "$duration" \
    --arg tool "computed-styles" --arg extver "$EXTRACTOR_VERSION" --arg abver "$AB_VERSION" \
    --arg logo_source "$LOGO_SOURCE" --arg logo_file "$LOGO_FILE" \
    --argjson colors "${colors_n:-0}" --argjson fonts "${fonts_n:-0}" \
    --argjson violations "${viol_n:-0}" --argjson dark "${dark:-false}" \
    --argjson notes "$notes_arr" '{
      url: $url, final_url: $final, status: $status,
      timestamp: $ts, duration_seconds: $duration,
      tool: $tool, extractor_version: $extver, agent_browser_version: $abver,
      logo: { source: (if $logo_source=="null" then null else $logo_source end),
              file: ($logo_file | if .=="" then null else . end) },
      counts: { palette_colors: $colors, fonts: $fonts, contrast_violations: $violations },
      dark_mode: $dark,
      notes: $notes
    }' > "$BR_DIR/branding-meta.json"
}

partial() { STATUS="partial"; EXIT_CODE=1; NOTES+=("$1"); echo "  · $1" >&2; }

# ── Schritt 1: Seite öffnen ────────────────────────────────────────────────
echo "→ Öffne Seite im Browser: $URL"
if ! ab open "$URL" >/dev/null 2>&1; then
  partial "Seite konnte nicht geladen werden ($URL) — leere Tokens, Pipeline läuft degradiert weiter"
  echo '{}' > "$BR_DIR/raw-extract.json"
  jq -n '{ "$description":"leer — Seite nicht ladbar", color:{palette:{},extended:{}}, font:{}, radius:{}, spacing:{}, shadow:{} }' > "$BR_DIR/tokens.json"
  printf '/* leer — Seite nicht ladbar */\n@theme {\n}\n' > "$BR_DIR/tailwind-theme.css"
  printf '# Branding-Profil\n\n> Seite nicht ladbar — keine Tokens extrahierbar.\n' > "$BR_DIR/branding.md"
  write_meta; ab_cleanup; exit 1
fi
ab wait --load networkidle >/dev/null 2>&1 || NOTES+=("Network-Idle nicht erreicht (Timeout)")

real_url="$(ab get url 2>/dev/null)"
[[ -n "$real_url" && "$real_url" =~ ^https?:// ]] && FINAL_URL="$real_url"
domain="$(printf '%s' "$FINAL_URL" | sed -E 's#^https?://##; s#/.*$##; s#^www\.##')"

# Cookie-Banner best-effort wegklicken.
echo "→ Cookie-Banner (Best-Effort) …"
dismissed=false
for sel in "${COOKIE_SELECTORS[@]}"; do
  if ab is visible "$sel" >/dev/null 2>&1 && ab click "$sel" >/dev/null 2>&1; then dismissed=true; break; fi
done
if [[ "$dismissed" != true ]]; then
  for txt in "${COOKIE_TEXTS[@]}"; do
    if ab find text "$txt" click --exact >/dev/null 2>&1; then dismissed=true; break; fi
  done
fi
[[ "$dismissed" == true ]] && ab wait 400 >/dev/null 2>&1

# Lazy-Loading anstoßen, danach nach oben und Default-Viewport setzen.
ab set viewport 1440 900 >/dev/null 2>&1
ab_eval "(async()=>{await new Promise(r=>{let y=0;const t=setInterval(()=>{window.scrollBy(0,800);y+=800;if(y>=document.documentElement.scrollHeight){clearInterval(t);r();}},40);setTimeout(()=>{clearInterval(t);r();},10000);});window.scrollTo(0,0);return true;})()" >/dev/null
ab wait --load networkidle >/dev/null 2>&1 || true
ab wait 300 >/dev/null 2>&1 || true

# ── Schritt 2: Extraktor ausführen ─────────────────────────────────────────
echo "→ Extrahiere Design-Tokens (computed styles) …"
RAW="$BR_DIR/raw-extract.json"
if ! ab eval --stdin --json < "$EXTRACTOR_JS" 2>/dev/null | jq -e '.data.result' > "$RAW" 2>/dev/null || [[ ! -s "$RAW" ]]; then
  partial "Token-Extraktion fehlgeschlagen — Browser lieferte kein Ergebnis"
  echo '{}' > "$RAW"
fi

n_colors="$(jq '(.colors // []) | length' "$RAW" 2>/dev/null || echo 0)"
if [[ ! "$n_colors" =~ ^[0-9]+$ ]] || [[ "$n_colors" -eq 0 ]]; then
  partial "Keine Farben extrahiert — Seite ohne sichtbaren Inhalt?"
fi
[[ "$(jq -r '.dark_mode_hint // false' "$RAW" 2>/dev/null)" == "true" ]] && \
  NOTES+=("Dark-Mode-Default erkannt — Tokens beziehen sich auf den dunklen Standardzustand")

# ── Schritt 3: tokens.json (DTCG-orientiert) ───────────────────────────────
echo "→ Baue tokens.json …"
jq --arg url "$FINAL_URL" --arg ts "$TIMESTAMP" --arg extver "$EXTRACTOR_VERSION" '
  def ext($c): { "uicheck.count": $c.count, "uicheck.contexts": $c.contexts,
                 "uicheck.hsl": { h: $c.h, s: $c.s, l: $c.l }, "uicheck.neutral": $c.neutral };
  def colorTok($c): { "$type":"color", "$value": $c.hex, "$extensions": ext($c) };
  (.colors // []) as $cols
  | (.roles // {}) as $roles
  | ([ $cols[] | {key: .hex, value: .} ] | from_entries) as $byhex
  | (.fonts // []) as $fonts
  | {
      "$description": "UI-Check Branding-Tokens (deterministisch aus computed styles). Rollen-Vermutung ist Heuristik.",
      "$meta": { source: $url, generated: $ts, extractor_version: $extver, tool: "computed-styles",
                 role_method: ($roles.method // "heuristic") },
      "color": (
        ( [ "primary","accent","surface","text" ]
          | map( . as $r | { key: $r, value: ($roles[$r] as $hex
                    | if $hex == null then null
                      else ({ "$type":"color", "$value":$hex,
                              "$extensions": ({ "uicheck.role_method": ($roles.method // "heuristic") }
                                + ( ($byhex[$hex] // {}) as $c | { "uicheck.count": ($c.count // null) } )) })
                      end) } )
          | map(select(.value != null)) | from_entries )
        + { palette: ( [ $cols[0:8][] | {key: ("c" + (( . ) | .hex | ltrimstr("#"))), value: colorTok(.)} ] | from_entries ),
            extended: ( [ $cols[8:24][] | {key: ("c" + (.hex | ltrimstr("#"))), value: colorTok(.)} ] | from_entries ) }
      ),
      "font": ( [ $fonts[]
                  | { key: (.role // "other"),
                      value: { "$type":"fontFamily", "$value": [ .family, "ui-sans-serif", "system-ui", "sans-serif" ],
                               "$extensions": { "uicheck.usage_count": .usage_count, "uicheck.max_px": .max_px,
                                                "uicheck.found_in": .found_in } } }
                ] | from_entries ),
      "radius": ( [ (.radius // [])[] | {key: ("r" + (.value|tostring)), value: {"$type":"dimension","$value": ((.value|tostring)+"px"), "$extensions": {"uicheck.count": .count}}} ] | from_entries ),
      "spacing": ( [ (.spacing // [])[] | {key: ("s" + (.value|tostring)), value: {"$type":"dimension","$value": ((.value|tostring)+"px"), "$extensions": {"uicheck.count": .count}}} ] | from_entries ),
      "shadow": ( [ (.shadows // []) | to_entries[] | {key: ("sh" + (.key|tostring)), value: {"$type":"shadow","$value": .value.value, "$extensions": {"uicheck.count": .value.count}}} ] | from_entries )
    }
' "$RAW" > "$BR_DIR/tokens.json" || partial "tokens.json-Aufbau fehlgeschlagen"

# ── Schritt 4: tailwind-theme.css (Tailwind 4 @theme) ──────────────────────
echo "→ Baue tailwind-theme.css …"
{
  echo "/* UI-Check — generiertes Tailwind-4-Theme aus $FINAL_URL ($TIMESTAMP) */"
  echo "/* Deterministisch aus computed styles. Rollen = Heuristik, ggf. anpassen. */"
  echo "@theme {"
  jq -r '
    def line($n;$v): "  --" + $n + ": " + $v + ";";
    ( .color // {} ) as $c
    | ( [ ($c.primary // empty | "--color-primary: " + .["$value"] + ";"),
          ($c.accent  // empty | "--color-accent: "  + .["$value"] + ";"),
          ($c.surface // empty | "--color-surface: " + .["$value"] + ";"),
          ($c.text    // empty | "--color-text: "    + .["$value"] + ";") ]
        | map("  " + .) | .[] ),
    ( ($c.palette // {}) | to_entries | to_entries[]
      | "  --color-palette-" + ((.key+1)|tostring) + ": " + .value.value["$value"] + ";" ),
    ( (.font // {}) | to_entries[]
      | "  --font-" + (.key|gsub("\\+";"-")) + ": " + ( .value["$value"] | map(if test(" ") then "\"" + . + "\"" else . end) | join(", ") ) + ";" ),
    ( (.radius // {}) | to_entries | sort_by(.value["$extensions"]["uicheck.count"]) | reverse | to_entries[]
      | "  --radius-" + (["sm","md","lg","xl","2xl","3xl"] as $names | ($names[.key] // ("x"+(.key|tostring)))) + ": " + .value.value["$value"] + ";" ),
    ( (.shadow // {}) | to_entries | to_entries[]
      | "  --shadow-" + (["sm","md","lg"] as $names | ($names[.key] // ("x"+(.key|tostring)))) + ": " + (.value.value["$value"]) + ";" )
  ' "$BR_DIR/tokens.json" 2>/dev/null
  echo "}"
} > "$BR_DIR/tailwind-theme.css"

# ── Schritt 5: Logo beschaffen ─────────────────────────────────────────────
echo "→ Logo …"
fetch_ok() {  # $1 url · $2 out — lädt eine Bilddatei, prüft Nicht-Leere + Bild-Content-Type
  local u="$1" out="$2" ct
  ct="$(curl -sS -L --max-time 20 -A "Mozilla/5.0 (UI-Check/1.0)" -o "$out" -w '%{content_type}' "$u" 2>/dev/null)" || return 1
  [[ -s "$out" ]] || return 1
  printf '%s' "$ct" | grep -qiE 'image/|svg' || { rm -f "$out"; return 1; }
  return 0
}
ext_for() {  # rät Dateiendung aus URL/Content
  case "${1,,}" in
    *.svg*) echo svg ;; *.png*) echo png ;; *.jpg*|*.jpeg*) echo jpg ;;
    *.webp*) echo webp ;; *.gif*) echo gif ;; *.ico*) echo ico ;; *) echo png ;;
  esac
}

logo_done=false
# 5a: Brandfetch-Logo-API (nur wenn Client-ID vorhanden).
if [[ -n "$BRANDFETCH_KEY" && -n "$domain" ]]; then
  bf_url="https://cdn.brandfetch.io/${domain}/w/400/h/400?c=${BRANDFETCH_KEY}"
  cand="$BR_DIR/logo.png"
  if fetch_ok "$bf_url" "$cand"; then
    LOGO_SOURCE="brandfetch"; LOGO_FILE="logo.png"; logo_done=true
    echo "  ✓ Logo via Brandfetch"
  else
    NOTES+=("Brandfetch-Logo nicht verfügbar — DOM-Fallback")
  fi
fi

# 5b: DOM-Fallback aus logo_candidates.
if [[ "$logo_done" != true ]]; then
  # Inline-SVG direkt schreiben, falls bester Kandidat.
  svg_markup="$(jq -r '(.logo_candidates // [])[] | select(.kind=="svg-inline") | .svg_markup' "$RAW" 2>/dev/null | head -1)"
  if [[ -n "$svg_markup" && "$svg_markup" != "null" ]]; then
    printf '%s\n' "$svg_markup" > "$BR_DIR/logo.svg"
    LOGO_SOURCE="dom"; LOGO_FILE="logo.svg"; logo_done=true
    echo "  ✓ Logo aus Inline-SVG (DOM)"
  fi
fi
if [[ "$logo_done" != true ]]; then
  while IFS= read -r src; do
    [[ -z "$src" || "$src" == "null" ]] && continue
    e="$(ext_for "$src")"; cand="$BR_DIR/logo.$e"
    if fetch_ok "$src" "$cand"; then
      LOGO_SOURCE="dom"; LOGO_FILE="logo.$e"; logo_done=true
      echo "  ✓ Logo aus DOM ($src)"
      break
    fi
  done < <(jq -r '(.logo_candidates // [])[] | select(.kind!="svg-inline") | .src' "$RAW" 2>/dev/null)
fi
[[ "$logo_done" != true ]] && partial "Kein Logo auffindbar — logo: null (kein Fehler, Pipeline läuft weiter)"

# ── Schritt 6: branding.md ─────────────────────────────────────────────────
echo "→ Baue branding.md …"
BR_MD="$BR_DIR/branding.md"
{
  echo "# Branding-Profil"
  echo
  echo "**Quelle:** $FINAL_URL"
  echo "**Erfasst:** $TIMESTAMP · **Werkzeug:** computed-styles (deterministisch)"
  [[ "$(jq -r '.dark_mode_hint // false' "$RAW")" == "true" ]] && echo "**Hinweis:** Dark-Mode-Default erkannt — Tokens beziehen sich auf den dunklen Standardzustand."
  echo
  echo "## Palette"
  echo
  echo "| Rolle (Heuristik) | Hex |"
  echo "|---|---|"
  jq -r '.color as $c | ["primary","accent","surface","text"][] as $r | ($c[$r] // null) | if .==null then empty else "| \($r) | `\(.["$value"])` |" end' "$BR_DIR/tokens.json" 2>/dev/null
  echo
  echo "**Kern-Palette (nach Häufigkeit):** $(jq -r '[.colors[0:8][].hex] | join("  ·  ")' "$RAW" 2>/dev/null)"
  ext_line="$(jq -r 'if (.colors|length)>8 then [.colors[8:24][].hex] | join("  ·  ") else "" end' "$RAW" 2>/dev/null)"
  [[ -n "$ext_line" ]] && { echo; echo "**Erweitert (extended):** $ext_line"; }
  echo
  echo "> _Rollen-Vermutung ist eine deterministische Heuristik (\`role_method: \"heuristic\"\`) und in der Orchestrierung (PROJ-5) durch Claude überprüfbar._"
  echo
  echo "## Fonts"
  echo
  jq -r '.fonts[]? | "- **\(.role // "other")**: `\(.family)` — Einsatz: \(.found_in | join(", ")) (max \(.max_px)px, \(.usage_count)×)"' "$RAW" 2>/dev/null
  [[ -z "$(jq -r '.fonts[0]?.family // empty' "$RAW" 2>/dev/null)" ]] && echo "_Keine benannten Font-Familien erkannt (nur generischer Fallback-Stack)._"
  echo
  echo "## Radius / Spacing / Schatten"
  echo
  echo "- **Radius:** $(jq -r 'if (.radius|length)>0 then [.radius[].value|tostring+"px"]|join(", ") else "keine" end' "$RAW" 2>/dev/null)"
  echo "- **Spacing-Raster:** $(jq -r 'if (.spacing|length)>0 then [.spacing[0:8][].value|tostring+"px"]|join(", ") else "keins" end' "$RAW" 2>/dev/null)"
  echo "- **Schatten:** $(jq -r '(.shadows // []) | length' "$RAW" 2>/dev/null) verschiedene"
  echo
  echo "## WCAG-AA-Kontrast"
  echo
  nviol="$(jq -r '(.contrast_violations // []) | length' "$RAW" 2>/dev/null)"
  if [[ "$nviol" =~ ^[0-9]+$ && "$nviol" -gt 0 ]]; then
    echo "$nviol Verstoß/Verstöße gegen AA gefunden (Text zu geringer Kontrast):"
    echo
    echo "| Text | Hintergrund | Ratio | Soll | Größe |"
    echo "|---|---|---|---|---|"
    jq -r '.contrast_violations[] | "| `\(.fg)` | `\(.bg)` | \(.ratio):1 | \(.required):1 | \(.font_px)px\(if .large then " (groß)" else "" end) |"' "$RAW" 2>/dev/null
  else
    echo "Keine AA-Verstöße im sichtbaren Text gefunden."
  fi
  echo
  echo "## Logo"
  echo
  if [[ "$LOGO_SOURCE" == "null" ]]; then
    echo "Kein Logo auffindbar (\`logo: null\`)."
  else
    echo "\`$LOGO_FILE\` — Quelle: **$LOGO_SOURCE**"
  fi
  echo
  echo "## Tonalität"
  echo
  echo "> _LLM-Anteil — wird in der Orchestrierung (PROJ-5) aus der Seiten-Copy von Claude ergänzt (2–4 Sätze, deutsch). Rohmaterial siehe unten._"
  echo
  echo "**Copy-Sample (Rohmaterial für die Tonalitäts-Ableitung):**"
  echo
  echo "> $(jq -r '.copy_sample // "" ' "$RAW" 2>/dev/null | sed 's/^/> /; s/•/\n> •/g' | head -c 1400)"
} > "$BR_MD"

# ── Schritt 7: Finalize ────────────────────────────────────────────────────
write_meta
ab_cleanup

dur=$(( $(date +%s) - START_TS ))
if [[ "$STATUS" == "ok" ]]; then
  echo "✓ Branding-Extraktion abgeschlossen in ${dur}s → $RUN_DIR"
else
  echo "✓ Branding-Extraktion (Teilausfall) in ${dur}s → $RUN_DIR" >&2
fi
echo "  branding/{tokens.json · tailwind-theme.css · branding.md · $( [[ -n "$LOGO_FILE" ]] && echo "$LOGO_FILE · " )branding-meta.json}"
exit "$EXIT_CODE"
