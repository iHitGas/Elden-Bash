#!/usr/bin/env bash
# Combat engine
# Uses global COMBAT_RESULT instead of echo/subshell to preserve state

# Global return variable: "win" | "lose" | "flee"
COMBAT_RESULT=""

run_combat() {
    local enemy_id="$1"
    COMBAT_RESULT=""

    load_enemy "$enemy_id"

    # Reset per-battle buffs
    PLAYER[str_buff]=0
    PLAYER[def_buff]=0
    PLAYER[is_dodging]=0
    PLAYER[is_guarding]=0

    clear
    if [ "${ENEMY[is_boss]}" -eq 1 ]; then
        printf "\n${BLOOD}${BOLD}"
        center_text "⚔  BOSS ENCOUNTER  ⚔" "$BLOOD"
        printf "${NC}"
        print_msg lore "${ENEMY[desc]}"
        sleep 1
    else
        printf "\n${LRED}${BOLD}  !! ENEMY ENCOUNTERED !!${NC}\n"
        printf "  ${GRAY}%s${NC}\n\n" "${ENEMY[desc]}"
        sleep 0.4
    fi

    while true; do
        # Regen stamina at start of each turn
        regen_stamina 20

        clear
        draw_line "─"
        show_enemy_bar "${ENEMY[name]}" "${ENEMY[hp]}" "${ENEMY[max_hp]}"
        show_status_bar

        # ── Player's turn ──────────────────────────────────────────────────
        PLAYER[is_dodging]=0
        PLAYER[is_guarding]=0

        # Display action menu and get input directly
        printf "\n${GOLD}  ── Combat Actions ──${NC}\n"
        printf "  ${CYAN}[1]${NC} Light Attack  (STA: %d)   " "$(weapon_sta_light "${PLAYER[weapon]}")"
        printf "${CYAN}[2]${NC} Heavy Attack  (STA: %d)\n" "$(weapon_sta_heavy "${PLAYER[weapon]}")"
        printf "  ${CYAN}[3]${NC} Dodge Roll    (STA: 15)   "
        printf "${CYAN}[4]${NC} Guard         (STA: 5)\n"
        printf "  ${BLOOD}[5]${NC} Crimson Flask (%d left)   " "${PLAYER[crimson_flasks]}"
        if [ "${PLAYER[cerulean_flasks]}" -gt 0 ]; then
            printf "${BLUE}[6]${NC} Cerulean Flask (%d left)\n" "${PLAYER[cerulean_flasks]}"
        else
            printf "${DARK}[6]${NC} ${DARK}Cerulean Flask (0 left)${NC}\n"
        fi
        if [ -n "${PLAYER[spells]:-}" ]; then
            printf "  ${LBLUE}[7]${NC} Cast Spell    (FP: %d/%d)  " "${PLAYER[fp]}" "${PLAYER[max_fp]}"
        else
            printf "  ${DARK}[7]${NC} ${DARK}Cast Spell    (no spells)${NC}  "
        fi
        printf "${CYAN}[8]${NC} Use Item\n"
        printf "  ${YELLOW}[9]${NC} Try to Flee\n"
        printf "\n${WHITE}> ${NC}"
        local choice
        read -r choice

        case "$choice" in
            1) _action_light_attack ;;
            2) _action_heavy_attack ;;
            3) _action_dodge ;;
            4) _action_guard ;;
            5) use_flask crimson || true ;;
            6)
                if [ "${PLAYER[cerulean_flasks]}" -gt 0 ]; then
                    use_flask cerulean || true
                else
                    print_msg warn "No Cerulean Flasks left!"
                    sleep 0.6
                    continue
                fi
                ;;
            7)
                if [ -n "${PLAYER[spells]:-}" ]; then
                    _action_cast_spell
                else
                    print_msg warn "You know no spells."
                    sleep 0.6
                    continue
                fi
                ;;
            8) _action_use_item || continue ;;
            9)
                if [ "${ENEMY[is_boss]}" -eq 1 ]; then
                    print_msg warn "You cannot flee from a boss fight!"
                    sleep 0.8
                    continue
                fi
                local flee_roll=$(( RANDOM % 100 ))
                if [ $flee_roll -lt 45 ]; then
                    print_msg info "You fled from battle!"
                    sleep 0.8
                    COMBAT_RESULT="flee"
                    return
                else
                    print_msg warn "Couldn't escape — the enemy blocks the way!"
                    sleep 0.8
                fi
                ;;
            *) print_msg warn "Invalid action."; sleep 0.4; continue ;;
        esac

        # Damage was applied by action functions via ENEMY[hp]
        if enemy_dead; then
            clear
            local rune_gain="${ENEMY[runes]}"
            if [ "${ENEMY[is_boss]}" -eq 1 ]; then
                show_victory_screen "${ENEMY[name]}"
            else
                print_msg good "${ENEMY[name]} defeated!"
                sleep 0.5
            fi
            printf "\n"
            print_msg gold "Obtained ${rune_gain} runes."
            PLAYER[runes]=$(( PLAYER[runes] + rune_gain ))
            PLAYER[kills]=$(( PLAYER[kills] + 1 ))
            enemy_loot
            sleep 1
            press_key
            COMBAT_RESULT="win"
            return
        fi

        # ── Enemy's turn ───────────────────────────────────────────────────
        enemy_take_turn "${PLAYER[is_guarding]}" "${PLAYER[is_dodging]}"

        if [ "$ENEMY_DAMAGE" -gt 0 ]; then
            PLAYER[hp]=$(( PLAYER[hp] - ENEMY_DAMAGE ))
            [ "${PLAYER[hp]}" -lt 0 ] && PLAYER[hp]=0
            printf "  ${BLOOD}You took %d damage!${NC}  HP: %d/%d\n" \
                "$ENEMY_DAMAGE" "${PLAYER[hp]}" "${PLAYER[max_hp]}"
        fi

        if player_dead; then
            PLAYER[hp]=0
            PLAYER[deaths]=$(( PLAYER[deaths] + 1 ))
            show_death_screen
            COMBAT_RESULT="lose"
            return
        fi

        sleep 0.3
    done
}

# ── Action helpers (called directly, modify globals) ──────────────────────────

_action_light_attack() {
    local sta_cost; sta_cost=$(weapon_sta_light "${PLAYER[weapon]}")
    if [ "${PLAYER[stamina]}" -lt "$sta_cost" ]; then
        print_msg warn "Not enough stamina! (need $sta_cost, have ${PLAYER[stamina]})"
        sleep 0.8
        return 1
    fi
    PLAYER[stamina]=$(( PLAYER[stamina] - sta_cost ))
    local dmg; dmg=$(calc_attack_damage light)
    print_msg bad "You strike for ${dmg} damage!"
    ENEMY[hp]=$(( ENEMY[hp] - dmg ))
}

_action_heavy_attack() {
    local sta_cost; sta_cost=$(weapon_sta_heavy "${PLAYER[weapon]}")
    if [ "${PLAYER[stamina]}" -lt "$sta_cost" ]; then
        print_msg warn "Not enough stamina for a heavy attack! (need $sta_cost)"
        sleep 0.8
        return 1
    fi
    PLAYER[stamina]=$(( PLAYER[stamina] - sta_cost ))
    local dmg; dmg=$(calc_attack_damage heavy)
    print_msg bad "You SLAM for ${dmg} damage!"
    ENEMY[hp]=$(( ENEMY[hp] - dmg ))
    if [ $(( RANDOM % 100 )) -lt 35 ]; then
        ENEMY[stunned]=1
        print_msg good "Enemy staggered by the heavy blow!"
    fi
}

_action_dodge() {
    if [ "${PLAYER[stamina]}" -lt 15 ]; then
        print_msg warn "Not enough stamina to dodge! (need 15)"
        sleep 0.8
        return 1
    fi
    PLAYER[stamina]=$(( PLAYER[stamina] - 15 ))
    PLAYER[is_dodging]=1
    print_msg info "You prepare to dodge roll..."
}

_action_guard() {
    if [ "${PLAYER[stamina]}" -lt 5 ]; then
        print_msg warn "Not enough stamina to guard!"
        sleep 0.8
        return 1
    fi
    PLAYER[stamina]=$(( PLAYER[stamina] - 5 ))
    PLAYER[is_guarding]=1
    print_msg info "You raise your guard..."
}

_action_cast_spell() {
    local spell_arr=( ${PLAYER[spells]} )
    local opts=()
    for sp in "${spell_arr[@]}"; do
        opts+=("$(spell_name "$sp")  FP:$(spell_fp "$sp")  DMG:$(spell_dmg "$sp")  — $(spell_desc "$sp")")
    done
    opts+=("Cancel")

    local choice
    choice=$(ask_menu "Choose a spell:" "${opts[@]}")

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -gt "${#spell_arr[@]}" ]; then
        return 1
    fi

    local spell_id="${spell_arr[$((choice-1))]}"
    local fp_cost; fp_cost=$(spell_fp "$spell_id")

    if [ "${PLAYER[fp]}" -lt "$fp_cost" ]; then
        print_msg warn "Not enough FP! (need $fp_cost, have ${PLAYER[fp]})"
        sleep 0.8
        return 1
    fi

    PLAYER[fp]=$(( PLAYER[fp] - fp_cost ))

    local base_dmg; base_dmg=$(spell_dmg "$spell_id")
    local scale; scale=$(spell_scale "$spell_id")
    local hits; hits=$(spell_hits "$spell_id")
    local int_val="${PLAYER[int]}"
    local enemy_mdef=$(( ENEMY[def] / 2 ))
    local per_hit=$(( base_dmg + int_val * scale / 10 - enemy_mdef ))
    [ $per_hit -lt 1 ] && per_hit=1
    local total=$(( per_hit * hits ))

    if [ "$hits" -gt 1 ]; then
        print_msg bad "$(spell_name "$spell_id") — ${hits} hits × ${per_hit} = ${total} total!"
    else
        print_msg bad "$(spell_name "$spell_id") — ${total} damage!"
    fi
    ENEMY[hp]=$(( ENEMY[hp] - total ))
}

_action_use_item() {
    local usable_ids=()
    local usable_disp=()
    for entry in ${PLAYER[inventory]:-}; do
        local id="${entry%%:*}"
        local cnt="${entry##*:}"
        if [ -n "${CONSUMABLES[$id]+_}" ] && [ "$cnt" -gt 0 ]; then
            usable_ids+=("$id")
            usable_disp+=("$(consumable_name "$id") x${cnt} — $(consumable_desc "$id")")
        fi
    done

    if [ "${#usable_ids[@]}" -eq 0 ]; then
        print_msg warn "No usable items!"
        sleep 0.6
        return 1
    fi

    usable_disp+=("Cancel")
    local choice
    choice=$(ask_menu "Use which item?" "${usable_disp[@]}")

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -gt "${#usable_ids[@]}" ]; then
        return 1
    fi

    local item_id="${usable_ids[$((choice-1))]}"
    local effect; effect=$(consumable_effect "$item_id")
    local value; value=$(consumable_value "$item_id")
    inventory_remove "$item_id" 1

    case "$effect" in
        hp)
            PLAYER[hp]=$(( PLAYER[hp] + value ))
            [ "${PLAYER[hp]}" -gt "${PLAYER[max_hp]}" ] && PLAYER[hp]="${PLAYER[max_hp]}"
            print_msg good "Used $(consumable_name "$item_id"). Restored ${value} HP."
            ;;
        fp)
            PLAYER[fp]=$(( PLAYER[fp] + value ))
            [ "${PLAYER[fp]}" -gt "${PLAYER[max_fp]}" ] && PLAYER[fp]="${PLAYER[max_fp]}"
            print_msg good "Used $(consumable_name "$item_id"). Restored ${value} FP."
            ;;
        str_buff)
            PLAYER[str_buff]=$(( ${PLAYER[str_buff]:-0} + value ))
            print_msg good "Used $(consumable_name "$item_id"). STR +${value} for this battle!"
            ;;
        def_buff)
            PLAYER[def_buff]=$(( ${PLAYER[def_buff]:-0} + value ))
            print_msg good "Used $(consumable_name "$item_id"). Defense +${value} for this battle!"
            ;;
    esac
}

calc_attack_damage() {
    local attack_type="${1:-light}"
    local str_total=$(( ${PLAYER[str]} + ${PLAYER[str_buff]:-0} ))
    local base; base=$(calc_weapon_damage "${PLAYER[weapon]}" "$str_total" "${PLAYER[dex]}" "${PLAYER[int]}")
    local variance=$(( RANDOM % (base / 5 + 1) ))
    local dmg
    if [ "$attack_type" = "heavy" ]; then
        dmg=$(( base * 17 / 10 + variance ))
    else
        dmg=$(( base + variance ))
    fi
    dmg=$(( dmg - ENEMY[def] ))
    [ $dmg -lt 1 ] && dmg=1
    echo "$dmg"
}
