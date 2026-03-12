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
out_info()    { print_line "i" "$blu" "$1"       ;  }
out_success() { print_line "✓" "$grn" "$1"       ;  }
out_warn()    { print_line "!" "$yel" "$1"       ;  }
out_error()   { print_line "X" "$red" "$1" 2     ;  }
out_banner()    { echo -e "${cyn}${bld}$1${noc}" ;  }

# loggin into logfile
log_info()      { echo "[ INFO ]  $1" >> "$LOG_FILE";       }
log_success()   { echo "[SUCCESS] $1" >> "$LOG_FILE"       &&
                  echo ""             >> "$LOG_FILE";       }
log_warn()      { echo "[ WARN ]  $1" >> "$LOG_FILE";       }
log_error()     { echo "[ ERROR ] $1" >> "$LOG_FILE" 2>&1;  }
log_banner()    { echo "[BANNER ] $1" >> "$LOG_FILE";       }

# both logs together
info()      { out_info "$1"     && log_info "$1"    ;   }
success()   { out_success "$1"  && log_success "$1" ;   }
warn()      { out_warn "$1"     && log_warn "$1"    ;   }
error()     { out_error "$1"    && log_error "$1"   ;   }
banner()    { out_banner "$1"   && log_banner "$1"  ;   }

readonly LOG_FILE="/tmp/.3xui_log"

check_bbr_available() {
    if sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -q bbr; then
        success "BBR is Available"
        return 0
    fi

    return 1
}

check_current_settings() {
    info "Checking current network settings..."
    echo ""

    echo -e "${cyn}Current Configuration:${noc}"

    local qdisc
    qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "not set")
    info "  Queue Discipline:       $qdisc"

    local congestion
    congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "not set")
    info "  TCP Congestion Control: $congestion"

    local fastopen
    fastopen=$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo "not set")
    info "  TCP Fast Open:          $fastopen"

    local ip_forward
    ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "not set")
    info "  IPv4 Forwarding:        $ip_forward"
}

# Applying network optimizations
apply_network_optimizations() {
    info "Applying network optimizations to /etc/sysctl.d/99-net-optimization-custom.conf"

    local sysctl_conf="/etc/sysctl.d/99-net-optimization-custom.conf"

    # backup working file
    if [ -f "$sysctl_conf" ]; then
        sudo cp $sysctl_conf /etc/sysctl.conf.backup
        info "Backed up to /etc/sysctl.d/99-net-optimization-custom.conf.backup file"
    fi

    if sudo grep -q "# 3X-UI Network Optimization" "$sysctl_conf" 2>/dev/null; then
        warn "Network optimizations already present in $sysctl_conf"
        echo -n "Reapply optimizations (NOT recomended) [y/N]: "
        local reapply
        read reapply
        reapply=${reapply:-N}
        if [[ ! "$reapply" =~ ^[Yy]$ ]]; then
            info "Keeping existing network settings"
            return 0
        fi

        info "Removing old optimizations"
        sudo sed -i '/# 3X-UI Network Optimization/,/# End 3X-UI Network Optimization/d' "$sysctl_conf"
    fi

    info "Adding network optimizations"

    cat << 'EOF' | sudo tee -a "$sysctl_conf" >> "$LOG_FILE"
# ═══════════════════════════════════════════════════════════════════════════
# 3X-UI Network Optimizations
# Applied for VPN/Proxy performance enhancement
# ═══════════════════════════════════════════════════════════════════════════

# --- General performance ---
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1

# --- Connection handling ---
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_window_scaling=1
net.core.netdev_max_backlog=4096

# --- Buffer sizes ---
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864

# --- Disable slow TCP features ---
net.ipv4.tcp_slow_start_after_idle=0

# End 3X-UI Network Optimizations
EOF

    success "Network optimizations added to $sysctl_conf"
}

load_sysctl_settings() {
    info "Loading sysctl settings"

    if sudo sysctl --system >> "$LOG_FILE" 2>&1; then
        success "sysctl settings loaded successfully!"
    else
        warn "Some sysctl settings may have failed to load"
    fi
}

verify_optimizations() {
    info "Verifying network optimizations"

    echo -e "${grn}Applied Configuration:${noc}"

    local qdisc
    qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    if [ "$qdisc" == "fq" ]; then
        success "  ✓ Queue Discipline:       $qdisc"
    else
        warn "  ✗ Queue Discipline: $qdisc (expected: fq)"
    fi

    local congestion
    congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [ "$congestion" == "bbr" ]; then
        success "  ✓ TCP Congestion Control: $congestion"
    else
        warn "  ✗ TCP Congestion Control: $congestion (expected: bbr)"
    fi

    local fastopen
    fastopen=$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null)
    if [ "$fastopen" == "3" ]; then
        success "  ✓ TCP Fast Open:          $fastopen"
    else
        warn "  ! TCP Fast Open:         $fastopen (expected: 3)"
    fi

    local ip_forward
    ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)
    if [ "$ip_forward" == "1" ]; then
        success "  ✓ IPv4 Forwarding: Enabled"
    else
        warn "  ✗ IPv4 Forwarding: Disabled"
    fi

    local ipv6_forward
    ipv6_forward=$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null)
    if [ "$ipv6_forward" == "1" ]; then
        success "  ✓ IPv6 Forwarding: Enabled"
    else
        warn "  ! IPv6 Forwarding: Disabled"
    fi

    echo ""
}

show_performance_info() {
    echo ""
    banner "═══════════════════════════════════════════════════════════"
    banner "           Expected Performance Improvements"
    banner "═══════════════════════════════════════════════════════════"
    echo ""
    echo -e "${grn}What was optimized:${noc}"
    echo ""
    echo "  🚀 ${bld}BBR Congestion Control${noc}"
    echo "     → Smarter bandwidth usage, higher throughput"
    echo "     → Better performance on high-latency connections"
    echo ""
    echo "  📦 ${bld}Fair Queue (FQ) Scheduling${noc}"
    echo "     → Fair packet scheduling across connections"
    echo "     → Reduced latency spikes under load"
    echo ""
    echo "  💾 ${bld}Increased Buffer Sizes${noc}"
    echo "     → Prevents packet loss under high traffic"
    echo "     → Improved handling of large transfers"
    echo ""
    echo "  ⚡ ${bld}TCP Fast Open & Reuse${noc}"
    echo "     → Faster connection establishment"
    echo "     → Efficient socket recycling"
    echo ""
    echo "  🌐 ${bld}IP Forwarding Enabled${noc}"
    echo "     → Essential for VPN/proxy functionality"
    echo "     → Proper packet routing"
    echo ""
    echo -e "${yel}Expected Results:${noc}"
    echo "  • Shadowsocks/VLESS: 20-30x speed improvement possible"
    echo "  • Better stability on long-distance connections"
    echo "  • Lower latency and reduced jitter"
    echo "  • Improved throughput under load"
    echo ""
    banner "═══════════════════════════════════════════════════════════"
}

main() {
    banner "═══════════════════════════════════════════════════════════"
    banner "           Network Optimization Setup"
    banner "═══════════════════════════════════════════════════════════"
    echo ""

    info "This will apply kernel-level network optimizations for VPN/Proxy servers"
    echo ""
    echo -e "${cyn}Optimizations include:${noc}"
    echo "  • Google BBR congestion control"
    echo "  • Fair Queue (FQ) packet scheduling"
    echo "  • Increased TCP buffer sizes"
    echo "  • TCP Fast Open"
    echo "  • Connection handling improvements"
    echo "  • IP forwarding for VPN/proxy traffic"
    echo ""

    # Check current settings
    check_current_settings

    # Check if BBR is available
    if ! check_bbr_available; then
        warn "BBR congestion control may not be available on this kernel"
        warn "Kernel version $(uname -r)"
        warn "BBR requires kernel 4.9 or higher"

        local try_load
        echo -n "Try to load kernel module (BBR) [Y/n]: "
        read try_load
        try_load=${try_load:-Y}
        if [[ "$try_load" =~ ^[Yy]$ ]]; then
            info "Trying '${cyn}sudo modprobe tcp_bbr${noc}'"
            sudo modprobe tcp_bbr
        fi

        if ! check_bbr_available; then
            warn "Attempt to load BBR module was not successful"
        fi

        echo ""
        local continue_no_bbr
        read -p "Continue anyway? [y/N]: " continue_no_bbr
        if [[ ! "$continue_no_bbr" =~ ^[Yy]$ ]]; then
            info "Skipping network optimization"
            return 0
        fi
    fi

    local apply_opt
    read -p "Apply network optimizations? [Y/n]: " apply_opt
    apply_opt=${apply_opt:-Y}

    if [[ ! "$apply_opt" =~ ^[Yy]$ ]]; then
        info "Skipping network optimization"
        return 0
    fi

    # Apply optimizations
    apply_network_optimizations

    # Load settings
    load_sysctl_settings

    # Verify
    echo ""
    verify_optimizations

    # Show expected improvements
    show_performance_info

    success "Network optimization completed!"

    return 0
}

main "$@"
