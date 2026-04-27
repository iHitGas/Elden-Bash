#!/usr/bin/env bash
# World navigation, areas, story events

declare -A AREA_NAMES
AREA_NAMES[stranded_graveyard]="Stranded Graveyard"
AREA_NAMES[limgrave]="Limgrave"
AREA_NAMES[stormveil]="Stormveil Castle"
AREA_NAMES[liurnia]="Liurnia of the Lakes"
AREA_NAMES[academy]="Academy of Raya Lucaria"
AREA_NAMES[altus]="Altus Plateau"
AREA_NAMES[leyndell]="Leyndell, Royal Capital"

declare -A AREA_DESCRIPTIONS
AREA_DESCRIPTIONS[stranded_graveyard]="You awaken in a crumbling underground graveyard. The air smells of old death. Somewhere above, the Erdtree glows gold. You are Tarnished — called by grace to reclaim your destiny."
AREA_DESCRIPTIONS[limgrave]="Rolling green fields beneath a golden sky. The Erdtree's light bathes the land in warmth. Ruins of an ancient civilization litter the ground. Soldiers in golden armor patrol the roads ahead."
AREA_DESCRIPTIONS[stormveil]="A crumbling castle battered by perpetual storm. The banner of Godrick the Grafted hangs in tatters from every tower. Inside, grafted soldiers and monstrous creatures guard every hall and passage."
AREA_DESCRIPTIONS[liurnia]="A vast flooded lowland beneath a purple sky. The Academy of Raya Lucaria rises from the water on a great rocky hill. Sorcerers and blue-armored soldiers wander the flooded shore."
AREA_DESCRIPTIONS[academy]="Towers of blue stone pierce the sky. Within the Academy, the full moon shines even at midday. Rennala, the once-great queen of full moon sorcery, sits cradling her golden amber egg deep within the inner library."
AREA_DESCRIPTIONS[altus]="High plateaus of golden grass that catch the light of the Erdtree. Ancient golems patrol the roads. The walls of Leyndell are visible on the horizon, gleaming gold."
AREA_DESCRIPTIONS[leyndell]="The Royal Capital, partially buried in the roots of the Erdtree. Golden soldiers and knights of the Order patrol its elegant, ruined streets. At its heart sits Morgott, the Omen King."

# Encounters per area: "enemy_id:chance ..."
declare -A AREA_ENCOUNTERS
AREA_ENCOUNTERS[stranded_graveyard]="hollow:60 giant_bat:30"
AREA_ENCOUNTERS[limgrave]="godrick_soldier:55 wolves:40 giant_bat:25 crucible_knight:15"
AREA_ENCOUNTERS[stormveil]="godrick_soldier:70 crucible_knight:40 troll:20"
AREA_ENCOUNTERS[liurnia]="raya_sorcerer:60 wolves:30 crucible_knight:20"
AREA_ENCOUNTERS[academy]="raya_sorcerer:70 golem:30"
AREA_ENCOUNTERS[altus]="erdtree_knight:50 golem:35 dragon_soldier:40"
AREA_ENCOUNTERS[leyndell]="leyndell_knight:65 golem:30 dragon_soldier:45"

# One-time treasures per area
declare -A AREA_TREASURES
AREA_TREASURES[stranded_graveyard]="short_sword rowa_raisin"
AREA_TREASURES[limgrave]="longsword vagabond_set rowa_raisin exalted_flesh"
AREA_TREASURES[stormveil]="greatsword lordsworn_set uplifting_aroma"
AREA_TREASURES[liurnia]="magic_staff raya_lucaria starlight_shards glintstone_arc"
AREA_TREASURES[academy]="great_glintstone rock_sling"
AREA_TREASURES[altus]="bastard_sword knight_set comet"
AREA_TREASURES[leyndell]="crucible_set sacred_seal cannon"

declare -A AREA_CONNECTIONS
AREA_CONNECTIONS[stranded_graveyard]="limgrave"
AREA_CONNECTIONS[limgrave]="stranded_graveyard stormveil liurnia"
AREA_CONNECTIONS[stormveil]="limgrave"
AREA_CONNECTIONS[liurnia]="limgrave academy"
AREA_CONNECTIONS[academy]="liurnia altus"
AREA_CONNECTIONS[altus]="academy leyndell"
AREA_CONNECTIONS[leyndell]="altus"

# ── Site of Grace ─────────────────────────────────────────────────────────────

site_of_grace() {
    full_heal_player
    # Replenish flasks (min 3, keep extra)
    [ "${PLAYER[crimson_flasks]}" -lt 3 ] && PLAYER[crimson_flasks]=3
    if [ "${PLAYER[int]}" -ge 14 ] && [ "${PLAYER[cerulean_flasks]}" -lt 2 ]; then
        PLAYER[cerulean_flasks]=2
    fi

    # Recover runes dropped in this area
    if [ "${PLAYER[runes_on_ground]:-0}" -gt 0 ] && [ "${PLAYER[rune_location]:-}" = "${PLAYER[location]}" ]; then
        local recovered="${PLAYER[runes_on_ground]}"
        PLAYER[runes]=$(( PLAYER[runes] + recovered ))
        PLAYER[runes_on_ground]=0
        PLAYER[rune_location]=""
        print_msg gold "Recovered ${recovered} runes from your last death!"
    fi

    clear
    printf "\n${GOLD}${BOLD}"
    center_text "⬡  SITE OF GRACE  ⬡" "$GOLD"
    printf "${NC}\n"
    print_msg lore "Grace's warmth envelops you. All is restored."
    printf "\n"
    printf "  ${BLOOD}HP${NC}  restored to %d\n" "${PLAYER[max_hp]}"
    printf "  ${BLUE}FP${NC}  restored to %d\n" "${PLAYER[max_fp]}"
    printf "  ${GREEN}STA${NC} restored to %d\n" "${PLAYER[max_stamina]}"
    printf "  ${BLOOD}Flasks of Crimson Tears${NC}: %d\n\n" "${PLAYER[crimson_flasks]}"
    [ "${PLAYER[runes_on_ground]:-0}" -gt 0 ] && \
        printf "  ${YELLOW}Lost runes nearby: %d — return here to recover them.${NC}\n\n" "${PLAYER[runes_on_ground]}"

    while true; do
        local opts=("Level Up  (have ${PLAYER[runes]} runes)" "Memorize Spell" "Save Game" "Continue Exploring" "Travel")
        local choice
        choice=$(ask_menu "Grace's boon:" "${opts[@]}")
        case "$choice" in
            1) try_level_up ;;
            2) memorize_spell_menu ;;
            3) save_menu ;;
            4) return ;;
            5) travel_menu; return ;;
            *) return ;;
        esac
    done
}

memorize_spell_menu() {
    local available=()
    local min_int
    for sp_id in "${!SPELLS[@]}"; do
        case "$sp_id" in
            glintstone_pebble)  min_int=10 ;;
            glintstone_arc)     min_int=12 ;;
            swift_glintstone)   min_int=12 ;;
            great_glintstone)   min_int=16 ;;
            rock_sling)         min_int=18 ;;
            comet)              min_int=22 ;;
            cannon)             min_int=28 ;;
            *)                  min_int=10 ;;
        esac
        if ! echo " ${PLAYER[spells]:-} " | grep -qw "$sp_id" && [ "${PLAYER[int]}" -ge "$min_int" ]; then
            available+=("$sp_id")
        fi
    done

    if [ "${#available[@]}" -eq 0 ]; then
        print_msg warn "No new spells available. Raise INT to unlock more."
        press_key
        return
    fi

    local opts=()
    for sp_id in "${available[@]}"; do
        opts+=("$(spell_name "$sp_id")  FP:$(spell_fp "$sp_id")  DMG:$(spell_dmg "$sp_id") — $(spell_desc "$sp_id")")
    done
    opts+=("Cancel")

    local choice
    choice=$(ask_menu "Memorize which spell?" "${opts[@]}")

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#available[@]}" ]; then
        local sp_id="${available[$((choice-1))]}"
        if [ -z "${PLAYER[spells]:-}" ]; then
            PLAYER[spells]="$sp_id"
        else
            PLAYER[spells]="${PLAYER[spells]} $sp_id"
        fi
        print_msg good "Memorized: $(spell_name "$sp_id")!"
        if [ "${PLAYER[weapon]}" != "magic_staff" ] && [ "${PLAYER[weapon]}" != "sacred_seal" ]; then
            print_msg warn "Tip: equip a Glintstone Staff or Sacred Seal for better spell scaling."
        fi
        press_key
    fi
}

travel_menu() {
    local connections="${AREA_CONNECTIONS[${PLAYER[location]}]:-}"
    if [ -z "$connections" ]; then
        print_msg warn "No travel routes available from here."
        press_key
        return
    fi

    local opts=()
    local dest_ids=()
    for dest in $connections; do
        opts+=("${AREA_NAMES[$dest]:-$dest}")
        dest_ids+=("$dest")
    done
    opts+=("Cancel")

    local choice
    choice=$(ask_menu "Travel where?" "${opts[@]}")

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#dest_ids[@]}" ]; then
        enter_area "${dest_ids[$((choice-1))]}"
    fi
}

enter_area() {
    local area_id="$1"
    PLAYER[location]="$area_id"
    PLAYER[location_name]="${AREA_NAMES[$area_id]}"

    clear
    draw_line "═"
    center_text "${AREA_NAMES[$area_id]}" "$GOLD"
    draw_line "═"
    printf "\n"
    print_msg lore "${AREA_DESCRIPTIONS[$area_id]}"
    printf "\n"

    if [ "${PLAYER[runes_on_ground]:-0}" -gt 0 ] && [ "${PLAYER[rune_location]:-}" = "$area_id" ]; then
        print_msg gold "Your lost runes (${PLAYER[runes_on_ground]}) shimmer here. Rest at a Site of Grace to recover them."
    fi

    press_key
}

explore_area() {
    local area_id="${PLAYER[location]}"
    local encounters="${AREA_ENCOUNTERS[$area_id]:-}"
    local enemy_id=""

    for entry in $encounters; do
        local eid="${entry%%:*}"
        local chance="${entry##*:}"
        if [ $(( RANDOM % 100 )) -lt $chance ]; then
            enemy_id="$eid"
            break
        fi
    done

    if [ -n "$enemy_id" ]; then
        clear
        printf "\n${LRED}  An enemy appears in the distance!${NC}\n"
        sleep 0.5
        run_combat "$enemy_id"
        if [ "$COMBAT_RESULT" = "lose" ]; then
            on_player_death
        fi
    else
        print_msg info "You explore cautiously. No enemies find you this time."
        sleep 0.6
    fi
}

search_area() {
    local area_id="${PLAYER[location]}"
    local treasures="${AREA_TREASURES[$area_id]:-}"
    local found_key="found_${area_id}"
    local already_found="${PLAYER[$found_key]:-}"
    local any_found=0

    for item_id in $treasures; do
        echo " $already_found " | grep -qw "$item_id" && continue
        if [ $(( RANDOM % 100 )) -lt 50 ]; then
            inventory_add "$item_id" 1
            if [ -z "$already_found" ]; then
                PLAYER[$found_key]="$item_id"
            else
                PLAYER[$found_key]="$already_found $item_id"
            fi
            already_found="${PLAYER[$found_key]}"
            local iname=""
            if   [ -n "${WEAPONS[$item_id]+_}" ];     then iname=$(weapon_name "$item_id")
            elif [ -n "${ARMORS[$item_id]+_}" ];      then iname=$(armor_name "$item_id")
            elif [ -n "${CONSUMABLES[$item_id]+_}" ]; then iname=$(consumable_name "$item_id")
            elif [ -n "${SPELLS[$item_id]+_}" ];      then iname=$(spell_name "$item_id")
            fi
            print_msg gold "Found: ${iname}!"
            any_found=$(( any_found + 1 ))
        fi
    done

    [ $any_found -eq 0 ] && print_msg info "You search the area but find nothing new."
    press_key
}

# ── Boss fights ───────────────────────────────────────────────────────────────

_boss_fight() {
    local enemy_id="$1"
    local gate_title="$2"
    local lore_text="$3"

    clear
    draw_line "─" "$BLOOD"
    center_text "$gate_title" "$BLOOD"
    draw_line "─" "$BLOOD"
    print_msg lore "$lore_text"
    printf "\n"

    local choice
    choice=$(ask_menu "The fog gate awaits..." "Enter the fog (fight!)" "Turn back")
    [ "$choice" != "1" ] && return

    run_combat "$enemy_id"

    if [ "$COMBAT_RESULT" = "win" ]; then
        case "$enemy_id" in
            grafted)
                PLAYER[boss_grafted_dead]=1
                printf "\n"
                print_msg lore "Godrick the Grafted is no more. The path to Liurnia of the Lakes opens before you."
                ;;
            rennala)
                PLAYER[boss_rennala_dead]=1
                printf "\n"
                print_msg lore "Rennala, Queen of the Full Moon, is pacified at last."
                PLAYER[cerulean_flasks]=$(( ${PLAYER[cerulean_flasks]:-0} + 2 ))
                print_msg gold "Rennala's blessing bestowed: +2 Flasks of Cerulean Tears."
                ;;
            morgott)
                PLAYER[boss_morgott_dead]=1
                game_ending
                ;;
        esac
        press_key
    elif [ "$COMBAT_RESULT" = "lose" ]; then
        on_player_death
    fi
}

boss_defeated() {
    local boss_id="$1"
    local key="boss_${boss_id}_dead"
    [ "${PLAYER[$key]:-0}" -eq 1 ]
}

on_player_death() {
    if [ "${PLAYER[runes]:-0}" -gt 0 ]; then
        PLAYER[runes_on_ground]="${PLAYER[runes]}"
        PLAYER[rune_location]="${PLAYER[location]}"
        printf "  ${YELLOW}Your %d runes remain where you fell.${NC}\n" "${PLAYER[runes]}"
        PLAYER[runes]=0
    fi
    PLAYER[hp]="${PLAYER[max_hp]}"
    PLAYER[fp]="${PLAYER[max_fp]}"
    PLAYER[stamina]="${PLAYER[max_stamina]}"
    PLAYER[crimson_flasks]=3
    print_msg info "You have respawned at the nearest Site of Grace."
    press_key
}

# ── Area navigation menu ──────────────────────────────────────────────────────

area_menu() {
    while true; do
        clear
        draw_line "═" "$GOLD"
        center_text "${PLAYER[location_name]}" "$GOLD"
        draw_line "═" "$GOLD"
        show_status_bar

        # Build dynamic option list
        local opts=()
        local actions=()

        opts+=("Explore  (chance of encounters)")
        actions+=("explore")

        opts+=("Search area  (find items)")
        actions+=("search")

        # Boss option
        local boss_here=""
        case "${PLAYER[location]}" in
            stormveil)
                boss_defeated "grafted" || { boss_here="grafted"; opts+=("${BLOOD}Fog Gate: Godrick the Grafted${NC}"); actions+=("boss_grafted"); }
                ;;
            academy)
                boss_defeated "rennala" || { boss_here="rennala"; opts+=("${BLOOD}Fog Gate: Rennala, Queen of Full Moon${NC}"); actions+=("boss_rennala"); }
                ;;
            leyndell)
                boss_defeated "morgott" || { boss_here="morgott"; opts+=("${BLOOD}Fog Gate: Morgott, the Omen King${NC}"); actions+=("boss_morgott"); }
                ;;
        esac

        opts+=("Site of Grace")
        actions+=("grace")

        opts+=("Travel")
        actions+=("travel")

        opts+=("Character")
        actions+=("char")

        opts+=("Inventory")
        actions+=("inv")

        opts+=("Equipment")
        actions+=("equip")

        # Print status hints
        boss_defeated "grafted" && [ "${PLAYER[location]}" = "stormveil" ] && \
            printf "  ${DARK}[Godrick has been slain]${NC}\n"
        boss_defeated "rennala" && [ "${PLAYER[location]}" = "academy" ] && \
            printf "  ${DARK}[Rennala has been pacified]${NC}\n"
        boss_defeated "morgott" && [ "${PLAYER[location]}" = "leyndell" ] && \
            printf "  ${DARK}[Morgott has been slain]${NC}\n"
        [ "${PLAYER[runes_on_ground]:-0}" -gt 0 ] && [ "${PLAYER[rune_location]:-}" = "${PLAYER[location]}" ] && \
            printf "  ${GOLD}Your lost runes (%d) are here — rest at grace to recover.${NC}\n" "${PLAYER[runes_on_ground]}"
        printf "\n"

        local choice
        choice=$(ask_menu "What will you do?" "${opts[@]}")

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#actions[@]}" ]; then
            continue
        fi

        local action="${actions[$((choice-1))]}"

        case "$action" in
            explore) explore_area ;;
            search)  search_area ;;
            boss_grafted)
                _boss_fight "grafted" "Fog Gate: Godrick the Grafted" \
                    "Grafted limbs writhe across the walls. Beyond the fog, Godrick waits — a lord of nothing, who steals the power of those he slays."
                ;;
            boss_rennala)
                _boss_fight "rennala" "Fog Gate: Rennala, Queen of the Full Moon" \
                    "Soft chanting fills the candlelit library. Rennala floats serenely above a golden egg — all that remains of the love she was promised."
                ;;
            boss_morgott)
                _boss_fight "morgott" "Fog Gate: Morgott, the Omen King" \
                    "The throne room of Leyndell. Morgott descends from above, his omen horns bound in golden cloth. He will not let you pass."
                ;;
            grace)  site_of_grace ;;
            travel) travel_menu ;;
            char)   show_player_stats ;;
            inv)    show_inventory ;;
            equip)  show_equipment_menu ;;
        esac
    done
}

# ── Ending ────────────────────────────────────────────────────────────────────

game_ending() {
    clear
    sleep 1
    printf "\n\n"
    center_text "╔══════════════════════════════════════════════════════╗" "$GOLD"
    center_text "║                                                      ║" "$GOLD"
    center_text "║                  ELDEN LORD                         ║" "$GOLD"
    center_text "║                                                      ║" "$GOLD"
    center_text "║   You have shattered the chains of the Erdtree.     ║" "$GOLD"
    center_text "║   The Greater Will is silent. The Elden Ring         ║" "$GOLD"
    center_text "║   lies broken, waiting to be remade by your will.   ║" "$GOLD"
    center_text "║                                                      ║" "$GOLD"
    center_text "║        YOU ARE THE ELDEN LORD.                       ║" "$GOLD"
    center_text "║                                                      ║" "$GOLD"
    center_text "╚══════════════════════════════════════════════════════╝" "$GOLD"
    printf "\n\n"
    center_text "Thank you for playing  E L D E N  B A S H" "$GRAY"
    center_text "A Souls-like written entirely in Bash." "$DARK"
    printf "${NC}\n\n"
    printf "  ${WHITE}─── Final Stats ───${NC}\n"
    printf "  ${YELLOW}Level:${NC}  %d\n" "${PLAYER[level]}"
    printf "  ${LRED}Kills:${NC}  %d\n" "${PLAYER[kills]}"
    printf "  ${BLOOD}Deaths:${NC} %d\n" "${PLAYER[deaths]}"
    printf "  ${GOLD}Runes:${NC}  %d\n\n" "${PLAYER[runes]}"
    press_key
    exit 0
}
