#!/usr/bin/env bash

# ProxBalance Bootstrap Installer
# Downloads full installer and runs it locally (avoids pipe issues)

set -e

INSTALL_URL="https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install-full.sh"
INSTALL_SCRIPT="/tmp/proxbalance-install-$$.sh"

# Check prerequisites
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root"
  exit 1
fi

if ! command -v pct &> /dev/null; then
  echo "Error: This script must be run on a Proxmox VE host"
  exit 1
fi

clear
cat <<"EOF"
╔════════════════════════════════════════════════════════════════╗
║  ProxBalance Bootstrap Installer                              ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo ""
echo "Downloading installer from GitHub..."
echo ""

# Download the full installer
if command -v wget &> /dev/null; then
  if ! wget -q --show-progress -O "$INSTALL_SCRIPT" "$INSTALL_URL" 2>&1; then
    echo "Error: Failed to download installer"
    exit 1
  fi
elif command -v curl &> /dev/null; then
  if ! curl -fsSL -o "$INSTALL_SCRIPT" "$INSTALL_URL" 2>&1; then
    echo "Error: Failed to download installer"
    exit 1
  fi
else
  echo "Error: Neither wget nor curl found"
  exit 1
fi

# Verify download
if [ ! -f "$INSTALL_SCRIPT" ] || [ ! -s "$INSTALL_SCRIPT" ]; then
  echo "Error: Downloaded installer is empty or missing"
  exit 1
fi

# Make executable
chmod +x "$INSTALL_SCRIPT"

echo ""
echo "✓ Installer downloaded successfully"
echo "✓ Starting ProxBalance installation..."
echo ""

# Run the installer
exec bash "$INSTALL_SCRIPT"
