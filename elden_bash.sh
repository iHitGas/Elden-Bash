#!/usr/bin/env bash
# ELDEN BASH — A Bash Souls-like Adventure
# Main entry point

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/lib/items.sh"
source "${SCRIPT_DIR}/lib/player.sh"
source "${SCRIPT_DIR}/lib/enemies.sh"
source "${SCRIPT_DIR}/lib/combat.sh"
source "${SCRIPT_DIR}/lib/save.sh"
source "${SCRIPT_DIR}/lib/world.sh"

check_requirements() {
    if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        printf "Error: Bash 4.0+ required (you have %s)\n" "$BASH_VERSION" >&2
        exit 1
    fi
}

character_creation() {
    clear
    draw_title_banner
    printf "\n"

    print_msg lore "You are Tarnished — stripped of grace, exiled from the Lands Between."
    print_msg lore "Now grace calls you back. Rise, and claim the Elden Ring."
    printf "\n"
    press_key

    # Name
    clear
    printf "\n${GOLD}${BOLD}  CHARACTER CREATION${NC}\n\n"
    printf "  ${WHITE}Enter your name, Tarnished:${NC} "
    local player_name
    read -r player_name
    [ -z "$player_name" ] && player_name="Tarnished"

    # Class
    clear
    printf "\n${GOLD}${BOLD}  CHOOSE YOUR CLASS${NC}\n\n"
    printf "  ${YELLOW}Vagabond${NC}  — Balanced warrior. Longsword and medium armor. STR/DEX focus.\n"
    printf "  ${YELLOW}Warrior${NC}   — Raw strength build. Battle axe, heavy armor. STR focus.\n"
    printf "  ${YELLOW}Prophet${NC}   — Magic wielder. Glintstone Staff. INT/FAI with starting spells.\n"
    printf "  ${YELLOW}Wretch${NC}    — Nothing. A club and bare skin. Equal stats. True challenge.\n\n"

    local class_choice
    class_choice=$(ask_menu "Choose your origin:" \
        "Vagabond  (Recommended)" \
        "Warrior   (Tanky, high damage)" \
        "Prophet   (Sorcery build)" \
        "Wretch    (Hardest — start with nothing)")

    local class_id
    case "$class_choice" in
        1) class_id="vagabond" ;;
        2) class_id="warrior" ;;
        3) class_id="prophet" ;;
        4) class_id="wretch" ;;
        *) class_id="vagabond" ;;
    esac

    init_player "$class_id" "$player_name"

    # Opening lore
    clear
    printf "\n\n"
    sleep 0.3
    animate_text "  The Elden Ring was shattered." 0.04 "$GRAY"
    sleep 0.8
    animate_text "  Its shards, the Great Runes, were claimed by the demigods." 0.04 "$GRAY"
    sleep 0.8
    animate_text "  War followed. The Shattering." 0.04 "$DARK"
    sleep 0.8
    animate_text "  Now you, ${player_name}, are called by grace to restore what was broken." 0.04 "$GOLD"
    sleep 1.5
    printf "\n"
    press_key

    # Tutorial fight
    clear
    printf "\n${BLOOD}${BOLD}  WARNING: A GRAFTED SCION DESCENDS!${NC}\n"
    printf "\n${GRAY}  A horrific grafted creature blocks your path.\n"
    printf "  This fight introduces combat. You will likely die — and that's okay.\n\n${NC}"
    printf "  ${DIM}Tip: Light attacks cost less stamina. Guard halves damage taken.${NC}\n\n"
    press_key

    run_combat "grafted_scion"
    local intro_result="$COMBAT_RESULT"

    if [ "$intro_result" = "lose" ]; then
        clear
        printf "\n\n"
        sleep 0.5
        animate_text "  ...You awaken in the Stranded Graveyard." 0.04 "$GRAY"
        sleep 0.8
        animate_text "  Defeated, but not yet dead. Grace has guided you here." 0.04 "$GOLD"
        sleep 1
        PLAYER[hp]="${PLAYER[max_hp]}"
        PLAYER[fp]="${PLAYER[max_fp]}"
        PLAYER[stamina]="${PLAYER[max_stamina]}"
        PLAYER[deaths]=0
        PLAYER[runes]=0
        PLAYER[runes_on_ground]=0
        printf "\n"
        press_key
    else
        printf "\n"
        print_msg gold "Remarkable. You've bested the Grafted Scion. Grace shines bright upon you."
        press_key
    fi

    enter_area "stranded_graveyard"
}

main_menu() {
    while true; do
        draw_title_banner

        # Build options dynamically based on save existence
        local opts=("New Game")
        local has_saves=0
        if any_save_exists; then
            opts+=("Continue" "Load Game")
            has_saves=1
        fi
        opts+=("Quit")

        # Quit is always last option
        local quit_idx=$(( ${#opts[@]} ))

        local choice
        choice=$(ask_menu "Main Menu" "${opts[@]}")

        [[ "$choice" =~ ^[0-9]+$ ]] || continue

        if [ "$choice" -eq 1 ]; then
            character_creation
            game_loop
        elif [ "$has_saves" -eq 1 ] && [ "$choice" -eq 2 ]; then
            # Continue: try slot 1, fall back to load menu
            if load_game 1 2>/dev/null; then
                print_msg good "Continued from slot 1."
                press_key
                game_loop
            else
                if load_menu; then
                    game_loop
                fi
            fi
        elif [ "$has_saves" -eq 1 ] && [ "$choice" -eq 3 ]; then
            if load_menu; then
                game_loop
            fi
        elif [ "$choice" -eq "$quit_idx" ]; then
            clear
            printf "\n  ${GRAY}May grace guide thee, Tarnished.${NC}\n\n"
            exit 0
        fi
    done
}

game_loop() {
    while true; do
        area_menu
    done
}

check_requirements
main_menu
