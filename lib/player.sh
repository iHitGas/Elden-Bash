#!/usr/bin/env bash
# Player state, creation, leveling

declare -A PLAYER

# Level-up costs (runes required)
level_up_cost() {
    local level="$1"
    # Roughly: 300 * level^1.5
    echo $(( 300 * level * level / 10 + level * 50 ))
}

init_player() {
    local class="$1"
    local name="$2"

    PLAYER[name]="$name"
    PLAYER[level]=1
    PLAYER[runes]=0
    PLAYER[runes_on_ground]=0
    PLAYER[rune_location]=""
    PLAYER[deaths]=0
    PLAYER[kills]=0

    PLAYER[location]="stranded_graveyard"
    PLAYER[location_name]="Stranded Graveyard"
    PLAYER[area_progress]="000000000"  # 9 areas, 0=locked 1=available 2=complete

    PLAYER[str_buff]=0
    PLAYER[def_buff]=0
    PLAYER[is_dodging]=0
    PLAYER[is_guarding]=0

    # Spells: space-separated list of spell IDs
    PLAYER[spells]=""

    case "$class" in
        vagabond)
            PLAYER[class]="Vagabond"
            PLAYER[vig]=15; PLAYER[end]=11; PLAYER[str]=12
            PLAYER[dex]=9;  PLAYER[int]=6;  PLAYER[fai]=9
            PLAYER[weapon]="longsword"
            PLAYER[armor]="vagabond_set"
            PLAYER[inventory]="short_sword:1"
            PLAYER[crimson_flasks]=3
            PLAYER[cerulean_flasks]=0
            ;;
        warrior)
            PLAYER[class]="Warrior"
            PLAYER[vig]=11; PLAYER[end]=12; PLAYER[str]=16
            PLAYER[dex]=12; PLAYER[int]=5;  PLAYER[fai]=8
            PLAYER[weapon]="battle_axe"
            PLAYER[armor]="soldier_set"
            PLAYER[inventory]="scimitar:1 rowa_raisin:2"
            PLAYER[crimson_flasks]=3
            PLAYER[cerulean_flasks]=0
            ;;
        prophet)
            PLAYER[class]="Prophet"
            PLAYER[vig]=10; PLAYER[end]=8;  PLAYER[str]=8
            PLAYER[dex]=8;  PLAYER[int]=16; PLAYER[fai]=14
            PLAYER[weapon]="magic_staff"
            PLAYER[armor]="raya_lucaria"
            PLAYER[inventory]="dagger:1 starlight_shards:2"
            PLAYER[spells]="glintstone_pebble glintstone_arc"
            PLAYER[crimson_flasks]=2
            PLAYER[cerulean_flasks]=2
            ;;
        wretch)
            PLAYER[class]="Wretch"
            PLAYER[vig]=10; PLAYER[end]=10; PLAYER[str]=10
            PLAYER[dex]=10; PLAYER[int]=10; PLAYER[fai]=10
            PLAYER[weapon]="club"
            PLAYER[armor]="no_armor"
            PLAYER[inventory]=""
            PLAYER[crimson_flasks]=3
            PLAYER[cerulean_flasks]=0
            ;;
    esac

    recalc_player_stats
}

recalc_player_stats() {
    # Max HP: base 300 + vig*20
    PLAYER[max_hp]=$(( 300 + PLAYER[vig] * 20 ))
    # Max FP: base 50 + int*8 + fai*4
    PLAYER[max_fp]=$(( 50 + PLAYER[int] * 8 + PLAYER[fai] * 4 ))
    # Max Stamina: base 80 + end*6
    PLAYER[max_stamina]=$(( 80 + PLAYER[end] * 6 ))

    # Only set current values if not already set (on init)
    [ -z "${PLAYER[hp]+x}" ] && PLAYER[hp]="${PLAYER[max_hp]}"
    [ -z "${PLAYER[fp]+x}" ] && PLAYER[fp]="${PLAYER[max_fp]}"
    [ -z "${PLAYER[stamina]+x}" ] && PLAYER[stamina]="${PLAYER[max_stamina]}"

    # Clamp current to max
    [ "${PLAYER[hp]}" -gt "${PLAYER[max_hp]}" ] && PLAYER[hp]="${PLAYER[max_hp]}"
    [ "${PLAYER[fp]}" -gt "${PLAYER[max_fp]}" ] && PLAYER[fp]="${PLAYER[max_fp]}"
    [ "${PLAYER[stamina]}" -gt "${PLAYER[max_stamina]}" ] && PLAYER[stamina]="${PLAYER[max_stamina]}"
}

full_heal_player() {
    recalc_player_stats
    PLAYER[hp]="${PLAYER[max_hp]}"
    PLAYER[fp]="${PLAYER[max_fp]}"
    PLAYER[stamina]="${PLAYER[max_stamina]}"
}

show_player_stats() {
    clear
    printf "\n${GOLD}${BOLD}  ═══ CHARACTER ═══${NC}\n\n"
    printf "  ${WHITE}Name:${NC}  %s   ${WHITE}Class:${NC} %s   ${WHITE}Level:${NC} %d\n\n" \
        "${PLAYER[name]}" "${PLAYER[class]}" "${PLAYER[level]}"
    printf "  ${BLOOD}VIG${NC} %2d  │  ${LGREEN}END${NC} %2d  │  ${LRED}STR${NC} %2d\n" \
        "${PLAYER[vig]}" "${PLAYER[end]}" "${PLAYER[str]}"
    printf "  ${CYAN}DEX${NC} %2d  │  ${LBLUE}INT${NC} %2d  │  ${YELLOW}FAI${NC} %2d\n\n" \
        "${PLAYER[dex]}" "${PLAYER[int]}" "${PLAYER[fai]}"
    printf "  ${BLOOD}HP${NC}  %d/%d\n" "${PLAYER[hp]}" "${PLAYER[max_hp]}"
    printf "  ${BLUE}FP${NC}  %d/%d\n" "${PLAYER[fp]}" "${PLAYER[max_fp]}"
    printf "  ${GREEN}STA${NC} %d/%d\n\n" "${PLAYER[stamina]}" "${PLAYER[max_stamina]}"

    local weapon_dmg
    weapon_dmg=$(calc_weapon_damage "${PLAYER[weapon]}" "${PLAYER[str]}" "${PLAYER[dex]}" "${PLAYER[int]}")
    printf "  ${LRED}Attack:${NC}  %d (with %s)\n" "$weapon_dmg" "$(weapon_name "${PLAYER[weapon]}")"
    printf "  ${LBLUE}Defense:${NC} %d (with %s)\n\n" "$(armor_phys "${PLAYER[armor]}")" "$(armor_name "${PLAYER[armor]}")"

    if [ -n "${PLAYER[spells]}" ]; then
        printf "  ${CYAN}Known Spells:${NC}\n"
        for sp in ${PLAYER[spells]}; do
            printf "    ${LBLUE}• %s${NC} (FP: %d, DMG: %d)\n" \
                "$(spell_name "$sp")" "$(spell_fp "$sp")" "$(spell_dmg "$sp")"
        done
        echo
    fi

    local next_cost
    next_cost=$(level_up_cost "${PLAYER[level]}")
    printf "  ${GOLD}Runes: %d${NC}   Next level: %d runes\n\n" \
        "${PLAYER[runes]}" "$next_cost"

    printf "  ${DARK}Deaths: %d   Kills: %d${NC}\n\n" "${PLAYER[deaths]}" "${PLAYER[kills]}"
    press_key
}

try_level_up() {
    local cost
    cost=$(level_up_cost "${PLAYER[level]}")
    if [ "${PLAYER[runes]}" -lt "$cost" ]; then
        print_msg warn "Need $cost runes to level up. You have ${PLAYER[runes]}."
        press_key
        return 1
    fi

    PLAYER[runes]=$(( PLAYER[runes] - cost ))
    PLAYER[level]=$(( PLAYER[level] + 1 ))

    clear
    printf "\n${GOLD}${BOLD}  LEVEL UP! → Level %d${NC}\n\n" "${PLAYER[level]}"
    printf "  Choose a stat to increase:\n\n"

    local opts=(
        "Vigor (VIG ${PLAYER[vig]}) — increases max HP"
        "Endurance (END ${PLAYER[end]}) — increases stamina"
        "Strength (STR ${PLAYER[str]}) — increases melee damage"
        "Dexterity (DEX ${PLAYER[dex]}) — increases finesse damage"
        "Intelligence (INT ${PLAYER[int]}) — increases sorcery damage and FP"
        "Faith (FAI ${PLAYER[fai]}) — increases incantation power and FP"
    )

    local choice
    choice=$(ask_menu "Increase which stat?" "${opts[@]}")

    case "$choice" in
        1) PLAYER[vig]=$(( PLAYER[vig] + 1 )); print_msg good "Vigor increased to ${PLAYER[vig]}." ;;
        2) PLAYER[end]=$(( PLAYER[end] + 1 )); print_msg good "Endurance increased to ${PLAYER[end]}." ;;
        3) PLAYER[str]=$(( PLAYER[str] + 1 )); print_msg good "Strength increased to ${PLAYER[str]}." ;;
        4) PLAYER[dex]=$(( PLAYER[dex] + 1 )); print_msg good "Dexterity increased to ${PLAYER[dex]}." ;;
        5) PLAYER[int]=$(( PLAYER[int] + 1 )); print_msg good "Intelligence increased to ${PLAYER[int]}." ;;
        6) PLAYER[fai]=$(( PLAYER[fai] + 1 )); print_msg good "Faith increased to ${PLAYER[fai]}." ;;
        *) print_msg info "Level saved but no stat chosen. Defaulting to Vigor."
           PLAYER[vig]=$(( PLAYER[vig] + 1 )) ;;
    esac

    local old_hp="${PLAYER[hp]}"
    local old_fp="${PLAYER[fp]}"
    local old_sta="${PLAYER[stamina]}"
    local old_max_hp="${PLAYER[max_hp]}"

    recalc_player_stats
    # Restore the gained HP from vigor increase
    local hp_gained=$(( PLAYER[max_hp] - old_max_hp ))
    [ $hp_gained -gt 0 ] && PLAYER[hp]=$(( old_hp + hp_gained ))

    press_key
    return 0
}

use_flask() {
    local flask_type="${1:-crimson}"
    if [ "$flask_type" = "crimson" ]; then
        if [ "${PLAYER[crimson_flasks]}" -le 0 ]; then
            print_msg warn "No Flasks of Crimson Tears remaining!"
            return 1
        fi
        PLAYER[crimson_flasks]=$(( PLAYER[crimson_flasks] - 1 ))
        local heal=$(( PLAYER[max_hp] * 40 / 100 ))
        PLAYER[hp]=$(( PLAYER[hp] + heal ))
        [ "${PLAYER[hp]}" -gt "${PLAYER[max_hp]}" ] && PLAYER[hp]="${PLAYER[max_hp]}"
        print_msg good "Used Flask of Crimson Tears. Restored ~${heal} HP."
        return 0
    else
        if [ "${PLAYER[cerulean_flasks]}" -le 0 ]; then
            print_msg warn "No Flasks of Cerulean Tears remaining!"
            return 1
        fi
        PLAYER[cerulean_flasks]=$(( PLAYER[cerulean_flasks] - 1 ))
        local restore=$(( PLAYER[max_fp] * 40 / 100 ))
        PLAYER[fp]=$(( PLAYER[fp] + restore ))
        [ "${PLAYER[fp]}" -gt "${PLAYER[max_fp]}" ] && PLAYER[fp]="${PLAYER[max_fp]}"
        print_msg good "Used Flask of Cerulean Tears. Restored ~${restore} FP."
        return 0
    fi
}

player_dead() {
    [ "${PLAYER[hp]}" -le 0 ]
}

regen_stamina() {
    local regen="${1:-15}"
    PLAYER[stamina]=$(( PLAYER[stamina] + regen ))
    [ "${PLAYER[stamina]}" -gt "${PLAYER[max_stamina]}" ] && PLAYER[stamina]="${PLAYER[max_stamina]}"
}
