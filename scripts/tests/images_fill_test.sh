#!/usr/bin/env bash
#
# images_fill_test.sh — Black-Box-QA-Suite für scripts/images-fill.sh (PROJ-20)
#
# Vollständig hermetisch: kein echtes Netz, kein Claude. Ein lokaler Python-Mock
# spielt Unsplash/Pexels/OpenAI + ein Bild; die Website-Quelle zeigt auf dasselbe
# lokale Bild. Prüft: 0-€-Platzhalter-Baseline, Website-Quelle, Stock-Vorrang,
# Judge-Schwelle, externer Judge, Idempotenz, Manifest-/Bericht-Kontrakt,
# Exit-Code-Semantik.
#
# Nutzung:  scripts/tests/images_fill_test.sh
# Exit 0 = alle Tests bestanden · 1 = mindestens ein Fehlschlag.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
IF="$ROOT/scripts/images-fill.sh"
WORK="$(mktemp -d)"
MOCK_PID=""
cleanup() { [[ -n "$MOCK_PID" ]] && kill "$MOCK_PID" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

command -v jq >/dev/null 2>&1 || { echo "✗ jq nicht installiert"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "✗ python3 nicht installiert"; exit 1; }

PASS=0; FAIL=0; declare -a FAILURES=()
ok()  { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $*" >&2; FAIL=$((FAIL+1)); FAILURES+=("$*"); }
assert_eq() { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }

# ── Mock-Server (Unsplash/Pexels/OpenAI + 1×1-PNG) ──────────────────────────
cat > "$WORK/mock.py" <<'PY'
import base64, json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs
PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")
class H(BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def _png(self):
        self.send_response(200); self.send_header("Content-Type","image/png"); self.end_headers(); self.wfile.write(PNG)
    def _json(self,obj):
        b=json.dumps(obj).encode(); self.send_response(200); self.send_header("Content-Type","application/json"); self.end_headers(); self.wfile.write(b)
    def do_POST(self):
        p=self.path.split("?")[0]
        if p.endswith("/v1/images/generations"):
            self._json({"data":[{"b64_json":base64.b64encode(PNG).decode()}]}); return
        self.send_response(404); self.end_headers()
    def do_GET(self):
        u=urlparse(self.path); p=u.path
        q=(parse_qs(u.query).get("query") or [""])[0]   # empfangene Suchquery zurückspiegeln
        host=self.headers.get("Host","127.0.0.1")
        img="http://%s/img.png"%host
        if p=="/img.png": self._png(); return
        if p.endswith("/search/photos"):   # Unsplash — Fotograf = empfangene Query (Reflexion)
            self._json({"results":[{"urls":{"regular":img},"links":{"html":"http://site/u","download_location":"http://%s/dl"%host},"width":1600,"height":900,"user":{"name":q or "Foto Graf","links":{"html":"http://u/graf"}}}]}); return
        if p.endswith("/v1/search"):        # Pexels
            self._json({"photos":[{"src":{"large2x":img},"url":"http://site/p","width":1600,"height":900,"photographer":"Pex Elson","photographer_url":"http://p/elson"}]}); return
        if p=="/dl": self._json({"url":img}); return
        self.send_response(404); self.end_headers()
srv=ThreadingHTTPServer(("127.0.0.1",0),H)
print("READY %d"%srv.server_address[1],flush=True)
srv.serve_forever()
PY
exec 3< <(python3 "$WORK/mock.py"); MOCK_PID=$!
read -r _ PORT <&3
[[ "$PORT" =~ ^[0-9]+$ ]] || { echo "✗ Mock-Server nicht gestartet"; exit 1; }
BASE="http://127.0.0.1:$PORT"
IMG_URL="$BASE/img.png"

# ── Redesign-Fixture ────────────────────────────────────────────────────────
mk_run() { # $1=dir  [$2=website-img-breite]  [$3=website-img-höhe]
  local d="$1" w="${2:-1600}" h="${3:-900}"
  local rd="$d/redesign"
  mkdir -p "$rd/shared" "$rd/safe" "$rd/bold" "$d/capture"
  jq -n '{language:"de",sections:[{id:"hero",type:"hero",heading:"Meisterbetrieb für Dächer",image_slots:["hero-bild"]}]}' > "$rd/shared/content.json"
  cat > "$rd/images.md" <<'EOF'
## Slot: hero-bild
- **Platzhalter:** Token-Fläche (surface) mit Slot-Label, 1600×900
- **Bild-Prompt:** "Fotorealistische Aufnahme eines Dachdeckers bei der Arbeit, warmes Tageslicht, 16:9"
EOF
  echo '<div data-image-slot="hero-bild"></div>' > "$rd/safe/App.jsx"
  echo '<div data-image-slot="hero-bild"></div>' > "$rd/bold/App.jsx"
  jq -n --arg u "$IMG_URL" --argjson w "$w" --argjson h "$h" \
    '{domain:"ex.test",count:1,images:[{url:$u,width:$w,height:$h,alt:"Team am Bau",source:"img"}],og_image:null}' \
    > "$d/capture/page-images.json"
  jq -n '{run_id:"t",status:"done",phases:{}}' > "$d/status.json"
}

echo "── Test 1: keine Quelle aktiv → Platzhalter, Exit 0 (0-€-Baseline)"
R1="$WORK/r1"; mkdir -p "$R1"; mk_run "$R1"
rm -f "$R1/capture/page-images.json"   # auch Website aus
( cd "$ROOT" && env -u UNSPLASH_ACCESS_KEY -u PEXELS_API_KEY -u OPENAI_API_KEY -u FAL_KEY -u RECRAFT_API_KEY \
    bash "$IF" "$R1" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "0" "Exit 0 ohne aktive Quelle"
assert_eq "$(jq -r '.counts.filled' "$R1/redesign/images-fill.json")" "0" "0 gefüllt"
assert_eq "$(jq -r '.slots[0].source' "$R1/redesign/images-fill.json")" "placeholder" "Slot = placeholder"
[[ ! -e "$R1/redesign/assets/hero-bild."* ]] 2>/dev/null && ok "kein Asset angelegt" || { ls "$R1/redesign/assets" 2>/dev/null | grep -q hero && bad "unerwartetes Asset" || ok "kein Asset angelegt"; }

echo "── Test 2: Website-Quelle füllt Slot, Exit 0"
R2="$WORK/r2"; mkdir -p "$R2"; mk_run "$R2"
( cd "$ROOT" && env -u UNSPLASH_ACCESS_KEY -u PEXELS_API_KEY bash "$IF" "$R2" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "0" "Exit 0 mit gefülltem Slot"
assert_eq "$(jq -r '.slots[0].source' "$R2/redesign/images-fill.json")" "website" "Quelle = website"
f="$(jq -r '.slots[0].file' "$R2/redesign/images-fill.json")"
[[ -s "$R2/redesign/$f" ]] && ok "Asset-Datei vorhanden ($f)" || bad "Asset-Datei fehlt ($f)"
assert_eq "$(jq -r '.slots[0].used_in|sort|join(",")' "$R2/redesign/images-fill.json")" "bold,safe" "used_in = safe+bold"

echo "── Test 3: Stock hat Vorrang vor Website (F2=C)"
R3="$WORK/r3"; mkdir -p "$R3"; mk_run "$R3"
( cd "$ROOT" && UNSPLASH_ACCESS_KEY=k UNSPLASH_API_BASE="$BASE/unsplash" PEXELS_API_BASE="$BASE/pexels" \
    bash "$IF" "$R3" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "0" "Exit 0"
assert_eq "$(jq -r '.slots[0].source' "$R3/redesign/images-fill.json")" "stock:unsplash" "Quelle = stock:unsplash (vor Website)"
# Der Mock spiegelt die empfangene Query als Fotografennamen — so lässt sich BUG-1
# (Query-Bereinigung) prüfen: Heading "Meisterbetrieb für Dächer", Slot "hero-bild"
# → Stopwort "für" + Slot-Wörter "hero"/"bild" raus.
q3="$(jq -r '.slots[0].attribution.photographer' "$R3/redesign/images-fill.json")"
[[ "$q3" == *meisterbetrieb* && "$q3" == *dächer* ]] && ok "Fallback-Query gebaut ($q3)" || bad "Query falsch — war '$q3'"
[[ "$q3" != *für* && "$q3" != *hero* && "$q3" != *bild* ]] && ok "Query ohne Stopwörter/Slot-Wörter" || bad "Query enthält Füllwörter — '$q3'"

echo "── Test 4: Judge-Schwelle greift → Platzhalter trotz aktiver Quelle, Exit 1"
R4="$WORK/r4"; mkdir -p "$R4"; mk_run "$R4"
( cd "$ROOT" && env -u UNSPLASH_ACCESS_KEY -u PEXELS_API_KEY bash "$IF" --threshold 101 "$R4" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "1" "Exit 1 (degradiert)"
assert_eq "$(jq -r '.slots[0].source' "$R4/redesign/images-fill.json")" "placeholder" "Slot = placeholder (unter Schwelle)"

echo "── Test 5: externer Judge akzeptiert (Score 88)"
R5="$WORK/r5"; mkdir -p "$R5"; mk_run "$R5"
( cd "$ROOT" && env -u UNSPLASH_ACCESS_KEY -u PEXELS_API_KEY IMAGES_FILL_JUDGE_CMD='cat >/dev/null; echo 88' \
    bash "$IF" "$R5" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "0" "Exit 0"
assert_eq "$(jq -r '.judge' "$R5/redesign/images-fill.json")" "external" "Judge-Modus = external"
assert_eq "$(jq -r '.slots[0].judge_score' "$R5/redesign/images-fill.json")" "88" "Score aus externem Judge"

echo "── Test 6: Generierung (OpenAI-Mock) füllt ohne Judge"
R6="$WORK/r6"; mkdir -p "$R6"; mk_run "$R6"; rm -f "$R6/capture/page-images.json"
( cd "$ROOT" && OPENAI_API_KEY=k OPENAI_API_BASE="$BASE/openai" bash "$IF" "$R6" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "0" "Exit 0"
assert_eq "$(jq -r '.slots[0].source' "$R6/redesign/images-fill.json")" "generated:openai" "Quelle = generated:openai"
assert_eq "$(jq -r '.slots[0].judge_score' "$R6/redesign/images-fill.json")" "null" "kein Judge-Score bei Generierung"

echo "── Test 7: Idempotenz — zweiter Lauf lässt gefüllten Slot stehen"
sig1="$(jq -r '.slots[0].file' "$R2/redesign/images-fill.json")"
( cd "$ROOT" && env -u UNSPLASH_ACCESS_KEY -u PEXELS_API_KEY bash "$IF" "$R2" > "$WORK/r2b.log" 2>&1 ); rc=$?
grep -q "übersprungen" "$WORK/r2b.log" && ok "zweiter Lauf meldet 'übersprungen'" || bad "Idempotenz-Meldung fehlt"
assert_eq "$(jq -r '.slots[0].source' "$R2/redesign/images-fill.json")" "website" "Quelle nach Re-Run stabil"

echo "── Test 8: Bericht + Manifest-Kontrakt"
[[ -s "$R3/redesign/images-fill.md" ]] && ok "images-fill.md geschrieben" || bad "images-fill.md fehlt"
grep -q "hero-bild" "$R3/redesign/images-fill.md" && ok "Bericht listet Slot" || bad "Bericht ohne Slot"
assert_eq "$(jq -r '.sources_available.generation' "$R3/redesign/images-fill.json")" "null" "keine Generierung aktiv"

echo "── Test 9: images-fill-queries.json übersteuert die Query (BUG-1-Fix)"
R9="$WORK/r9"; mkdir -p "$R9"; mk_run "$R9"
jq -n '{"hero-bild":{query:"roofer installing tiles on a roof",orientation:"landscape"}}' > "$R9/redesign/images-fill-queries.json"
( cd "$ROOT" && UNSPLASH_ACCESS_KEY=k UNSPLASH_API_BASE="$BASE/unsplash" \
    bash "$IF" "$R9" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "0" "Exit 0"
assert_eq "$(jq -r '.slots[0].attribution.photographer' "$R9/redesign/images-fill.json")" "roofer installing tiles on a roof" "Skill-Query 1:1 an Stock übergeben"

echo "── Test 10: fehlerhafte queries.json → Fallback-Query (kein Abbruch)"
R10="$WORK/r10"; mkdir -p "$R10"; mk_run "$R10"
echo 'kein json' > "$R10/redesign/images-fill-queries.json"
( cd "$ROOT" && UNSPLASH_ACCESS_KEY=k UNSPLASH_API_BASE="$BASE/unsplash" \
    bash "$IF" "$R10" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "0" "Exit 0 trotz kaputter queries.json"
q10="$(jq -r '.slots[0].attribution.photographer' "$R10/redesign/images-fill.json")"
[[ "$q10" == *meisterbetrieb* ]] && ok "Fallback-Query greift ($q10)" || bad "Fallback fehlt — '$q10'"

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "✓ Alle $PASS Tests bestanden."; exit 0
else
  echo "✗ $FAIL Fehlschlag(e), $PASS bestanden:"; printf '  - %s\n' "${FAILURES[@]}" >&2; exit 1
fi
