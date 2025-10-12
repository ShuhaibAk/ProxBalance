#!/usr/bin/env bash

# ProxBalance Installation Repair Script
# Fixes incomplete or broken installations

set -euo pipefail

# Colors
RD='\033[0;31m'
YW='\033[1;33m'
GN='\033[0;32m'
BL='\033[0;34m'
CL='\033[0m'
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

CTID="${1:-335}"

echo -e "${BL}╔════════════════════════════════════════════════════════════════╗${CL}"
echo -e "${BL}║${CL}  ${YW}ProxBalance Installation Repair${CL}                            ${BL}║${CL}"
echo -e "${BL}║${CL}  Container: ${GN}${CTID}${CL}                                              ${BL}║${CL}"
echo -e "${BL}╚════════════════════════════════════════════════════════════════╝${CL}"
echo ""

# Check if container exists
if ! pct status "$CTID" &>/dev/null; then
    echo -e "${CROSS} Container ${CTID} not found"
    exit 1
fi

# Check container status
CT_STATUS=$(pct status "$CTID" | awk '{print $2}')
if [ "$CT_STATUS" != "running" ]; then
    echo -e "${CROSS} Container is ${CT_STATUS}. Starting..."
    pct start "$CTID"
    sleep 5
fi

echo -e "${CM} Container is running"

# Get container IP
CONTAINER_IP=$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}')
echo -e "${CM} Container IP: ${GN}${CONTAINER_IP}${CL}"
echo ""

# Step 1: Check if ProxBalance is installed
echo -e "${BL}[1/7]${CL} Checking ProxBalance installation..."
if pct exec "$CTID" -- test -d /opt/proxmox-balance-manager; then
    echo -e "${CM} ProxBalance directory exists"
else
    echo -e "${CROSS} ProxBalance not found. Installing..."
    pct exec "$CTID" -- bash <<'EOF'
cd /opt
git clone https://github.com/Pr0zak/ProxBalance.git proxmox-balance-manager
cd proxmox-balance-manager
python3 -m venv venv
source venv/bin/activate
pip install -q flask flask-cors gunicorn
deactivate
chmod +x /opt/proxmox-balance-manager/*.py 2>/dev/null || true
chmod +x /opt/proxmox-balance-manager/*.sh 2>/dev/null || true
EOF
    echo -e "${CM} ProxBalance installed"
fi

# Step 2: Check and fix configuration
echo ""
echo -e "${BL}[2/7]${CL} Checking configuration..."
if pct exec "$CTID" -- test -f /opt/proxmox-balance-manager/config.json; then
    echo -e "${CM} Configuration file exists"
else
    echo -e "${YW}⚠${CL} Creating configuration file..."
    
    # Detect primary Proxmox node
    PROXMOX_HOST=$(hostname -I | awk '{print $1}' | sed 's/\.[^.]*$/\.3/')
    
    pct exec "$CTID" -- bash <<EOF
cat > /opt/proxmox-balance-manager/config.json <<'CONFIGEOF'
{
  "collection_interval_minutes": 60,
  "ui_refresh_interval_minutes": 15,
  "proxmox_host": "${PROXMOX_HOST}"
}
CONFIGEOF
EOF
    echo -e "${CM} Configuration created"
fi

# Step 3: Check and fix systemd services
echo ""
echo -e "${BL}[3/7]${CL} Checking systemd services..."

# Check if service files exist
API_SERVICE_EXISTS=$(pct exec "$CTID" -- test -f /etc/systemd/system/proxmox-balance.service && echo "yes" || echo "no")
COLLECTOR_SERVICE_EXISTS=$(pct exec "$CTID" -- test -f /etc/systemd/system/proxmox-collector.service && echo "yes" || echo "no")
TIMER_EXISTS=$(pct exec "$CTID" -- test -f /etc/systemd/system/proxmox-collector.timer && echo "yes" || echo "no")

if [ "$API_SERVICE_EXISTS" = "yes" ] && [ "$COLLECTOR_SERVICE_EXISTS" = "yes" ] && [ "$TIMER_EXISTS" = "yes" ]; then
    echo -e "${CM} Service files exist"
else
    echo -e "${YW}⚠${CL} Installing service files..."
    pct exec "$CTID" -- bash <<'EOF'
# Copy service files if they exist in repo
if [ -f /opt/proxmox-balance-manager/proxmox-balance.service ]; then
    cp /opt/proxmox-balance-manager/proxmox-balance.service /etc/systemd/system/
    cp /opt/proxmox-balance-manager/proxmox-collector.service /etc/systemd/system/
    cp /opt/proxmox-balance-manager/proxmox-collector.timer /etc/systemd/system/
fi

systemctl daemon-reload
EOF
    echo -e "${CM} Service files installed"
fi

# Enable and start services
echo -e "${BL}[4/7]${CL} Starting services..."
pct exec "$CTID" -- bash <<'EOF'
systemctl daemon-reload
systemctl enable proxmox-balance.service 2>/dev/null || true
systemctl enable proxmox-collector.timer 2>/dev/null || true
systemctl enable nginx.service 2>/dev/null || true

systemctl restart proxmox-balance.service
systemctl restart proxmox-collector.timer
systemctl restart nginx.service
EOF

sleep 3

# Check service status
API_ACTIVE=$(pct exec "$CTID" -- systemctl is-active proxmox-balance.service 2>/dev/null || echo "inactive")
TIMER_ACTIVE=$(pct exec "$CTID" -- systemctl is-active proxmox-collector.timer 2>/dev/null || echo "inactive")
NGINX_ACTIVE=$(pct exec "$CTID" -- systemctl is-active nginx.service 2>/dev/null || echo "inactive")

if [ "$API_ACTIVE" = "active" ]; then
    echo -e "${CM} API service: ${GN}active${CL}"
else
    echo -e "${CROSS} API service: ${RD}${API_ACTIVE}${CL}"
    echo -e "${YW}   Checking logs...${CL}"
    pct exec "$CTID" -- journalctl -u proxmox-balance -n 10 --no-pager
fi

if [ "$TIMER_ACTIVE" = "active" ]; then
    echo -e "${CM} Collector timer: ${GN}active${CL}"
else
    echo -e "${CROSS} Collector timer: ${RD}${TIMER_ACTIVE}${CL}"
fi

if [ "$NGINX_ACTIVE" = "active" ]; then
    echo -e "${CM} Web server: ${GN}active${CL}"
else
    echo -e "${CROSS} Web server: ${RD}${NGINX_ACTIVE}${CL}"
fi

# Step 5: Setup SSH keys if not configured
echo ""
echo -e "${BL}[5/7]${CL} Checking SSH configuration..."
if pct exec "$CTID" -- test -f /root/.ssh/id_ed25519.pub; then
    echo -e "${CM} SSH key exists"
    SSH_PUBKEY=$(pct exec "$CTID" -- cat /root/.ssh/id_ed25519.pub)
else
    echo -e "${YW}⚠${CL} Generating SSH key..."
    pct exec "$CTID" -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
    SSH_PUBKEY=$(pct exec "$CTID" -- cat /root/.ssh/id_ed25519.pub)
    echo -e "${CM} SSH key generated"
fi

# Step 6: Distribute SSH keys
echo ""
echo -e "${BL}[6/7]${CL} Distributing SSH keys to cluster nodes..."

# Detect nodes
if command -v pvesh &>/dev/null; then
    NODES=$(pvesh get /nodes --output-format json 2>/dev/null | jq -r '.[].node' 2>/dev/null | tr '\n' ' ' || echo "")
fi

if [ -z "$NODES" ]; then
    echo -e "${YW}⚠${CL} Could not auto-detect nodes"
    read -p "Enter space-separated list of node hostnames (e.g., pve3 pve4 pve5 pve6): " NODES
fi

echo -e "   Detected nodes: ${GN}${NODES}${CL}"
echo ""

for node in $NODES; do
    echo -n "   ${node}: "
    
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"${node}" \
       "mkdir -p /root/.ssh && echo '${SSH_PUBKEY}' >> /root/.ssh/authorized_keys && chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys" &>/dev/null; then
        echo -e "${GN}✓${CL}"
    else
        echo -e "${RD}✗${CL}"
    fi
done

# Test connectivity
echo ""
echo -e "   Testing SSH connectivity from container..."
TEST_RESULTS=$(pct exec "$CTID" -- bash <<EOF
for node in $NODES; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@\$node 'echo OK' 2>/dev/null | grep -q OK; then
        echo "\$node:OK"
    else
        echo "\$node:FAILED"
    fi
done
EOF
)

ALL_OK=true
while IFS=: read -r node status; do
    if [ "$status" = "OK" ]; then
        echo -e "   ${node}: ${GN}✓ Connected${CL}"
    else
        echo -e "   ${node}: ${RD}✗ Failed${CL}"
        ALL_OK=false
    fi
done <<< "$TEST_RESULTS"

# Step 7: Trigger initial collection
echo ""
echo -e "${BL}[7/7]${CL} Triggering data collection..."

if [ "$ALL_OK" = true ]; then
    pct exec "$CTID" -- bash -c "/opt/proxmox-balance-manager/venv/bin/python3 /opt/proxmox-balance-manager/collector.py > /var/log/proxmox-collector-repair.log 2>&1 &"
    echo -e "${CM} Collection started in background"
    echo -e "   Monitor with: ${BL}pct exec ${CTID} -- tail -f /var/log/proxmox-collector-repair.log${CL}"
else
    echo -e "${YW}⚠${CL} Skipping collection due to SSH connectivity issues"
    echo -e "   Fix SSH connectivity first, then run:"
    echo -e "   ${BL}pct exec ${CTID} -- systemctl start proxmox-collector.service${CL}"
fi

# Summary
echo ""
echo -e "${GN}╔════════════════════════════════════════════════════════════════╗${CL}"
echo -e "${GN}║${CL}  ${BL}Repair Complete${CL}                                               ${GN}║${CL}"
echo -e "${GN}╚════════════════════════════════════════════════════════════════╝${CL}"
echo ""
echo -e "${BL}Access ProxBalance at:${CL} http://${GN}${CONTAINER_IP}${CL}"
echo ""
echo -e "${BL}Status check:${CL}"
echo -e "  bash -c \"\$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/check-status.sh)\" _ ${CTID}"
echo ""

if [ "$ALL_OK" = false ]; then
    echo -e "${YW}⚠ Warning:${CL} Some SSH connections failed"
    echo -e "   SSH Public Key:"
    echo -e "   ${GN}${SSH_PUBKEY}${CL}"
    echo ""
    echo -e "   Add manually to failed nodes:"
    echo -e "   ${BL}ssh root@<node> \"mkdir -p /root/.ssh && echo '${SSH_PUBKEY}' >> /root/.ssh/authorized_keys\"${CL}"
    echo ""
fi
