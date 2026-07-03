#!/usr/bin/env bash
#
# lh-audit — Lighthouse-Audit (PROJ-2) für die UI-Check-Pipeline
#
# Misst die technische Qualität einer öffentlichen URL mit der lokalen
# Lighthouse-CLI (headless Chrome): Performance/Core-Web-Vitals, Accessibility,
# SEO, Best Practices — als maschinenlesbare Basis für PROJ-4 (Score-Panel).
#
# Nutzung:
#   lh-audit.sh <url> [--out <run-dir>] [--desktop] [--timeout 120]
#
# Erzeugt (Run-Ordner-Kontrakt):
#   <run-dir>/lighthouse/lighthouse-mobile.json    Voll-Report (Beweis/Archiv)
#   <run-dir>/lighthouse/lighthouse-desktop.json   nur bei --desktop
#   <run-dir>/lighthouse/lh-summary.json           4 Kategorie-Scores · CWV mit
#                                                   Google-Bewertung · Top-5-
#                                                   Opportunities · status ok|failed
#
# Exit-Codes:  0 = ok · 1 = failed (Lighthouse-Absturz/Timeout ODER interner
#              Fehler). Die Pipeline degradiert bewusst, statt abzubrechen:
#              bei status=failed steht trotzdem ein lh-summary.json mit Grund.
#
# Alle Meldungen auf Deutsch. Maschinenlesbares Ergebnis in lh-summary.json.

set -uo pipefail

# ── Konfiguration ──────────────────────────────────────────────────────────
DEFAULT_TIMEOUT=120
CATEGORIES="performance,accessibility,best-practices,seo"
CHROME_FLAGS="--headless=new --no-sandbox --disable-dev-shm-usage"

# ── Hilfsfunktionen ────────────────────────────────────────────────────────
die_intern() { echo "✗ $*" >&2; exit 1; }

# ── Argumente parsen ───────────────────────────────────────────────────────
URL=""
OUT=""
DESKTOP=false
TIMEOUT=$DEFAULT_TIMEOUT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)     OUT="${2:-}"; shift 2 ;;
    --desktop) DESKTOP=true; shift ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,31p' "$0"; exit 0 ;;
    -*)        die_intern "Unbekannte Option: $1" ;;
    *)         [[ -z "$URL" ]] && URL="$1" || die_intern "Zu viele Argumente: $1"; shift ;;
  esac
done

[[ -z "$URL" ]] && die_intern "Keine URL angegeben. Nutzung: lh-audit.sh <url> [--out <run-dir>] [--desktop]"
[[ "$TIMEOUT" =~ ^[0-9]+$ ]] || die_intern "--timeout erwartet eine Zahl (Sekunden), war: $TIMEOUT"

# Protokoll ergänzen, falls fehlend.
[[ "$URL" =~ ^https?:// ]] || URL="https://$URL"

# Tool-Preflight.
command -v lighthouse >/dev/null 2>&1 || die_intern "lighthouse nicht gefunden (npm i -g lighthouse)."
command -v jq         >/dev/null 2>&1 || die_intern "jq nicht gefunden."

LH_VERSION="$(lighthouse --version 2>/dev/null | head -1)"

# Chrome für Lighthouse bestimmen (CHROME_PATH respektieren, sonst suchen).
if [[ -z "${CHROME_PATH:-}" ]]; then
  for c in chrome google-chrome chromium chromium-browser; do
    if command -v "$c" >/dev/null 2>&1; then CHROME_PATH="$(command -v "$c")"; break; fi
  done
fi
[[ -n "${CHROME_PATH:-}" ]] || die_intern "Kein Chrome/Chromium gefunden. CHROME_PATH setzen oder Chrome installieren."
export CHROME_PATH

# Run-Ordner bestimmen (auto, falls --out fehlt) — gleiche Konvention wie capture.sh.
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
LH_DIR="$RUN_DIR/lighthouse"
mkdir -p "$LH_DIR" || die_intern "Run-Ordner nicht anlegbar: $LH_DIR"

MOBILE_JSON="$LH_DIR/lighthouse-mobile.json"
DESKTOP_JSON="$LH_DIR/lighthouse-desktop.json"
SUMMARY_JSON="$LH_DIR/lh-summary.json"

START_TS="$(date +%s)"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Cookie-Banner-Vermerk aus PROJ-1 (capture meta.json) spiegeln, falls vorhanden.
COOKIE_BANNER="null"
if [[ -s "$RUN_DIR/meta.json" ]]; then
  COOKIE_BANNER="$(jq -c '
    (.cookie_banner // null) as $cb
    | if $cb == null then null
      else {
        dismissed: ($cb.dismissed // false),
        note: (if ($cb.dismissed // false) then null
               else "Consent-/Cookie-Wall bei der Erfassung nicht geschlossen — Messwerte ggf. verfälscht." end)
      } end' "$RUN_DIR/meta.json" 2>/dev/null)"
  [[ -z "$COOKIE_BANNER" ]] && COOKIE_BANNER="null"
fi

# ── Lighthouse-Lauf (eine Form-Factor) ─────────────────────────────────────
# $1 = out-json · $2 = "mobile"|"desktop" · Rückgabe: 0 = ok, sonst Fehler.
run_lh() {
  local out="$1" ff="$2" preset=() rc
  [[ "$ff" == "desktop" ]] && preset=(--preset=desktop)
  echo "→ Lighthouse ($ff) …"
  timeout "${TIMEOUT}s" lighthouse "$URL" \
    --output=json --output-path="$out" \
    --only-categories="$CATEGORIES" \
    --chrome-flags="$CHROME_FLAGS" \
    "${preset[@]}" \
    --quiet 2>>"$LH_DIR/lighthouse.log"
  rc=$?
  if [[ $rc -eq 124 ]]; then
    echo "  ✗ Zeitüberschreitung nach ${TIMEOUT}s" >&2
    return 124
  fi
  if [[ $rc -ne 0 ]]; then
    echo "  ✗ Lighthouse-Fehler (Exit $rc)" >&2
    return "$rc"
  fi
  # Report muss gültiges JSON sein und darf keinen runtimeError tragen.
  if [[ ! -s "$out" ]] || ! jq -e . "$out" >/dev/null 2>&1; then
    echo "  ✗ Kein gültiger Report erzeugt" >&2
    return 3
  fi
  local re
  re="$(jq -r '.runtimeError.code // empty' "$out" 2>/dev/null)"
  if [[ -n "$re" ]]; then
    echo "  ✗ Laufzeitfehler: $re" >&2
    return 4
  fi
  return 0
}

# ── failed-Summary schreiben + beenden ─────────────────────────────────────
write_failed() {
  local reason="$1" end_ts duration
  end_ts="$(date +%s)"; duration=$((end_ts - START_TS))
  jq -n \
    --arg url "$URL" \
    --arg reason "$reason" \
    --arg ts "$TIMESTAMP" \
    --argjson duration "$duration" \
    --arg lhver "$LH_VERSION" \
    --argjson cookie "$COOKIE_BANNER" \
    '{
      url: $url,
      final_url: null,
      status: "failed",
      error: $reason,
      timestamp: $ts,
      duration_seconds: $duration,
      lighthouse_version: $lhver,
      form_factors: [],
      scores: null,
      core_web_vitals: null,
      opportunities: [],
      cookie_banner: $cookie
    }' > "$SUMMARY_JSON"
  echo "✗ Audit fehlgeschlagen: $reason → $SUMMARY_JSON (Pipeline läuft degradiert weiter)" >&2
  exit 1
}

# ── Mobile (Default, Pflicht) ──────────────────────────────────────────────
run_lh "$MOBILE_JSON" "mobile"; rc=$?
if [[ $rc -ne 0 ]]; then
  case $rc in
    124) write_failed "Zeitüberschreitung nach ${TIMEOUT}s (Mobile-Lauf)" ;;
    4)   write_failed "Lighthouse-Laufzeitfehler: $(jq -r '.runtimeError.message // .runtimeError.code // "unbekannt"' "$MOBILE_JSON" 2>/dev/null)" ;;
    *)   write_failed "Lighthouse-Mobile-Lauf fehlgeschlagen (Exit $rc) — Details in lighthouse.log" ;;
  esac
fi

FORM_FACTORS='["mobile"]'

# ── Desktop (optional) ─────────────────────────────────────────────────────
# Für jq per --slurpfile referenziert (große Reports sprengen ARG_MAX). Ohne
# Desktop zeigt DESKTOP_SLURP auf eine leere Datei → $desk wird [].
HAVE_DESKTOP=false
DESKTOP_SLURP="$(mktemp)"
if [[ "$DESKTOP" == true ]]; then
  if run_lh "$DESKTOP_JSON" "desktop"; then
    DESKTOP_SLURP="$DESKTOP_JSON"
    HAVE_DESKTOP=true
    FORM_FACTORS='["mobile","desktop"]'
  else
    echo "  · Desktop-Lauf fehlgeschlagen — nur Mobile-Ergebnis im Summary" >&2
    rm -f "$DESKTOP_JSON"
  fi
fi

# ── Extraktion lh-summary.json ─────────────────────────────────────────────
echo "→ Extrahiere lh-summary.json …"
END_TS="$(date +%s)"; DURATION=$((END_TS - START_TS))

jq -n \
  --slurpfile mob "$MOBILE_JSON" \
  --slurpfile desk "$DESKTOP_SLURP" \
  --arg url "$URL" \
  --arg ts "$TIMESTAMP" \
  --argjson duration "$DURATION" \
  --arg lhver "$LH_VERSION" \
  --argjson forms "$FORM_FACTORS" \
  --argjson cookie "$COOKIE_BANNER" '
  def scoreOf($r; $k): ($r.categories[$k].score) | if . == null then null else (.*100|round) end;
  def rate($v; $g; $n): if $v == null then "unknown"
                        elif $v <= $g then "good"
                        elif $v <= $n then "needs-improvement"
                        else "poor" end;
  def num($r; $id): $r.audits[$id].numericValue // null;
  def r3($v): if $v == null then null else (($v*1000|round)/1000) end;
  def cwv($r):
    { lcp:         { value_ms: (num($r;"largest-contentful-paint")|if .==null then null else round end),
                     rating: rate(num($r;"largest-contentful-paint");2500;4000) },
      cls:         { value:    r3(num($r;"cumulative-layout-shift")),
                     rating: rate(num($r;"cumulative-layout-shift");0.1;0.25) },
      tbt:         { value_ms: (num($r;"total-blocking-time")|if .==null then null else round end),
                     rating: rate(num($r;"total-blocking-time");200;600) },
      fcp:         { value_ms: (num($r;"first-contentful-paint")|if .==null then null else round end),
                     rating: rate(num($r;"first-contentful-paint");1800;3000) },
      speed_index: { value_ms: (num($r;"speed-index")|if .==null then null else round end),
                     rating: rate(num($r;"speed-index");3400;5800) } };
  def scores($r): { performance:    scoreOf($r;"performance"),
                    accessibility:  scoreOf($r;"accessibility"),
                    best_practices: scoreOf($r;"best-practices"),
                    seo:            scoreOf($r;"seo") };
  def opps($r): [ $r.audits | to_entries[]
                  | select(.value.details.type=="opportunity")
                  | select((.value.details.overallSavingsMs // 0) > 0)
                  | { id: .key, title: .value.title,
                      savings_ms: (.value.details.overallSavingsMs|round) } ]
                | sort_by(-.savings_ms) | .[0:5];
  ($mob[0]) as $m |
  ($desk[0] // null) as $d |
  {
    url: $url,
    final_url: ($m.finalDisplayedUrl // $m.finalUrl // $url),
    status: "ok",
    error: null,
    timestamp: $ts,
    duration_seconds: $duration,
    lighthouse_version: $lhver,
    form_factors: $forms,
    scores: scores($m),
    core_web_vitals: cwv($m),
    opportunities: opps($m),
    cookie_banner: $cookie
  }
  + (if $d == null then {} else { desktop: { scores: scores($d), core_web_vitals: cwv($d) } } end)
  ' > "$SUMMARY_JSON" || write_failed "Summary-Extraktion fehlgeschlagen (ungültiger Report?)"

# ── Ausgabe ────────────────────────────────────────────────────────────────
echo "✓ Audit abgeschlossen in ${DURATION}s → $RUN_DIR"
jq -r '"  Scores  P:\(.scores.performance) A:\(.scores.accessibility) BP:\(.scores.best_practices) SEO:\(.scores.seo)"' "$SUMMARY_JSON" 2>/dev/null
jq -r '"  CWV     LCP:\(.core_web_vitals.lcp.value_ms)ms(\(.core_web_vitals.lcp.rating)) CLS:\(.core_web_vitals.cls.value)(\(.core_web_vitals.cls.rating)) TBT:\(.core_web_vitals.tbt.value_ms)ms(\(.core_web_vitals.tbt.rating))"' "$SUMMARY_JSON" 2>/dev/null
echo "  lighthouse/{lighthouse-mobile.json$([[ "$HAVE_DESKTOP" == true ]] && echo ', lighthouse-desktop.json')} · lh-summary.json"
exit 0
