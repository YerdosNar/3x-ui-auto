#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# Logger Module - Centralized logging with file and console output
# ═══════════════════════════════════════════════════════════════════════════

# ANSI Colors
readonly NC="\033[0m"
readonly RED="\033[31m"
readonly GREEN="\033[32m"
readonly YELLOW="\033[33m"
readonly BLUE="\033[34m"
readonly CYAN="\033[36m"
readonly BOLD="\033[1m"

# Log file
readonly LOG_FILE="/tmp/.3xui_install_logs_$$.txt"

# Initialize log file
init_logging() {
    cat > "$LOG_FILE" <<EOF
═══════════════════════════════════════════════════════════════════════════
3X-UI Automated Installer - Installation Log
═══════════════════════════════════════════════════════════════════════════
Started: $(date '+%Y-%m-%d %H:%M:%S')
User: $USER
Hostname: $(hostname)
OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 2>/dev/null || echo "Unknown")
═══════════════════════════════════════════════════════════════════════════

EOF
    chmod 600 "$LOG_FILE"
}

# Logging functions that output to both console and file
log_info() {
    local msg="$1"
    echo -e "${BLUE}[INFO]${NC} $msg"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

log_success() {
    local msg="$1"
    echo -e "${GREEN}[✓]${NC} $msg"
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

log_warn() {
    local msg="$1"
    echo -e "${YELLOW}[!]${NC} $msg"
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

log_error() {
    local msg="$1"
    echo -e "${RED}[✗]${NC} $msg" >&2
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

log_banner() {
    local msg="$1"
    echo -e "${CYAN}${BOLD}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

# Execute command with output redirected to log file only
exec_silent() {
    local cmd="$1"
    echo "[EXEC] $(date '+%Y-%m-%d %H:%M:%S') - Running: $cmd" >> "$LOG_FILE"
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        echo "[EXEC] $(date '+%Y-%m-%d %H:%M:%S') - Success" >> "$LOG_FILE"
        return 0
    else
        local exit_code=$?
        echo "[EXEC] $(date '+%Y-%m-%d %H:%M:%S') - Failed with exit code: $exit_code" >> "$LOG_FILE"
        return $exit_code
    fi
}

# Initialize logging on module load
init_logging
