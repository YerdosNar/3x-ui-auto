#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# Docker Installation Module
# ═══════════════════════════════════════════════════════════════════════════

docker_install() {
    log_info "Checking Docker installation..."

    if command -v docker &> /dev/null && docker --version >> "$LOG_FILE" 2>&1; then
        log_success "Docker is already installed: $(docker --version)"
        return 0
    fi

    log_info "Removing old Docker packages..."
    exec_silent "sudo apt-get remove -y docker docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null || true"

    log_info "Updating system packages..."
    exec_silent "sudo apt-get update -y"
    exec_silent "sudo apt-get install -y ca-certificates curl gnupg lsb-release"

    log_info "Setting up Docker repository..."
    exec_silent "sudo install -m 0755 -d /etc/apt/keyrings"

    if [ -f /etc/apt/keyrings/docker.gpg ]; then
        exec_silent "sudo rm /etc/apt/keyrings/docker.gpg"
    fi

    log_info "Adding Docker GPG key..."
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg 2>> "$LOG_FILE" | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "$LOG_FILE" 2>&1; then
        log_error "Failed to add Docker GPG key"
        exit 1
    fi

    exec_silent "sudo chmod a+r /etc/apt/keyrings/docker.gpg"

    log_info "Adding Docker repository..."
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list >> "$LOG_FILE"

    log_info "Installing Docker and Docker Compose..."
    exec_silent "sudo apt-get update -y"
    exec_silent "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"

    log_info "Enabling Docker service..."
    exec_silent "sudo systemctl enable --now docker"

    # Wait for Docker to be ready
    log_info "Waiting for Docker daemon to start..."
    for i in {1..30}; do
        if sudo docker info >> "$LOG_FILE" 2>&1; then
            log_success "Docker daemon is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Docker daemon failed to start within 30 seconds"
            exit 1
        fi
        sleep 1
    done

    # Check if user is in docker group
    if ! groups $USER | grep -q "docker"; then
        log_info "Adding user '$USER' to docker group..."
        exec_silent "sudo usermod -aG docker $USER"

        log_warn "═══════════════════════════════════════════════════════════"
        log_warn "User added to docker group. Session restart required!"
        log_warn "═══════════════════════════════════════════════════════════"
        echo ""

        read -p "Is this a SERVER (VPS) or LOCAL machine? [s/L]: " MACHINE_TYPE
        MACHINE_TYPE=${MACHINE_TYPE:-L}

        save_state "DOCKER_INSTALLED"

        if [[ "$MACHINE_TYPE" =~ ^[Ss]$ ]]; then
            log_warn "You need to LOG OUT and LOG BACK IN to apply group changes."
            log_warn "After logging back in, run this command again:"
            echo -e "${CYAN}cd $(pwd) && ./install.sh${NC}"
            echo ""
            read -p "Press Enter to logout now (or Ctrl+C to cancel)..."
            clear_state
            # For SSH sessions
            if [ -n "${SSH_CONNECTION:-}" ]; then
                kill -HUP "$PPID"
            else
                # For local terminal
                pkill -KILL -u "$USER"
            fi
            exit 0
        else
            log_warn "You need to REBOOT your machine to apply group changes."
            log_warn "After reboot, run this command again:"
            echo -e "${CYAN}cd $(pwd) && ./install.sh${NC}"
            echo ""
            read -p "Reboot now? [Y/n]: " REBOOT
            REBOOT=${REBOOT:-Y}
            if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
                clear_state
                sudo reboot
            else
                log_warn "Please reboot manually and run the script again."
                exit 0
            fi
        fi
    fi

    # Test Docker
    log_info "Testing Docker installation..."
    if docker run --rm hello-world >> "$LOG_FILE" 2>&1; then
        log_success "Docker test passed!"
    else
        log_error "Docker test failed. Check logs at: $LOG_FILE"
        exit 1
    fi

    log_success "Docker installation completed!"
}
