#!/usr/bin/env bash
# set -euo pipefail

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
success() { echo -e "${GREEN}[✓]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[!]${NC}    $1"; }
error()   { echo -e "${RED}[✗]${NC}    $1" >&2; }
banner()  { echo -e "${CYAN}${BOLD}$1${NC}"; }

# ───────────────────────────────
# Installation paths
# ───────────────────────────────
readonly BASE_DIR="$HOME/3x-ui"
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
    warn "Starting uninstallation in 8 seconds... Press Ctrl+C to cancel!"
    for i in {8..1}; do
        case "$i" in
            8)
              bar="[##--------------]" ;;
            7)
              bar="[####------------]" ;;
            6)
              bar="[######----------]" ;;
            5)
              bar="[########--------]" ;;
            4)
              bar="[########${YELLOW}##${NC}------]" ;;
            3)
              bar="[########${YELLOW}####${NC}----]" ;;
            2)
              bar="[########${YELLOW}####${RED}##${NC}--]" ;;
            1)
                bar="[########${YELLOW}####${RED}####${NC}]" ;;
        esac
        if [ "$i" -eq 1 ]; then
            echo -ne "\r$bar ${BOLD}${RED}$i${NC} second left..."
        else
            echo -ne "\r$bar $i seconds left..."
        fi
        sleep 1
    done
    echo -e "\n"
}

# ───────────────────────────────
# Stop and Remove 3X-UI Container
# ───────────────────────────────
remove_3xui() {
    local install_dir="$1"

    info "Removing 3X-UI containers..."

    # If installation directory exists, try docker compose down first
    if [ -n "$install_dir" ] && [ -d "$install_dir" ]; then
        cd "$install_dir"

        if [ -f "compose.yml" ] || [ -f "docker-compose.yml" ]; then
            local docker_name=$(grep "container_name:" "*compose.yml" 2>/dev/null | awk '{print $2}' | tr -d "'\"")
            info "Stopping 3X-UI containers using docker compose..."
            docker compose down -v 2>/dev/null || docker-compose down -v 2>/dev/null || true
            docker rm "$docker_name" 2>/dev/null
            success "3X-UI containers stopped via compose!"
        fi
    fi

    # Force remove any remaining 3xui containers (including PID-based names)
    # This will catch both 3xui_app and 3xui_app_* patterns

    success "3X-UI containers and images cleanup completed!"
}

# ───────────────────────────────
# Remove Installation Directory
# ───────────────────────────────
remove_install_dir() {
    local install_dir="$1"

    if [ -z "$install_dir" ]; then
        info "No installation directory detected, skipping..."
        return 0
    fi

    if [ -d "$install_dir" ]; then
        info "Removing installation directory: $install_dir"

        # Show what will be deleted
        echo ""
        warn "Directory contents:"
        ls -lah "$install_dir" 2>/dev/null || true
        echo ""

        read -p "Delete this directory and all its contents? [y/N]: " DELETE_DIR
        if [[ "$DELETE_DIR" =~ ^[Yy]$ ]]; then
            sudo rm -rf "$install_dir"
            success "Installation directory removed: $install_dir"
        else
            warn "Keeping installation directory at: $install_dir"
        fi
    else
        info "Installation directory not found: $install_dir"
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

    # Check for any remaining 3x-uiPANEL directories
    for dir in "$BASE_DIR"*; do
        if [ -d "$dir" ]; then
            remains+=("Installation directory: $dir")
        fi
    done

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
# Detect installation directory
# ───────────────────────────────
detect_install_dir() {
    local preselected="$1"

    # First check if state file exists with saved directory
    if [ -f "$STATE_FILE" ] && grep -q "INSTALL_DIR=" "$STATE_FILE" 2>/dev/null; then
        local saved_dir=$(grep "INSTALL_DIR=" "$STATE_FILE" | cut -d= -f2)
        if [ -d "$saved_dir" ]; then
            echo "$saved_dir"
            return 0
        fi
    fi

    # Look for directories matching the pattern
    local found_dirs=()
    for dir in "$BASE_DIR"*; do
        if [ -d "$dir" ]; then
            found_dirs+=("$dir")
        fi
    done

    if [ ${#found_dirs[@]} -eq 0 ]; then
        echo ""
        return 1
    elif [ ${#found_dirs[@]} -eq 1 ]; then
        echo "${found_dirs[0]}"
        return 0
    else
        # Multiple directories found
        # If preselected choice provided (from command line), use it
        if [ -n "$preselected" ]; then
            if [[ "$preselected" =~ ^[0-9]+$ ]] && [ "$preselected" -ge 1 ] && [ "$preselected" -le ${#found_dirs[@]} ]; then
                echo "${found_dirs[$((preselected-1))]}"
                return 0
            else
                error "Invalid directory selection: $preselected (must be 1-${#found_dirs[@]})"
                return 1
            fi
        fi

        # Interactive selection
        echo ""
        warn "Multiple 3X-UI installation directories found:"
        echo ""
        local i=1
        for dir in "${found_dirs[@]}"; do
            echo "  $i) $dir"
            ((i++))
        done
        echo ""
        read -p "Select directory to uninstall [1-${#found_dirs[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#found_dirs[@]} ]; then
            echo "${found_dirs[$((choice-1))]}"
            return 0
        else
            error "Invalid selection"
            return 1
        fi
    fi
}

# ───────────────────────────────
# Get all installation directories
# ───────────────────────────────
get_all_dirs() {
    local dirs=()
    for dir in "$BASE_DIR"*; do
        if [ -d "$dir" ]; then
            dirs+=("$dir")
        fi
    done
    echo "${dirs[@]}"
}

# ───────────────────────────────
# Remove Caddyfile configuration for specific domain
# ───────────────────────────────
remove_caddy_config() {
    local dom_name=""
    if [ -d "$1" ]; then
        dom_name=$(grep "hostname:" "$1/compose.yml" 2>/dev/null | awk '{print $2}' | tr -d " ")
        if [ -n "$dom_name" ]; then
            info "Domain Name: $dom_name"
        else
            warn "No domain name found in compose.yml"
            return 0
        fi
    else
        warn "Installation directory not found"
        return 0
    fi

    local caddyfile="/etc/caddy/Caddyfile"

    # Check if Caddyfile exists
    if [ ! -f "$caddyfile" ]; then
        warn "Caddyfile not found at $caddyfile"
        return 0
    fi

    if ! grep -E "^$dom_name( |\{)" "$caddyfile" >/dev/null 2>&1; then
        info "Configuration for ${BLUE}$dom_name${NC} not found in Caddyfile"
        echo "[WARNING] Configuration for ${BLUE}$dom_name${NC} not found in Caddyfile"
        return 0
    fi

    awk -v dom="$dom_name" '
        $1 == dom {
            skip = 1
            brace = 0

            if ($0 ~ /\{/) brace++

            next
        }

        skip {
            if ($0 ~ /\{/) brace++
            if ($0 ~ /\}/) brace--

            if (brace == 0) {
                skip = 0
            }

            next
        }

        { print }
    ' "$caddyfile" | sudo tee "$caddyfile.tmp" >/dev/null

    sudo mv "$caddyfile.tmp" "$caddyfile"

    # Reload Caddy to apply changes
    if systemctl is-active --quiet caddy 2>/dev/null; then
        info "Reloading Caddy service..."
        sudo systemctl reload caddy 2>/dev/null || true
    fi

    success "Removed configuration from Caddyfile"
}

# ───────────────────────────────
# List Available Directories
# ───────────────────────────────
list_directories() {
    local found_dirs=()
    for dir in "$BASE_DIR"*; do
        if [ -d "$dir" ]; then
            found_dirs+=("$dir")
        fi
    done

    if [ ${#found_dirs[@]} -eq 0 ]; then
        echo "No 3X-UI installation directories found."
        return 1
    elif [ ${#found_dirs[@]} -eq 1 ]; then
        echo "Found ${#found_dirs[@]} 3X-UI installation directory:"
        echo ""
        echo "  1) ${found_dirs[0]}"
        if [ -f "${found_dirs[0]}/compose.yml" ]; then
            local container_name=$(grep "container_name:" "${found_dirs[0]}/compose.yml" 2>/dev/null | awk '{print $2}' | tr -d "'\"")
            local is_running=$(docker ps --filter "name=$container_name" --format "{{.Names}}" 2>/dev/null)
            local has_dom_name=$(grep "hostname:" "${found_dirs[0]}/compose.yml" 2>/dev/null | awk '{print $2}' | tr -d "'\"")
            if [ -n "$is_running" ]; then
                echo -e "     Status: ${GREEN}Running${NC} (Container: ${BLUE}$container_name${NC})"
                echo -e "     Domain: ${CYAN}$has_dom_name${NC}"
            else
                echo -e "     Status: ${YELLOW}Stopped${NC} (Container: ${BLUE}$container_name${NC})"
                echo -e "     Domain: ${CYAN}$has_dom_name${NC}"
            fi
        fi
        echo ""
    else
        echo "Found ${#found_dirs[@]} 3X-UI installation directories:"
        echo ""
        local i=1
        for dir in "${found_dirs[@]}"; do
            echo "  $i) $dir"
            # Show additional info if compose file exists
            if [ -f "$dir/compose.yml" ]; then
                local container_name=$(grep "container_name:" "$dir/compose.yml" 2>/dev/null | awk '{print $2}' | tr -d "'\"")
                local is_running=$(docker ps --filter "name=$container_name" --format "{{.Names}}" 2>/dev/null)
                local has_dom_name=$(grep "hostname:" "$dir/compose.yml" 2>/dev/null | awk '{print $2}' | tr -d "'\"")
                if [ -n "$is_running" ]; then
                    echo -e "     Status: ${GREEN}Running${NC} (Container: $container_name)"
                    echo -e "     Domain: ${CYAN}$has_dom_name${NC}"
                else
                    echo -e "     Status: ${YELLOW}Stopped${NC} (Container: $container_name)"
                    echo -e "     Domain: ${CYAN}$has_dom_name${NC}"
                fi
            fi
            echo ""
            ((i++))
        done
        echo "Use -d NUM to select which directory to uninstall."
        return 0
    fi
}

# ───────────────────────────────
# Remove single 3X-UI installation
# ───────────────────────────────
remove_single_installation() {
    local install_dir="$1"

    info "Removing single 3X-UI installation: $install_dir"
    echo ""

    # Remove container
    remove_3xui "$install_dir"
    echo ""

    # Remove Caddy config (if exists)
    if command -v caddy &> /dev/null; then
        remove_caddy_config "$install_dir"
        echo ""
    fi

    # Remove directory
    remove_install_dir "$install_dir"

    success "Installation removed successfully!"
}

# ───────────────────────────────
# Remove all 3X-UI installations
# ───────────────────────────────
remove_all_installations() {
    info "Removing ALL 3X-UI installations..."
    echo ""

    local dirs=($(get_all_dirs))

    if [ ${#dirs[@]} -eq 0 ]; then
        warn "No 3X-UI installations found"
        return 0
    fi

    info "Found ${#dirs[@]} installation(s)"
    for dir in "${dirs[@]}"; do
        echo "  • $dir"
    done
    echo ""

    read -p "Remove all these installations? [y/N]: " CONFIRM_ALL
    if [[ ! "$CONFIRM_ALL" =~ ^[Yy]$ ]]; then
        info "Operation cancelled"
        return 0
    fi

    for dir in "${dirs[@]}"; do
        echo ""
        banner "Removing: $dir"
        remove_single_installation "$dir"
    done

    echo ""
    success "All 3X-UI installations removed!"
    info "Docker and Caddy were preserved"
}

# ───────────────────────────────
# Purge everything
# ───────────────────────────────
purge_everything() {
    confirm_uninstall

    echo ""
    banner "═══════════════════════════════════════════════════════════"
    banner "Starting Complete Purge..."
    banner "═══════════════════════════════════════════════════════════"
    echo ""

    # Get all dirs
    local dirs=($(get_all_dirs))

    # Remove all 3X-UI installations
    if [ ${#dirs[@]} -gt 0 ]; then
        info "Removing ${#dirs[@]} 3X-UI installation(s)..."
        for dir in "${dirs[@]}"; do
            remove_3xui "$dir"
            remove_install_dir "$dir"
        done
        echo ""
    fi

    # Remove Caddy completely
    remove_caddy
    echo ""

    # Remove Docker completely
    remove_docker
    echo ""

    # Remove state
    remove_state
    echo ""

    # Cleanup
    cleanup_system

    show_summary
}

# ───────────────────────────────
# Show Usage
# ───────────────────────────────
show_usage() {
    cat << EOF
3X-UI Complete Uninstaller - Removes Docker, Caddy, and all related configurations

OPTIONS:
    -d, --dir NUM       Select directory number to uninstall (if multiple exist)
    -l, --list          List all 3X-UI installation directories and exit
    -h, --help          Show this help message

EXAMPLES:
    # Interactive mode (will prompt for selections)
    bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh)

    # List available installations
    bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) -l

    # Removes the directory, container, removes config from Caddyfile (if exists)
    bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) -d 1

    # Remove all directories for 3X-UI Panel (leaves Caddy and Docker installed)
    bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) --all

    # Purge everything (Caddy, Docker, every file/directory related to 3X-UI panel)
    bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) --purge

    # Local execution
    ./uninstall.sh -l
    ./uninstall.sh -d 2

NOTES:
    - If multiple 3x-uiPANEL directories exist, you'll be prompted to choose
    - Use -d option to preselect which directory to remove (avoids prompts)
    - Use -l option to see all installations without running uninstall
    - The script will still ask for confirmation before deleting

EOF
}

# ───────────────────────────────
# Main Uninstallation
# ───────────────────────────────
main() {
    local dir_selection=""
    local mode="interactive"  # interactive, single, all, purge

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                mode="single"
                dir_selection="$2"
                shift 2
                ;;
            -l|--list)
                list_directories
                exit $?
                ;;
            --all)
                mode="all"
                shift
                ;;
            --purge)
                mode="purge"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

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

    # Handle different modes
    case "$mode" in
        purge)
            purge_everything
            exit 0
            ;;
        all)
            remove_all_installations
            exit 0
            ;;
        single)
            # Detect specific directory
            info "Detecting 3X-UI installation..."
            INSTALL_DIR=$(detect_install_dir "$dir_selection")

            if [ -z "$INSTALL_DIR" ]; then
                error "No installation directory found"
                exit 1
            fi

            success "Found installation directory: $INSTALL_DIR"
            echo ""

            remove_single_installation "$INSTALL_DIR"
            exit 0
            ;;
        interactive)
            # Original full uninstall behavior with confirmation
            confirm_uninstall

            echo ""
            banner "═══════════════════════════════════════════════════════════"
            banner "Starting Uninstallation Process..."
            banner "═══════════════════════════════════════════════════════════"
            echo ""

            # Detect installation directory
            info "Detecting 3X-UI installation..."
            INSTALL_DIR=$(detect_install_dir "")

            if [ -n "$INSTALL_DIR" ]; then
                success "Found installation directory: $INSTALL_DIR"
            else
                warn "No installation directory detected"
                warn "Will attempt to remove any 3X-UI Docker containers anyway"
            fi
            echo ""

            # Remove in reverse order of installation
            remove_3xui "$INSTALL_DIR"
            echo ""

            remove_caddy
            echo ""

            remove_docker
            echo ""

            remove_install_dir "$INSTALL_DIR"
            echo ""

            remove_state
            echo ""

            cleanup_system

            show_summary
            ;;
    esac
}

main "$@"
