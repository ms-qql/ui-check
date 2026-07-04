#!/usr/bin/env bash
#
# after_score_test.sh — Black-Box-QA-Suite für scripts/after-score.sh (PROJ-9)
#
# Hermetisch: kein Browser, kein Netz, kein LLM. Die Nachher-Judge-Ausgaben sind
# JSON-Fixtures. Geprüft werden Artefakte, Delta-Gate, Retry-Verhalten,
# Lighthouse-Renormierung, Report-/Mockup-Anreicherung und status.json.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
AS="$ROOT/scripts/after-score.sh"
RV="$(head -1 "$ROOT/rubrics/VERSION")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v jq >/dev/null 2>&1 || { echo "✗ jq nicht installiert"; exit 1; }

PASS=0; FAIL=0; declare -a FAILURES=()
ok()  { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $*" >&2; FAIL=$((FAIL+1)); FAILURES+=("$*"); }
assert_eq() { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }
sj() { jq -r "$2" "$1" 2>/dev/null; }

mk_run() { # $1=dir
  local r="$1"
  mkdir -p "$r"
  jq -n --arg rv "$RV" '{
    run_id:"fixture",
    rubric_version:$rv,
    weights:{visuell:25,slop:15,performance:15,accessibility:15,conversion:30},
    dimensions:{
      visuell:{score:40,measurable:true},
      slop:{score:50,measurable:true},
      performance:{score:90,measurable:true},
      accessibility:{score:60,measurable:true},
      conversion:{score:50,measurable:true}
    },
    total:56
  }' > "$r/scores.json"
  printf '# UI-Check Report\n\nAltbestand.\n' > "$r/report.md"
  printf '<!doctype html><html><body><main>Mockup</main></body></html>\n' > "$r/mockup.html"
  jq -n '{run_id:"fixture",status:"done",phases:{}}' > "$r/status.json"
}

mk_judge() { # $1=file $2=visual $3=ki_score $4=a11y $5=conv
  jq -n --arg rv "$RV" \
    --argjson visual "$2" --argjson ki "$3" --argjson a11y "$4" --argjson conv "$5" '{
    rubric_version:$rv,
    visual:{score:$visual,findings:[{title:"Hero klarer",severity:"mittel",evidence:"Hero hat jetzt klare Hierarchie",location:"Hero"}]},
    ki_score:$ki,
    slop:{findings:[{title:"Weniger generisch",severity:"niedrig",evidence:"Markentokens sichtbar",location:"Global"}]},
    accessibility:{score:$a11y},
    conversion:{clarity:$conv,credibility:$conv,logic:$conv,action:$conv,emotion:$conv,
      findings:[{title:"CTA besser",severity:"hoch",evidence:"CTA liegt im ersten Viewport",location:"Hero"}]}
  }' > "$1"
}

echo "▶ A: Happy Path — Safe besteht, Bold scheitert"
R="$WORK/a"; mk_run "$R"
mk_judge "$R/after-judge-safe.json" 82 1 82 84
mk_judge "$R/after-judge-bold.json" 55 5 60 55
bash "$AS" "$R" > "$WORK/a.out" 2>&1
assert_eq "$?" "0" "Exit 0 bei mindestens einer auslieferbaren Variante"
[[ -s "$R/scores-safe.json" ]] && ok "scores-safe.json erzeugt" || bad "scores-safe.json fehlt"
[[ -s "$R/scores-bold.json" ]] && ok "scores-bold.json erzeugt" || bad "scores-bold.json fehlt"
[[ -s "$R/after-scoring.json" ]] && ok "after-scoring.json erzeugt" || bad "after-scoring.json fehlt"
assert_eq "$(sj "$R/scores-safe.json" '.dimensions.performance.measurable')" "false" "Performance nicht vergleichbar"
assert_eq "$(sj "$R/scores-safe.json" '.gate.status')" "passed" "Safe Gate passed"
assert_eq "$(sj "$R/scores-bold.json" '.gate.status')" "failed" "Bold Gate failed"
assert_eq "$(sj "$R/after-scoring.json" '.winner')" "safe" "Winner safe"
grep -q "Nachher-Scoring" "$R/report.md" && ok "report.md erweitert" || bad "report.md ohne Nachher-Abschnitt"
grep -q "UI-CHECK-AFTER-SCORING-BADGE" "$R/mockup.html" && ok "mockup.html Badge eingefuegt" || bad "Mockup-Badge fehlt"
assert_eq "$(jq -r '.phases.after_scoring.status' "$R/status.json")" "ok" "status.json after_scoring ok"

echo; echo "▶ B: Retry — initial scheitert, Retry besteht"
R="$WORK/b"; mk_run "$R"
mk_judge "$R/after-judge-safe.json" 50 5 50 50
mk_judge "$R/after-judge-bold.json" 50 5 50 50
RETRY_CMD="$WORK/retry-cmd.sh"
cat > "$RETRY_CMD" <<EOF
#!/usr/bin/env bash
variant="\$1"; run_dir="\$2"; brief="\$3"; out="\$4"
test "\$variant" = safe || exit 0
test -s "\$brief" || exit 3
jq -n --arg rv "$RV" '{
  rubric_version:\$rv,
  visual:{score:88,findings:[{title:"Retry verbessert Hero",severity:"mittel",evidence:"Brief umgesetzt",location:"Hero"}]},
  ki_score:1,
  slop:{findings:[]},
  accessibility:{score:86},
  conversion:{clarity:88,credibility:88,logic:88,action:88,emotion:88,findings:[]}
}' > "\$out"
EOF
chmod +x "$RETRY_CMD"
bash "$AS" "$R" --retry-cmd "$RETRY_CMD" > "$WORK/b.out" 2>&1
assert_eq "$?" "0" "Exit 0 nach erfolgreichem Safe-Retry"
assert_eq "$(sj "$R/scores-safe.json" '.attempt')" "retry" "Safe nutzt Retry-Score"
assert_eq "$(sj "$R/scores-safe.json" '.retry.used')" "true" "Retry als genutzt markiert"
assert_eq "$(sj "$R/scores-safe.json" '.retry.command')" "$RETRY_CMD" "Retry-Kommando dokumentiert"
[[ -s "$R/after-score/retry-safe.md" ]] && ok "Retry-Brief für Safe erzeugt" || bad "Retry-Brief Safe fehlt"

echo; echo "▶ C: Beide Varianten scheitern — Audit-only"
R="$WORK/c"; mk_run "$R"
mk_judge "$R/after-judge-safe.json" 45 6 50 45
mk_judge "$R/after-judge-bold.json" 48 6 50 48
bash "$AS" "$R" > "$WORK/c.out" 2>&1
assert_eq "$?" "1" "Exit 1 wenn beide Varianten scheitern"
assert_eq "$(sj "$R/after-scoring.json" '.status')" "failed" "Summary failed"
assert_eq "$(jq -r '.phases.after_scoring.status' "$R/status.json")" "failed" "status.json failed"
grep -q "Audit-only" "$R/report.md" && ok "Report nennt Audit-only" || bad "Audit-only-Hinweis fehlt"

echo; echo "▶ D: Input-Gates"
R="$WORK/d"; mk_run "$R"; rm "$R/mockup.html"
bash "$AS" "$R" > "$WORK/d.out" 2>&1
assert_eq "$?" "2" "fehlendes mockup.html → Exit 2"
grep -q "mockup.html fehlt" "$WORK/d.out" && ok "Meldung nennt mockup.html" || bad "mockup-Fehlermeldung fehlt"

R="$WORK/e"; mk_run "$R"
mk_judge "$R/after-judge-safe.json" 82 1 82 84
mk_judge "$R/after-judge-bold.json" 82 1 82 84
jq '.rubric_version="1999.00-0"' "$R/after-judge-bold.json" > "$R/bad.json" && mv "$R/bad.json" "$R/after-judge-bold.json"
bash "$AS" "$R" > "$WORK/e.out" 2>&1
assert_eq "$?" "2" "Rubrik-Konflikt → Exit 2"
grep -q "Rubrik-Version-Konflikt" "$WORK/e.out" && ok "Meldung nennt Rubrik-Konflikt" || bad "Rubrik-Konflikt-Meldung fehlt"

R="$WORK/f"; mk_run "$R"
mk_judge "$R/after-judge-safe.json" 82 1 82 84
mk_judge "$R/after-judge-bold.json" 82 1 82 84
jq 'del(.accessibility)' "$R/after-judge-safe.json" > "$R/no-a11y.json" && mv "$R/no-a11y.json" "$R/after-judge-safe.json"
bash "$AS" "$R" > "$WORK/f.out" 2>&1
assert_eq "$?" "2" "fehlende Nachher-A11y → Exit 2"
grep -q "accessibility.score" "$WORK/f.out" && ok "Meldung nennt accessibility.score" || bad "A11y-Fehlermeldung fehlt"

echo; echo "──────────────────────────────────────────"
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}" >&2
  exit 1
fi
echo "✓ Alle Tests bestanden"
