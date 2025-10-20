#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# Validators Module - Input validation functions
# ═══════════════════════════════════════════════════════════════════════════

# Validate domain name format
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain name format: $domain"
        return 1
    fi
    return 0
}

# Validate port number
validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Invalid port number: $port (must be 1-65535)"
        return 1
    fi
    return 0
}

# Check if port is available
check_port_available() {
    local port="$1"
    if sudo lsof -Pi :$port -sTCP:LISTEN -t >> "$LOG_FILE" 2>&1; then
        log_error "Port $port is already in use"
        return 1
    fi
    return 0
}
