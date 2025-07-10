#!/usr/bin/env bash

MRU_FILE="/tmp/niri_mru_order"
[[ ! -f "$MRU_FILE" ]] && touch "$MRU_FILE"

while true; do
  sleep 0.1

  focused_id=$(niri msg windows | awk '/^Window ID/ && /\(focused\)/ { print $3 }' | tr -d ':')

  [[ -z "$focused_id" ]] && continue

  mapfile -t mru_list < "$MRU_FILE"

  # Remove focused_id duplicates
  new_mru=()
  for id in "${mru_list[@]}"; do
    [[ "$id" != "$focused_id" ]] && new_mru+=("$id")
  done

  # Add new focused at front
  new_mru=("$focused_id" "${new_mru[@]}")

  # Get all open windows
  mapfile -t open_windows < <(niri msg windows | awk '/^Window ID/ { print $3 }' | tr -d ':')

  # Filter closed windows out of MRU
  filtered_mru=()
  for id in "${new_mru[@]}"; do
    if printf '%s\n' "${open_windows[@]}" | grep -qx "$id"; then
      filtered_mru+=("$id")
    fi
  done

  printf "%s\n" "${filtered_mru[@]}" > "$MRU_FILE"
done
