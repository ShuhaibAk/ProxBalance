#!/usr/bin/env bash

# Copyright (c) 2024 ProxBalance
# Author: Pr0zak
# License: MIT
# https://github.com/Pr0zak/ProxBalance
#
# ProxBalance - Proxmox Balance Manager
# Standalone Installer

set -euo pipefail
shopt -s inherit_errexit nullglob

# ═══════════════════════════════════════════════════════════════
# Color Definitions
# ═══════════════════════════════════════════════════════════════
RD='\033[0;31m'
YW='\033[1;33m'
GN='\033[0;32m'
BL='\033[0;34m'
BFR='\033[1;97m'
CL='\033[0m'
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
INFO="${BL}ℹ${CL}"
WARN="${YW}⚠${CL}"

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════
msg_info() {
  echo -e "${INFO} ${BL}${1}${CL}"
}

msg_ok() {
  echo -e "${CM} ${GN}${1}${CL}"
}

msg_error() {
  echo -e "${CROSS} ${RD}${1}${CL}"
}

msg_warn() {
  echo -e "${WARN} ${YW}${1}${CL}"
}

header_info() {
  clear
  cat <<"EOF"
╔════════════════════════════════════════════════════════════════╗
║  ProxBalance - Proxmox Balance Manager                        ║
║  Standalone Installer v1.0                                    ║
╚════════════════════════════════════════════════════════════════╝
EOF
  echo ""
}

# ═══════════════════════════════════════════════════════════════
# Validation Functions
# ═══════════════════════════════════════════════════════════════
check_root() {
  if [[ $EUID -ne 0 ]]; then
    msg_error "This script must be run as root"
    exit 1
  fi
}

check_proxmox() {
  if ! command -v pct &> /dev/null; then
    msg_error "This script must be run on a Proxmox VE host"
    exit 1
  fi
}

get_next_ctid() {
  local next_id=100
  while pct status "$next_id" &>/dev/null; do
    ((next_id++))
  done
  echo "$next_id"
}

# ═══════════════════════════════════════════════════════════════
# Configuration Functions
# ═══════════════════════════════════════════════════════════════
select_container_id() {
  msg_info "Container ID Configuration"
  local next_ctid
  next_ctid=$(get_next_ctid)
  
  echo -e "  ${BL}1)${CL} Automatic (Next available: ${GN}${next_ctid}${CL})"
  echo -e "  ${BL}2)${CL} Manual (Enter custom ID)"
  echo ""
  
  read -p "Select option [1-2] (default: 1): " choice
  choice=${choice:-1}
  
  case $choice in
    1)
      CTID=$next_ctid
      ;;
    2)
      read -p "Enter container ID (100-999999): " custom_id
      if [[ ! "$custom_id" =~ ^[0-9]+$ ]] || [ "$custom_id" -lt 100 ]; then
        msg_error "Invalid container ID. Must be >= 100"
        select_container_id
        return
      fi
      if pct status "$custom_id" &>/dev/null; then
        msg_error "Container ID $custom_id already exists"
        select_container_id
        return
      fi
      CTID=$custom_id
      ;;
    *)
      msg_error "Invalid selection"
      select_container_id
      return
      ;;
  esac
  
  msg_ok "Container ID: ${GN}${CTID}${CL}"
}

select_hostname() {
  msg_info "Hostname Configuration"
  read -p "Enter hostname (default: ProxBalance): " hostname
  HOSTNAME=${hostname:-ProxBalance}
  msg_ok "Hostname: ${GN}${HOSTNAME}${CL}"
}

select_network() {
  msg_info "Network Configuration"
  echo -e "  ${BL}1)${CL} DHCP (Automatic) - ${GN}Recommended (default)${CL}"
  echo -e "  ${BL}2)${CL} Static IP"
  echo ""
  
  read -p "Select option [1-2] (default: 1): " choice
  choice=${choice:-1}
  
  case $choice in
    1)
      NET_CONFIG="name=eth0,bridge=vmbr0,ip=dhcp"
      msg_ok "Network: ${GN}DHCP (Automatic)${CL}"
      ;;
    2)
      read -p "Enter IP address (e.g., 10.0.0.131): " ip_addr
      read -p "Enter CIDR (e.g., 24): " cidr
      read -p "Enter gateway (e.g., 10.0.0.1): " gateway
      
      if [[ ! "$ip_addr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        msg_error "Invalid IP address format"
        select_network
        return
      fi
      
      NET_CONFIG="name=eth0,bridge=vmbr0,ip=${ip_addr}/${cidr},gw=${gateway}"
      msg_ok "Static IP: ${GN}${ip_addr}/${cidr}${CL} via ${GN}${gateway}${CL}"
      ;;
    *)
      msg_error "Invalid selection"
      select_network
      ;;
  esac
}

select_storage() {
  msg_info "Storage Configuration"
  
  # Get available storages
  mapfile -t STORAGES < <(pvesm status | awk 'NR>1 {print $1}')
  
  if [ ${#STORAGES[@]} -eq 0 ]; then
    msg_error "No storage found"
    exit 1
  fi
  
  echo "Available storage locations:"
  for i in "${!STORAGES[@]}"; do
    local storage_type
    storage_type=$(pvesm status | awk -v s="${STORAGES[$i]}" '$1==s {print $2}')
    echo -e "  ${BL}$((i+1)))${CL} ${STORAGES[$i]} ${YW}($storage_type)${CL}"
  done
  echo ""
  
  while true; do
    read -p "Select storage [1-${#STORAGES[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#STORAGES[@]} ]; then
      STORAGE="${STORAGES[$((choice-1))]}"
      msg_ok "Using storage: ${GN}${STORAGE}${CL}"
      break
    else
      msg_error "Invalid selection"
    fi
  done
}

select_template() {
  msg_info "Template Configuration"
  
  # Check for Debian 12 standard template
  local template_name="debian-12-standard_12.2-1_amd64.tar.zst"
  local template_path="local:vztmpl/${template_name}"
  
  if pveam list local | grep -q "$template_name"; then
    TEMPLATE="$template_path"
    msg_ok "Using template: ${GN}${template_name}${CL}"
    return
  fi
  
  # List available Debian 12 templates
  mapfile -t TEMPLATES < <(pveam available | grep "debian-12-standard" | awk '{print $2}')
  
  if [ ${#TEMPLATES[@]} -eq 0 ]; then
    msg_warn "No Debian 12 templates available"
    read -p "Enter template path manually: " TEMPLATE
    return
  fi
  
  echo "Available Debian 12 templates:"
  for i in "${!TEMPLATES[@]}"; do
    echo -e "  ${BL}$((i+1)))${CL} ${TEMPLATES[$i]}"
  done
  echo ""
  
  local default_choice=1
  read -p "Select template [1-${#TEMPLATES[@]}] (default: 1): " choice
  choice=${choice:-$default_choice}
  
  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#TEMPLATES[@]} ]; then
    local selected_template="${TEMPLATES[$((choice-1))]}"
    
    # Download template if not present
    if ! pveam list local | grep -q "$selected_template"; then
      msg_info "Downloading template..."
      if pveam download local "$selected_template"; then
        msg_ok "Template downloaded"
      else
        msg_error "Failed to download template"
        exit 1
      fi
    fi
    
    TEMPLATE="local:vztmpl/${selected_template}"
    msg_ok "Using template: ${GN}${selected_template}${CL}"
  else
    msg_error "Invalid selection"
    select_template
  fi
}

select_resources() {
  msg_info "Resource Configuration"
  
  read -p "Memory (MB) [default: 2048]: " memory
  MEMORY=${memory:-2048}
  
  read -p "CPU cores [default: 2]: " cores
  CORES=${cores:-2}
  
  read -p "Disk size (GB) [default: 8]: " disk
  DISK=${disk:-8}
  
  msg_ok "Resources: ${GN}${MEMORY}${CL}MB RAM, ${GN}${CORES}${CL} cores, ${GN}${DISK}${CL}GB disk"
}

detect_proxmox_nodes() {
  msg_info "Detecting Proxmox Cluster"
  
  if command -v pvesh &> /dev/null; then
    DETECTED_NODES=$(pvesh get /nodes --output-format json 2>/dev/null | jq -r '.[].node' 2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo "")
    
    if [ -n "$DETECTED_NODES" ]; then
      msg_ok "Detected nodes: ${GN}${DETECTED_NODES}${CL}"
      PROXMOX_HOST=$(echo "$DETECTED_NODES" | cut -d',' -f1)
      msg_ok "Primary host: ${GN}${PROXMOX_HOST}${CL}"
    else
      msg_warn "Could not auto-detect cluster"
      read -p "Enter primary Proxmox host IP/hostname: " PROXMOX_HOST
    fi
  else
    read -p "Enter primary Proxmox host IP/hostname: " PROXMOX_HOST
  fi
}

show_summary() {
  msg_info "Configuration Summary"
  echo ""
  echo -e "  Container ID:     ${GN}${CTID}${CL}"
  echo -e "  Hostname:         ${GN}${HOSTNAME}${CL}"
  echo -e "  Network:          ${GN}${NET_CONFIG}${CL}"
  echo -e "  Storage:          ${GN}${STORAGE}${CL}"
  echo -e "  Template:         ${GN}${TEMPLATE}${CL}"
  echo -e "  Memory:           ${GN}${MEMORY}${CL} MB"
  echo -e "  CPU Cores:        ${GN}${CORES}${CL}"
  echo -e "  Disk:             ${GN}${DISK}${CL} GB"
  echo -e "  Proxmox Host:     ${GN}${PROXMOX_HOST}${CL}"
  echo ""
  
  read -p "Proceed with installation? [Y/n]: " proceed
  proceed=${proceed:-Y}
  
  if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
    msg_info "Installation cancelled"
    exit 0
  fi
}

# ═══════════════════════════════════════════════════════════════
# Installation Functions
# ═══════════════════════════════════════════════════════════════
create_container() {
  msg_info "Creating Container"
  
  pct create "$CTID" "$TEMPLATE" \
    --hostname "$HOSTNAME" \
    --memory "$MEMORY" \
    --cores "$CORES" \
    --rootfs "${STORAGE}:${DISK}" \
    --net0 "${NET_CONFIG}" \
    --unprivileged 1 \
    --features nesting=1 \
    --onboot 1 \
    --start 1
  
  msg_ok "Container ${CTID} created"
  
  # Wait for container to be ready
  msg_info "Waiting for container to start..."
  sleep 10
  msg_ok "Container started"
}

get_container_ip() {
  msg_info "Getting Container IP"
  
  if [[ "$NET_CONFIG" == *"ip=dhcp"* ]]; then
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
      CONTAINER_IP=$(pct exec "$CTID" -- ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")
      
      if [ -n "$CONTAINER_IP" ]; then
        msg_ok "Container IP (DHCP): ${GN}${CONTAINER_IP}${CL}"
        return
      fi
      
      ((attempt++))
      sleep 2
    done
    
    msg_warn "Could not detect DHCP IP"
    CONTAINER_IP="<DHCP-assigned>"
  else
    CONTAINER_IP=$(echo "$NET_CONFIG" | grep -oP '(?<=ip=)[^/]+')
    msg_ok "Container IP (Static): ${GN}${CONTAINER_IP}${CL}"
  fi
}

install_dependencies() {
  msg_info "Installing Dependencies"
  
  pct exec "$CTID" -- bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update >/dev/null 2>&1
    apt-get install -y \
      python3 \
      python3-venv \
      python3-pip \
      nginx \
      curl \
      jq \
      openssh-client \
      git >/dev/null 2>&1
  "
  
  msg_ok "Dependencies installed"
}

install_proxbalance() {
  msg_info "Installing ProxBalance"
  
  pct exec "$CTID" -- bash <<'EOF'
cd /opt
git clone https://github.com/Pr0zak/ProxBalance.git proxmox-balance-manager
cd proxmox-balance-manager

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -q --upgrade pip
pip install -q flask flask-cors gunicorn
deactivate

# Make scripts executable
chmod +x /opt/proxmox-balance-manager/scripts/*.py 2>/dev/null || true
chmod +x /opt/proxmox-balance-manager/scripts/*.sh 2>/dev/null || true
chmod +x /opt/proxmox-balance-manager/*.py 2>/dev/null || true
chmod +x /opt/proxmox-balance-manager/*.sh 2>/dev/null || true
EOF
  
  msg_ok "ProxBalance installed"
}

configure_application() {
  msg_info "Configuring Application"
  
  pct exec "$CTID" -- bash <<EOF
cat > /opt/proxmox-balance-manager/config.json <<'CONFIGEOF'
{
  "collection_interval_minutes": 60,
  "ui_refresh_interval_minutes": 15,
  "proxmox_host": "${PROXMOX_HOST}"
}
CONFIGEOF
EOF
  
  msg_ok "Application configured"
}

setup_services() {
  msg_info "Setting Up System Services"
  
  pct exec "$CTID" -- bash <<'EOF'
# Copy service files (check multiple possible locations)
if [ -f /opt/proxmox-balance-manager/systemd/proxmox-balance.service ]; then
  cp /opt/proxmox-balance-manager/systemd/*.service /etc/systemd/system/
  cp /opt/proxmox-balance-manager/systemd/*.timer /etc/systemd/system/
elif [ -f /opt/proxmox-balance-manager/proxmox-balance.service ]; then
  cp /opt/proxmox-balance-manager/proxmox-balance.service /etc/systemd/system/
  cp /opt/proxmox-balance-manager/proxmox-collector.service /etc/systemd/system/
  cp /opt/proxmox-balance-manager/proxmox-collector.timer /etc/systemd/system/
fi

systemctl daemon-reload
systemctl enable proxmox-balance.service
systemctl enable proxmox-collector.timer
EOF
  
  msg_ok "Services configured"
}

setup_nginx() {
  msg_info "Configuring Web Server"
  
  pct exec "$CTID" -- bash <<'EOF'
# Copy web files (check multiple possible locations)
if [ -d /opt/proxmox-balance-manager/web ]; then
  cp -r /opt/proxmox-balance-manager/web/* /var/www/html/
elif [ -f /opt/proxmox-balance-manager/index.html ]; then
  cp /opt/proxmox-balance-manager/index.html /var/www/html/
fi

# Copy nginx config
if [ -f /opt/proxmox-balance-manager/nginx/proxmox-balance ]; then
  cp /opt/proxmox-balance-manager/nginx/proxmox-balance /etc/nginx/sites-available/
elif [ -f /opt/proxmox-balance-manager/proxmox-balance-nginx ]; then
  cp /opt/proxmox-balance-manager/proxmox-balance-nginx /etc/nginx/sites-available/proxmox-balance
fi

ln -sf /etc/nginx/sites-available/proxmox-balance /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl restart nginx && systemctl enable nginx
EOF
  
  msg_ok "Web server configured"
}

setup_ssh() {
  msg_info "Setting Up SSH Authentication"
  
  pct exec "$CTID" -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
  SSH_PUBKEY=$(pct exec "$CTID" -- cat /root/.ssh/id_ed25519.pub)
  
  msg_ok "SSH key generated"
}

distribute_ssh_keys() {
  msg_info "Distributing SSH Keys to Cluster Nodes"
  
  # Detect all cluster nodes
  local nodes
  if command -v pvesh &> /dev/null; then
    nodes=$(pvesh get /nodes --output-format json 2>/dev/null | jq -r '.[].node' 2>/dev/null | tr '\n' ' ')
  fi
  
  if [ -z "$nodes" ]; then
    msg_warn "Could not auto-detect cluster nodes - skipping SSH key distribution"
    return 0
  fi
  
  msg_ok "Auto-distributing SSH keys to: ${GN}${nodes}${CL}"
  echo ""
  msg_info "Adding SSH key to nodes..."
  
  for node in $nodes; do
    echo -n "  ${node}: "
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"${node}" \
       "mkdir -p /root/.ssh && echo '${SSH_PUBKEY}' >> /root/.ssh/authorized_keys" &>/dev/null; then
      echo -e "${GN}✓${CL}"
    else
      echo -e "${RD}✗${CL}"
    fi
  done
  
  msg_ok "SSH key distribution complete"
  
  # Test SSH connectivity
  msg_info "Testing SSH connectivity..."
  local test_results
  test_results=$(pct exec "$CTID" -- bash <<EOF
for node in $nodes; do
  if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no root@\$node 'echo OK' 2>/dev/null | grep -q OK; then
    echo "\$node:OK"
  else
    echo "\$node:FAILED"
  fi
done
EOF
)
  
  echo ""
  local connectivity_ok=true
  while IFS=: read -r node status; do
    if [ "$status" = "OK" ]; then
      echo -e "  ${node}: ${GN}✓ Connected${CL}"
    else
      echo -e "  ${node}: ${RD}✗ Failed${CL}"
      connectivity_ok=false
    fi
  done <<< "$test_results"
  
  echo ""
  if [ "$connectivity_ok" = true ]; then
    msg_ok "All SSH connections verified"
  else
    msg_warn "Some SSH connections failed - check configuration"
  fi
}

start_services() {
  msg_info "Starting Services"
  
  pct exec "$CTID" -- bash <<'EOF'
systemctl start proxmox-balance.service
systemctl start proxmox-collector.timer
EOF
  
  sleep 3
  
  if pct exec "$CTID" -- systemctl is-active proxmox-balance.service &>/dev/null; then
    msg_ok "API service running"
  else
    msg_warn "API service may have issues"
  fi
  
  if pct exec "$CTID" -- systemctl is-active proxmox-collector.timer &>/dev/null; then
    msg_ok "Collector timer running"
  else
    msg_warn "Collector timer may have issues"
  fi
}

show_completion() {
  echo ""
  echo -e "${GN}╔════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${GN}║${CL}  ${BFR}Installation Complete!${CL}                                        ${GN}║${CL}"
  echo -e "${GN}╚════════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  if [ "$CONTAINER_IP" != "<DHCP-assigned>" ]; then
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo -e "  ${BFR}Access Information${CL}"
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo -e "  ${BL}Web Interface:${CL}  ${GN}http://${CONTAINER_IP}${CL}"
    echo -e "  ${BL}API Endpoint:${CL}   ${GN}http://${CONTAINER_IP}/api${CL}"
    echo -e "  ${BL}Container ID:${CL}   ${GN}${CTID}${CL}"
    echo ""
  fi
  
  echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  echo -e "  ${BFR}Useful Commands${CL}"
  echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  echo ""
  echo -e "  ${YW}# Check detailed status${CL}"
  echo -e "  ${BL}bash -c \"\$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/check-status.sh)\" _ ${CTID}${CL}"
  echo ""
  echo -e "  ${YW}# Monitor data collection${CL}"
  echo -e "  ${BL}pct exec ${CTID} -- journalctl -u proxmox-collector -f${CL}"
  echo ""
  echo -e "  ${YW}# View API logs${CL}"
  echo -e "  ${BL}pct exec ${CTID} -- journalctl -u proxmox-balance -f${CL}"
  echo ""
  
  msg_ok "ProxBalance is now running at: ${GN}http://${CONTAINER_IP}${CL}"
  echo ""
}

# ═══════════════════════════════════════════════════════════════
# Main Installation Flow
# ═══════════════════════════════════════════════════════════════
main() {
  header_info
  check_root
  check_proxmox
  
  msg_ok "Running on Proxmox VE"
  msg_ok "Running as root"
  echo ""
  
  select_container_id
  select_hostname
  select_network
  select_storage
  select_template
  select_resources
  detect_proxmox_nodes
  show_summary
  
  create_container
  get_container_ip
  install_dependencies
  install_proxbalance
  configure_application
  setup_services
  setup_nginx
  setup_ssh
  distribute_ssh_keys
  start_services
  show_completion
}

# Trap to ensure we don't exit before completion
trap '' INT

main "$@"
