#!/usr/bin/env bash

# ProxBalance Upgrade Script - v1.x to v2.0
# Author: Pr0zak
# License: MIT
# https://github.com/Pr0zak/ProxBalance

# Colors (define first for trap)
RD='\033[0;31m'
YW='\033[1;33m'
GN='\033[0;32m'
BL='\033[0;34m'
CY='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
CL='\033[0m'
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

# Enable error handling with better error messages
set -euo pipefail
trap 'echo -e "\n${RD}✗${CL} Script failed at line $LINENO. Check the error output above for details." >&2; exit 1' ERR
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

# Clean up any orphaned ACL entries FIRST to prevent warnings during pct commands
# This must happen before ANY pct status or pct exec commands
# Check if token or ACL references exist in user.cfg (causes "ignore invalid acl token" warnings)
if grep -q "proxbalance@pam!proxbalance" /etc/pve/user.cfg 2>/dev/null; then
    msg_info "Cleaning up orphaned ProxBalance ACL entries"
    # Remove ACL entries (even if they don't show in pveum acl list)
    pveum acl delete / --tokens proxbalance@pam!proxbalance 2>/dev/null || true
    pveum acl delete / --users proxbalance@pam 2>/dev/null || true
    # Also clean up old root@pam token ACL if it exists
    pveum acl delete / --tokens root@pam!proxbalance 2>/dev/null || true
    # Delete the user entirely if it exists (will be recreated later if needed)
    pveum user delete proxbalance@pam 2>/dev/null || true
    msg_ok "Orphaned entries cleaned - will recreate during upgrade"
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
if pct exec "$CTID" -- test -f /opt/proxmox-balance-manager/config.json 2>/dev/null; then
    pct exec "$CTID" -- cp /opt/proxmox-balance-manager/config.json /tmp/proxbalance_config_backup.json 2>/dev/null || true
    msg_ok "Configuration backed up to /tmp"
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

# Restore config from backup
if pct exec "$CTID" -- test -f /tmp/proxbalance_config_backup.json 2>/dev/null; then
    pct exec "$CTID" -- cp /tmp/proxbalance_config_backup.json /opt/proxmox-balance-manager/config.json 2>/dev/null || true
    msg_ok "Configuration restored from backup"
fi

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
pct exec "$CTID" -- cp /opt/proxmox-balance-manager/systemd/proxmox-balance.service /etc/systemd/system/ 2>/dev/null || true
pct exec "$CTID" -- cp /opt/proxmox-balance-manager/systemd/proxmox-collector.service /etc/systemd/system/ 2>/dev/null || true
pct exec "$CTID" -- cp /opt/proxmox-balance-manager/systemd/proxmox-collector.timer /etc/systemd/system/ 2>/dev/null || true
pct exec "$CTID" -- systemctl daemon-reload 2>/dev/null || true
msg_ok "Systemd services updated"

# Copy web UI to nginx
msg_info "Updating web interface..."
pct exec "$CTID" -- cp /opt/proxmox-balance-manager/index.html /var/www/html/ 2>/dev/null || true
msg_ok "Web interface updated"

# Run post-update script if it exists
if pct exec "$CTID" -- test -f /opt/proxmox-balance-manager/post_update.sh 2>/dev/null; then
    msg_info "Running post-update migration script..."
    pct exec "$CTID" -- bash /opt/proxmox-balance-manager/post_update.sh
    msg_ok "Post-update migration completed"
fi

# Check if config needs updating
msg_info "Checking configuration..."
HAS_PROXMOX_HOST=$(pct exec "$CTID" -- jq -e '.proxmox_host' /opt/proxmox-balance-manager/config.json >/dev/null 2>&1 && echo "yes" || echo "no")
HAS_API_TOKEN_IN_CONFIG=$(pct exec "$CTID" -- jq -e '.proxmox_api_token_id' /opt/proxmox-balance-manager/config.json >/dev/null 2>&1 && echo "yes" || echo "no")

# Check if token actually exists in Proxmox (not just in config.json)
TOKEN_EXISTS_IN_PROXMOX="no"
if pvesh get /access/users/proxbalance@pam/token/proxbalance &>/dev/null; then
    TOKEN_EXISTS_IN_PROXMOX="yes"
fi

# Configure API token if needed (token missing in config OR token missing in Proxmox)
if [ "$HAS_API_TOKEN_IN_CONFIG" = "no" ] || [ "$TOKEN_EXISTS_IN_PROXMOX" = "no" ]; then
    echo ""
    if [ "$HAS_API_TOKEN_IN_CONFIG" = "yes" ] && [ "$TOKEN_EXISTS_IN_PROXMOX" = "no" ]; then
        msg_warn "API token in config.json no longer exists in Proxmox"
        echo -e "  ${DIM}The token was likely deleted or orphaned ACL entries were cleaned up${CL}"
    else
        msg_warn "v2.0 requires Proxmox API token authentication"
    fi
    echo ""
    echo -e "  ${BL}Would you like to automatically configure API access now?${CL}"
    echo -e "  ${DIM}(This will create a new Proxmox API token and update config.json)${CL}"
    echo ""
    echo -e "  ${BL}1)${CL} ${GN}Yes${CL} ${DIM}- Configure automatically (recommended)${CL}"
    echo -e "  ${BL}2)${CL} ${YW}No${CL} ${DIM}- Configure manually later${CL}"
    echo ""
    read -p "Select option [1-2] (default: 1): " config_choice
    config_choice=${config_choice:-1}

    if [ "$config_choice" = "1" ]; then
        # Get Proxmox host IP
        PROXMOX_HOST=$(hostname -I | awk '{print $1}')
        echo ""
        echo -e "${CY}▶${CL} Proxmox host IP (default: ${PROXMOX_HOST}): "
        read custom_host
        PROXMOX_HOST=${custom_host:-$PROXMOX_HOST}

        # Clean up old root@pam token if it still exists (from early v2.0)
        if pveum user token list root@pam 2>/dev/null | grep -q "proxbalance"; then
            msg_info "Removing old root@pam!proxbalance token"
            pvesh delete /access/users/root@pam/token/proxbalance 2>/dev/null || true
            msg_ok "Old token removed"
        fi

        # Create dedicated user if it doesn't exist
        TOKEN_USER="proxbalance@pam"
        TOKEN_NAME="proxbalance"

        # Ensure user exists (create if needed)
        if ! pveum user list 2>/dev/null | grep -q "proxbalance@pam"; then
            msg_info "Creating dedicated 'proxbalance' user"
            pveum user add proxbalance@pam --comment "ProxBalance service account" --enable 1 >/dev/null 2>&1 || true
        fi

        # Verify user exists
        if pveum user list 2>/dev/null | grep -q "proxbalance@pam"; then
            msg_ok "User 'proxbalance@pam' ready"
        else
            msg_error "Failed to create or find user 'proxbalance@pam'"
            exit 1
        fi

        API_TOKEN_ID="${TOKEN_USER}!${TOKEN_NAME}"

        # Permission selection
        echo ""
        msg_info "Select API Token Permissions"
        echo ""
        echo -e "  ${BL}1)${CL} ${GN}Minimal${CL} ${DIM}(Read-only - Monitoring only)${CL}"
        echo -e "     ${DIM}✓ View cluster resources and statistics${CL}"
        echo -e "     ${DIM}✗ Cannot perform migrations${CL}"
        echo ""
        echo -e "  ${BL}2)${CL} ${YW}Full${CL} ${DIM}(Read + Migrate - Recommended)${CL}"
        echo -e "     ${DIM}✓ View cluster resources and statistics${CL}"
        echo -e "     ${DIM}✓ Perform automated live migrations${CL}"
        echo ""
        read -p "Select permission level [1-2] (default: 2): " perm_choice
        perm_choice=${perm_choice:-2}

        case $perm_choice in
            1)
                TOKEN_COMMENT="ProxBalance monitoring (read-only)"
                TOKEN_PERMS="minimal"
                msg_info "Using minimal permissions (read-only)"
                ;;
            2)
                TOKEN_COMMENT="ProxBalance with migration support"
                TOKEN_PERMS="full"
                msg_info "Using full permissions (with migration)"
                ;;
            *)
                TOKEN_COMMENT="ProxBalance monitoring (read-only)"
                TOKEN_PERMS="minimal"
                msg_warn "Invalid selection, using minimal permissions"
                ;;
        esac

        # Initialize token creation flag
        HAS_API_TOKEN="create"

        # Check if token already exists
        if pvesh get /access/users/${TOKEN_USER}/token/${TOKEN_NAME} &>/dev/null; then
            msg_warn "API token 'proxbalance' already exists"
            echo ""
            echo -e "  ${BL}1)${CL} Delete and create new token"
            echo -e "  ${BL}2)${CL} Skip token creation (configure manually)"
            echo ""
            read -p "Select option [1-2] (default: 1): " token_choice
            token_choice=${token_choice:-1}

            if [ "$token_choice" = "1" ]; then
                msg_info "Deleting existing token..."
                pvesh delete /access/users/${TOKEN_USER}/token/${TOKEN_NAME} 2>/dev/null || true
            else
                msg_info "Skipping token creation"
                HAS_API_TOKEN="skip"
            fi
        fi

        # Create new token (unless user chose to skip)
        if [ "$HAS_API_TOKEN" = "create" ]; then
            msg_info "Creating new API token..."
            token_result=$(pvesh create /access/users/${TOKEN_USER}/token/${TOKEN_NAME} \
                --comment "$TOKEN_COMMENT" \
                --privsep 0 2>&1)

            # Extract token secret (try multiple methods)
            API_TOKEN_SECRET=""
            API_TOKEN_SECRET=$(echo "$token_result" | grep -E '^\|\s*value\s*\|' | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' 2>/dev/null | head -n1)
            if [ -z "$API_TOKEN_SECRET" ]; then
                API_TOKEN_SECRET=$(echo "$token_result" | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' 2>/dev/null | head -n1)
            fi

            if [ -n "$API_TOKEN_SECRET" ]; then
                msg_ok "API token created successfully"

                # Configure permissions
                msg_info "Configuring API permissions..."
                if [ "$TOKEN_PERMS" = "minimal" ]; then
                    # IMPORTANT: Both USER and TOKEN need permissions (even with privsep=0)
                    pvesh set /access/acl --path / --roles PVEAuditor --users "${TOKEN_USER}" --propagate 1 2>/dev/null || true
                    pvesh set /access/acl --path / --roles PVEAuditor --tokens "${API_TOKEN_ID}" --propagate 1 2>/dev/null || true
                    msg_ok "Minimal permissions applied"
                else
                    # IMPORTANT: Both USER and TOKEN need permissions (even with privsep=0)
                    # IMPORTANT: Both PVEAuditor and PVEVMAdmin roles are required
                    #            PVEVMAdmin alone doesn't include all Sys.Audit permissions
                    pvesh set /access/acl --path / --roles PVEAuditor --users "${TOKEN_USER}" --propagate 1 2>/dev/null || true
                    pvesh set /access/acl --path / --roles PVEVMAdmin --users "${TOKEN_USER}" --propagate 1 2>/dev/null || true
                    pvesh set /access/acl --path / --roles PVEAuditor --tokens "${API_TOKEN_ID}" --propagate 1 2>/dev/null || true
                    pvesh set /access/acl --path / --roles PVEVMAdmin --tokens "${API_TOKEN_ID}" --propagate 1 2>/dev/null || true
                    msg_ok "Full permissions applied (includes VM.Migrate)"
                fi

                # Update config.json
                msg_info "Updating configuration..."
                pct exec "$CTID" -- jq \
                    --arg host "$PROXMOX_HOST" \
                    --arg token_id "$API_TOKEN_ID" \
                    --arg token_secret "$API_TOKEN_SECRET" \
                    '.proxmox_host = $host | .proxmox_port = 8006 | .proxmox_api_token_id = $token_id | .proxmox_api_token_secret = $token_secret' \
                    /opt/proxmox-balance-manager/config.json > /tmp/config.json.tmp
                pct exec "$CTID" -- mv /tmp/config.json.tmp /opt/proxmox-balance-manager/config.json
                msg_ok "Configuration updated"
                HAS_API_TOKEN="yes"
            else
                msg_error "Failed to extract API token from response"
                HAS_API_TOKEN="no"
            fi
        fi
    else
        msg_info "Skipping automatic configuration"
    fi
fi

# Check and fix existing API token permissions if needed
msg_info "Checking API token permissions..."

# Ensure user exists (create if needed)
if ! pveum user list 2>/dev/null | grep -q "proxbalance@pam"; then
    msg_warn "User 'proxbalance@pam' does not exist - creating it..."
    pveum user add proxbalance@pam --comment "ProxBalance service account" --enable 1 >/dev/null 2>&1 || true
fi

# Verify user exists
if pveum user list 2>/dev/null | grep -q "proxbalance@pam"; then
    msg_ok "User 'proxbalance@pam' ready"
else
    msg_error "Failed to create or find user 'proxbalance@pam'"
    exit 1
fi

# Check if token exists
if ! pvesh get /access/users/proxbalance@pam/token/proxbalance &>/dev/null; then
    msg_warn "API token 'proxbalance@pam!proxbalance' does not exist"
    echo ""
    echo -e "  ${BL}Would you like to create a new API token now?${CL}"
    echo ""
    echo -e "  ${BL}1)${CL} ${GN}Yes${CL} ${DIM}- Create new token (recommended)${CL}"
    echo -e "  ${BL}2)${CL} ${YW}No${CL} ${DIM}- Configure manually later${CL}"
    echo ""
    read -p "Select option [1-2] (default: 1): " create_token_choice
    create_token_choice=${create_token_choice:-1}

    if [ "$create_token_choice" = "1" ]; then
        # Ask for permission level
        echo ""
        echo -e "  ${BL}Select permission level:${CL}"
        echo -e "  ${BL}1)${CL} Read-only (PVEAuditor)"
        echo -e "  ${BL}2)${CL} Full permissions (PVEAuditor + PVEVMAdmin)"
        echo ""
        read -p "Select permission level [1-2] (default: 2): " new_token_perm_choice
        new_token_perm_choice=${new_token_perm_choice:-2}

        # Generate new token
        msg_info "Creating new API token..."
        TOKEN_RESPONSE=$(pveum user token add proxbalance@pam proxbalance --privsep 0 --output-format json 2>/dev/null)

        if [ -n "$TOKEN_RESPONSE" ]; then
            API_TOKEN_SECRET=$(echo "$TOKEN_RESPONSE" | jq -r '.value' 2>/dev/null)

            if [ -n "$API_TOKEN_SECRET" ] && [ "$API_TOKEN_SECRET" != "null" ]; then
                msg_ok "API token created"

                # Apply permissions
                if [ "$new_token_perm_choice" = "1" ]; then
                    pvesh set /access/acl --path / --roles PVEAuditor --users "proxbalance@pam" --propagate 1 2>/dev/null || true
                    pvesh set /access/acl --path / --roles PVEAuditor --tokens "proxbalance@pam!proxbalance" --propagate 1 2>/dev/null || true
                    msg_ok "Read-only permissions applied"
                else
                    pvesh set /access/acl --path / --roles PVEAuditor --users "proxbalance@pam" --propagate 1 2>/dev/null || true
                    pvesh set /access/acl --path / --roles PVEVMAdmin --users "proxbalance@pam" --propagate 1 2>/dev/null || true
                    pvesh set /access/acl --path / --roles PVEAuditor --tokens "proxbalance@pam!proxbalance" --propagate 1 2>/dev/null || true
                    pvesh set /access/acl --path / --roles PVEVMAdmin --tokens "proxbalance@pam!proxbalance" --propagate 1 2>/dev/null || true
                    msg_ok "Full permissions applied"
                fi

                # Get Proxmox host IP
                PROXMOX_HOST=$(hostname -I | awk '{print $1}')

                # Update config.json
                msg_info "Updating configuration with new token..."
                pct exec "$CTID" -- jq \
                    --arg host "$PROXMOX_HOST" \
                    --arg token_id "proxbalance@pam!proxbalance" \
                    --arg token_secret "$API_TOKEN_SECRET" \
                    '.proxmox_host = $host | .proxmox_port = 8006 | .proxmox_api_token_id = $token_id | .proxmox_api_token_secret = $token_secret' \
                    /opt/proxmox-balance-manager/config.json > /tmp/config.json.tmp
                pct exec "$CTID" -- mv /tmp/config.json.tmp /opt/proxmox-balance-manager/config.json
                msg_ok "Configuration updated"
            else
                msg_error "Failed to extract API token from response"
            fi
        else
            msg_error "Failed to create API token"
        fi
    else
        msg_info "Skipping token creation"
        echo ""
        echo -e "  ${YW}Note: ProxBalance requires a valid API token to function${CL}"
        echo ""
    fi
else
    # Check existing permissions
    CURRENT_PERMS=$(pveum acl list | grep "proxbalance@pam!proxbalance" | awk '{print $2}' | sort -u | tr '\n' ' ')
    if [[ "$CURRENT_PERMS" == *"PVEVMAdmin"* ]] && [[ "$CURRENT_PERMS" != *"PVEAuditor"* ]]; then
        msg_warn "Detected PVEVMAdmin without PVEAuditor - fixing permissions..."
        pvesh set /access/acl --path / --roles PVEAuditor --users "proxbalance@pam" --propagate 1 2>/dev/null || true
        pvesh set /access/acl --path / --roles PVEAuditor --tokens "proxbalance@pam!proxbalance" --propagate 1 2>/dev/null || true
        msg_ok "Permissions fixed - added PVEAuditor role"
    elif [[ "$CURRENT_PERMS" == *"PVEAuditor"* ]] && [[ "$CURRENT_PERMS" == *"PVEVMAdmin"* ]]; then
        msg_ok "Permissions are correct (PVEAuditor + PVEVMAdmin)"
    elif [[ "$CURRENT_PERMS" == *"PVEAuditor"* ]]; then
        msg_ok "Permissions are correct (PVEAuditor - read-only)"
    else
        msg_warn "No permissions found - setting default permissions..."
        echo ""
        echo -e "  ${BL}1)${CL} Read-only (PVEAuditor)"
        echo -e "  ${BL}2)${CL} Full permissions (PVEAuditor + PVEVMAdmin)"
        echo ""
        read -p "Select permission level [1-2] (default: 2): " fix_perm_choice
        fix_perm_choice=${fix_perm_choice:-2}

        if [ "$fix_perm_choice" = "1" ]; then
            pvesh set /access/acl --path / --roles PVEAuditor --users "proxbalance@pam" --propagate 1 2>/dev/null || true
            pvesh set /access/acl --path / --roles PVEAuditor --tokens "proxbalance@pam!proxbalance" --propagate 1 2>/dev/null || true
            msg_ok "Read-only permissions applied"
        else
            pvesh set /access/acl --path / --roles PVEAuditor --users "proxbalance@pam" --propagate 1 2>/dev/null || true
            pvesh set /access/acl --path / --roles PVEVMAdmin --users "proxbalance@pam" --propagate 1 2>/dev/null || true
            pvesh set /access/acl --path / --roles PVEAuditor --tokens "proxbalance@pam!proxbalance" --propagate 1 2>/dev/null || true
            pvesh set /access/acl --path / --roles PVEVMAdmin --tokens "proxbalance@pam!proxbalance" --propagate 1 2>/dev/null || true
            msg_ok "Full permissions applied"
        fi
    fi
fi

# Restart services
msg_info "Restarting services..."
pct exec "$CTID" -- systemctl restart proxmox-balance.service
pct exec "$CTID" -- systemctl restart proxmox-collector.timer
msg_ok "Services restarted"

# Trigger immediate data collection
msg_info "Triggering immediate data collection..."
pct exec "$CTID" -- systemctl start proxmox-collector.service
sleep 3
msg_ok "Data collection triggered"

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
    echo -e "     ${DIM}\"proxmox_api_token_id\": \"proxbalance@pam!proxbalance\",${CL}"
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
