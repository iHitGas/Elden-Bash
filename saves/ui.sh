#!/usr/bin/env bash
# UI utilities - colors, drawing, menus

RED='\033[0;31m'
LRED='\033[1;31m'
GREEN='\033[0;32m'
LGREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
LBLUE='\033[1;34m'
MAGENTA='\033[0;35m'
LMAGENTA='\033[1;35m'
CYAN='\033[0;36m'
LCYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
DARK='\033[1;30m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

GOLD='\033[38;5;220m'
ORANGE='\033[38;5;208m'
BLOOD='\033[38;5;124m'

get_term_width() {
    tput cols 2>/dev/null || echo 80
}

repeat_char() {
    local char="$1"
    local count="$2"
    printf "%${count}s" | tr ' ' "$char"
}

draw_line() {
    local char="${1:-─}"
    local color="${2:-$DARK}"
    local w
    w=$(get_term_width)
    printf "${color}$(repeat_char "$char" "$w")${NC}\n"
}

center_text() {
    local text="$1"
    local color="${2:-$WHITE}"
    local w
    w=$(get_term_width)
    local len=${#text}
    local pad=$(( (w - len) / 2 ))
    printf "%${pad}s${color}%s${NC}\n" "" "$text"
}

draw_title_banner() {
    local w
    w=$(get_term_width)
    clear
    printf "${DARK}$(repeat_char '═' "$w")${NC}\n"
    center_text "" ""
    center_text "▓▓▓▓▓   ▓      ▓▓▓▓  ▓▓▓▓▓  ▓▓▓▓▓   ▓▓▓▓   ▓▓▓   ▓▓▓" "$GOLD"
    center_text "▓       ▓      ▓  ▓  ▓      ▓  ▓    ▓  ▓  ▓   ▓  ▓" "$GOLD"
    center_text "▓▓▓▓    ▓      ▓  ▓  ▓▓▓▓   ▓  ▓    ▓  ▓  ▓   ▓  ▓▓▓" "$YELLOW"
    center_text "▓       ▓      ▓  ▓  ▓      ▓  ▓    ▓  ▓  ▓   ▓  ▓" "$YELLOW"
    center_text "▓▓▓▓▓   ▓▓▓▓▓  ▓▓▓▓  ▓▓▓▓▓  ▓  ▓     ▓▓▓   ▓▓▓   ▓" "$ORANGE"
    center_text "" ""
    center_text "▓▓▓▓    ▓▓▓   ▓▓▓▓  ▓  ▓" "$GOLD"
    center_text "▓   ▓  ▓   ▓  ▓     ▓  ▓" "$YELLOW"
    center_text "▓▓▓▓   ▓▓▓▓▓  ▓▓▓   ▓▓▓▓" "$ORANGE"
    center_text "▓   ▓  ▓   ▓  ▓     ▓  ▓" "$YELLOW"
    center_text "▓▓▓▓   ▓   ▓  ▓▓▓▓  ▓  ▓" "$GOLD"
    center_text "" ""
    center_text "A Bash Souls-like Adventure" "$GRAY"
    center_text "" ""
    printf "${DARK}$(repeat_char '═' "$w")${NC}\n"
}

show_status_bar() {
    local w
    w=$(get_term_width)
    printf "${DARK}$(repeat_char '─' "$w")${NC}\n"
    # HP bar
    local hp="${PLAYER[hp]}"
    local max_hp="${PLAYER[max_hp]}"
    local fp="${PLAYER[fp]}"
    local max_fp="${PLAYER[max_fp]}"
    local sta="${PLAYER[stamina]}"
    local max_sta="${PLAYER[max_stamina]}"
    local runes="${PLAYER[runes]}"
    local level="${PLAYER[level]}"
    local loc="${PLAYER[location_name]}"

    printf " ${BLOOD}HP${NC} $(health_bar "$hp" "$max_hp" 15) ${hp}/${max_hp}   "
    printf "${BLUE}FP${NC} $(mana_bar "$fp" "$max_fp" 10) ${fp}/${max_fp}   "
    printf "${GREEN}STA${NC} $(sta_bar "$sta" "$max_sta" 10) ${sta}/${max_sta}\n"
    printf " ${GOLD}Runes: %d${NC}   ${WHITE}Lv: %d${NC}   ${GRAY}%s${NC}\n" "$runes" "$level" "$loc"
    printf "${DARK}$(repeat_char '─' "$w")${NC}\n"
}

health_bar() {
    local cur="$1" max="$2" width="$3"
    local filled=$(( cur * width / max ))
    [ $filled -lt 0 ] && filled=0
    [ $filled -gt $width ] && filled=$width
    local empty=$(( width - filled ))
    local pct=$(( cur * 100 / max ))
    local color=$LGREEN
    [ $pct -le 50 ] && color=$YELLOW
    [ $pct -le 25 ] && color=$LRED
    printf "${color}$(repeat_char '█' $filled)${DARK}$(repeat_char '░' $empty)${NC}"
}

mana_bar() {
    local cur="$1" max="$2" width="$3"
    [ "$max" -eq 0 ] && { printf "${DARK}$(repeat_char '░' $width)${NC}"; return; }
    local filled=$(( cur * width / max ))
    [ $filled -lt 0 ] && filled=0
    [ $filled -gt $width ] && filled=$width
    local empty=$(( width - filled ))
    printf "${LBLUE}$(repeat_char '█' $filled)${DARK}$(repeat_char '░' $empty)${NC}"
}

sta_bar() {
    local cur="$1" max="$2" width="$3"
    local filled=$(( cur * width / max ))
    [ $filled -lt 0 ] && filled=0
    [ $filled -gt $width ] && filled=$width
    local empty=$(( width - filled ))
    printf "${LGREEN}$(repeat_char '█' $filled)${DARK}$(repeat_char '░' $empty)${NC}"
}

press_key() {
    printf "\n${DIM}[ Press any key ]${NC}"
    read -r -s -n 1
    echo
}

ask_menu() {
    # Display goes to stderr so it's visible even when called inside $(...)
    # Only the chosen number is echoed to stdout for capture
    local title="$1"; shift
    local opts=("$@")
    local w
    w=$(get_term_width)

    {
        printf "\n${GOLD}$(repeat_char '─' "$w")${NC}\n"
        printf "${YELLOW}${BOLD}  %s${NC}\n" "$title"
        printf "${GOLD}$(repeat_char '─' "$w")${NC}\n"
        for i in "${!opts[@]}"; do
            printf "  ${CYAN}[%d]${NC} %s\n" "$((i+1))" "${opts[$i]}"
        done
        printf "\n${WHITE}> ${NC}"
    } >&2
    local choice
    read -r choice
    echo "$choice"
}

print_msg() {
    local type="$1"; shift
    local msg="$*"
    case "$type" in
        info)   printf "  ${CYAN}▶ %s${NC}\n" "$msg" ;;
        good)   printf "  ${LGREEN}✓ %s${NC}\n" "$msg" ;;
        warn)   printf "  ${YELLOW}⚠ %s${NC}\n" "$msg" ;;
        bad)    printf "  ${LRED}✗ %s${NC}\n" "$msg" ;;
        boss)   printf "\n  ${ORANGE}${BOLD}☠ %s${NC}\n\n" "$msg" ;;
        lore)   printf "\n  ${DIM}${GRAY}「 %s 」${NC}\n\n" "$msg" ;;
        gold)   printf "  ${GOLD}★ %s${NC}\n" "$msg" ;;
        *)      printf "  %s\n" "$msg" ;;
    esac
}

show_enemy_bar() {
    local name="${1}"
    local hp="${2}"
    local max_hp="${3}"
    local w
    w=$(get_term_width)
    local pct=$(( hp * 100 / max_hp ))
    local bar_w=30
    local filled=$(( hp * bar_w / max_hp ))
    [ $filled -lt 0 ] && filled=0
    [ $filled -gt $bar_w ] && filled=$bar_w
    local empty=$(( bar_w - filled ))
    local color=$LRED
    [ $pct -ge 60 ] && color=$ORANGE
    [ $pct -ge 80 ] && color=$YELLOW
    printf "\n  ${BOLD}${WHITE}%s${NC}\n" "$name"
    printf "  ${BLOOD}HP${NC} ${color}$(repeat_char '█' $filled)${DARK}$(repeat_char '░' $empty)${NC} ${hp}/${max_hp}\n\n"
}

animate_text() {
    local text="$1"
    local delay="${2:-0.03}"
    local color="${3:-$WHITE}"
    printf "${color}"
    while IFS= read -r -n1 char; do
        printf "%s" "$char"
        sleep "$delay"
    done <<< "$text"
    printf "${NC}\n"
}

show_death_screen() {
    clear
    sleep 0.5
    local w
    w=$(get_term_width)
    printf "\n\n\n"
    printf "${BLOOD}"
    center_text "$(repeat_char '─' 40)" "$BLOOD"
    printf "\n"
    center_text "YOU DIED" "$BLOOD"
    printf "\n"
    center_text "$(repeat_char '─' 40)" "$BLOOD"
    printf "${NC}\n\n"
    center_text "Your runes linger at the place of your death." "$GRAY"
    printf "\n\n"
    sleep 2
    press_key
}

show_victory_screen() {
    local name="$1"
    clear
    sleep 0.3
    printf "\n\n\n"
    center_text "╔══════════════════════════════════════╗" "$GOLD"
    center_text "║                                      ║" "$GOLD"
    center_text "║        GREAT ENEMY FELLED            ║" "$GOLD"
    center_text "║                                      ║" "$GOLD"
    printf "${GOLD}"
    center_text "║   $name   " "$GOLD"
    center_text "║                                      ║" "$GOLD"
    center_text "╚══════════════════════════════════════╝" "$GOLD"
    printf "${NC}\n\n"
    sleep 1.5
    press_key
}
