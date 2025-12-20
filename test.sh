#!/usr/bin/env bash

readonly noc="\033[0m"
readonly red="\033[31m"
readonly grn="\033[32m"
readonly yel="\033[33m"
readonly blu="\033[34m"
readonly cyn="\033[36m"
readonly bld="\033[1m"

# Get terminal width, but cap it at 85
WIDTH=$(tput cols)
[ "$WIDTH" -gt 90 ] && WIDTH=85

# Logic to truncate and pad
print_line() {
    local symbol="$1"
    local color="$2"
    local raw_msg="$3"
    local out_stream="${4:-1}" # Default to stdout (1)

    # 1. Truncate the message to the WIDTH
    local msg="${raw_msg:0:$((WIDTH-3))}"
    local msg_len=${#msg}

    # 2. Calculate dots (if any)
    local dots_needed=$((WIDTH - msg_len))
    local dots=""
    if [ "$dots_needed" -gt 0 ]; then
        dots=$(printf '%*s' "$dots_needed" '' | tr ' ' '.')
    fi

    # 3. Print the formatted line
    printf "${color}${bld}[%s]>${noc}%s${color}${bld}%s<[%s]${noc}\n" \
        "$symbol" "$msg" "$dots" "$symbol" >&"$out_stream"
}

info()    { print_line "i" "$blu" "$1"; }
success() { print_line "✓" "$grn" "$1"; }
warn()    { print_line "!" "$yel" "$1"; }
error()   { print_line "X" "$red" "$1" 2; } # Directs to stderr (2)

# --- Testing ---
info "Short message"
info "This is a very long message that would normally wrap to the next line but now it will be truncated at the width limit of the script."
success "Operation completed successfully"
error "This error message is also extremely long to demonstrate that the truncation logic works across all function types."
