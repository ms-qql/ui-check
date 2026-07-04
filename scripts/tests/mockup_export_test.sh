#!/usr/bin/env bash
#
# mockup_export_test.sh — Black-Box-QA-Suite für scripts/mockup-export.sh (PROJ-7)
#
# Hermetisch: kein npm, kein Netz, kein Browser. Der Build wird über
# MOCKUP_EXPORT_BUILD_CMD gestubbt (schreibt kontrollierte out/-Artefakte),
# agent-browser über einen PATH-Stub. Getestet werden INIT-Gates,
# Publish-Gates (M1–M11), gates.json, Promote-Verhalten, status.json
# und Exit-Codes.
#
# Optional: MOCKUP_EXPORT_E2E=1 baut zusätzlich einmal ECHT (npm install,
# esbuild/tailwind, echter agent-browser) gegen die Fixture-Varianten.
#
# Nutzung:  scripts/tests/mockup_export_test.sh
# Exit 0 = alle Tests bestanden · 1 = mindestens ein Fehlschlag.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ME="$ROOT/scripts/mockup-export.sh"
RECIPE_V="$(head -1 "$ROOT/recipes/VERSION")"

command -v jq >/dev/null 2>&1 || { echo "✗ jq nicht installiert"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0; declare -a FAILURES=()
ok()  { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $*" >&2; FAIL=$((FAIL+1)); FAILURES+=("$*"); }
assert_eq() { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }
assert_gate() { # $1=gates.json $2=gate-id $3=erwarteter status
  local st; st="$(jq -r --arg id "$2" '.gates[] | select(.id==$id) | .status' "$1" 2>/dev/null)"
  assert_eq "${st:-fehlt}" "$3" "Gate $2"
}

# ── Fixture: vollständiger Run mit kontrakt-konformem redesign/ ─────────────
mk_run() { # $1 = Run-Ordner
  local r="$1" rd="$1/redesign"
  mkdir -p "$rd/shared" "$rd/safe/sections" "$rd/bold/sections"
  mkdir -p "$r/capture"

  jq -n '{url:"https://example.de", final_url:"https://example.de/", status:"ok"}' > "$r/meta.json"
  jq -n '{url:"https://example.de", final_url:"https://example.de/"}' > "$r/ui-check.json"
  jq -n '{run_id:"test", phases:{}}' > "$r/status.json"
  local png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII='
  for vw in 375 768 1440; do
    printf '%s' "$png" | base64 -d > "$r/capture/shot-$vw.png"
  done
  jq -n '{
    "375":[{id:"hero",label:"Hero",y:0,height:180},{id:"kontakt",label:"Kontakt",y:180,height:160}],
    "768":[{id:"hero",label:"Hero",y:0,height:220},{id:"kontakt",label:"Kontakt",y:220,height:180}],
    "1440":[{id:"hero",label:"Hero",y:0,height:260},{id:"kontakt",label:"Kontakt",y:260,height:220}]
  }' > "$r/capture/sections.json"

  jq -n '{color:{palette:[{value:"#0d9488"}]},
          font:{"display+text":{"$type":"fontFamily","$value":["Inter","system-ui","sans-serif"]}}}' \
    > "$rd/shared/tokens.json"
  cat > "$rd/shared/tailwind-theme.css" <<'EOF'
@theme {
  --color-primary: #0d9488;
  --color-surface: #fafafa;
  --color-text: #262626;
  --font-display-text: Inter, ui-sans-serif, system-ui, sans-serif;
}
EOF

  jq -n '{language:"de",
    conversion:{goal:"Terminanfrage", assumed:false,
      primary_cta:{label:"Termin buchen", intent:"kontakt", target:"#kontakt"}},
    sections:[
      {id:"hero", type:"hero",
       heading:"Klarheit für Ihre Website",
       body:"Wir zeigen Ihnen in einem kurzen Gespräch, wo Ihre Seite Besucher verliert und wie zwei konkrete Gestaltungsrichtungen das ändern. Ohne Fachchinesisch, mit messbaren Kriterien und einem klaren nächsten Schritt.",
       cta:{label:"Termin buchen", intent:"kontakt", target:"#kontakt"},
       image_slots:["hero-bild"]},
      {id:"kontakt", type:"cta",
       heading:"Sprechen wir über Ihre Website",
       body:"Ein Termin, dreißig Minuten, konkrete Empfehlungen. Sie entscheiden danach in Ruhe, ob und mit welcher Richtung Sie weitermachen möchten."}
    ]}' > "$rd/shared/content.json"

  echo "# Redesign-Brief (Fixture)" > "$rd/brief.md"
  printf '## Slot: hero-bild\n- Platzhalter + Bild-Prompt (Fixture)\n' > "$rd/images.md"
  jq -n '{sections:[{id:"hero",original:"Hero",change:"Fixture"},{id:"kontakt",original:null,change:"Fixture"}]}' > "$rd/compare.json"
  jq -n '{run_id:"fixture"}' > "$rd/redesign-context.json"
  jq -n '{summary:{ok:12,warn:0,fail:0},gates:[]}' > "$rd/verify.json"

  for v in safe bold; do
    jq -n --arg v "$v" --arg rv "$RECIPE_V" \
      '{variant:$v, recipe_version:$rv, entry:"App.jsx",
        dials:{variance:(if $v=="safe" then 3 else 8 end), motion:2, density:4},
        sections:[{id:"hero",layout:"full-bleed",motion:"none"},{id:"kontakt",layout:"stack",motion:"none"}]}' \
      > "$rd/$v/manifest.json"
  done
  jq -n '{dependencies:{react:"^19.1.0"}}' > "$rd/safe/package.json"
  jq -n '{dependencies:{react:"^19.1.0", motion:"^12.0.0"}}' > "$rd/bold/package.json"

  cat > "$rd/safe/App.jsx" <<'EOF'
import content from "../shared/content.json";

export default function App() {
  return (
    <main className="bg-surface text-text font-display-text">
      {content.sections.map((s) => (
        <section key={s.id} id={s.id} className="mx-auto max-w-3xl px-6 py-16">
          <h2 className="text-3xl font-semibold text-primary">{s.heading}</h2>
          <p className="mt-4 leading-relaxed">{s.body}</p>
          {s.cta && (
            <a className="mt-6 inline-block rounded-md bg-primary px-5 py-2.5 text-surface" href={s.cta.target}>
              {s.cta.label}
            </a>
          )}
          {(s.image_slots || []).map((slot) => (
            <div key={slot} data-image-slot={slot} className="mt-8 h-48 rounded-lg bg-surface" aria-hidden="true" />
          ))}
        </section>
      ))}
    </main>
  );
}
EOF

  cat > "$rd/bold/App.jsx" <<'EOF'
import content from "../shared/content.json";
import { motion } from "motion/react";

export default function App() {
  return (
    <main className="bg-text text-surface font-display-text">
      {content.sections.map((s, i) => (
        <section key={s.id} id={s.id} className="min-h-[50vh] px-6 py-24">
          <motion.h2
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            className="max-w-4xl text-5xl font-semibold text-primary"
          >
            {s.heading}
          </motion.h2>
          <p className="mt-6 max-w-2xl text-lg leading-relaxed">{s.body}</p>
          {s.cta && (
            <a className="mt-8 inline-block rounded-full bg-primary px-6 py-3 text-surface" href={s.cta.target}>
              {s.cta.label}
            </a>
          )}
          {(s.image_slots || []).map((slot) => (
            <div key={slot} data-image-slot={slot} className="mt-10 h-64 rounded-xl bg-surface/10" aria-hidden="true" />
          ))}
        </section>
      ))}
    </main>
  );
}
EOF
}

# ── Stubs ───────────────────────────────────────────────────────────────────
STUB_DIR="$WORK/stubs"; mkdir -p "$STUB_DIR"

# agent-browser-Stub: beantwortet open/wait/set/close/eval; eval wird anhand
# des JS-Strings geroutet (Envelope wie das echte --json-Format).
cat > "$STUB_DIR/agent-browser" <<'EOF'
#!/usr/bin/env bash
args=("$@"); cmd=""; js=""
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    --session) ((i++)) ;;
    --json|--load|-*) : ;;
    open|close|wait|set|eval|snapshot|click|find|get|is|screenshot)
      [[ -z "$cmd" ]] && { cmd="${args[$i]}"; [[ "$cmd" == "eval" ]] && js="${args[$((i+1))]:-}"; } ;;
  esac
done
case "$cmd" in
  open) exit "${STUB_AB_OPEN_RC:-0}" ;;
  eval)
    if [[ "$js" == *__MOCKUP_MOUNTED* ]]; then
      jq -cn --arg m "${STUB_AB_MOUNTED:-{\"safe\":true,\"bold\":true}}" '{data:{result:$m}}'
    elif [[ "$js" == *scrollWidth* ]]; then
      jq -cn --argjson w "${STUB_AB_SW:-375}" '{data:{result:$w}}'
    else
      jq -cn '{data:{result:true}}'
    fi ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$STUB_DIR/agent-browser"
# node/npm dürfen im hermetischen Modus NICHT laufen — Wächter-Stubs.
for t in node npm; do
  printf '#!/usr/bin/env bash\necho "STUB %s aufgerufen — Suite ist nicht hermetisch!" >&2; exit 97\n' "$t" > "$STUB_DIR/$t"
  chmod +x "$STUB_DIR/$t"
done

# Build-Stub: schreibt kontrollierte out/-Artefakte; Variationen über STUB_HTML_MODE.
BUILD_STUB="$WORK/build-stub.sh"
cat > "$BUILD_STUB" <<'EOF'
#!/usr/bin/env bash
set -u
ws="$1"; mkdir -p "$ws/out"
mode="${STUB_HTML_MODE:-good}"

inner_safe='<section id="hero"><h1>Klarheit für Ihre Website</h1><p>Wir zeigen Ihnen in einem kurzen Gespräch, wo Ihre Seite Besucher verliert und wie zwei konkrete Gestaltungsrichtungen das ändern. Ohne Fachchinesisch, mit messbaren Kriterien und einem klaren nächsten Schritt für Ihr Team.</p><a href="#kontakt">Termin buchen</a></section><section id="kontakt"><h2>Sprechen wir über Ihre Website</h2><p>Ein Termin, dreißig Minuten, konkrete Empfehlungen für die nächsten Schritte.</p></section>'
inner_bold="$inner_safe"
extra_head=""; pr_extra='{}'
case "$mode" in
  gfonts)  extra_head='<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter">' ;;
  extern)  extra_head='<img src="https://cdn.example.com/hero.png">' ;;
  lorem)   inner_bold="${inner_bold//konkrete Empfehlungen/Lorem ipsum dolor sit amet}" ;;
  anchor)  inner_safe="${inner_safe//href=\"#kontakt\"/href=\"#missing\"}" ;;
  prerr)   pr_extra='{"bold":"", "bold_error":"window is not defined (Fixture)"}' ;;
esac

title="Redesign-Vorschlag — example.de"
[[ "$mode" == "notitle" ]] && title=""

{
  printf '<!doctype html>\n<html lang="de" class="no-js" data-run-id="fixture">\n<head>\n'
  printf '<meta charset="utf-8">\n<title>%s</title>\n' "$title"
  printf '<meta name="description" content="Redesign-Vorschlag für example.de: zwei Richtungen im Vergleich.">\n'
  printf '<link rel="icon" href="data:image/svg+xml;base64,PHN2Zy8+">\n'
  printf '<link rel="stylesheet" href="https://fonts.bunny.net/css2?family=Inter:wght@400;600&display=swap">\n'
  printf '%s\n<style>.shell-header{position:sticky}</style>\n</head>\n<body data-active-variant="safe">\n' "$extra_head"
  printf '<script>document.documentElement.classList.replace("no-js","js")</script>\n'
  printf '<main><section class="shell-variant" data-variant="safe"><div id="mount-safe">%s</div></section>\n' "$inner_safe"
  printf '<section class="shell-variant" data-variant="bold"><div id="mount-bold">%s</div></section></main>\n' "$inner_bold"
  printf '<section class="shell-proj8-fallback"><h2>Vorher / Nachher</h2><img src="data:image/png;base64,iVBORw0KGgo=" alt="Original-Screenshot"></section>\n'
  printf '<div data-vote-variant="safe">Welche Richtung gefällt Ihnen?</div><div data-vote-variant="bold"></div>\n'
  printf '<div data-split></div><button data-viewport-tab="375">375</button><button data-viewport-tab="768">768</button><button data-viewport-tab="1440">1440</button>\n'
  printf '<button>Antwort kopieren</button><textarea class="shell-copy-text">Gewählte Richtung: Safe</textarea>\n'
  printf '<script>\nvar BUNDLE_MIT_TODO_IM_CODE=1; // TODO-Marker im Bundle darf NICHT feuern\n</script>\n</body>\n</html>\n'
  [[ "$mode" == "big" ]] && { printf '<!-- '; head -c $((5 * 1024 * 1024)) /dev/zero | tr '\0' 'A'; printf ' -->\n'; }
} > "$ws/out/mockup.html"

jq -n --arg s "$inner_safe" --arg b "$inner_bold" --argjson extra "$pr_extra" \
  '{safe:$s, bold:$b} + $extra' > "$ws/out/prerendered.json"
jq -n '{bytes:{total:2048,css:512,js:512}, largest_data_uris:[{mime:"image/png",bytes:1400000}]}' \
  > "$ws/out/build-report.json"
EOF
chmod +x "$BUILD_STUB"

run_export() { # $@ = zusätzliche Args/Env via Variablen; $1=run-dir [...opts]
  PATH="$STUB_DIR:$PATH" MOCKUP_EXPORT_BUILD_CMD="$BUILD_STUB" "$ME" "$@" \
    > "$WORK/last-stdout.log" 2> "$WORK/last-stderr.log"
}

# ════════════════════════════════════════════════════════════════════════════
echo "── INIT-Gates ──"

PATH="$STUB_DIR:$PATH" "$ME" > /dev/null 2>&1; assert_eq "$?" 2 "Ohne Argument → Exit 2"

R="$WORK/r-no-redesign"; mkdir -p "$R"
run_export "$R"; assert_eq "$?" 2 "Fehlendes redesign/ → Exit 2"
grep -q "redesign" "$WORK/last-stderr.log" && ok "Meldung nennt redesign/" || bad "Meldung nennt redesign/ nicht"

R="$WORK/r-no-verify"; mk_run "$R"; rm "$R/redesign/verify.json"
run_export "$R"; assert_eq "$?" 2 "Fehlendes verify.json → Exit 2"

R="$WORK/r-red-verify"; mk_run "$R"
jq -n '{summary:{ok:10,warn:0,fail:2},gates:[]}' > "$R/redesign/verify.json"
run_export "$R"; assert_eq "$?" 2 "Rotes verify.json → Exit 2"

echo "── Happy Path ──"
R="$WORK/r-good"; mk_run "$R"
run_export "$R"; rc=$?
assert_eq "$rc" 0 "Voller Export → Exit 0"
[[ -s "$R/mockup.html" ]] && ok "mockup.html promotet" || bad "mockup.html fehlt im Run-Ordner"
[[ -s "$R/mockup/gates.json" ]] && ok "gates.json geschrieben" || bad "gates.json fehlt"
[[ -s "$R/mockup/build.log" ]] || bad "build.log fehlt"
assert_eq "$(jq -r '.summary.fail' "$R/mockup/gates.json")" 0 "gates.json: 0 rote Gates"
for g in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12 M13 M14 M15 M16 M17; do assert_gate "$R/mockup/gates.json" "$g" ok; done
assert_eq "$(jq -r '.phases.mockup.status' "$R/status.json")" "ok" "status.json phases.mockup"

run_export "$R"; assert_eq "$?" 2 "Erneuter Export ohne --force → Exit 2"
run_export "$R" --force; assert_eq "$?" 0 "Erneuter Export mit --force → Exit 0"

echo "── Rote Publish-Gates (Export stoppt, kein Promote) ──"
for case in "gfonts:M4" "extern:M5" "notitle:M1" "lorem:M6" "anchor:M8" "prerr:M7"; do
  mode="${case%%:*}"; g="${case##*:}"
  R="$WORK/r-$mode"; mk_run "$R"
  STUB_HTML_MODE="$mode" run_export "$R"
  assert_eq "$?" 2 "Modus $mode → Exit 2"
  assert_gate "$R/mockup/gates.json" "$g" fail
  [[ -e "$R/mockup.html" ]] && bad "Modus $mode: mockup.html wurde trotz rotem Gate promotet" || ok "Modus $mode: kein Promote"
done
assert_eq "$(jq -r '.phases.mockup.status' "$WORK/r-gfonts/status.json")" "failed" "status.json failed bei rotem Gate"

echo "── Warn-Gates (degradiert, Promote trotzdem) ──"
R="$WORK/r-big"; mk_run "$R"
STUB_HTML_MODE=big run_export "$R"
assert_eq "$?" 1 "Datei > 5 MB → Exit 1 (Warnung)"
assert_gate "$R/mockup/gates.json" M9 warn
jq -r '.gates[] | select(.id=="M9") | .detail' "$R/mockup/gates.json" | grep -q "image/png" \
  && ok "M9 nennt größten Treiber" || bad "M9 nennt größten Treiber nicht"
[[ -s "$R/mockup.html" ]] && ok "mockup.html trotz Warnung promotet" || bad "mockup.html fehlt trotz nur-Warnung"
assert_eq "$(jq -r '.phases.mockup.status' "$R/status.json")" "degraded" "status.json degraded"

R="$WORK/r-nomount"; mk_run "$R"
STUB_AB_MOUNTED='{"safe":true,"bold":false}' run_export "$R"
assert_eq "$?" 1 "JS-Mount unvollständig → Exit 1 (Warnung M11)"
assert_gate "$R/mockup/gates.json" M11 warn

R="$WORK/r-nosections"; mk_run "$R"; rm "$R/capture/sections.json"
run_export "$R"
assert_eq "$?" 1 "Fehlende sections.json → Exit 1 (Warnung M17)"
assert_gate "$R/mockup/gates.json" M17 warn

R="$WORK/r-nocapture"; mk_run "$R"; rm -rf "$R/capture"
run_export "$R"
assert_eq "$?" 1 "Fehlende Capture-Screenshots → Exit 1 (Warnungen)"
assert_gate "$R/mockup/gates.json" M14 warn
assert_gate "$R/mockup/gates.json" M15 warn
assert_gate "$R/mockup/gates.json" M16 warn
assert_gate "$R/mockup/gates.json" M17 warn

R="$WORK/r-badcompare"; mk_run "$R"
jq '.sections[0].change = ""' "$R/redesign/compare.json" > "$R/redesign/c.json" && mv "$R/redesign/c.json" "$R/redesign/compare.json"
run_export "$R"
assert_eq "$?" 2 "Fehlende Vergleichs-Begründung → Exit 2"
assert_gate "$R/mockup/gates.json" M13 fail

echo "── Browser-Gates ──"
R="$WORK/r-hscroll"; mk_run "$R"
STUB_AB_SW=420 run_export "$R"
assert_eq "$?" 2 "scrollWidth 420 bei 375px → Exit 2"
assert_gate "$R/mockup/gates.json" M10 fail

R="$WORK/r-noopen"; mk_run "$R"
STUB_AB_OPEN_RC=1 run_export "$R"
assert_eq "$?" 2 "agent-browser open scheitert → Exit 2"
assert_gate "$R/mockup/gates.json" M10 fail

# ════════════════════════════════════════════════════════════════════════════
if [[ "${MOCKUP_EXPORT_E2E:-0}" == "1" ]]; then
  echo "── E2E (echter Build: npm + esbuild + tailwind + agent-browser) ──"
  R="$WORK/r-e2e"; mk_run "$R"
  "$ME" "$R" > "$WORK/e2e-stdout.log" 2> "$WORK/e2e-stderr.log"; rc=$?
  assert_eq "$rc" 0 "E2E-Export → Exit 0"
  [[ -s "$R/mockup.html" ]] && ok "E2E: mockup.html vorhanden ($(stat -c %s "$R/mockup.html") Bytes)" || bad "E2E: mockup.html fehlt"
  grep -q "Termin buchen" "$R/mockup.html" && ok "E2E: CTA im statischen HTML" || bad "E2E: CTA fehlt im HTML"
  grep -q "Welche Richtung gefällt Ihnen" "$R/mockup.html" && ok "E2E: Voting-Screen im Bundle" || bad "E2E: Voting-Screen fehlt"
  grep -q "shell-proj8-fallback" "$R/mockup.html" && ok "E2E: No-JS-Fallback Vorher/Nachher" || bad "E2E: PROJ-8-Fallback fehlt"
  grep -q "fonts.bunny.net" "$R/mockup.html" && ok "E2E: Bunny-Fonts-Link" || bad "E2E: Bunny-Fonts-Link fehlt"
  ! grep -qE 'fonts\.(googleapis|gstatic)\.com' "$R/mockup.html" && ok "E2E: kein Google-CDN" || bad "E2E: Google-CDN gefunden"
  cat "$WORK/e2e-stdout.log"

  # ── PROJ-20: gefüllten Bild-Slot einbetten und Einbettung verifizieren (BUG-2) ──
  echo "── E2E: PROJ-20 Bild-Slot-Einbettung ──"
  png20='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII='
  mkdir -p "$R/redesign/assets"
  printf '%s' "$png20" | base64 -d > "$R/redesign/assets/hero-bild.png"
  jq -n '{run_id:"e2e", generated_at:"t", threshold:70, judge:"heuristic",
    sources_available:{stock:true, website:false, generation:null},
    slots:[{slot_id:"hero-bild", used_in:["safe","bold"], prompt:"Dachdecker bei der Arbeit auf einem Ziegeldach",
      target:{width:1600,height:900}, source:"stock:pexels", license:"Pexels License",
      attribution:{photographer:"E2E Tester"}, judge_score:90, file:"assets/hero-bild.png",
      width:1600, height:900, bytes:100}],
    counts:{filled:1, placeholder:0, by_source:{"stock:pexels":1}}, notes:[]}' > "$R/redesign/images-fill.json"
  "$ME" --force "$R" > "$WORK/e2e-p20.log" 2>&1; rc=$?
  assert_eq "$rc" 0 "E2E+PROJ-20: Export → Exit 0"
  grep -qF 'data-image-slot="hero-bild"]{background-image:url("data:image/' "$R/mockup.html" \
    && ok "E2E+PROJ-20: Slot-Bild als base64-background-image eingebettet" \
    || bad "E2E+PROJ-20: Slot-background-image fehlt im HTML"
  grep -q "Dachdecker bei der Arbeit" "$R/mockup.html" \
    && ok "E2E+PROJ-20: aria-label aus Prompt eingebettet" || bad "E2E+PROJ-20: aria-label fehlt"
  if grep -oE '(src|url\()\s*=?\s*["'\'']?https?://[^"'\'' )]+\.(jpe?g|png|webp|gif|avif)' "$R/mockup.html" | grep -qv 'fonts\.bunny\.net'; then
    bad "E2E+PROJ-20: externe Bild-URL im finalen HTML (DSGVO)"; else ok "E2E+PROJ-20: keine externen Bild-Requests (DSGVO)"; fi
  cat "$WORK/e2e-p20.log"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo
echo "═══ $PASS bestanden · $FAIL fehlgeschlagen ═══"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}" >&2
  exit 1
fi
exit 0
