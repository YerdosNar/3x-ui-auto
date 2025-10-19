#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# Docker Compose Configuration Module
# ═══════════════════════════════════════════════════════════════════════════

create_compose() {
    local dom_name="${1:-}"
    local c_dom_name

    log_info "Creating Docker Compose configuration..."

    if [ -n "$dom_name" ]; then
        c_dom_name="    hostname: $dom_name"
        echo "[COMPOSE] Setting hostname: $dom_name" >> "$LOG_FILE"
    else
        c_dom_name="    # hostname: example.com"
        echo "[COMPOSE] No hostname set" >> "$LOG_FILE"
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

    log_success "Docker compose file created at $INSTALL_DIR/compose.yml"
    echo "[COMPOSE] File content saved" >> "$LOG_FILE"
    cat "$INSTALL_DIR/compose.yml" >> "$LOG_FILE"
}
