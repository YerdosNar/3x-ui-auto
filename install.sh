#!/usr/bin/env bash

readonly noc="\033[0m"
readonly red="\033[31m"
readonly grn="\033[32m"
readonly yel="\033[33m"
readonly blu="\033[34m"
readonly cyn="\033[36m"
readonly bld="\033[1m"

info()      { echo -e "${blu}[i]${noc} $1" ;    }
success()   { echo -e "${grn}[✓]${noc} $1" ;    }
warn()      { echo -e "${blu}[i]${noc} $1" ;    }
error()     { echo -e "${red}[X]${noc} $1" >&2; }
banner()    { echo -e "${cyn}${bld}$1${noc}" ;  }

log_info()      { echo -e "[ INFO ]  $1" >> "$LOG_FILE";    }
log_success()   { echo -e "[SUCCESS] $1" >> "$LOG_FILE";    }
log_warn()      { echo -e "[ WARN ]  $1" >> "$LOG_FILE";    }
log_error()     { echo -e "[ ERROR ] $1" >&2>> "$LOG_FILE"; }
log_banner()    { echo -e "[BANNER ] $1" >> "$LOG_FILE";    }

readonly STATE_FILE="/tmp/.3xui_state"
readonly LOG_FILE="/tmp/.3xui_log_$$"
readonly INSTALL_DIR="$HOME/3x-ui_$$"
readonly CADDYFILE="/etc/caddy/Caddyfile"

save_state() {
    info "Save state..."
    local stage=$1
    cat > "$STATE_FILE" <<EOF
STAGE=$stage
DOM_NAME=${DOM_NAME}
ADMIN_NAME=${ADMIN_NAME}
PASSWORD=${PASSWORD}
ROUTE=${ROUTE}
PORT=${PORT}
BE_PORT=${BE_PORT}
EOF
    chmod 600 "$STATE_FILE"
    success "State saved!"
}

load_state() {
    info "Loadin state..."
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        success "State loaded!"
        return 0
    fi
    info "No state file"
    return 1
}

clear_state() {
    info "Clearing state..."
    rm -f "$STATE_FILE"
    success "State cleared!"
}

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        error "Installation failed! Check log file: $LOG_FILE"
    fi
}
trap cleanup EXIT

# Validation
validate_domain() {
    info "Validating domain name..."
    local domain="$1"
    if [[ ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        error "Invalid domain name format: $domain"
        return 1
    fi
    success "Domain is valid!"
    return 0
}

validate_port() {
    info "Validating port..."
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error "Invalid port number: $port (must be 1-65535)"
        return 1
    fi
    success "Port is valid!"
    return 0
}

check_port_availability() {
    info "Checking port availability..."
    local port=$1
    if sudo lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        error "Port $port is already in use"
        return 1
    fi
    success "Port is available!"
    return 0
}

get_public_ip() {
    info "Getting public IP..."
    local ip
    ip=$(curl -s --max-time 5 ifconfig.me || curl -s --max-time 5 icanhazip.com || echo "")
    if [ -z "$ip" ]; then
        error "Failed to retrieve public IP"
        return 1
    fi
    success "Public IP: $ip"
    return 0
}

# check requirements
check_requirements() {
    info "Checking system requirements..."

    if [ "$EUID" -eq 0 ]; then
        error "Do ${red}${bld}NOT${noc} run this as root. Run as user with sudo privileges."
        exit 1
    fi

    if ! sudo -v; then
        error "Sudo authentication failed. SUDO privileges needed."
        exit 1
    fi

    source /etc/os-release
    if [[ ! "$ID" =~ ^(ubuntu|debian)$ ]]; then
        error "This script runs only in Ubuntu|Debian."
        exit 1
    fi

    local available_space=$(df -BG / | awk 'NR=2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 2 ]; then
        error "Insufficient disk space."
        echo "    Required : 2GB."
        echo "    Available: ${available_space}GB."
        exit 1
    fi

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
    return 0
}

docker_install() {
    info "Checking Docker installation..."

    if command -v docker &>/dev/null && docker --version &>/dev/null; then
        success "Docker is already installed: $(docker --version)"
        return 0
    fi

    info "Removing old Docker..."
    sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1) || true

    info "Updating system packages..."
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl gnupg lsb-release

    info "Setting up Docker repository..."
    sudo install -m 0755 -d /etc/apt/keyrings

    if [ -f /etc/apt/keyrings/docker.gpg ]; then
        sudo rm /etc/apt/keyrings/docker.gpg
    fi

    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    info "Add the repository to Apt sources:"
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    info "Updating the system..."
    sudo apt update

    info "Installing Docker..."
    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    success "Docker installation finished!"

    info "Enabling Docker service..."
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

    if ! groups $USER | grep -q "docker"; then
        info "Adding user '$USER' to docker group"
        sudo usermod -aG docker "$USER"

        warn "═══════════════════════════════════════════════════════════"
        warn "User added to docker group. Session restart required!"
        warn "═══════════════════════════════════════════════════════════"
        echo ""

        read -p "Is this a (S)erver or (L)ocal machine? [S/l]: " MACHINE_TYPE
        MACHINE_TYPE=${MACHINE_TYPE:-S}

        save_state "DOCKER_INSTALLED"

        if [[ "$MACHINE_TYPE" =~ ^[Ss]$ ]]; then
            warn "You need to LOG OUT and LOG back IN to apply group changes."
            warn "After LOGGIN IN, run this command again:"
            echo -e "${cyn}bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/install.sh)${noc}"
            echo ""
            read -p "Press ${yel}ENTER${noc} to logout now (or Ctrl+C to cancel)..."
            clear_state

            if [ -n "${SSH_CONNECTION:-}" ]; then
                kill -HUP "$PPID"
            else
                pkill -KILL -u "$USER"
            fi
            exit 0
        else
            warn "You need to REBOOT to apply group changes."
            warn "After reboot, run this command again: "
            echo -e "${cyn}bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/install.sh)${noc}"
            echo ""
            read -p "Reboot now? [Y/n]: " REBOOT
            REBOOT=${REBOOT:-Y}
            if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
                clear_state
                sudo reboot
            else
                warn "Please reboot manually ad run the script again."
                exit 0
            fi
        fi
    fi

    # Testing
    info "Testing Docker installation..."
    if docker run --rm hello-world >/dev/null 2>&1; then
        success "Docker test passed!"
    else
        error "Docker test failed. Try running: docker run hello-world"
        exit 1
    fi

    success "Docker installation completed!"
    return 0
}

create_compose() {
    info "Creating compose file"
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
    container_name: 3xui_app_$$
$c_dom_name
    volumes:
      - "\${PWD}/db/:/etc/x-ui/"
      - "\${PWD}/cert/:/root/cert/"
    environment:
      XRAY_VMESS_AEAD_FORCED: "false"
      XUI_ENABLE_FAIL2BAN: "true"
    tty: true
    network_mode: host
    restart: unless_stopped
EOF

    success "Docker compose file created at $INSTALL_DIR/"
    return 0
}

add_header_to_caddy() {
    info "Adding header to $file_to_add"
    local file_to_add="$1"
    read -r -d '' caddy_header <<'EOF'
{
    servers {
        proxy_protocol {
            timeout 2s
            allow 127.0.0.1/8
        }
    }
}
EOF
    local temp_caddyfile=$(mktemp)
    printf "%s\n" "$caddy_header" > "$temp_caddyfile"
    sudo cat "$file_to_add" >> "$temp_caddyfile"
    sudo mv "$temp_caddyfile" "$file_to_add"
    success "Header added to $file_to_add!"
    return 0
}

configure_caddy() {
    local dom_name="$1"
    local route="$2"
    local admin_name="$3"
    local hash_pw="$4"
    local port="$5"
    local be_port="$6"
    local redirect_port="$7"

    info "Creating Caddyfile configuration..."

}
