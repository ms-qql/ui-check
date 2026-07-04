#!/usr/bin/env bash
#
# ui_check_test.sh — Black-Box-QA-Suite für scripts/ui-check.sh (PROJ-5)
#
# Vollständig hermetisch: kein Browser, kein Lighthouse, kein Netz. Die vier
# Schritt-CLIs werden durch Stubs ersetzt (UI_CHECK_BIN), die Fixtures in den
# Run-Ordner schreiben und wählbare Exit-Codes liefern. Getestet wird die
# ORCHESTRIERUNG: Preflight, Run-Ordner/NNN, Parallel-Aufruf, Fehlerpolitik
# (Capture=Abbruch, Rest=degradieren), status.json, ui-check.json, Finalize +
# Terminal-Summary, Exit-Codes, Headless-Verhalten.
#
# Nutzung:  scripts/tests/ui_check_test.sh
# Exit 0 = alle Tests bestanden · 1 = mindestens ein Fehlschlag.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
UC="$ROOT/scripts/ui-check.sh"
REAL_SCORE="$ROOT/scripts/score-report.sh"
RV="$(cat "$ROOT/rubrics/VERSION" | head -1)"

command -v jq >/dev/null 2>&1 || { echo "✗ jq nicht installiert"; exit 1; }

WORK="$(mktemp -d)"
RUNS="$ROOT/data/runs.jsonl"
RUNS_BAK="$WORK/runs.bak"; [[ -f "$RUNS" ]] && cp "$RUNS" "$RUNS_BAK"
cleanup() { [[ -f "$RUNS_BAK" ]] && cp "$RUNS_BAK" "$RUNS" || : > "$RUNS"; rm -rf "$WORK"; }
trap cleanup EXIT

PASS=0; FAIL=0; declare -a FAILURES=()
ok()  { echo "  ✓ $*"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $*" >&2; FAIL=$((FAIL+1)); FAILURES+=("$*"); }
assert_eq() { [[ "$1" == "$2" ]] && ok "$3 ($1)" || bad "$3 — erwartet '$2', war '$1'"; }

# ── Stub-Bausteine ──────────────────────────────────────────────────────────
# Stubs parsen `<url> --out <dir> …`, schreiben Fixtures, liefern $STUB_*_RC.
mk_stubs() { # $1 = Stub-Verzeichnis
  local d="$1"; mkdir -p "$d"

  cat > "$d/capture.sh" <<'EOF'
#!/usr/bin/env bash
out=""; url="$1"; shift
while [[ $# -gt 0 ]]; do case "$1" in --out) out="$2"; shift 2;; *) shift;; esac; done
mkdir -p "$out/capture"
if [[ "${STUB_CAPTURE_RC:-0}" -ne 0 ]]; then
  jq -n --arg u "$url" '{url:$u,final_url:$u,status:"aborted",error:"Stub-Capture-Abbruch"}' > "$out/meta.json"
  echo "STUB capture: Abbruch" >&2; exit "${STUB_CAPTURE_RC}"
fi
jq -n --arg u "$url" --arg s "${STUB_CAPTURE_SUSPICION:-}" \
  '{url:$u,final_url:($u+"/"),status:"ok",
    content_suspicion:($s|if .=="" then null else . end),
    notes:($s|if .=="" then [] else ["Sehr wenig sichtbarer Textinhalt (28 Zeichen) — SPA ohne SSR? content_suspicion=\(.)"] end)}' > "$out/meta.json"
echo "sleep-marker $$" ; sleep "${STUB_CAPTURE_SLEEP:-0}"
exit 0
EOF

  cat > "$d/lh-audit.sh" <<'EOF'
#!/usr/bin/env bash
out=""; while [[ $# -gt 0 ]]; do case "$1" in --out) out="$2"; shift 2;; *) shift;; esac; done
mkdir -p "$out/lighthouse"
sleep "${STUB_LH_SLEEP:-0}"
if [[ "${STUB_LH_RC:-0}" -ne 0 ]]; then
  jq -n '{status:"failed",error:"Stub-Lighthouse-Timeout",scores:null,opportunities:[]}' > "$out/lighthouse/lh-summary.json"
  exit "${STUB_LH_RC}"
fi
jq -n '{status:"ok",scores:{performance:88,accessibility:90,best_practices:96,seo:100},
  opportunities:[{id:"unused-css",title:"Ungenutztes CSS",savings_ms:1400}]}' > "$out/lighthouse/lh-summary.json"
exit 0
EOF

  cat > "$d/brand-extract.sh" <<'EOF'
#!/usr/bin/env bash
out=""; while [[ $# -gt 0 ]]; do case "$1" in --out) out="$2"; shift 2;; *) shift;; esac; done
mkdir -p "$out/branding"
if [[ "${STUB_BRAND_RC:-0}" -ne 0 ]]; then
  jq -n '{status:"partial",error:"Kein Logo gefunden"}' > "$out/branding/branding-meta.json"
  jq -n '{contrast_violations:[]}' > "$out/branding/raw-extract.json"
  exit "${STUB_BRAND_RC}"
fi
jq -n '{status:"ok",counts:{contrast_violations:2}}' > "$out/branding/branding-meta.json"
jq -n '{contrast_violations:[{fg:"#999",bg:"#fff",ratio:2.8,required:4.5,font_px:14,large:false}]}' > "$out/branding/raw-extract.json"
exit 0
EOF

  # score-report bleibt echt (deterministisch, jq-only) — Wrapper statt Symlink,
  # damit $0 im Original korrekt auf den echten Pfad zeigt (ROOT/rubrics/VERSION).
  cat > "$d/score-report.sh" <<EOF
#!/usr/bin/env bash
exec bash "$REAL_SCORE" "\$@"
EOF
  chmod +x "$d/score-report.sh"
  # PATH-Tools, die die echten Skripte im Preflight erwarten, werden über die
  # command-Prüfung abgedeckt; die Stubs brauchen nur jq/curl (vorhanden).
  chmod +x "$d/capture.sh" "$d/lh-audit.sh" "$d/brand-extract.sh"
}

mk_judge() { # $1=run-dir  — vollständige, belegte Judge-Ausgabe
  jq -n --arg rv "$RV" '{
    rubric_version:$rv, language_confident:true, app_mode:false, cta_present:true,
    visual:{score:72,findings:[{title:"Schwache Hierarchie",severity:"mittel",
      evidence:"H1 kaum größer als Body",location:"Hero, 1440px"}]},
    ki_score:3,
    slop:{findings:[{title:"Generischer Hero",severity:"niedrig",
      evidence:"Standard-Gradient",location:"Hero, 375px"}]},
    conversion:{clarity:80,credibility:70,logic:65,action:55,emotion:60,
      findings:[{title:"CTA schwach",severity:"hoch",evidence:"CTA unter dem Fold",location:"Hero, 375px"}]}
  }' > "$1/judge.json"
}

STUBS="$WORK/bin"; mk_stubs "$STUBS"
export UI_CHECK_BIN="$STUBS"
run() { ( cd "$WORK" && env "$@" bash "$UC" "${RUN_ARGS[@]}" ); }

# ════════════════════════════════════════════════════════════════════════════
echo "▶ A: Collect Happy Path — Run-Ordner, status.json, ui-check.json, Exit 0"
: > "$RUNS"
RUN_ARGS=(https://ex.test --industry saas --prompt "Fokus Terminbuchung" --out "$WORK/a")
run STUB_CAPTURE_RC=0 STUB_LH_RC=0 STUB_BRAND_RC=0 >"$WORK/a.out" 2>&1
assert_eq "$?" "0" "Collect Exit 0 (alles ok)"
[[ -s "$WORK/a/meta.json" ]] && ok "capture-Fixture da (meta.json)" || bad "meta.json fehlt"
[[ -s "$WORK/a/lighthouse/lh-summary.json" ]] && ok "lighthouse-Fixture da" || bad "lh-summary fehlt"
[[ -s "$WORK/a/branding/branding-meta.json" ]] && ok "branding-Fixture da" || bad "branding fehlt"
[[ -s "$WORK/a/status.json" ]] && ok "status.json geschrieben" || bad "status.json fehlt"
assert_eq "$(jq -r '.status' "$WORK/a/status.json")" "awaiting_judge" "status = awaiting_judge nach Collect"
assert_eq "$(jq -r '.phases.capture.status' "$WORK/a/status.json")" "ok" "Phase capture = ok"
assert_eq "$(jq -r '.phases.lighthouse.status' "$WORK/a/status.json")" "ok" "Phase lighthouse = ok"
assert_eq "$(jq -r '.phases.branding.status' "$WORK/a/status.json")" "ok" "Phase branding = ok"
assert_eq "$(jq -r '.industry_tag' "$WORK/a/ui-check.json")" "saas" "ui-check.json: industry_tag durchgereicht"
assert_eq "$(jq -r '.industry_source' "$WORK/a/ui-check.json")" "explicit" "industry_source = explicit"
assert_eq "$(jq -r '.user_prompt' "$WORK/a/ui-check.json")" "Fokus Terminbuchung" "--prompt durchgereicht"
grep -q "Bereit für den Judge-Pass" "$WORK/a.out" && ok "Hinweis auf Judge-Pass" || bad "Judge-Hinweis fehlt"

echo; echo "▶ B: Finalize — score-report, Summary, runs.jsonl, Exit 0"
mk_judge "$WORK/a"
RUN_ARGS=(--finalize "$WORK/a")
run >"$WORK/b.out" 2>&1
assert_eq "$?" "0" "Finalize Exit 0 (alle Dimensionen messbar)"
[[ -s "$WORK/a/scores.json" ]] && ok "scores.json erzeugt" || bad "scores.json fehlt"
[[ -s "$WORK/a/report.md" ]] && ok "report.md erzeugt" || bad "report.md fehlt"
assert_eq "$(jq -r '.total' "$WORK/a/scores.json")" "74" "Gesamtscore 74 (durchgereichter Kontext)"
assert_eq "$(jq -r '.status' "$WORK/a/status.json")" "done" "status = done nach Finalize"
assert_eq "$(jq -r '.phases.scoring.status' "$WORK/a/status.json")" "ok" "Phase scoring = ok"
grep -q "Gesamtscore" "$WORK/b.out" && ok "Terminal-Summary: Gesamtscore" || bad "Summary Gesamtscore fehlt"
grep -q "Top-Befunde" "$WORK/b.out" && ok "Terminal-Summary: Top-Befunde" || bad "Top-Befunde fehlen"
grep -q "report.md" "$WORK/b.out" && ok "Terminal-Summary: Report-Pfad" || bad "Report-Pfad fehlt"
tail -1 "$RUNS" | grep -q '"industry_tag":"saas"' && ok "runs.jsonl: Zeile angehängt (saas)" || bad "runs.jsonl-Append fehlt"

echo; echo "▶ C: Fehlerpolitik — Capture-Fehler ⇒ Abbruch (Exit 2), Rest nicht gestartet"
RUN_ARGS=(https://ex.test --industry saas --out "$WORK/c")
run STUB_CAPTURE_RC=2 STUB_LH_RC=0 STUB_BRAND_RC=0 >"$WORK/c.out" 2>&1
assert_eq "$?" "2" "Capture-Fehler → Exit 2 (Abbruch)"
assert_eq "$(jq -r '.status' "$WORK/c/status.json")" "aborted" "status = aborted"
assert_eq "$(jq -r '.phases.capture.status' "$WORK/c/status.json")" "aborted" "Phase capture = aborted"
[[ ! -d "$WORK/c/branding" ]] && ok "Branding nicht gestartet (Abbruch vor Schritt 4)" || bad "Branding lief trotz Abbruch"
grep -qi "nichts zu bewerten" "$WORK/c.out" && ok "Meldung 'nichts zu bewerten'" || bad "Abbruch-Meldung fehlt"

echo; echo "▶ D: Fehlerpolitik — Lighthouse-Fehler ⇒ degradieren (Exit 1), Lauf nutzbar"
RUN_ARGS=(https://ex.test --industry saas --out "$WORK/d")
run STUB_CAPTURE_RC=0 STUB_LH_RC=1 STUB_BRAND_RC=0 >"$WORK/d.out" 2>&1
assert_eq "$?" "1" "Lighthouse-Fehler → Exit 1 (Teilfehler)"
assert_eq "$(jq -r '.status' "$WORK/d/status.json")" "awaiting_judge" "status = awaiting_judge (Lauf läuft weiter)"
assert_eq "$(jq -r '.phases.lighthouse.status' "$WORK/d/status.json")" "degraded" "Phase lighthouse = degraded"
assert_eq "$(jq -r '.phases.capture.status' "$WORK/d/status.json")" "ok" "Capture trotzdem ok"
# Finalize degradiert weiter → Exit 1, Perf/A11y nicht messbar
mk_judge "$WORK/d"; RUN_ARGS=(--finalize "$WORK/d"); run >"$WORK/d2.out" 2>&1
assert_eq "$?" "1" "Finalize degradiert → Exit 1"
assert_eq "$(jq -r '.dimensions.performance.measurable' "$WORK/d/scores.json")" "false" "performance nicht messbar"
grep -qi "Nicht messbar" "$WORK/d2.out" && ok "Summary vermerkt 'Nicht messbar'" || bad "'Nicht messbar' fehlt"

echo; echo "▶ E: Branding-Teilausfall ⇒ degradieren (Exit 1), Lauf nutzbar"
RUN_ARGS=(https://ex.test --industry saas --out "$WORK/e")
run STUB_CAPTURE_RC=0 STUB_LH_RC=0 STUB_BRAND_RC=1 >"$WORK/e.out" 2>&1
assert_eq "$?" "1" "Branding-Teilausfall → Exit 1"
assert_eq "$(jq -r '.phases.branding.status' "$WORK/e/status.json")" "degraded" "Phase branding = degraded"
assert_eq "$(jq -r '.phases.capture.status' "$WORK/e/status.json")" "ok" "Capture ok trotz Branding-Ausfall"

echo; echo "▶ F: Auto-Industrie — --industry fehlt → industry_source=auto"
RUN_ARGS=(https://ex.test --out "$WORK/f")
run STUB_CAPTURE_RC=0 STUB_LH_RC=0 STUB_BRAND_RC=0 >"$WORK/f.out" 2>&1
assert_eq "$(jq -r '.industry_source' "$WORK/f/ui-check.json")" "auto" "industry_source = auto ohne --industry"
grep -qi "Claude schlägt ihn aus dem Seiteninhalt vor" "$WORK/f.out" && ok "Hinweis auf Auto-Vorschlag" || bad "Auto-Hinweis fehlt"

echo; echo "▶ G: NNN-Kollisionssicherheit — gleiche URL, kein --out, zweiter Lauf NNN+1"
( cd "$WORK" && env STUB_CAPTURE_RC=0 STUB_LH_RC=0 STUB_BRAND_RC=0 bash "$UC" https://kollision.test --industry saas >/dev/null 2>&1 )
( cd "$WORK" && env STUB_CAPTURE_RC=0 STUB_LH_RC=0 STUB_BRAND_RC=0 bash "$UC" https://kollision.test --industry saas >/dev/null 2>&1 )
n_dirs="$(ls -d "$WORK"/runs/*kollision.test* 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "$n_dirs" "2" "zwei getrennte Run-Ordner (NNN hochgezählt)"
ls -d "$WORK"/runs/*kollision.test-001 >/dev/null 2>&1 && ls -d "$WORK"/runs/*kollision.test-002 >/dev/null 2>&1 \
  && ok "Ordner -001 und -002 vorhanden" || bad "NNN-Suffixe -001/-002 fehlen"

echo; echo "▶ H: Parallelität — Capture ∥ Lighthouse laufen gleichzeitig"
# Beide Stubs schlafen 2s. Bei parallelem Start ist die Phase-Dauer ~2s (nicht ~4s).
RUN_ARGS=(https://ex.test --industry saas --out "$WORK/h")
t0="$(date +%s)"
run STUB_CAPTURE_RC=0 STUB_LH_RC=0 STUB_BRAND_RC=0 STUB_CAPTURE_SLEEP=2 STUB_LH_SLEEP=2 >/dev/null 2>&1
t1="$(date +%s)"; elapsed=$(( t1 - t0 ))
[[ "$elapsed" -lt 4 ]] && ok "Capture+Lighthouse parallel (~${elapsed}s < 4s seriell)" || bad "Nicht parallel: ${elapsed}s ≥ 4s"

echo; echo "▶ I: Finalize-Gate — judge.json fehlt → Exit 2"
RUN_ARGS=(--finalize "$WORK/f")   # f hat kein judge.json
run >"$WORK/i.out" 2>&1
assert_eq "$?" "2" "Finalize ohne judge.json → Exit 2"
grep -qi "judge.json fehlt" "$WORK/i.out" && ok "Meldung 'judge.json fehlt'" || bad "judge-fehlt-Meldung fehlt"

echo; echo "▶ J: Argument-Gates (Exit 2)"
RUN_ARGS=(); run >"$WORK/j1.out" 2>&1; assert_eq "$?" "2" "keine URL → Exit 2"
RUN_ARGS=(https://ex.test --unknown-flag); run >"$WORK/j2.out" 2>&1; assert_eq "$?" "2" "unbekannte Option → Exit 2"
RUN_ARGS=(--finalize "$WORK/does-not-exist"); run >"$WORK/j3.out" 2>&1; assert_eq "$?" "2" "Finalize auf fehlenden Ordner → Exit 2"

echo; echo "▶ K: Inhalts-Gate — leere/Wartungsseite (spa_empty) ⇒ Abbruch (Exit 2)"
RUN_ARGS=(https://ex.test --industry saas --out "$WORK/k")
run STUB_CAPTURE_RC=0 STUB_CAPTURE_SUSPICION=spa_empty STUB_LH_RC=0 STUB_BRAND_RC=0 >"$WORK/k.out" 2>&1
assert_eq "$?" "2" "spa_empty → Exit 2 (Abbruch)"
assert_eq "$(jq -r '.status' "$WORK/k/status.json")" "aborted" "status = aborted"
assert_eq "$(jq -r '.phases.capture.status' "$WORK/k/status.json")" "aborted" "Phase capture = aborted"
assert_eq "$(jq -r '.phase' "$WORK/k/status.json")" "aborted" "phase != awaiting_judge (kein Hänger)"
[[ ! -d "$WORK/k/branding" ]] && ok "Branding nicht gestartet (Abbruch vor Judge-Pausenpunkt)" || bad "Branding lief trotz leerer Seite"
grep -qi "ohne bewertbaren Inhalt" "$WORK/k.out" && ok "Meldung 'ohne bewertbaren Inhalt'" || bad "Inhalts-Gate-Meldung fehlt"

echo; echo "──────────────────────────────────────────"
echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
if [[ $FAIL -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILURES[@]}" >&2
  exit 1
fi
echo "✓ Alle Tests bestanden"
