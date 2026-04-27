#!/usr/bin/env bash
# Items, weapons, armor definitions and inventory management
# Weapon scales stored as integers (×10), e.g. 0.7 → 7

# ── Weapon definitions ────────────────────────────────────────────────────────
# Format: NAME|BASE_DMG|STR_SCALE|DEX_SCALE|INT_SCALE|STA_LIGHT|STA_HEAVY|TYPE|DESC
# Scales are ×10 integers: 7 = 0.7 scaling
declare -A WEAPONS
WEAPONS[broken_sword]="Broken Sword|8|5|3|0|8|15|slash|A cracked blade. Better than nothing."
WEAPONS[short_sword]="Short Sword|15|6|5|0|10|18|slash|A reliable short blade."
WEAPONS[longsword]="Longsword|22|7|6|0|12|22|slash|Balanced sword, scales well with STR and DEX."
WEAPONS[greatsword]="Greatsword|38|10|3|0|18|30|slash|Heavy weapon of immense power. Requires high STR."
WEAPONS[bastard_sword]="Bastard Sword|30|9|5|0|15|26|slash|Versatile heavy sword."
WEAPONS[dagger]="Dagger|10|2|9|0|6|12|pierce|Fast and light. Great for dex builds."
WEAPONS[scimitar]="Scimitar|18|4|8|0|8|16|slash|A curved blade favoring dexterity."
WEAPONS[battle_axe]="Battle Axe|26|9|4|0|14|24|strike|Heavy axe, strong against armor."
WEAPONS[magic_staff]="Glintstone Staff|12|0|0|12|10|16|magic|Channels glintstone sorceries. Scales with INT."
WEAPONS[sacred_seal]="Sacred Seal|10|3|0|8|10|16|holy|Used to cast incantations."
WEAPONS[club]="Club|20|10|0|0|12|22|strike|Simple but effective. High poise damage."
WEAPONS[spear]="Spear|20|6|7|0|10|18|pierce|Longer reach, good for thrusting."

weapon_name()      { cut -d'|' -f1 <<< "${WEAPONS[$1]}"; }
weapon_base_dmg()  { cut -d'|' -f2 <<< "${WEAPONS[$1]}"; }
weapon_str_scale() { cut -d'|' -f3 <<< "${WEAPONS[$1]}"; }
weapon_dex_scale() { cut -d'|' -f4 <<< "${WEAPONS[$1]}"; }
weapon_int_scale() { cut -d'|' -f5 <<< "${WEAPONS[$1]}"; }
weapon_sta_light() { cut -d'|' -f6 <<< "${WEAPONS[$1]}"; }
weapon_sta_heavy() { cut -d'|' -f7 <<< "${WEAPONS[$1]}"; }
weapon_type()      { cut -d'|' -f8 <<< "${WEAPONS[$1]}"; }
weapon_desc()      { cut -d'|' -f9 <<< "${WEAPONS[$1]}"; }

calc_weapon_damage() {
    local weapon_id="$1"
    local str="${2:-10}"
    local dex="${3:-10}"
    local int_val="${4:-10}"
    local base; base=$(weapon_base_dmg "$weapon_id")
    local ss; ss=$(weapon_str_scale "$weapon_id")
    local ds; ds=$(weapon_dex_scale "$weapon_id")
    local is_; is_=$(weapon_int_scale "$weapon_id")
    # Scales are ×10 integers, so bonus = stat * scale / 10
    local bonus_str=$(( str * ss / 10 ))
    local bonus_dex=$(( dex * ds / 10 ))
    local bonus_int=$(( int_val * is_ / 10 ))
    echo $(( base + bonus_str + bonus_dex + bonus_int ))
}

# ── Armor definitions ─────────────────────────────────────────────────────────
# Format: NAME|PHYS_DEF|MAG_DEF|WEIGHT|DESCRIPTION
declare -A ARMORS
ARMORS[no_armor]="No Armor|0|0|0|Bare skin. Maximum mobility."
ARMORS[light_wrap]="Tattered Wrap|3|1|1|Strips of cloth. Minimal protection."
ARMORS[vagabond_set]="Vagabond's Armor|8|3|3|Sturdy traveler's garb."
ARMORS[soldier_set]="Soldier's Armor|12|2|5|Standard issue armor of the Erdtree soldiers."
ARMORS[knight_set]="Knight's Armor|18|5|8|Heavy plate worn by knights of the Golden Order."
ARMORS[lordsworn_set]="Lordsworn's Armor|14|3|6|Armor of soldiers sworn to Godrick."
ARMORS[raya_lucaria]="Raya Lucarian Robe|5|12|3|Sorcerer's robe from the Academy."
ARMORS[crucible_set]="Crucible Knight Armor|22|8|10|Revered armor of ancient knights."
ARMORS[bull_goat]="Bull-Goat Armor|30|6|15|The heaviest armor in the Lands Between."

armor_name()   { cut -d'|' -f1 <<< "${ARMORS[$1]}"; }
armor_phys()   { cut -d'|' -f2 <<< "${ARMORS[$1]}"; }
armor_mag()    { cut -d'|' -f3 <<< "${ARMORS[$1]}"; }
armor_weight() { cut -d'|' -f4 <<< "${ARMORS[$1]}"; }
armor_desc()   { cut -d'|' -f5 <<< "${ARMORS[$1]}"; }

# ── Consumables ───────────────────────────────────────────────────────────────
# Format: NAME|EFFECT|VALUE|DESCRIPTION
declare -A CONSUMABLES
CONSUMABLES[rowa_raisin]="Rowa Raisin|hp|15|A dried rowa fruit. Restores some HP."
CONSUMABLES[exalted_flesh]="Exalted Flesh|str_buff|5|Temporarily boosts STR for one battle."
CONSUMABLES[uplifting_aroma]="Uplifting Aromatic|def_buff|10|Temporarily boosts defense."
CONSUMABLES[starlight_shards]="Starlight Shards|fp|20|Restores FP using starlight."
CONSUMABLES[cerulean_flask]="Flask of Cerulean Tears|fp|40|Restores a large amount of FP."

consumable_name()   { cut -d'|' -f1 <<< "${CONSUMABLES[$1]}"; }
consumable_effect() { cut -d'|' -f2 <<< "${CONSUMABLES[$1]}"; }
consumable_value()  { cut -d'|' -f3 <<< "${CONSUMABLES[$1]}"; }
consumable_desc()   { cut -d'|' -f4 <<< "${CONSUMABLES[$1]}"; }

# ── Spells ────────────────────────────────────────────────────────────────────
# Format: NAME|FP_COST|BASE_DMG|INT_SCALE(×10)|HITS|DESCRIPTION
declare -A SPELLS
SPELLS[glintstone_pebble]="Glintstone Pebble|10|30|10|1|A basic sorcery that hurls a glintstone pebble."
SPELLS[glintstone_arc]="Glintstone Arc|14|40|11|1|Sweeping arc of glintstone magic."
SPELLS[swift_glintstone]="Swift Glintstone Shard|8|22|9|2|Quick shard cast twice in succession."
SPELLS[great_glintstone]="Great Glintstone Shard|18|55|12|1|A large, powerful sorcery projectile."
SPELLS[rock_sling]="Rock Sling|22|28|10|3|Pulls up debris and hurls it. Three hits."
SPELLS[comet]="Comet|35|120|14|1|A powerful comet of condensed magic."
SPELLS[cannon]="Cannon of Haima|50|160|15|1|Mighty explosion of glintstone magic."

spell_name()  { cut -d'|' -f1 <<< "${SPELLS[$1]}"; }
spell_fp()    { cut -d'|' -f2 <<< "${SPELLS[$1]}"; }
spell_dmg()   { cut -d'|' -f3 <<< "${SPELLS[$1]}"; }
spell_scale() { cut -d'|' -f4 <<< "${SPELLS[$1]}"; }
spell_hits()  { cut -d'|' -f5 <<< "${SPELLS[$1]}"; }
spell_desc()  { cut -d'|' -f6 <<< "${SPELLS[$1]}"; }

# ── Inventory functions ───────────────────────────────────────────────────────
# PLAYER[inventory] = "item_id:count item_id:count ..."

inventory_add() {
    local item_id="$1"
    local count="${2:-1}"
    local inv="${PLAYER[inventory]:-}"
    local new_inv=""
    local found=0

    for entry in $inv; do
        local id="${entry%%:*}"
        local cnt="${entry##*:}"
        if [ "$id" = "$item_id" ]; then
            cnt=$(( cnt + count ))
            new_inv="${new_inv:+$new_inv }${item_id}:${cnt}"
            found=1
        else
            new_inv="${new_inv:+$new_inv }${entry}"
        fi
    done

    if [ "$found" -eq 0 ]; then
        new_inv="${new_inv:+$new_inv }${item_id}:${count}"
    fi

    PLAYER[inventory]="$new_inv"
}

inventory_remove() {
    local item_id="$1"
    local count="${2:-1}"
    local inv="${PLAYER[inventory]:-}"
    local new_inv=""

    for entry in $inv; do
        local id="${entry%%:*}"
        local cnt="${entry##*:}"
        if [ "$id" = "$item_id" ]; then
            cnt=$(( cnt - count ))
            [ "$cnt" -gt 0 ] && new_inv="${new_inv:+$new_inv }${item_id}:${cnt}"
        else
            new_inv="${new_inv:+$new_inv }${entry}"
        fi
    done

    PLAYER[inventory]="$new_inv"
}

inventory_count() {
    local item_id="$1"
    local inv="${PLAYER[inventory]:-}"
    for entry in $inv; do
        if [ "${entry%%:*}" = "$item_id" ]; then
            echo "${entry##*:}"
            return
        fi
    done
    echo 0
}

show_inventory() {
    clear
    printf "\n${GOLD}${BOLD}  ═══ INVENTORY ═══${NC}\n\n"
    printf "  ${WHITE}Equipped Weapon:${NC} %s\n" "$(weapon_name "${PLAYER[weapon]}")"
    printf "  ${WHITE}Equipped Armor:${NC}  %s\n" "$(armor_name "${PLAYER[armor]}")"
    printf "\n  ${YELLOW}Items:${NC}\n"

    local inv="${PLAYER[inventory]:-}"
    if [ -z "$inv" ]; then
        printf "  ${GRAY}(empty)${NC}\n"
    else
        for entry in $inv; do
            local id="${entry%%:*}"
            local cnt="${entry##*:}"
            if [ -n "${CONSUMABLES[$id]+_}" ]; then
                printf "  ${CYAN}%-32s${NC} x%s\n" "$(consumable_name "$id")" "$cnt"
            elif [ -n "${WEAPONS[$id]+_}" ]; then
                printf "  ${LRED}%-32s${NC} x%s\n" "$(weapon_name "$id")" "$cnt"
            elif [ -n "${ARMORS[$id]+_}" ]; then
                printf "  ${LBLUE}%-32s${NC} x%s\n" "$(armor_name "$id")" "$cnt"
            fi
        done
    fi
    printf "\n  ${WHITE}Flasks:${NC} ${BLOOD}Crimson x%d${NC}  ${BLUE}Cerulean x%d${NC}\n" \
        "${PLAYER[crimson_flasks]}" "${PLAYER[cerulean_flasks]}"
    printf "\n  ${GOLD}Runes: %d${NC}\n\n" "${PLAYER[runes]}"
    press_key
}

show_equipment_menu() {
    while true; do
        clear
        printf "\n${GOLD}${BOLD}  ═══ EQUIPMENT ═══${NC}\n\n"
        printf "  Current: ${LRED}%s${NC} | ${LBLUE}%s${NC}\n\n" \
            "$(weapon_name "${PLAYER[weapon]}")" "$(armor_name "${PLAYER[armor]}")"

        local equip_weapons=()
        local equip_armors=()
        for entry in ${PLAYER[inventory]:-}; do
            local id="${entry%%:*}"
            [ -n "${WEAPONS[$id]+_}" ] && equip_weapons+=("$id")
            [ -n "${ARMORS[$id]+_}" ] && equip_armors+=("$id")
        done

        local opts=("Equip Weapon" "Equip Armor" "Back")
        local choice
        choice=$(ask_menu "What to equip?" "${opts[@]}")

        case "$choice" in
            1)
                if [ "${#equip_weapons[@]}" -eq 0 ]; then
                    print_msg warn "No other weapons in inventory."
                    press_key
                else
                    local wopts=()
                    for wid in "${equip_weapons[@]}"; do
                        local dmg; dmg=$(calc_weapon_damage "$wid" "${PLAYER[str]}" "${PLAYER[dex]}" "${PLAYER[int]}")
                        wopts+=("$(weapon_name "$wid") — DMG: $dmg")
                    done
                    wopts+=("Cancel")
                    local wc
                    wc=$(ask_menu "Choose weapon:" "${wopts[@]}")
                    if [[ "$wc" =~ ^[0-9]+$ ]] && [ "$wc" -le "${#equip_weapons[@]}" ]; then
                        local old_w="${PLAYER[weapon]}"
                        local new_w="${equip_weapons[$((wc-1))]}"
                        PLAYER[weapon]="$new_w"
                        inventory_remove "$new_w" 1
                        [ "$old_w" != "broken_sword" ] && inventory_add "$old_w" 1
                        print_msg good "Equipped $(weapon_name "$new_w")."
                        press_key
                    fi
                fi
                ;;
            2)
                if [ "${#equip_armors[@]}" -eq 0 ]; then
                    print_msg warn "No other armor in inventory."
                    press_key
                else
                    local aopts=()
                    for aid in "${equip_armors[@]}"; do
                        aopts+=("$(armor_name "$aid") — DEF: $(armor_phys "$aid")")
                    done
                    aopts+=("Cancel")
                    local ac
                    ac=$(ask_menu "Choose armor:" "${aopts[@]}")
                    if [[ "$ac" =~ ^[0-9]+$ ]] && [ "$ac" -le "${#equip_armors[@]}" ]; then
                        local old_a="${PLAYER[armor]}"
                        local new_a="${equip_armors[$((ac-1))]}"
                        PLAYER[armor]="$new_a"
                        inventory_remove "$new_a" 1
                        [ "$old_a" != "no_armor" ] && inventory_add "$old_a" 1
                        print_msg good "Equipped $(armor_name "$new_a")."
                        press_key
                    fi
                fi
                ;;
            *) return ;;
        esac
    done
}
