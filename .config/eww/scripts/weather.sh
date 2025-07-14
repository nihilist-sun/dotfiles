#!/usr/bin/env bash

ICON_DIR="$HOME/.config/eww/weather_icons"
# Oregon coast (Cannon Beach)
LAT=45.8918
LON=-123.9615

# Big Sur, California
#LAT=36.2704
#LON=-121.8070

# Hawaii (Maui, near Lahaina)
#LAT=20.8677
#LON=-156.6171

# Utah (Salt Lake City)
#LAT=40.7608
#LON=-111.8910

# API User-Agent (app & contact)
USER_AGENT="weather-script/1.0 (yourname@example.com)"

# Get station URL and ID
GRID_JSON=$(curl -s -H "User-Agent: $USER_AGENT" "https://api.weather.gov/points/${LAT},${LON}")
STATIONS_URL=$(jq -r '.properties.observationStations' <<<"$GRID_JSON")
STATION_ID=$(curl -s -H "User-Agent: $USER_AGENT" "$STATIONS_URL" | jq -r '.features[0].properties.stationIdentifier')

# Fetch latest observation JSON
OBS_JSON=$(curl -s -H "User-Agent: $USER_AGENT" "https://api.weather.gov/stations/${STATION_ID}/observations/latest")

# Extract timestamps
OBS_TIME_UTC=$(jq -r '.properties.timestamp // empty' <<<"$OBS_JSON")
OBS_TIME_LOCAL=$(date -d "$OBS_TIME_UTC" '+%Y-%m-%d %I:%M %p %Z')

# Hourly forecast fallback
HOURLY_JSON=""

# Convert temp C→F, fallback
TEMP_C=$(jq -r '.properties.temperature.value // empty' <<<"$OBS_JSON")
if [[ -n "$TEMP_C" ]]; then
    TEMP=$(awk -v c="$TEMP_C" 'BEGIN { printf "%.0f", c * 9/5 + 32 }')
else
    FORECAST_URL_HOURLY=$(jq -r '.properties.forecastHourly' <<<"$GRID_JSON")
    HOURLY_JSON=$(curl -s -H "User-Agent: $USER_AGENT" "$FORECAST_URL_HOURLY")
    TEMP_F=$(jq -r '.properties.periods[0].temperature // empty' <<<"$HOURLY_JSON")
    TEMP=$(printf "%.0f" "$TEMP_F")
fi

# Get humidity, fallback
HUMIDITY_RAW=$(jq -r '.properties.relativeHumidity.value // empty' <<<"$OBS_JSON")
if [[ -z "$HUMIDITY_RAW" || "$HUMIDITY_RAW" == "null" ]]; then
    [[ -z "$HOURLY_JSON" ]] && HOURLY_JSON=$(curl -s -H "User-Agent: $USER_AGENT" "$(jq -r '.properties.forecastHourly' <<<"$GRID_JSON")")
    HUMIDITY_RAW=$(jq -r '.properties.periods[0].relativeHumidity.value // empty' <<<"$HOURLY_JSON")
fi
if [[ -n "$HUMIDITY_RAW" && "$HUMIDITY_RAW" != "null" ]]; then
    HUMIDITY=$(awk -v h="$HUMIDITY_RAW" 'BEGIN { printf "%.0f", h }')
else
    HUMIDITY="N/A"
fi

# Determine condition from station or forecast
CONDITION=$(jq -r '
  if (.properties.presentWeather | length) > 0 then
    .properties.presentWeather[0].weather
  else
    .properties.textDescription
  end
  // .properties.rawMessage
  // empty' <<<"$OBS_JSON")

# Fallback to forecast shortForecast if empty
if [[ -z "$CONDITION" ]]; then
  FORECAST_JSON=$(curl -s -H "User-Agent: $USER_AGENT" "$(jq -r '.properties.forecast' <<<"$GRID_JSON")")
  CONDITION=$(jq -r '.properties.periods[0].shortForecast // empty' <<<"$FORECAST_JSON")
fi

# Day/night via sunrise/sunset
FORECAST_URL=$(jq -r '.properties.forecast' <<<"$GRID_JSON")
FORECAST_JSON=$(curl -s -H "User-Agent: $USER_AGENT" "$FORECAST_URL")
SUNRISE=$(jq -r '.properties.periods[0].sunriseTime // empty' <<<"$FORECAST_JSON")
SUNSET=$(jq -r '.properties.periods[0].sunsetTime // empty' <<<"$FORECAST_JSON")

if [[ -n "$SUNRISE" && -n "$SUNSET" ]]; then
    NOW=$(date --iso-8601=seconds)
    if [[ "$NOW" > "$SUNRISE" && "$NOW" < "$SUNSET" ]]; then
        IS_DAY=1
    else
        IS_DAY=0
    fi
else
    HOUR=$(date +%H)
    (( 6 <= HOUR && HOUR < 21 )) && IS_DAY=1 || IS_DAY=0
fi

# Choose icon based on condition
COND_NORM=$(echo "$CONDITION" | tr '[:upper:]' '[:lower:]' | sed 's/  */ /g')
case "$COND_NORM" in
    *thunderstorm*|*t-storm*) ICON="cloud-bolt.svg" ;;
    *rain*|*drizzle*|*showers*) ICON="cloud-rain.svg" ;;
    *snow*|*flurries*|*sleet*|*ice*) ICON="snowflakes.svg" ;;
    *fog*|*haze*) ICON="cloud-fog.svg" ;;
    *partly\ cloudy*|*few\ clouds*|*mostly\ sunny*|*partly\ sunny*|*fair*) ICON=$([ $IS_DAY -eq 1 ] && echo "cloud-sun.svg" || echo "cloud-moon.svg") ;;
    *cloudy*|*overcast*|*mostly\ cloudy*) ICON="cloud.svg" ;;
    *sunny*|*clear*) ICON=$([ $IS_DAY -eq 1 ] && echo "sun.svg" || echo "moon-stars.svg") ;;
    *) ICON=$([ $IS_DAY -eq 1 ] && echo "sun.svg" || echo "moon-stars.svg") ;;
esac

# Moon phase bar (original)
MOON_NUM=$(curl -s "https://wttr.in/?format=%M" | tr -d '\r')
if (( MOON_NUM == 0 )); then
    MOON_PHASE="New Moon"; INDEX=0
elif (( MOON_NUM >= 1 && MOON_NUM <= 6 )); then
    MOON_PHASE="Waxing Crescent"; INDEX=1
elif (( MOON_NUM == 7 )); then
    MOON_PHASE="First Quarter"; INDEX=2
elif (( MOON_NUM >= 8 && MOON_NUM <= 13 )); then
    MOON_PHASE="Waxing Gibbous"; INDEX=3
elif (( MOON_NUM == 14 )); then
    MOON_PHASE="Full Moon"; INDEX=4
elif (( MOON_NUM >= 15 && MOON_NUM <= 20 )); then
    MOON_PHASE="Waning Gibbous"; INDEX=5
elif (( MOON_NUM == 21 )); then
    MOON_PHASE="Last Quarter"; INDEX=6
elif (( MOON_NUM >= 22 && MOON_NUM <= 27 )); then
    MOON_PHASE="Waning Crescent"; INDEX=7
else
    MOON_PHASE="Unknown"; INDEX=-1
fi

PHASES=("New Moon" "Waxing Crescent" "First Quarter" "Waxing Gibbous" "Full Moon" "Waning Gibbous" "Last Quarter" "Waning Crescent")
ICONS=("󰽤 " "󰽧" "󰽡" "󰽨" "󰽢 " "󰽦" "󰽣" "󰽥")
MOON_BAR=""
for i in "${!PHASES[@]}"; do
    if [[ $i -eq $INDEX ]]; then color="#d8a657"; else color="#504945"; fi
    MOON_BAR+="<span foreground=\"$color\">${ICONS[$i]}</span>"
    [[ $i -lt 7 ]] && MOON_BAR+=" "
done

# Output by argument
case "$1" in
  temp)      printf "%s°
" "$TEMP" ;;  
  humidity)  printf "%s%%
" "$HUMIDITY" ;;  
  condition) printf "%s
" "$CONDITION" ;;  
  icon)      printf "%s
" "$ICON_DIR/$ICON" ;;  
  humicon)   printf "%s
" "$ICON_DIR/custom-humidity.svg" ;;  
  moon)      printf "%s
" "$MOON_BAR" ;;  
  coords)    printf "%.6f,%.6f
" "$LAT" "$LON" ;;  
  debug)
      echo "Station ID:       $STATION_ID"
      echo "Observation Time: $OBS_TIME_UTC (UTC)"
      echo "Local Time:       $OBS_TIME_LOCAL"
      echo "Condition:        $CONDITION"
      echo "Temp:             $TEMP°F"
      echo "Humidity:         $HUMIDITY%"
      echo "Daytime:          $IS_DAY"
      echo "Icon selected:    $ICON"
      echo "Moon Phase:       '$MOON_PHASE'"
      echo "Moon Bar:         $MOON_BAR"
      ;;  
  *)         printf "%s
" "$CONDITION" ;;  
esac
