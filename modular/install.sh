#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# 3X-UI Automated Installer - Main Entry Point
# ═══════════════════════════════════════════════════════════════════════════

# Get script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FUNCTIONS_DIR="$SCRIPT_DIR/functions"

# Source all function modules
source "$FUNCTIONS_DIR/logger.sh"
source "$FUNCTIONS_DIR/config.sh"
source "$FUNCTIONS_DIR/validators.sh"
source "$FUNCTIONS_DIR/utils.sh"
source "$FUNCTIONS_DIR/requirements.sh"
source "$FUNCTIONS_DIR/docker.sh"
source "$FUNCTIONS_DIR/compose.sh"
source "$FUNCTIONS_DIR/caddy.sh"
source "$FUNCTIONS_DIR/panel.sh"

# ───────────────────────────────
# Cleanup on Exit
# ───────────────────────────────
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Installation failed! Check the errors above."
        log_error "Full logs available at: $LOG_FILE"
    fi
}

trap cleanup EXIT

# ───────────────────────────────
# Main Installation Flow
# ───────────────────────────────
main() {
    clear
    log_banner "═══════════════════════════════════════════════════════════"
    log_banner "           3X-UI Automated Installer v2.0"
    log_banner "═══════════════════════════════════════════════════════════"
    echo ""

    log_info "Logs will be saved to: $LOG_FILE"
    echo ""

    # Check if resuming from saved state
    if load_state; then
        log_info "Resuming installation from stage: $STAGE"
        case "$STAGE" in
            DOCKER_INSTALLED)
                log_info "Docker was installed. Checking group membership..."
                if ! groups $USER | grep -q "docker"; then
                    log_error "User still not in docker group. Please log out/reboot and try again."
                    exit 1
                fi
                if ! docker info >/dev/null 2>&1; then
                    log_error "Cannot connect to Docker. Please log out/reboot and try again."
                    exit 1
                fi
                log_success "Docker access confirmed! Continuing installation..."
                clear_state
                ;;
        esac
    fi

    check_requirements
    docker_install

    # Create installation directory
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR" >> "$LOG_FILE" 2>&1
        log_success "Created installation directory: $INSTALL_DIR"
    fi

    cd "$INSTALL_DIR"

    # Domain configuration
    echo ""
    echo -ne "${BLUE}Do you have a domain name? [y/N]: ${NC}"
    read DN_EXIST
    DN_EXIST=${DN_EXIST:-N}

    DOM_NAME=""

    if [[ "$DN_EXIST" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "Enter your domain name (e.g., example.com): " DOM_NAME
            if validate_domain "$DOM_NAME"; then
                log_info "Testing DNS resolution for $DOM_NAME..."
                if host "$DOM_NAME" >> "$LOG_FILE" 2>&1; then
                    log_success "Domain $DOM_NAME resolves successfully!"
                    break
                else
                    log_warn "Domain $DOM_NAME does not resolve to an IP yet."
                    read -p "Continue anyway? [y/N]: " CONTINUE
                    if [[ "$CONTINUE" =~ ^[Yy]$ ]]; then
                        break
                    fi
                fi
            fi
        done
        create_compose "$DOM_NAME"
    else
        PUB_IP=$(get_public_ip)
        if [ -n "$PUB_IP" ]; then
            log_info "Your public IP: $PUB_IP"
        fi
        create_compose
    fi

    # Start 3X-UI container
    log_info "Starting 3X-UI container..."
    cd "$INSTALL_DIR"

    if docker compose up -d >> "$LOG_FILE" 2>&1; then
        log_success "3X-UI container started!"

        # Wait for container to be healthy
        log_info "Waiting for 3X-UI to be ready..."
        sleep 5

        if docker ps | grep -q 3xui_app; then
            log_success "3X-UI container is running!"
        else
            log_error "3X-UI container failed to start!"
            docker logs 3xui_app >> "$LOG_FILE" 2>&1
            exit 1
        fi
    else
        log_error "Failed to start 3X-UI container!"
        exit 1
    fi

    # Caddy setup
    if [[ "$DN_EXIST" =~ ^[Yy]$ ]]; then
        echo ""
        echo -ne "${BLUE}Install Caddy for HTTPS reverse proxy? [Y/n]: ${NC}"
        read INSTALL_CADDY
        INSTALL_CADDY=${INSTALL_CADDY:-Y}

        if [[ "$INSTALL_CADDY" =~ ^[Yy]$ ]]; then
            caddy_install "$DOM_NAME"
        else
            log_warn "Skipping Caddy setup."
            log_info "Access 3X-UI at: http://$DOM_NAME:2053"
            log_info "Default credentials: admin / admin"
        fi
    else
        PUB_IP=$(get_public_ip)
        log_warn "═══════════════════════════════════════════════════════════"
        log_warn "No domain configured - HTTPS not available"
        log_warn "═══════════════════════════════════════════════════════════"
        echo -e "${GREEN}Panel URL:${NC}      http://$PUB_IP:2053"
        echo -e "${GREEN}Default Login:${NC}  admin / admin"
        log_warn "═══════════════════════════════════════════════════════════"
        log_warn "IMPORTANT: Change default credentials after first login!"
        log_warn "═══════════════════════════════════════════════════════════"
    fi

    echo ""
    log_success "═══════════════════════════════════════════════════════════"
    log_success "           Installation completed successfully!"
    log_success "═══════════════════════════════════════════════════════════"
    echo ""
    log_info "Installation directory: $INSTALL_DIR"
    log_info "Docker compose file: $INSTALL_DIR/compose.yml"
    if [ -f "$INSTALL_DIR/Caddyfile" ]; then
        log_info "Caddyfile: $INSTALL_DIR/Caddyfile"
    fi
    log_info "Full logs: $LOG_FILE"
    echo ""
    log_info "Useful commands:"
    echo -e "  ${CYAN}cd $INSTALL_DIR${NC}"
    echo -e "  ${CYAN}docker compose logs -f${NC}      # View logs"
    echo -e "  ${CYAN}docker compose restart${NC}      # Restart container"
    echo -e "  ${CYAN}docker compose down${NC}         # Stop container"
    echo -e "  ${CYAN}docker compose up -d${NC}        # Start container"
    if command -v caddy &> /dev/null; then
        echo -e "  ${CYAN}sudo systemctl status caddy${NC} # Check Caddy status"
    fi
    echo ""

    clear_state
}

main "$@"
