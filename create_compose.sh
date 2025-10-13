#!/usr/bin/env bash

DOM_NAME=""
if [ $# -eq 1 ]; then
    DOM_NAME="hostname: $1"
else
    DOM_NAME="# hostname: example.com"
fi

cat > compose.yml<<EOF
services:
  3xui:
    image: ghcr.io/mhsanaei/3x-ui:latest
    container_name: 3xui_app
    $DOM_NAME
    volumes:
      - $PWD/db/:/etc/x-ui/
      - $PWD/cert/:/root/cert/
    environment:
      XRAY_VMESS_AEAD_FORCED: "false"
      XUI_ENABLE_FAIL2BAN: "true"
    tty: true
    network_mode: host
    restart: unless-stopped
EOF
