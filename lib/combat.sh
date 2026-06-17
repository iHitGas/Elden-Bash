#!/usr/bin/env bash
# Combat engine
# Uses global COMBAT_RESULT instead of echo/subshell to preserve state

# Global return variable: "win" | "lose" | "flee"
COMBAT_RESULT=""

# Combat log (stores last 5 messages)
declare -a COMBAT_LOG=()

combat_log_add() {
    local msg="$1"
    COMBAT_LOG+=("$msg")
    # Keep only last 5
    while [ "${#COMBAT_LOG[@]}" -gt 5 ]; do
        COMBAT_LOG=("${COMBAT_LOG[@]:1}")
    done
}

combat_log_show() {
    printf "\n${DARK}── Combat Log ──${NC}\n"
    for entry in "${COMBAT_LOG[@]:-}"; do
        printf "  ${GRAY}%s${NC}\n" "$entry"
    done
}

# Damage number display with color scaling
damage_number() {
    local dmg="$1"
    local is_crit="${2:-0}"
    if [ "$is_crit" -eq 1 ]; then
        printf "${BOLD}${ORANGE}⚔ CRITICAL! %d ⚔${NC}" "$dmg"
    elif [ "$dmg" -ge 100 ]; then
        printf "${LRED}💥 %d${NC}" "$dmg"
    elif [ "$dmg" -ge 50 ]; then
        printf "${ORANGE}%d${NC}" "$dmg"
    elif [ "$dmg" -ge 20 ]; then
        printf "${YELLOW}%d${NC}" "$dmg"
    else
        printf "${WHITE}%d${NC}" "$dmg"
    fi
}

run_combat() {
    local enemy_id="$1"
    COMBAT_RESULT=""
    COMBAT_LOG=()

    load_enemy "$enemy_id"

    # Reset per-battle buffs
    PLAYER[str_buff]=0
    PLAYER[def_buff]=0
    PLAYER[is_dodging]=0
    PLAYER[is_guarding]=0
    PLAYER[backstab_ready]=0
    PLAYER[spec_cooldown]=0

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

        # Process poison tick
        local poison_dmg=0
        if [ "${PLAYER[poison_status]:-0}" -gt 0 ]; then
            poison_dmg=3
            PLAYER[hp]=$(( PLAYER[hp] - poison_dmg ))
            PLAYER[poison_status]=$(( PLAYER[poison_status] - 1 ))
            combat_log_add "Poison dealt ${poison_dmg} damage (${PLAYER[poison_status]} turns left)"
            print_msg warn "☠ Poison: -${poison_dmg} HP (${PLAYER[poison_status]} turns left)"
            if player_dead; then
                PLAYER[hp]=0
                PLAYER[deaths]=$(( PLAYER[deaths] + 1 ))
                show_death_screen
                COMBAT_RESULT="lose"
                return
            fi
        fi

        # Decrement weapon spec cooldown
        if [ "${PLAYER[spec_cooldown]:-0}" -gt 0 ]; then
            PLAYER[spec_cooldown]=$(( PLAYER[spec_cooldown] - 1 ))
        fi

        clear
        draw_line "─"
        show_enemy_bar "${ENEMY[name]}" "${ENEMY[hp]}" "${ENEMY[max_hp]}"
        show_status_bar

        # Show poison indicator
        if [ "${PLAYER[poison_status]:-0}" -gt 0 ]; then
            printf "  ${LMAGENTA}☠ POISONED${NC} (${PLAYER[poison_status]} turns)\n"
        fi

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
        # Weapon special option
        if [ "${PLAYER[spec_cooldown]:-0}" -le 0 ]; then
            printf "  ${ORANGE}[S]${NC} Weapon Special (2x STA, 3-turn CD)  "
        else
            printf "  ${DARK}[S]${NC} ${DARK}Weapon Special (CD: %d)${NC}    " "${PLAYER[spec_cooldown]}"
        fi
        printf "${YELLOW}[9]${NC} Try to Flee\n"
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
            [Ss])
                if [ "${PLAYER[spec_cooldown]:-0}" -le 0 ]; then
                    _action_weapon_special
                else
                    print_msg warn "Weapon special on cooldown! (${PLAYER[spec_cooldown]} turns)"
                    sleep 0.6
                    continue
                fi
                ;;
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
            PLAYER[xp_from_kills]=$(( ${PLAYER[xp_from_kills]:-0} + rune_gain ))
            enemy_loot
            # Clear poison on victory
            PLAYER[poison_status]=0
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
            combat_log_add "${ENEMY[name]} dealt ${ENEMY_DAMAGE} damage to you"
            # Malenia phase 2 heals on any hit
            if [ "${ENEMY[id]}" = "malenia" ] && [ "${ENEMY[phase]}" -eq 2 ]; then
                local malenia_heal=$(( ENEMY_DAMAGE / 3 ))
                ENEMY[hp]=$(( ENEMY[hp] + malenia_heal ))
                [ "${ENEMY[hp]}" -gt "${ENEMY[max_hp]}" ] && ENEMY[hp]="${ENEMY[max_hp]}"
                print_msg warn "${ENEMY[name]} absorbs your vitality! Healed ${malenia_heal} HP!"
            fi
        fi

        if player_dead; then
            PLAYER[hp]=0
            PLAYER[deaths]=$(( PLAYER[deaths] + 1 ))
            show_death_screen
            COMBAT_RESULT="lose"
            return
        fi

        # Show combat log
        combat_log_show

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

    # Backstab: if player dodged last turn, +50% damage
    if [ "${PLAYER[backstab_ready]:-0}" -eq 1 ]; then
        local backstab_bonus=$(( dmg * 50 / 100 ))
        dmg=$(( dmg + backstab_bonus ))
        print_msg good "BACKSTAB! +${backstab_bonus} bonus damage!"
        PLAYER[backstab_ready]=0
        combat_log_add "Backstab! Dealt ${dmg} damage"
    fi

    # Critical hit: 10% chance for 2x damage
    local is_crit=0
    if [ $(( RANDOM % 100 )) -lt 10 ]; then
        dmg=$(( dmg * 2 ))
        is_crit=1
    fi

    printf "  You strike for "; damage_number "$dmg" "$is_crit"; printf " damage!\n"
    ENEMY[hp]=$(( ENEMY[hp] - dmg ))
    combat_log_add "Light attack: ${dmg} damage${is_crit:+ (CRIT!)}"
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

    # Backstab
    if [ "${PLAYER[backstab_ready]:-0}" -eq 1 ]; then
        local backstab_bonus=$(( dmg * 50 / 100 ))
        dmg=$(( dmg + backstab_bonus ))
        print_msg good "BACKSTAB! +${backstab_bonus} bonus damage!"
        PLAYER[backstab_ready]=0
    fi

    # Critical hit
    local is_crit=0
    if [ $(( RANDOM % 100 )) -lt 10 ]; then
        dmg=$(( dmg * 2 ))
        is_crit=1
    fi

    printf "  You SLAM for "; damage_number "$dmg" "$is_crit"; printf " damage!\n"
    ENEMY[hp]=$(( ENEMY[hp] - dmg ))
    if [ $(( RANDOM % 100 )) -lt 35 ]; then
        ENEMY[stunned]=1
        print_msg good "Enemy staggered by the heavy blow!"
    fi
    combat_log_add "Heavy attack: ${dmg} damage${is_crit:+ (CRIT!)}"
}

_action_dodge() {
    if [ "${PLAYER[stamina]}" -lt 15 ]; then
        print_msg warn "Not enough stamina to dodge! (need 15)"
        sleep 0.8
        return 1
    fi
    PLAYER[stamina]=$(( PLAYER[stamina] - 15 ))
    PLAYER[is_dodging]=1
    PLAYER[backstab_ready]=1  # Next attack after dodge gets backstab bonus
    print_msg info "You prepare to dodge roll..."
    combat_log_add "Dodge roll prepared"
}

_action_guard() {
    if [ "${PLAYER[stamina]}" -lt 5 ]; then
        print_msg warn "Not enough stamina to guard!"
        sleep 0.8
        return 1
    fi
    PLAYER[stamina]=$(( PLAYER[stamina] - 5 ))
    PLAYER[is_guarding]=1
    PLAYER[backstab_ready]=0  # Guarding cancels backstab
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

    # Critical hit for spells too
    local is_crit=0
    if [ $(( RANDOM % 100 )) -lt 10 ]; then
        total=$(( total * 2 ))
        is_crit=1
    fi

    if [ "$hits" -gt 1 ]; then
        printf "  $(spell_name "$spell_id") — ${hits} hits × ${per_hit} = "
        damage_number "$total" "$is_crit"
        printf " total!\n"
    else
        printf "  $(spell_name "$spell_id") — "; damage_number "$total" "$is_crit"; printf " damage!\n"
    fi
    ENEMY[hp]=$(( ENEMY[hp] - total ))
    combat_log_add "Spell: ${total} damage"
}

_action_weapon_special() {
    local sta_cost; sta_cost=$(weapon_sta_heavy "${PLAYER[weapon]}")
    local spec_cost=$(( sta_cost * 2 ))
    if [ "${PLAYER[stamina]}" -lt "$spec_cost" ]; then
        print_msg warn "Not enough stamina for weapon special! (need $spec_cost)"
        sleep 0.8
        return 1
    fi
    PLAYER[stamina]=$(( PLAYER[stamina] - spec_cost ))
    PLAYER[spec_cooldown]=3

    local dmg; dmg=$(calc_attack_damage heavy)
    dmg=$(( dmg * 25 / 10 ))  # 2.5x heavy attack

    # Critical
    local is_crit=0
    if [ $(( RANDOM % 100 )) -lt 10 ]; then
        dmg=$(( dmg * 2 ))
        is_crit=1
    fi

    local wname; wname=$(weapon_name "${PLAYER[weapon]}")
    printf "  ${ORANGE}${wname} SPECIAL!${NC} "; damage_number "$dmg" "$is_crit"; printf " damage!\n"
    ENEMY[hp]=$(( ENEMY[hp] - dmg ))
    ENEMY[stunned]=1
    print_msg good "Enemy staggered by the special attack!"
    combat_log_add "Weapon special: ${dmg} damage"
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
        cure_poison)
            PLAYER[poison_status]=0
            print_msg good "Used $(consumable_name "$item_id"). Poison cured!"
            ;;
        throwable)
            # Fire pots etc: deal direct damage to enemy
            local throw_dmg="$value"
            # Critical for throwables
            local is_crit=0
            if [ $(( RANDOM % 100 )) -lt 10 ]; then
                throw_dmg=$(( throw_dmg * 2 ))
                is_crit=1
            fi
            printf "  Threw $(consumable_name "$item_id")! "; damage_number "$throw_dmg" "$is_crit"; printf " damage!\n"
            ENEMY[hp]=$(( ENEMY[hp] - throw_dmg ))
            combat_log_add "Throwable: ${throw_dmg} damage"
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
