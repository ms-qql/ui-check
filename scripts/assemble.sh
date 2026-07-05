#!/usr/bin/env bash
#
# assemble.sh — Portfolio-Assembler (PROJ-13)
#
# Greenfield-Einstieg in die UI-Check-Pipeline: kein Capture/Audit als Quelle,
# sondern Branding-Profil + Registry + kurzer Kundenbrief. Das Skript erzeugt
# einen run-kompatiblen redesign/-Ordner, damit redesign.sh --verify und
# mockup-export.sh unverändert weiterarbeiten können.
#
# Nutzung:
#   scripts/assemble.sh --branding <slug> --industry <tag>
#                       [--sections hero,trust,features,pricing,cta]
#                       [--prompt "Kunden-Briefing"]
#                       [--template <slug>|--pin s=block|--exclude block]
#                       [--registry-only|--no-registry|--no-export]
#
# Exit:
#   0 ok          Scaffold + Registry-Auswahl erzeugt
#   1 degradiert  Registry-Fallbacks/Export-Warnungen, mockup.html liegt vor
#   2 Abbruch     ungültige Eingaben oder harte Registry-Lücke

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

die() { echo "✗ $*" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || die "jq nicht gefunden."
command -v node >/dev/null 2>&1 || die "node nicht gefunden."

BRANDING=""
INDUSTRY=""
SECTIONS="hero,trust,features,pricing,cta"
PROMPT=""
RUN_DIR=""
TEMPLATE=""
PIN=()
EXCLUDE=()
REGISTRY_ONLY=false
NO_REGISTRY=false
NO_EXPORT=false
REDESIGN_SH="${REDESIGN_SH:-$ROOT/scripts/redesign.sh}"
MOCKUP_EXPORT_SH="${MOCKUP_EXPORT_SH:-$ROOT/scripts/mockup-export.sh}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branding)      BRANDING="${2:-}"; shift 2 ;;
    --industry)      INDUSTRY="${2:-}"; shift 2 ;;
    --sections)      SECTIONS="${2:-}"; shift 2 ;;
    --prompt)        PROMPT="${2:-}"; shift 2 ;;
    --out)           RUN_DIR="${2:-}"; shift 2 ;;
    --template)      TEMPLATE="${2:-}"; shift 2 ;;
    --pin)           PIN+=("${2:-}"); shift 2 ;;
    --exclude)       EXCLUDE+=("${2:-}"); shift 2 ;;
    --registry-only) REGISTRY_ONLY=true; shift ;;
    --no-registry)   NO_REGISTRY=true; shift ;;
    --no-export)     NO_EXPORT=true; shift ;;
    -h|--help)       sed -n '2,29p' "$0"; exit 0 ;;
    -*)              die "Unbekannte Option: $1" ;;
    *)               die "Unerwartetes Argument: $1" ;;
  esac
done

[[ -n "$BRANDING" ]] || die "--branding <slug> fehlt."
[[ -n "$INDUSTRY" ]] || die "--industry <tag> fehlt."
[[ "$BRANDING" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "Ungültiger Branding-Slug: $BRANDING"
[[ "$INDUSTRY" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "Ungültiger Industrie-Tag: $INDUSTRY"
[[ "$REGISTRY_ONLY" == true && "$NO_REGISTRY" == true ]] && die "--registry-only und --no-registry schließen sich aus."

PROFILE="$ROOT/branding/$BRANDING/current"
[[ -d "$PROFILE" ]] || die "Branding-Profil nicht gefunden: branding/$BRANDING/current"
[[ -s "$PROFILE/tokens.json" ]] || die "Branding-Profil unvollständig: tokens.json fehlt."
[[ -s "$PROFILE/tailwind-theme.css" ]] || die "Branding-Profil unvollständig: tailwind-theme.css fehlt."
[[ -s "$ROOT/registry/registry.json" ]] || die "Registry fehlt: registry/registry.json"
[[ -s "$ROOT/scripts/registry-select.mjs" ]] || die "registry-select.mjs fehlt."
[[ -s "$REDESIGN_SH" ]] || die "redesign.sh fehlt: $REDESIGN_SH"
[[ -s "$MOCKUP_EXPORT_SH" ]] || die "mockup-export.sh fehlt: $MOCKUP_EXPORT_SH"

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g; s/-+/-/g'
}

normalize_german_copy() {
  sed -E 's/\bfuer\b/für/g; s/\bFuer\b/Für/g; s/\bueber\b/über/g; s/\bUeber\b/Über/g; s/\bLoesung\b/Lösung/g; s/\bLoesungen\b/Lösungen/g; s/\bnaechst/nächst/g; s/\bErstgespraech\b/Erstgespräch/g; s/\bEinschaetzung\b/Einschätzung/g'
}

if [[ -z "$RUN_DIR" ]]; then
  today="$(date +%F)"
  base="runs/${today}-assemble-$(slugify "$BRANDING")-$(slugify "$INDUSTRY")"
  n=1
  while :; do
    cand="${base}-$(printf '%03d' "$n")"
    [[ -e "$ROOT/$cand" ]] || { RUN_DIR="$ROOT/$cand"; break; }
    n=$((n+1))
  done
else
  [[ "$RUN_DIR" = /* ]] || RUN_DIR="$ROOT/$RUN_DIR"
fi
[[ ! -e "$RUN_DIR" ]] || die "Run-Ordner existiert bereits: $RUN_DIR"
PROMPT="$(printf '%s' "$PROMPT" | normalize_german_copy)"

RD="$RUN_DIR/redesign"
mkdir -p "$RD/shared" "$RD/safe" "$RD/bold" || die "Run-Ordner nicht anlegbar: $RUN_DIR"
cp "$PROFILE/tokens.json" "$RD/shared/tokens.json"
cp "$PROFILE/tailwind-theme.css" "$RD/shared/tailwind-theme.css"
[[ -s "$PROFILE/branding.md" ]] && cp "$PROFILE/branding.md" "$RD/shared/branding.md"
for f in logo.svg logo.png branding-meta.json; do
  [[ -s "$PROFILE/$f" ]] && cp "$PROFILE/$f" "$RD/shared/$f"
done

sections_json="$(printf '%s' "$SECTIONS" | tr ',' '\n' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' \
  | awk 'NF' | jq -R . | jq -s '.')"
section_count="$(jq 'length' <<<"$sections_json")"
[[ "$section_count" -gt 0 ]] || die "--sections enthält keine Sektionen."

content_tmp="$(mktemp)"
jq -n \
  --arg branding "$BRANDING" \
  --arg industry "$INDUSTRY" \
  --arg prompt "$PROMPT" \
  --argjson sectionTypes "$sections_json" '
  def title($t):
    if $t == "hero" then "Klares Angebot für " + $industry
    elif $t == "trust" then "Warum Kunden vertrauen"
    elif $t == "features" then "Leistungen und Vorteile"
    elif $t == "pricing" then "Festpreis-Pakete"
    elif $t == "cta" then "Nächster Schritt"
    else ($t | gsub("-"; " ") | ascii_upcase) end;
  def sid($t): ($t | ascii_downcase | gsub("[^a-z0-9-]"; "-"));
  ($sectionTypes | map(sid(.))) as $ids |
  (if ($ids | index("cta")) then "#cta" else ("#" + ($ids[-1] // "hero")) end) as $ctaTarget |
  { language: "de",
    source: "assemble",
    branding: $branding,
    industry_tag: $industry,
    brief: ($prompt | if . == "" then null else . end),
    conversion: {
      goal: "Anfrage für ein Landing-Page-Angebot",
      assumed: true,
      primary_cta: {label: "Anfrage starten", intent: "lead", target: $ctaTarget}
    },
    sections: [
      $sectionTypes[] as $t |
      { id: sid($t),
        type: $t,
        heading: title($t),
        body: (if $prompt == "" then "Platzhalter aus dem Kunden-Briefing im ui-assemble Skill ersetzen." else $prompt end),
        cta: (if $t == "hero" or $t == "cta" then {label:"Anfrage starten", intent:"lead", target:$ctaTarget} else null end),
        image_slots: [] }
    ] }' > "$content_tmp" || { rm -f "$content_tmp"; die "content.json konnte nicht erzeugt werden."; }
mv "$content_tmp" "$RD/shared/content.json"

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -n \
  --arg run_id "$(basename "$RUN_DIR")" \
  --arg created "$now" \
  --arg branding "$BRANDING" \
  --arg industry "$INDUSTRY" \
  --arg prompt "$PROMPT" \
  --argjson sections "$sections_json" \
  '{ mode:"assemble",
     run_id:$run_id,
     created_at:$created,
     branding:$branding,
     industry_tag:$industry,
     sections:$sections,
     brief:($prompt | if .=="" then null else . end),
     notes:["Greenfield-Lauf: kein Capture/Audit, keine DB, kein Server."] }' \
  > "$RD/redesign-context.json"

jq -n \
  --arg run_id "$(basename "$RUN_DIR")" \
  --arg branding "$BRANDING" \
  --arg industry "$INDUSTRY" \
  --arg prompt "$PROMPT" \
  --arg created "$now" \
  '{run_id:$run_id,status:"awaiting_generation",phase:"assemble",
    url:null,final_url:null,industry_tag:$industry,industry_source:"explicit",
    user_prompt:($prompt | if .=="" then null else . end),
    started_at:$created,updated_at:$created,
    phases:{assemble:{status:"ok",duration_seconds:0,error:null},
            redesign:{status:"awaiting_generation",duration_seconds:0,error:null},
            mockup:{status:"pending",duration_seconds:0,error:null}},
    assemble:{branding:$branding, industry:$industry}}' > "$RUN_DIR/status.json"

jq -n \
  --arg run_id "$(basename "$RUN_DIR")" \
  --arg branding "$BRANDING" \
  --arg industry "$INDUSTRY" \
  --arg prompt "$PROMPT" \
  --arg created "$now" \
  --argjson sections "$sections_json" \
  '{run_id:$run_id,mode:"assemble",branding:$branding,industry_tag:$industry,
    industry_source:"explicit",user_prompt:($prompt | if .=="" then null else . end),
    sections:$sections,created_at:$created}' > "$RUN_DIR/ui-check.json"

pins_json="$(for kv in "${PIN[@]:-}"; do [[ -n "$kv" ]] && printf '%s\n' "$kv"; done \
  | jq -R 'select(.!="") | (split("=")) | select(length==2) | {(.[0]):.[1]}' | jq -s 'add // {}')"
excludes_json="$(printf '%s\n' "${EXCLUDE[@]:-}" | jq -R 'select(.!="")' | jq -s '.')"
jq -n --arg t "$TEMPLATE" --argjson pin "$pins_json" --argjson exc "$excludes_json" \
  --argjson ro "$REGISTRY_ONLY" --argjson nr "$NO_REGISTRY" \
  '{template:(if $t=="" then null else $t end), pin:$pin, exclude:$exc, registryOnly:$ro, noRegistry:$nr}' \
  > "$RD/registry-config.json"

rc=0
for style in safe bold; do
  node "$ROOT/scripts/registry-select.mjs" --run "$RUN_DIR" --style "$style" --config "$RD/registry-config.json"
  c=$?
  (( c > rc )) && rc=$c
done

recipe_version="$(head -1 "$ROOT/recipes/VERSION" 2>/dev/null || true)"
[[ -n "$recipe_version" ]] || die "recipes/VERSION fehlt."

cat > "$RD/brief.md" <<EOF
# Assemble-Brief

## Conversion-Ziel
Anfrage für ein Landing-Page-Angebot aus einem vorhandenen Branding-Profil.

## Primärer CTA
"Anfrage starten" · intent: lead · Ziel: #cta

## Sektionsplan
$(jq -r '.sections | map(.id) | join(" → ")' "$RD/shared/content.json")

## Brand-Entscheidungen
Tokens, Theme und Registry-Alias kommen aus branding/$BRANDING/current. Tokens gewinnen bei Stilkonflikten.

## Anti-Slop-Constraints
Ein CTA-Label pro Intent; keine erfundenen Kundenzahlen; Kundendaten bleiben ausschließlich im Run.
EOF

jq -n --slurpfile content "$RD/shared/content.json" '
  {sections: [$content[0].sections[] | {
    id,
    original: null,
    change: ("Greenfield-Assemble-Sektion aus Branding-Profil, Registry-Auswahl und Briefing für " + .type + ".")
  }]}' > "$RD/compare.json"

cat > "$RD/images.md" <<'EOF'
# Bild-Slots

Dieser Assemble-Starter nutzt keine Bild-Slots. Registry- oder Visual-Passes
können später Slots ergänzen; dann müssen sie hier nachgetragen werden.
EOF

write_variant() {
  local variant="$1"
  local selection="$RD/registry-selection.$variant.json"
  mkdir -p "$RD/$variant"
  cat > "$RD/$variant/App.jsx" <<'EOF'
import React from "react";
import content from "../shared/content.json";

const sectionTone = {
  hero: "bg-ink text-paper",
  pricing: "bg-surface text-ink",
  trust: "bg-paper text-ink",
  cta: "bg-ink text-paper",
};

function Section({ section, index, variant }) {
  const tone = sectionTone[section.type] || (index % 2 === 0 ? "bg-paper text-ink" : "bg-surface text-ink");
  const isHero = section.type === "hero";
  const isCta = section.type === "cta";
  return (
    <section id={section.id} className={`${tone} section-padding`}>
      <div className="container-x">
        <div className={isHero || isCta ? "max-w-4xl" : "grid gap-8 lg:grid-cols-[0.85fr_1.15fr]"}>
          <div>
            <p className="mono-label mb-5 text-muted">{variant === "safe" ? "Safe" : "Bold"} · {section.type}</p>
            <h1 className={`${isHero ? "text-5xl lg:text-7xl" : "text-3xl lg:text-5xl"} display max-w-4xl`}>
              {section.heading}
            </h1>
          </div>
          <div className={isHero || isCta ? "mt-8 max-w-2xl" : "max-w-2xl"}>
            <p className="text-lg leading-relaxed text-muted">{section.body}</p>
            {section.cta ? (
              <a href={section.cta.target} className="mt-8 inline-flex rounded-[var(--radius)] bg-accent px-5 py-3 text-sm font-semibold text-paper">
                {section.cta.label}
              </a>
            ) : null}
          </div>
        </div>
      </div>
    </section>
  );
}

export default function App() {
  return (
    <main className="min-h-screen bg-paper text-ink">
      {content.sections.map((section, index) => (
        <Section key={section.id} section={section} index={index} variant={content.variant || "assemble"} />
      ))}
    </main>
  );
}
EOF
  jq -n \
    --arg variant "$variant" \
    --arg recipe "$recipe_version" \
    --slurpfile content "$RD/shared/content.json" \
    --slurpfile sel "$selection" '
    ($sel[0].sections // []) as $picked |
    {variant:$variant, recipe_version:$recipe, entry:"App.jsx",
     dials:(if $variant == "safe" then {variance:3,motion:1,density:4} else {variance:7,motion:2,density:3} end),
     sections: [$content[0].sections[] as $s |
       ($picked[]? | select(.id == $s.id)) as $p |
       {id:$s.id, layout:(if $s.type == "hero" or $s.type == "cta" then "full-bleed" else "stack" end),
        motion:"none", source:($p.decision // "generate"), block:($p.block // null)}],
     components_used:["assemble-starter"]}' > "$RD/$variant/manifest.json"
  jq -n '{name:"assemble-variant",private:true,
          dependencies:{react:"^19.1.0", "react-dom":"^19.1.0", tailwindcss:"^4.1.11"}}' \
    > "$RD/$variant/package.json"
}

write_variant safe
write_variant bold

verify_rc=0
bash "$REDESIGN_SH" --verify "$RUN_DIR"
verify_rc=$?
[[ $verify_rc -ge 2 ]] && exit 2

export_rc=0
if [[ "$NO_EXPORT" != true ]]; then
  bash "$MOCKUP_EXPORT_SH" "$RUN_DIR" --force
  export_rc=$?
  [[ $export_rc -ge 2 ]] && exit 2
fi

echo
echo "✓ Assemble-Run angelegt → $(realpath --relative-to="$ROOT" "$RUN_DIR" 2>/dev/null || printf '%s' "$RUN_DIR")"
echo "  · Branding: $BRANDING"
echo "  · Industrie: $INDUSTRY"
echo "  · Sektionsplan: $(jq -r 'join(",")' <<<"$sections_json")"
if [[ "$NO_EXPORT" == true ]]; then
  echo "  · Export übersprungen (--no-export): Verify wurde ausgeführt, mockup.html nicht erzeugt."
else
  echo "  · Verify + Mockup-Export ausgeführt: $RUN_DIR/mockup.html"
fi

[[ $rc -ge 2 || $verify_rc -ge 2 || $export_rc -ge 2 ]] && exit 2
[[ $rc -eq 1 || $verify_rc -eq 1 || $export_rc -eq 1 ]] && exit 1
exit 0
