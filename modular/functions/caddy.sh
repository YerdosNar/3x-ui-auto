#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# Caddy Installation & Configuration Module
# ═══════════════════════════════════════════════════════════════════════════

configure_caddy() {
    local dom_name="$1"
    local route="$2"
    local admin_name="$3"
    local hash_pw="$4"
    local port="$5"
    local be_port="$6"

    log_info "Creating Caddyfile configuration..."
    echo "[CADDY] Creating Caddyfile" >> "$LOG_FILE"
    echo "[CADDY] Domain: $dom_name, Route: /$route" >> "$LOG_FILE"
    echo "[CADDY] API Port: $port, Backend Port: $be_port" >> "$LOG_FILE"

    cat > "$INSTALL_DIR/Caddyfile" <<EOF
$dom_name {
    encode gzip

    tls {
        protocols tls1.3
    }

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options nosniff
        X-Frame-Options SAMEORIGIN
        Referrer-Policy strict-origin-when-cross-origin
        -Server
        -X-Powered-By
    }

    route /$route* {
        basic_auth {
            $admin_name $hash_pw
        }
        reverse_proxy localhost:$be_port
    }

    route /api/v1* {
        reverse_proxy localhost:$port
    }

    route {
        respond "Not found!" 404
    }
}
EOF

    log_success "Caddyfile created at $INSTALL_DIR/Caddyfile"
    echo "[CADDY] Caddyfile content:" >> "$LOG_FILE"
    cat "$INSTALL_DIR/Caddyfile" >> "$LOG_FILE"
}

caddy_install() {
    local dom_name="$1"

    log_info "Checking Caddy installation..."

    if command -v caddy &> /dev/null; then
        local caddy_version=$(caddy version 2>> "$LOG_FILE")
        log_success "Caddy is already installed: $caddy_version"
        echo "[CADDY] Already installed: $caddy_version" >> "$LOG_FILE"
    else
        log_info "Installing Caddy..."
        echo "[CADDY] Starting installation" >> "$LOG_FILE"

        exec_silent "sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl"

        log_info "Adding Caddy repository..."
        if ! curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' 2>> "$LOG_FILE" | \
            sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg >> "$LOG_FILE" 2>&1; then
            log_error "Failed to add Caddy GPG key"
            exit 1
        fi

        if ! curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' 2>> "$LOG_FILE" | \
            sudo tee /etc/apt/sources.list.d/caddy-stable.list >> "$LOG_FILE"; then
            log_error "Failed to add Caddy repository"
            exit 1
        fi

        exec_silent "sudo apt update"
        exec_silent "sudo apt install -y caddy"

        log_success "Caddy installed!"
        echo "[CADDY] Installation completed" >> "$LOG_FILE"
    fi

    log_info "Configuring Caddy reverse proxy..."
    echo ""

    # Admin credentials
    read -p "Enter admin username [default: admin]: " ADMIN_NAME
    ADMIN_NAME=${ADMIN_NAME:-admin}
    echo "[CADDY] Admin username: $ADMIN_NAME" >> "$LOG_FILE"

    echo -ne "${YELLOW}Generate strong random password? [Y/n]: ${NC}"
    read GEN_PASS
    GEN_PASS=${GEN_PASS:-Y}

    if [[ "$GEN_PASS" =~ ^[Yy]$ ]]; then
        PASSWORD=$(generate_strong_password)
        echo -e "${GREEN}Generated password:${NC} ${BOLD}$PASSWORD${NC}"
        echo -e "${YELLOW}SAVE THIS PASSWORD - it will only be shown once!${NC}"
        echo "[CADDY] Generated strong password" >> "$LOG_FILE"
        echo ""
        read -p "Press Enter to continue..."
    else
        while true; do
            read -sp "Enter admin password [default: admin]: " PASSWORD
            PASSWORD=${PASSWORD:-admin}
            echo ""
            local check_password
            read -sp "Enter admin password again: " check_password
            echo ""
            if [ "$PASSWORD" == "$check_password" ]; then
                break
            fi
            log_warn "Passwords do not match. Please try again."
        done
        if [ "$PASSWORD" == "admin" ]; then
            log_warn "Using default password 'admin' - consider changing this later!"
        fi
        echo "[CADDY] Password set by user" >> "$LOG_FILE"
    fi

    log_info "Hashing password..."
    HASH_PW=$(caddy hash-password --plaintext "$PASSWORD" 2>> "$LOG_FILE")
    echo "[CADDY] Password hashed successfully" >> "$LOG_FILE"

    # Route configuration
    echo ""
    read -p "Enter route nickname (panel will be at /<n>-admin) [default: admin]: " N_NAME
    N_NAME=${N_NAME:-admin}
    ROUTE="${N_NAME}-admin"
    if [ "$N_NAME" == "admin" ]; then
        ROUTE="admin"
    fi
    echo "[CADDY] Route: /$ROUTE" >> "$LOG_FILE"

    # Port configuration
    echo ""
    while true; do
        read -p "Enter API port [default: 8443]: " PORT
        PORT=${PORT:-8443}
        if validate_port "$PORT" && check_port_available "$PORT"; then
            echo "[CADDY] API port: $PORT" >> "$LOG_FILE"
            break
        fi
    done

    while true; do
        read -p "Enter backend port [default: 2087]: " BE_PORT
        BE_PORT=${BE_PORT:-2087}
        if validate_port "$BE_PORT" && check_port_available "$BE_PORT"; then
            echo "[CADDY] Backend port: $BE_PORT" >> "$LOG_FILE"
            break
        fi
    done

    configure_caddy "$dom_name" "$ROUTE" "$ADMIN_NAME" "$HASH_PW" "$PORT" "$BE_PORT"

    log_info "Installing Caddyfile..."
    exec_silent "sudo cp $INSTALL_DIR/Caddyfile /etc/caddy/Caddyfile"

    log_info "Testing Caddy configuration..."
    if sudo caddy validate --config /etc/caddy/Caddyfile >> "$LOG_FILE" 2>&1; then
        log_success "Caddy configuration is valid!"
        echo "[CADDY] Configuration validated" >> "$LOG_FILE"
    else
        log_error "Caddy configuration validation failed!"
        echo "[CADDY] Validation failed" >> "$LOG_FILE"
        exit 1
    fi

    log_info "Starting Caddy service..."
    exec_silent "sudo systemctl enable --now caddy"

    # Wait for Caddy to start
    sleep 2

    if systemctl is-active --quiet caddy; then
        log_success "Caddy is running!"
        echo "[CADDY] Service is active" >> "$LOG_FILE"
        echo ""

        # Try automatic 3X-UI configuration
        if configure_3xui_panel "$BE_PORT" "$ROUTE" "$ADMIN_NAME" "$PASSWORD"; then
            # Automatic configuration succeeded
            exec_silent "sudo systemctl restart caddy"
            echo ""
            log_banner "═══════════════════════════════════════════════════════════"
            log_banner "    ✓ 3X-UI Panel Configured Automatically!"
            log_banner "═══════════════════════════════════════════════════════════"
            echo -e "${GREEN}Panel URL:${NC}      https://$dom_name/$ROUTE"
            echo -e "${GREEN}Admin User:${NC}     $ADMIN_NAME"
            echo -e "${GREEN}Password:${NC}       $PASSWORD"
            echo -e "${GREEN}API Endpoint:${NC}   https://$dom_name/api/v1"
            log_banner "═══════════════════════════════════════════════════════════"
        else
            # Automatic configuration failed - show manual steps
            echo ""
            echo -e "${RED}${BOLD}!ATTENTION! - MANUAL SETUP REQUIRED${NC}"
            echo ""
            log_warn "Automatic configuration failed. Please complete these steps manually:"
            echo ""
            echo -e "${YELLOW}Step-by-step instructions:${NC}"
            echo ""
            echo -e "  1. Open: ${CYAN}http://$dom_name:2053${NC}"
            echo -e "  2. Login with default credentials: ${GREEN}admin${NC} / ${GREEN}admin${NC}"
            echo -e "  3. Navigate to: ${YELLOW}Panel Settings${NC}"
            echo -e "  4. Change ${YELLOW}Listen Port${NC} to: ${BLUE}$PORT${NC}"
            echo -e "  5. Change ${YELLOW}URI Path${NC} to: ${BLUE}/$ROUTE${NC}"
            echo -e "  6. Click ${BLUE}Save${NC}"
            echo -e "  7. Navigate to: ${YELLOW}Authentication${NC}"
            echo -e "  8. Enter ${YELLOW}Current Username${NC}: ${BLUE}admin${NC}"
            echo -e "  9. Enter ${YELLOW}Current Password${NC}: ${BLUE}admin${NC}"
            echo -e " 10. Enter ${YELLOW}New Username${NC}: ${BLUE}$ADMIN_NAME${NC}"
            echo -e " 11. Enter ${YELLOW}New Password${NC}: ${BLUE}$PASSWORD${NC}"
            echo -e " 12. Click ${BLUE}Save${NC}"
            echo -e " 13. Click ${BLUE}Restart Panel${NC}"
            echo ""
            echo -e "${YELLOW}Note: The panel will close after restart.${NC}"
            echo ""
            echo "[CADDY] Manual configuration required" >> "$LOG_FILE"
            read -p "Press Enter after completing these steps and the panel has restarted..."
            echo ""
            log_banner "═══════════════════════════════════════════════════════════"
            log_banner "               3X-UI Panel Access Information"
            log_banner "═══════════════════════════════════════════════════════════"
            echo -e "${GREEN}Panel URL:${NC}      https://$dom_name/$ROUTE"
            echo -e "${GREEN}Admin User:${NC}     $ADMIN_NAME"
            echo -e "${GREEN}Password:${NC}       $PASSWORD"
            echo -e "${GREEN}API Endpoint:${NC}   https://$dom_name/api/v1"
            log_banner "═══════════════════════════════════════════════════════════"
        fi
    else
        log_error "Caddy failed to start!"
        echo "[CADDY] Service failed to start" >> "$LOG_FILE"
        sudo journalctl -u caddy -n 50 --no-pager >> "$LOG_FILE" 2>&1
        exit 1
    fi
}
