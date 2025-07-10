#!/usr/bin/env bash

choices=()
declare -A sink_map  # To map descriptions to sink IDs

while read -r line; do
  sink_id=$(echo "$line" | awk '{print $1}')
  description=$(pactl list sinks | grep -A20 "Sink #$sink_id" | grep "Description:" | head -n1 | cut -d ':' -f2- | sed 's/^[ \t]*//')
  
  # Store in array and map description to sink_id
  choices+=("$description")
  sink_map["$description"]=$sink_id
done < <(pactl list short sinks)

if [[ ${#choices[@]} -eq 0 ]]; then
  echo "No audio sinks found!"
  exit 1
fi

# Display choices without IDs
selection=$(printf '%s\n' "${choices[@]}" | fuzzel --dmenu -p "Select Audio Output:")

if [[ -z "$selection" ]]; then
  echo "No sink selected, aborting"
  exit 1
fi

# Get the sink ID from our mapping
sink_id=${sink_map["$selection"]}

pactl set-default-sink "$sink_id"

# Move all streams to the new sink
while read -r stream; do
  pactl move-sink-input "$stream" "$sink_id"
done < <(pactl list short sink-inputs | awk '{print $1}')

notify-send "Audio output switched to $selection"