#!/usr/bin/env bash

detect_cwd() {
    local focused_pid shell_pid cwd
    focused_pid=$(niri msg windows | awk '/\(focused\)/ {found=1} found && /PID:/ {print $2; exit}')
    if [[ -n "$focused_pid" ]]; then
        shell_pid=$(pgrep -P "$focused_pid" -a | grep -m1 -E "bash|zsh|fish" | awk '{print $1}')
        [[ -n "$shell_pid" ]] && cwd=$(readlink -f "/proc/$shell_pid/cwd" 2>/dev/null)
        [[ -d "$cwd" ]] && echo "$cwd"
    fi
}

open_in_file_manager() {
    local path="$1"

    if command -v nautilus &>/dev/null; then
        nautilus --select "$path" &>/dev/null &
    elif command -v thunar &>/dev/null; then
        thunar "$path" &>/dev/null &
    elif command -v dolphin &>/dev/null; then
        dolphin --select "$path" &>/dev/null &
    elif command -v pcmanfm &>/dev/null; then
        pcmanfm --select "$path" &>/dev/null &
    else
        xdg-open "$(dirname "$path")" &>/dev/null &
    fi
}

search_root=$(detect_cwd)
[[ -z "$search_root" ]] && search_root="$HOME"

while true; do
    display_dir="${search_root/#$HOME/~}"

    # ——— 1) build shallow (depth-1) lists ———
    mapfile -t raw_dirs_all  < <(fd -H -t d -d 1 . "$search_root" 2>/dev/null)
    mapfile -t raw_files_all < <(fd -H -t f -d 1 . "$search_root" 2>/dev/null)

    # Separate visible and hidden
    visible=()
    hidden=()
    for item in "${raw_dirs_all[@]}" "${raw_files_all[@]}"; do
        base=$(basename "$item")
        [[ "$base" == .* ]] && hidden+=("$item") || visible+=("$item")
    done

    # Sort each group
    IFS=$'\n'
    sorted_visible=($(LC_COLLATE=C sort -f <<<"${visible[*]}"))
    sorted_hidden=($(LC_COLLATE=C sort -f <<<"${hidden[*]}"))
    unset IFS

    # Combine groups
    shallow_combined=( "${sorted_visible[@]}" "${sorted_hidden[@]}" )

    # add up-entries
    [[ "$search_root" != "/" ]] && shallow_combined=( "../" "${shallow_combined[@]}" )
    shallow_combined=( "~" "${shallow_combined[@]}" )

    # build a quick lookup set
    declare -A is_shallow
    for p in "${shallow_combined[@]}"; do is_shallow["$p"]=1; done

    # ——— 2) first dmenu prompt ———
    sel=$(printf '%s\n' "${shallow_combined[@]}" \
          | fuzzel --dmenu)

    [[ -z "$sel" ]] && exit 0

    # ——— 3) if user picked a shallow entry, handle it ———
    if [[ ${is_shallow["$sel"]} ]]; then
        case "$sel" in
            "~")
                search_root="$HOME"
                continue
                ;;
            "../")
                if [[ "$search_root" == "$HOME" ]]; then
                    search_root="/"
                else
                    search_root=$(dirname "$search_root")
                fi
                continue
                ;;
            *)
                if [[ -d "$sel" ]]; then
                    search_root="$sel"
                    continue
                else
                    open_in_file_manager "$sel"
                    exit 0
                fi
                ;;
        esac
    fi

    # ——— 4) otherwise the user typed “sel” as a pattern: do a recursive search ———
    pattern="$sel"
    IFS=' ' read -ra terms <<< "$pattern"

    # Start with fd command
    match_cmd="fd -HI -t d -t f --exclude '.cache' --exclude 'node_modules' . \"$search_root\""

    # Append a grep for each word
    for term in "${terms[@]}"; do
        match_cmd+=" | grep -i ${term@Q}"
    done

    # Run the composed pipeline
    mapfile -t matches < <(eval "$match_cmd" 2>/dev/null)

    ((${#matches[@]} == 0)) && { notify-send "No matches for ‘$pattern’"; continue; }

    # sort and present the matches
    IFS=$'\n' sorted_matches=($(LC_COLLATE=C sort <<<"${matches[*]}")) ; unset IFS
    sel2=$(printf '%s\n' "${sorted_matches[@]}" \
           | fuzzel --dmenu --prompt "Results for ‘$pattern’:")
    [[ -z "$sel2" ]] && continue

    # handle the recursive selection
    if [[ -d "$sel2" ]]; then
        search_root="$sel2"
        continue
    else
        open_in_file_manager "$sel2"
        exit 0
    fi
done
