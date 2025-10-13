#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# 3X-UI Automated Installer with Docker & Caddy
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
# State File for Multi-Stage Installation
# ───────────────────────────────
readonly STATE_FILE="/tmp/.3xui_install_state"
readonly INSTALL_DIR="$HOME/3x-uiPANEL"

save_state() {
    cat > "$STATE_FILE" <<EOF
STAGE=$1
DOM_NAME=${DOM_NAME:-}
ADMIN_NAME=${ADMIN_NAME:-}
PASSWORD=${PASSWORD:-}
ROUTE=${ROUTE:-}
PORT=${PORT:-}
BE_PORT=${BE_PORT:-}
EOF
    chmod 600 "$STATE_FILE"
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        return 0
    fi
    return 1
}

clear_state() {
    rm -f "$STATE_FILE"
}

# ───────────────────────────────
# Cleanup on Exit
# ───────────────────────────────
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        error "Installation failed! Check the errors above."
    fi
}

trap cleanup EXIT

# ───────────────────────────────
# Validation Functions
# ───────────────────────────────
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        error "Invalid domain name format: $domain"
        return 1
    fi
    return 0
}

validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error "Invalid port number: $port (must be 1-65535)"
        return 1
    fi
    return 0
}

check_port_available() {
    local port="$1"
    if sudo lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        error "Port $port is already in use"
        return 1
    fi
    return 0
}

generate_strong_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 16
}

get_public_ip() {
    local ip
    ip=$(curl -s --max-time 5 ifconfig.me || curl -s --max-time 5 icanhazip.com || echo "")
    if [ -z "$ip" ]; then
        error "Failed to retrieve public IP address"
        return 1
    fi
    echo "$ip"
}

# ───────────────────────────────
# System Requirements Check
# ───────────────────────────────
check_requirements() {
    info "Checking system requirements..."

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

    # Check OS
    if [ ! -f /etc/os-release ]; then
        error "Cannot determine OS. This script is designed for Ubuntu/Debian."
        exit 1
    fi

    source /etc/os-release
    if [[ ! "$ID" =~ ^(ubuntu|debian)$ ]]; then
        warn "This script is tested on Ubuntu/Debian. Your OS: $ID"
        read -p "Continue anyway? [y/N]: " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    # Check available disk space (minimum 2GB)
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 2 ]; then
        error "Insufficient disk space. At least 2GB required. Available: ${available_space}GB"
        exit 1
    fi

    # Check required commands
    local missing_cmds=()
    for cmd in curl gpg apt-get systemctl; do
        if ! command -v $cmd &> /dev/null; then
            missing_cmds+=("$cmd")
        fi
    done

    if [ ${#missing_cmds[@]} -gt 0 ]; then
        error "Missing required commands: ${missing_cmds[*]}"
        exit 1
    fi

    success "System requirements check passed!"
}

# ───────────────────────────────
# Docker Installation
# ───────────────────────────────
docker_install() {
    info "Checking Docker installation..."

    if command -v docker &> /dev/null && docker --version &> /dev/null; then
        success "Docker is already installed: $(docker --version)"
        return 0
    fi

    info "Removing old Docker packages..."
    sudo apt-get remove -y docker docker.io docker-doc docker-compose \
        docker-compose-v2 podman-docker containerd runc 2>/dev/null || true

    info "Updating system packages..."
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl gnupg lsb-release

    info "Setting up Docker repository..."
    sudo install -m 0755 -d /etc/apt/keyrings

    if [ -f /etc/apt/keyrings/docker.gpg ]; then
        sudo rm /etc/apt/keyrings/docker.gpg
    fi

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    info "Installing Docker and Docker Compose..."
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    info "Enabling Docker service..."
    sudo systemctl enable --now docker

    # Wait for Docker to be ready
    info "Waiting for Docker daemon to start..."
    for i in {1..30}; do
        if sudo docker info >/dev/null 2>&1; then
            success "Docker daemon is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            error "Docker daemon failed to start within 30 seconds"
            exit 1
        fi
        sleep 1
    done

    # Check if user is in docker group
    if ! groups $USER | grep -q "docker"; then
        info "Adding user '$USER' to docker group..."
        sudo usermod -aG docker "$USER"

        warn "═══════════════════════════════════════════════════════════"
        warn "User added to docker group. Session restart required!"
        warn "═══════════════════════════════════════════════════════════"
        echo ""

        read -p "Is this a SERVER (VPS) or LOCAL machine? [s/L]: " MACHINE_TYPE
        MACHINE_TYPE=${MACHINE_TYPE:-L}

        save_state "DOCKER_INSTALLED"

        if [[ "$MACHINE_TYPE" =~ ^[Ss]$ ]]; then
            warn "You need to LOG OUT and LOG BACK IN to apply group changes."
            warn "After logging back in, run this command again:"
            echo -e "${CYAN}bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/one_liner.sh)${NC}"
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
            warn "You need to REBOOT your machine to apply group changes."
            warn "After reboot, run this command again:"
            echo -e "${CYAN}bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/one_liner.sh)${NC}"
            echo ""
            read -p "Reboot now? [Y/n]: " REBOOT
            REBOOT=${REBOOT:-Y}
            if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
                clear_state
                sudo reboot
            else
                warn "Please reboot manually and run the script again."
                exit 0
            fi
        fi
    fi

    # Test Docker
    info "Testing Docker installation..."
    if docker run --rm hello-world >/dev/null 2>&1; then
        success "Docker test passed!"
    else
        error "Docker test failed. Try running: docker run hello-world"
        exit 1
    fi

    success "Docker installation completed!"
}

# ───────────────────────────────
# 3X-UI Docker Compose
# ───────────────────────────────
create_compose() {
    local dom_name="$1"
    local c_dom_name

    if [ -n "$dom_name" ]; then
        c_dom_name="    hostname: $dom_name"
    else
        c_dom_name="    # hostname: example.com"
    fi

    cat > "$INSTALL_DIR/compose.yml" <<EOF
services:
  3xui:
    image: ghcr.io/mhsanaei/3x-ui:latest
    container_name: 3xui_app
$c_dom_name
    volumes:
      - "\${PWD}/db/:/etc/x-ui/"
      - "\${PWD}/cert/:/root/cert/"
    environment:
      XRAY_VMESS_AEAD_FORCED: "false"
      XUI_ENABLE_FAIL2BAN: "true"
    tty: true
    network_mode: host
    restart: unless-stopped
EOF

    success "Docker compose file created at $INSTALL_DIR/compose.yml"
}

# ───────────────────────────────
# Caddy Configuration
# ───────────────────────────────
configure_caddy() {
    local dom_name="$1"
    local route="$2"
    local admin_name="$3"
    local hash_pw="$4"
    local port="$5"
    local be_port="$6"

    cat > "$INSTALL_DIR/Caddyfile" <<EOF
$dom_name {
	encode gzip

	tls {
		protocols tls1.3
	}

	header {
		header_up Authorization {>Authorization}
		header_up Content-Type {>Content-Type}

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

    success "Caddyfile created at $INSTALL_DIR/Caddyfile"
}

caddy_install() {
    local dom_name="$1"

    info "Checking Caddy installation..."

    if command -v caddy &> /dev/null; then
        success "Caddy is already installed: $(caddy version)"
    else
        info "Installing Caddy..."
        sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
            sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
            sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null

        sudo apt update
        sudo apt install -y caddy

        success "Caddy installed!"
    fi

    info "Configuring Caddy reverse proxy..."
    echo ""

    # Admin credentials
    read -p "Enter admin username [default: admin]: " ADMIN_NAME
    ADMIN_NAME=${ADMIN_NAME:-admin}

    echo -ne "${YELLOW}Generate strong random password? [Y/n]: ${NC}"
    read GEN_PASS
    GEN_PASS=${GEN_PASS:-Y}

    if [[ "$GEN_PASS" =~ ^[Yy]$ ]]; then
        PASSWORD=$(generate_strong_password)
        echo -e "${GREEN}Generated password:${NC} ${BOLD}$PASSWORD${NC}"
        echo -e "${YELLOW}SAVE THIS PASSWORD - it will only be shown once!${NC}"
        echo ""
        read -p "Press Enter to continue..."
    else
        read -sp "Enter admin password [default: admin]: " PASSWORD
        echo ""
        PASSWORD=${PASSWORD:-admin}
        if [ "$PASSWORD" == "admin" ]; then
            warn "Using default password 'admin' - consider changing this later!"
        fi
    fi

    HASH_PW=$(caddy hash-password --plaintext "$PASSWORD")

    # Route configuration
    echo ""
    read -p "Enter route nickname (panel will be at /<name>-admin) [default: admin]: " N_NAME
    N_NAME=${N_NAME:-admin}
    ROUTE="${N_NAME}-admin"
    if [ "$N_NAME" == "admin" ]; then
        ROUTE="admin"
    fi

    # Port configuration
    echo ""
    while true; do
        read -p "Enter API port [default: 8443]: " PORT
        PORT=${PORT:-8443}
        if validate_port "$PORT" && check_port_available "$PORT"; then
            break
        fi
    done

    while true; do
        read -p "Enter backend port [default: 2087]: " BE_PORT
        BE_PORT=${BE_PORT:-2087}
        if validate_port "$BE_PORT" && check_port_available "$BE_PORT"; then
            break
        fi
    done

    configure_caddy "$dom_name" "$ROUTE" "$ADMIN_NAME" "$HASH_PW" "$PORT" "$BE_PORT"

    info "Installing Caddyfile..."
    sudo cp "$INSTALL_DIR/Caddyfile" /etc/caddy/Caddyfile

    info "Testing Caddy configuration..."
    if sudo caddy validate --config /etc/caddy/Caddyfile; then
        success "Caddy configuration is valid!"
    else
        error "Caddy configuration validation failed!"
        exit 1
    fi

    info "Starting Caddy service..."
    sudo systemctl enable --now caddy

    # Wait for Caddy to start
    sleep 2

    if systemctl is-active --quiet caddy; then
        success "Caddy is running!"
        echo ""
        banner "═══════════════════════════════════════════════════════════"
        banner "               3X-UI Panel Access Information"
        banner "═══════════════════════════════════════════════════════════"
        echo -e "${GREEN}Panel URL:${NC}      https://$dom_name/$ROUTE"
        echo -e "${GREEN}Admin User:${NC}     $ADMIN_NAME"
        echo -e "${GREEN}Password:${NC}       $PASSWORD"
        echo -e "${GREEN}API Endpoint:${NC}   https://$dom_name/api/v1"
        banner "═══════════════════════════════════════════════════════════"
    else
        error "Caddy failed to start!"
        sudo journalctl -u caddy -n 50 --no-pager
        exit 1
    fi
}

# ───────────────────────────────
# Main Installation
# ───────────────────────────────
main() {
    clear
    banner "═══════════════════════════════════════════════════════════"
    banner "           3X-UI Automated Installer v2.0"
    banner "═══════════════════════════════════════════════════════════"
    echo ""

    # Check if resuming from saved state
    if load_state; then
        info "Resuming installation from stage: $STAGE"
        case "$STAGE" in
            DOCKER_INSTALLED)
                info "Docker was installed. Checking group membership..."
                if ! groups $USER | grep -q "docker"; then
                    error "User still not in docker group. Please log out/reboot and try again."
                    exit 1
                fi
                if ! docker info >/dev/null 2>&1; then
                    error "Cannot connect to Docker. Please log out/reboot and try again."
                    exit 1
                fi
                success "Docker access confirmed! Continuing installation..."
                clear_state
                ;;
        esac
    fi

    check_requirements
    docker_install

    # Create installation directory
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
        success "Created installation directory: $INSTALL_DIR"
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
                info "Testing DNS resolution for $DOM_NAME..."
                if host "$DOM_NAME" >/dev/null 2>&1; then
                    success "Domain $DOM_NAME resolves successfully!"
                    break
                else
                    warn "Domain $DOM_NAME does not resolve to an IP yet."
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
            info "Your public IP: $PUB_IP"
        fi
        create_compose
    fi

    # Start 3X-UI container
    info "Starting 3X-UI container..."
    cd "$INSTALL_DIR"

    if docker compose up -d; then
        success "3X-UI container started!"

        # Wait for container to be healthy
        info "Waiting for 3X-UI to be ready..."
        sleep 5

        if docker ps | grep -q 3xui_app; then
            success "3X-UI container is running!"
        else
            error "3X-UI container failed to start!"
            docker logs 3xui_app
            exit 1
        fi
    else
        error "Failed to start 3X-UI container!"
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
            warn "Skipping Caddy setup."
            info "Access 3X-UI at: http://$DOM_NAME:2053"
            info "Default credentials: admin / admin"
        fi
    else
        PUB_IP=$(get_public_ip)
        warn "═══════════════════════════════════════════════════════════"
        warn "No domain configured - HTTPS not available"
        warn "═══════════════════════════════════════════════════════════"
        echo -e "${GREEN}Panel URL:${NC}      http://$PUB_IP:2053"
        echo -e "${GREEN}Default Login:${NC}  admin / admin"
        warn "═══════════════════════════════════════════════════════════"
        warn "IMPORTANT: Change default credentials after first login!"
        warn "═══════════════════════════════════════════════════════════"
    fi

    echo ""
    success "═══════════════════════════════════════════════════════════"
    success "           Installation completed successfully!"
    success "═══════════════════════════════════════════════════════════"
    echo ""
    info "Installation directory: $INSTALL_DIR"
    info "Docker compose file: $INSTALL_DIR/compose.yml"
    if [ -f "$INSTALL_DIR/Caddyfile" ]; then
        info "Caddyfile: $INSTALL_DIR/Caddyfile"
    fi
    echo ""
    info "Useful commands:"
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
