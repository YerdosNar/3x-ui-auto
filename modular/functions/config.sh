#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# Configuration Module - State management and configuration
# ═══════════════════════════════════════════════════════════════════════════

readonly STATE_FILE="/tmp/.3xui_install_state"
readonly INSTALL_DIR="$HOME/3x-uiPANEL_$$"

# Save installation state
save_state() {
    local stage="$1"
    cat > "$STATE_FILE" <<EOF
STAGE=$stage
DOM_NAME=${DOM_NAME:-}
ADMIN_NAME=${ADMIN_NAME:-}
PASSWORD=${PASSWORD:-}
ROUTE=${ROUTE:-}
PORT=${PORT:-}
BE_PORT=${BE_PORT:-}
EOF
    chmod 600 "$STATE_FILE"
    echo "[STATE] $(date '+%Y-%m-%d %H:%M:%S') - Saved state: $stage" >> "$LOG_FILE"
}

# Load installation state
load_state() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        echo "[STATE] $(date '+%Y-%m-%d %H:%M:%S') - Loaded state: $STAGE" >> "$LOG_FILE"
        return 0
    fi
    return 1
}

# Clear installation state
clear_state() {
    if [ -f "$STATE_FILE" ]; then
        rm -f "$STATE_FILE"
        echo "[STATE] $(date '+%Y-%m-%d %H:%M:%S') - Cleared state" >> "$LOG_FILE"
    fi
}
