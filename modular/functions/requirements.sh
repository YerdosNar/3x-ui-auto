#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# Requirements Check Module - System prerequisites validation
# ═══════════════════════════════════════════════════════════════════════════

check_requirements() {
    log_info "Checking system requirements..."

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_error "Do not run this script as root. Run as a regular user with sudo privileges."
        exit 1
    fi

    # Check sudo access
    if ! sudo -v >> "$LOG_FILE" 2>&1; then
        log_error "Sudo authentication failed. You need sudo privileges."
        exit 1
    fi

    # Check OS
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot determine OS. This script is designed for Ubuntu/Debian."
        exit 1
    fi

    source /etc/os-release
    echo "[SYSTEM] OS: $PRETTY_NAME" >> "$LOG_FILE"

    if [[ ! "$ID" =~ ^(ubuntu|debian)$ ]]; then
        log_warn "This script is tested on Ubuntu/Debian. Your OS: $ID"
        read -p "Continue anyway? [y/N]: " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    # Check available disk space (minimum 2GB)
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    echo "[SYSTEM] Available disk space: ${available_space}GB" >> "$LOG_FILE"

    if [ "$available_space" -lt 2 ]; then
        log_error "Insufficient disk space. At least 2GB required. Available: ${available_space}GB"
        exit 1
    fi

    # Check required commands
    local missing_cmds=()
    for cmd in curl gpg apt-get systemctl; do
        if ! command -v $cmd &> /dev/null; then
            missing_cmds+=("$cmd")
            echo "[SYSTEM] Missing command: $cmd" >> "$LOG_FILE"
        fi
    done

    if [ ${#missing_cmds[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing_cmds[*]}"
        exit 1
    fi

    log_success "System requirements check passed!"
}
