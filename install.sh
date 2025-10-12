#!/bin/bash
#
# ProxBalance - Proxmox Balance Manager Installer
# https://github.com/Pr0zak/ProxBalance
#
# Enhanced installer with automatic/manual container ID, DHCP/static IP, and default hostname
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_HOSTNAME="ProxBalance"
DEFAULT_MEMORY=2048
DEFAULT_CORES=2
DEFAULT_DISK=8
DEFAULT_STORAGE="local-lvm"
DEFAULT_TEMPLATE="local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"

# Script banner
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  ${GREEN}ProxBalance - Proxmox Balance Manager Installer${NC}             ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  Version 1.0                                                  ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}═══${NC} $1 ${BLUE}═══${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to print info messages
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if running on Proxmox host
if ! command -v pct &> /dev/null; then
    print_error "This script must be run on a Proxmox VE host"
    exit 1
fi

print_success "Running on Proxmox VE host"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

print_success "Running as root"

# ═══════════════════════════════════════════════════════════════
# Container ID Selection
# ═══════════════════════════════════════════════════════════════
print_header "Container ID Configuration"

# Function to find next available CT ID
get_next_ctid() {
    local next_id=100
    while pct status $next_id &>/dev/null; do
        ((next_id++))
    done
    echo $next_id
}

NEXT_CTID=$(get_next_ctid)
print_info "Next available container ID: ${GREEN}${NEXT_CTID}${NC}"

read -p "$(echo -e "Use automatic ID (${GREEN}${NEXT_CTID}${NC}) or enter custom ID? [a/c] (default: a): ")" ctid_choice
ctid_choice=${ctid_choice:-a}

if [[ "$ctid_choice" == "c" || "$ctid_choice" == "C" ]]; then
    while true; do
        read -p "Enter container ID (100-999999): " CTID
        if [[ ! "$CTID" =~ ^[0-9]+$ ]] || [ "$CTID" -lt 100 ]; then
            print_error "Invalid container ID. Must be a number >= 100"
            continue
        fi
        if pct status $CTID &>/dev/null; then
            print_error "Container ID $CTID already exists"
            continue
        fi
        break
    done
else
    CTID=$NEXT_CTID
fi

print_success "Using container ID: ${GREEN}${CTID}${NC}"

# ═══════════════════════════════════════════════════════════════
# Hostname Configuration
# ═══════════════════════════════════════════════════════════════
print_header "Hostname Configuration"

read -p "$(echo -e "Enter hostname (default: ${GREEN}${DEFAULT_HOSTNAME}${NC}): ")" HOSTNAME
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}

print_success "Hostname: ${GREEN}${HOSTNAME}${NC}"

# ═══════════════════════════════════════════════════════════════
# Network Configuration
# ═══════════════════════════════════════════════════════════════
print_header "Network Configuration"

echo "Select network configuration:"
echo "  1) DHCP (automatic) - recommended"
echo "  2) Static IP"
read -p "Choice [1-2] (default: 1): " net_choice
net_choice=${net_choice:-1}

if [ "$net_choice" == "2" ]; then
    # Static IP configuration
    read -p "Enter IP address (e.g., 10.0.0.131): " IP_ADDR
    read -p "Enter subnet mask in CIDR notation (e.g., 24): " CIDR
    read -p "Enter gateway (e.g., 10.0.0.1): " GATEWAY
    
    # Validate IP format
    if [[ ! "$IP_ADDR" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid IP address format"
        exit 1
    fi
    
    NET_CONFIG="name=eth0,bridge=vmbr0,ip=${IP_ADDR}/${CIDR},gw=${GATEWAY}"
    print_success "Static IP: ${GREEN}${IP_ADDR}/${CIDR}${NC} via ${GREEN}${GATEWAY}${NC}"
else
    # DHCP configuration
    NET_CONFIG="name=eth0,bridge=vmbr0,ip=dhcp"
    print_success "Network: ${GREEN}DHCP${NC} (automatic)"
fi

# ═══════════════════════════════════════════════════════════════
# Storage Configuration
# ═══════════════════════════════════════════════════════════════
print_header "Storage Configuration"

# List available storages
print_info "Available storage locations:"
pvesm status | awk 'NR>1 {print "  - " $1 " (" $2 ")"}'

read -p "$(echo -e "Enter storage name (default: ${GREEN}${DEFAULT_STORAGE}${NC}): ")" STORAGE
STORAGE=${STORAGE:-$DEFAULT_STORAGE}

# Verify storage exists
if ! pvesm status | grep -q "^${STORAGE} "; then
    print_error "Storage '${STORAGE}' not found"
    exit 1
fi

print_success "Using storage: ${GREEN}${STORAGE}${NC}"

# ═══════════════════════════════════════════════════════════════
# Template Selection
# ═══════════════════════════════════════════════════════════════
print_header "Template Configuration"

# List available Debian templates
print_info "Available Debian templates:"
pveam available | grep "debian-12" | awk '{print "  - " $2}'

read -p "$(echo -e "Enter template path (default: ${GREEN}${DEFAULT_TEMPLATE}${NC}): ")" TEMPLATE
TEMPLATE=${TEMPLATE:-$DEFAULT_TEMPLATE}

# Check if template exists, offer to download if not
if ! pveam list local | grep -q "${TEMPLATE##*:}"; then
    print_warning "Template not found locally"
    read -p "Download Debian 12 template? [y/N]: " download_template
    if [[ "$download_template" == "y" || "$download_template" == "Y" ]]; then
        print_info "Downloading template..."
        pveam download local debian-12-standard_12.2-1_amd64.tar.zst
        print_success "Template downloaded"
    else
        print_error "Template required to continue"
        exit 1
    fi
fi

print_success "Using template: ${GREEN}${TEMPLATE}${NC}"

# ═══════════════════════════════════════════════════════════════
# Resource Configuration
# ═══════════════════════════════════════════════════════════════
print_header "Resource Configuration"

read -p "$(echo -e "Memory (MB) (default: ${GREEN}${DEFAULT_MEMORY}${NC}): ")" MEMORY
MEMORY=${MEMORY:-$DEFAULT_MEMORY}

read -p "$(echo -e "CPU cores (default: ${GREEN}${DEFAULT_CORES}${NC}): ")" CORES
CORES=${CORES:-$DEFAULT_CORES}

read -p "$(echo -e "Disk size (GB) (default: ${GREEN}${DEFAULT_DISK}${NC}): ")" DISK
DISK=${DISK:-$DEFAULT_DISK}

print_success "Resources: ${GREEN}${MEMORY}${NC}MB RAM, ${GREEN}${CORES}${NC} cores, ${GREEN}${DISK}${NC}GB disk"

# ═══════════════════════════════════════════════════════════════
# Proxmox Host Configuration
# ═══════════════════════════════════════════════════════════════
print_header "Proxmox Cluster Configuration"

# Auto-detect cluster nodes
print_info "Detecting Proxmox cluster nodes..."
DETECTED_NODES=$(pvesh get /nodes --output-format json | jq -r '.[].node' | tr '\n' ',' | sed 's/,$//')

if [ -n "$DETECTED_NODES" ]; then
    print_success "Detected nodes: ${GREEN}${DETECTED_NODES}${NC}"
    read -p "Use detected nodes? [Y/n]: " use_detected
    use_detected=${use_detected:-Y}
    
    if [[ "$use_detected" == "Y" || "$use_detected" == "y" ]]; then
        # Use first node as primary host
        PROXMOX_HOST=$(echo $DETECTED_NODES | cut -d',' -f1)
    else
        read -p "Enter primary Proxmox host IP/hostname: " PROXMOX_HOST
    fi
else
    print_warning "Could not auto-detect cluster nodes"
    read -p "Enter primary Proxmox host IP/hostname (e.g., 10.0.0.3 or pve1): " PROXMOX_HOST
fi

print_success "Primary Proxmox host: ${GREEN}${PROXMOX_HOST}${NC}"

# ═══════════════════════════════════════════════════════════════
# Configuration Summary
# ═══════════════════════════════════════════════════════════════
print_header "Configuration Summary"

echo ""
echo "  Container ID:     ${GREEN}${CTID}${NC}"
echo "  Hostname:         ${GREEN}${HOSTNAME}${NC}"
echo "  Network:          ${GREEN}${NET_CONFIG}${NC}"
echo "  Memory:           ${GREEN}${MEMORY}${NC} MB"
echo "  CPU Cores:        ${GREEN}${CORES}${NC}"
echo "  Disk:             ${GREEN}${DISK}${NC} GB"
echo "  Storage:          ${GREEN}${STORAGE}${NC}"
echo "  Template:         ${GREEN}${TEMPLATE}${NC}"
echo "  Proxmox Host:     ${GREEN}${PROXMOX_HOST}${NC}"
echo ""

read -p "Proceed with installation? [Y/n]: " proceed
proceed=${proceed:-Y}

if [[ "$proceed" != "Y" && "$proceed" != "y" ]]; then
    print_info "Installation cancelled"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# Container Creation
# ═══════════════════════════════════════════════════════════════
print_header "Creating Container"

pct create $CTID $TEMPLATE \
    --hostname $HOSTNAME \
    --memory $MEMORY \
    --cores $CORES \
    --rootfs ${STORAGE}:${DISK} \
    --net0 ${NET_CONFIG} \
    --unprivileged 1 \
    --features nesting=1 \
    --onboot 1

print_success "Container ${CTID} created"

# Start container
print_info "Starting container..."
pct start $CTID
sleep 5
print_success "Container started"

# ═══════════════════════════════════════════════════════════════
# Get Container IP
# ═══════════════════════════════════════════════════════════════
print_header "Network Information"

if [ "$net_choice" == "1" ]; then
    # DHCP - need to wait and detect IP
    print_info "Waiting for DHCP lease..."
    sleep 10
    
    CONTAINER_IP=$(pct exec $CTID -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    
    if [ -n "$CONTAINER_IP" ]; then
        print_success "Container IP (DHCP): ${GREEN}${CONTAINER_IP}${NC}"
    else
        print_warning "Could not detect container IP. Check with: pct exec ${CTID} -- ip addr"
        CONTAINER_IP="<DHCP-assigned>"
    fi
else
    # Static IP
    CONTAINER_IP=$IP_ADDR
    print_success "Container IP (Static): ${GREEN}${CONTAINER_IP}${NC}"
fi

# ═══════════════════════════════════════════════════════════════
# Install Dependencies
# ═══════════════════════════════════════════════════════════════
print_header "Installing Dependencies"

print_info "Updating package lists..."
pct exec $CTID -- bash -c "apt-get update > /dev/null 2>&1"

print_info "Installing packages..."
pct exec $CTID -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-venv python3-pip nginx curl jq ssh git > /dev/null 2>&1"

print_success "Dependencies installed"

# ═══════════════════════════════════════════════════════════════
# Clone Repository and Install Application
# ═══════════════════════════════════════════════════════════════
print_header "Installing ProxBalance Application"

print_info "Cloning repository..."
pct exec $CTID -- bash << 'EOF'
cd /opt
git clone https://github.com/Pr0zak/ProxBalance.git proxmox-balance-manager
cd proxmox-balance-manager
EOF

print_success "Repository cloned"

# Create Python virtual environment
print_info "Setting up Python environment..."
pct exec $CTID -- bash << 'EOF'
cd /opt/proxmox-balance-manager
python3 -m venv venv
source venv/bin/activate
pip install -q flask flask-cors gunicorn
deactivate
EOF

print_success "Python environment ready"

# Configure application
print_info "Configuring application..."
pct exec $CTID -- bash << EOF
cat > /opt/proxmox-balance-manager/config.json << 'CONFIGEOF'
{
  "collection_interval_minutes": 60,
  "ui_refresh_interval_minutes": 15,
  "proxmox_host": "${PROXMOX_HOST}"
}
CONFIGEOF

chmod +x /opt/proxmox-balance-manager/*.py
chmod +x /opt/proxmox-balance-manager/*.sh
EOF

print_success "Application configured"

# ═══════════════════════════════════════════════════════════════
# Setup Systemd Services
# ═══════════════════════════════════════════════════════════════
print_header "Setting Up System Services"

print_info "Installing systemd services..."
pct exec $CTID -- bash << 'EOF'
# Copy service files
cp /opt/proxmox-balance-manager/systemd/proxmox-balance.service /etc/systemd/system/
cp /opt/proxmox-balance-manager/systemd/proxmox-collector.service /etc/systemd/system/
cp /opt/proxmox-balance-manager/systemd/proxmox-collector.timer /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable services
systemctl enable proxmox-balance.service
systemctl enable proxmox-collector.timer
EOF

print_success "Systemd services installed"

# ═══════════════════════════════════════════════════════════════
# Setup Nginx
# ═══════════════════════════════════════════════════════════════
print_header "Configuring Web Server"

print_info "Setting up Nginx..."
pct exec $CTID -- bash << 'EOF'
# Copy web files
cp -r /opt/proxmox-balance-manager/web/* /var/www/html/

# Copy nginx config
cp /opt/proxmox-balance-manager/nginx/proxmox-balance /etc/nginx/sites-available/

# Enable site
ln -sf /etc/nginx/sites-available/proxmox-balance /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx config
nginx -t

# Enable and restart nginx
systemctl enable nginx
systemctl restart nginx
EOF

print_success "Web server configured"

# ═══════════════════════════════════════════════════════════════
# Setup SSH Keys
# ═══════════════════════════════════════════════════════════════
print_header "Setting Up SSH Authentication"

print_info "Generating SSH key pair..."
pct exec $CTID -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q

print_success "SSH key generated"

# Get public key
SSH_PUBKEY=$(pct exec $CTID -- cat /root/.ssh/id_ed25519.pub)

print_info "SSH public key:"
echo -e "${YELLOW}${SSH_PUBKEY}${NC}"
echo ""

print_warning "You need to add this key to all Proxmox nodes"
echo ""
echo "Run these commands on each Proxmox node:"
echo ""

if [ -n "$DETECTED_NODES" ]; then
    IFS=',' read -ra NODES <<< "$DETECTED_NODES"
    for node in "${NODES[@]}"; do
        echo -e "${BLUE}# On node ${node}:${NC}"
        echo "ssh root@${node} \"mkdir -p /root/.ssh && echo '${SSH_PUBKEY}' >> /root/.ssh/authorized_keys\""
        echo ""
    done
else
    echo "mkdir -p /root/.ssh"
    echo "echo '${SSH_PUBKEY}' >> /root/.ssh/authorized_keys"
    echo ""
fi

read -p "Press Enter when SSH keys have been added to all nodes..."

# Test SSH connectivity
print_info "Testing SSH connectivity..."
if [ -n "$DETECTED_NODES" ]; then
    IFS=',' read -ra NODES <<< "$DETECTED_NODES"
    for node in "${NODES[@]}"; do
        if pct exec $CTID -- ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${node} "echo OK" &>/dev/null; then
            print_success "SSH to ${node}: OK"
        else
            print_error "SSH to ${node}: FAILED"
        fi
    done
else
    if pct exec $CTID -- ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${PROXMOX_HOST} "echo OK" &>/dev/null; then
        print_success "SSH to ${PROXMOX_HOST}: OK"
    else
        print_error "SSH to ${PROXMOX_HOST}: FAILED"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# Start Services
# ═══════════════════════════════════════════════════════════════
print_header "Starting Services"

print_info "Starting API service..."
pct exec $CTID -- systemctl start proxmox-balance.service
sleep 2

if pct exec $CTID -- systemctl is-active proxmox-balance.service &>/dev/null; then
    print_success "API service running"
else
    print_error "API service failed to start"
fi

print_info "Starting collector timer..."
pct exec $CTID -- systemctl start proxmox-collector.timer

if pct exec $CTID -- systemctl is-active proxmox-collector.timer &>/dev/null; then
    print_success "Collector timer running"
else
    print_error "Collector timer failed to start"
fi

# ═══════════════════════════════════════════════════════════════
# Initial Data Collection
# ═══════════════════════════════════════════════════════════════
print_header "Initial Data Collection"

print_info "Triggering first data collection (this may take 30-60 seconds)..."
pct exec $CTID -- /opt/proxmox-balance-manager/venv/bin/python3 /opt/proxmox-balance-manager/collector.py

if [ $? -eq 0 ]; then
    print_success "Initial data collection complete"
else
    print_warning "Initial data collection had issues. Check logs later."
fi

# ═══════════════════════════════════════════════════════════════
# Installation Complete
# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ${BLUE}Installation Complete!${NC}                                        ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_info "ProxBalance has been successfully installed!"
echo ""

if [ "$CONTAINER_IP" != "<DHCP-assigned>" ]; then
    echo -e "  ${BLUE}Web Interface:${NC}  http://${GREEN}${CONTAINER_IP}${NC}"
    echo -e "  ${BLUE}API Endpoint:${NC}   http://${GREEN}${CONTAINER_IP}${NC}/api"
else
    echo -e "  ${YELLOW}Note: Container is using DHCP${NC}"
    echo -e "  Run this command to get the IP address:"
    echo -e "  ${BLUE}pct exec ${CTID} -- ip -4 addr show eth0 | grep inet${NC}"
fi
echo ""

echo -e "${BLUE}Quick Commands:${NC}"
echo -e "  View logs:       ${GREEN}pct exec ${CTID} -- journalctl -u proxmox-balance -f${NC}"
echo -e "  Restart API:     ${GREEN}pct exec ${CTID} -- systemctl restart proxmox-balance${NC}"
echo -e "  Check status:    ${GREEN}pct exec ${CTID} -- systemctl status proxmox-balance${NC}"
echo -e "  Manual refresh:  ${GREEN}curl -X POST http://${CONTAINER_IP}/api/refresh${NC}"
echo ""

echo -e "${BLUE}Configuration:${NC}"
echo -e "  Config file:     ${GREEN}/opt/proxmox-balance-manager/config.json${NC}"
echo -e "  Settings tool:   ${GREEN}/opt/proxmox-balance-manager/manage_settings.sh${NC}"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Access the web interface in your browser"
echo "  2. Verify all Proxmox nodes are visible"
echo "  3. Adjust CPU/Memory thresholds as needed"
echo "  4. Configure collection intervals in Settings"
echo ""

print_success "Enjoy ProxBalance!"
echo ""
