#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# UFW Firewall Management Module
# Smart port detection and comprehensive security setup
# ═══════════════════════════════════════════════════════════════════════════

# ───────────────────────────────
# Detect SSH Port
# ───────────────────────────────
detect_ssh_port() {
    local ssh_port=$(grep -E "^Port\s+" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    if [ -z "$ssh_port" ]; then
        ssh_port=22
    fi
    echo "$ssh_port"
}

# ───────────────────────────────
# Check if UFW is installed
# ───────────────────────────────
check_ufw_installed() {
    if command -v ufw &> /dev/null; then
        return 0
    fi
    return 1
}

# ───────────────────────────────
# Install UFW
# ───────────────────────────────
install_ufw() {
    log_info "Installing UFW (Uncomplicated Firewall)..."
    echo "[FIREWALL] Installing UFW" >> "$LOG_FILE"
    
    exec_silent "sudo apt-get update"
    exec_silent "sudo apt-get install -y ufw"
    
    if check_ufw_installed; then
        log_success "UFW installed successfully!"
        echo "[FIREWALL] UFW installation completed" >> "$LOG_FILE"
        return 0
    else
        log_error "Failed to install UFW"
        echo "[FIREWALL] UFW installation failed" >> "$LOG_FILE"
        return 1
    fi
}

# ───────────────────────────────
# Collect Required Ports
# ───────────────────────────────
collect_required_ports() {
    local -n ports_ref=$1
    
    log_info "Detecting required ports..."
    echo "[FIREWALL] Port detection started" >> "$LOG_FILE"
    
    # SSH port (critical - never block this!)
    local ssh_port=$(detect_ssh_port)
    ports_ref["SSH"]="$ssh_port/tcp"
    log_info "SSH port detected: $ssh_port"
    echo "[FIREWALL] SSH port: $ssh_port" >> "$LOG_FILE"
    
    # HTTP/HTTPS for Caddy
    if command -v caddy &> /dev/null || [ "${INSTALL_CADDY:-}" == "Y" ]; then
        ports_ref["HTTP"]="80/tcp"
        ports_ref["HTTPS"]="443/tcp"
        log_info "Web server ports: 80, 443"
        echo "[FIREWALL] Web ports: 80, 443" >> "$LOG_FILE"
    fi
    
    # 3X-UI default port
    ports_ref["3X-UI"]="2053/tcp"
    log_info "3X-UI default port: 2053"
    echo "[FIREWALL] 3X-UI port: 2053" >> "$LOG_FILE"
    
    # Backend port (if configured)
    if [ -n "${BE_PORT:-}" ]; then
        ports_ref["BACKEND"]="$BE_PORT/tcp"
        log_info "Backend port: $BE_PORT"
        echo "[FIREWALL] Backend port: $BE_PORT" >> "$LOG_FILE"
    fi
    
    # API port (if configured)
    if [ -n "${PORT:-}" ]; then
        ports_ref["API"]="$PORT/tcp"
        ports_ref["API_UDP"]="$PORT/udp"
        log_info "API port: $PORT (TCP/UDP)"
        echo "[FIREWALL] API port: $PORT" >> "$LOG_FILE"
    fi
    
    log_success "Port detection completed"
    echo "[FIREWALL] Detected ${#ports_ref[@]} port rules" >> "$LOG_FILE"
}

# ───────────────────────────────
# Configure UFW Default Policies
# ───────────────────────────────
configure_ufw_defaults() {
    log_info "Configuring UFW default policies..."
    echo "[FIREWALL] Setting default policies" >> "$LOG_FILE"
    
    # Set default policies
    exec_silent "sudo ufw default deny incoming"
    exec_silent "sudo ufw default allow outgoing"
    
    log_success "Default policies set: deny incoming, allow outgoing"
    echo "[FIREWALL] Default policies configured" >> "$LOG_FILE"
}

# ───────────────────────────────
# Enable IP Forwarding in UFW
# ───────────────────────────────
enable_ufw_forwarding() {
    log_info "Enabling IP forwarding in UFW..."
    echo "[FIREWALL] Configuring IP forwarding" >> "$LOG_FILE"
    
    local ufw_sysctl="/etc/ufw/sysctl.conf"
    
    if [ -f "$ufw_sysctl" ]; then
        # Backup original file
        exec_silent "sudo cp $ufw_sysctl ${ufw_sysctl}.backup.$(date +%s)"
        
        # Enable IPv4 forwarding
        if sudo grep -q "^net.ipv4.ip_forward=1" "$ufw_sysctl"; then
            log_info "IPv4 forwarding already enabled in UFW"
        else
            if sudo grep -q "^#net.ipv4.ip_forward=1" "$ufw_sysctl"; then
                exec_silent "sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' $ufw_sysctl"
            else
                echo "net.ipv4.ip_forward=1" | sudo tee -a "$ufw_sysctl" >> "$LOG_FILE"
            fi
            log_success "IPv4 forwarding enabled"
        fi
        
        # Enable IPv6 forwarding
        if sudo grep -q "^net.ipv6.conf.all.forwarding=1" "$ufw_sysctl"; then
            log_info "IPv6 forwarding already enabled in UFW"
        else
            if sudo grep -q "^#net.ipv6.conf.all.forwarding=1" "$ufw_sysctl"; then
                exec_silent "sudo sed -i 's/^#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/' $ufw_sysctl"
            else
                echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a "$ufw_sysctl" >> "$LOG_FILE"
            fi
            log_success "IPv6 forwarding enabled"
        fi
        
        echo "[FIREWALL] IP forwarding enabled in UFW" >> "$LOG_FILE"
    else
        log_warn "UFW sysctl.conf not found at $ufw_sysctl"
        echo "[FIREWALL] UFW sysctl.conf not found" >> "$LOG_FILE"
    fi
}

# ───────────────────────────────
# Open Required Ports
# ───────────────────────────────
open_required_ports() {
    local -n ports_ref=$1
    
    log_info "Opening required ports..."
    echo "[FIREWALL] Opening ports" >> "$LOG_FILE"
    
    local failed_rules=0
    
    for name in "${!ports_ref[@]}"; do
        local port="${ports_ref[$name]}"
        log_info "Opening port: $port ($name)"
        echo "[FIREWALL] Opening: $port ($name)" >> "$LOG_FILE"
        
        if sudo ufw allow "$port" >> "$LOG_FILE" 2>&1; then
            log_success "  ✓ $port opened"
        else
            log_warn "  ! Failed to open $port"
            ((failed_rules++))
        fi
    done
    
    if [ $failed_rules -eq 0 ]; then
        log_success "All ports opened successfully"
        echo "[FIREWALL] All ports opened" >> "$LOG_FILE"
        return 0
    else
        log_warn "$failed_rules port(s) failed to open"
        echo "[FIREWALL] $failed_rules failed rules" >> "$LOG_FILE"
        return 1
    fi
}

# ───────────────────────────────
# Open Port Ranges for Inbounds
# ───────────────────────────────
open_port_ranges() {
    log_info "Opening port ranges for VPN/proxy inbounds..."
    echo "[FIREWALL] Opening port ranges" >> "$LOG_FILE"
    
    echo ""
    echo -e "${YELLOW}Common port ranges for VPN inbounds:${NC}"
    echo "  • 8380-8400 (TCP/UDP) - Common for VLESS/VMess"
    echo "  • 9380-9400 (TCP/UDP) - Alternative range"
    echo ""
    
    read -p "Open port range 8380-8400 (TCP/UDP)? [Y/n]: " OPEN_RANGE1
    OPEN_RANGE1=${OPEN_RANGE1:-Y}
    
    if [[ "$OPEN_RANGE1" =~ ^[Yy]$ ]]; then
        log_info "Opening ports 8380-8400..."
        exec_silent "sudo ufw allow 8380:8400/tcp"
        exec_silent "sudo ufw allow 8380:8400/udp"
        log_success "  ✓ Ports 8380-8400 (TCP/UDP) opened"
        echo "[FIREWALL] Opened range 8380-8400" >> "$LOG_FILE"
    fi
    
    read -p "Open port range 9380-9400 (TCP/UDP)? [Y/n]: " OPEN_RANGE2
    OPEN_RANGE2=${OPEN_RANGE2:-Y}
    
    if [[ "$OPEN_RANGE2" =~ ^[Yy]$ ]]; then
        log_info "Opening ports 9380-9400..."
        exec_silent "sudo ufw allow 9380:9400/tcp"
        exec_silent "sudo ufw allow 9380:9400/udp"
        log_success "  ✓ Ports 9380-9400 (TCP/UDP) opened"
        echo "[FIREWALL] Opened range 9380-9400" >> "$LOG_FILE"
    fi
    
    echo ""
    read -p "Open custom port range? [y/N]: " OPEN_CUSTOM
    if [[ "$OPEN_CUSTOM" =~ ^[Yy]$ ]]; then
        read -p "Enter start port: " START_PORT
        read -p "Enter end port: " END_PORT
        
        if validate_port "$START_PORT" && validate_port "$END_PORT"; then
            if [ "$START_PORT" -lt "$END_PORT" ]; then
                log_info "Opening custom range $START_PORT-$END_PORT..."
                exec_silent "sudo ufw allow $START_PORT:$END_PORT/tcp"
                exec_silent "sudo ufw allow $START_PORT:$END_PORT/udp"
                log_success "  ✓ Ports $START_PORT-$END_PORT (TCP/UDP) opened"
                echo "[FIREWALL] Opened custom range $START_PORT-$END_PORT" >> "$LOG_FILE"
            else
                log_error "Invalid range: start port must be less than end port"
            fi
        else
            log_error "Invalid port numbers"
        fi
    fi
}

# ───────────────────────────────
# Enable UFW (with safety check)
# ───────────────────────────────
enable_ufw() {
    log_info "Enabling UFW firewall..."
    echo "[FIREWALL] Enabling UFW" >> "$LOG_FILE"
    
    # Double-check SSH is allowed
    local ssh_port=$(detect_ssh_port)
    sudo ufw allow "$ssh_port/tcp" >> "$LOG_FILE" 2>&1
    
    # Enable UFW (non-interactive)
    if echo "y" | sudo ufw enable >> "$LOG_FILE" 2>&1; then
        log_success "UFW enabled successfully!"
        echo "[FIREWALL] UFW enabled" >> "$LOG_FILE"
        return 0
    else
        log_error "Failed to enable UFW"
        echo "[FIREWALL] Failed to enable UFW" >> "$LOG_FILE"
        return 1
    fi
}

# ───────────────────────────────
# Show Firewall Status
# ───────────────────────────────
show_firewall_status() {
    log_info "Firewall status:"
    echo ""
    sudo ufw status numbered | tee -a "$LOG_FILE"
    echo ""
}

# ───────────────────────────────
# Main Firewall Setup Function
# ───────────────────────────────
firewall_setup() {
    log_banner "═══════════════════════════════════════════════════════════"
    log_banner "           UFW Firewall Setup"
    log_banner "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Check if UFW is installed
    if ! check_ufw_installed; then
        log_warn "UFW is not installed"
        read -p "Install UFW firewall? [Y/n]: " INSTALL_UFW
        INSTALL_UFW=${INSTALL_UFW:-Y}
        
        if [[ ! "$INSTALL_UFW" =~ ^[Yy]$ ]]; then
            log_warn "Skipping firewall setup"
            echo "[FIREWALL] User skipped installation" >> "$LOG_FILE"
            return 0
        fi
        
        if ! install_ufw; then
            log_error "Cannot proceed without UFW"
            return 1
        fi
    else
        log_success "UFW is already installed"
        echo "[FIREWALL] UFW already present" >> "$LOG_FILE"
    fi
    
    # Check if UFW is already enabled
    if sudo ufw status | grep -q "Status: active"; then
        log_warn "UFW is already active"
        read -p "Reconfigure UFW rules? [y/N]: " RECONFIG
        if [[ ! "$RECONFIG" =~ ^[Yy]$ ]]; then
            log_info "Keeping existing firewall configuration"
            show_firewall_status
            return 0
        fi
    fi
    
    echo ""
    log_info "This will configure UFW with smart port detection"
    log_warn "⚠️  Firewall will block all incoming traffic except allowed ports"
    log_success "✓  SSH port will be automatically preserved"
    echo ""
    
    read -p "Continue with firewall setup? [Y/n]: " CONTINUE_FW
    CONTINUE_FW=${CONTINUE_FW:-Y}
    
    if [[ ! "$CONTINUE_FW" =~ ^[Yy]$ ]]; then
        log_warn "Skipping firewall setup"
        return 0
    fi
    
    # Collect required ports
    declare -A required_ports
    collect_required_ports required_ports
    
    echo ""
    log_info "Ports that will be opened:"
    for name in "${!required_ports[@]}"; do
        echo "  • ${required_ports[$name]} - $name"
    done
    echo ""
    
    read -p "Proceed with these ports? [Y/n]: " PROCEED_PORTS
    PROCEED_PORTS=${PROCEED_PORTS:-Y}
    
    if [[ ! "$PROCEED_PORTS" =~ ^[Yy]$ ]]; then
        log_warn "Firewall setup cancelled"
        return 0
    fi
    
    # Configure UFW
    configure_ufw_defaults
    enable_ufw_forwarding
    open_required_ports required_ports
    
    echo ""
    open_port_ranges
    
    # Enable UFW
    echo ""
    enable_ufw
    
    # Show status
    echo ""
    show_firewall_status
    
    log_success "═══════════════════════════════════════════════════════════"
    log_success "           Firewall Setup Completed!"
    log_success "═══════════════════════════════════════════════════════════"
    
    echo "[FIREWALL] Setup completed successfully" >> "$LOG_FILE"
    return 0
}

# ───────────────────────────────
# Quick command to open a port
# ───────────────────────────────
firewall_open_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    
    if ! check_ufw_installed; then
        log_error "UFW is not installed"
        return 1
    fi
    
    log_info "Opening port $port/$protocol..."
    if sudo ufw allow "$port/$protocol" >> "$LOG_FILE" 2>&1; then
        log_success "Port $port/$protocol opened"
        return 0
    else
        log_error "Failed to open port $port/$protocol"
        return 1
    fi
}

# ───────────────────────────────
# Quick command to close a port
# ───────────────────────────────
firewall_close_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    
    if ! check_ufw_installed; then
        log_error "UFW is not installed"
        return 1
    fi
    
    log_info "Closing port $port/$protocol..."
    if sudo ufw delete allow "$port/$protocol" >> "$LOG_FILE" 2>&1; then
        log_success "Port $port/$protocol closed"
        return 0
    else
        log_error "Failed to close port $port/$protocol"
        return 1
    fi
}
