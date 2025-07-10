#!/usr/bin/env bash
set -euo pipefail

CACHE="$HOME/.cache/spotify_art"
STATE="$CACHE/last_url"
LINK="$CACHE/cover_art.png"
LOCK="$CACHE/lock"
mkdir -p "$CACHE"
touch "$LOCK"

# Get playback status
if pgrep -x spotify >/dev/null; then
  status=$(playerctl -p spotify status 2>/dev/null || echo "Stopped")
else
  status="Stopped"
fi

# Get position and length
pos_f=$(playerctl -p spotify position 2>/dev/null || echo 0)
len_us=$(playerctl -p spotify metadata --format '{{mpris:length}}' 2>/dev/null || echo 0)

# Convert length to seconds
len_s=$(( len_us / 1000000 ))

# Convert position to seconds
pos_s=${pos_f%.*}

format_time() {
  local total_sec=$1
  local min=$(( total_sec / 60 ))
  local sec=$(( total_sec % 60 ))
  printf "%d:%02d" "$min" "$sec"
}

timeline="$(format_time "$pos_s") / $(format_time "$len_s")"

# If stopped, use placeholder art
if [[ "$status" == "Stopped" ]]; then
  [[ -f "$LINK" ]] || magick -size 116x116 xc:grey "$LINK" 2>/dev/null || true
  art_url="$LINK"
  printf '%s\n' "{\"artUrl\":\"$art_url\",\"status\":\"$status\",\"timeline\":\"$timeline\"}"
  exit 0
fi

# Get album art URL
url=$(playerctl -p spotify metadata --format '{{mpris:artUrl}}' 2>/dev/null || echo "")

if [[ -z "$url" ]]; then
  [[ -f "$LINK" ]] || magick -size 116x116 xc:grey "$LINK" 2>/dev/null || true
  art_url="$LINK"
  printf '%s\n' "{\"artUrl\":\"$art_url\",\"status\":\"$status\",\"timeline\":\"$timeline\"}"
  exit 0
fi

# Normalize URL
if [[ $url == file://* ]]; then
  url=${url#file://}
elif [[ $url == *open.spotify.com* ]]; then
  url=${url/open.spotify.com\/image/i.scdn.co\/image}
  url=${url//\/spic\//\/image}
fi

last=""
[ -r "$STATE" ] && read -r last < "$STATE"

# Download cover art if needed
if [[ ("$url" != "$last" || ! -f "$LINK") && $url == http* ]]; then
  (
    flock -n 200 || exit 0
    if curl -fsL --max-time 5 "$url" | magick - -resize 116x116 "$LINK"; then
      echo "$url" > "$STATE"
    else
      magick -size 116x116 xc:grey "$LINK" 2>/dev/null || true
    fi
  ) 200>"$LOCK"
fi

art_url="$LINK"

# Output JSON
printf '%s\n' "{\"artUrl\":\"$art_url\",\"status\":\"$status\",\"timeline\":\"$timeline\"}"