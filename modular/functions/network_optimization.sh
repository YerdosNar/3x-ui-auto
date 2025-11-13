#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# Network Optimization Module
# Comprehensive kernel-level network tuning for VPN/Proxy servers
# Based on BBR congestion control and high-performance TCP settings
# ═══════════════════════════════════════════════════════════════════════════

# ───────────────────────────────
# Check if BBR is available
# ───────────────────────────────
check_bbr_available() {
    if sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -q bbr; then
        return 0
    fi
    return 1
}

# ───────────────────────────────
# Check current network settings
# ───────────────────────────────
check_current_settings() {
    log_info "Checking current network settings..."
    echo ""
    
    echo -e "${CYAN}Current Configuration:${NC}"
    
    local qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "not set")
    echo "  Queue Discipline: $qdisc"
    
    local congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "not set")
    echo "  TCP Congestion Control: $congestion"
    
    local fastopen=$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo "not set")
    echo "  TCP Fast Open: $fastopen"
    
    local ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "not set")
    echo "  IPv4 Forwarding: $ip_forward"
    
    echo ""
    
    echo "[NETWORK] Current qdisc: $qdisc" >> "$LOG_FILE"
    echo "[NETWORK] Current congestion control: $congestion" >> "$LOG_FILE"
}

# ───────────────────────────────
# Apply Network Optimizations
# ───────────────────────────────
apply_network_optimizations() {
    log_info "Applying network optimizations to /etc/sysctl.conf..."
    echo "[NETWORK] Applying optimizations" >> "$LOG_FILE"
    
    local sysctl_conf="/etc/sysctl.conf"
    
    # Backup original file
    if [ -f "$sysctl_conf" ]; then
        exec_silent "sudo cp $sysctl_conf ${sysctl_conf}.backup.$(date +%s)"
        log_success "Backup created: ${sysctl_conf}.backup.*"
        echo "[NETWORK] Backup created" >> "$LOG_FILE"
    fi
    
    # Check if optimizations already applied
    if sudo grep -q "# 3X-UI Network Optimizations" "$sysctl_conf" 2>/dev/null; then
        log_warn "Network optimizations already present in $sysctl_conf"
        read -p "Reapply optimizations? [y/N]: " REAPPLY
        if [[ ! "$REAPPLY" =~ ^[Yy]$ ]]; then
            log_info "Keeping existing network settings"
            return 0
        fi
        
        # Remove old optimizations
        log_info "Removing old optimizations..."
        sudo sed -i '/# 3X-UI Network Optimizations/,/# End 3X-UI Network Optimizations/d' "$sysctl_conf"
    fi
    
    # Add network optimizations
    log_info "Adding network optimizations..."
    
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
    
    log_success "Network optimizations added to $sysctl_conf"
    echo "[NETWORK] Optimizations written to sysctl.conf" >> "$LOG_FILE"
}

# ───────────────────────────────
# Load sysctl settings
# ───────────────────────────────
load_sysctl_settings() {
    log_info "Loading sysctl settings..."
    echo "[NETWORK] Loading sysctl" >> "$LOG_FILE"
    
    if sudo sysctl -p >> "$LOG_FILE" 2>&1; then
        log_success "Sysctl settings loaded successfully!"
        echo "[NETWORK] Sysctl loaded" >> "$LOG_FILE"
    else
        log_warn "Some sysctl settings may have failed to load"
        echo "[NETWORK] Sysctl load had warnings" >> "$LOG_FILE"
    fi
}

# ───────────────────────────────
# Verify optimizations
# ───────────────────────────────
verify_optimizations() {
    log_info "Verifying network optimizations..."
    echo ""
    
    echo -e "${GREEN}Applied Configuration:${NC}"
    
    local qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    if [ "$qdisc" == "fq" ]; then
        echo "  ✓ Queue Discipline: $qdisc"
        echo "[NETWORK] Verified qdisc: $qdisc" >> "$LOG_FILE"
    else
        echo "  ✗ Queue Discipline: $qdisc (expected: fq)"
        echo "[NETWORK] WARNING: qdisc not set to fq" >> "$LOG_FILE"
    fi
    
    local congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [ "$congestion" == "bbr" ]; then
        echo "  ✓ TCP Congestion Control: $congestion"
        echo "[NETWORK] Verified congestion control: $congestion" >> "$LOG_FILE"
    else
        echo "  ✗ TCP Congestion Control: $congestion (expected: bbr)"
        echo "[NETWORK] WARNING: BBR not enabled" >> "$LOG_FILE"
    fi
    
    local fastopen=$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null)
    if [ "$fastopen" == "3" ]; then
        echo "  ✓ TCP Fast Open: $fastopen"
    else
        echo "  ! TCP Fast Open: $fastopen (expected: 3)"
    fi
    
    local ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)
    if [ "$ip_forward" == "1" ]; then
        echo "  ✓ IPv4 Forwarding: Enabled"
    else
        echo "  ✗ IPv4 Forwarding: Disabled"
    fi
    
    local ipv6_forward=$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null)
    if [ "$ipv6_forward" == "1" ]; then
        echo "  ✓ IPv6 Forwarding: Enabled"
    else
        echo "  ! IPv6 Forwarding: Disabled"
    fi
    
    echo ""
}

# ───────────────────────────────
# Show expected performance improvements
# ───────────────────────────────
show_performance_info() {
    echo ""
    log_banner "═══════════════════════════════════════════════════════════"
    log_banner "           Expected Performance Improvements"
    log_banner "═══════════════════════════════════════════════════════════"
    echo ""
    echo -e "${GREEN}What was optimized:${NC}"
    echo ""
    echo "  🚀 ${BOLD}BBR Congestion Control${NC}"
    echo "     → Smarter bandwidth usage, higher throughput"
    echo "     → Better performance on high-latency connections"
    echo ""
    echo "  📦 ${BOLD}Fair Queue (FQ) Scheduling${NC}"
    echo "     → Fair packet scheduling across connections"
    echo "     → Reduced latency spikes under load"
    echo ""
    echo "  💾 ${BOLD}Increased Buffer Sizes${NC}"
    echo "     → Prevents packet loss under high traffic"
    echo "     → Improved handling of large transfers"
    echo ""
    echo "  ⚡ ${BOLD}TCP Fast Open & Reuse${NC}"
    echo "     → Faster connection establishment"
    echo "     → Efficient socket recycling"
    echo ""
    echo "  🌐 ${BOLD}IP Forwarding Enabled${NC}"
    echo "     → Essential for VPN/proxy functionality"
    echo "     → Proper packet routing"
    echo ""
    echo -e "${YELLOW}Expected Results:${NC}"
    echo "  • Shadowsocks/VLESS: 20-30x speed improvement possible"
    echo "  • Better stability on long-distance connections"
    echo "  • Lower latency and reduced jitter"
    echo "  • Improved throughput under load"
    echo ""
    log_banner "═══════════════════════════════════════════════════════════"
}

# ───────────────────────────────
# Main Network Optimization Function
# ───────────────────────────────
network_optimization_setup() {
    log_banner "═══════════════════════════════════════════════════════════"
    log_banner "           Network Optimization Setup"
    log_banner "═══════════════════════════════════════════════════════════"
    echo ""
    
    log_info "This will apply kernel-level network optimizations for VPN/Proxy servers"
    echo ""
    echo -e "${CYAN}Optimizations include:${NC}"
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
        log_warn "BBR congestion control may not be available on this kernel"
        log_warn "Kernel version $(uname -r)"
        log_warn "BBR requires kernel 4.9 or higher"
        echo ""
        read -p "Continue anyway? [y/N]: " CONTINUE_NO_BBR
        if [[ ! "$CONTINUE_NO_BBR" =~ ^[Yy]$ ]]; then
            log_info "Skipping network optimization"
            return 0
        fi
    fi
    
    read -p "Apply network optimizations? [Y/n]: " APPLY_OPT
    APPLY_OPT=${APPLY_OPT:-Y}
    
    if [[ ! "$APPLY_OPT" =~ ^[Yy]$ ]]; then
        log_info "Skipping network optimization"
        echo "[NETWORK] User skipped optimization" >> "$LOG_FILE"
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
    
    log_success "Network optimization completed!"
    echo "[NETWORK] Optimization completed successfully" >> "$LOG_FILE"
    
    return 0
}

# ───────────────────────────────
# Quick check network performance
# ───────────────────────────────
check_network_performance() {
    echo ""
    log_banner "═══════════════════════════════════════════════════════════"
    log_banner "           Network Performance Check"
    log_banner "═══════════════════════════════════════════════════════════"
    echo ""
    
    echo -e "${CYAN}BBR Status:${NC}"
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        echo -e "  ${GREEN}✓ BBR is ENABLED${NC}"
    else
        echo -e "  ${RED}✗ BBR is NOT enabled${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Available Congestion Control Algorithms:${NC}"
    sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | sed 's/^/  /'
    
    echo ""
    echo -e "${CYAN}Current Queue Discipline:${NC}"
    sysctl net.core.default_qdisc 2>/dev/null | sed 's/^/  /'
    
    echo ""
    echo -e "${CYAN}IP Forwarding:${NC}"
    local ipv4_fwd=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)
    local ipv6_fwd=$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null)
    
    if [ "$ipv4_fwd" == "1" ]; then
        echo -e "  IPv4: ${GREEN}✓ Enabled${NC}"
    else
        echo -e "  IPv4: ${RED}✗ Disabled${NC}"
    fi
    
    if [ "$ipv6_fwd" == "1" ]; then
        echo -e "  IPv6: ${GREEN}✓ Enabled${NC}"
    else
        echo -e "  IPv6: ${YELLOW}! Disabled${NC}"
    fi
    
    echo ""
}
