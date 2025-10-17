#!/usr/bin/env bash

# ProxBalance Upgrade Script - v1.x to v2.0
# Author: Pr0zak
# License: MIT
# https://github.com/Pr0zak/ProxBalance

set -euo pipefail

# Colors
RD='\033[0;31m'
YW='\033[1;33m'
GN='\033[0;32m'
BL='\033[0;34m'
CY='\033[0;36m'
BOLD='\033[1m'
CL='\033[0m'
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
INFO="${CY}◆${CL}"
WARN="${YW}⚠${CL}"

msg_info() { echo -e "${INFO} ${BOLD}${BL}${1}${CL}"; }
msg_ok() { echo -e "${CM} ${GN}${1}${CL}"; }
msg_error() { echo -e "${CROSS} ${BOLD}${RD}${1}${CL}"; }
msg_warn() { echo -e "${WARN} ${YW}${1}${CL}"; }

# Banner
echo ""
echo -e "${CY}╔════════════════════════════════════════════════════════════════╗${CL}"
echo -e "${CY}║${CL} ${BOLD}ProxBalance Upgrade to v2.0${CL}                                   ${CY}║${CL}"
echo -e "${CY}╚════════════════════════════════════════════════════════════════╝${CL}"
echo ""

# Get container ID
if [ -z "${1:-}" ]; then
    echo -ne "${CY}▶${CL} Enter ProxBalance container ID: "
    read CTID
else
    CTID=$1
fi

# Validate container exists
if ! pct status "$CTID" &>/dev/null; then
    msg_error "Container $CTID does not exist"
    exit 1
fi

# Check if container is running
CT_STATUS=$(pct status "$CTID" | awk '{print $2}')
if [ "$CT_STATUS" != "running" ]; then
    msg_error "Container $CTID is not running. Please start it first."
    exit 1
fi

msg_ok "Container $CTID found and running"

# Check if this is a ProxBalance installation
if ! pct exec "$CTID" -- test -d /opt/proxmox-balance-manager; then
    msg_error "This doesn't appear to be a ProxBalance installation"
    exit 1
fi

msg_ok "ProxBalance installation detected"

# Backup current config
msg_info "Creating backup of current configuration..."
if pct exec "$CTID" -- test -f /opt/proxmox-balance-manager/config.json; then
    pct exec "$CTID" -- cp /opt/proxmox-balance-manager/config.json /opt/proxmox-balance-manager/config.json.backup
    msg_ok "Configuration backed up to config.json.backup"
fi

# Stop services
msg_info "Stopping services..."
pct exec "$CTID" -- systemctl stop proxmox-balance.service || true
pct exec "$CTID" -- systemctl stop proxmox-collector.timer || true
pct exec "$CTID" -- systemctl stop proxmox-collector.service || true
msg_ok "Services stopped"

# Update repository
msg_info "Pulling latest code from GitHub..."
pct exec "$CTID" -- bash -c "cd /opt/proxmox-balance-manager && git fetch origin && git reset --hard origin/main"
msg_ok "Code updated to v2.0"

# Install new dependencies
msg_info "Installing updated Python dependencies..."
# Check if venv exists (v1.x used venv)
if pct exec "$CTID" -- test -d /opt/proxmox-balance-manager/venv; then
    pct exec "$CTID" -- bash -c "cd /opt/proxmox-balance-manager && source venv/bin/activate && pip install -q --upgrade -r requirements.txt" 2>/dev/null || true
    msg_ok "Dependencies updated (using venv)"
else
    # No venv, install system-wide with break-system-packages flag
    # Temporarily disable pipefail and error exit to handle pip's externally-managed warning
    set +e
    pct exec "$CTID" -- bash -c "cd /opt/proxmox-balance-manager && pip3 install --upgrade -r requirements.txt --break-system-packages 2>&1" >/dev/null 2>&1
    PIP_EXIT=$?
    set -e
    # pip may return error but packages install successfully, so we continue
    msg_ok "Dependencies updated (system-wide)"
fi

# Update systemd service files
msg_info "Updating systemd service files..."
pct exec "$CTID" -- cp /opt/proxmox-balance-manager/systemd/proxmox-balance.service /etc/systemd/system/
pct exec "$CTID" -- cp /opt/proxmox-balance-manager/systemd/proxmox-collector.service /etc/systemd/system/
pct exec "$CTID" -- cp /opt/proxmox-balance-manager/systemd/proxmox-collector.timer /etc/systemd/system/
pct exec "$CTID" -- systemctl daemon-reload
msg_ok "Systemd services updated"

# Copy web UI to nginx
msg_info "Updating web interface..."
pct exec "$CTID" -- cp /opt/proxmox-balance-manager/index.html /var/www/html/
msg_ok "Web interface updated"

# Run post-update script if it exists
if pct exec "$CTID" -- test -f /opt/proxmox-balance-manager/post_update.sh; then
    msg_info "Running post-update migration script..."
    pct exec "$CTID" -- bash /opt/proxmox-balance-manager/post_update.sh
    msg_ok "Post-update migration completed"
fi

# Check if config needs updating
msg_info "Checking configuration..."
HAS_PROXMOX_HOST=$(pct exec "$CTID" -- jq -e '.proxmox_host' /opt/proxmox-balance-manager/config.json >/dev/null 2>&1 && echo "yes" || echo "no")
HAS_API_TOKEN=$(pct exec "$CTID" -- jq -e '.proxmox_api_token_id' /opt/proxmox-balance-manager/config.json >/dev/null 2>&1 && echo "yes" || echo "no")

if [ "$HAS_PROXMOX_HOST" = "no" ]; then
    msg_warn "Configuration needs updating for v2.0"
    echo ""
    echo -e "  ${INFO} v2.0 requires Proxmox API token authentication"
    echo -e "  ${INFO} Please configure your Proxmox host and API token"
    echo ""
fi

# Start services
msg_info "Starting services..."
pct exec "$CTID" -- systemctl start proxmox-balance.service
pct exec "$CTID" -- systemctl start proxmox-collector.timer
msg_ok "Services started"

# Get container IP
CONTAINER_IP=$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}')

# Summary
echo ""
echo -e "${CY}╔════════════════════════════════════════════════════════════════╗${CL}"
echo -e "${CY}║${CL} ${BOLD}${GN}Upgrade Complete!${CL}                                              ${CY}║${CL}"
echo -e "${CY}╚════════════════════════════════════════════════════════════════╝${CL}"
echo ""
msg_ok "ProxBalance has been upgraded to v2.0!"
echo ""
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${BOLD}What's New in v2.0:${CL}"
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo ""
echo -e "  ${CM} ${BOLD}AI-Powered Recommendations${CL}"
echo -e "      - Support for OpenAI, Anthropic Claude, and Ollama"
echo -e "      - Configurable analysis time periods (1h, 6h, 24h, 7d)"
echo -e "      - Smart filtering to prevent hallucinated nodes"
echo ""
echo -e "  ${CM} ${BOLD}Enhanced Security${CL}"
echo -e "      - API token authentication (no more password storage)"
echo -e "      - Web UI authentication removed for better security"
echo ""
echo -e "  ${CM} ${BOLD}Improved Web Interface${CL}"
echo -e "      - Settings panel for AI configuration"
echo -e "      - Time period selector for analysis"
echo -e "      - Enhanced status display"
echo ""
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${BOLD}Next Steps:${CL}"
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo ""

if [ "$HAS_API_TOKEN" = "no" ]; then
    echo -e "  ${WARN} ${BOLD}IMPORTANT: Configure Proxmox API Access${CL}"
    echo ""
    echo -e "  1. Create Proxmox API token:"
    echo -e "     ${BL}pct exec $CTID -- bash /opt/proxmox-balance-manager/create_api_token.sh${CL}"
    echo ""
    echo -e "  2. Or manually edit config.json to add:"
    echo -e "     ${DIM}\"proxmox_host\": \"your-proxmox-ip\",${CL}"
    echo -e "     ${DIM}\"proxmox_api_token_id\": \"root@pam!proxbalance\",${CL}"
    echo -e "     ${DIM}\"proxmox_api_token_secret\": \"your-token-secret\"${CL}"
    echo ""
fi

echo -e "  ${INFO} ${BOLD}Enable AI Features (Optional):${CL}"
echo -e "      1. Access web interface: ${CY}http://${CONTAINER_IP}${CL}"
echo -e "      2. Click ⚙️ Settings icon (top-right)"
echo -e "      3. Enable AI Recommendations"
echo -e "      4. Configure your AI provider"
echo ""
echo -e "  ${INFO} ${BOLD}Documentation:${CL}"
echo -e "      - AI Features Guide: ${CY}https://github.com/Pr0zak/ProxBalance/blob/main/docs/AI_FEATURES.md${CL}"
echo -e "      - Full Documentation: ${CY}https://github.com/Pr0zak/ProxBalance/blob/main/docs/README.md${CL}"
echo ""
echo -e "  ${INFO} ${BOLD}Check Status:${CL}"
echo -e "      ${BL}bash /opt/proxmox-balance-manager/check-status.sh $CTID${CL}"
echo ""
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo ""
