#!/usr/bin/env bash

# Original Author: @JaKooLit

# WALLPAPERS PATH
DIR=$HOME/Pictures/wallpapers

# Transition config
FPS=30
TYPE="simple"
DURATION=2
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION"

# Collect all image files
PICS=($(ls "${DIR}" | grep -Ei "\.(jpg|jpeg|png|gif)$"))

# Random image fallback
RANDOM_PIC=${PICS[$RANDOM % ${#PICS[@]}]}
RANDOM_PIC_NAME="${#PICS[@]}. random"

# Fuzzel config
fuzzel_command="fuzzel --dmenu"

# Build menu
menu() {
    for i in "${!PICS[@]}"; do
        if [[ "${PICS[$i]}" =~ \.gif$ ]]; then
            echo "$i. ${PICS[$i]}"
        else
            echo "$i. $(basename "${PICS[$i]}" | cut -d. -f1)"
        fi
    done

    echo "$RANDOM_PIC_NAME"
}

main() {
    choice=$(menu | $fuzzel_command)

    # No choice
    if [[ -z "$choice" ]]; then return; fi

    # Random case
    if [[ "$choice" == "$RANDOM_PIC_NAME" ]]; then
        swww img "${DIR}/${RANDOM_PIC}" $SWWW_PARAMS
        return
    fi

    pic_index=$(echo "$choice" | cut -d. -f1)
    swww img "${DIR}/${PICS[$pic_index]}" $SWWW_PARAMS
}

main
