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

readonly STATE_FILE="/tmp/.3xui_state"
readonly LOG_FILE="/tmp/.3xui_log_$$"
readonly INSTALL="$HOME/3x-ui_$$"
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
        return 0
    fi
    success "State loaded!"
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
    info "Validating port"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error "Invalid port number: $port (must be 1-65535)"
        return 1
    fi
    success "Port is valid!"
    return 0
}


