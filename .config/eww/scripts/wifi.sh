#!/bin/bash

# Signal strength from env or fallback
signal="${1:-100}"

hour=$(date +%H)
minute=$(date +%M)

# If it's 4:20 (AM or PM), show the weed icon
if [[ "$hour" == "04" || "$hour" == "16" ]] && [[ "$minute" == "20" ]]; then
  echo ""
else
  if nmcli radio wifi | grep -q "disabled"; then
    echo ""
  elif [[ "$signal" -lt 25 ]]; then
    echo ""
  elif [[ "$signal" -lt 75 ]]; then
    echo ""
  else
    echo ""
  fi
fi
