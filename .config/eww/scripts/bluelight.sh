#!/usr/bin/env bash
STATUS_FILE="/tmp/gammastep-active"

toggle_filter() {
  if pgrep -x "gammastep" > /dev/null; then
    # Deactivate
    pkill -x "gammastep"
    echo "off" > "$STATUS_FILE"
  else
    # Activate with night temperature (4500K)
    gammastep -O 4500 &
    echo "on" > "$STATUS_FILE"
  fi
}

get_status() { cat "$STATUS_FILE" 2>/dev/null || echo "off"; }

case "$1" in
  "--toggle") toggle_filter ;;
  "--status") get_status ;;
  *) echo "Invalid option"; exit 1 ;;
esac
