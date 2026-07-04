#!/usr/bin/env bash
#
# images-fill.sh — Automatische Bild-Befüllung der Redesign-Slots (PROJ-20)
#
# Läuft NACH der Redesign-Generierung (PROJ-6) und VOR dem Mockup-Export
# (PROJ-7). Füllt die von PROJ-6 deklarierten Bild-Slots (content.json →
# sections[].image_slots, gedeckt durch images.md) mit echten Bildern. Feste
# Fallback-Kette je Slot:
#
#   1) Stock       Unsplash + Pexels (Gratis-API)      [opt-in: *_KEY]
#   2) Website     eigene Bilder der auditierten Domain (capture/page-images.json)
#   3) Generierung OpenAI gpt-image | fal.ai Flux | Recraft [opt-in: *_KEY]
#
# Jede Stufe ist opt-in. Ohne jeglichen Key bleibt der Slot Platzhalter (0-€-
# Verhalten wie PROJ-6-MVP) — der Lauf bricht nie ab. Stock/Website-Kandidaten
# durchlaufen ein Judge-Gate (Default: Auflösungs-/Seitenverhältnis-Heuristik;
# via $IMAGES_FILL_JUDGE_CMD durch einen Claude-Judge ersetzbar). Generierte
# Bilder gelten ohne Judge als passend (Prompt == Kontext).
#
# Ergebnis (Run-Ordner-Kontrakt, alles additiv — bricht kein PROJ-6/7-Gate):
#   <run-dir>/redesign/assets/<slot-id>.<ext>   gefüllte Bilddateien
#   <run-dir>/redesign/images-fill.json         Manifest (Quelle/Lizenz/Score/Datei)
#   <run-dir>/redesign/images-fill.md           menschenlesbarer Bericht
#
# Nutzung:
#   images-fill.sh <run-dir> [--force] [--threshold N] [--only safe|bold]
#
# Exit-Codes (headless-tauglich, Jupiter/PROJ-14):
#   0  ok          — alle Slots verarbeitet (gefüllt oder bewusst Platzhalter,
#                    weil keine Quelle aktiv war)
#   1  degradiert  — mindestens ein Slot blieb Platzhalter, obwohl eine Quelle
#                    aktiv war, oder eine API meldete Fehler
#   2  Abbruch     — fehlender Redesign-Lauf / ungültige Argumente
#
# Env (alle Quellen opt-in, nie im Repo):
#   UNSPLASH_ACCESS_KEY   PEXELS_API_KEY
#   OPENAI_API_KEY        FAL_KEY            RECRAFT_API_KEY
#   IMAGES_FILL_GEN_PROVIDER   erzwingt openai|fal|recraft bei mehreren Keys
#   IMAGES_FILL_JUDGE_CMD      externer Judge (Kandidat-JSON auf stdin → Score 0..100)
#   *_API_BASE                 Basis-URLs überschreibbar (Tests/Proxy)
#
# Alle Meldungen auf Deutsch. Maschinenlesbares Ergebnis in images-fill.json.

set -uo pipefail

die() { echo "✗ $*" >&2; exit 2; }
command -v jq   >/dev/null 2>&1 || die "jq nicht gefunden — apt install jq / brew install jq."
command -v curl >/dev/null 2>&1 || die "curl nicht gefunden."

# ── Argumente ──────────────────────────────────────────────────────────────
RUN_DIR=""
FORCE=false
THRESHOLD="${IMAGES_FILL_THRESHOLD:-70}"
ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)     FORCE=true; shift ;;
    --threshold) THRESHOLD="${2:-70}"; shift 2 ;;
    --only)      ONLY="${2:-}"; shift 2 ;;
    -h|--help)   sed -n '2,40p' "$0"; exit 0 ;;
    -*)          die "Unbekannte Option: $1" ;;
    *)           [[ -z "$RUN_DIR" ]] && RUN_DIR="$1" || die "Zu viele Argumente: $1"; shift ;;
  esac
done
[[ -n "$RUN_DIR" ]] || die "Kein Run-Ordner. Nutzung: images-fill.sh <run-dir> [--force] [--threshold N] [--only safe|bold]"
[[ -d "$RUN_DIR" ]] || die "Run-Ordner nicht gefunden: $RUN_DIR"
[[ "$THRESHOLD" =~ ^[0-9]+$ ]] || die "--threshold erwartet eine Zahl, bekam: $THRESHOLD"
[[ -z "$ONLY" || "$ONLY" == "safe" || "$ONLY" == "bold" ]] || die "--only erwartet safe|bold, bekam: $ONLY"

RD="$RUN_DIR/redesign"
CONTENT="$RD/shared/content.json"
IMAGES_MD="$RD/images.md"
ASSETS="$RD/assets"
MANIFEST="$RD/images-fill.json"
REPORT="$RD/images-fill.md"
PAGE_IMAGES="$RUN_DIR/capture/page-images.json"
# Optional vom Skill/Claude geschriebene, thematisch geschärfte (EN) Suchqueries
# je Slot: { "<slot-id>": {"query":"…","orientation":"landscape|portrait|squarish"} }
QUERIES="$RD/images-fill-queries.json"

[[ -d "$RD" ]]        || die "Kein redesign/ in $RUN_DIR — erst PROJ-6 fahren (/ui-redesign)."
[[ -s "$CONTENT" ]]   || die "redesign/shared/content.json fehlt — PROJ-6 unvollständig."
jq -e '.sections' "$CONTENT" >/dev/null 2>&1 || die "content.json ungültig (keine sections)."
[[ -s "$IMAGES_MD" ]] || die "redesign/images.md fehlt — PROJ-6-Slot-Prompts sind Voraussetzung."

# status.json (PROJ-5) fortschreiben, falls vorhanden.
update_status() { # $1=status $2=fehlertext
  local sf="$RUN_DIR/status.json" tmp
  [[ -s "$sf" ]] || return 0
  tmp="$(mktemp)"
  jq --arg s "$1" --arg e "${2:-}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.phases.images_fill = {status:$s, error:($e|if .=="" then null else . end)} | .updated_at=$now' \
     "$sf" > "$tmp" 2>/dev/null && mv "$tmp" "$sf" || rm -f "$tmp"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$ASSETS"

# ── Quellen-Verfügbarkeit ───────────────────────────────────────────────────
UNSPLASH_BASE="${UNSPLASH_API_BASE:-https://api.unsplash.com}"
PEXELS_BASE="${PEXELS_API_BASE:-https://api.pexels.com}"
OPENAI_BASE="${OPENAI_API_BASE:-https://api.openai.com}"
FAL_BASE="${FAL_API_BASE:-https://fal.run}"
RECRAFT_BASE="${RECRAFT_API_BASE:-https://external.api.recraft.ai}"

STOCK_ON=false
[[ -n "${UNSPLASH_ACCESS_KEY:-}" || -n "${PEXELS_API_KEY:-}" ]] && STOCK_ON=true
WEBSITE_ON=false
[[ -s "$PAGE_IMAGES" ]] && WEBSITE_ON=true

GEN_PROVIDER=""
if [[ -n "${IMAGES_FILL_GEN_PROVIDER:-}" ]]; then
  GEN_PROVIDER="$IMAGES_FILL_GEN_PROVIDER"
elif [[ -n "${OPENAI_API_KEY:-}" ]]; then GEN_PROVIDER="openai"
elif [[ -n "${FAL_KEY:-}" ]];        then GEN_PROVIDER="fal"
elif [[ -n "${RECRAFT_API_KEY:-}" ]]; then GEN_PROVIDER="recraft"
fi

JUDGE_MODE="heuristic"; [[ -n "${IMAGES_FILL_JUDGE_CMD:-}" ]] && JUDGE_MODE="external"

echo "→ Bild-Befüllung: Stock=$([[ $STOCK_ON == true ]] && echo an || echo aus) · Website=$([[ $WEBSITE_ON == true ]] && echo an || echo aus) · Generierung=${GEN_PROVIDER:-aus} · Judge=$JUDGE_MODE · Schwelle=$THRESHOLD"

# BUG-1-Hinweis: Stock aktiv, aber keine geschärften Queries vom Skill → nur die
# schwache deutsche Fallback-Query. Nur Empfehlung (kein Fehler, kein Exit-Einfluss).
if [[ "$STOCK_ON" == true && ! -s "$QUERIES" ]]; then
  echo "  ⚠ Keine images-fill-queries.json — Stock-Suche nutzt nur die bereinigte deutsche Fallback-Query"
  echo "     (v. a. Unsplash findet so oft nichts). Für beste Trefferqualität über den Skill starten:"
  echo "     /ui-images-fill $RUN_DIR   — Claude schreibt dann englische Queries je Slot."
fi

declare -a NOTES=()
note() { NOTES+=("$1"); }

# ── Slots einlesen (mit Section-Heading, Prompt, Ziel-Maßen, Varianten-Nutzung)
# Von welchen Varianten wird ein Slot per data-image-slot referenziert?
slot_used_in() { # $1=slot-id → "safe,bold" (Teilmenge, evtl. leer)
  local id="$1" used=()
  for v in safe bold; do
    if [[ -d "$RD/$v" ]] && grep -rqE "data-image-slot=\"$id\"" "$RD/$v" 2>/dev/null; then used+=("$v"); fi
  done
  (IFS=,; echo "${used[*]}")
}

# Ziel-Maße aus dem images.md-Slotblock (Platzhalter "1600×900" / "1600x900").
slot_target() { # $1=slot-id → "W H" (Default 1600 900)
  local id="$1" block dims
  block="$(awk -v id="$id" '
    $0 ~ "^##[[:space:]]*Slot:[[:space:]]*"id"([^A-Za-z0-9-]|$)" {p=1; next}
    /^##[[:space:]]*Slot:/ {p=0}
    p {print}' "$IMAGES_MD")"
  dims="$(printf '%s' "$block" | grep -oiE '[0-9]{3,5}[[:space:]]*[x×][[:space:]]*[0-9]{3,5}' | head -1)"
  if [[ "$dims" =~ ([0-9]{3,5})[[:space:]]*[x×][[:space:]]*([0-9]{3,5}) ]]; then
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
  else
    echo "1600 900"
  fi
}

# Bild-Prompt aus dem Slotblock (erste **Bild-Prompt:**-Zeile, Anführungen weg).
slot_prompt() { # $1=slot-id
  awk -v id="$1" '
    $0 ~ "^##[[:space:]]*Slot:[[:space:]]*"id"([^A-Za-z0-9-]|$)" {p=1; next}
    /^##[[:space:]]*Slot:/ {p=0}
    p' "$IMAGES_MD" 2>/dev/null | \
    grep -iE 'Bild-Prompt' | head -1 | \
    sed -E 's/.*Bild-Prompt[^:]*:[[:space:]]*//; s/^["“]//; s/["”][[:space:]]*$//'
}

# Slot → Heading (aus content.json, erste Sektion, die den Slot deklariert).
slot_heading() { # $1=slot-id
  jq -r --arg id "$1" '[.sections[] | select((.image_slots // []) | index($id)) | .heading][0] // ""' "$CONTENT"
}

# Fallback-Suchquery aus dem Heading bauen (BUG-1): deutsche Stopwörter, generische
# Slot-Wörter ("bild"/"foto"/"hero"/…) und die Slot-ID-Wörter entfernen, damit die
# Stock-Suche nicht an Füllwörtern scheitert. Bevorzugt wird ohnehin die vom Skill
# gelieferte images-fill-queries.json (thematisch/EN) — das ist nur die Rückfallebene.
build_query() { # $1=heading $2=slot-id → bereinigte Query
  local heading="$1" idw; idw="$(printf '%s' "$2" | tr '-' ' ')"
  printf '%s' "$heading" | tr 'A-ZÄÖÜ' 'a-zäöü' | tr -cs 'a-zäöü0-9' ' ' | \
    awk -v idw="$idw" 'BEGIN{
      split("der die das den dem des ein eine einer eines fuer für und mit im am in an auf zu von aus bei über als wie ihre ihr unser unsere sich den beim zur zum",sw," ");
      for(i in sw) stop[sw[i]]=1;
      split("bild bilder foto fotos image images hero slot grafik banner motiv aufnahme",gg," ");
      for(i in gg) gen[gg[i]]=1;
      n=split(idw,ida," "); for(i=1;i<=n;i++) idword[ida[i]]=1;
    }
    { for(j=1;j<=NF;j++){ w=$j; if(length(w)<3) continue; if(stop[w]||gen[w]||idword[w]) continue; printf "%s ", w } }' | \
    sed 's/  */ /g; s/^ //; s/ *$//'
}

# ── Download-Helfer (Content-Type-Bild-Prüfung, wie brand-extract fetch_ok) ──
fetch_image() { # $1=url $2=out-datei [$3=header] → 0/1
  local u="$1" out="$2" hdr="${3:-}" ct
  if [[ -n "$hdr" ]]; then
    ct="$(curl -sS -L --max-time 30 -H "$hdr" -A "Mozilla/5.0 (UI-Check/1.0 PROJ-20)" -o "$out" -w '%{content_type}' "$u" 2>/dev/null)" || return 1
  else
    ct="$(curl -sS -L --max-time 30 -A "Mozilla/5.0 (UI-Check/1.0 PROJ-20)" -o "$out" -w '%{content_type}' "$u" 2>/dev/null)" || return 1
  fi
  [[ -s "$out" ]] || return 1
  printf '%s' "$ct" | grep -qiE 'image/|octet-stream' || { rm -f "$out"; return 1; }
  return 0
}

ext_for_url() { case "${1,,}" in *.png*) echo png;; *.jpg*|*.jpeg*) echo jpg;; *.webp*) echo webp;; *.gif*) echo gif;; *.svg*) echo svg;; *) echo jpg;; esac; }

# ── Judge (Heuristik oder externer Befehl) → Score 0..100 ────────────────────
judge_score() { # $1=cand-json(mit width/height) $2=tw $3=th $4=prompt → Zahl
  local cj="$1" tw="$2" th="$3" prompt="$4"
  if [[ "$JUDGE_MODE" == "external" ]]; then
    local payload sc
    payload="$(jq -c --argjson tw "$tw" --argjson th "$th" --arg pr "$prompt" \
      '. + {target:{width:$tw,height:$th}, prompt:$pr}' <<<"$cj" 2>/dev/null)"
    sc="$(printf '%s' "$payload" | eval "$IMAGES_FILL_JUDGE_CMD" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
    [[ "$sc" =~ ^[0-9]+$ ]] && { echo "$(( sc>100 ? 100 : sc ))"; return; }
    echo 0; return
  fi
  # Heuristik: Auflösungs-Adäquanz + Seitenverhältnis-Nähe.
  local w h; w="$(jq -r '.width // 0' <<<"$cj")"; h="$(jq -r '.height // 0' <<<"$cj")"
  [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ && "$w" -gt 0 && "$h" -gt 0 ]] || { echo 0; return; }
  awk -v w="$w" -v h="$h" -v tw="$tw" -v th="$th" 'BEGIN{
    long=(w>h?w:h); tlong=(tw>th?tw:th);
    s=50;
    if (long>=tlong*0.9) s+=30; else if (long>=tlong*0.6) s+=20; else if (long>=400) s+=10; else s-=20;
    a=w/h; ta=tw/th; r=(a>ta?a/ta:ta/a);
    if (r<=1.15) s+=20; else if (r<=1.4) s+=10; else if (r>2.2) s-=25;
    if (s<0) s=0; if (s>100) s=100; printf "%d", s;
  }'
}

# ── Stufe 1: Stock (Unsplash + Pexels) → Kandidaten-JSONL ────────────────────
gather_stock() { # $1=slot $2=query $3=tw $4=th [$5=orient] → JSONL {tmp,source,license,attribution,width,height,url}
  local slot="$1" q="$2" tw="$3" th="$4" orient="${5:-}"
  if [[ -z "$orient" ]]; then
    orient="landscape"; [[ "$th" -gt "$tw" ]] && orient="portrait"; [[ "$tw" -eq "$th" ]] && orient="squarish"
  fi
  local i=0
  if [[ -n "${UNSPLASH_ACCESS_KEY:-}" ]]; then
    local resp; resp="$(curl -sS -L --max-time 25 -H "Authorization: Client-ID ${UNSPLASH_ACCESS_KEY}" \
      "${UNSPLASH_BASE}/search/photos?query=$(jq -rn --arg q "$q" '$q|@uri')&per_page=4&orientation=${orient}" 2>/dev/null)"
    while IFS= read -r row; do
      [[ -z "$row" || "$row" == "null" ]] && continue
      local url dl; url="$(jq -r '.url' <<<"$row")"; dl="$(jq -r '.download_location // empty' <<<"$row")"
      local tmp="$WORK/stock-u-$slot-$i.$(ext_for_url "$url")"
      if fetch_image "$url" "$tmp"; then
        # ToS: Download-Endpoint triggern (best effort).
        [[ -n "$dl" ]] && curl -sS -L --max-time 10 -H "Authorization: Client-ID ${UNSPLASH_ACCESS_KEY}" "$dl" >/dev/null 2>&1 || true
        jq -c --arg tmp "$tmp" '{tmp:$tmp, source:"stock:unsplash", license:"Unsplash License", attribution:.attribution, width:.width, height:.height, url:.page}' <<<"$row"
      fi
      i=$((i+1))
    done < <(jq -c '.results[]? | {url:(.urls.regular // .urls.full), page:.links.html, download_location:.links.download_location, width:.width, height:.height, attribution:{photographer:.user.name, profile_url:(.user.links.html // null)}}' <<<"$resp" 2>/dev/null)
  fi
  if [[ -n "${PEXELS_API_KEY:-}" ]]; then
    local resp; resp="$(curl -sS -L --max-time 25 -H "Authorization: ${PEXELS_API_KEY}" \
      "${PEXELS_BASE}/v1/search?query=$(jq -rn --arg q "$q" '$q|@uri')&per_page=4&orientation=${orient}" 2>/dev/null)"
    while IFS= read -r row; do
      [[ -z "$row" || "$row" == "null" ]] && continue
      local url; url="$(jq -r '.url' <<<"$row")"
      local tmp="$WORK/stock-p-$slot-$i.$(ext_for_url "$url")"
      if fetch_image "$url" "$tmp"; then
        jq -c --arg tmp "$tmp" '{tmp:$tmp, source:"stock:pexels", license:"Pexels License", attribution:.attribution, width:.width, height:.height, url:.page}' <<<"$row"
      fi
      i=$((i+1))
    done < <(jq -c '.photos[]? | {url:(.src.large2x // .src.large // .src.original), page:.url, width:.width, height:.height, attribution:{photographer:.photographer, profile_url:(.photographer_url // null)}}' <<<"$resp" 2>/dev/null)
  fi
}

# ── Stufe 2: Website (eigene Bilder der auditierten Domain) → Kandidaten-JSONL
gather_website() { # $1=slot $2=tw $3=th → JSONL
  local slot="$1" i=0
  [[ -s "$PAGE_IMAGES" ]] || return 0
  while IFS= read -r row; do
    [[ -z "$row" || "$row" == "null" ]] && continue
    local url; url="$(jq -r '.url' <<<"$row")"
    local tmp="$WORK/web-$slot-$i.$(ext_for_url "$url")"
    if fetch_image "$url" "$tmp"; then
      jq -c --arg tmp "$tmp" '{tmp:$tmp, source:"website", license:"Kunden-eigen (auditierte Domain)", attribution:{source_url:.url, alt:(.alt // null)}, width:.width, height:.height, url:.url}' <<<"$row"
    fi
    i=$((i+1))
  done < <(jq -c '[.images[]? | select((.width*.height) >= (600*400))] | sort_by(-(.width*.height)) | .[0:8][]' "$PAGE_IMAGES" 2>/dev/null)
  # og:image als Minimal-Fallback.
  local og; og="$(jq -r '.og_image // empty' "$PAGE_IMAGES" 2>/dev/null)"
  if [[ -n "$og" ]]; then
    local tmp="$WORK/web-$slot-og.$(ext_for_url "$og")"
    if fetch_image "$og" "$tmp"; then
      jq -nc --arg tmp "$tmp" --arg url "$og" '{tmp:$tmp, source:"website", license:"Kunden-eigen (og:image)", attribution:{source_url:$url}, width:1200, height:630, url:$url}'
    fi
  fi
}

# ── Stufe 3: Generierung (provider-agnostisch, opt-in) → 1 Datei, akzeptiert ─
generate_image() { # $1=slot $2=prompt $3=tw $4=th → JSONL(0/1 Zeile)
  local slot="$1" prompt="$2" tw="$3" th="$4"
  [[ -n "$GEN_PROVIDER" ]] || return 0
  local size="1024x1024"
  [[ "$tw" -gt "$th" ]] && size="1536x1024"; [[ "$th" -gt "$tw" ]] && size="1024x1536"
  local tmp="$WORK/gen-$slot"
  case "$GEN_PROVIDER" in
    openai)
      [[ -n "${OPENAI_API_KEY:-}" ]] || { note "Generierung openai: OPENAI_API_KEY fehlt"; return 0; }
      local body resp; body="$(jq -n --arg p "$prompt" --arg s "$size" '{model:"gpt-image-1", prompt:$p, size:$s, n:1}')"
      resp="$(curl -sS -L --max-time 120 -H "Authorization: Bearer ${OPENAI_API_KEY}" -H "Content-Type: application/json" \
        -d "$body" "${OPENAI_BASE}/v1/images/generations" 2>/dev/null)"
      local b64 url; b64="$(jq -r '.data[0].b64_json // empty' <<<"$resp" 2>/dev/null)"; url="$(jq -r '.data[0].url // empty' <<<"$resp" 2>/dev/null)"
      if [[ -n "$b64" ]]; then printf '%s' "$b64" | base64 -d > "$tmp.png" 2>/dev/null && tmp="$tmp.png" || return 0
      elif [[ -n "$url" ]]; then fetch_image "$url" "$tmp.png" && tmp="$tmp.png" || return 0
      else note "Generierung openai fehlgeschlagen: $(jq -r '.error.message // "unbekannt"' <<<"$resp" 2>/dev/null | head -c 120)"; return 0; fi
      ;;
    fal)
      [[ -n "${FAL_KEY:-}" ]] || { note "Generierung fal: FAL_KEY fehlt"; return 0; }
      local resp url; resp="$(curl -sS -L --max-time 120 -H "Authorization: Key ${FAL_KEY}" -H "Content-Type: application/json" \
        -d "$(jq -n --arg p "$prompt" '{prompt:$p, image_size:"landscape_16_9"}')" "${FAL_BASE}/fal-ai/flux/schnell" 2>/dev/null)"
      url="$(jq -r '.images[0].url // empty' <<<"$resp" 2>/dev/null)"
      [[ -n "$url" ]] && fetch_image "$url" "$tmp.png" && tmp="$tmp.png" || { note "Generierung fal fehlgeschlagen"; return 0; }
      ;;
    recraft)
      [[ -n "${RECRAFT_API_KEY:-}" ]] || { note "Generierung recraft: RECRAFT_API_KEY fehlt"; return 0; }
      local resp url; resp="$(curl -sS -L --max-time 120 -H "Authorization: Bearer ${RECRAFT_API_KEY}" -H "Content-Type: application/json" \
        -d "$(jq -n --arg p "$prompt" '{prompt:$p, style:"realistic_image"}')" "${RECRAFT_BASE}/v1/images/generations" 2>/dev/null)"
      url="$(jq -r '.data[0].url // empty' <<<"$resp" 2>/dev/null)"
      [[ -n "$url" ]] && fetch_image "$url" "$tmp.png" && tmp="$tmp.png" || { note "Generierung recraft fehlgeschlagen"; return 0; }
      ;;
    *) note "Unbekannter Generierungs-Provider: $GEN_PROVIDER"; return 0 ;;
  esac
  [[ -s "$tmp" ]] || return 0
  local gw="${size%x*}" gh="${size#*x}"
  jq -nc --arg tmp "$tmp" --arg prov "$GEN_PROVIDER" --argjson w "$gw" --argjson h "$gh" \
    '{tmp:$tmp, source:("generated:"+$prov), license:("KI-generiert ("+$prov+")"), attribution:null, width:$w, height:$h, url:null}'
}

# Kandidatenliste (JSONL) gegen die Schwelle prüfen → erste Annahme echoen.
pick_accepted() { # stdin=JSONL $1=tw $2=th $3=prompt → akzeptierte cand-json (+judge_score) | leer
  local tw="$1" th="$2" prompt="$3" cand sc
  while IFS= read -r cand; do
    [[ -z "$cand" ]] && continue
    sc="$(judge_score "$cand" "$tw" "$th" "$prompt")"
    if [[ "$sc" -ge "$THRESHOLD" ]]; then
      jq -c --argjson s "$sc" '. + {judge_score:$s}' <<<"$cand"; return 0
    fi
  done
  return 1
}

# ── Vorhandenes Manifest für Idempotenz laden ───────────────────────────────
prev_file_for() { # $1=slot → relativer Dateipfad falls bereits gefüllt & Datei da
  [[ -s "$MANIFEST" ]] || return 1
  local f; f="$(jq -r --arg id "$1" '.slots[]? | select(.slot_id==$id and .source!="placeholder") | .file // empty' "$MANIFEST" 2>/dev/null | head -1)"
  [[ -n "$f" && -s "$RD/$f" ]] && { echo "$f"; return 0; }
  return 1
}

# ── Hauptschleife über alle deklarierten Slots ──────────────────────────────
mapfile -t SLOTS < <(jq -r '[.sections[].image_slots[]?] | unique | .[]' "$CONTENT" 2>/dev/null)
SLOT_ENTRIES=()
FILLED=0; PLACEHOLDER=0; SOURCE_ERR=false
declare -A BY_SOURCE=()

for id in "${SLOTS[@]}"; do
  [[ -z "$id" ]] && continue
  used="$(slot_used_in "$id")"
  if [[ -n "$ONLY" ]]; then
    case ",$used," in *",$ONLY,"*) : ;; *) continue ;; esac
  fi
  read -r TW TH < <(slot_target "$id")
  PROMPT="$(slot_prompt "$id")"; [[ -n "$PROMPT" ]] || PROMPT="$(slot_heading "$id")"
  HEADING="$(slot_heading "$id")"
  # BUG-1: bevorzugt die vom Skill/Claude gelieferte (EN/thematische) Query je Slot;
  # sonst eine aus dem Heading bereinigte Fallback-Query (Stopwörter/Slot-Wörter raus).
  QUERY=""; ORIENT=""
  qj=""; [[ -s "$QUERIES" ]] && qj="$(jq -c --arg id "$id" '.[$id] // empty' "$QUERIES" 2>/dev/null)" || true
  if [[ -n "$qj" ]]; then
    QUERY="$(jq -r '.query // empty' <<<"$qj")"
    ORIENT="$(jq -r '.orientation // empty' <<<"$qj")"
  fi
  [[ -n "$QUERY" ]] || QUERY="$(build_query "$HEADING" "$id")"
  [[ -n "$QUERY" ]] || QUERY="$HEADING"
  [[ -n "$QUERY" ]] || QUERY="$(printf '%s' "$id" | tr '-' ' ')"
  used_json="$(printf '%s' "$used" | jq -Rc 'split(",") | map(select(length>0))')"

  # Idempotenz: bereits gefüllt & Datei vorhanden → übernehmen (außer --force).
  if [[ "$FORCE" != true ]] && prev="$(prev_file_for "$id")"; then
    entry="$(jq -c --arg id "$id" '.slots[] | select(.slot_id==$id)' "$MANIFEST" 2>/dev/null | head -1)"
    SLOT_ENTRIES+=("$(jq -c --argjson u "$used_json" '.used_in=$u' <<<"$entry")")
    FILLED=$((FILLED+1)); src="$(jq -r '.source' <<<"$entry")"; BY_SOURCE[$src]=$(( ${BY_SOURCE[$src]:-0} + 1 ))
    echo "  = $id: bereits gefüllt (${src}) — übersprungen (--force zum Neufüllen)"
    continue
  fi

  accepted=""
  # Stufe 1: Stock
  if [[ -z "$accepted" && "$STOCK_ON" == true ]]; then
    accepted="$(gather_stock "$id" "$QUERY" "$TW" "$TH" "$ORIENT" | pick_accepted "$TW" "$TH" "$PROMPT" || true)"
  fi
  # Stufe 2: Website
  if [[ -z "$accepted" && "$WEBSITE_ON" == true ]]; then
    accepted="$(gather_website "$id" "$TW" "$TH" | pick_accepted "$TW" "$TH" "$PROMPT" || true)"
  fi
  # Stufe 3: Generierung (ohne Judge)
  if [[ -z "$accepted" && -n "$GEN_PROVIDER" ]]; then
    gen="$(generate_image "$id" "$PROMPT" "$TW" "$TH" || true)"
    [[ -n "$gen" ]] && accepted="$(jq -c '. + {judge_score:null}' <<<"$gen")"
  fi

  if [[ -n "$accepted" ]]; then
    tmp="$(jq -r '.tmp' <<<"$accepted")"
    ext="${tmp##*.}"; [[ "$ext" == "$tmp" ]] && ext="jpg"
    dest_rel="assets/${id}.${ext}"
    cp "$tmp" "$RD/$dest_rel"
    bytes="$(wc -c < "$RD/$dest_rel" | tr -d ' ')"
    src="$(jq -r '.source' <<<"$accepted")"
    entry="$(jq -nc \
      --arg id "$id" --argjson used "$used_json" --arg prompt "$PROMPT" \
      --argjson tw "$TW" --argjson th "$TH" \
      --arg src "$src" --arg lic "$(jq -r '.license' <<<"$accepted")" \
      --argjson attr "$(jq -c '.attribution' <<<"$accepted")" \
      --argjson score "$(jq -c '.judge_score' <<<"$accepted")" \
      --arg file "$dest_rel" \
      --argjson w "$(jq -r '.width // 0' <<<"$accepted")" --argjson h "$(jq -r '.height // 0' <<<"$accepted")" \
      --argjson bytes "$bytes" \
      '{slot_id:$id, used_in:$used, prompt:$prompt, target:{width:$tw,height:$th},
        source:$src, license:$lic, attribution:$attr, judge_score:$score,
        file:$file, width:$w, height:$h, bytes:$bytes}')"
    SLOT_ENTRIES+=("$entry")
    FILLED=$((FILLED+1)); BY_SOURCE[$src]=$(( ${BY_SOURCE[$src]:-0} + 1 ))
    echo "  ✓ $id → $src (Score $(jq -r '.judge_score // "—"' <<<"$accepted"), $dest_rel)"
  else
    rm -f "$ASSETS/${id}."* 2>/dev/null || true
    entry="$(jq -nc --arg id "$id" --argjson used "$used_json" --arg prompt "$PROMPT" \
      --argjson tw "$TW" --argjson th "$TH" \
      '{slot_id:$id, used_in:$used, prompt:$prompt, target:{width:$tw,height:$th},
        source:"placeholder", license:null, attribution:null, judge_score:null,
        file:null, width:null, height:null, bytes:null}')"
    SLOT_ENTRIES+=("$entry")
    PLACEHOLDER=$((PLACEHOLDER+1)); BY_SOURCE[placeholder]=$(( ${BY_SOURCE[placeholder]:-0} + 1 ))
    if [[ "$STOCK_ON" == true || "$WEBSITE_ON" == true || -n "$GEN_PROVIDER" ]]; then
      note "Slot '$id' blieb Platzhalter — keine Quelle lieferte einen Kandidaten ≥ Schwelle $THRESHOLD."
      echo "  · $id → Platzhalter (kein Kandidat ≥ $THRESHOLD)"
    else
      echo "  · $id → Platzhalter (keine Bildquelle aktiv, 0-€-Baseline)"
    fi
  fi
done

# ── Manifest + Bericht schreiben ────────────────────────────────────────────
slots_json="[]"; [[ ${#SLOT_ENTRIES[@]} -gt 0 ]] && slots_json="[$(IFS=,; echo "${SLOT_ENTRIES[*]}")]"
by_source_json="$(for k in "${!BY_SOURCE[@]}"; do jq -nc --arg k "$k" --argjson v "${BY_SOURCE[$k]}" '{($k):$v}'; done | jq -sc 'add // {}')"
notes_json="$(printf '%s\n' "${NOTES[@]:-}" | jq -R . | jq -sc 'map(select(length>0))')"

jq -n \
  --arg run_id "$(basename "$RUN_DIR")" \
  --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson threshold "$THRESHOLD" \
  --arg judge "$JUDGE_MODE" \
  --argjson stock "$STOCK_ON" --argjson website "$WEBSITE_ON" \
  --arg gen "${GEN_PROVIDER:-}" \
  --argjson slots "$slots_json" \
  --argjson filled "$FILLED" --argjson placeholder "$PLACEHOLDER" \
  --argjson by_source "$by_source_json" \
  --argjson notes "$notes_json" \
  '{run_id:$run_id, generated_at:$created, threshold:$threshold, judge:$judge,
    sources_available:{stock:$stock, website:$website, generation:($gen|if .=="" then null else . end)},
    slots:$slots,
    counts:{filled:$filled, placeholder:$placeholder, by_source:$by_source},
    notes:$notes}' > "$MANIFEST" || die "images-fill.json konnte nicht geschrieben werden."

{
  echo "# Bild-Befüllung (PROJ-20)"
  echo
  echo "- Lauf: \`$(basename "$RUN_DIR")\` · $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Quellen: Stock $([[ $STOCK_ON == true ]] && echo an || echo aus) · Website $([[ $WEBSITE_ON == true ]] && echo an || echo aus) · Generierung ${GEN_PROVIDER:-aus} · Judge $JUDGE_MODE (Schwelle $THRESHOLD)"
  echo "- Ergebnis: **$FILLED gefüllt**, $PLACEHOLDER Platzhalter"
  echo
  echo "| Slot | Quelle | Lizenz | Score | Attribution | Datei |"
  echo "|---|---|---|---|---|---|"
  for e in "${SLOT_ENTRIES[@]}"; do
    jq -r '"| \(.slot_id) | \(.source) | \(.license // "—") | \(.judge_score // "—") | \((.attribution.photographer // .attribution.source_url) // "—") | \(.file // "—") |"' <<<"$e"
  done
  if [[ ${#NOTES[@]} -gt 0 ]]; then
    echo; echo "## Vermerke"; for n in "${NOTES[@]}"; do [[ -n "$n" ]] && echo "- $n"; done
  fi
} > "$REPORT"

echo "✓ Bild-Befüllung fertig → $MANIFEST"
echo "  $FILLED gefüllt · $PLACEHOLDER Platzhalter · Bericht: $REPORT"

# ── Exit-Code ────────────────────────────────────────────────────────────────
if [[ "$PLACEHOLDER" -gt 0 && ( "$STOCK_ON" == true || "$WEBSITE_ON" == true || -n "$GEN_PROVIDER" ) ]]; then
  update_status "degraded" "Platzhalter-Reste trotz aktiver Quelle"
  exit 1
fi
if [[ ${#NOTES[@]} -gt 0 ]]; then update_status "degraded" ""; exit 1; fi
update_status "ok" ""
exit 0
