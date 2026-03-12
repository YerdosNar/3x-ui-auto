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

readonly STATE_FILE="/tmp/.3xui_state"
readonly LOG_FILE="/tmp/.3xui_log"
readonly INSTALL_DIR="$HOME/3x-ui"
readonly CADDYFILE="/etc/caddy/Caddyfile"
readonly CONTAINER_NAME="3xui_app"

# Not to overwrite existing files
rename_file() {
    local file="$1"
    local f_name="${file%.*}"
    local f_ext="${file##*.}"

    local count=1
    local new_f="$file"

    while [ -e "$new_f" ]; do
        new_f="${f_name}($count).$f_ext"
        ((count++))
    done

    echo "$new_f"
}

file_init() {
    INSTALL_DIR=$(rename_file "$INSTALL_DIR")
    CONTAINER_NAME=$(rename_file "$CONTAINER_NAME")
}

# Initialize log file
log_init() {
    echo "====================================" >  "$LOG_FILE"
    echo "# Log file created at $(date)"    >> "$LOG_FILE"
    echo "====================================" >> "$LOG_FILE"
    chmod 600 "$LOG_FILE"
}

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
    info "Loading state..."
    if [ -f "$STATE_FILE" ]; then
        # shellcheck source=/dev/null
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
    local port="$1"
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
        echo ""
        return 1
    fi
    success "Public IP: $ip"
    echo "$ip"
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

    local available_space
    available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 2 ]; then
        error "Insufficient disk space."
        echo "    Required : 2GB."
        echo "    Available: ${available_space}GB."
        exit 1
    fi

    local missing_cmds=()
    for cmd in curl gpg apt-get systemctl lsof; do
        if ! command -v "$cmd" &> /dev/null; then
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
    sudo apt-get remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1) 2>&1 | tee -a "$LOG_FILE" >/dev/null || true

    info "Updating system packages..."
    sudo apt-get update -y 2>&1 | tee -a "$LOG_FILE" >/dev/null
    sudo apt-get install -y ca-certificates curl gnupg lsb-release 2>&1 | tee -a "$LOG_FILE" >/dev/null

    info "Setting up Docker repository..."
    sudo install -m 0755 -d /etc/apt/keyrings

    if [ -f /etc/apt/keyrings/docker.gpg ]; then
        sudo rm /etc/apt/keyrings/docker.gpg
    fi

    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc 2>> "$LOG_FILE"
    sudo chmod a+r /etc/apt/keyrings/docker.asc 2>> "$LOG_FILE"

    info "Add the repository to Apt sources:"
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    info "Updating the system..."
    sudo apt-get update 2>&1 | tee -a "$LOG_FILE" >/dev/null

    info "Installing Docker..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>&1 | tee -a "$LOG_FILE" >/dev/null

    success "Docker installation finished!"

    info "Enabling Docker service..."
    sudo systemctl enable docker 2>/dev/null || true
    sudo systemctl start docker 2>/dev/null || true

    for i in {1..30}; do
        if sudo docker info >/dev/null 2>&1; then
            success "Docker daemon is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            error "Docker daemon failed to start within 30 seconds"
            sudo journalctl -u docker -n 20 --no-pager
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
            echo -e "Press ${yel}ENTER${noc} to logout now (or Ctrl+C to cancel)..."
            read
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
                sudo reboot
            else
                warn "Please reboot manually and run the script again."
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
    container_name: $CONTAINER_NAME
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

    success "Docker compose file created at $INSTALL_DIR/"
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
    if [ -f "$CADDYFILE" ]; then
        success "$CADDYFILE exists"
    else
        info "$CADDYFILE not found, creating new one..."
    fi

    cat > "$INSTALL_DIR/Caddyfile" <<EOF
$dom_name:$redirect_port {
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
        respond "Not found" 404
    }
}
EOF
    success "Caddyfile created at $INSTALL_DIR/Caddyfile"

    return 0
}

configure_3xui_panel() {
    local port="$1"
    local route="$2"
    local username="$3"
    local password="$4"

    local temp_output="/tmp/3xui_output_$$.txt"
    local cookie_file="/tmp/3xui_cookies_$$.txt"
    local base_url="http://localhost:2053"

    restart_function() {
        info "Restarting 3X-UI panel..."
        curl -s --fail --max-time 10 -b "$cookie_file" -X POST \
            "$base_url/panel/setting/restartPanel" \
            > "$temp_output"

        if grep -Eq '"success":\s*true|successfully' "$temp_output"; then
            success "Restarted successfully!"
        else
            warn "Could not restart panel, further commands may fail..."
        fi
    }

    login_function() {
        local login_username="$1"
        local login_password="$2"
        curl -s --fail --max-time 10 -c "$cookie_file" -X POST \
            "$base_url/login" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "username=$login_username&password=$login_password" \
            > "$temp_output"

        if ! grep -Eq '"success":\s*true|successfully' "$temp_output"; then
            warn "Failed to login to 3X-UI panel"
            rm -f "$cookie_file"
            return 1
        else
            success "Logged in successfully ($login_username/$login_password)!"
            return 0
        fi
    }

    info "Configuring 3X-UI panel setting automatically..."
    local max_attempts=30
    local attempt=0

    info "Waiting for 3X-UI panel to be ready..."
    while [ $attempt -lt $max_attempts ]; do
        info "Attempt: $((attempt+1))/$max_attempts..."
        if curl -s --fail --max-time 5 "$base_url" >/dev/null 2>&1; then
            success "3X-UI is responding!"
            break
        fi
        attempt=$((attempt+1))
        sleep 1
    done

    if [ $attempt -eq $max_attempts ]; then
        warn "Could not verify 3X-UI is ready. Configuration may fail."
        return 1
    fi

    sleep 2

    info "Logging in to 3X-UI panel..."
    if ! login_function "admin" "admin"; then
        error "Initial login with (admin/admin) failed. Aborting..."
        return 1
    fi

    info "Updating admin credentials..."
    curl -s --fail --max-time 10 -b "$cookie_file" -X POST                                  \
        "$base_url/panel/setting/updateUser"                                                 \
        -H "Content-Type: application/x-www-form-urlencoded"                                 \
        -d "oldUsername=admin&oldPassword=admin&newUsername=$username&newPassword=$password" \
        > "$temp_output"

    if grep -Eq '"success":\s*true|successfully' "$temp_output"; then
        success "Admin credentials updated!"
    else
        warn "Could not update credentials automatically."
    fi

    restart_function

    if ! login_function "$username" "$password"; then
        error "Login with updated credentials failed. Aborting..."
        return 1
    fi

    info "Updating panel port to $port and path to /$route..."
    curl -s --fail --max-time 10 -b "$cookie_file" -X POST \
        "$base_url/panel/setting/update"                                            \
        -H "Content-Type: application/x-www-form-urlencoded"                        \
        -d "webPort=$port&subPort=2096&webBasePath=/$route&webCertFile=&webKeyFile="\
        > "$temp_output"

    if grep -Eq 'The parameters have been changed' "$temp_output"; then
        success "Panel settings updated!"
    else
        warn "Could not update panel settings automatically"
        rm -f "$cookie_file"
        return 1
    fi

    restart_function

    info "Waiting for panel to restart..."

    local verify_attempts=0
    while [ $verify_attempts -lt 10 ]; do
        info "Attempt: $((verify_attempts+1))"
        if curl -s --fail --max-time 5 "http://localhost:$port/$route" >/dev/null 2>&1; then
            success "Panel is accessible on new port $port!"
            return 0
        fi
        verify_attempts=$((verify_attempts+1))
        sleep 1
    done

    warn "Could not verify panel on new port, but settings were applied."
    return 0
}

open_browser() {
    local port="$1"
    local route="$2"
    local admin_name="$3"
    local password="$4"
    local dom_name="$5"

    info "Finding SSH port..."
    local ssh_port
    ssh_port=$(grep -i "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    ssh_port=${ssh_port:-22}
    success "SSH Port: $ssh_port"

    echo ""
    echo -e "${red}${bld}MANUAL SETUP REQUIRED${noc}"
    echo ""
    echo -e "${yel}First, create an SSH tunnel from your LOCAL machine:${noc}"
    echo ""
    echo -e "  ${cyn}ssh -p $ssh_port -L 8080:localhost:2053 $USER@$dom_name${noc}"
    echo ""
    echo -e "${yel}Then follow these steps in your browser(ORDER MATTERS):${noc}"
    echo ""
    echo -e "  1. Open: ${cyn}http://localhost:8080${noc}"
    echo -e "  2. Login with default credentials: ${grn}admin${noc} / ${grn}admin${noc}"
    echo -e "  3. Navigate to: ${yel}Authentication${noc}"
    echo -e "  4. Enter ${yel}Current Username${noc}: ${blu}admin${noc}"
    echo -e "  5. Enter ${yel}Current Password${noc}: ${blu}admin${noc}"
    echo -e "  6. Enter ${yel}New Username${noc}: ${blu}$ADMIN_NAME${noc}"
    echo -e "  7. Enter ${yel}New Password${noc}: ${blu}$PASSWORD${noc}"
    echo -e "  8. Click ${blu}Save${noc}"
    echo -e "  9. Navigate to: ${yel}Panel Settings${noc}"
    echo -e " 10. Change ${yel}Listen Port${noc} to: ${blu}$port${noc}"
    echo -e " 11. Change ${yel}URI Path${noc} to: ${blu}/$route${noc}"
    echo -e " 12. Click ${blu}Save${noc}"
    echo -e " 13. Click ${blu}Restart Panel${noc}"
    echo ""
    echo -e "${yel}Note: The panel will close after restart. Close the SSH tunnel after.${noc}"
    echo ""
    echo -ne "Press ${yel}ENTER${noc} after completing these steps and the panel has restarted. "
    read
    echo ""

    return 0
}

caddy_install() {
    local dom_name="$1"

    info "Checking Caddy installation..."

    if command -v caddy &> /dev/null; then
        success "Caddy is already installed: $(caddy version)"
    else
        info "Installing Caddy..."
        sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl 2>&1 | tee -a "$LOG_FILE" >/dev/null

        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' 2>> "$LOG_FILE" | sudo gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>> "$LOG_FILE"

        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' 2>> "$LOG_FILE" | sudo tee /etc/apt/sources.list.d/caddy-stable.list 2>> "$LOG_FILE"

        sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null || true

        sudo chmod o+r /etc/apt/sources.list.d/caddy-stable.list 2>/dev/null || true

        sudo apt-get update 2>&1 | tee -a "$LOG_FILE" >/dev/null
        sudo apt-get install -y caddy 2>&1 | tee -a "$LOG_FILE" >/dev/null

        info "Deleting default Caddyfile..."
        sudo rm -f /etc/caddy/Caddyfile

        success "Caddy installed!"
    fi

    info "Configuring Caddy reverse proxy..."
    echo ""

    read -p "Enter admin username [default: admin]: " ADMIN_NAME
    ADMIN_NAME=${ADMIN_NAME:-admin}

    while true; do
        read -sp "Enter admin password [default: admin]: " PASSWORD
        PASSWORD=${PASSWORD:-admin}
        echo ""
        local check_pw
        read -sp "Enter admin password again: " check_pw
        echo ""
        if [ "$PASSWORD" == "$check_pw" ]; then
            break
        fi
    done

    if [ "$PASSWORD" == "admin" ]; then
        warn "Using default password. Consider changing later!"
    fi

    HASH_PW=$(caddy hash-password --plaintext "$PASSWORD")

    echo ""
    read -p "Enter route nickname (panel will be at /<n>-admin) [default: admin]: " N_NAME
    N_NAME=${N_NAME:-admin}
    ROUTE="${N_NAME}-admin"
    if [ "$N_NAME" == "admin" ]; then
        ROUTE="admin"
    fi

    echo ""
    while true; do
        read -p "Enter API port [default: 8443]: " PORT
        PORT=${PORT:-8443}
        if validate_port "$PORT" && check_port_availability "$PORT"; then
            break
        fi
    done

    while true; do
        read -p "Enter backend port [default: 2087]: " BE_PORT
        BE_PORT=${BE_PORT:-2087}
        if validate_port "$BE_PORT" && check_port_availability "$BE_PORT"; then
            break
        fi
    done

    while true; do
        read -p "Enter port for Caddy [default: $((PORT-1))]: " REDIRECT_PORT
        REDIRECT_PORT=${REDIRECT_PORT:-$((PORT-1))}
        if validate_port "$REDIRECT_PORT" && check_port_availability "$REDIRECT_PORT"; then
            break
        fi
    done

    configure_caddy "$dom_name" "$ROUTE" "$ADMIN_NAME" "$HASH_PW" "$PORT" "$BE_PORT" "$REDIRECT_PORT"

    info "Installing Caddyfile..."
    if [ -f "$CADDYFILE" ]; then
        info "Existing Caddyfile found at $CADDYFILE"

        if sudo grep -qE "^$dom_name(:|[[:space:]]|\{|$)" "$CADDYFILE"; then
            warn "Domain $dom_name already exists in Caddyfile."
            echo ""
            read -p "Overwrite existing configuration for $dom_name? [y/N]: " OVERWRITE
            if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
                local backup_file
                backup_file="/etc/caddy/Caddyfile.backup.$(date +%s)"
                sudo cp "$CADDYFILE" "$backup_file"

                info "Removing old configuration for $dom_name..."
                sudo awk -v domain="$dom_name" '
                    BEGIN { skip=0; brace_count=0 }

                    $1 == domain || $1 ~ "^" domain ":" || $1 ~ "^" domain "{" {
                        skip=1
                        for (i=1; i<=NF; i++) {
                            if ($i ~ /{/) brace_count++
                            if ($i ~ /}/) brace_count--
                        }
                        if (brace_count == 0) skip=0
                        next
                    }

                    skip {
                        for(i=1; i<=NF; i++) {
                            if ($i ~ /{/) brace_count++
                            if ($i ~ /}/) brace_count--
                        }
                        if (brace_count == 0) skip=0
                        next
                    }

                    !skip { print }
                ' "$CADDYFILE" | sudo tee /tmp/Caddyfile.tmp >/dev/null

                if [ -s /tmp/Caddyfile.tmp ]; then
                    sudo mv /tmp/Caddyfile.tmp "$CADDYFILE"
                else
                    error "Failed to remove old configuration - backup reserved."
                    sudo rm -f /tmp/Caddyfile.tmp
                fi

                info "Appending new configuration for $dom_name"
                echo "" | sudo tee -a "$CADDYFILE"
                sudo cat "$INSTALL_DIR/Caddyfile" | sudo tee -a "$CADDYFILE"
                success "Configuration for $dom_name appended to Caddyfile!"
            else
                warn "Keeping existing configuration."
                warn "New config saved to: $INSTALL_DIR/Caddyfile."
                warn "You can manually merge configurations if needed."
            fi
        else
            info "Domain not found in existing Caddyfile, appending..."
            local backup_file
            backup_file="/etc/caddy/Caddyfile.backup.$(date +%s)"
            sudo cp "$CADDYFILE" "$backup_file"
            success "Backup created: $backup_file"

            echo "" | sudo tee -a "$CADDYFILE"
            echo "# 3X-UI Configuration for $dom_name - Added $(date)" | sudo tee -a "$CADDYFILE"
            sudo cat "$INSTALL_DIR/Caddyfile" | sudo tee -a "$CADDYFILE"
            success "Configuration appended to existing Caddyfile!"
        fi
    else
        info "No existing Caddyfile found, creating new one..."
        sudo mkdir -p /etc/caddy
        sudo cp $INSTALL_DIR/Caddyfile "$CADDYFILE"
        success "New Caddyfile created!"
    fi

    sudo chmod 644 "$CADDYFILE"

    info "Testing Caddy configuration..."
    if sudo caddy fmt --overwrite "$CADDYFILE"; then
        success "FMT --overwrite"
    fi
    if sudo caddy validate --config "$CADDYFILE"; then
        success "Caddy configuration is valid!"
    else
        error "Caddy configuration validation failed!"
        error "Check the configuration at $CADDYFILE"
        echo ""

        if ls /etc/caddy/Caddyfile.backup.* 1>/dev/null 2>&1; then
            local latest_backup
            latest_backup=$(ls -t /etc/caddy/Caddyfile.backup.* | head -1)
            echo ""
            local restore_backup
            read -p "Restore from backup? [Y/n]: " restore_backup
            restore_backup=${restore_backup:-Y}
            if [[ "$restore_backup" =~ ^[Yy]$ ]]; then
                sudo cp "$latest_backup" "$CADDYFILE"
                sudo chmod 644 "$CADDYFILE"
                success "Backup restored: $latest_backup"
            else
                warn "Manual restoration command: "
                warn "sudo cp $latest_backup $CADDYFILE"
            fi
        fi
    fi

    info "Starting Caddy service..."
    sudo systemctl enable --now caddy

    sleep 2

    if systemctl is-active --quiet caddy; then
        success "Caddy is running!"
        echo ""

        echo "You can configure by opening browser:"
        echo "  Open 'http://localhost:8080'"
        echo ""
        echo "Or we can configure for you (NOT RECOMMENDED)"
        local auto_or_browser
        read -p "${bld}${cyn}A${noc}utoconfigure/${bld}${cyn}C${noc}onfigure by yourself [a/C]: " auto_or_browser
        if [[ "$auto_or_browser" =~ ^[Aa]$ ]]; then
            if configure_3xui_panel "$BE_PORT" "$ROUTE" "$ADMIN_NAME" "$PASSWORD"; then
                sudo systemctl restart caddy
                echo ""
                banner "═══════════════════════════════════════════════════════════"
                banner "    ✓ 3X-UI Panel Configured Automatically!"
                banner "═══════════════════════════════════════════════════════════"
                echo -e "${grn}Panel URL:${noc}     https://$dom_name:$REDIRECT_PORT/$ROUTE"
                echo -e "${grn}Admin User:${noc}    $ADMIN_NAME"
                echo -e "${grn}Password:${noc}      $PASSWORD"
                echo -e "${grn}API Endpoint:${noc}  https://$dom_name/api/v1"
                banner "═══════════════════════════════════════════════════════════"
            else
                echo ""
                echo -e "${red}${bld}!ATTENTION! - MANUAL SETUP REQUIRED${noc}"
                echo ""
                warn "Automatic configuration failed. Please complete these steps manually:"
                echo ""
                echo -e "${yel}Step-by-step instructions:${noc}"
                echo ""
                echo -e "  1. Open: ${cyn}https://$dom_name:2053${noc}"
                echo -e "  2. Login with default credentials: ${grn}admin${noc} / ${grn}admin${noc}"
                echo -e "  3. Navigate to: ${yel}Panel Settings${noc}"
                echo -e "  4. Change ${yel}Listen Port${noc} to: ${blu}$PORT${noc}"
                echo -e "  5. Change ${yel}URI Path${noc} to: ${blu}/$ROUTE${noc}"
                echo -e "  6. Click ${blu}Save${noc}"
                echo -e "  7. Navigate to: ${yel}Authentication${noc}"
                echo -e "  8. Enter ${yel}Current Username${noc}: ${blu}admin${noc}"
                echo -e "  9. Enter ${yel}Current Password${noc}: ${blu}admin${noc}"
                echo -e " 10. Enter ${yel}New Username${noc}: ${blu}$ADMIN_NAME${noc}"
                echo -e " 11. Enter ${yel}New Password${noc}: ${blu}$PASSWORD${noc}"
                echo -e " 12. Click ${blu}Save${noc}"
                echo -e " 13. Click ${blu}Restart Panel${noc}"
                echo ""
                echo -e "${yel}Note: The panel will close after restart.${noc}"
                echo ""
                read -p "Press ${yel}ENTER${noc} after completing these steps and the panel has restarted."
                echo ""
                banner "═══════════════════════════════════════════════════════════"
                banner "                  3X-UI Panel Access Information"
                banner "═══════════════════════════════════════════════════════════"
                echo -e "${grn}Panel URL:${noc}     https://$dom_name:$REDIRECT_PORT/$ROUTE"
                echo -e "${grn}Admin User:${noc}    $ADMIN_NAME"
                echo -e "${grn}Password:${noc}      $PASSWORD"
                echo -e "${grn}API Endpoint:${noc}  https://$dom_name/api/v1"
                banner "═══════════════════════════════════════════════════════════"
            fi
        else
            open_browser "$BE_PORT" "$ROUTE" "$ADMIN_NAME" "$PASSWORD" "$dom_name"
            sudo systemctl restart caddy
            echo ""
            banner "═══════════════════════════════════════════════════════════"
            banner "                  3X-UI Panel Access Information"
            banner "═══════════════════════════════════════════════════════════"
            echo -e "${grn}Panel URL:${noc}     https://$dom_name:$REDIRECT_PORT/$ROUTE"
            echo -e "${grn}Admin User:${noc}    $ADMIN_NAME"
            echo -e "${grn}Password:${noc}      $PASSWORD"
            echo -e "${grn}API Endpoint:${noc}  https://$dom_name/api/v1"
            banner "═══════════════════════════════════════════════════════════"
        fi
    else
        error "Caddy failed to start!"
        sudo journalctl -u caddy -n 50 --no-pager
        exit 1
    fi

    return 0
}

main() {
    clear
    file_init
    log_init
    banner "═══════════════════════════════════════════════════════════"
    banner "            3X-UI Automated Installer v2.2"
    banner "═══════════════════════════════════════════════════════════"
    echo ""

    if load_state; then
        info "Resuming installation from stage: $STAGE"
        case "$STAGE" in
            DOCKER_INSTALLED)
                info "Docker was installed. Checking group membership..."
                if ! groups $USER | grep -q "docker"; then
                    error "User still not in docker group. Please log out/reboot and try again."
                    sudo usermod -aG docker $USER
                    exit 1
                fi
                if ! docker info >/dev/null 2>&1; then
                    error "Cannot connect to Docker. Please log out/reboot and try again."
                    exit 1
                fi
                success "Docker access confirmed! Continuing..."
                clear_state
                ;;
        esac
    fi

    check_requirements
    docker_install

    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
        success "Created installation directory: $INSTALL_DIR"
    fi

    cd "$INSTALL_DIR" || exit 1

    echo ""
    echo -ne "${blu}Do you have a domain name? [Y/n]: ${noc}"
    read DN_EXIST
    DN_EXIST=${DN_EXIST:-Y}

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

    info "Starting 3X-UI container..."
    if [ ! -f "$INSTALL_DIR/compose.yml" ]; then
        error "compose.yml not found in $INSTALL_DIR"
        exit 1
    fi

    cd "$INSTALL_DIR" || {
        error "Failed to change directory to $INSTALL_DIR"
        exit 1
    }

    if docker compose up -d; then
        success "3X-UI container started!"

        info "Waiting for 3X-UI to be ready..."
        sleep 5

        if docker ps | grep -q "$CONTAINER_NAME"; then
            success "3X-UI container is running!"
        else
            error "3X-UI container failed to start!"
            docker logs "$CONTAINER_NAME"
            exit 1
        fi
    else
        error "Failed to start 3X-UI container!"
        exit 1
    fi

    if [[ "$DN_EXIST" =~ ^[Yy]$ ]]; then
        echo ""
        echo -ne "${blu}Install Caddy for HTTPS reverse proxy? [Y/n]: ${noc}"
        read INSTALL_CADDY
        INSTALL_CADDY=${INSTALL_CADDY:-Y}

        if [[ "$INSTALL_CADDY" =~ ^[Yy]$ ]]; then
            caddy_install "$DOM_NAME"
        else
            warn "Skipping Caddy setup."
            info "Access 3X-UI at: http://$DOM_NAME:2053"
            info "Default credential: admin / admin"
        fi
    else
        PUB_IP=$(get_public_ip)
        warn "═══════════════════════════════════════════════════════════"
        warn "No domain configured - HTTPS not available"
        warn "═══════════════════════════════════════════════════════════"
        echo -e "${grn}Panel URL:${noc}     http://$PUB_IP:2053"
        echo -e "${grn}Default Login:${noc} admin / admin"
        warn "═══════════════════════════════════════════════════════════"
        warn "IMPORTANT: Change default credentials after first login!"
        warn "═══════════════════════════════════════════════════════════"
    fi

    echo ""

    success "═══════════════════════════════════════════════════════════"
    success "            Installation completed successfully"
    success "═══════════════════════════════════════════════════════════"
    echo ""
    info "Installation directory: $INSTALL_DIR"
    info "Docker compose file: $INSTALL_DIR/compose.yml"
    if [ -f "$INSTALL_DIR/Caddyfile" ]; then
        info "Caddyfile: $INSTALL_DIR/Caddyfile"
    fi

    echo ""

    info "Useful commands:"
    echo -e "   ${cyn}docker compose logs -f${noc}      # View logs"
    echo -e "   ${cyn}docker compose restart${noc}      # Restart container"
    echo -e "   ${cyn}docker compose down -v${noc}      # Stop container"
    echo -e "   ${cyn}docker compose up -d  ${noc}      # Start container"
    if command -v caddy &>/dev/null; then
        echo -e "   ${cyn}sudo systemctl status caddy${noc} # Check Caddy status"
    fi

    echo ""

    clear_state
    return 0
}

main "$@"
