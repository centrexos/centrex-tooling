#!/usr/bin/env bash
# Generate a new cxpkg metadata entry interactively
# Usage: ./gen-package.sh [category-file]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
META_DIR="$ROOT_DIR/metadata/packages"

info()  { echo -e "\033[1;34m[gen-pkg]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[gen-pkg]\033[0m $*"; }
prompt(){ read -rp "  $1: " "$2"; }

CATEGORY_FILE="${1:-}"
if [[ -z "$CATEGORY_FILE" ]]; then
    echo "Available categories:"
    ls "$META_DIR/"*.json | xargs -I{} basename {} .json | nl
    prompt "Category file (e.g. dev, browsers, core)" CATEGORY_FILE
fi

OUTPUT="$META_DIR/${CATEGORY_FILE}.json"
[[ -f "$OUTPUT" ]] || echo "{}" > "$OUTPUT"

info "Adding new package to $OUTPUT"
prompt "Logical name (e.g. vscode)"       PKG_NAME
prompt "APT package name (or blank)"      APT_NAME
prompt "DNF package name (or blank)"      DNF_NAME
prompt "Flatpak application ID (or blank)" FP_NAME
prompt "Short description"                DESCRIPTION
prompt "Category (browser/editor/dev/…)"  CATEGORY
prompt "Aliases (space-separated, blank for none)" ALIASES_STR

# Build aliases JSON array
ALIASES_JSON="[]"
if [[ -n "$ALIASES_STR" ]]; then
    ALIASES_JSON=$(echo "$ALIASES_STR" | tr ' ' '\n' | jq -R . | jq -s .)
fi

APT_VAL=$(  [[ -n "$APT_NAME" ]] && echo "\"$APT_NAME\"" || echo "null")
DNF_VAL=$(  [[ -n "$DNF_NAME" ]] && echo "\"$DNF_NAME\"" || echo "null")
FP_VAL=$(   [[ -n "$FP_NAME"  ]] && echo "\"$FP_NAME\""  || echo "null")

# Merge into existing JSON
ENTRY=$(jq -n \
    --arg apt  "$APT_NAME" \
    --arg dnf  "$DNF_NAME" \
    --arg fp   "$FP_NAME" \
    --arg desc "$DESCRIPTION" \
    --arg cat  "$CATEGORY" \
    --argjson aliases "$ALIASES_JSON" \
    '{
      apt:     (if $apt  == "" then null else $apt  end),
      dnf:     (if $dnf  == "" then null else $dnf  end),
      flatpak: (if $fp   == "" then null else $fp   end),
      aliases: $aliases,
      description: $desc,
      category: $cat,
      tags: []
    }'
)

# Inject into file
TMP=$(mktemp)
jq --arg key "$PKG_NAME" --argjson val "$ENTRY" '. + {($key): $val}' "$OUTPUT" > "$TMP"
mv "$TMP" "$OUTPUT"

ok "Added '$PKG_NAME' to $OUTPUT"
