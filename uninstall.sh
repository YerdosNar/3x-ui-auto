#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# 3X-UI Complete Uninstaller
# Removes Docker, Caddy, and all related configurations
# ═══════════════════════════════════════════════════════════════════════════

# ───────────────────────────────
# ANSI Colors
# ───────────────────────────────
readonly NC="\033[0m"
readonly RED="\033[31m"
readonly GREEN="\033[32m"
readonly YELLOW="\033[33m"
readonly BLUE="\033[34m"
readonly CYAN="\033[36m"
readonly BOLD="\033[1m"

# ───────────────────────────────
# Logging Functions
# ───────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1" >&2; }
banner()  { echo -e "${CYAN}${BOLD}$1${NC}"; }

# ───────────────────────────────
# Installation paths
# ───────────────────────────────
readonly INSTALL_DIR="$HOME/3x-uiPANEL"
readonly STATE_FILE="/tmp/.3xui_install_state"

# ───────────────────────────────
# Confirmation
# ───────────────────────────────
confirm_uninstall() {
    clear
    banner "═══════════════════════════════════════════════════════════"
    banner "           3X-UI Complete Uninstaller v1.0"
    banner "═══════════════════════════════════════════════════════════"
    echo ""
    warn "⚠️  WARNING: This will completely remove:"
    echo ""
    echo "  • 3X-UI Panel and all configurations"
    echo "  • Docker Engine and all containers/images/volumes"
    echo "  • Docker Compose"
    echo "  • Caddy web server and configurations"
    echo "  • All related data and certificates"
    echo ""
    error "THIS ACTION CANNOT BE UNDONE!"
    echo ""
    read -p "Are you absolutely sure you want to continue? [yes/NO]: " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        info "Uninstallation cancelled."
        exit 0
    fi

    echo ""
    read -p "Type 'DELETE EVERYTHING' to confirm: " FINAL_CONFIRM

    if [ "$FINAL_CONFIRM" != "DELETE EVERYTHING" ]; then
        info "Uninstallation cancelled."
        exit 0
    fi

    echo ""
    warn "Starting uninstallation in 5 seconds... Press Ctrl+C to cancel!"
    sleep 5
}

# ───────────────────────────────
# Stop and Remove 3X-UI Container
# ───────────────────────────────
remove_3xui() {
    info "Removing 3X-UI containers..."

    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"

        if [ -f "compose.yml" ] || [ -f "docker-compose.yml" ]; then
            info "Stopping 3X-UI containers..."
            docker compose down -v 2>/dev/null || docker-compose down -v 2>/dev/null || true
            success "3X-UI containers stopped and removed!"
        fi
    fi

    # Force remove any remaining 3xui containers
    if docker ps -a | grep -q "3xui"; then
        info "Force removing any remaining 3X-UI containers..."
        docker ps -a | grep "3xui" | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
    fi

    # Remove 3X-UI images
    if docker images | grep -q "3x-ui"; then
        info "Removing 3X-UI images..."
        docker images | grep "3x-ui" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
    fi

    success "3X-UI containers and images removed!"
}

# ───────────────────────────────
# Remove Installation Directory
# ───────────────────────────────
remove_install_dir() {
    if [ -d "$INSTALL_DIR" ]; then
        info "Removing installation directory: $INSTALL_DIR"

        # Show what will be deleted
        echo ""
        warn "Directory contents:"
        ls -lah "$INSTALL_DIR" 2>/dev/null || true
        echo ""

        read -p "Delete this directory and all its contents? [y/N]: " DELETE_DIR
        if [[ "$DELETE_DIR" =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
            success "Installation directory removed!"
        else
            warn "Keeping installation directory at: $INSTALL_DIR"
        fi
    else
        info "Installation directory not found, skipping..."
    fi
}

# ───────────────────────────────
# Stop and Remove Caddy
# ───────────────────────────────
remove_caddy() {
    info "Checking for Caddy installation..."

    if command -v caddy &> /dev/null; then
        info "Stopping Caddy service..."
        sudo systemctl stop caddy 2>/dev/null || true
        sudo systemctl disable caddy 2>/dev/null || true
        success "Caddy service stopped!"

        info "Removing Caddy package..."
        sudo apt-get remove --purge -y caddy 2>/dev/null || true
        sudo apt-get autoremove -y 2>/dev/null || true
        success "Caddy package removed!"

        # Remove Caddy repository
        if [ -f /etc/apt/sources.list.d/caddy-stable.list ]; then
            info "Removing Caddy repository..."
            sudo rm -f /etc/apt/sources.list.d/caddy-stable.list
            sudo rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
            sudo apt-get update -y 2>/dev/null || true
            success "Caddy repository removed!"
        fi

        # Remove Caddy configuration
        if [ -d /etc/caddy ]; then
            info "Removing Caddy configuration..."
            read -p "Delete Caddy config directory (/etc/caddy)? [y/N]: " DELETE_CADDY_CONF
            if [[ "$DELETE_CADDY_CONF" =~ ^[Yy]$ ]]; then
                sudo rm -rf /etc/caddy
                success "Caddy configuration removed!"
            else
                warn "Keeping Caddy configuration at: /etc/caddy"
            fi
        fi

        # Remove Caddy data
        if [ -d /var/lib/caddy ]; then
            info "Removing Caddy data directory..."
            sudo rm -rf /var/lib/caddy
        fi

        success "Caddy completely removed!"
    else
        info "Caddy not found, skipping..."
    fi
}

# ───────────────────────────────
# Remove All Docker Components
# ───────────────────────────────
remove_docker() {
    info "Checking for Docker installation..."

    if command -v docker &> /dev/null; then
        warn "═══════════════════════════════════════════════════════════"
        warn "About to remove Docker and ALL containers, images, volumes!"
        warn "═══════════════════════════════════════════════════════════"
        echo ""

        # Show what exists
        info "Current Docker resources:"
        echo ""
        echo -e "${YELLOW}Containers:${NC}"
        docker ps -a 2>/dev/null || true
        echo ""
        echo -e "${YELLOW}Images:${NC}"
        docker images 2>/dev/null || true
        echo ""
        echo -e "${YELLOW}Volumes:${NC}"
        docker volume ls 2>/dev/null || true
        echo ""

        read -p "Remove ALL Docker data? [y/N]: " REMOVE_DOCKER_DATA

        if [[ "$REMOVE_DOCKER_DATA" =~ ^[Yy]$ ]]; then
            info "Stopping all Docker containers..."
            docker stop $(docker ps -aq) 2>/dev/null || true

            info "Removing all Docker containers..."
            docker rm -f $(docker ps -aq) 2>/dev/null || true

            info "Removing all Docker images..."
            docker rmi -f $(docker images -q) 2>/dev/null || true

            info "Removing all Docker volumes..."
            docker volume rm $(docker volume ls -q) 2>/dev/null || true

            info "Removing all Docker networks..."
            docker network rm $(docker network ls -q) 2>/dev/null || true

            info "Pruning Docker system..."
            docker system prune -af --volumes 2>/dev/null || true

            success "All Docker data removed!"
        fi

        info "Stopping Docker service..."
        sudo systemctl stop docker 2>/dev/null || true
        sudo systemctl stop docker.socket 2>/dev/null || true
        sudo systemctl disable docker 2>/dev/null || true
        success "Docker service stopped!"

        info "Removing Docker packages..."
        sudo apt-get remove --purge -y \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin \
            docker-compose \
            2>/dev/null || true

        sudo apt-get autoremove -y 2>/dev/null || true
        success "Docker packages removed!"

        # Remove Docker repository
        if [ -f /etc/apt/sources.list.d/docker.list ]; then
            info "Removing Docker repository..."
            sudo rm -f /etc/apt/sources.list.d/docker.list
            sudo rm -f /etc/apt/keyrings/docker.gpg
            sudo apt-get update -y 2>/dev/null || true
            success "Docker repository removed!"
        fi

        # Remove Docker directories
        info "Removing Docker directories..."
        read -p "Delete all Docker data directories? [y/N]: " DELETE_DOCKER_DIRS
        if [[ "$DELETE_DOCKER_DIRS" =~ ^[Yy]$ ]]; then
            sudo rm -rf /var/lib/docker
            sudo rm -rf /var/lib/containerd
            sudo rm -rf /etc/docker
            sudo rm -rf /var/run/docker.sock
            sudo rm -rf ~/.docker
            success "Docker directories removed!"
        else
            warn "Keeping Docker data directories"
        fi

        # Remove user from docker group
        if groups $USER | grep -q "docker"; then
            info "Removing user '$USER' from docker group..."
            sudo gpasswd -d "$USER" docker 2>/dev/null || true
            success "User removed from docker group!"
        fi

        success "Docker completely removed!"
    else
        info "Docker not found, skipping..."
    fi
}

# ───────────────────────────────
# Remove State File
# ───────────────────────────────
remove_state() {
    if [ -f "$STATE_FILE" ]; then
        info "Removing installation state file..."
        rm -f "$STATE_FILE"
        success "State file removed!"
    fi
}

# ───────────────────────────────
# Clean Up System Packages
# ───────────────────────────────
cleanup_system() {
    info "Cleaning up system packages..."
    sudo apt-get autoremove -y 2>/dev/null || true
    sudo apt-get autoclean -y 2>/dev/null || true
    success "System cleanup completed!"
}

# ───────────────────────────────
# Final Summary
# ───────────────────────────────
show_summary() {
    echo ""
    banner "═══════════════════════════════════════════════════════════"
    banner "           Uninstallation Completed!"
    banner "═══════════════════════════════════════════════════════════"
    echo ""
    success "The following have been removed:"
    echo ""
    echo "  ✓ 3X-UI Panel and configurations"
    echo "  ✓ Docker Engine and all containers"
    echo "  ✓ Docker Compose"
    echo "  ✓ Caddy web server"
    echo "  ✓ Related configurations and data"
    echo ""

    # Check what remains
    local remains=()

    [ -d "$INSTALL_DIR" ] && remains+=("Installation directory: $INSTALL_DIR")
    [ -d /etc/caddy ] && remains+=("Caddy config: /etc/caddy")
    [ -d /var/lib/docker ] && remains+=("Docker data: /var/lib/docker")

    if [ ${#remains[@]} -gt 0 ]; then
        warn "The following items were preserved:"
        echo ""
        for item in "${remains[@]}"; do
            echo "  • $item"
        done
        echo ""
    fi

    info "Remaining packages installed for the installation:"
    echo "  • ca-certificates, curl, gnupg, lsb-release"
    echo "  • apt-transport-https"
    echo "  • sqlite3 (if installed)"
    echo ""
    info "These are common system utilities and were not removed."
    echo ""

    if groups $USER | grep -q "docker"; then
        warn "Note: You are still in the 'docker' group."
        warn "This change will take effect after logout/reboot."
    fi

    banner "═══════════════════════════════════════════════════════════"
    success "System restored to pre-installation state!"
    banner "═══════════════════════════════════════════════════════════"
    echo ""
}

# ───────────────────────────────
# Main Uninstallation
# ───────────────────────────────
main() {
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        error "Do not run this script as root. Run as a regular user with sudo privileges."
        exit 1
    fi

    # Check sudo access
    if ! sudo -v; then
        error "Sudo authentication failed. You need sudo privileges."
        exit 1
    fi

    confirm_uninstall

    echo ""
    banner "═══════════════════════════════════════════════════════════"
    banner "Starting Uninstallation Process..."
    banner "═══════════════════════════════════════════════════════════"
    echo ""

    # Remove in reverse order of installation
    remove_3xui
    echo ""

    remove_caddy
    echo ""

    remove_docker
    echo ""

    remove_install_dir
    echo ""

    remove_state
    echo ""

    cleanup_system

    show_summary
}

main "$@"
