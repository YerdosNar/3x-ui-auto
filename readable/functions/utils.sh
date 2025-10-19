#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# Utility Functions Module - Helper functions
# ═══════════════════════════════════════════════════════════════════════════

# Generate strong random password
generate_strong_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 16
}

# Get public IP address
get_public_ip() {
    local ip
    log_info "Retrieving public IP address..." >> "$LOG_FILE"
    ip=$(curl -s --max-time 5 ifconfig.me 2>> "$LOG_FILE" || curl -s --max-time 5 icanhazip.com 2>> "$LOG_FILE" || echo "")
    if [ -z "$ip" ]; then
        log_error "Failed to retrieve public IP address"
        return 1
    fi
    echo "[INFO] Public IP: $ip" >> "$LOG_FILE"
    echo "$ip"
}
