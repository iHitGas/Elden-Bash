#!/usr/bin/env bash
# Save/load system

SAVE_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../saves"

save_game() {
    local slot="${1:-1}"
    local save_file="${SAVE_DIR}/save_${slot}.dat"
    mkdir -p "$SAVE_DIR"
    {
        for key in "${!PLAYER[@]}"; do
            printf "%s=%s\n" "$key" "${PLAYER[$key]}"
        done
    } > "$save_file"
    print_msg good "Game saved to slot ${slot}."
}

load_game() {
    local slot="${1:-1}"
    local save_file="${SAVE_DIR}/save_${slot}.dat"
    if [ ! -f "$save_file" ]; then
        print_msg warn "No save found in slot ${slot}."
        return 1
    fi

    # Clear and reload player
    for key in "${!PLAYER[@]}"; do
        unset "PLAYER[$key]"
    done

    while IFS='=' read -r key value; do
        [ -n "$key" ] && PLAYER["$key"]="$value"
    done < "$save_file"

    print_msg good "Game loaded from slot ${slot}."
    return 0
}

list_saves() {
    printf "\n${GOLD}  Save Slots:${NC}\n"
    for slot in 1 2 3; do
        local save_file="${SAVE_DIR}/save_${slot}.dat"
        if [ -f "$save_file" ]; then
            local name level loc
            name=$(grep '^name=' "$save_file" | cut -d= -f2)
            level=$(grep '^level=' "$save_file" | cut -d= -f2)
            loc=$(grep '^location_name=' "$save_file" | cut -d= -f2-)
            printf "  ${CYAN}[%d]${NC} %s  Lv.%s  @ %s\n" "$slot" "$name" "$level" "$loc"
        else
            printf "  ${DARK}[%d] Empty${NC}\n" "$slot"
        fi
    done
    echo
}

save_menu() {
    list_saves
    local choice
    choice=$(ask_menu "Save to which slot? (1-3, 0=cancel)" "Slot 1" "Slot 2" "Slot 3" "Cancel")
    case "$choice" in
        1|2|3) save_game "$choice" ;;
        4|0|*) print_msg info "Save cancelled." ;;
    esac
    press_key
}

load_menu() {
    list_saves
    local choice
    choice=$(ask_menu "Load from which slot? (0=cancel)" "Slot 1" "Slot 2" "Slot 3" "Cancel")
    case "$choice" in
        1|2|3)
            if load_game "$choice"; then
                return 0
            else
                press_key
                return 1
            fi
            ;;
        *) return 1 ;;
    esac
}

any_save_exists() {
    for slot in 1 2 3; do
        [ -f "${SAVE_DIR}/save_${slot}.dat" ] && return 0
    done
    return 1
}
