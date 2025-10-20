#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# 3X-UI Panel Auto-Configuration Module
# ═══════════════════════════════════════════════════════════════════════════

configure_3xui_panel() {
    local port="$1"
    local route="$2"
    local username="$3"
    local password="$4"

    local temp_output="/tmp/3xui_output_$$.txt"
    local cookie_file="/tmp/3xui_cookies_$$.txt"
    local base_url="http://localhost:2053"

    trap 'rm -rf "$temp_output" "$cookie_file"' RETURN

    echo "[PANEL] Starting auto-configuration" >> "$LOG_FILE"
    echo "[PANEL] Port: $port, Route: /$route, Username: $username" >> "$LOG_FILE"

    # Nested functions for readability
    restart_function() {
        log_info "Restarting 3X-UI panel..."
        curl -s --fail -b "$cookie_file" -X POST \
            "$base_url/panel/setting/restartPanel" \
            > "$temp_output" 2>> "$LOG_FILE"

        if grep -Eq '"success":\s*true|successfully' "$temp_output"; then
            log_success "Restarted successfully!"
            echo "[PANEL] Restart successful" >> "$LOG_FILE"
        else
            log_warn "Could not restart the panel, further commands may fail"
            echo "[PANEL] Restart failed" >> "$LOG_FILE"
            cat "$temp_output" >> "$LOG_FILE"
        fi
    }

    login_function() {
        local login_username=$1
        local login_password=$2

        echo "[PANEL] Attempting login with username: $login_username" >> "$LOG_FILE"

        curl -s --fail -c "$cookie_file" -X POST \
            "$base_url/login" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "username=$login_username&password=$login_password" \
            > "$temp_output" 2>> "$LOG_FILE"

        if ! grep -Eq '"success":\s*true|successfully' "$temp_output"; then
            log_warn "Failed to login to 3X-UI panel"
            echo "[PANEL] Login failed" >> "$LOG_FILE"
            cat "$temp_output" >> "$LOG_FILE"
            rm -f "$cookie_file"
            return 1
        else
            log_success "Logged in successfully ($login_username)!"
            echo "[PANEL] Login successful" >> "$LOG_FILE"
            return 0
        fi
    }

    log_info "Configuring 3X-UI panel settings automatically..."

    # Wait for 3X-UI to be fully ready
    local max_attempts=30
    local attempt=0

    log_info "Waiting for 3X-UI panel to be ready..."
    while [ $attempt -lt $max_attempts ]; do
        log_info "Attempt: $((attempt + 1))/$max_attempts..."
        if curl -s --fail "$base_url" >> "$LOG_FILE" 2>&1; then
            log_success "3X-UI panel is responding!"
            echo "[PANEL] Panel is ready" >> "$LOG_FILE"
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    if [ $attempt -eq $max_attempts ]; then
        log_warn "Could not verify 3X-UI is ready. Configuration may fail."
        echo "[PANEL] Timeout waiting for panel" >> "$LOG_FILE"
        return 1
    fi

    sleep 2  # Extra wait for full initialization

    # Login and get session cookie
    log_info "Logging in to 3X-UI panel..."
    if ! login_function "admin" "admin"; then
        log_error "Initial login with (admin/admin) failed. Aborting..."
        return 1
    fi

    # Update admin credentials
    log_info "Updating admin credentials..."
    curl -s --fail -b "$cookie_file" -X POST \
        "$base_url/panel/setting/updateUser" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "oldUsername=admin&oldPassword=admin&newUsername=$username&newPassword=$password" \
        > "$temp_output" 2>> "$LOG_FILE"

    if grep -Eq '"success":\s*true|successfully' "$temp_output"; then
        log_success "Admin credentials updated!"
        echo "[PANEL] Credentials updated successfully" >> "$LOG_FILE"
    else
        log_warn "Could not update credentials automatically"
        echo "[PANEL] Credential update failed" >> "$LOG_FILE"
        cat "$temp_output" >> "$LOG_FILE"
    fi

    restart_function

    # Re-login with new credentials
    if ! login_function "$username" "$password"; then
        log_error "Login with updated credentials failed. Aborting..."
        return 1
    fi

    # Update panel settings
    log_info "Updating panel port to $port and path to /$route..."
    curl -s --fail -b "$cookie_file" -X POST \
        "$base_url/panel/setting/update" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "webPort=$port&subPort=2096&webBasePath=/$route&webCertFile=&webKeyFile=" \
        > "$temp_output" 2>> "$LOG_FILE"

    if grep -Eq 'The parameters have been changed' "$temp_output"; then
        log_success "Panel settings updated!"
        echo "[PANEL] Settings updated successfully" >> "$LOG_FILE"
    else
        log_warn "Could not update panel settings automatically"
        echo "[PANEL] Settings update failed" >> "$LOG_FILE"
        cat "$temp_output" >> "$LOG_FILE"
        rm -f "$cookie_file"
        return 1
    fi

    restart_function

    log_info "Waiting for panel to restart..."

    local verify_attempts=0
    while [ $verify_attempts -lt 10 ]; do
        log_info "Attempt: $((verify_attempts + 1))"
        if curl -s --fail "http://localhost:$port/$route" >> "$LOG_FILE" 2>&1; then
            log_success "Panel is accessible on new port $port!"
            echo "[PANEL] Panel accessible on new configuration" >> "$LOG_FILE"
            return 0
        fi
        verify_attempts=$((verify_attempts + 1))
        sleep 1
    done

    log_warn "Could not verify panel on new port, but settings were applied"
    echo "[PANEL] Could not verify new configuration" >> "$LOG_FILE"
    return 0
}
