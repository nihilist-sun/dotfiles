#!/usr/bin/env bash

signal=$(nmcli -t -f ACTIVE,SIGNAL dev wifi | awk -F: '$1 == "yes" { print $2 }')

hour=$(date +%H)
minute=$(date +%M)

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
