#!/usr/bin/env bash
#
# mockup-export.sh — Mockup-Export als self-contained HTML (PROJ-7)
#
# Bündelt die Redesign-Varianten (PROJ-6) zu EINER statischen, offline
# lauffähigen HTML-Datei (CSS/JS inline, Bilder base64) und prüft davor
# Publish-Gates. Rein deterministisch — kein LLM-Anteil.
#
# Nutzung:
#   mockup-export.sh <run-dir> [--force]
#
# Ablauf:
#   1. INIT-Gate    PROJ-6 komplett? (redesign/{safe,bold}, verify.json ohne Rot)
#   2. Workspace    <run-dir>/mockup/.build/ (Shell + redesign/ + Merge-package.json;
#                   node_modules repo-übergreifend gecacht in ~/.cache/ui-check/)
#   3. Build        node shell/build.mjs (Pre-Render → Client-Bundle → Tailwind → Assemble)
#   4. Gates        statisch (grep/jq) + Browser (agent-browser, lokal) → mockup/gates.json
#   5. Promote      nur ohne rote Gates: out/mockup.html → <run-dir>/mockup.html
#
# Exit-Codes (headless-tauglich, Jupiter/PROJ-14):
#   0  ok           alle Gates grün, mockup.html liegt im Run-Ordner
#   1  degradiert   nur Warn-Gates gelb (z. B. Größe) — mockup.html liegt im Run-Ordner
#   2  Abbruch      fehlender/roter PROJ-6-Stand, Build-Fehler, rote Pflicht-Gates
#
# Test-Hook: MOCKUP_EXPORT_BUILD_CMD ersetzt Dependency-Install + Build
# (bekommt den Workspace als $1; muss out/{mockup.html,prerendered.json,
# build-report.json} schreiben) — siehe scripts/tests/mockup_export_test.sh.
#
# Alle Meldungen auf Deutsch.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SHELL_SRC="$HERE/lib/mockup-shell"
MAX_BYTES=$((5 * 1024 * 1024))

die() { echo "✗ $*" >&2; update_status failed "$*"; exit 2; }

# ── Argumente ───────────────────────────────────────────────────────────────
RUN_DIR=""; FORCE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)   FORCE=true; shift ;;
    -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
    -*)        echo "✗ Unbekannte Option: $1" >&2; exit 2 ;;
    *)         [[ -z "$RUN_DIR" ]] && RUN_DIR="$1" || { echo "✗ Zu viele Argumente: $1" >&2; exit 2; }; shift ;;
  esac
done
[[ -n "$RUN_DIR" ]] || { echo "✗ Kein Run-Ordner angegeben. Nutzung: mockup-export.sh <run-dir> [--force]" >&2; exit 2; }
[[ -d "$RUN_DIR" ]] || { echo "✗ Run-Ordner nicht gefunden: $RUN_DIR" >&2; exit 2; }
RUN_DIR="$(cd "$RUN_DIR" && pwd)"
RD="$RUN_DIR/redesign"
MOCKUP_DIR="$RUN_DIR/mockup"
WS="$MOCKUP_DIR/.build"
OUT_HTML="$WS/out/mockup.html"

# status.json (PROJ-5) fortschreiben, falls vorhanden — Fortschrittsquelle Jupiter.
update_status() { # $1=status $2=fehlertext
  local sf="$RUN_DIR/status.json" tmp
  [[ -s "$sf" ]] || return 0
  tmp="$(mktemp)"
  jq --arg s "$1" --arg e "${2:-}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.phases.mockup = {status:$s, error:($e|if .=="" then null else . end)} | .updated_at=$now' \
     "$sf" > "$tmp" 2>/dev/null && mv "$tmp" "$sf" || rm -f "$tmp"
}

# ── Preflight ───────────────────────────────────────────────────────────────
command -v jq   >/dev/null 2>&1 || { echo "✗ jq nicht gefunden — apt install jq." >&2; exit 2; }
command -v node >/dev/null 2>&1 || die "node nicht gefunden (>= v20 benötigt)."
command -v npm  >/dev/null 2>&1 || die "npm nicht gefunden."
command -v agent-browser >/dev/null 2>&1 || die "agent-browser nicht gefunden (npm i -g agent-browser && agent-browser install)."
[[ -s "$SHELL_SRC/build.mjs" && -s "$SHELL_SRC/template.html" ]] || die "Build-Harness fehlt: $SHELL_SRC (Teil des Repos)."

# ── INIT-Gate: PROJ-6 komplett + Verify ohne rote Gates ─────────────────────
[[ -d "$RD" ]] || die "Kein redesign/ in $RUN_DIR — erst PROJ-6 fahren (/ui-redesign)."
for f in shared/content.json shared/tailwind-theme.css safe/manifest.json bold/manifest.json; do
  [[ -s "$RD/$f" ]] || die "redesign/$f fehlt — PROJ-6 unvollständig."
done
[[ -s "$RD/verify.json" ]] || die "redesign/verify.json fehlt — erst Gates fahren: scripts/redesign.sh --verify $RUN_DIR"
n_red="$(jq -r '.summary.fail // 999' "$RD/verify.json")"
[[ "$n_red" -eq 0 ]] || die "redesign/verify.json meldet $n_red rote(s) Gate(s) — erst PROJ-6 fixen, dann exportieren."
for v in safe bold; do
  entry="$(jq -r '.entry // "App.jsx"' "$RD/$v/manifest.json")"
  [[ -s "$RD/$v/$entry" ]] || die "Entry der Variante '$v' fehlt: redesign/$v/$entry"
done
if [[ -e "$RUN_DIR/mockup.html" && "$FORCE" != true ]]; then
  die "mockup.html existiert bereits in $RUN_DIR — erneuter Export nur mit --force."
fi

CONTENT="$RD/shared/content.json"
RUN_ID="$(basename "$RUN_DIR")"
DOMAIN="$(jq -r '(.final_url // .url // "") | sub("^https?://";"") | sub("/.*$";"")' "$RUN_DIR/ui-check.json" 2>/dev/null)"
[[ -n "$DOMAIN" ]] || DOMAIN="${RUN_ID#*-*-*-}"   # Fallback: Domain aus Run-ID

echo "→ Mockup-Export für $RUN_ID ($DOMAIN) …"

# ── Workspace zusammenstellen ───────────────────────────────────────────────
rm -rf "$WS"
mkdir -p "$WS/meta" "$MOCKUP_DIR" || die "Workspace nicht anlegbar: $WS"
cp -r "$SHELL_SRC" "$WS/shell"
mkdir -p "$WS/redesign"
for d in shared safe bold; do cp -r "$RD/$d" "$WS/redesign/$d"; done

# Favicon-Quelle: extrahiertes Logo (PROJ-3), sonst deterministischer Fallback im Build.
FAVICON_FILE="$(ls "$RUN_DIR"/branding/logo.svg "$RUN_DIR"/branding/logo.png 2>/dev/null | head -1 || true)"
PRIMARY="$(grep -oE -- '--color-primary:[^;]+' "$RD/shared/tailwind-theme.css" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ')"

# build-meta.json: mechanische (nicht erfundene) Shell-Texte + Font-Familien für Bunny.
jq -n --arg run_id "$RUN_ID" --arg domain "$DOMAIN" \
      --arg title "Redesign-Vorschlag — $DOMAIN" \
      --arg desc "Redesign-Vorschlag für $DOMAIN: zwei Richtungen (Safe und Bold) im direkten Vergleich. Erstellt mit UI-Check." \
      --arg fav "${FAVICON_FILE:-}" --arg prim "${PRIMARY:-}" \
      --slurpfile tokens <(cat "$RD/shared/tokens.json" 2>/dev/null || echo '{}') '
  {run_id: $run_id, domain: $domain, title: $title, description: $desc,
   favicon_file: ($fav | if .=="" then null else . end),
   primary_color: ($prim | if .=="" then null else . end),
   font_families: ([($tokens[0].font // {}) | to_entries[]?.value["$value"][0]?] | map(select(. != null)) | unique)}' \
  > "$WS/meta/build-meta.json" || die "build-meta.json konnte nicht geschrieben werden."

# ── Dependencies + Build ────────────────────────────────────────────────────
BUILD_LOG="$MOCKUP_DIR/build.log"
echo "── Mockup-Export $RUN_ID · $(date -u +%Y-%m-%dT%H:%M:%SZ) · Workspace: $WS ──" > "$BUILD_LOG"

if [[ -n "${MOCKUP_EXPORT_BUILD_CMD:-}" ]]; then
  # Test-Hook: ersetzt Install + Build (hermetische Suite).
  "$MOCKUP_EXPORT_BUILD_CMD" "$WS" >> "$BUILD_LOG" 2>&1 || die "Build (Stub) fehlgeschlagen — siehe $BUILD_LOG"
else
  # Merge-package.json: Varianten-Dependencies + Shell-Pins (Shell gewinnt bei Konflikt).
  jq -s '{name:"ui-check-mockup-build", private:true,
          dependencies: ((.[1].dependencies // {}) + (.[2].dependencies // {}) + (.[0].dependencies // {}))}' \
    "$SHELL_SRC/package.json" "$RD/safe/package.json" "$RD/bold/package.json" \
    > "$WS/package.json" || die "package.json-Merge fehlgeschlagen."

  # node_modules-Cache: keyed am Dependency-Set — wiederholte Exporte ohne npm-Install.
  DEP_HASH="$(jq -cS '.dependencies' "$WS/package.json" | sha1sum | cut -c1-12)"
  CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ui-check/mockup-deps-$DEP_HASH"
  if [[ ! -d "$CACHE_DIR/node_modules" ]]; then
    echo "  · npm install (einmalig für dieses Dependency-Set) …"
    mkdir -p "$CACHE_DIR"
    cp "$WS/package.json" "$CACHE_DIR/package.json"
    ( cd "$CACHE_DIR" && npm install --no-audit --no-fund --loglevel=error ) >> "$BUILD_LOG" 2>&1 \
      || { rm -rf "$CACHE_DIR"; die "npm install fehlgeschlagen — siehe $BUILD_LOG"; }
  fi
  ln -s "$CACHE_DIR/node_modules" "$WS/node_modules"

  echo "  · Build (Pre-Render → Bundle → Tailwind → Assemble) …"
  ( cd "$WS" && node shell/build.mjs ) >> "$BUILD_LOG" 2>&1 \
    || die "Build fehlgeschlagen — siehe $BUILD_LOG (letzte Zeilen: $(tail -3 "$BUILD_LOG" | tr '\n' ' ' | cut -c1-300))"
fi
for f in mockup.html prerendered.json build-report.json; do
  [[ -s "$WS/out/$f" ]] || die "Build-Output unvollständig: out/$f fehlt — siehe $BUILD_LOG"
done

# ── Publish-Gates ───────────────────────────────────────────────────────────
GATES_TMP="$(mktemp)"
AB_SESSION="ui-check-mockup-$$"
cleanup() { rm -f "$GATES_TMP"; agent-browser close --session "$AB_SESSION" >/dev/null 2>&1 || true; }
trap cleanup EXIT

gate() { # $1=id $2=ok|warn|fail $3=Titel $4=Detail
  jq -cn --arg id "$1" --arg st "$2" --arg t "$3" --arg d "${4:-}" \
    '{id:$id, status:$st, title:$t, detail:($d|if .=="" then null else . end)}' >> "$GATES_TMP"
  case "$2" in
    ok)   echo "  ✓ $3" ;;
    warn) echo "  ⚠ $3 — ${4:-}" ;;
    fail) echo "  ✗ $3 — ${4:-}" >&2 ;;
  esac
}

echo "→ Publish-Gates gegen out/mockup.html …"
PRERENDERED="$WS/out/prerendered.json"
REPORT="$WS/out/build-report.json"

# Script-Blöcke ausblenden für Text-Scans (Bundle-Code erzeugt sonst Fehlalarme);
# Styles bleiben drin (CSS lädt Ressourcen).
NOSCRIPT_HTML="$WS/out/.mockup-noscript.html"
awk 'BEGIN{s=0} /<script[ >]/{s=1} s==0{print} /<\/script>/{s=0}' "$OUT_HTML" > "$NOSCRIPT_HTML"

# M1: Title
title="$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' "$OUT_HTML" | head -1)"
if [[ -n "$title" ]]; then gate M1 ok "Title gesetzt („$title“)"
else gate M1 fail "Title fehlt oder leer" "<title> im <head> muss gesetzt sein"; fi

# M2: Meta-Description
mdesc="$(grep -oE '<meta name="description" content="[^"]+"' "$OUT_HTML" | head -1)"
if [[ -n "$mdesc" ]]; then gate M2 ok "Meta-Description gesetzt"
else gate M2 fail "Meta-Description fehlt" '<meta name="description"> muss gesetzt sein'; fi

# M3: Favicon inline
if grep -qE '<link rel="icon" href="data:' "$OUT_HTML"; then gate M3 ok "Favicon vorhanden (inline)"
else gate M3 fail "Favicon fehlt oder nicht inline" 'rel="icon" muss als data:-URI eingebettet sein'; fi

# M4: kein Google-Fonts-CDN (DSGVO) — ganze Datei, auch Bundle-Code.
gf="$(grep -oE 'fonts\.(googleapis|gstatic)\.com' "$OUT_HTML" | sort -u | paste -sd' ' || true)"
if [[ -z "$gf" ]]; then gate M4 ok "Kein Google-Fonts-CDN (DSGVO)"
else gate M4 fail "Google-Fonts-CDN referenziert" "$gf — Bunny Fonts oder Subset inlined verwenden"; fi

# M5: keine externen Ressourcen außer Bunny Fonts (Navigations-Links <a href> sind erlaubt).
ext="$( { grep -oE '<(link|script|img|source|iframe|video|audio|embed|object)[^>]*' "$NOSCRIPT_HTML" \
          | grep -oE '(src|srcset|href)="https?://[^"]+' ;
          grep -oE 'url\(["'"'"']?https?://[^)"'"'"']+' "$NOSCRIPT_HTML" ; } 2>/dev/null \
        | grep -v 'fonts\.bunny\.net' | sort -u | head -5 | paste -sd' · ' || true)"
if [[ -z "$ext" ]]; then gate M5 ok "Keine externen Requests außer Bunny Fonts"
else gate M5 fail "Externe Ressourcen referenziert" "$ext"; fi

# M6: keine Platzhalter-Reste — Lorem in der ganzen Datei, TODO/FIXME im sichtbaren Markup.
lorem="$(grep -oiE 'lorem ipsum' "$OUT_HTML" | head -1 || true)"
todo="$(jq -r '(.safe // "") + " " + (.bold // "")' "$PRERENDERED" | grep -oE '\b(TODO|FIXME|TBD)\b' | head -1 || true)"
if [[ -z "$lorem" && -z "$todo" ]]; then gate M6 ok "Keine Lorem-/TODO-Platzhalter-Reste"
else gate M6 fail "Platzhalter-Reste gefunden" "${lorem:-}${lorem:+ }${todo:-}"; fi

# M7: No-JS-Baseline — beide Varianten vorgerendert + primärer CTA sichtbar.
cta_label="$(jq -r '.conversion.primary_cta.label // ""' "$CONTENT")"
m7_err=()
for v in safe bold; do
  perr="$(jq -r ".${v}_error // \"\"" "$PRERENDERED")"
  plen="$(jq -r "(.$v // \"\") | length" "$PRERENDERED")"
  [[ -n "$perr" ]] && m7_err+=("Pre-Render '$v' fehlgeschlagen: $(cut -c1-140 <<< "$perr")")
  [[ "$plen" -lt 400 ]] && m7_err+=("Variante '$v' nahezu leer vorgerendert (${plen} Zeichen)")
done
[[ -n "$cta_label" ]] && ! grep -qF "$cta_label" "$NOSCRIPT_HTML" && m7_err+=("primärer CTA „$cta_label“ nicht im statischen HTML")
if [[ ${#m7_err[@]} -eq 0 ]]; then gate M7 ok "No-JS-Baseline steht (beide Varianten vorgerendert, CTA sichtbar)"
else gate M7 fail "No-JS-Baseline verletzt" "$(IFS='; '; echo "${m7_err[*]}")"; fi

# M8: interne Anker erreichen ihr Ziel.
anchor_missing=()
while IFS= read -r a; do
  [[ -z "$a" || "$a" == "#" ]] && continue
  grep -qE "id=\"${a#\#}\"" "$NOSCRIPT_HTML" || anchor_missing+=("$a")
done < <(grep -oE 'href="#[^"]*"' "$NOSCRIPT_HTML" | sed 's/^href="//; s/"$//' | sort -u)
if [[ ${#anchor_missing[@]} -eq 0 ]]; then gate M8 ok "Alle internen Anker erreichen ihr Ziel"
else gate M8 fail "Tote interne Anker" "${anchor_missing[*]} ohne passendes id=-Ziel"; fi

# M9: Dateigröße < 5 MB (Warn-Gate mit Treiber-Angabe).
bytes="$(stat -c %s "$OUT_HTML" 2>/dev/null || wc -c < "$OUT_HTML")"
if [[ "$bytes" -lt "$MAX_BYTES" ]]; then
  gate M9 ok "Dateigröße ok ($(awk "BEGIN{printf \"%.1f\", $bytes/1048576}") MB < 5 MB)"
else
  driver="$(jq -r '(.largest_data_uris[0] // null) | if . == null then "kein einzelner Asset-Treiber (CSS/JS/Markup)" else "größter Treiber: \(.mime), \(.bytes/1048576*100 | round/100) MB (base64)" end' "$REPORT")"
  gate M9 warn "Datei größer als 5 MB ($(awk "BEGIN{printf \"%.1f\", $bytes/1048576}") MB)" "$driver — Bilder komprimieren/skalieren"
fi

# M10/M11: Browser-Gates gegen die lokal gebaute Datei (kein Netz).
export AGENT_BROWSER_ARGS="${AGENT_BROWSER_ARGS:---no-sandbox,--disable-dev-shm-usage}"
ab() { agent-browser --session "$AB_SESSION" "$@"; }
ab_eval() { ab eval "$1" --json 2>/dev/null | jq -c '.data.result // empty' 2>/dev/null; }

if ab open "file://$OUT_HTML" >/dev/null 2>&1; then
  ab wait --load load >/dev/null 2>&1 || true
  ab wait 500 >/dev/null 2>&1 || true

  # M11 zuerst (JS-Boot), dann M10 je Variante bei 375 px.
  mounted="$(ab_eval 'JSON.stringify(window.__MOCKUP_MOUNTED || null)')"
  if jq -e 'fromjson? | .safe == true and .bold == true' <<< "$mounted" >/dev/null 2>&1; then
    gate M11 ok "Interaktive Ansicht startet (beide Varianten gemountet)"
  else
    gate M11 warn "Interaktive Ansicht startet nicht vollständig" "window.__MOCKUP_MOUNTED=$mounted — Baseline bleibt nutzbar, Interaktionen prüfen"
  fi

  ab set viewport 375 800 >/dev/null 2>&1
  ab wait 250 >/dev/null 2>&1 || true
  hscroll_err=()
  for v in safe bold; do
    ab_eval "window.__SHELL_SET_VARIANT && window.__SHELL_SET_VARIANT('$v')" >/dev/null
    ab wait 250 >/dev/null 2>&1 || true
    sw="$(ab_eval 'document.documentElement.scrollWidth')"
    if [[ -z "$sw" ]]; then hscroll_err+=("$v: Scrollbreite nicht messbar")
    elif [[ "$sw" -gt 377 ]]; then hscroll_err+=("$v: scrollWidth ${sw}px > 375px"); fi
  done
  if [[ ${#hscroll_err[@]} -eq 0 ]]; then gate M10 ok "Kein horizontales Scrollen bei 375 px (beide Varianten)"
  else gate M10 fail "Horizontales Scrollen bei 375 px" "$(IFS='; '; echo "${hscroll_err[*]}")"; fi
else
  gate M10 fail "Browser-Gate nicht ausführbar" "agent-browser konnte file://$OUT_HTML nicht öffnen"
fi

# ── Ergebnis: gates.json + Promote ──────────────────────────────────────────
summary="$(jq -s '{ok: map(select(.status=="ok"))|length,
                   warn: map(select(.status=="warn"))|length,
                   fail: map(select(.status=="fail"))|length}' "$GATES_TMP")"
n_fail="$(jq -r '.fail' <<< "$summary")"
n_warn="$(jq -r '.warn' <<< "$summary")"

jq -s --arg run_id "$RUN_ID" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson bytes "${bytes:-0}" --argjson summary "$summary" \
   '{run_id: $run_id, checked_at: $now, bytes: $bytes, summary: $summary, gates: .}' \
   "$GATES_TMP" > "$MOCKUP_DIR/gates.json" || die "gates.json konnte nicht geschrieben werden."
cp "$REPORT" "$MOCKUP_DIR/build-report.json" 2>/dev/null || true

echo
if [[ "$n_fail" -gt 0 ]]; then
  update_status failed "$n_fail rote(s) Publish-Gate(s) — siehe mockup/gates.json"
  echo "✗ Export gestoppt: $n_fail rote(s) Gate(s), $n_warn Warnung(en) → $MOCKUP_DIR/gates.json" >&2
  echo "  Kein Publish: mockup.html wurde NICHT in den Run-Ordner übernommen (Diagnose: $OUT_HTML)." >&2
  exit 2
fi

cp "$OUT_HTML" "$RUN_DIR/mockup.html" || die "mockup.html konnte nicht in den Run-Ordner kopiert werden."
if [[ "$n_warn" -gt 0 ]]; then
  update_status degraded "$n_warn Warnung(en) — siehe mockup/gates.json"
  echo "⚠ Export ok mit $n_warn Warnung(en) → $RUN_DIR/mockup.html ($(awk "BEGIN{printf \"%.1f\", $bytes/1048576}") MB)"
  exit 1
else
  update_status ok ""
  echo "✓ Export ok: alle Gates grün → $RUN_DIR/mockup.html ($(awk "BEGIN{printf \"%.1f\", $bytes/1048576}") MB)"
  exit 0
fi
