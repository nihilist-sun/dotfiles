#!/usr/bin/env bash

hour=$(date +%H)
minute=$(date +%M)
if [[ "$hour" == "04" || "$hour" == "16" ]] && [[ "$minute" == "20" ]]; then
  printf ""
  exit
fi

if ! nmcli radio wifi | grep -q "enabled"; then
  printf ""
  exit
fi

signal=$(nmcli -t -f IN-USE,SIGNAL dev wifi list --rescan no \
         | awk -F: '$1 == "*" { print $2 }')

signal=${signal:-0}

if (( signal < 25 )); then
  printf ""
elif (( signal < 75 )); then
  printf ""
else
  printf ""
fi
