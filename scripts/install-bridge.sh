#!/bin/bash
set -euo pipefail

echo "=========================================================="
echo "  ServerDeck Native Host Bridge Installer (like Beszel)   "
echo "=========================================================="

BINARY_SRC="${1:-/mnt/DATA/serverdeck/bridge/target/release/serverdeck-bridge}"
SERVICE_SRC="${2:-/mnt/DATA/serverdeck/scripts/serverdeck-bridge.service}"

if [ ! -f "$BINARY_SRC" ]; then
    echo "Error: Binary not found at $BINARY_SRC"
    exit 1
fi

echo "==> Stopping any existing bridge service..."
systemctl stop serverdeck-bridge.service 2>/dev/null || true

echo "==> Installing binary to /usr/local/bin/serverdeck-bridge..."
install -m 755 "$BINARY_SRC" /usr/local/bin/serverdeck-bridge

echo "==> Installing systemd service unit..."
install -m 644 "$SERVICE_SRC" /etc/systemd/system/serverdeck-bridge.service

echo "==> Reloading systemd and enabling service..."
systemctl daemon-reload
systemctl enable --now serverdeck-bridge.service

echo "==> Checking service status..."
systemctl status serverdeck-bridge.service --no-pager

echo ""
echo "✓ ServerDeck Host Bridge successfully installed and active!"
echo "Socket available at /run/serverdeck/bridge.sock"
