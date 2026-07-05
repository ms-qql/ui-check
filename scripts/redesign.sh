#!/usr/bin/env bash
#
# redesign.sh — Redesign-Generierung Safe+Bold (PROJ-6), deterministischer Treiber
#
# Generator-Sandwich (analog PROJ-5): alles Kreative macht Claude (Skill
# `ui-redesign`), alles Prüfbare dieses Skript. Zwei Modi:
#
#   1) INIT     redesign.sh <run-dir> [--force]
#      Gate (Stufe-1-Lauf komplett?) → Scaffold <run-dir>/redesign/ →
#      Kontext bündeln (redesign-context.json: Scores, Cai, Befunde, Branding,
#      Nutzer-Prompt, Rezept-Version). Danach: Brief-/Content-/Visual-Pässe
#      durch Claude (siehe .claude/skills/ui-redesign/SKILL.md).
#
#   2) VERIFY   redesign.sh --verify <run-dir>
#      Deterministische Gates gegen das generierte redesign/:
#      Struktur · Brief-Pflichtabschnitte · content/compare/manifest-Kontrakte ·
#      Token-Lint (nur Tokens bzw. tokens-extra.json) · kein Google-Fonts-CDN ·
#      keine Lorem-/TODO-Reste · Bild-Slot-Deckung (images.md) ·
#      Anti-Slop mechanisch (CTA-Länge, ein Label pro Intent, Zigzag-Cap).
#      Ergebnis: <run-dir>/redesign/verify.json (grün/gelb/rot je Gate).
#
#   3) SELECT   redesign.sh --select <run-dir> [Registry-Overrides]
#      Registry-Andockung (PROJ-11) nach dem Content-Pass: wählt je Sektion
#      einen Registry-Block (Auto nach Typ+Branche+Stil, Fallback = generieren)
#      und schreibt redesign/registry-selection.{safe,bold}.json + redesign/registry/
#      (kopierte Blocks/lib + Token-Alias registry-tokens.css).
#
#   Registry-Overrides (auch bei INIT verwendbar, werden in registry-config.json
#   persistiert): --template <slug> · --pin <section>=<block> · --exclude <block>
#   · --registry-only (kein Fallback) · --no-registry (Registry aus).
#
#   Branding-Bibliothek (PROJ-12): --branding <slug> nutzt
#   branding/<slug>/current/ statt runs/<run>/branding/ als Quelle fuer
#   shared/tokens.json + shared/tailwind-theme.css.
#
# Exit-Codes (headless-tauglich, Jupiter/PROJ-14):
#   0  ok            — INIT vollständig bzw. alle Gates grün
#   1  degradiert    — INIT mit Vermerk (z. B. leere Token-Palette) bzw.
#                      nur Warn-Gates gelb
#   2  Abbruch       — fehlender Stufe-1-Lauf, ungültige Argumente,
#                      mindestens ein Pflicht-Gate rot
#
# Alle Meldungen auf Deutsch. Buildbarkeit selbst prüft erst PROJ-7.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

die() { echo "✗ $*" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || die "jq nicht gefunden — apt install jq / brew install jq."

# ── Argumente ──────────────────────────────────────────────────────────────
MODE="init"
RUN_DIR=""
FORCE=false
# Registry-Andockung (PROJ-11) — optionale Overrides
TEMPLATE=""
PIN=()
EXCLUDE=()
REGISTRY_ONLY=false
NO_REGISTRY=false
BRANDING_SLUG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify) MODE="verify"; RUN_DIR="${2:-}"; shift 2 ;;
    --select) MODE="select"; RUN_DIR="${2:-}"; shift 2 ;;
    --force)  FORCE=true; shift ;;
    --template)      TEMPLATE="${2:-}"; shift 2 ;;
    --pin)           PIN+=("${2:-}"); shift 2 ;;
    --exclude)       EXCLUDE+=("${2:-}"); shift 2 ;;
    --registry-only) REGISTRY_ONLY=true; shift ;;
    --no-registry)   NO_REGISTRY=true; shift ;;
    --branding)      BRANDING_SLUG="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    -*)       die "Unbekannte Option: $1" ;;
    *)        [[ -z "$RUN_DIR" ]] && RUN_DIR="$1" || die "Zu viele Argumente: $1"; shift ;;
  esac
done
[[ -n "$RUN_DIR" ]] || die "Kein Run-Ordner angegeben. Nutzung: redesign.sh <run-dir> [--force] | --verify <run-dir>"
[[ -d "$RUN_DIR" ]] || die "Run-Ordner nicht gefunden: $RUN_DIR"

RD="$RUN_DIR/redesign"
RECIPE_VERSION="$(head -1 "$ROOT/recipes/VERSION" 2>/dev/null || true)"
[[ -n "$RECIPE_VERSION" ]] || die "recipes/VERSION fehlt — Rezepte sind Teil des Repos."

resolve_branding_source() {
  if [[ -n "$BRANDING_SLUG" ]]; then
    [[ "$BRANDING_SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "Ungültiger Branding-Slug: $BRANDING_SLUG"
    local profile_dir="$ROOT/branding/$BRANDING_SLUG"
    [[ -d "$profile_dir" ]] || die "Branding-Profil nicht gefunden: branding/$BRANDING_SLUG"
    [[ -e "$profile_dir/current" ]] || die "Branding-Profil hat kein current-Ziel: branding/$BRANDING_SLUG/current"
    local src="$profile_dir/current"
    [[ -s "$src/tokens.json" ]] || die "Branding-Profil unvollständig: branding/$BRANDING_SLUG/current/tokens.json fehlt."
    [[ -s "$src/tailwind-theme.css" ]] || die "Branding-Profil unvollständig: branding/$BRANDING_SLUG/current/tailwind-theme.css fehlt."
    printf '%s\n' "$src"
    return 0
  fi
  [[ -s "$RUN_DIR/branding/tokens.json" ]] || die "branding/tokens.json fehlt — Branding-Extraktion (PROJ-3) ist Redesign-Voraussetzung."
  [[ -s "$RUN_DIR/branding/tailwind-theme.css" ]] || die "branding/tailwind-theme.css fehlt — Branding-Extraktion (PROJ-3) unvollständig."
  printf '%s\n' "$RUN_DIR/branding"
}

# status.json (PROJ-5) fortschreiben, falls vorhanden — Fortschrittsquelle Jupiter.
update_status() { # $1=phase-status $2=fehlertext
  local sf="$RUN_DIR/status.json" tmp
  [[ -s "$sf" ]] || return 0
  tmp="$(mktemp)"
  jq --arg s "$1" --arg e "${2:-}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.phases.redesign = {status:$s, error:($e|if .=="" then null else . end)} | .updated_at=$now' \
     "$sf" > "$tmp" 2>/dev/null && mv "$tmp" "$sf" || rm -f "$tmp"
}

# ── Registry-Andockung (PROJ-11) ────────────────────────────────────────────
# Overrides persistieren, damit --select später denselben Stand nutzt.
write_registry_config() {
  local pins_json exc_json
  pins_json="$(for kv in "${PIN[@]:-}"; do [[ -n "$kv" ]] && printf '%s\n' "$kv"; done \
                | jq -R 'select(.!="") | (split("=")) | select(length==2) | {(.[0]):.[1]}' | jq -s 'add // {}')"
  exc_json="$(printf '%s\n' "${EXCLUDE[@]:-}" | jq -R 'select(.!="")' | jq -s '.')"
  jq -n --arg t "$TEMPLATE" --argjson pin "$pins_json" --argjson exc "$exc_json" \
        --argjson ro "$REGISTRY_ONLY" --argjson nr "$NO_REGISTRY" \
     '{template:(if $t=="" then null else $t end), pin:$pin, exclude:$exc, registryOnly:$ro, noRegistry:$nr}' \
     > "$RD/registry-config.json"
}
# Selektor für safe+bold ausführen; höchsten Exit-Code (0 ok / 1 degradiert / 2 hart) zurückgeben.
run_registry_select() {
  command -v node >/dev/null 2>&1 || { echo "  ⚠ node fehlt — Registry-Auswahl übersprungen."; return 0; }
  [[ -s "$ROOT/registry/registry.json" ]] || { echo "  ⚠ Keine Registry — Auswahl übersprungen."; return 0; }
  local rc=0 st
  for st in safe bold; do
    node "$ROOT/scripts/registry-select.mjs" --run "$RUN_DIR" --style "$st" --config "$RD/registry-config.json" || { local c=$?; (( c > rc )) && rc=$c; }
  done
  return $rc
}

# Hex-Farben auf 6-stellige Kleinschreibung normalisieren (#abc → #aabbcc,
# Alpha-Kanal fällt weg) — Grundlage des Token-Lints.
norm_hex() {
  awk '{
    h=tolower($0); sub(/^#/,"",h)
    if (length(h)==3 || length(h)==4)
      h=substr(h,1,1) substr(h,1,1) substr(h,2,1) substr(h,2,1) substr(h,3,1) substr(h,3,1)
    else if (length(h)==8) h=substr(h,1,6)
    if (length(h)==6) print "#" h
  }' | sort -u
}

# ════════════════════════════════════════════════════════════════════════════
# INIT-Modus
# ════════════════════════════════════════════════════════════════════════════
if [[ "$MODE" == "init" ]]; then
  # ── Gate: Stufe-1-Lauf komplett? ──
  [[ -s "$RUN_DIR/meta.json" ]] || die "meta.json fehlt — kein Capture-Lauf (PROJ-1) in $RUN_DIR."
  cap_status="$(jq -r '.status // "unbekannt"' "$RUN_DIR/meta.json")"
  [[ "$cap_status" == "ok" ]] || die "Capture-Status ist '$cap_status' (erwartet: ok) — Redesign braucht einen vollständigen Stufe-1-Lauf."
  [[ -s "$RUN_DIR/scores.json" ]] || die "scores.json fehlt — erst Stufe 1 abschließen (ui-check.sh --finalize), dann Redesign."
  BRANDING_SRC="$(resolve_branding_source)" || exit $?

  if [[ -e "$RD" && "$FORCE" != true ]]; then
    die "Es existiert bereits ein Redesign in $RD — erneuter INIT nur mit --force (überschreibt shared/ + redesign-context.json, generierte Inhalte bleiben)."
  fi

  DEGRADED=false
  NOTES=()

  palette_n="$(jq -r '
    (.color // {}) |
    [.. | objects | (.["$value"]? // .hex?) |
      select(type == "string" and test("^#[0-9A-Fa-f]{3,8}$"))] |
    unique | length
  ' "$BRANDING_SRC/tokens.json" 2>/dev/null || echo 0)"
  if [[ "${palette_n:-0}" -eq 0 ]]; then
    DEGRADED=true
    NOTES+=("Token-Palette ist leer — jede Farbentscheidung muss im Brief begründet und in shared/tokens-extra.json deklariert werden.")
  fi
  logo_src="$(jq -r '.logo.source // "profile"' "$BRANDING_SRC/branding-meta.json" 2>/dev/null || echo profile)"
  [[ "$logo_src" == "null" ]] && NOTES+=("Kein Logo extrahiert — Wortmarke aus Tokens setzen, kein Logo erfinden.")

  mkdir -p "$RD/shared" "$RD/safe" "$RD/bold" || die "Scaffold nicht anlegbar: $RD"
  cp "$BRANDING_SRC/tokens.json"        "$RD/shared/tokens.json"
  cp "$BRANDING_SRC/tailwind-theme.css" "$RD/shared/tailwind-theme.css"
  jq -n \
    --arg mode "$( [[ -n "$BRANDING_SLUG" ]] && echo profile || echo run )" \
    --arg slug "$BRANDING_SLUG" \
    --arg source "$(realpath --relative-to="$ROOT" "$BRANDING_SRC" 2>/dev/null || printf '%s' "$BRANDING_SRC")" \
    --arg version "$(basename "$(realpath "$BRANDING_SRC" 2>/dev/null || printf '%s' "$BRANDING_SRC")")" \
    '{mode:$mode, slug:(if $slug=="" then null else $slug end), source:$source, version:$version}' \
    > "$RUN_DIR/.branding-source.json" 2>/dev/null || true

  # Kontext für Brief-/Content-/Visual-Pässe bündeln.
  notes_json="$(printf '%s\n' "${NOTES[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')"
  jq -n \
    --arg run_id "$(basename "$RUN_DIR")" \
    --arg recipe "$RECIPE_VERSION" \
    --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg logo "$logo_src" \
    --argjson pal "${palette_n:-0}" \
    --argjson degraded "$DEGRADED" \
    --argjson notes "$notes_json" \
    --slurpfile scores "$RUN_DIR/scores.json" \
    --slurpfile ctx0 <(cat "$RUN_DIR/ui-check.json" 2>/dev/null || echo '{}') '
    ($ctx0[0] // {}) as $ctx | ($scores[0] // {}) as $sc |
    { run_id: $run_id,
      url: ($ctx.url // null), final_url: ($ctx.final_url // null),
      industry_tag: ($ctx.industry_tag // null),
      user_prompt: ($ctx.user_prompt // null),
      rubric_version: ($ctx.rubric_version // $sc.rubric_version // null),
      recipe_version: $recipe,
      scores: { total: ($sc.total // null),
                dimensions: (($sc.dimensions // {}) | with_entries(.value |= {score: .score, measurable: .measurable})),
                cai: ($sc.dimensions.conversion.subscores // null) },
      top_findings: (($sc.findings // [])[0:10]),
      cta_present: ($sc.cta_present // null),
      branding: { palette_size: $pal, logo_source: $logo },
      degraded: $degraded, notes: $notes,
      created_at: $created }' > "$RD/redesign-context.json" \
    || die "redesign-context.json konnte nicht geschrieben werden."

  # Registry-Andockung: Config sichern; Auswahl sobald der Sektionsplan (content.json) existiert.
  write_registry_config
  if [[ -s "$RD/shared/content.json" ]]; then
    echo "  · Registry-Auswahl (safe+bold) …"
    run_registry_select || true
  fi

  update_status "awaiting_generation" ""

  echo "✓ Redesign-Scaffold angelegt → $RD"
  if [[ -n "$BRANDING_SLUG" ]]; then
    echo "  · shared/tokens.json + tailwind-theme.css aus Branding-Profil '$BRANDING_SLUG'"
  else
    echo "  · shared/tokens.json + tailwind-theme.css (eingefrorener Stand dieses Laufs)"
  fi
  echo "  · redesign-context.json (Scores, Befunde, Nutzer-Prompt, Rezept-Version $RECIPE_VERSION)"
  for n in "${NOTES[@]:-}"; do [[ -n "$n" ]] && echo "  ⚠ $n"; done
  echo
  echo "  Nächste Schritte (Claude, siehe .claude/skills/ui-redesign/SKILL.md):"
  echo "    1. Brief-Pass          → $RD/brief.md"
  echo "    2. Struktur/Content    → $RD/shared/content.json + $RD/compare.json"
  echo "    3. Visual-Pass ×2      → $RD/safe/ + $RD/bold/ + $RD/images.md"
  echo "    4. Gates               → scripts/redesign.sh --verify $RUN_DIR"
  [[ "$DEGRADED" == true ]] && exit 1
  exit 0
fi

# ════════════════════════════════════════════════════════════════════════════
# SELECT-Modus (Registry-Andockung nach dem Content-Pass)
# ════════════════════════════════════════════════════════════════════════════
if [[ "$MODE" == "select" ]]; then
  [[ -d "$RD" ]] || die "Kein redesign/ in $RUN_DIR — erst INIT ausführen."
  write_registry_config
  run_registry_select; rc=$?
  [[ $rc -ge 2 ]] && exit 2
  [[ $rc -eq 1 ]] && exit 1
  exit 0
fi

# ════════════════════════════════════════════════════════════════════════════
# VERIFY-Modus
# ════════════════════════════════════════════════════════════════════════════
[[ -d "$RD" ]] || die "Kein redesign/ in $RUN_DIR — erst INIT ausführen: redesign.sh $RUN_DIR"

GATES_TMP="$(mktemp)"; trap 'rm -f "$GATES_TMP"' EXIT
gate() { # $1=id $2=ok|warn|fail $3=Titel $4=Detail
  jq -cn --arg id "$1" --arg st "$2" --arg t "$3" --arg d "${4:-}" \
    '{id:$id, status:$st, title:$t, detail:($d|if .=="" then null else . end)}' >> "$GATES_TMP"
  case "$2" in
    ok)   echo "  ✓ $3" ;;
    warn) echo "  ⚠ $3 — ${4:-}" ;;
    fail) echo "  ✗ $3 — ${4:-}" >&2 ;;
  esac
}

echo "→ Verify: deterministische Gates gegen $RD …"

CONTENT="$RD/shared/content.json"
COMPARE="$RD/compare.json"

# ── G1: Ordner-/Datei-Struktur ──────────────────────────────────────────────
missing=()
for f in brief.md images.md compare.json shared/content.json shared/tokens.json shared/tailwind-theme.css redesign-context.json; do
  [[ -s "$RD/$f" ]] || missing+=("$f")
done
for v in safe bold; do
  [[ -d "$RD/$v" ]] || { missing+=("$v/"); continue; }
  for f in manifest.json package.json; do
    [[ -s "$RD/$v/$f" ]] || missing+=("$v/$f")
  done
done
if [[ ${#missing[@]} -eq 0 ]]; then
  gate G1 ok "Struktur vollständig (brief, images, compare, shared, safe/, bold/)"
else
  gate G1 fail "Struktur unvollständig" "fehlt: ${missing[*]}"
fi

# ── G-REG: Registry-Andockung (PROJ-11) — nur prüfen, falls genutzt ──────────
shopt -s nullglob; reg_sels=("$RD"/registry-selection.*.json); shopt -u nullglob
if [[ ${#reg_sels[@]} -gt 0 ]]; then
  reg_fail=0; reg_detail=""
  for f in "${reg_sels[@]}"; do
    stl="$(jq -r '.style' "$f")"; st="$(jq -r '.status' "$f")"
    gen="$(jq -r '.stats.generate' "$f")"; ro="$(jq -r '.overrides.registryOnly' "$f")"
    [[ "$st" == "error" ]] && { reg_fail=1; reg_detail+="$stl:error "; }
    [[ "$ro" == "true" && "${gen:-0}" -gt 0 ]] && { reg_fail=1; reg_detail+="$stl:registry-only-Lücke($gen) "; }
    while IFS= read -r b; do [[ -z "$b" ]] && continue
      [[ -s "$RD/registry/blocks/$b.jsx" ]] || { reg_fail=1; reg_detail+="$stl:$b-fehlt "; }
    done < <(jq -r '.blocks_copied[]?' "$f")
  done
  [[ -s "$RD/registry/registry-tokens.css" ]] || { reg_fail=1; reg_detail+="token-alias-fehlt "; }
  if [[ $reg_fail -eq 0 ]]; then
    gate GREG ok "Registry-Andockung konsistent (Auswahl + kopierte Blocks + Token-Alias)"
  else
    gate GREG fail "Registry-Andockung fehlerhaft" "$reg_detail"
  fi
fi

# ── G2: brief.md Pflicht-Abschnitte ─────────────────────────────────────────
if [[ -s "$RD/brief.md" ]]; then
  brief_missing=()
  for kw in "Conversion-Ziel" "Primärer CTA" "Sektionsplan" "Brand-Entscheidungen" "Anti-Slop"; do
    grep -qiE "^#{1,4} .*${kw}" "$RD/brief.md" || brief_missing+=("$kw")
  done
  if [[ ${#brief_missing[@]} -eq 0 ]]; then
    gate G2 ok "brief.md enthält alle Pflicht-Abschnitte"
  else
    gate G2 fail "brief.md unvollständig" "fehlende Abschnitte: ${brief_missing[*]}"
  fi
else
  gate G2 fail "brief.md fehlt oder leer" "Brief-Pass muss vor der Generierung laufen"
fi

# ── G3: content.json-Kontrakt ───────────────────────────────────────────────
CONTENT_OK=false
if [[ -s "$CONTENT" ]] && jq -e . "$CONTENT" >/dev/null 2>&1; then
  c_err="$(jq -r '
    [ if ((.sections // []) | length) == 0 then "keine sections" else empty end,
      ( .sections[]? | select((.id // "" | test("^[a-z0-9-]+$")) | not) | "ungültige section.id: \(.id // "leer")" ),
      ( .sections[]? | select((.type // "") == "") | "section \(.id): type fehlt" ),
      if ((.conversion.primary_cta.label // "") == "") then "conversion.primary_cta.label fehlt" else empty end
    ] | unique | join("; ")' "$CONTENT")"
  if [[ -z "$c_err" ]]; then
    CONTENT_OK=true
    gate G3 ok "content.json-Kontrakt erfüllt ($(jq '.sections|length' "$CONTENT") Sektionen)"
    lang="$(jq -r '.language // ""' "$CONTENT")"
    [[ "$lang" == "de" ]] || gate G3b warn "content.json language ist '${lang:-fehlt}'" "AC verlangt deutsche Texte (language: de)"
  else
    gate G3 fail "content.json-Kontrakt verletzt" "$c_err"
  fi
else
  gate G3 fail "content.json fehlt oder ist kein gültiges JSON" "$CONTENT"
fi

# ── G4: compare.json (Original↔Redesign-Zuordnung, PROJ-8-Input) ────────────
if [[ -s "$COMPARE" ]] && jq -e . "$COMPARE" >/dev/null 2>&1; then
  if [[ "$CONTENT_OK" == true ]]; then
    cmp_err="$(jq -r --slurpfile c "$CONTENT" '
      ([$c[0].sections[].id]) as $ids |
      [ ( .sections[]? | select((.id // "") as $i | ($ids | index($i)) | not) | "unbekannte id: \(.id // "leer")" ),
        ( .sections[]? | select((.change // .reason // "") == "") | "section \(.id): Begründung (change) fehlt" ),
        ( $ids[] as $i | select([.sections[]?.id] | index($i) | not) | "content-Sektion ohne compare-Eintrag: \($i)" )
      ] | unique | join("; ")' "$COMPARE")"
    if [[ -z "$cmp_err" ]]; then
      gate G4 ok "compare.json deckt alle Sektionen mit Begründung"
    else
      gate G4 fail "compare.json inkonsistent" "$cmp_err"
    fi
  else
    gate G4 warn "compare.json nicht prüfbar" "content.json ungültig"
  fi
else
  gate G4 fail "compare.json fehlt oder ist kein gültiges JSON" "$COMPARE"
fi

# ── G5: Varianten-Manifeste ─────────────────────────────────────────────────
declare -A MANIFEST_OK=( [safe]=false [bold]=false )
for v in safe bold; do
  m="$RD/$v/manifest.json"
  if [[ ! -s "$m" ]] || ! jq -e . "$m" >/dev/null 2>&1; then
    gate "G5-$v" fail "manifest.json ($v) fehlt oder ungültig" "$m"
    continue
  fi
  m_err=()
  [[ "$(jq -r '.variant // ""' "$m")" == "$v" ]] || m_err+=("variant ≠ $v")
  mrv="$(jq -r '.recipe_version // ""' "$m")"
  [[ "$mrv" == "$RECIPE_VERSION" ]] || m_err+=("recipe_version '$mrv' ≠ recipes/VERSION '$RECIPE_VERSION'")
  entry="$(jq -r '.entry // ""' "$m")"
  { [[ -n "$entry" && -s "$RD/$v/$entry" ]]; } || m_err+=("entry fehlt oder Datei nicht vorhanden: '$entry'")
  jq -e '(.sections // []) | length > 0 and all(.[]; (.id // "") != "" and (.layout // "") != "")' "$m" >/dev/null 2>&1 \
    || m_err+=("sections[] mit id+layout fehlen")
  if [[ "$CONTENT_OK" == true ]]; then
    unknown="$(jq -r --slurpfile c "$CONTENT" '([$c[0].sections[].id]) as $ids
      | [.sections[]?.id | select(($ids | index(.)) | not)] | join(", ")' "$m")"
    [[ -z "$unknown" ]] || m_err+=("unbekannte Sektions-IDs: $unknown")
  fi
  if [[ ${#m_err[@]} -eq 0 ]]; then
    MANIFEST_OK[$v]=true
    gate "G5-$v" ok "manifest.json ($v) konsistent (Rezept $RECIPE_VERSION)"
    jq -e '.dials.variance != null and .dials.motion != null' "$m" >/dev/null 2>&1 \
      || gate "G5b-$v" warn "manifest.json ($v): dials unvollständig" "variance/motion aus recipes/$v.md eintragen"
  else
    gate "G5-$v" fail "manifest.json ($v) verletzt Kontrakt" "$(IFS='; '; echo "${m_err[*]}")"
  fi
done

# ── G6: Token-Lint (Farben nur aus Tokens bzw. tokens-extra.json) ───────────
SRC_GLOB=(-name '*.jsx' -o -name '*.tsx' -o -name '*.js' -o -name '*.ts' -o -name '*.css' -o -name '*.html')
list_src() { find "$RD/safe" "$RD/bold" -path '*/node_modules/*' -prune -o -type f \( "${SRC_GLOB[@]}" \) -print 2>/dev/null; }

allowed="$( { grep -hoE '#[0-9a-fA-F]{3,8}' "$RD/shared/tailwind-theme.css" "$RD/shared/tokens.json" 2>/dev/null;
              jq -r '.colors[]?.value // empty' "$RD/shared/tokens-extra.json" 2>/dev/null;
              printf '#ffffff\n#000000\n'; } | norm_hex )"
found="$(list_src | xargs -r grep -hoE '#[0-9a-fA-F]{3,8}\b' 2>/dev/null | norm_hex)"
offtoken="$(comm -23 <(echo "$found" | sed '/^$/d') <(echo "$allowed" | sed '/^$/d'))"
tw_palette="$(list_src | xargs -r grep -lnE '(bg|text|border|from|via|to|ring|fill|stroke|shadow|accent|divide|outline)-(red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|slate|gray|zinc|neutral|stone)-[0-9]{2,3}' 2>/dev/null | head -3)"
if [[ -z "$offtoken" && -z "$tw_palette" ]]; then
  gate G6 ok "Token-Lint bestanden (nur Token-Farben)"
else
  det=""
  [[ -n "$offtoken" ]] && det="fremde Hex-Farben: $(echo "$offtoken" | paste -sd' ' | cut -c1-160)"
  [[ -n "$tw_palette" ]] && det="$det${det:+ · }Tailwind-Default-Palette in: $(echo "$tw_palette" | xargs -r -n1 basename | paste -sd' ')"
  gate G6 fail "Token-Lint verletzt" "$det (erlaubt: Tokens, tokens-extra.json mit Brief-Begründung, #fff/#000)"
fi
rgb_lit="$(list_src | xargs -r grep -lE '(rgba?|hsla?)\(\s*[0-9]' 2>/dev/null | head -3)"
[[ -z "$rgb_lit" ]] || gate G6b warn "rgb()/hsl()-Literale gefunden" "$(echo "$rgb_lit" | xargs -r -n1 basename | paste -sd' ') — Token-Variablen bevorzugen"

# ── G7: kein Google-Fonts-CDN (DSGVO) ───────────────────────────────────────
gf="$(find "$RD" -path '*/node_modules/*' -prune -o -type f -print 2>/dev/null \
  | xargs -r grep -lE 'fonts\.(googleapis|gstatic)\.com' 2>/dev/null | head -3)"
if [[ -z "$gf" ]]; then
  gate G7 ok "Kein Google-Fonts-CDN (DSGVO)"
else
  gate G7 fail "Google-Fonts-CDN referenziert" "$(echo "$gf" | xargs -r -n1 basename | paste -sd' ') — Bunny Fonts oder self-hosted verwenden"
fi

# ── G8: keine Lorem-/TODO-Reste ─────────────────────────────────────────────
lorem="$(find "$RD" -path '*/node_modules/*' -prune -o -type f -print 2>/dev/null \
         | xargs -r grep -niE 'lorem ipsum|\bTODO\b|\bFIXME\b|\bTBD\b' 2>/dev/null \
         | grep -v 'redesign-context.json\|verify.json' | head -3)"
if [[ -z "$lorem" ]]; then
  gate G8 ok "Keine Lorem-/TODO-Platzhalter-Reste"
else
  gate G8 fail "Platzhalter-Reste gefunden" "$(echo "$lorem" | cut -c1-200 | paste -sd' · ')"
fi

# ── G9: Bild-Slot-Deckung (images.md ↔ content.json ↔ Code) ────────────────
if [[ "$CONTENT_OK" == true && -s "$RD/images.md" ]]; then
  declared="$(jq -r '.sections[].image_slots[]?' "$CONTENT" | sort -u)"
  slot_err=(); slot_warn=()
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    grep -qE "Slot:[[:space:]]*${id}\b" "$RD/images.md" || slot_err+=("Slot '$id' fehlt in images.md")
  done <<< "$declared"
  referenced="$(list_src | xargs -r grep -hoE 'data-image-slot="[^"]+"' 2>/dev/null | sed 's/.*="//; s/"$//' | sort -u)"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    grep -qxF "$id" <<< "$declared" || slot_err+=("Code referenziert undeklarierten Slot '$id'")
  done <<< "$referenced"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    grep -qxF "$id" <<< "$referenced" || slot_warn+=("Slot '$id' wird in keiner Variante verwendet")
  done <<< "$declared"
  if [[ ${#slot_err[@]} -eq 0 ]]; then
    gate G9 ok "Bild-Slots gedeckt (images.md ↔ content.json ↔ Code)"
  else
    gate G9 fail "Bild-Slot-Deckung verletzt" "$(IFS='; '; echo "${slot_err[*]}")"
  fi
  [[ ${#slot_warn[@]} -eq 0 ]] || gate G9b warn "Ungenutzte Bild-Slots" "$(IFS='; '; echo "${slot_warn[*]}")"
else
  gate G9 fail "Bild-Slots nicht prüfbar" "images.md fehlt oder content.json ungültig"
fi

# ── G10: CTA-Länge (Taste-Pre-Flight: einzeilig ⇒ Wortlimit) ────────────────
if [[ "$CONTENT_OK" == true ]]; then
  p_label="$(jq -r '.conversion.primary_cta.label // ""' "$CONTENT")"
  p_words="$(wc -w <<< "$p_label" | tr -d ' ')"
  long_sec="$(jq -r '.sections[]?.cta.label // empty' "$CONTENT" | awk 'NF>4 {print "\"" $0 "\""}' | paste -sd' ')"
  if [[ "$p_words" -le 3 && -z "$long_sec" ]]; then
    gate G10 ok "CTA-Längen ok (primär ≤ 3 Wörter, Sektions-CTAs ≤ 4)"
  else
    det=""
    [[ "$p_words" -gt 3 ]] && det="primärer CTA '$p_label' hat $p_words Wörter (max 3)"
    [[ -n "$long_sec" ]] && det="$det${det:+ · }Sektions-CTAs > 4 Wörter: $long_sec"
    gate G10 fail "CTA-Text zu lang (Wrap-Gefahr)" "$det"
  fi
fi

# ── G11: ein CTA-Label pro Intent ───────────────────────────────────────────
if [[ "$CONTENT_OK" == true ]]; then
  cta_err="$(jq -r '
    ([(.conversion.primary_cta // empty), (.sections[]?.cta // empty)]
     | map({label:(.label // ""), intent:(.intent // "")})) as $ctas |
    [ ( $ctas[] | select(.intent == "") | "CTA ohne intent: \"\(.label)\"" ),
      ( $ctas | group_by(.intent)[] | select((map(.label | ascii_downcase) | unique | length) > 1)
        | "Intent \"\(.[0].intent)\" hat mehrere Labels: \(map(.label) | unique | join(" / "))" )
    ] | unique | join("; ")' "$CONTENT")"
  if [[ -z "$cta_err" ]]; then
    gate G11 ok "Ein CTA-Label pro Intent"
  else
    gate G11 fail "CTA-Intent-Regel verletzt" "$cta_err"
  fi
fi

# ── G12: Zigzag-Cap (max. 2 split-Sektionen in Folge, je Variante) ──────────
for v in safe bold; do
  [[ "${MANIFEST_OK[$v]}" == true ]] || continue
  streak="$(jq -r '[.sections[].layout] | join(" ")' "$RD/$v/manifest.json" \
    | awk '{ run=0; max=0; for (i=1;i<=NF;i++){ if ($i=="split") {run++; if (run>max) max=run} else run=0 } print max }')"
  if [[ "${streak:-0}" -le 2 ]]; then
    gate "G12-$v" ok "Zigzag-Cap eingehalten ($v)"
  else
    gate "G12-$v" fail "Zigzag-Cap verletzt ($v)" "$streak × 'split' in Folge (max 2) — Layout-Familie wechseln (full-bleed, stack, bento, marquee …)"
  fi
done

# ── G13: npm-Abhängigkeiten (Whitelist, nur Warnung) ────────────────────────
DEP_WL='^(react|react-dom|motion|@paper-design/shaders-react|tailwindcss|@tailwindcss/.+|clsx|tailwind-merge|class-variance-authority|@radix-ui/.+|@phosphor-icons/react|lucide-react)$'
for v in safe bold; do
  [[ -s "$RD/$v/package.json" ]] || continue
  extra="$(jq -r '
      ((.dependencies // {}) | keys[] | "dependencies\t" + .),
      ((.devDependencies // {}) | keys[] | "devDependencies\t" + .)
    ' "$RD/$v/package.json" 2>/dev/null \
    | awk -F '\t' -v re="$DEP_WL" '$2 !~ re { print $1 "/" $2 }' \
    | paste -sd' ')"
  [[ -z "$extra" ]] || gate "G13-$v" warn "Unerwartete Dependencies ($v)" "$extra — prüfen, ob fürs Bundle (PROJ-7) nötig"
done

# ── G14: deutsche Umlaute statt ASCII-Umschreibungen ────────────────────────
umlaut_files="$(
  find "$RD" -type f \
    \( -name '*.md' -o -name '*.json' -o -name '*.jsx' -o -name '*.tsx' -o -name '*.js' -o -name '*.ts' \) \
    ! -path '*/node_modules/*' ! -name 'package-lock.json' ! -name 'verify.json' 2>/dev/null
)"
umlaut_hits="$(
  printf '%s\n' "$umlaut_files" \
    | xargs -r grep -nE '\b[A-Za-z]*(Loesung|Loesungen|fuer|Fuer|ueber|Ueber|naechst|Erstgespraech|Einschaetzung|glaubwuerdig|gleichfoermig|Saeulen|primaer|Flaeche|Flaechen|Weiss|zusaetzlich|unnoetig|mittelstaendisch|enthaelt|Uebergabe|hoeren)[A-Za-z]*\b' 2>/dev/null \
    | head -5
)"
if [[ -z "$umlaut_hits" ]]; then
  gate G14 ok "Deutsche Umlaute korrekt (keine ae/oe/ue-Umschreibungen in Copy)"
else
  gate G14 fail "ASCII-Umschreibungen statt Umlauten gefunden" "$(echo "$umlaut_hits" | sed "s#$RD/##" | cut -c1-220 | paste -sd' · ')"
fi

# ── Ergebnis ────────────────────────────────────────────────────────────────
summary="$(jq -s '{ok: map(select(.status=="ok"))|length,
                   warn: map(select(.status=="warn"))|length,
                   fail: map(select(.status=="fail"))|length}' "$GATES_TMP")"
n_fail="$(jq -r '.fail' <<< "$summary")"
n_warn="$(jq -r '.warn' <<< "$summary")"

jq -s --arg run_id "$(basename "$RUN_DIR")" --arg recipe "$RECIPE_VERSION" \
      --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson summary "$summary" \
   '{run_id: $run_id, recipe_version: $recipe, checked_at: $now,
     summary: $summary, gates: .}' "$GATES_TMP" > "$RD/verify.json" \
  || die "verify.json konnte nicht geschrieben werden."

echo
if [[ "$n_fail" -gt 0 ]]; then
  update_status "failed" "$n_fail rote(s) Gate(s) — siehe redesign/verify.json"
  echo "✗ Verify: $n_fail rote(s) Gate(s), $n_warn Warnung(en) → $RD/verify.json" >&2
  echo "  Rote Gates beheben (Fix im jeweiligen Pass), dann erneut: redesign.sh --verify $RUN_DIR" >&2
  exit 2
elif [[ "$n_warn" -gt 0 ]]; then
  update_status "degraded" "$n_warn Warnung(en) — siehe redesign/verify.json"
  echo "⚠ Verify: alle Pflicht-Gates grün, $n_warn Warnung(en) → $RD/verify.json"
  echo "  Weiter mit PROJ-7 (Mockup-Export) möglich."
  exit 1
else
  update_status "ok" ""
  echo "✓ Verify: alle Gates grün → $RD/verify.json"
  echo "  Redesign bereit für PROJ-7 (Mockup-Export)."
  exit 0
fi
