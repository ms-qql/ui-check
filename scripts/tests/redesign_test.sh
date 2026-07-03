#!/usr/bin/env bash
#
# redesign_test.sh — Black-Box-QA-Suite für scripts/redesign.sh (PROJ-6)
#
# Vollständig hermetisch: kein Browser, kein Netz, kein Claude — Run-Ordner und
# generierte Redesigns sind Fixtures. Prüft INIT-Gates, Kontext-Bündelung,
# alle Verify-Gates (grün/gelb/rot) und die Exit-Code-Semantik.
#
# Nutzung:  scripts/tests/redesign_test.sh
# Exit 0 = alle Tests bestanden · 1 = mindestens ein Fehlschlag.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RG="$ROOT/scripts/redesign.sh"
RCV="$(head -1 "$ROOT/recipes/VERSION")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v jq >/dev/null 2>&1 || { echo "✗ jq nicht installiert"; exit 1; }

PASS=0; FAIL=0
declare -a FAILURES=()
ok()  { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $*" >&2; FAIL=$((FAIL+1)); FAILURES+=("$*"); }
assert_eq() { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }
gate_status() { jq -r --arg id "$2" '.gates[] | select(.id==$id) | .status' "$1/redesign/verify.json" 2>/dev/null; }

# ── Fixture: abgeschlossener Stufe-1-Lauf ───────────────────────────────────
mk_run() { # $1=dir
  mkdir -p "$1/branding"
  jq -n '{url:"https://ex.test",final_url:"https://ex.test/",status:"ok"}' > "$1/meta.json"
  jq -n '{total:61, rubric_version:"2026.07-1", cta_present:true,
          dimensions:{visuell:{score:58,measurable:true},
                      conversion:{score:52,measurable:true,
                        subscores:{clarity:60,credibility:55,logic:50,action:40,emotion:55}}},
          findings:[{title:"CTA unter dem Fold",severity:"hoch",
                     evidence:"Kein CTA im Viewport",location:"Hero, 375px",source:"conversion"}]}' > "$1/scores.json"
  jq -n '{color:{palette:[{hex:"#112233"},{hex:"#eeddcc"}],
                 primary:{hex:"#112233"},surface:{hex:"#ffffff"},text:{hex:"#111827"}},
          font:{display:"Georgia"}}' > "$1/branding/tokens.json"
  printf '@theme {\n  --color-primary: #112233;\n  --color-accent: #eeddcc;\n  --color-surface: #ffffff;\n  --color-text: #111827;\n}\n' \
    > "$1/branding/tailwind-theme.css"
  jq -n '{status:"ok",logo:{source:"dom"}}' > "$1/branding/branding-meta.json"
  jq -n '{run_id:"t",url:"https://ex.test",final_url:"https://ex.test/",
          industry_tag:"handwerk",industry_source:"explicit",
          user_prompt:"Fokus auf Terminbuchung",rubric_version:"2026.07-1"}' > "$1/ui-check.json"
  jq -n '{run_id:"t",status:"done",phases:{capture:{status:"ok"},scoring:{status:"ok"}}}' > "$1/status.json"
}

# ── Fixture: vollständig regelkonformes Redesign ────────────────────────────
mk_redesign_ok() { # $1=run-dir
  local rd="$1/redesign"
  cat > "$rd/brief.md" <<'EOF'
# Redesign-Brief
## Conversion-Ziel
Terminanfrage über das Kontaktformular.
## Primärer CTA
"Termin buchen" · intent: kontakt · Ziel: #kontakt
## Sektionsplan
hero → leistungen → vertrauen → kontakt
## Brand-Entscheidungen
Palette und Fonts unverändert übernommen (keine Anpassungen nötig).
## Anti-Slop-Constraints
Ein CTA-Label pro Intent; keine erfundenen Zahlen; Token-Treue.
EOF
  jq -n '{language:"de",
    conversion:{goal:"Terminanfrage",assumed:false,
      primary_cta:{label:"Termin buchen",intent:"kontakt",target:"#kontakt"}},
    sections:[
      {id:"hero",type:"hero",heading:"Meisterbetrieb seit 1998",
       body:"Wir sanieren Bäder in Festpreis und Termintreue.",
       cta:{label:"Termin buchen",intent:"kontakt",target:"#kontakt"},
       image_slots:["hero-bild"]},
      {id:"leistungen",type:"leistungen",heading:"Leistungen",body:"Bad, Heizung, Notdienst.",image_slots:[]},
      {id:"kontakt",type:"cta",heading:"Bereit?",body:"Rufen Sie uns an.",
       cta:{label:"Termin buchen",intent:"kontakt",target:"#kontakt"},image_slots:[]}
    ]}' > "$rd/shared/content.json"
  jq -n '{sections:[
    {id:"hero",original:"Hero mit Slider",change:"Slider durch statisches Hero mit klarem CTA ersetzt."},
    {id:"leistungen",original:"Leistungsliste",change:"Liste zu gewichteter Zwei-Spalten-Gruppe umgebaut."},
    {id:"kontakt",original:null,change:"Neu: dedizierte CTA-Sektion fuer das Conversion-Ziel."}
  ]}' > "$rd/compare.json"
  cat > "$rd/images.md" <<'EOF'
# Bild-Slots
## Slot: hero-bild
- **Platzhalter:** Token-Fläche (surface), 1600×900
- **Bild-Prompt:** "Handwerker bei der Badmontage, Tageslicht, 16:9"
EOF
  for v in safe bold; do
    mkdir -p "$rd/$v/sections"
    cat > "$rd/$v/App.jsx" <<'EOF'
import content from "../shared/content.json";
export default function App() {
  return (
    <main className="bg-surface text-text">
      <section id="hero" style={{ background: "#112233" }}>
        <h1>{content.sections[0].heading}</h1>
        <div data-image-slot="hero-bild" />
        <a href="#kontakt">Termin buchen</a>
      </section>
    </main>
  );
}
EOF
    jq -n --arg v "$v" --arg rv "$RCV" '{variant:$v, recipe_version:$rv, entry:"App.jsx",
      dials:(if $v=="safe" then {variance:3,motion:2,density:4} else {variance:8,motion:7,density:3} end),
      sections:[{id:"hero",layout:"full-bleed",motion:"none"},
                {id:"leistungen",layout:"grid",motion:"none"},
                {id:"kontakt",layout:"stack",motion:"none"}],
      components_used:["shadcn/button"]}' > "$rd/$v/manifest.json"
    jq -n '{name:"redesign-variant",private:true,
            dependencies:{react:"^19",("react-dom"):"^19",motion:"^12",tailwindcss:"^4"}}' > "$rd/$v/package.json"
  done
}

run_init()   { (cd "$ROOT" && bash "$RG" "$1" ${2:-} >"$WORK/init.log" 2>&1); }
run_verify() { (cd "$ROOT" && bash "$RG" --verify "$1" >"$WORK/verify.log" 2>&1); }

# ════════════════════════════════════════════════════════════════════════════
echo "═══ A) INIT: Happy Path ═══"
R="$WORK/run-a"; mk_run "$R"
run_init "$R"; assert_eq "$?" "0" "INIT Exit 0"
[[ -s "$R/redesign/shared/tokens.json" && -s "$R/redesign/shared/tailwind-theme.css" ]] \
  && ok "shared/ eingefroren (tokens + theme)" || bad "shared/-Kopien fehlen"
CTX="$R/redesign/redesign-context.json"
assert_eq "$(jq -r '.recipe_version' "$CTX")" "$RCV" "recipe_version im Kontext"
assert_eq "$(jq -r '.user_prompt' "$CTX")" "Fokus auf Terminbuchung" "user_prompt durchgereicht"
assert_eq "$(jq -r '.scores.total' "$CTX")" "61" "Gesamtscore im Kontext"
assert_eq "$(jq -r '.scores.cai.action' "$CTX")" "40" "Cai-Teilscore (action) im Kontext"
assert_eq "$(jq -r '.top_findings[0].title' "$CTX")" "CTA unter dem Fold" "Top-Befund im Kontext"
assert_eq "$(jq -r '.branding.palette_size' "$CTX")" "2" "Palette-Größe im Kontext"
assert_eq "$(jq -r '.phases.redesign.status' "$R/status.json")" "awaiting_generation" "status.json: phases.redesign"

echo "═══ B) INIT: Gates ═══"
R="$WORK/run-b1"; mkdir -p "$R"; jq -n '{status:"ok"}' > "$R/meta.json"
run_init "$R"; assert_eq "$?" "2" "Exit 2 ohne scores.json (Stufe 1 unvollständig)"
R="$WORK/run-b2"; mk_run "$R"; rm "$R/branding/tokens.json"
run_init "$R"; assert_eq "$?" "2" "Exit 2 ohne branding/tokens.json"
R="$WORK/run-b3"; mk_run "$R"; jq -n '{status:"aborted"}' > "$R/meta.json"
run_init "$R"; assert_eq "$?" "2" "Exit 2 bei Capture-Status ≠ ok"
R="$WORK/run-b4"; mk_run "$R"
run_init "$R"
run_init "$R"; assert_eq "$?" "2" "Exit 2 bei existierendem redesign/ ohne --force"
run_init "$R" "--force"; assert_eq "$?" "0" "--force erlaubt Re-INIT"
run_init "$WORK/gibt-es-nicht"; assert_eq "$?" "2" "Exit 2 bei fehlendem Run-Ordner"

echo "═══ C) INIT: degradiert (leere Palette) ═══"
R="$WORK/run-c"; mk_run "$R"
jq '.color.palette = []' "$R/branding/tokens.json" > "$R/t.json" && mv "$R/t.json" "$R/branding/tokens.json"
run_init "$R"; assert_eq "$?" "1" "Exit 1 bei leerer Token-Palette"
assert_eq "$(jq -r '.degraded' "$R/redesign/redesign-context.json")" "true" "degraded-Flag im Kontext"
assert_eq "$(jq '.notes|length > 0' "$R/redesign/redesign-context.json")" "true" "notes erklären die Degradierung"

echo "═══ D) VERIFY: alles grün ═══"
R="$WORK/run-d"; mk_run "$R"; run_init "$R"; mk_redesign_ok "$R"
run_verify "$R"; assert_eq "$?" "0" "Verify Exit 0 (alle Gates grün)"
V="$R/redesign/verify.json"
assert_eq "$(jq -r '.summary.fail' "$V")" "0" "verify.json: 0 rote Gates"
assert_eq "$(jq -r '.summary.warn' "$V")" "0" "verify.json: 0 Warnungen"
assert_eq "$(jq -r '.recipe_version' "$V")" "$RCV" "verify.json: Rezept-Version"
assert_eq "$(gate_status "$R" "G6")" "ok" "Token-Lint grün"
assert_eq "$(jq -r '.phases.redesign.status' "$R/status.json")" "ok" "status.json: redesign ok"

echo "═══ E) VERIFY: rote Gates (je Verstoß) ═══"
mk_bad() { R="$WORK/run-e$1"; mk_run "$R"; run_init "$R"; mk_redesign_ok "$R"; }

mk_bad 1  # Off-Token-Hexfarbe
sed -i 's/#112233/#ff00aa/' "$R/redesign/safe/App.jsx"
run_verify "$R"; assert_eq "$?" "2" "Exit 2 bei fremder Hex-Farbe"
assert_eq "$(gate_status "$R" "G6")" "fail" "G6 Token-Lint rot"

mk_bad 2  # Tailwind-Default-Palette
sed -i 's/bg-surface/bg-blue-500/' "$R/redesign/bold/App.jsx"
run_verify "$R"; assert_eq "$(gate_status "$R" "G6")" "fail" "G6 rot bei Tailwind-Default-Palette (bg-blue-500)"

mk_bad 3  # Google-Fonts-CDN
sed -i 's#</main>#<link href="https://fonts.googleapis.com/css2?family=X" rel="stylesheet" /></main>#' "$R/redesign/safe/App.jsx"
run_verify "$R"; assert_eq "$(gate_status "$R" "G7")" "fail" "G7 rot bei Google-Fonts-CDN"

mk_bad 4  # Lorem-Rest
sed -i 's/Bad, Heizung, Notdienst./Lorem ipsum dolor sit amet./' "$R/redesign/shared/content.json"
run_verify "$R"; assert_eq "$(gate_status "$R" "G8")" "fail" "G8 rot bei Lorem ipsum"

mk_bad 5  # Bild-Slot fehlt in images.md
sed -i 's/hero-bild/hero-neu/' "$R/redesign/shared/content.json"
run_verify "$R"; assert_eq "$(gate_status "$R" "G9")" "fail" "G9 rot bei ungedecktem Bild-Slot"

mk_bad 6  # primärer CTA zu lang
jq '.conversion.primary_cta.label = "Jetzt sofort Termin online buchen"' \
  "$R/redesign/shared/content.json" > "$R/c.json" && mv "$R/c.json" "$R/redesign/shared/content.json"
run_verify "$R"; assert_eq "$(gate_status "$R" "G10")" "fail" "G10 rot bei CTA > 3 Wörtern"

mk_bad 7  # doppelter CTA-Intent
jq '.sections[2].cta.label = "Jetzt anfragen"' \
  "$R/redesign/shared/content.json" > "$R/c.json" && mv "$R/c.json" "$R/redesign/shared/content.json"
run_verify "$R"; assert_eq "$(gate_status "$R" "G11")" "fail" "G11 rot bei zwei Labels für einen Intent"

mk_bad 8  # Zigzag: 3× split in Folge
jq '.sections = [{id:"hero",layout:"split"},{id:"leistungen",layout:"split"},{id:"kontakt",layout:"split"}]' \
  "$R/redesign/bold/manifest.json" > "$R/m.json" && mv "$R/m.json" "$R/redesign/bold/manifest.json"
run_verify "$R"; assert_eq "$(gate_status "$R" "G12-bold")" "fail" "G12 rot bei 3× split in Folge"

mk_bad 9  # Brief-Pflichtabschnitt fehlt
sed -i 's/## Anti-Slop-Constraints/## Sonstiges/' "$R/redesign/brief.md"
run_verify "$R"; assert_eq "$(gate_status "$R" "G2")" "fail" "G2 rot bei fehlendem Brief-Abschnitt"

mk_bad 10 # Rezept-Versions-Konflikt
jq '.recipe_version = "1999.00-0"' "$R/redesign/safe/manifest.json" > "$R/m.json" && mv "$R/m.json" "$R/redesign/safe/manifest.json"
run_verify "$R"; assert_eq "$(gate_status "$R" "G5-safe")" "fail" "G5 rot bei recipe_version-Konflikt"

mk_bad 11 # compare.json deckt nicht alle Sektionen
jq '.sections |= .[0:1]' "$R/redesign/compare.json" > "$R/c.json" && mv "$R/c.json" "$R/redesign/compare.json"
run_verify "$R"; assert_eq "$(gate_status "$R" "G4")" "fail" "G4 rot bei unvollständigem compare.json"

mk_bad 12 # Code referenziert undeklarierten Slot
sed -i 's/data-image-slot="hero-bild"/data-image-slot="erfunden"/' "$R/redesign/bold/App.jsx"
run_verify "$R"; assert_eq "$(gate_status "$R" "G9")" "fail" "G9 rot bei undeklariertem Slot im Code"
assert_eq "$(jq -r '.phases.redesign.status' "$R/status.json")" "failed" "status.json: redesign failed"

echo "═══ F) VERIFY: Warnungen (Exit 1, kein Abbruch) ═══"
R="$WORK/run-f"; mk_run "$R"; run_init "$R"; mk_redesign_ok "$R"
jq '.dependencies.jquery = "^3"' "$R/redesign/safe/package.json" > "$R/p.json" && mv "$R/p.json" "$R/redesign/safe/package.json"
run_verify "$R"; assert_eq "$?" "1" "Exit 1 bei Whitelist-fremder Dependency"
assert_eq "$(gate_status "$R" "G13-safe")" "warn" "G13 warnt (jquery)"
assert_eq "$(jq -r '.phases.redesign.status' "$R/status.json")" "degraded" "status.json: redesign degraded"

R="$WORK/run-f2"; mk_run "$R"; run_init "$R"; mk_redesign_ok "$R"
jq '.language = "en"' "$R/redesign/shared/content.json" > "$R/c.json" && mv "$R/c.json" "$R/redesign/shared/content.json"
run_verify "$R"; assert_eq "$?" "1" "Exit 1 bei language ≠ de"
assert_eq "$(gate_status "$R" "G3b")" "warn" "G3b warnt (Sprache)"

echo "═══ G) VERIFY: Struktur-Gate ═══"
R="$WORK/run-g"; mk_run "$R"; run_init "$R"
run_verify "$R"; assert_eq "$?" "2" "Exit 2 ohne generierte Inhalte"
assert_eq "$(gate_status "$R" "G1")" "fail" "G1 rot (Struktur unvollständig)"
run_verify "$WORK/run-b1" >/dev/null 2>&1; assert_eq "$?" "2" "Exit 2 bei --verify ohne redesign/"

# ════════════════════════════════════════════════════════════════════════════
echo
echo "════════════════════════════════════════"
echo "  Ergebnis: $PASS bestanden · $FAIL fehlgeschlagen"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}"
  exit 1
fi
echo "  ✓ Alle Tests grün."
exit 0
