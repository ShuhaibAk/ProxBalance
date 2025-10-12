#!/usr/bin/env bash

# ProxBalance Installer Script
# Automated installation for Proxmox VE
# https://github.com/Pr0zak/ProxBalance

# Copyright (c) 2025 Zak Forsyth
# Licensed under MIT License

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script version
VERSION="1.0.0"

# Default values
DEFAULT_CTID="333"
DEFAULT_HOSTNAME="pve-balance-mgr"
DEFAULT_DISK_SIZE="8"
DEFAULT_CORES="2"
DEFAULT_RAM="2048"
DEFAULT_STORAGE="local-lvm"
DEFAULT_TEMPLATE_STORAGE="local"

# GitHub repository
REPO_URL="https://github.com/Pr0zak/ProxBalance"
RAW_URL="https://raw.githubusercontent.com/Pr0zak/ProxBalance/main"

# Banner
function show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║                    ProxBalance Installer                  ║"
    echo "║                                                           ║"
    echo "║          Automated Cluster Load Balancing for            ║"
    echo "║                      Proxmox VE                          ║"
    echo "║                                                           ║"
    echo "║                      Version ${VERSION}                        ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print functions
function msg_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function msg_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

function msg_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function msg_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if running on Proxmox
function check_proxmox() {
    msg_info "Checking if running on Proxmox VE..."
    if ! command -v pveversion &> /dev/null; then
        msg_error "This script must be run on a Proxmox VE host!"
        exit 1
    fi
    
    PVE_VERSION=$(pveversion | grep -oP 'pve-manager/\K[0-9]+')
    if [ "$PVE_VERSION" -lt 7 ]; then
        msg_error "Proxmox VE 7.0 or higher is required!"
        exit 1
    fi
    msg_ok "Running on Proxmox VE $PVE_VERSION"
}

# Check if running as root
function check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        msg_error "This script must be run as root!"
        exit 1
    fi
}

# Get user input
function get_user_input() {
    echo ""
    echo -e "${GREEN}=== Container Configuration ===${NC}"
    echo ""
    
    # Container ID
    read -p "Enter Container ID [${DEFAULT_CTID}]: " CTID
    CTID=${CTID:-$DEFAULT_CTID}
    
    # Check if CTID already exists
    if pct status "$CTID" &>/dev/null; then
        msg_error "Container ID $CTID already exists!"
        read -p "Do you want to destroy it and continue? (yes/no): " DESTROY
        if [ "$DESTROY" = "yes" ]; then
            msg_warn "Destroying existing container $CTID..."
            pct stop "$CTID" 2>/dev/null || true
            pct destroy "$CTID" 2>/dev/null || true
            msg_ok "Container $CTID destroyed"
        else
            exit 1
        fi
    fi
    
    # Hostname
    read -p "Enter Hostname [${DEFAULT_HOSTNAME}]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
    
    # IP Address
    while true; do
        read -p "Enter IP Address (e.g., 10.0.0.131/24): " IP_ADDRESS
        if [[ $IP_ADDRESS =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            break
        else
            msg_error "Invalid IP address format!"
        fi
    done
    
    # Gateway
    while true; do
        read -p "Enter Gateway IP (e.g., 10.0.0.1): " GATEWAY
        if [[ $GATEWAY =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            break
        else
            msg_error "Invalid gateway format!"
        fi
    done
    
    # Proxmox Host IP (for SSH)
    while true; do
        read -p "Enter Proxmox Host IP (for SSH communication): " PROXMOX_HOST
        if [[ $PROXMOX_HOST =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            break
        else
            msg_error "Invalid IP format!"
        fi
    done
    
    # Advanced options
    echo ""
    read -p "Show advanced options? (y/n) [n]: " ADVANCED
    if [[ $ADVANCED =~ ^[Yy]$ ]]; then
        read -p "Disk Size (GB) [${DEFAULT_DISK_SIZE}]: " DISK_SIZE
        DISK_SIZE=${DISK_SIZE:-$DEFAULT_DISK_SIZE}
        
        read -p "CPU Cores [${DEFAULT_CORES}]: " CORES
        CORES=${CORES:-$DEFAULT_CORES}
        
        read -p "RAM (MB) [${DEFAULT_RAM}]: " RAM
        RAM=${RAM:-$DEFAULT_RAM}
        
        read -p "Storage location [${DEFAULT_STORAGE}]: " STORAGE
        STORAGE=${STORAGE:-$DEFAULT_STORAGE}
    else
        DISK_SIZE=$DEFAULT_DISK_SIZE
        CORES=$DEFAULT_CORES
        RAM=$DEFAULT_RAM
        STORAGE=$DEFAULT_STORAGE
    fi
    
    # Confirmation
    echo ""
    echo -e "${GREEN}=== Configuration Summary ===${NC}"
    echo "Container ID: $CTID"
    echo "Hostname: $HOSTNAME"
    echo "IP Address: $IP_ADDRESS"
    echo "Gateway: $GATEWAY"
    echo "Proxmox Host: $PROXMOX_HOST"
    echo "Disk Size: ${DISK_SIZE}GB"
    echo "CPU Cores: $CORES"
    echo "RAM: ${RAM}MB"
    echo "Storage: $STORAGE"
    echo ""
    read -p "Continue with installation? (y/n): " CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        msg_warn "Installation cancelled by user"
        exit 0
    fi
}

# Download Debian template
function download_template() {
    msg_info "Checking for Debian 12 template..."
    
    TEMPLATE="debian-12-standard_12.2-1_amd64.tar.zst"
    
    if ! pveam list "$DEFAULT_TEMPLATE_STORAGE" | grep -q "$TEMPLATE"; then
        msg_info "Downloading Debian 12 template..."
        pveam update
        pveam download "$DEFAULT_TEMPLATE_STORAGE" "$TEMPLATE"
        msg_ok "Template downloaded"
    else
        msg_ok "Template already exists"
    fi
}

# Create container
function create_container() {
    msg_info "Creating LXC container..."
    
    pct create "$CTID" \
        "${DEFAULT_TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}" \
        --hostname "$HOSTNAME" \
        --memory "$RAM" \
        --cores "$CORES" \
        --rootfs "${STORAGE}:${DISK_SIZE}" \
        --net0 "name=eth0,bridge=vmbr0,ip=${IP_ADDRESS},gw=${GATEWAY}" \
        --unprivileged 1 \
        --features nesting=1 \
        --onboot 1 \
        --start 1
    
    msg_ok "Container created and started"
    
    # Wait for container to be ready
    msg_info "Waiting for container to be ready..."
    sleep 10
}

# Install dependencies
function install_dependencies() {
    msg_info "Installing dependencies..."
    
    pct exec "$CTID" -- bash -c "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y python3 python3-venv python3-pip nginx curl jq openssh-client git
    "
    
    msg_ok "Dependencies installed"
}

# Download and install ProxBalance files
function install_proxbalance() {
    msg_info "Downloading ProxBalance files..."
    
    # Create directories
    pct exec "$CTID" -- mkdir -p /opt/proxmox-balance-manager
    pct exec "$CTID" -- mkdir -p /var/www/html
    pct exec "$CTID" -- mkdir -p /etc/nginx/sites-available
    pct exec "$CTID" -- mkdir -p /etc/systemd/system
    
    # Download files using curl
    FILES=(
        "app.py"
        "collector.py"
        "update_timer.py"
        "manage_settings.sh"
        "config.json"
        "index.html"
    )
    
    for file in "${FILES[@]}"; do
        msg_info "Downloading $file..."
        if [ "$file" = "index.html" ]; then
            pct exec "$CTID" -- curl -fsSL "${RAW_URL}/${file}" -o "/var/www/html/${file}"
        else
            pct exec "$CTID" -- curl -fsSL "${RAW_URL}/${file}" -o "/opt/proxmox-balance-manager/${file}"
        fi
    done
    
    # Download systemd files
    pct exec "$CTID" -- curl -fsSL "${RAW_URL}/systemd/proxmox-balance.service" \
        -o "/etc/systemd/system/proxmox-balance.service"
    pct exec "$CTID" -- curl -fsSL "${RAW_URL}/systemd/proxmox-collector.service" \
        -o "/etc/systemd/system/proxmox-collector.service"
    pct exec "$CTID" -- curl -fsSL "${RAW_URL}/systemd/proxmox-collector.timer" \
        -o "/etc/systemd/system/proxmox-collector.timer"
    
    # Download nginx config
    pct exec "$CTID" -- curl -fsSL "${RAW_URL}/nginx/proxmox-balance" \
        -o "/etc/nginx/sites-available/proxmox-balance"
    
    # Make scripts executable
    pct exec "$CTID" -- chmod +x /opt/proxmox-balance-manager/*.py
    pct exec "$CTID" -- chmod +x /opt/proxmox-balance-manager/*.sh
    
    msg_ok "ProxBalance files downloaded"
}

# Setup Python environment
function setup_python() {
    msg_info "Setting up Python virtual environment..."
    
    pct exec "$CTID" -- bash -c "
        cd /opt/proxmox-balance-manager
        python3 -m venv venv
        source venv/bin/activate
        pip install --upgrade pip
        pip install flask flask-cors gunicorn
        deactivate
    "
    
    msg_ok "Python environment configured"
}

# Configure application
function configure_app() {
    msg_info "Configuring ProxBalance..."
    
    # Update config.json with Proxmox host IP
    pct exec "$CTID" -- bash -c "cat > /opt/proxmox-balance-manager/config.json << EOF
{
  \"collection_interval_minutes\": 60,
  \"ui_refresh_interval_minutes\": 15,
  \"proxmox_host\": \"${PROXMOX_HOST}\"
}
EOF"
    
    msg_ok "Configuration updated"
}

# Setup nginx
function setup_nginx() {
    msg_info "Configuring nginx..."
    
    pct exec "$CTID" -- bash -c "
        ln -sf /etc/nginx/sites-available/proxmox-balance /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
        nginx -t
        systemctl restart nginx
        systemctl enable nginx
    "
    
    msg_ok "Nginx configured"
}

# Setup SSH keys
function setup_ssh() {
    msg_info "Setting up SSH keys for Proxmox communication..."
    
    # Generate SSH key in container
    pct exec "$CTID" -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
    
    # Get public key
    SSH_PUB_KEY=$(pct exec "$CTID" -- cat /root/.ssh/id_ed25519.pub)
    
    # Add to authorized_keys on Proxmox host
    echo "$SSH_PUB_KEY" >> /root/.ssh/authorized_keys
    
    # Test SSH connection
    pct exec "$CTID" -- ssh -o StrictHostKeyChecking=no "root@${PROXMOX_HOST}" "echo SSH_OK" &>/dev/null
    
    if [ $? -eq 0 ]; then
        msg_ok "SSH keys configured successfully"
    else
        msg_warn "SSH connection test failed - you may need to manually configure SSH keys"
    fi
    
    echo ""
    msg_info "SSH Public Key (add this to all Proxmox nodes):"
    echo -e "${YELLOW}${SSH_PUB_KEY}${NC}"
    echo ""
}

# Enable and start services
function start_services() {
    msg_info "Enabling and starting services..."
    
    pct exec "$CTID" -- bash -c "
        systemctl daemon-reload
        systemctl enable proxmox-balance
        systemctl enable proxmox-collector.timer
        systemctl start proxmox-balance
        systemctl start proxmox-collector.timer
    "
    
    msg_ok "Services started"
}

# Trigger initial data collection
function initial_collection() {
    msg_info "Triggering initial data collection..."
    
    pct exec "$CTID" -- systemctl start proxmox-collector.service
    
    msg_info "Waiting 30 seconds for data collection..."
    sleep 30
    
    msg_ok "Initial collection complete"
}

# Show completion message
function show_completion() {
    IP_ONLY=$(echo "$IP_ADDRESS" | cut -d'/' -f1)
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║            ProxBalance Installation Complete!             ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Container Information:${NC}"
    echo "  Container ID: $CTID"
    echo "  IP Address: $IP_ONLY"
    echo ""
    echo -e "${BLUE}Access ProxBalance:${NC}"
    echo "  Web Interface: ${GREEN}http://${IP_ONLY}${NC}"
    echo "  API Health: ${GREEN}http://${IP_ONLY}/api/health${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Open ${GREEN}http://${IP_ONLY}${NC} in your browser"
    echo "  2. Click the ⚙️ Settings icon to adjust intervals"
    echo "  3. Monitor your cluster and review recommendations"
    echo ""
    echo -e "${BLUE}SSH Key Distribution:${NC}"
    echo "  The SSH public key has been added to this Proxmox host."
    echo "  ${YELLOW}Add it to all other nodes in your cluster:${NC}"
    echo ""
    echo "  For each additional node, run:"
    echo "  ${YELLOW}echo '${SSH_PUB_KEY}' | ssh root@<node-ip> 'cat >> /root/.ssh/authorized_keys'${NC}"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  GitHub: ${GREEN}${REPO_URL}${NC}"
    echo "  Install Guide: ${GREEN}${REPO_URL}/blob/main/docs/INSTALL.md${NC}"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  Restart API: ${YELLOW}pct exec $CTID -- systemctl restart proxmox-balance${NC}"
    echo "  View logs: ${YELLOW}pct exec $CTID -- journalctl -u proxmox-balance -f${NC}"
    echo "  Settings: ${YELLOW}pct exec $CTID -- /opt/proxmox-balance-manager/manage_settings.sh show${NC}"
    echo ""
    echo -e "${GREEN}Thank you for using ProxBalance!${NC}"
    echo ""
}

# Main installation function
function main() {
    show_banner
    check_root
    check_proxmox
    get_user_input
    
    echo ""
    msg_info "Starting ProxBalance installation..."
    echo ""
    
    download_template
    create_container
    install_dependencies
    install_proxbalance
    setup_python
    configure_app
    setup_nginx
    setup_ssh
    start_services
    initial_collection
    show_completion
}

# Run main function
main
