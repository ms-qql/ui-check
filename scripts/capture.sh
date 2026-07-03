#!/usr/bin/env bash
#
# capture — Seiten-Erfassung (PROJ-1) für die UI-Check-Pipeline
#
# Erfasst eine öffentliche URL visuell + strukturell als Grundlage aller
# weiteren Pipeline-Schritte (PROJ-2/3/4).
#
# Nutzung:
#   capture.sh <url> [--out <run-dir>] [--timeout 60] [--max-height 20000]
#
# Erzeugt (Run-Ordner-Kontrakt):
#   <run-dir>/capture/shot-375.png  shot-768.png  shot-1440.png
#   <run-dir>/capture/snapshot.txt      (A11y-Tree, token-kompakt)
#   <run-dir>/capture/dom-meta.json     (Title, Meta, OG, Favicon, Sektionen)
#   <run-dir>/meta.json                 (URL, finale URL, Status, Dauer, Vermerke)
#
# Exit-Codes:  0 = ok · 2 = Abbruch (nicht erreichbar / Bot-Schutz / kein HTML)
#              1 = interner Fehler (fehlendes Tool, ungültige Argumente)
#
# Alle Meldungen auf Deutsch. Maschinenlesbares Ergebnis in meta.json.

set -uo pipefail

# ── Konfiguration ──────────────────────────────────────────────────────────
VIEWPORTS=(375 768 1440)
DEFAULT_TIMEOUT=60
DEFAULT_MAX_HEIGHT=20000

# Best-Effort-Selektoren + Buttontexte zum Wegklicken gängiger Cookie-Banner.
COOKIE_SELECTORS=(
  "#onetrust-accept-btn-handler"
  "#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll"
  "#CybotCookiebotDialogBodyButtonAccept"
  "#didomi-notice-agree-button"
  ".fc-cta-consent"
  ".cc-allow"
  ".cc-dismiss"
  "button[data-testid='uc-accept-all-button']"
  "#usercentrics-root >>> button[data-testid='uc-accept-all-button']"
)
COOKIE_TEXTS=(
  "Alle akzeptieren"
  "Alle Cookies akzeptieren"
  "Akzeptieren"
  "Zustimmen"
  "Einverstanden"
  "Alle zulassen"
  "Accept all"
  "Accept All Cookies"
  "I agree"
)

# agent-browser braucht in Container/VM-Umgebungen --no-sandbox. Überschreibbar
# über bereits gesetztes AGENT_BROWSER_ARGS.
export AGENT_BROWSER_ARGS="${AGENT_BROWSER_ARGS:---no-sandbox,--disable-dev-shm-usage}"
# Isolierte Session, damit parallele Läufe sich nicht ins Gehege kommen.
export AGENT_BROWSER_SESSION="${AGENT_BROWSER_SESSION:-ui-check-capture-$$}"

# ── Hilfsfunktionen ────────────────────────────────────────────────────────
die_intern() { echo "✗ $*" >&2; exit 1; }

abbruch() {
  # $1 = deutsche Meldung. Schreibt (falls Run-Ordner steht) meta.json und
  # beendet mit Exit 2.
  local msg="$1"
  echo "✗ $msg" >&2
  if [[ -n "${RUN_DIR:-}" && -d "$RUN_DIR" ]]; then
    write_meta "aborted" "$msg"
  fi
  ab_cleanup
  exit 2
}

ab_cleanup() { agent-browser close --session "$AGENT_BROWSER_SESSION" >/dev/null 2>&1 || true; }
trap 'ab_cleanup' EXIT

ab() { agent-browser --session "$AGENT_BROWSER_SESSION" "$@"; }

# eval, das den nackten Result-Wert zurückgibt (aus dem --json-Envelope).
ab_eval() {
  ab eval "$1" --json 2>/dev/null | jq -c '.data.result // empty' 2>/dev/null
}

# ── Argumente parsen ───────────────────────────────────────────────────────
URL=""
OUT=""
TIMEOUT=$DEFAULT_TIMEOUT
MAX_HEIGHT=$DEFAULT_MAX_HEIGHT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)        OUT="${2:-}"; shift 2 ;;
    --timeout)    TIMEOUT="${2:-}"; shift 2 ;;
    --max-height) MAX_HEIGHT="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,30p' "$0"; exit 0 ;;
    -*)           die_intern "Unbekannte Option: $1" ;;
    *)            [[ -z "$URL" ]] && URL="$1" || die_intern "Zu viele Argumente: $1"; shift ;;
  esac
done

[[ -z "$URL" ]] && die_intern "Keine URL angegeben. Nutzung: capture.sh <url> [--out <run-dir>]"

# Protokoll ergänzen, falls fehlend.
[[ "$URL" =~ ^https?:// ]] || URL="https://$URL"

# Tool-Preflight.
command -v agent-browser >/dev/null 2>&1 || die_intern "agent-browser nicht gefunden (npm i -g agent-browser && agent-browser install)."
command -v curl >/dev/null 2>&1 || die_intern "curl nicht gefunden."
command -v jq   >/dev/null 2>&1 || die_intern "jq nicht gefunden."

AB_VERSION="$(agent-browser --version 2>/dev/null | awk '{print $2}')"

# Run-Ordner bestimmen (auto, falls --out fehlt).
domain="$(printf '%s' "$URL" | sed -E 's#^https?://##; s#/.*$##; s#^www\.##; s#[^a-zA-Z0-9.-]#-#g')"
if [[ -z "$OUT" ]]; then
  today="$(date +%F)"
  n=1
  while :; do
    cand="runs/${today}-${domain}-$(printf '%03d' "$n")"
    [[ -e "$cand" ]] || { OUT="$cand"; break; }
    n=$((n+1))
  done
fi
RUN_DIR="$OUT"
CAP_DIR="$RUN_DIR/capture"
mkdir -p "$CAP_DIR" || die_intern "Run-Ordner nicht anlegbar: $RUN_DIR"

START_TS="$(date +%s)"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Vermerke, die meta.json füllen.
FINAL_URL="$URL"
HTTP_STATUS=""
CONTENT_TYPE=""
NUM_REDIRECTS=0
COOKIE_DISMISSED=false
COOKIE_METHOD=""
CONTENT_SUSPICION=""
declare -a NOTES=()
declare -a SHOTS_JSON=()

# ── meta.json schreiben ────────────────────────────────────────────────────
write_meta() {
  # $1 = status (ok|aborted) · $2 = optionale Fehlermeldung
  local status="$1" error="${2:-}"
  local end_ts duration
  end_ts="$(date +%s)"; duration=$((end_ts - START_TS))
  local shots_arr="[]"
  [[ ${#SHOTS_JSON[@]} -gt 0 ]] && shots_arr="[$(IFS=,; echo "${SHOTS_JSON[*]}")]"
  local notes_arr
  notes_arr="$(printf '%s\n' "${NOTES[@]:-}" | jq -R . | jq -s -c 'map(select(length>0))')"

  jq -n \
    --arg url "$URL" \
    --arg final_url "$FINAL_URL" \
    --arg status "$status" \
    --arg error "$error" \
    --arg http "$HTTP_STATUS" \
    --arg ctype "$CONTENT_TYPE" \
    --argjson redirects "${NUM_REDIRECTS:-0}" \
    --arg ts "$TIMESTAMP" \
    --argjson duration "$duration" \
    --arg abver "$AB_VERSION" \
    --argjson cookie_dismissed "$COOKIE_DISMISSED" \
    --arg cookie_method "$COOKIE_METHOD" \
    --arg suspicion "$CONTENT_SUSPICION" \
    --argjson shots "$shots_arr" \
    --argjson notes "$notes_arr" \
    '{
      url: $url,
      final_url: $final_url,
      status: $status,
      error: ($error | if . == "" then null else . end),
      http_status: ($http | if . == "" then null else (tonumber? // .) end),
      content_type: ($ctype | if . == "" then null else . end),
      redirects: $redirects,
      timestamp: $ts,
      duration_seconds: $duration,
      agent_browser_version: $abver,
      cookie_banner: { dismissed: $cookie_dismissed, method: ($cookie_method | if . == "" then null else . end) },
      content_suspicion: ($suspicion | if . == "" then null else . end),
      screenshots: $shots,
      notes: $notes
    }' > "$RUN_DIR/meta.json"
}

# ── Schritt 1: Preflight (curl) ────────────────────────────────────────────
echo "→ Preflight: $URL"
hdr="$(mktemp)"; body="$(mktemp)"
trap 'rm -f "$hdr" "$body"; ab_cleanup' EXIT

curl_out="$(curl -sS -L --max-time "$TIMEOUT" \
  -A "Mozilla/5.0 (compatible; UI-Check/1.0; +https://auxevo.de)" \
  -D "$hdr" -o "$body" \
  -w '%{url_effective}\t%{http_code}\t%{content_type}\t%{num_redirects}' \
  "$URL" 2>/dev/null)"
curl_rc=$?

if [[ $curl_rc -ne 0 ]]; then
  case $curl_rc in
    6)  abbruch "Seite nicht erreichbar: DNS-Auflösung fehlgeschlagen ($URL)" ;;
    7)  abbruch "Seite nicht erreichbar: Verbindung abgelehnt ($URL)" ;;
    28) abbruch "Seite nicht erreichbar: Zeitüberschreitung nach ${TIMEOUT}s ($URL)" ;;
    35|51|60) abbruch "Seite nicht erreichbar: TLS-/Zertifikatsfehler ($URL)" ;;
    *)  abbruch "Seite nicht erreichbar: Netzwerkfehler (curl $curl_rc, $URL)" ;;
  esac
fi

FINAL_URL="$(printf '%s' "$curl_out" | cut -f1)"
HTTP_STATUS="$(printf '%s' "$curl_out" | cut -f2)"
CONTENT_TYPE="$(printf '%s' "$curl_out" | cut -f3)"
NUM_REDIRECTS="$(printf '%s' "$curl_out" | cut -f4)"
[[ "$NUM_REDIRECTS" =~ ^[0-9]+$ ]] || NUM_REDIRECTS=0
[[ "$NUM_REDIRECTS" -gt 0 ]] && NOTES+=("Redirect-Kette: $NUM_REDIRECTS Sprung/Sprünge → $FINAL_URL")

# Bot-Schutz erkennen (Cloudflare/Challenge). Kein Umgehungsversuch.
server_hdr="$(grep -i '^server:' "$hdr" | tail -1 | tr -d '\r')"
if grep -qiE 'just a moment|cf-browser-verification|challenge-platform|cf-chl-|attention required|/cdn-cgi/challenge' "$body" \
   || { [[ "$HTTP_STATUS" =~ ^(403|503)$ ]] && printf '%s' "$server_hdr" | grep -qi cloudflare; } \
   || grep -qi '^cf-mitigated:' "$hdr"; then
  abbruch "Seite ist bot-geschützt — Lauf nicht möglich (Cloudflare-/Bot-Challenge erkannt)"
fi

# HTTP-Status ≥ 400 → Abbruch.
if [[ "$HTTP_STATUS" =~ ^[0-9]+$ ]] && [[ "$HTTP_STATUS" -ge 400 ]]; then
  abbruch "Seite nicht erreichbar: HTTP $HTTP_STATUS ($FINAL_URL)"
fi

# Non-HTML-Ziel (PDF, Bild, …) → Abbruch.
if [[ -n "$CONTENT_TYPE" ]] && ! printf '%s' "$CONTENT_TYPE" | grep -qiE 'text/html|application/xhtml'; then
  abbruch "Kein HTML-Dokument (Content-Type: $CONTENT_TYPE)"
fi

rm -f "$hdr" "$body"
trap 'ab_cleanup' EXIT

# ── Schritt 2: Browse (öffnen, Lazy-Loading, Cookie-Banner) ────────────────
echo "→ Öffne Seite im Browser …"
if ! ab open "$FINAL_URL" >/dev/null 2>&1; then
  abbruch "Seite nicht erreichbar: Browser konnte die Seite nicht laden ($FINAL_URL)"
fi
ab wait --load networkidle >/dev/null 2>&1 || NOTES+=("Network-Idle nicht erreicht (Timeout) — Seite ggf. mit Dauer-Verbindungen")

# Finale URL nach client-seitigen Redirects aktualisieren.
real_url="$(ab get url 2>/dev/null)"
[[ -n "$real_url" && "$real_url" =~ ^https?:// ]] && FINAL_URL="$real_url"

# Cookie-Banner best-effort wegklicken.
echo "→ Cookie-Banner (Best-Effort) …"
for sel in "${COOKIE_SELECTORS[@]}"; do
  if ab is visible "$sel" >/dev/null 2>&1 && ab click "$sel" >/dev/null 2>&1; then
    COOKIE_DISMISSED=true; COOKIE_METHOD="selector:$sel"; break
  fi
done
if [[ "$COOKIE_DISMISSED" != true ]]; then
  for txt in "${COOKIE_TEXTS[@]}"; do
    if ab find text "$txt" click --exact >/dev/null 2>&1; then
      COOKIE_DISMISSED=true; COOKIE_METHOD="text:$txt"; break
    fi
  done
fi
[[ "$COOKIE_DISMISSED" == true ]] \
  && { echo "  ✓ Banner geschlossen ($COOKIE_METHOD)"; ab wait 400 >/dev/null 2>&1; } \
  || echo "  · kein bekanntes Banner gefunden"

# Lazy-Loading durch Scroll-Durchlauf auslösen, danach zurück nach oben.
echo "→ Scroll-Durchlauf (Lazy-Loading) …"
ab_eval "(async()=>{await new Promise(r=>{let y=0;const step=Math.max(400,Math.round(window.innerHeight*0.8));const t=setInterval(()=>{window.scrollBy(0,step);y+=step;if(y>=document.documentElement.scrollHeight){clearInterval(t);r();}},60);setTimeout(()=>{clearInterval(t);r();},15000);});window.scrollTo(0,0);return document.documentElement.scrollHeight;})()" >/dev/null
ab wait --load networkidle >/dev/null 2>&1 || true
ab wait 300 >/dev/null 2>&1 || true

# SPA-Leerverdacht: sehr wenig sichtbarer Text nach Network-Idle.
body_len="$(ab_eval "(() => (document.body && document.body.innerText || '').trim().length)()")"
if [[ "$body_len" =~ ^[0-9]+$ ]] && [[ "$body_len" -lt 40 ]]; then
  CONTENT_SUSPICION="spa_empty"
  NOTES+=("Sehr wenig sichtbarer Textinhalt ($body_len Zeichen) — SPA ohne SSR? content_suspicion=spa_empty")
fi

# ── Schritt 3: Shots (375 / 768 / 1440, Fullpage, mit Höhenkappung) ────────
echo "→ Screenshots …"
for vw in "${VIEWPORTS[@]}"; do
  ab set viewport "$vw" 900 >/dev/null 2>&1
  ab wait 250 >/dev/null 2>&1 || true
  # Lazy-Loading pro Viewport erneut anstoßen (responsive Bilder), zurück nach oben.
  ab_eval "(async()=>{await new Promise(r=>{let y=0;const t=setInterval(()=>{window.scrollBy(0,600);y+=600;if(y>=document.documentElement.scrollHeight){clearInterval(t);r();}},40);setTimeout(()=>{clearInterval(t);r();},8000);});window.scrollTo(0,0);return true;})()" >/dev/null

  page_h="$(ab_eval "(() => Math.max(document.documentElement.scrollHeight, document.body ? document.body.scrollHeight : 0))()")"
  [[ "$page_h" =~ ^[0-9]+$ ]] || page_h=0
  shot="$CAP_DIR/shot-${vw}.png"
  capped=false
  ok=false

  if [[ "$page_h" -gt "$MAX_HEIGHT" ]]; then
    # Kappung: Viewport auf MAX_HEIGHT hochsetzen und die oberen MAX_HEIGHT px als
    # Viewport-Screenshot (ohne --full) aufnehmen — der Rest wird verworfen.
    capped=true
    ab set viewport "$vw" "$MAX_HEIGHT" >/dev/null 2>&1
    ab_eval "(() => { window.scrollTo(0,0); return true; })()" >/dev/null
    ab wait 200 >/dev/null 2>&1 || true
    ab screenshot "$shot" >/dev/null 2>&1 && [[ -s "$shot" ]] && ok=true
    ab set viewport "$vw" 900 >/dev/null 2>&1
    NOTES+=("Viewport ${vw}: Seite ${page_h}px > ${MAX_HEIGHT}px → auf ${MAX_HEIGHT}px gekappt")
  else
    ab screenshot --full "$shot" >/dev/null 2>&1 && [[ -s "$shot" ]] && ok=true
  fi

  if [[ "$ok" == true ]]; then
    [[ "$capped" == true ]] && echo "  ✓ shot-${vw}.png (${page_h}px → ${MAX_HEIGHT}px gekappt)" || echo "  ✓ shot-${vw}.png (${page_h}px)"
    SHOTS_JSON+=("$(jq -n --argjson vp "$vw" --arg path "capture/shot-${vw}.png" --argjson h "$page_h" --argjson capped "$capped" '{viewport:$vp, path:$path, page_height:$h, capped:$capped}')")
  else
    NOTES+=("Viewport ${vw}: Screenshot fehlgeschlagen")
    echo "  ✗ shot-${vw}.png fehlgeschlagen" >&2
  fi
done

# ── Schritt 4: Snapshot (A11y-Tree) + dom-meta ─────────────────────────────
echo "→ A11y-Snapshot + DOM-Meta …"
ab set viewport 1440 900 >/dev/null 2>&1
if ! ab snapshot -c > "$CAP_DIR/snapshot.txt" 2>/dev/null || [[ ! -s "$CAP_DIR/snapshot.txt" ]]; then
  ab snapshot > "$CAP_DIR/snapshot.txt" 2>/dev/null || NOTES+=("A11y-Snapshot fehlgeschlagen")
fi

dom_meta="$(ab_eval "(() => {
  const abs = (u) => { try { return u ? new URL(u, location.href).href : null; } catch(e){ return u||null; } };
  const metaC = (k) => { const e = document.querySelector('meta[name=\"'+k+'\"]') || document.querySelector('meta[property=\"'+k+'\"]'); return e ? (e.getAttribute('content')||null) : null; };
  const iconEl = document.querySelector('link[rel~=\"icon\"]') || document.querySelector('link[rel=\"shortcut icon\"]');
  const og = {}; document.querySelectorAll('meta[property^=\"og:\"]').forEach(m => { const p=m.getAttribute('property'); if(p) og[p]=m.getAttribute('content'); });
  return {
    title: document.title || null,
    meta_description: metaC('description'),
    favicon: iconEl ? abs(iconEl.getAttribute('href')) : abs('/favicon.ico'),
    og: og,
    sections_detected: document.querySelectorAll('section, header, footer, nav, main, article').length
  };
})()")"
if [[ -n "$dom_meta" ]]; then
  printf '%s\n' "$dom_meta" | jq . > "$CAP_DIR/dom-meta.json" 2>/dev/null || printf '%s\n' "$dom_meta" > "$CAP_DIR/dom-meta.json"
else
  echo '{}' > "$CAP_DIR/dom-meta.json"
  NOTES+=("DOM-Meta-Extraktion fehlgeschlagen")
fi

# ── Schritt 5: Finalize ────────────────────────────────────────────────────
write_meta "ok" ""
ab_cleanup

dur=$(( $(date +%s) - START_TS ))
echo "✓ Erfassung abgeschlossen in ${dur}s → $RUN_DIR"
echo "  meta.json · capture/{shot-375,shot-768,shot-1440}.png · snapshot.txt · dom-meta.json"
exit 0
