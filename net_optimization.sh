#!/usr/bin/env bash

readonly noc=$'\033[0m'
readonly red=$'\033[31m'
readonly grn=$'\033[32m'
readonly yel=$'\033[33m'
readonly blu=$'\033[34m'
readonly cyn=$'\033[36m'
readonly bld=$'\033[1m'

WIDTH=$(tput cols 2>/dev/null || echo 80)
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

# logging to the terminal
info()    { print_line "i" "$blu" "$1"       ;  }
success() { print_line "✓" "$grn" "$1"       ;  }
warn()    { print_line "!" "$yel" "$1"       ;  }
error()   { print_line "X" "$red" "$1" 2     ;  }
banner()    { echo -e "${cyn}${bld}$1${noc}" ;  }

# loggin into logfile
log_info()      { echo "[ INFO ]  $1" >> "$LOG_FILE";       }
log_success()   { echo "[SUCCESS] $1" >> "$LOG_FILE"       &&
                  echo ""             >> "$LOG_FILE";       }
log_warn()      { echo "[ WARN ]  $1" >> "$LOG_FILE";       }
log_error()     { echo "[ ERROR ] $1" >> "$LOG_FILE" 2>&1;  }
log_banner()    { echo "[BANNER ] $1" >> "$LOG_FILE";       }

readonly LOG_FILE="/tmp/.3xui_log"

check_current_settings() {
    info "Checking current network settings..."
    log_info "Checking current network settings..."

    log_info "Checking current network settings..."
    echo ""

    echo -e "${CYAN}Current Configuration:${NC}"

    local qdisc
    qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "not set")
    echo "  Queue Discipline: $qdisc"
    log_info "  Queue Discipline: $qdisc"

    local congestion
    congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "not set")
    echo "  TCP Congestion Control: $congestion"
    log_info "  TCP Congestion Control: $congestion"

    local fastopen
    fastopen=$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo "not set")
    log_info "  TCP Fast Open: $fastopen"

    local ip_forward
    ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "not set")
    echo "  IPv4 Forwarding: $ip_forward"
    log_info "  IPv4 Forwarding: $ip_forward"
}

# Applying network optimizations
apply_network_optimization() {
    info "Applying network optimizations to /etc/sysctl.conf"
    log_info "Applying network optimizations to /etc/sysctl.conf"

    local sysctl_conf="/etc/sysctl.conf"

    # backup working file
    if [ -f "$sysctl_conf" ]; then
        sudo cp $sysctl_conf /etc/sysctl.conf.backup
        info "Backed up to /etc/sysctl.conf.backup file"
        log_info "Backed up to /etc/sysctl.conf.backup file"
    fi

    if sudo grep -q "# 3X-UI Network Optimization" "$sysctl_conf" 2>/dev/null; then
        warn "Network"
}
