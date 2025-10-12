#!/usr/bin/env bash

# Copyright (c) 2024 ProxBalance
# Author: Pr0zak
# License: MIT
# https://github.com/Pr0zak/ProxBalance
#
# ProxBalance - Proxmox Balance Manager
# Enhanced Installer v1.2 with Verbose Mode

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

# Global verbose flag
VERBOSE=0

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

msg_verbose() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo -e "  ${BL}[DEBUG]${CL} $1"
  fi
}

header_info() {
  clear
  cat <<"EOF"
╔════════════════════════════════════════════════════════════════╗
║  ProxBalance - Proxmox Balance Manager                        ║
║  Enhanced Installer v1.2                                      ║
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
select_verbose_mode() {
  msg_info "Installation Mode"
  echo -e "  ${BL}1)${CL} Standard (Recommended)"
  echo -e "  ${BL}2)${CL} Verbose (Show detailed debug output)"
  echo ""
  
  read -p "Select mode [1-2] (default: 1): " mode_choice
  mode_choice=${mode_choice:-1}
  
  case $mode_choice in
    1)
      VERBOSE=0
      msg_ok "Mode: ${GN}Standard${CL}"
      ;;
    2)
      VERBOSE=1
      msg_ok "Mode: ${GN}Verbose${CL}"
      ;;
    *)
      msg_error "Invalid selection, using Standard mode"
      VERBOSE=0
      ;;
  esac
}

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
  local template_name="debian-12-standard_12.12-1_amd64.tar.zst"
  local template_path="local:vztmpl/${template_name}"
  
  if pveam list local 2>/dev/null | grep -q "$template_name"; then
    TEMPLATE="$template_path"
    msg_ok "Using template: ${GN}${template_name}${CL}"
    return
  fi
  
  # Update template list
  msg_info "Updating template list..."
  msg_verbose "Running: pveam update"
  pveam update >/dev/null 2>&1 || true
  
  # List available Debian 12 templates
  mapfile -t TEMPLATES < <(pveam available 2>/dev/null | grep "debian-12-standard" | awk '{print $2}')
  
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
    if ! pveam list local 2>/dev/null | grep -q "$selected_template"; then
      msg_info "Downloading template..."
      msg_verbose "Running: pveam download local $selected_template"
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
  
  DETECTED_NODES=""
  
  # Method 1: Try pvesh
  msg_verbose "Attempting cluster detection via pvesh"
  if command -v pvesh &> /dev/null; then
    msg_verbose "Running: pvesh get /nodes --output-format json"
    DETECTED_NODES=$(pvesh get /nodes --output-format json 2>/dev/null | jq -r '.[].node' 2>/dev/null | tr '\n' ' ' || echo "")
    msg_verbose "pvesh result: '$DETECTED_NODES'"
  fi
  
  # Method 2: Try pvecm if pvesh failed
  if [ -z "$DETECTED_NODES" ] && command -v pvecm &> /dev/null; then
    msg_verbose "Attempting cluster detection via pvecm"
    msg_verbose "Running: pvecm nodes"
    DETECTED_NODES=$(pvecm nodes 2>/dev/null | grep -oP '(?<=Node ).*(?= \()' | tr '\n' ' ' || echo "")
    msg_verbose "pvecm result: '$DETECTED_NODES'"
  fi
  
  # Method 3: Check cluster.conf
  if [ -z "$DETECTED_NODES" ] && [ -f /etc/pve/corosync.conf ]; then
    msg_verbose "Attempting cluster detection via corosync.conf"
    msg_verbose "Reading: /etc/pve/corosync.conf"
    DETECTED_NODES=$(grep -oP '(?<=name: ).*' /etc/pve/corosync.conf 2>/dev/null | tr '\n' ' ' || echo "")
    msg_verbose "corosync.conf result: '$DETECTED_NODES'"
  fi
  
  # Method 4: List /etc/pve/nodes directory
  if [ -z "$DETECTED_NODES" ] && [ -d /etc/pve/nodes ]; then
    msg_verbose "Attempting cluster detection via /etc/pve/nodes"
    msg_verbose "Listing: /etc/pve/nodes/"
    DETECTED_NODES=$(ls /etc/pve/nodes/ 2>/dev/null | tr '\n' ' ' || echo "")
    msg_verbose "/etc/pve/nodes result: '$DETECTED_NODES'"
  fi
  
  # Trim whitespace
  DETECTED_NODES=$(echo "$DETECTED_NODES" | xargs)
  
  if [ -n "$DETECTED_NODES" ]; then
    msg_ok "Detected nodes: ${GN}${DETECTED_NODES}${CL}"
    
    # Set primary host to first node
    PROXMOX_HOST=$(echo "$DETECTED_NODES" | awk '{print $1}')
    msg_ok "Primary host: ${GN}${PROXMOX_HOST}${CL}"
    msg_verbose "All detected nodes: $DETECTED_NODES"
  else
    msg_warn "Could not auto-detect cluster"
    msg_verbose "All detection methods failed"
    read -p "Enter primary Proxmox host IP/hostname: " PROXMOX_HOST
    
    # Ask for all nodes
    echo ""
    msg_info "Enter all cluster node names/IPs (space-separated)"
    read -p "Nodes [or press Enter to skip]: " manual_nodes
    if [ -n "$manual_nodes" ]; then
      DETECTED_NODES="$manual_nodes"
      msg_verbose "Manually entered nodes: $DETECTED_NODES"
    fi
  fi
}

show_summary() {
  msg_info "Configuration Summary"
  echo ""
  echo -e "  Installation Mode: ${GN}$([ "$VERBOSE" -eq 1 ] && echo "Verbose" || echo "Standard")${CL}"
  echo -e "  Container ID:      ${GN}${CTID}${CL}"
  echo -e "  Hostname:          ${GN}${HOSTNAME}${CL}"
  echo -e "  Network:           ${GN}${NET_CONFIG}${CL}"
  echo -e "  Storage:           ${GN}${STORAGE}${CL}"
  echo -e "  Template:          ${GN}${TEMPLATE}${CL}"
  echo -e "  Memory:            ${GN}${MEMORY}${CL} MB"
  echo -e "  CPU Cores:         ${GN}${CORES}${CL}"
  echo -e "  Disk:              ${GN}${DISK}${CL} GB"
  echo -e "  Proxmox Host:      ${GN}${PROXMOX_HOST}${CL}"
  if [ -n "$DETECTED_NODES" ]; then
    echo -e "  Cluster Nodes:     ${GN}${DETECTED_NODES}${CL}"
  fi
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
  msg_verbose "Running: pct create $CTID $TEMPLATE --hostname $HOSTNAME ..."
  
  if [ "$VERBOSE" -eq 1 ]; then
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
  else
    pct create "$CTID" "$TEMPLATE" \
      --hostname "$HOSTNAME" \
      --memory "$MEMORY" \
      --cores "$CORES" \
      --rootfs "${STORAGE}:${DISK}" \
      --net0 "${NET_CONFIG}" \
      --unprivileged 1 \
      --features nesting=1 \
      --onboot 1 \
      --start 1 2>&1 | grep -v "^Creating filesystem" | grep -v "^extracting" | grep -v "^Total bytes" || true
  fi
  
  msg_ok "Container ${CTID} created"
  
  # Wait for container to be ready
  msg_info "Waiting for container to start..."
  msg_verbose "Sleeping 10 seconds for container initialization"
  sleep 10
  msg_ok "Container started"
}

get_container_ip() {
  msg_info "Getting Container IP"
  
  if [[ "$NET_CONFIG" == *"ip=dhcp"* ]]; then
    local max_attempts=30
    local attempt=0
    
    msg_verbose "Detecting DHCP IP (max attempts: $max_attempts)"
    while [ $attempt -lt $max_attempts ]; do
      CONTAINER_IP=$(pct exec "$CTID" -- ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")
      
      if [ -n "$CONTAINER_IP" ]; then
        msg_ok "Container IP (DHCP): ${GN}${CONTAINER_IP}${CL}"
        return
      fi
      
      ((attempt++))
      msg_verbose "Attempt $attempt/$max_attempts - no IP yet"
      sleep 2
    done
    
    msg_warn "Could not detect DHCP IP after $max_attempts attempts"
    CONTAINER_IP="<DHCP-assigned>"
  else
    CONTAINER_IP=$(echo "$NET_CONFIG" | grep -oP '(?<=ip=)[^/]+')
    msg_ok "Container IP (Static): ${GN}${CONTAINER_IP}${CL}"
  fi
}

install_dependencies() {
  msg_info "Installing Dependencies"
  msg_verbose "Installing: python3, python3-venv, nginx, curl, jq, openssh-client, git"
  
  if [ "$VERBOSE" -eq 1 ]; then
    pct exec "$CTID" -- bash -c "
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y python3 python3-venv python3-pip nginx curl jq openssh-client git
    "
  else
    pct exec "$CTID" -- bash -c "
      export DEBIAN_FRONTEND=noninteractive
      apt-get update >/dev/null 2>&1
      apt-get install -y python3 python3-venv python3-pip nginx curl jq openssh-client git >/dev/null 2>&1
    "
  fi
  
  msg_ok "Dependencies installed"
}

install_proxbalance() {
  msg_info "Installing ProxBalance"
  msg_verbose "Cloning from: https://github.com/Pr0zak/ProxBalance.git"
  
  if [ "$VERBOSE" -eq 1 ]; then
    pct exec "$CTID" -- bash <<'EOF'
cd /opt
git clone https://github.com/Pr0zak/ProxBalance.git proxmox-balance-manager 2>&1 || {
  echo "Git clone failed, trying wget method..."
  wget https://github.com/Pr0zak/ProxBalance/archive/refs/heads/main.zip
  unzip main.zip
  mv ProxBalance-main proxmox-balance-manager
  rm main.zip
}
cd proxmox-balance-manager

echo "Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate
echo "Upgrading pip..."
pip install --upgrade pip
echo "Installing Python packages..."
pip install flask flask-cors gunicorn
deactivate

chmod +x /opt/proxmox-balance-manager/*.py 2>/dev/null || true
chmod +x /opt/proxmox-balance-manager/*.sh 2>/dev/null || true
EOF
  else
    pct exec "$CTID" -- bash <<'EOF'
cd /opt
git clone https://github.com/Pr0zak/ProxBalance.git proxmox-balance-manager >/dev/null 2>&1 || {
  wget -q https://github.com/Pr0zak/ProxBalance/archive/refs/heads/main.zip
  unzip -q main.zip
  mv ProxBalance-main proxmox-balance-manager
  rm main.zip
}
cd proxmox-balance-manager
python3 -m venv venv
source venv/bin/activate
pip install -q --upgrade pip
pip install -q flask flask-cors gunicorn
deactivate
chmod +x /opt/proxmox-balance-manager/*.py 2>/dev/null || true
chmod +x /opt/proxmox-balance-manager/*.sh 2>/dev/null || true
EOF
  fi
  
  msg_ok "ProxBalance installed"
}

configure_application() {
  msg_info "Configuring Application"
  msg_verbose "Writing config.json with proxmox_host=$PROXMOX_HOST"
  
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
  msg_verbose "Copying systemd service files"
  
  pct exec "$CTID" -- bash <<'EOF'
if [ -f /opt/proxmox-balance-manager/systemd/proxmox-balance.service ]; then
  cp /opt/proxmox-balance-manager/systemd/*.service /etc/systemd/system/ 2>/dev/null || true
  cp /opt/proxmox-balance-manager/systemd/*.timer /etc/systemd/system/ 2>/dev/null || true
fi
systemctl daemon-reload
systemctl enable proxmox-balance.service 2>/dev/null || true
systemctl enable proxmox-collector.timer 2>/dev/null || true
EOF
  
  msg_ok "Services configured"
}

setup_nginx() {
  msg_info "Configuring Web Server"
  msg_verbose "Copying nginx configuration and web files"
  
  if [ "$VERBOSE" -eq 1 ]; then
    pct exec "$CTID" -- bash <<'EOF'
if [ -f /opt/proxmox-balance-manager/index.html ]; then
  echo "Copying index.html to /var/www/html/"
  cp /opt/proxmox-balance-manager/index.html /var/www/html/
fi

if [ -f /opt/proxmox-balance-manager/nginx/proxmox-balance ]; then
  echo "Copying nginx config"
  cp /opt/proxmox-balance-manager/nginx/proxmox-balance /etc/nginx/sites-available/
fi

echo "Enabling nginx site"
ln -sf /etc/nginx/sites-available/proxmox-balance /etc/nginx/sites-enabled/ 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/default

echo "Testing nginx configuration"
nginx -t
echo "Restarting nginx"
systemctl restart nginx
systemctl enable nginx
EOF
  else
    pct exec "$CTID" -- bash <<'EOF'
if [ -f /opt/proxmox-balance-manager/index.html ]; then
  cp /opt/proxmox-balance-manager/index.html /var/www/html/
fi
if [ -f /opt/proxmox-balance-manager/nginx/proxmox-balance ]; then
  cp /opt/proxmox-balance-manager/nginx/proxmox-balance /etc/nginx/sites-available/
fi
ln -sf /etc/nginx/sites-available/proxmox-balance /etc/nginx/sites-enabled/ 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/default
nginx -t >/dev/null 2>&1 && systemctl restart nginx && systemctl enable nginx >/dev/null 2>&1
EOF
  fi
  
  msg_ok "Web server configured"
}

setup_ssh() {
  msg_info "Setting Up SSH Authentication"
  msg_verbose "Generating ed25519 SSH key pair"
  
  pct exec "$CTID" -- bash -c "
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N '' -q
  " 2>/dev/null || true
  
  SSH_PUBKEY=$(pct exec "$CTID" -- cat /root/.ssh/id_ed25519.pub 2>/dev/null || echo "")
  
  if [ -n "$SSH_PUBKEY" ]; then
    msg_ok "SSH key generated"
    msg_verbose "Public key: $SSH_PUBKEY"
  else
    msg_error "Failed to generate SSH key"
    return 1
  fi
}

distribute_ssh_keys() {
  msg_info "Distributing SSH Keys to Cluster Nodes"
  
  # Use detected nodes or try to detect again
  local nodes=""
  if [ -n "$DETECTED_NODES" ]; then
    nodes="$DETECTED_NODES"
    msg_verbose "Using previously detected nodes: $nodes"
  else
    msg_verbose "No nodes detected previously, attempting detection again"
    
    # Try detection methods again
    if command -v pvesh &> /dev/null; then
      msg_verbose "Trying pvesh for node detection"
      nodes=$(pvesh get /nodes --output-format json 2>/dev/null | jq -r '.[].node' 2>/dev/null | tr '\n' ' ' || echo "")
    fi
    
    if [ -z "$nodes" ] && [ -d /etc/pve/nodes ]; then
      msg_verbose "Trying /etc/pve/nodes directory listing"
      nodes=$(ls /etc/pve/nodes/ 2>/dev/null | tr '\n' ' ' || echo "")
    fi
    
    nodes=$(echo "$nodes" | xargs)
    msg_verbose "Final node list: '$nodes'"
  fi
  
  if [ -z "$nodes" ]; then
    msg_warn "Could not auto-detect cluster nodes"
    echo ""
    echo -e "${YW}SSH Public Key (add manually to all nodes):${CL}"
    echo -e "${GN}${SSH_PUBKEY}${CL}"
    echo ""
    echo -e "Add to each node with:"
    echo -e "  ${BL}ssh root@<node> \"mkdir -p /root/.ssh && echo '${SSH_PUBKEY}' >> /root/.ssh/authorized_keys\"${CL}"
    echo ""
    read -p "Press Enter to continue..."
    return 0
  fi
  
  msg_ok "Detected nodes: ${GN}${nodes}${CL}"
  echo ""
  msg_info "Adding SSH key to nodes..."
  
  local failed_nodes=""
  local success_count=0
  for node in $nodes; do
    echo -n "  ${node}: "
    msg_verbose "Attempting SSH to $node"
    
    # Try to add SSH key
    if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes root@"${node}" \
       "mkdir -p /root/.ssh && echo '${SSH_PUBKEY}' >> /root/.ssh/authorized_keys && chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys" >/dev/null 2>&1; then
      echo -e "${GN}✓${CL}"
      ((success_count++))
      msg_verbose "Successfully added key to $node"
    else
      echo -e "${RD}✗${CL}"
      failed_nodes="${failed_nodes} ${node}"
      msg_verbose "Failed to add key to $node"
    fi
  done
  
  echo ""
  if [ -n "$failed_nodes" ]; then
    msg_warn "Successfully added to $success_count node(s), failed:${failed_nodes}"
    echo ""
    echo -e "${YW}SSH Public Key (add manually to failed nodes):${CL}"
    echo -e "${GN}${SSH_PUBKEY}${CL}"
    echo ""
    echo -e "Add to failed nodes with:"
    echo -e "  ${BL}ssh root@<node> \"mkdir -p /root/.ssh && echo '${SSH_PUBKEY}' >> /root/.ssh/authorized_keys\"${CL}"
    echo ""
    read -p "Press Enter to continue..."
  else
    msg_ok "SSH keys successfully distributed to all $success_count node(s)"
  fi
}

start_services() {
  msg_info "Starting Services"
  msg_verbose "Starting proxmox-balance.service and proxmox-collector.timer"
  
  pct exec "$CTID" -- bash <<'EOF'
systemctl start proxmox-balance.service 2>/dev/null || true
systemctl start proxmox-collector.timer 2>/dev/null || true
EOF
  
  sleep 3
  
  if pct exec "$CTID" -- systemctl is-active proxmox-balance.service &>/dev/null; then
    msg_ok "API service running"
  else
    msg_warn "API service may have issues - check logs"
    msg_verbose "Run: pct exec $CTID -- journalctl -u proxmox-balance -n 20"
  fi
  
  if pct exec "$CTID" -- systemctl is-active proxmox-collector.timer &>/dev/null; then
    msg_ok "Collector timer running"
  else
    msg_warn "Collector timer may have issues - check logs"
    msg_verbose "Run: pct exec $CTID -- journalctl -u proxmox-collector -n 20"
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
  echo -e "  ${BFR}Next Steps${CL}"
  echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  echo ""
  echo -e "  ${YW}1. Verify SSH connectivity to all nodes${CL}"
  echo -e "     ${BL}pct exec ${CTID} -- ssh root@<node> 'echo OK'${CL}"
  echo ""
  echo -e "  ${YW}2. Trigger initial data collection${CL}"
  echo -e "     ${BL}curl -X POST http://${CONTAINER_IP}/api/refresh${CL}"
  echo ""
  echo -e "  ${YW}3. Check service status${CL}"
  echo -e "     ${BL}pct exec ${CTID} -- systemctl status proxmox-balance${CL}"
  echo ""
  echo -e "  ${YW}4. Monitor logs${CL}"
  echo -e "     ${BL}pct exec ${CTID} -- journalctl -u proxmox-balance -f${CL}"
  echo ""
  
  msg_ok "ProxBalance is ready at: ${GN}http://${CONTAINER_IP}${CL}"
  echo ""
}

# ═══════════════════════════════════════════════════════════════
# Main Installation Flow
# ═══════════════════════════════════════════════════════════════
main() {
  # Disable exit on error for SSH distribution
  set +e
  trap 'set -e' RETURN
  
  header_info
  check_root
  check_proxmox
  
  msg_ok "Running on Proxmox VE"
  msg_ok "Running as root"
  echo ""
  
  select_verbose_mode
  select_container_id
  select_hostname
  select_network
  select_storage
  select_template
  select_resources
  detect_proxmox_nodes
  show_summary
  
  # Re-enable strict error handling for critical steps
  set -e
  
  create_container
  get_container_ip
  install_dependencies
  install_proxbalance
  configure_application
  setup_services
  setup_nginx
  setup_ssh
  
  # Disable exit on error for SSH distribution
  set +e
  distribute_ssh_keys
  set -e
  
  start_services
  show_completion
}

main "$@"
