#!/usr/bin/env bash
#
# score_report_test.sh — Black-Box-QA-Suite für scripts/score-report.sh (PROJ-4)
#
# Vollständig hermetisch: kein Browser, kein Lighthouse, kein Netz — die Eingänge
# (meta.json / judge.json / lh-summary.json / branding) sind JSON-Fixtures. Prüft
# Acceptance Criteria + Edge Cases von PROJ-4 (Scoring, Renormierung, Befund-
# Validierung, Benchmark, Input-Gates, Reproduzierbarkeit).
#
# Nutzung:  scripts/tests/score_report_test.sh
# Exit 0 = alle Tests bestanden · 1 = mindestens ein Fehlschlag.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SR="$ROOT/scripts/score-report.sh"
RV="$(cat "$ROOT/rubrics/VERSION" | head -1)"
WORK="$(mktemp -d)"
# runs.jsonl in eine Sandbox umlenken? Das Skript nutzt $ROOT/data/runs.jsonl fest.
# Wir sichern die echte Datei und stellen sie am Ende wieder her.
RUNS="$ROOT/data/runs.jsonl"
RUNS_BAK="$WORK/runs.bak"; [[ -f "$RUNS" ]] && cp "$RUNS" "$RUNS_BAK"

command -v jq >/dev/null 2>&1 || { echo "✗ jq nicht installiert"; exit 1; }

PASS=0; FAIL=0
declare -a FAILURES=()
ok()  { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $*" >&2; FAIL=$((FAIL+1)); FAILURES+=("$*"); }
assert_eq() { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }
sj() { jq -r "$2" "$1/scores.json" 2>/dev/null; }

cleanup() { [[ -f "$RUNS_BAK" ]] && cp "$RUNS_BAK" "$RUNS" || : > "$RUNS"; rm -rf "$WORK"; }
trap cleanup EXIT

# ── Fixture-Helfer ─────────────────────────────────────────────────────────
mk_capture() { # $1=dir $2=status $3=suspicion
  mkdir -p "$1"
  jq -n --arg s "$2" --arg su "$3" \
    '{url:"https://ex.test",final_url:"https://ex.test/",status:$s,
      content_suspicion:($su|if .=="" then null else . end)}' > "$1/meta.json"
}
mk_judge() { # $1=dir  (Voll-Judge mit Belegen)
  jq -n --arg rv "$RV" '{
    rubric_version:$rv, language_confident:true, app_mode:false, cta_present:true,
    visual:{score:72,findings:[{title:"Schwache Hierarchie",severity:"mittel",
      evidence:"H1 kaum größer als Body",location:"Hero, 1440px"}]},
    ki_score:3,
    slop:{findings:[{title:"Generischer Hero",severity:"niedrig",
      evidence:"Standard-Gradient ohne Marke",location:"Hero, 375px"}]},
    conversion:{clarity:80,credibility:70,logic:65,action:55,emotion:60,
      findings:[{title:"CTA schwach",severity:"hoch",evidence:"CTA unter dem Fold",location:"Hero, 375px"}]}
  }' > "$1/judge.json"
}
mk_lh_ok() { mkdir -p "$1/lighthouse"; jq -n '{status:"ok",
  scores:{performance:88,accessibility:90,best_practices:96,seo:100},
  opportunities:[{id:"unused-css",title:"Ungenutztes CSS",savings_ms:1400}]}' > "$1/lighthouse/lh-summary.json"; }
mk_lh_failed() { mkdir -p "$1/lighthouse"; jq -n '{status:"failed",error:"Timeout",scores:null,opportunities:[]}' > "$1/lighthouse/lh-summary.json"; }
mk_branding() { mkdir -p "$1/branding"
  jq -n '{counts:{contrast_violations:2}}' > "$1/branding/branding-meta.json"
  jq -n '{contrast_violations:[{fg:"#999",bg:"#fff",ratio:2.8,required:4.5,font_px:14,large:false}]}' > "$1/branding/raw-extract.json"; }

# ── A: Happy Path (alle 5 Dimensionen) ─────────────────────────────────────
echo "▶ A: Happy Path (Judge + Lighthouse + Branding)"
: > "$RUNS"
R="$WORK/a"; mk_capture "$R" ok ""; mk_judge "$R"; mk_lh_ok "$R"; mk_branding "$R"
bash "$SR" "$R" --industry saas >"$WORK/a.out" 2>&1
assert_eq "$?" "0" "Exit 0 (alle Dimensionen messbar)"
[[ -s "$R/scores.json" ]] && ok "scores.json erzeugt" || bad "scores.json fehlt"
[[ -s "$R/report.md" ]] && ok "report.md erzeugt" || bad "report.md fehlt"
assert_eq "$(sj "$R" '.dimensions.visuell.score')" "72" "visuell = judge.visual.score"
assert_eq "$(sj "$R" '.dimensions.slop.score')" "70" "slop = (10-ki)*10"
assert_eq "$(sj "$R" '.dimensions.performance.score')" "88" "performance = lighthouse"
assert_eq "$(sj "$R" '.dimensions.accessibility.score')" "82" "a11y = 90 - min(2*4,40)"
assert_eq "$(sj "$R" '.dimensions.conversion.score')" "66" "conversion = Mittel(80,70,65,55,60)"
# Gesamtscore gewichtet 25/15/15/15/30, alle messbar
assert_eq "$(sj "$R" '.total')" "74" "Gesamtscore gewichtet == 74"
# Cai-Teilscores + Gewichte + Rubrik-Version im scores.json
assert_eq "$(sj "$R" '.dimensions.conversion.subscores.action')" "55" "Cai-Teilscore action präsent"
assert_eq "$(sj "$R" '.rubric_version')" "$RV" "rubric_version == VERSION"
assert_eq "$(sj "$R" '(.weights | to_entries | length)')" "5" "5 Gewichte in scores.json"
# Jede Dimension nennt Quelle
assert_eq "$(sj "$R" '[.dimensions[]|select(.source|length>0)]|length')" "5" "jede Dimension nennt Quelle"
# Befunde: min 5, max 15, jeder mit Beleg+Fundort+Quelle
n="$(sj "$R" '.findings|length')"
[[ "$n" -ge 5 && "$n" -le 15 ]] && ok "Befund-Anzahl 5–15 ($n)" || bad "Befund-Anzahl außerhalb 5–15: $n"
assert_eq "$(sj "$R" '[.findings[]|select((.evidence|length>0) and (.location|length>0) and (.source|length>0))]|length')" "$n" "jeder Befund hat Beleg+Fundort+Quelle"
# Report enthält Score-Panel + Meta
grep -q "Score-Panel" "$R/report.md" && ok "report.md: Score-Panel" || bad "Score-Panel fehlt"
grep -q "Lauf-ID" "$R/report.md" && ok "report.md: Meta (Lauf-ID)" || bad "Lauf-ID fehlt"

# ── B: Befund-Validierung — unbelegte Befunde werden verworfen ─────────────
echo; echo "▶ B: Unbelegte Befunde unzulässig (Beleg Pflicht)"
R="$WORK/b"; mk_capture "$R" ok ""; mk_lh_ok "$R"; mk_branding "$R"
jq -n --arg rv "$RV" '{rubric_version:$rv,visual:{score:60,
  findings:[{title:"Gültig",severity:"mittel",evidence:"belegt",location:"Hero"},
            {title:"Ohne Beleg",severity:"hoch",evidence:"",location:"Hero"},
            {title:"Ohne Fundort",severity:"hoch",evidence:"da",location:""}]},
  ki_score:5,conversion:{clarity:60,credibility:60,logic:60,action:60,emotion:60}}' > "$R/judge.json"
bash "$SR" "$R" --industry saas >"$WORK/b.out" 2>&1
assert_eq "$(sj "$R" '[.findings[]|select(.evidence=="" or .location=="")]|length')" "0" "keine unbelegten Befunde im Output"
[[ "$(sj "$R" '.findings_meta.dropped')" -ge 2 ]] && ok "≥2 unbelegte Befunde verworfen" || bad "dropped-Zähler falsch: $(sj "$R" '.findings_meta.dropped')"

# ── C: Renormierung bei ausgefallenem Lighthouse ───────────────────────────
echo; echo "▶ C: Lighthouse failed → Perf+A11y nicht messbar, renormiert, Exit 1"
R="$WORK/c"; mk_capture "$R" ok ""; mk_judge "$R"; mk_lh_failed "$R"
bash "$SR" "$R" --industry saas >"$WORK/c.out" 2>&1
assert_eq "$?" "1" "Exit 1 (degradiert)"
assert_eq "$(sj "$R" '.dimensions.performance.measurable')" "false" "performance nicht messbar"
assert_eq "$(sj "$R" '.dimensions.accessibility.measurable')" "false" "accessibility nicht messbar"
# effektive Gewichte nur über messbare Dims (25+15+30=70): visuell 36, slop 21, conversion 43
assert_eq "$(sj "$R" '.weights_effective.visuell')" "36" "renormiertes Gewicht visuell (25/70)"
assert_eq "$(sj "$R" '.weights_effective.conversion')" "43" "renormiertes Gewicht conversion (30/70)"
# Total = (72*25+70*15+66*30)/70 = 68.57 → 69
assert_eq "$(sj "$R" '.total')" "69" "Gesamtscore renormiert == 69"
grep -qi "nicht messbar" "$R/report.md" && ok "report.md markiert 'nicht messbar'" || bad "'nicht messbar' fehlt im Report"

# ── D: Reproduzierbarkeit (±5) — identischer Input, zwei Läufe ──────────────
echo; echo "▶ D: Reproduzierbarkeit — identischer Input ⇒ identischer Score"
R1="$WORK/d1"; R2="$WORK/d2"
mk_capture "$R1" ok ""; mk_judge "$R1"; mk_lh_ok "$R1"; mk_branding "$R1"
mk_capture "$R2" ok ""; mk_judge "$R2"; mk_lh_ok "$R2"; mk_branding "$R2"
bash "$SR" "$R1" --industry saas >/dev/null 2>&1
bash "$SR" "$R2" --industry saas >/dev/null 2>&1
t1="$(sj "$R1" '.total')"; t2="$(sj "$R2" '.total')"
d=$(( t1 - t2 )); d=${d#-}
[[ "$d" -le 5 ]] && ok "Score-Abweichung ≤ 5 (|$t1-$t2|=$d)" || bad "Score-Abweichung > 5: $t1 vs $t2"

# ── E: Sehr gute Seite (≥85) → Befund-Minimum 3 ────────────────────────────
echo; echo "▶ E: Sehr gute Seite (≥85) → Minimum sinkt auf 3"
R="$WORK/e"; mk_capture "$R" ok ""; mk_lh_ok "$R"
jq -n --arg rv "$RV" '{rubric_version:$rv,visual:{score:95,
  findings:[{title:"Detail",severity:"niedrig",evidence:"Feinschliff Whitespace",location:"global"}]},
  ki_score:0,conversion:{clarity:95,credibility:95,logic:95,action:95,emotion:95,
  findings:[{title:"Mini",severity:"niedrig",evidence:"kleiner CTA-Kontrast",location:"Hero"}]}}' > "$R/judge.json"
bash "$SR" "$R" --industry saas >"$WORK/e.out" 2>&1
[[ "$(sj "$R" '.total')" -ge 85 ]] && ok "Gesamtscore ≥ 85 ($(sj "$R" '.total'))" || bad "Score < 85"
assert_eq "$(sj "$R" '.findings_meta.minimum')" "3" "Befund-Minimum == 3 bei ≥85"

# ── F: Benchmark erst ab n ≥ 10 gleicher Industrie-Tag ─────────────────────
echo; echo "▶ F: Benchmark-Gate (n≥10, gleiche Rubrik-Version)"
: > "$RUNS"
# 5 Zeilen unter FREMDER Rubrik-Version — dürfen NICHT mitzählen (BUG-2).
for i in $(seq 1 5); do
  jq -c -n --arg t "$i" '{date:"2026-07-01",url_hash:("f"+$t),industry_tag:"finanz",
    rubric_version:"1999.00-0",run_id:("f"+$t),total:10,dimensions:{}}' >> "$RUNS"
done
# 9 Zeilen unter AKTUELLER Rubrik-Version.
for i in $(seq 1 9); do
  jq -c -n --arg t "$i" --arg rv "$RV" '{date:"2026-07-01",url_hash:("h"+$t),industry_tag:"finanz",
    rubric_version:$rv,run_id:("r"+$t),total:(60+($t|tonumber)),dimensions:{}}' >> "$RUNS"
done
R="$WORK/f9"; mk_capture "$R" ok ""; mk_judge "$R"; mk_lh_ok "$R"; mk_branding "$R"
bash "$SR" "$R" --industry finanz >/dev/null 2>&1
assert_eq "$(sj "$R" '.benchmark')" "null" "Benchmark ausgeblendet bei n=9 (Fremd-Rubrik ignoriert)"
# jetzt liegt der 10. Lauf gleicher Rubrik vor → nächster Lauf zeigt Benchmark
R="$WORK/f10"; mk_capture "$R" ok ""; mk_judge "$R"; mk_lh_ok "$R"; mk_branding "$R"
bash "$SR" "$R" --industry finanz >/dev/null 2>&1
[[ "$(sj "$R" '.benchmark')" != "null" ]] && ok "Benchmark erscheint ab n≥10" || bad "Benchmark fehlt trotz n≥10"
assert_eq "$(sj "$R" '.benchmark.rubric_version')" "$RV" "Benchmark nur über gleiche Rubrik-Version"
assert_eq "$(sj "$R" '.benchmark.n')" "10" "Benchmark n=10 (Fremd-Rubrik nicht mitgezählt)"
grep -qi "Benchmark" "$R/report.md" && ok "report.md zeigt Benchmark-Zeile" || bad "Benchmark-Zeile fehlt im Report"
# runs.jsonl append-only, nur URL-Hash (keine Klardaten)
tail -1 "$RUNS" | grep -q '"url_hash"' && ok "runs.jsonl: url_hash (keine Klardaten)" || bad "runs.jsonl url_hash fehlt"
tail -1 "$RUNS" | grep -q 'ex.test' && bad "runs.jsonl enthält Klar-URL!" || ok "runs.jsonl ohne Klar-URL"

# ── G: Edge — App-Modus + kein CTA vermerkt ────────────────────────────────
echo; echo "▶ G: App-Modus & fehlender CTA werden vermerkt"
R="$WORK/g"; mk_capture "$R" ok "spa_empty"; mk_lh_ok "$R"
jq -n --arg rv "$RV" '{rubric_version:$rv,app_mode:true,cta_present:false,language_confident:false,
  visual:{score:70,findings:[{title:"x",severity:"mittel",evidence:"y",location:"z"}]},
  ki_score:4,conversion:{clarity:70,credibility:70,logic:70,action:70,emotion:70}}' > "$R/judge.json"
bash "$SR" "$R" --industry saas >"$WORK/g.out" 2>&1
grep -qi "App-Modus" "$R/report.md" && ok "report.md: App-Modus-Hinweis" || bad "App-Modus-Hinweis fehlt"
grep -qi "Kein primärer CTA" "$R/report.md" && ok "report.md: CTA-Hinweis" || bad "CTA-Hinweis fehlt"
grep -qi "SPA" "$R/report.md" && ok "report.md: SPA-Verdacht-Hinweis" || bad "SPA-Hinweis fehlt"

# ── H: Input-Gates (Exit 2) ────────────────────────────────────────────────
echo; echo "▶ H: Input-Gates (Exit 2)"
R="$WORK/h"; mk_capture "$R" ok ""   # kein judge.json
bash "$SR" "$R" >"$WORK/h1.out" 2>&1; assert_eq "$?" "2" "kein judge.json → Exit 2"
grep -qi "Judge-Ausgabe fehlt" "$WORK/h1.out" && ok "Meldung 'Judge-Ausgabe fehlt'" || bad "Judge-fehlt-Meldung fehlt"
R="$WORK/h2"; mk_capture "$R" aborted ""; mk_judge "$R"
bash "$SR" "$R" >"$WORK/h2.out" 2>&1; assert_eq "$?" "2" "Capture aborted → Exit 2"
R="$WORK/h3"; mk_capture "$R" ok ""
jq -n '{rubric_version:"1999.01-0",visual:{score:50},ki_score:5,conversion:{clarity:50,credibility:50,logic:50,action:50,emotion:50}}' > "$R/judge.json"
bash "$SR" "$R" >"$WORK/h3.out" 2>&1; assert_eq "$?" "2" "Rubrik-Version-Konflikt → Exit 2"
grep -qi "Rubrik-Version-Konflikt" "$WORK/h3.out" && ok "Meldung 'Rubrik-Version-Konflikt'" || bad "Rubrik-Konflikt-Meldung fehlt"
bash "$SR" >"$WORK/h4.out" 2>&1; assert_eq "$?" "2" "kein Run-Ordner → Exit 2"

# ── I: Bugfix-Regression (QA 2026-07-03) ───────────────────────────────────
echo; echo "▶ I: Bugfix-Regression"
: > "$RUNS"
# BUG-1: nicht-numerischer Score ⇒ nicht messbar (NICHT still 100).
R="$WORK/i1"; mk_capture "$R" ok ""
jq -n --arg rv "$RV" '{rubric_version:$rv,visual:{score:"72"},ki_score:3,
  conversion:{clarity:80,credibility:70,logic:65,action:55,emotion:60}}' > "$R/judge.json"
bash "$SR" "$R" --industry x >/dev/null 2>&1
assert_eq "$(sj "$R" '.dimensions.visuell.score')" "null" "BUG-1: String-Score ⇒ null (nicht 100)"
assert_eq "$(sj "$R" '.dimensions.visuell.measurable')" "false" "BUG-1: String-Score ⇒ nicht messbar"
# BUG-3: URL-Sonderzeichen werden im Report-Titel neutralisiert.
R="$WORK/i3"; mkdir -p "$R"
jq -n '{url:"x",final_url:"https://ex.test/](javascript:alert(1)) <script>x</script>",status:"ok",content_suspicion:null}' > "$R/meta.json"
mk_judge "$R"; mk_lh_ok "$R"
bash "$SR" "$R" --industry x >/dev/null 2>&1
head -1 "$R/report.md" | grep -q '[<>()]' && bad "BUG-3: Sonderzeichen im Titel geblieben" || ok "BUG-3: URL im Titel neutralisiert"
# BUG-4: renormierte Gewichte summieren exakt 100 (nur visuell+slop+conversion messbar).
R="$WORK/i4"; mk_capture "$R" ok ""; mk_judge "$R"   # kein Lighthouse ⇒ perf/a11y weg
bash "$SR" "$R" --industry x >/dev/null 2>&1
assert_eq "$(sj "$R" '(.weights_effective | add)')" "100" "BUG-4: eff. Gewichte summieren exakt 100"
# BUG-5: eine kaputte runs.jsonl-Zeile kippt den Benchmark nicht.
: > "$RUNS"; printf 'DAS_IST_KEIN_JSON\n' >> "$RUNS"
for i in $(seq 1 10); do
  jq -c -n --arg t "$i" --arg rv "$RV" '{industry_tag:"kbroken",rubric_version:$rv,total:(60+($t|tonumber))}' >> "$RUNS"
done
R="$WORK/i5"; mk_capture "$R" ok ""; mk_judge "$R"; mk_lh_ok "$R"; mk_branding "$R"
bash "$SR" "$R" --industry kbroken >/dev/null 2>&1
assert_eq "$(sj "$R" '.benchmark.n')" "10" "BUG-5: kaputte Zeile ignoriert, 10 valide gezählt"

# ── Zusammenfassung ────────────────────────────────────────────────────────
echo; echo "──────────────────────────────────────────"
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}" >&2
  exit 1
fi
echo "✓ Alle Tests bestanden"
