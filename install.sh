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
}  
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

initial_collection() {
  msg_info "Initial Data Collection"
  echo ""
  echo -e "${BL}═══════════════════════════════════════════════════════════════${CL}"
  echo -e "${YW}IMPORTANT:${CL} The first data collection can take 2-5 minutes"
  echo ""
  echo -e "During this time:"
  echo -e "  • The web interface will show an error"
  echo -e "  • API requests will return 503 (Service Unavailable)"
  echo -e "  • This is ${GN}normal${CL} and expected"
  echo ""
  echo -e "The collection gathers data from all cluster nodes via SSH."
  echo -e "${BL}═══════════════════════════════════════════════════════════════${CL}"
  echo ""
  
  read -p "Start initial data collection now? [Y/n]: " start_collection
  start_collection=${start_collection:-Y}
  
  if [[ ! "$start_collection" =~ ^[Yy]$ ]]; then
    msg_warn "Skipping initial collection"
    echo ""
    msg_info "You can trigger it manually later with:"
    echo -e "  ${YW}curl -X POST http://${CONTAINER_IP}/api/refresh${CL}"
    echo -e "  ${YW}pct exec ${CTID} -- systemctl start proxmox-collector.service${CL}"
    return
  fi
  
  echo ""
  msg_info "Starting data collection in background..."
  
  # Start collection in background
  pct exec "$CTID" -- bash -c "
    /opt/proxmox-balance-manager/venv/bin/python3 \
    /opt/proxmox-balance-manager/collector.py \
    > /var/log/proxmox-collector-initial.log 2>&1 &
    echo \$!
  " > /tmp/collector_pid 2>/dev/null
  
  local collector_pid
  collector_pid=$(cat /tmp/collector_pid 2>/dev/null)
  
  if [ -n "$collector_pid" ]; then
    msg_ok "Collection started (PID: ${collector_pid})"
  else
    msg_ok "Collection started"
  fi
  
  echo ""
  echo -e "${BL}Monitoring collection progress...${CL}"
  echo -e "${YW}This will take 2-5 minutes. Please wait...${CL}"
  echo ""
  
  local max_wait=300  # 5 minutes
  local wait_time=0
  local check_interval=10
  local dots=""
  
  while [ $wait_time -lt $max_wait ]; do
    # Check if cache file exists and is recent
    local cache_exists
    cache_exists=$(pct exec "$CTID" -- test -f /opt/proxmox-balance-manager/cluster_cache.json && echo "yes" || echo "no")
    
    if [ "$cache_exists" = "yes" ]; then
      # Check if it's recent (less than 60 seconds old)
      local cache_age
      cache_age=$(pct exec "$CTID" -- stat -c %Y /opt/proxmox-balance-manager/cluster_cache.json 2>/dev/null || echo "0")
      local now
      now=$(date +%s)
      local age_diff=$((now - cache_age))
      
      if [ $age_diff -lt 60 ]; then
        echo ""
        msg_ok "Data collection completed successfully!"
        
        # Verify data is valid
        local data_valid
        data_valid=$(pct exec "$CTID" -- bash -c "
          if command -v jq &>/dev/null; then
            jq -e '.nodes' /opt/proxmox-balance-manager/cluster_cache.json >/dev/null 2>&1 && echo 'yes' || echo 'no'
          else
            grep -q '\"nodes\"' /opt/proxmox-balance-manager/cluster_cache.json && echo 'yes' || echo 'no'
          fi
        " 2>/dev/null)
        
        if [ "$data_valid" = "yes" ]; then
          msg_ok "Cache file validated"
          
          # Show summary
          local node_count
          node_count=$(pct exec "$CTID" -- bash -c "
            if command -v jq &>/dev/null; then
              jq -r '.summary.total_nodes // 0' /opt/proxmox-balance-manager/cluster_cache.json 2>/dev/null
            else
              echo '?'
            fi
          ")
          
          local guest_count
          guest_count=$(pct exec "$CTID" -- bash -c "
            if command -v jq &>/dev/null; then
              jq -r '.summary.total_guests // 0' /opt/proxmox-balance-manager/cluster_cache.json 2>/dev/null
            else
              echo '?'
            fi
          ")
          
          if [ "$node_count" != "?" ] && [ "$guest_count" != "?" ]; then
            echo -e "  ${BL}Cluster Summary:${CL}"
            echo -e "    Nodes: ${GN}${node_count}${CL}"
            echo -e "    Guests: ${GN}${guest_count}${CL}"
          fi
        else
          msg_warn "Cache file created but may be incomplete"
        fi
        
        break
      fi
    fi
    
    # Update progress indicator
    dots="${dots}."
    if [ ${#dots} -gt 40 ]; then
      dots="."
    fi
    echo -ne "\r  Collecting data${dots} (${wait_time}s elapsed)                    "
    
    sleep $check_interval
    wait_time=$((wait_time + check_interval))
  done
  
  echo ""
  
  if [ $wait_time -ge $max_wait ]; then
    msg_warn "Collection is taking longer than expected"
    echo ""
    echo -e "${YW}The collection is still running in the background.${CL}"
    echo -e "You can monitor it with:"
    echo -e "  ${BL}pct exec ${CTID} -- tail -f /var/log/proxmox-collector-initial.log${CL}"
    echo -e "  ${BL}pct exec ${CTID} -- journalctl -u proxmox-collector -f${CL}"
  fi
  
  echo ""
  msg_info "Collection Status Check Commands:"
  echo -e "  ${BL}# Check if cache file exists${CL}"
  echo -e "  ${YW}pct exec ${CTID} -- ls -lh /opt/proxmox-balance-manager/cluster_cache.json${CL}"
  echo ""
  echo -e "  ${BL}# View collection timestamp${CL}"
  echo -e "  ${YW}pct exec ${CTID} -- jq -r '.collected_at' /opt/proxmox-balance-manager/cluster_cache.json${CL}"
  echo ""
  echo -e "  ${BL}# Check API health${CL}"
  echo -e "  ${YW}curl -s http://${CONTAINER_IP}/api/health | jq${CL}"
  echo ""
  echo -e "  ${BL}# Verify data is available${CL}"
  echo -e "  ${YW}curl -s http://${CONTAINER_IP}/api/analyze | jq '.success'${CL}"
  echo ""
}

show_completion() {
  echo ""
  echo -e "${GN}╔════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${GN}║${CL}  ${BFR}Installation Complete!${CL}                                        ${GN}║${CL}"
  echo -e "${GN}╚════════════════════════════════════════════════════════════════╝${CL}"
  echo ""
  
  msg_info "Running Post-Installation Checks..."
  echo ""
  
  # Check 1: Service Status
  echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  echo -e "  ${BFR}[1/4] Service Status${CL}"
  echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  
  sleep 1
  
  # Check API service
  if pct exec "$CTID" -- systemctl is-active proxmox-balance.service &>/dev/null; then
    echo -e "  ${CM} API Service: ${GN}running${CL}"
  else
    echo -e "  ${CROSS} API Service: ${RD}not running${CL}"
    echo -e "     ${YW}Check logs: pct exec ${CTID} -- journalctl -u proxmox-balance -n 20${CL}"
  fi
  
  # Check collector timer
  if pct exec "$CTID" -- systemctl is-active proxmox-collector.timer &>/dev/null; then
    echo -e "  ${CM} Collector Timer: ${GN}running${CL}"
    
    # Get next run time
    NEXT_RUN=$(pct exec "$CTID" -- systemctl list-timers proxmox-collector.timer 2>/dev/null | grep proxmox-collector | awk '{print $1, $2}' | head -1)
    if [ -n "$NEXT_RUN" ]; then
      echo -e "     ${BL}Next collection: ${YW}${NEXT_RUN}${CL}"
    fi
  else
    echo -e "  ${CROSS} Collector Timer: ${RD}not running${CL}"
  fi
  
  # Check nginx
  if pct exec "$CTID" -- systemctl is-active nginx.service &>/dev/null; then
    echo -e "  ${CM} Web Server: ${GN}running${CL}"
  else
    echo -e "  ${CROSS} Web Server: ${RD}not running${CL}"
  fi
  
  # Check 2: Network Connectivity
  echo ""
  echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  echo -e "  ${BFR}[2/4] Network & API Health${CL}"
  echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  
  if [ "$CONTAINER_IP" != "<DHCP-assigned>" ]; then
    echo -e "  ${CM} Container IP: ${GN}${CONTAINER_IP}${CL}"
    
    # Test API endpoint
    sleep 2
    API_RESPONSE=$(curl -s -w "\n%{http_code}" "http://${CONTAINER_IP}/api/health" 2>/dev/null || echo "error\n000")
    HTTP_CODE=$(echo "$API_RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" = "200" ]; then
      echo -e "  ${CM} API Endpoint: ${GN}responding (HTTP 200)${CL}"
    else
      echo -e "  ${CROSS} API Endpoint: ${RD}not responding (HTTP ${HTTP_CODE})${CL}"
    fi
  else
    echo -e "  ${YW}⚠${CL} DHCP IP not detected yet"
  fi
  
  # Check 3: SSH Connectivity
  echo ""
  echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  echo -e "  ${BFR}[3/4] SSH Connectivity to Cluster Nodes${CL}"
  echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  
  # Detect nodes from cache or cluster
  local test_nodes=""
  if pct exec "$CTID" -- test -f /opt/proxmox-balance-manager/cluster_cache.json 2>/dev/null; then
    test_nodes=$(pct exec "$CTID" -- cat /opt/proxmox-balance-manager/cluster_cache.json 2>/dev/null | grep -o '"[^"]*":' | grep -v "timestamp\|collected_at\|nodes\|guests\|summary\|metrics\|tags\|status\|cpu\|mem" | sed 's/"//g' | sed 's/://g' | head -10 | tr '\n' ' ')
  fi
  
  if [ -z "$test_nodes" ] && command -v pvesh &>/dev/null; then
    test_nodes=$(pvesh get /nodes --output-format json 2>/dev/null | grep -o '"node":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')
  fi
  
  if [ -n "$test_nodes" ]; then
    local ssh_test_results
    ssh_test_results=$(pct exec "$CTID" -- bash <<EOF
for node in $test_nodes; do
  if timeout 5 ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no root@\$node 'echo OK' 2>/dev/null | grep -q OK; then
    echo "\$node:OK"
  else
    echo "\$node:FAILED"
  fi
done
EOF
)
    
    local all_ssh_ok=true
    if [ -n "$ssh_test_results" ]; then
      while IFS=: read -r node status; do
        if [ -n "$node" ]; then
          if [ "$status" = "OK" ]; then
            echo -e "  ${CM} ${node}: ${GN}connected${CL}"
          else
            echo -e "  ${CROSS} ${node}: ${RD}failed${CL}"
            all_ssh_ok=false
          fi
        fi
      done <<< "$ssh_test_results"
      
      if [ "$all_ssh_ok" = false ]; then
        echo ""
        echo -e "  ${YW}⚠ Some nodes failed SSH connectivity${CL}"
        echo -e "  ${BL}SSH Public Key:${CL}"
        echo -e "  ${GN}${SSH_PUBKEY}${CL}"
        echo ""
        echo -e "  ${BL}Add manually to failed nodes:${CL}"
        echo -e "  ${YW}ssh root@<node> \"mkdir -p /root/.ssh && echo '${SSH_PUBKEY}' >> /root/.ssh/authorized_keys\"${CL}"
      fi
    else
      echo -e "  ${YW}⚠${CL} Could not test SSH connectivity (no nodes detected)"
    fi
  else
    echo -e "  ${YW}⚠${CL} No cluster nodes detected for SSH testing"
    echo -e "  ${BL}You may need to manually configure SSH access${CL}"
    if [ -n "$SSH_PUBKEY" ]; then
      echo ""
      echo -e "  ${BL}SSH Public Key:${CL}"
      echo -e "  ${GN}${SSH_PUBKEY}${CL}"
    fi
  fi
  
  # Check 4: Data Collection Status
  echo ""
  echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  echo -e "  ${BFR}[4/4] Data Collection Status${CL}"
  echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
  
  if pct exec "$CTID" -- test -f /opt/proxmox-balance-manager/cluster_cache.json; then
    echo -e "  ${CM} Cache File: ${GN}exists${CL}"
    
    # Get cluster summary
    local node_count
    node_count=$(pct exec "$CTID" -- grep -o '"total_nodes":[0-9]*' /opt/proxmox-balance-manager/cluster_cache.json 2>/dev/null | grep -o '[0-9]*' || echo "0")
    local guest_count
    guest_count=$(pct exec "$CTID" -- grep -o '"total_guests":[0-9]*' /opt/proxmox-balance-manager/cluster_cache.json 2>/dev/null | grep -o '[0-9]*' || echo "0")
    
    if [ "$node_count" != "0" ]; then
      echo -e "  ${CM} Cluster Data: ${GN}${node_count} nodes${CL}, ${GN}${guest_count} guests${CL}"
    else
      echo -e "  ${YW}⚠${CL} Cache file exists but appears incomplete"
    fi
  else
    echo -e "  ${YW}⚠${CL} Cache File: ${YW}not yet created${CL}"
    echo -e "     ${BL}Initial collection is running in background${CL}"
    echo -e "     ${BL}This can take 2-5 minutes to complete${CL}"
  fi
  
  # Summary
  echo ""
  echo -e "${GN}╔════════════════════════════════════════════════════════════════╗${CL}"
  echo -e "${GN}║${CL}  ${BFR}Post-Installation Check Complete${CL}                            ${GN}║${CL}"
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
  echo -e "  ${YW}# Restart services${CL}"
  echo -e "  ${BL}pct exec ${CTID} -- systemctl restart proxmox-balance${CL}"
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
  initial_collection
  show_completion
}

# Trap to ensure we don't exit before completion
trap '' INT

main "$@"

