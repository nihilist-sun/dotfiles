#!/usr/bin/env bash

MRU_FILE="/tmp/niri_mru_order"
[[ ! -f "$MRU_FILE" ]] && echo "MRU file missing" && exit 1

declare -A ID_TO_DESC
declare -A DESC_TO_ID

# Parse current windows
while read -r line; do
  if [[ "$line" =~ ^Window\ ID\ ([0-9]+): ]]; then
    id="${BASH_REMATCH[1]}"
    app=""
    title=""
  elif [[ "$line" =~ Title:\ \"(.*)\" ]]; then
    title="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ App\ ID:\ \"(.*)\" ]]; then
    app="${BASH_REMATCH[1]}"
    desc="${app} — ${title}"

    ID_TO_DESC["$id"]="$desc"
    DESC_TO_ID["$desc"]="$id"
  fi
done < <(niri msg windows)

# Get list of all currently open window IDs
current_ids=("${!ID_TO_DESC[@]}")

# Read MRU file into array
mapfile -t mru_ids < "$MRU_FILE"

# Build the list for the menu, starting with MRU windows that are currently open
menu=()
added_ids=()

for id in "${mru_ids[@]}"; do
  if [[ -n "${ID_TO_DESC[$id]}" ]]; then
    desc="${ID_TO_DESC[$id]}"
    app="${desc%% — *}"

    # Smart normalization: lowercase only if no dots
    if [[ "$app" == *.* ]]; then
      icon_name="$app"
    else
      icon_name="$(echo "$app" | tr '[:upper:]' '[:lower:]')"
    fi

    menu+=("${desc}\x00icon\x1f${icon_name}")
    added_ids+=("$id")
  fi
done

# Append any currently open windows not already in MRU list
for id in "${current_ids[@]}"; do
  if ! [[ " ${added_ids[*]} " =~ " $id " ]]; then
    desc="${ID_TO_DESC[$id]}"
    app="${desc%% — *}"

    if [[ "$app" == *.* ]]; then
      icon_name="$app"
    else
      icon_name="$(echo "$app" | tr '[:upper:]' '[:lower:]')"
    fi

    menu+=("${desc}\x00icon\x1f${icon_name}")
    added_ids+=("$id")
  fi
done

# Show menu and get selection
selection=$(printf "%b\n" "${menu[@]}" | fuzzel --dmenu)

# Focus window if selection is not empty
if [[ -n "$selection" ]]; then
  # fuzzel strips the icon metadata, so we just use the plain desc
  win_id="${DESC_TO_ID[$selection]}"
  [[ -n "$win_id" ]] && niri msg action focus-window --id "$win_id"
fi
