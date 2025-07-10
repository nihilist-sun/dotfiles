#!/usr/bin/env bash

MRU_FILE="/tmp/niri_mru_order"

# --- Function: Get all current Firefox window IDs ---
get_firefox_windows() {
  declare -A windows

  while read -r line; do
    if [[ "$line" =~ ^Window\ ID\ ([0-9]+): ]]; then
      id="${BASH_REMATCH[1]}"
      app=""
    elif [[ "$line" =~ App\ ID:\ \"(.*)\" ]]; then
      app="${BASH_REMATCH[1]}"
      if [[ "$app" == "firefox" ]]; then
        windows["$id"]=1
      fi
    fi
  done < <(niri msg windows)

  for id in "${!windows[@]}"; do
    echo "$id"
  done
}

# --- STEP 1: Choose mode or type query directly ---
input=$(printf "New window\nPrivate window" | fuzzel --dmenu)
[ -z "$input" ] && exit 0

case "$input" in
  "New window"|"Private window")
    mode="$input"
    query=$(fuzzel --dmenu -p "Google Search:")
    [ -z "$query" ] && exit 0
    ;;
  *)
    mode="New tab"  # Implicit default
    query="$input"
    ;;
esac

# --- STEP 2: Prepare Google search URL ---
url="https://www.google.com/search?q=$(printf '%s' "$query" | jq -s -R -r @uri)"

# --- STEP 3: Get Firefox window IDs before launch ---
before_ids=($(get_firefox_windows))

# --- STEP 4: Launch Firefox ---
case "$mode" in
  "New tab")
    firefox --new-tab "$url" &
    ;;
  "New window")
    firefox --new-window "$url" &
    ;;
  "Private window")
    firefox --private-window "$url" &
    ;;
esac

# --- STEP 5: Wait for new window to appear ---
sleep 1.2

# --- STEP 6: Get Firefox window IDs after launch ---
after_ids=($(get_firefox_windows))

# --- STEP 7: Find new window ID ---
new_id=""
for id in "${after_ids[@]}"; do
  if ! [[ " ${before_ids[*]} " =~ " $id " ]]; then
    new_id="$id"
    break
  fi
done

# --- STEP 8: Focus new Firefox window if found ---
if [[ -n "$new_id" ]]; then
  niri msg action focus-window --id "$new_id"
fi
