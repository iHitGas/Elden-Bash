#!/usr/bin/env bash
# Enemy definitions and state

# Format: NAME|HP|ATK|DEF|RUNES|DESCRIPTION|LOOT_TABLE|IS_BOSS|POISONS
# POISONS: 1 if enemy applies poison, 0 otherwise
declare -A ENEMY_DATA
ENEMY_DATA[hollow]="Hollow Soldier|80|12|2|40|A mindless undead, once a soldier of the Erdtree.|short_sword:15 rowa_raisin:20|0|0"
ENEMY_DATA[godrick_soldier]="Godrick Soldier|120|18|5|80|A soldier sworn to the demented lord Godrick.|soldier_set:10 rowa_raisin:15|0|0"
ENEMY_DATA[grafted_scion]="Grafted Scion|200|25|8|0|A horrific creature assembled from many limbs. An intro to this world.|broken_sword:100|0|0"
ENEMY_DATA[giant_bat]="Giant Bat|60|10|1|30|A large bat that hunts at night.|rowa_raisin:25|0|0"
ENEMY_DATA[wolves]="Pack of Wolves|90|14|3|50|A pack of golden wolves, fierce and loyal.|rowa_raisin:30|0|0"
ENEMY_DATA[crucible_knight]="Crucible Knight|280|30|15|250|An ancient knight who predates the Erdtree itself.|crucible_set:8 battle_axe:12|0|0"
ENEMY_DATA[troll]="Giant Troll|350|35|10|300|A massive troll whose blows can shatter stone.|club:20 uplifting_aroma:15|0|0"
ENEMY_DATA[erdtree_knight]="Tree Sentinel|400|38|18|400|A mounted golden knight who patrols Limgrave.|knight_set:12 spear:15|0|0"
ENEMY_DATA[raya_sorcerer]="Raya Lucarian Sorcerer|150|22|6|150|A sorcerer from the Academy, wielding glintstone.|magic_staff:20 starlight_shards:30|0|0"
ENEMY_DATA[golem]="Ancient Stone Golem|500|40|20|450|A construct animated by ancient glintstone magic.|exalted_flesh:25|0|0"
ENEMY_DATA[dragon_soldier]="Dragon-Burnt Soldier|200|28|8|180|A soldier scorched by dragonfire.|soldier_set:8|0|0"
ENEMY_DATA[leyndell_knight]="Leyndell Knight|350|42|20|380|An elite knight of the capital, Leyndell.|knight_set:10 longsword:10|0|0"

# New enemies
ENEMY_DATA[skeleton_militiaman]="Skeleton Militiaman|70|14|3|45|A rattling skeleton in tattered armor. It rises again unless struck decisively.|short_sword:10 rowa_raisin:20|0|0"
ENEMY_DATA[noble_sorcerer]="Noble Sorcerer|130|24|5|160|A noble-born sorcerer wielding ancient glintstone sorceries.|magic_staff:15 starlight_shards:25|0|0"
ENEMY_DATA[iron_virgin]="Iron Virgin|450|38|22|500|A massive iron maiden construct that drags victims inside its spiked interior.|exalted_flesh:20|0|0"
ENEMY_DATA[ulcerated_tree_spirit]="Ulcerated Tree Spirit|380|35|12|420|A writhing mass of golden flesh, born from the Erdtree's roots.|sacred_seal:8|0|1"
ENEMY_DATA[black_knife_assassin]="Black Knife Assassin|220|40|8|350|A spectral assassin wielding a blade imbued with the Rune of Death.|dagger:20|0|1"
ENEMY_DATA[elden_beast_minion]="Elden Beast Minion|300|32|16|400|A fragment of the Elden Beast, radiating golden light.|starlight_shards:15|0|0"
ENEMY_DATA[misbegotten]="Misbegotten|160|22|4|120|A wretched creature, horned and hunched, wielding a crude weapon.|club:15 rowa_raisin:20|0|0"
ENEMY_DATA[demihuman]="Demihuman|110|16|3|80|A feral humanoid wielding a bone club. Hunts in packs.|rowa_raisin:25 short_sword:10|0|0"

# Bosses
ENEMY_DATA[grafted]="Godrick the Grafted|1200|45|12|2400|Scion of Godrick's lineage, he grafts the limbs of the fallen onto his own body.|greatsword:100 bastard_sword:50|1|0"
ENEMY_DATA[rennala]="Rennala, Queen of the Full Moon|900|38|8|1800|Once the beloved headmistress of the Academy, now sealed in amber by her students.|comet:100 great_glintstone:50|1|0"
ENEMY_DATA[morgott]="Morgott, the Omen King|1800|55|18|4800|The true heir to the Erdtree, hidden in shame beneath Leyndell.|knight_set:100 sacred_seal:50|1|0"
ENEMY_DATA[rykard]="Rykard, Lord of Blasphemy|1600|50|15|3000|A serpent-devoured lord who feeds his blasphemous blade on the bodies of champions.|bloodhound_claw:80 moonveil:50|1|1"
ENEMY_DATA[malenia]="Malenia, Blade of Miquella|1400|60|10|5000|The fiercest Empyrean. She has never known defeat. Her scarlet bloom inflicts rot.|dragon_king_fang:100 ronin_set:80|1|1"

declare -A ENEMY

# Global return for enemy_take_turn
ENEMY_DAMAGE=0

load_enemy() {
    local enemy_id="$1"
    local data="${ENEMY_DATA[$enemy_id]:-}"
    if [ -z "$data" ]; then
        printf "ERROR: Unknown enemy '%s'\n" "$enemy_id" >&2
        return 1
    fi
    ENEMY[id]="$enemy_id"
    ENEMY[name]=$(cut -d'|' -f1 <<< "$data")
    ENEMY[max_hp]=$(cut -d'|' -f2 <<< "$data")
    ENEMY[hp]="${ENEMY[max_hp]}"
    ENEMY[atk]=$(cut -d'|' -f3 <<< "$data")
    ENEMY[def]=$(cut -d'|' -f4 <<< "$data")
    ENEMY[runes]=$(cut -d'|' -f5 <<< "$data")
    ENEMY[desc]=$(cut -d'|' -f6 <<< "$data")
    ENEMY[loot]=$(cut -d'|' -f7 <<< "$data")
    ENEMY[is_boss]=$(cut -d'|' -f8 <<< "$data")
    ENEMY[poisons]=$(cut -d'|' -f9 <<< "$data")
    ENEMY[phase]=1
    ENEMY[telegraphed]=""
    ENEMY[stunned]=0
}

enemy_dead() {
    [ "${ENEMY[hp]}" -le 0 ]
}

enemy_loot() {
    for entry in ${ENEMY[loot]}; do
        local item_id="${entry%%:*}"
        local chance="${entry##*:}"
        local roll=$(( RANDOM % 100 ))
        if [ "$roll" -lt "$chance" ]; then
            inventory_add "$item_id" 1
            local iname=""
            if   [ -n "${WEAPONS[$item_id]+_}" ];     then iname=$(weapon_name "$item_id")
            elif [ -n "${ARMORS[$item_id]+_}" ];      then iname=$(armor_name "$item_id")
            elif [ -n "${CONSUMABLES[$item_id]+_}" ]; then iname=$(consumable_name "$item_id")
            elif [ -n "${SPELLS[$item_id]+_}" ];      then iname=$(spell_name "$item_id")
            fi
            [ -n "$iname" ] && print_msg gold "Dropped: $iname"
        fi
    done
}

boss_special_move() {
    case "${ENEMY[id]}" in
        grafted)  [ "${ENEMY[phase]}" -eq 1 ] && echo "grafted_slam" || echo "grafted_combo" ;;
        rennala)  [ "${ENEMY[phase]}" -eq 1 ] && echo "rennala_orbs" || echo "rennala_moon" ;;
        morgott)  [ "${ENEMY[phase]}" -eq 1 ] && echo "morgott_spear" || echo "morgott_rain" ;;
        rykard)   [ "${ENEMY[phase]}" -eq 1 ] && echo "rykard_bite" || echo "rykard_blasphemy" ;;
        malenia)  [ "${ENEMY[phase]}" -eq 1 ] && echo "malenia_waterfowl" || echo "malenia_scarlet_aeonia" ;;
    esac
}

# Sets global ENEMY_DAMAGE. Also modifies ENEMY state (stunned, phase, telegraphed).
# Args: player_guarding player_dodging
enemy_take_turn() {
    local player_guarding="${1:-0}"
    local player_dodging="${2:-0}"
    ENEMY_DAMAGE=0

    # Stunned: skip turn
    if [ "${ENEMY[stunned]}" -gt 0 ]; then
        ENEMY[stunned]=$(( ENEMY[stunned] - 1 ))
        print_msg warn "${ENEMY[name]} is staggered — unable to act!"
        return
    fi

    local base_atk="${ENEMY[atk]}"
    local is_boss="${ENEMY[is_boss]}"
    local dmg=0
    local avoidable=1

    # Phase 2 transition
    if [ "$is_boss" -eq 1 ] && [ "${ENEMY[phase]}" -eq 1 ] && [ "${ENEMY[hp]}" -le $(( ENEMY[max_hp] / 2 )) ]; then
        ENEMY[phase]=2
        ENEMY[atk]=$(( ENEMY[atk] * 130 / 100 ))
        base_atk="${ENEMY[atk]}"
        print_msg boss "${ENEMY[name]}'s power surges! Phase 2!"
    fi

    # Resolve telegraphed attack
    if [ -n "${ENEMY[telegraphed]}" ]; then
        local special="${ENEMY[telegraphed]}"
        ENEMY[telegraphed]=""
        case "$special" in
            grafted_slam)
                print_msg bad "${ENEMY[name]} SLAMS with grafted arms!"
                dmg=$(( base_atk * 2 + RANDOM % 20 ))
                ;;
            grafted_combo)
                print_msg bad "${ENEMY[name]} unleashes a COMBO!"
                dmg=$(( base_atk + base_atk * 2 / 3 + RANDOM % base_atk ))
                ;;
            rennala_orbs)
                print_msg bad "Glintstone orbs CRASH into you!"
                dmg=$(( base_atk * 3 / 2 + RANDOM % 25 ))
                ;;
            rennala_moon)
                print_msg bad "The FULL MOON sweeps the arena!"
                dmg=$(( base_atk * 2 + RANDOM % 30 ))
                ;;
            morgott_spear)
                print_msg bad "${ENEMY[name]} hurls a GOLDEN SPEAR!"
                dmg=$(( base_atk * 2 ))
                ;;
            morgott_rain)
                print_msg bad "HOLY RAIN falls — you cannot escape!"
                dmg=$(( base_atk + RANDOM % base_atk ))
                avoidable=0
                ;;
            rykard_bite)
                print_msg bad "${ENEMY[name]} devours with the SERPENT's maw!"
                dmg=$(( base_atk * 2 + RANDOM % 25 ))
                ;;
            rykard_blasphemy)
                print_msg bad "${ENEMY[name]} unleashes BLASPHEMOUS BLADE!"
                dmg=$(( base_atk * 5 / 2 + RANDOM % 30 ))
                avoidable=0
                ;;
            malenia_waterfowl)
                print_msg bad "${ENEMY[name]} dances — WATERFOWL DANCE!"
                dmg=$(( base_atk * 2 + RANDOM % 20 ))
                ;;
            malenia_scarlet_aeonia)
                print_msg bad "${ENEMY[name]} blooms — SCARLET AEONIA!"
                dmg=$(( base_atk * 3 + RANDOM % base_atk ))
                avoidable=0
                # Malenia phase 2 heals on hit
                local heal_amt=$(( base_atk / 2 ))
                ENEMY[hp]=$(( ENEMY[hp] + heal_amt ))
                [ "${ENEMY[hp]}" -gt "${ENEMY[max_hp]}" ] && ENEMY[hp]="${ENEMY[max_hp]}"
                print_msg warn "${ENEMY[name]} drains your vitality! Healed ${heal_amt} HP!"
                ;;
        esac
    else
        local roll=$(( RANDOM % 100 ))
        if [ "$is_boss" -eq 1 ] && [ $roll -lt 25 ]; then
            local special; special=$(boss_special_move)
            ENEMY[telegraphed]="$special"
            case "$special" in
                grafted_slam)       print_msg warn "${ENEMY[name]} raises grafted arms — BRACE!" ;;
                grafted_combo)      print_msg warn "${ENEMY[name]} winds up for a COMBO!" ;;
                rennala_orbs)       print_msg warn "Glintstone orbs orbit ${ENEMY[name]}!" ;;
                rennala_moon)       print_msg warn "${ENEMY[name]} channels the FULL MOON..." ;;
                morgott_spear)      print_msg warn "${ENEMY[name]} manifests a golden spear!" ;;
                morgott_rain)       print_msg warn "Holy light gathers above — UNAVOIDABLE!" ;;
                rykard_bite)        print_msg warn "${ENEMY[name]} opens the serpent's maw..." ;;
                rykard_blasphemy)   print_msg warn "Blasphemous energy gathers — UNSTOPPABLE!" ;;
                malenia_waterfowl)  print_msg warn "${ENEMY[name]} readies her blade — WATERFOWL!" ;;
                malenia_scarlet_aeonia) print_msg warn "Scarlet rot gathers — AEONIA approaches!" ;;
            esac
            ENEMY_DAMAGE=0
            return
        elif [ $roll -lt 65 ]; then
            dmg=$(( base_atk + RANDOM % (base_atk / 4 + 1) ))
            print_msg bad "${ENEMY[name]} attacks!"
        elif [ $roll -lt 88 ]; then
            dmg=$(( base_atk * 3 / 2 + RANDOM % 10 ))
            print_msg bad "${ENEMY[name]} swings with full force!"
        else
            print_msg info "${ENEMY[name]} lunges but misses!"
            ENEMY_DAMAGE=0
            return
        fi
    fi

    [ $dmg -le 0 ] && { ENEMY_DAMAGE=0; return; }

    # Dodge check
    if [ "$avoidable" -eq 1 ] && [ "$player_dodging" -eq 1 ]; then
        local dodge_roll=$(( RANDOM % 100 ))
        if [ $dodge_roll -lt 70 ]; then
            print_msg good "You rolled away — EVADED!"
            ENEMY_DAMAGE=0
            return
        else
            print_msg warn "Dodge failed — caught in the attack!"
        fi
    fi

    # Guard check
    if [ "$player_guarding" -eq 1 ]; then
        local blocked=$(( dmg * 45 / 100 ))
        dmg=$(( dmg - blocked ))
        print_msg info "Guarded! Blocked ${blocked} damage."
    fi

    # Subtract player armor
    local player_def
    player_def=$(armor_phys "${PLAYER[armor]}")
    local def_bonus="${PLAYER[def_buff]:-0}"
    dmg=$(( dmg - player_def - def_bonus ))
    [ $dmg -lt 1 ] && dmg=1

    ENEMY_DAMAGE=$dmg

    # Apply poison if this enemy poisons and dealt damage
    if [ "${ENEMY[poisons]}" -eq 1 ] && [ "$dmg" -gt 0 ]; then
        apply_poison_to_player
    fi
}

# Apply poison status to player
apply_poison_to_player() {
    if [ "${PLAYER[poison_status]:-0}" -eq 0 ]; then
        PLAYER[poison_status]=4
        print_msg warn "You have been POISONED! (3 dmg/turn for 4 turns)"
    fi
}
