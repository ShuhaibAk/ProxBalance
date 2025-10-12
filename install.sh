#!/usr/bin/env bash
# ProxBalance Quick Installer
# Downloads and runs the full installer locally
cd /tmp
wget -q https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install-full.sh
chmod +x install-full.sh
exec bash install-full.sh
