# ProxBalance Installation Guide

Complete step-by-step installation instructions for ProxBalance.

---

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Quick Install (Recommended)](#-quick-install-recommended)
- [What the Installer Does](#-what-the-installer-does)
- [Manual Installation](#-manual-installation)
- [Post-Installation](#-post-installation)
- [Verification](#-verification)
- [Troubleshooting](#-troubleshooting)

---

## 📋 Prerequisites

Before installing ProxBalance, ensure you have:

### Required
- **Proxmox VE 7.0+** (tested on 7.x and 8.x)
- **Root access** to Proxmox host
- **Network connectivity** between container and all nodes
- **SSH access** to all Proxmox nodes (or ability to add SSH keys)

### Resource Requirements

**Minimum:**
- 2GB RAM
- 2 CPU cores
- 8GB disk space
- 1 available container ID

**Recommended:**
- 4GB RAM
- 2 CPU cores
- 16GB disk space

### Network Requirements
- Container needs network access to all Proxmox nodes
- DHCP server (recommended) or ability to configure static IP
- Port 80 available for web interface
- SSH (port 22) access to all nodes

---

## 🚀 Quick Install (Recommended)

### One-Command Installation

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install.sh)"
```

**That's it!** The installer handles everything automatically.

### Installation Time
- **Small clusters** (1-4 nodes): ~3-5 minutes
- **Large clusters** (5+ nodes): ~5-10 minutes
- **First data collection**: Additional 2-5 minutes

### What You'll Be Asked

The installer is interactive and will prompt you for:

1. **Container ID** 
   - Option 1: Automatic (next available ID) - **Recommended**
   - Option 2: Manual (specify custom ID)

2. **Hostname**
   - Default: `ProxBalance`
   - Can customize if desired

3. **Network Configuration**
   - Option 1: DHCP (Automatic) - **Recommended**
   - Option 2: Static IP (manual configuration)

4. **Storage Location**
   - Select from available Proxmox storage
   - Shows storage type for each option

5. **Template Selection**
   - Auto-detects if Debian 12 template exists
   - Downloads automatically if missing
   - Default: debian-12-standard_12.2-1_amd64

6. **Resources**
   - Memory: Default 2048MB (recommended)
   - CPU Cores: Default 2 (recommended)
   - Disk: Default 8GB (recommended)

7. **Confirmation**
   - Review all settings before proceeding

---

## 🔧 What the Installer Does

The automated installer performs these steps:

### Phase 1: Pre-Installation (30 seconds)
1. ✅ Validates you're running on Proxmox VE
2. ✅ Checks for root privileges
3. ✅ Detects next available container ID
4. ✅ Gathers your configuration preferences

### Phase 2: Container Creation (1-2 minutes)
1. ✅ Downloads Debian 12 template (if not present)
2. ✅ Creates unprivileged LXC container
3. ✅ Configures with your specified resources
4. ✅ Sets up networking (DHCP or static)
5. ✅ Starts the container
6. ✅ Detects container IP address

### Phase 3: Dependency Installation (1-2 minutes)
1. ✅ Updates package repositories
2. ✅ Installs system packages:
   - Python 3.8+
   - Python virtual environment
   - Nginx web server
   - curl, jq, ssh, git
3. ✅ Cleans up package cache

### Phase 4: ProxBalance Installation (1 minute)
1. ✅ Clones ProxBalance repository
2. ✅ Creates Python virtual environment
3. ✅ Installs Python dependencies:
   - Flask (web framework)
   - Flask-CORS (API support)
   - Gunicorn (WSGI server)
4. ✅ Sets file permissions

### Phase 5: Configuration (1 minute)
1. ✅ Auto-detects cluster nodes using 4 methods:
   - Method 1: Parses `/etc/pve/corosync.conf`
   - Method 2: Scans `/etc/pve/nodes/` directory
   - Method 3: Tries `pvecm status` command
   - Method 4: Queries `pvesh get /nodes`
2. ✅ Configures application with detected settings
3. ✅ Sets up systemd services (API, collector, timer)
4. ✅ Configures Nginx as reverse proxy
5. ✅ Enables services to start on boot

### Phase 6: SSH Key Setup (1-2 minutes)
1. ✅ Generates ed25519 SSH key pair in container
2. ✅ **Automatically distributes to all detected nodes** (parallel)
3. ✅ Tests SSH connectivity from Proxmox host
4. ✅ Tests SSH connectivity from container to each node
5. ✅ Reports success/failure for each node

### Phase 7: Service Startup (30 seconds)
1. ✅ Starts Flask API service
2. ✅ Starts data collector timer
3. ✅ Starts Nginx web server
4. ✅ Verifies all services are running

### Phase 8: Initial Data Collection (2-5 minutes)
1. ✅ Triggers first cluster data collection
2. ✅ Runs in background (non-blocking)
3. ✅ Web interface becomes available immediately
4. ✅ Data appears when collection completes

### Phase 9: Completion
1. ✅ Displays access information
2. ✅ Shows useful management commands
3. ✅ Provides quick action examples

---

## 📦 Manual Installation Steps

For advanced users who want full control over the installation process.

### Step 1: Download Debian Template

```bash
# Update template list
pveam update

# List available Debian 12 templates
pveam available | grep debian-12

# Download Debian 12 template
pveam download local debian-12-standard_12.2-1_amd64.tar.zst

# Verify download
pveam list local | grep debian-12
```

### Step 2: Create Container

```bash
# Set variables (customize as needed)
CTID=333
IP_ADDRESS="10.0.0.131/24"  # or "dhcp"
GATEWAY="10.0.0.1"
HOSTNAME="ProxBalance"
STORAGE="local-lvm"

# Create container with DHCP
pct create $CTID local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname $HOSTNAME \
  --memory 2048 \
  --cores 2 \
  --rootfs ${STORAGE}:8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --features nesting=1 \
  --onboot 1

# OR create container with static IP
pct create $CTID local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname $HOSTNAME \
  --memory 2048 \
  --cores 2 \
  --rootfs ${STORAGE}:8 \
  --net0 name=eth0,bridge=vmbr0,ip=$IP_ADDRESS,gw=$GATEWAY \
  --unprivileged 1 \
  --features nesting=1 \
  --onboot 1

# Start container
pct start $CTID

# Wait for boot
sleep 10
```

### Step 3: Install Dependencies

```bash
# Enter container
pct enter $CTID

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
  python3 \
  python3-venv \
  python3-pip \
  nginx \
  curl \
  jq \
  openssh-client \
  git

# Exit container
exit
```

### Step 4: Install ProxBalance

```bash
# Install from GitHub
pct exec $CTID -- bash -c "
cd /opt
git clone https://github.com/Pr0zak/ProxBalance.git proxmox-balance-manager
cd proxmox-balance-manager

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install --upgrade pip
pip install flask flask-cors gunicorn

# Deactivate venv
deactivate

# Set permissions
chmod +x /opt/proxmox-balance-manager/*.py
chmod +x /opt/proxmox-balance-manager/*.sh
"
```

### Step 5: Configure Application

```bash
# Create configuration file
pct exec $CTID -- bash -c 'cat > /opt/proxmox-balance-manager/config.json <<EOF
{
  "collection_interval_minutes": 60,
  "ui_refresh_interval_minutes": 15,
  "proxmox_host": "YOUR_PROXMOX_HOST_IP"
}
EOF'

# Replace YOUR_PROXMOX_HOST_IP with your actual Proxmox host IP
# Example: "10.0.0.1" or hostname
```

### Step 6: Setup System Services

```bash
# Copy systemd service files
pct exec $CTID -- bash -c "
cp /opt/proxmox-balance-manager/systemd/proxmox-balance.service /etc/systemd/system/
cp /opt/proxmox-balance-manager/systemd/proxmox-collector.service /etc/systemd/system/
cp /opt/proxmox-balance-manager/systemd/proxmox-collector.timer /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable services
systemctl enable proxmox-balance.service
systemctl enable proxmox-collector.timer
systemctl enable nginx.service
"
```

### Step 7: Configure Nginx

```bash
# Setup web server
pct exec $CTID -- bash -c "
# Copy web interface
cp /opt/proxmox-balance-manager/index.html /var/www/html/

# Copy Nginx configuration
cp /opt/proxmox-balance-manager/nginx/proxmox-balance /etc/nginx/sites-available/

# Enable site
ln -sf /etc/nginx/sites-available/proxmox-balance /etc/nginx/sites-enabled/

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Test configuration
nginx -t

# Restart Nginx
systemctl restart nginx
"
```

### Step 8: Setup SSH Keys

```bash
# Generate SSH key in container
pct exec $CTID -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q

# Get the public key
echo "=== SSH Public Key ==="
pct exec $CTID -- cat /root/.ssh/id_ed25519.pub
echo "======================"

# Add to each Proxmox node manually:
# Method 1: Copy-paste to each node
ssh root@node1 "mkdir -p /root/.ssh && echo 'PASTE_PUBLIC_KEY_HERE' >> /root/.ssh/authorized_keys"
ssh root@node2 "mkdir -p /root/.ssh && echo 'PASTE_PUBLIC_KEY_HERE' >> /root/.ssh/authorized_keys"

# Method 2: Use loop (replace with your node names)
for node in pve1 pve2 pve3 pve4; do
  echo "Adding key to $node..."
  pct exec $CTID -- cat /root/.ssh/id_ed25519.pub | \
    ssh root@$node "mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys"
done

# Test connectivity from container
pct exec $CTID -- bash -c '
for node in pve1 pve2 pve3 pve4; do
  echo -n "Testing $node: "
  ssh -o StrictHostKeyChecking=no root@$node "echo OK"
done
'
```

### Step 9: Start Services

```bash
# Start all services
pct exec $CTID -- systemctl start proxmox-balance.service
pct exec $CTID -- systemctl start proxmox-collector.timer
pct exec $CTID -- systemctl start nginx.service

# Check status
pct exec $CTID -- systemctl status proxmox-balance.service
pct exec $CTID -- systemctl status proxmox-collector.timer
pct exec $CTID -- systemctl status nginx.service
```

### Step 10: Initial Data Collection

```bash
# Get container IP
CONTAINER_IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
echo "Container IP: $CONTAINER_IP"

# Trigger first collection
curl -X POST http://$CONTAINER_IP/api/refresh

# Wait for collection to complete (60-90 seconds)
echo "Waiting for data collection..."
sleep 90

# Verify data was collected
curl http://$CONTAINER_IP/api/analyze | jq '.success'

# Should return: true
```

### Step 11: Access Web Interface

Open your browser and navigate to:
```
http://<container-ip>
```

You should see the ProxBalance dashboard!

---

## 🔧 Post-Installation Configuration

### 1. Verify Installation

Run the status checker:

```bash
# Download and run status checker
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/check-status.sh)" _ $CTID
```

This comprehensive check verifies:
- ✅ Container status and networking
- ✅ All service status
- ✅ Data collection status
- ✅ API health
- ✅ SSH connectivity to all nodes

### 2. Configure Collection Intervals

#### Via Web Interface (Recommended)
1. Click the ⚙️ **Settings** icon in the top right
2. Adjust **Backend Collection Interval** (5-240 minutes)
   - Small clusters (1-20 guests): 30-60 min
   - Medium clusters (21-50 guests): 60-120 min
   - Large clusters (50+ guests): 120-240 min
3. Adjust **UI Refresh Interval** (5-120 minutes)
   - Should be ≤ backend interval
   - Typical: 15-60 minutes
4. Click **Save Settings**
5. Services restart automatically

#### Via Command Line

```bash
# Show current settings
pct exec $CTID -- /opt/proxmox-balance-manager/manage_settings.sh show

# Set backend collection to 60 minutes
pct exec $CTID -- /opt/proxmox-balance-manager/manage_settings.sh set-backend 60

# Set UI refresh to 15 minutes
pct exec $CTID -- /opt/proxmox-balance-manager/manage_settings.sh set-ui 15

# Set both at once
pct exec $CTID -- /opt/proxmox-balance-manager/manage_settings.sh set-both 45
```

### 3. Configure Guest Tags

ProxBalance respects two types of tags on VMs and containers:

#### Ignore Tag - Prevent Migration
```bash
# For VMs
pvesh set /nodes/<node-name>/qemu/<vmid>/config --tags "ignore"

# For Containers
pvesh set /nodes/<node-name>/lxc/<vmid>/config --tags "ignore"
```

#### Anti-Affinity Tags - Keep Workloads Separated
```bash
# Example: Firewall VMs that must be on different nodes
pvesh set /nodes/pve1/qemu/100/config --tags "exclude_firewall"
pvesh set /nodes/pve2/qemu/101/config --tags "exclude_firewall"

# Example: Database servers
pvesh set /nodes/pve1/qemu/200/config --tags "exclude_database"
pvesh set /nodes/pve3/qemu/201/config --tags "exclude_database"

# Combine multiple tags (semicolon or space separated)
pvesh set /nodes/pve1/qemu/300/config --tags "ignore;exclude_critical"
```

After adding tags, trigger a data refresh:
```bash
curl -X POST http://<container-ip>/api/refresh
```

### 4. Adjust Thresholds

In the web interface:
- Use **CPU Threshold** slider (40-90%)
  - Default: 60%
  - Lower = more aggressive rebalancing
  - Higher = less frequent migrations
- Use **Memory Threshold** slider (50-95%)
  - Default: 70%
  - Adjust based on your workload patterns
- Recommendations update automatically as you adjust

### 5. Test a Migration

Before using in production, test with a non-critical guest:

1. Navigate to **Migration Recommendations** section
2. If recommendations appear, click **Execute** on one
3. Monitor progress in Proxmox web interface
4. Verify guest continues running after migration
5. Check ProxBalance logs: `pct exec $CTID -- journalctl -u proxmox-balance -f`

---

## 🔒 Security Hardening (Optional)

### 1. Implement Firewall Rules

Restrict access to the web interface:

```bash
# Install UFW
pct exec $CTID -- apt-get install -y ufw

# Allow SSH (important!)
pct exec $CTID -- ufw allow ssh

# Allow web interface only from your network
pct exec $CTID -- ufw allow from 10.0.0.0/24 to any port 80

# Enable firewall
pct exec $CTID -- ufw --force enable

# Check status
pct exec $CTID -- ufw status
```

### 2. Setup SSL/TLS with Let's Encrypt

If exposing externally with a domain name:

```bash
# Install Certbot
pct exec $CTID -- apt-get install -y certbot python3-certbot-nginx

# Obtain certificate (requires public domain)
pct exec $CTID -- certbot --nginx -d your-domain.com --non-interactive --agree-tos -m your-email@example.com

# Nginx will be automatically configured for HTTPS
# Certificate auto-renews via systemd timer

# Verify auto-renewal
pct exec $CTID -- systemctl list-timers | grep certbot
```

### 3. Restrict SSH Access

Configure SSH to only accept connections from cluster nodes:

```bash
# Edit SSH config in container
pct exec $CTID -- bash -c 'cat >> /root/.ssh/config <<EOF

# Proxmox cluster nodes
Host pve* 10.0.0.*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    
# Deny all other hosts
Host *
    User root
EOF'

# Set proper permissions
pct exec $CTID -- chmod 600 /root/.ssh/config
```

### 4. Enable Automatic Updates (Optional)

```bash
# Install unattended-upgrades
pct exec $CTID -- apt-get install -y unattended-upgrades

# Configure for security updates only
pct exec $CTID -- dpkg-reconfigure -plow unattended-upgrades
```

---

## ✅ Verification Checklist

After installation, verify everything is working:

### Container & Services
- [ ] Container is running: `pct status $CTID`
- [ ] Container has IP address (DHCP or static)
- [ ] Web interface loads: `http://<container-ip>`
- [ ] API responds: `curl http://<container-ip>/api/health`
- [ ] API service is active: `pct exec $CTID -- systemctl is-active proxmox-balance`
- [ ] Collector timer is active: `pct exec $CTID -- systemctl is-active proxmox-collector.timer`
- [ ] Nginx is active: `pct exec $CTID -- systemctl is-active nginx`

### Data Collection
- [ ] Cache file exists: `pct exec $CTID -- ls /opt/proxmox-balance-manager/cluster_cache.json`
- [ ] Cache has recent data: `pct exec $CTID -- jq '.collected_at' /opt/proxmox-balance-manager/cluster_cache.json`
- [ ] All nodes appear in dashboard
- [ ] Guest counts are correct
- [ ] CPU/Memory metrics are showing

### SSH Connectivity
- [ ] SSH works from container to all nodes
- [ ] Test: `pct exec $CTID -- ssh root@<node> "echo OK"`
- [ ] No password prompts (key-based auth)
- [ ] pvesh commands work from container

### Functionality
- [ ] Tags are recognized (if configured)
- [ ] Recommendations are generated (if cluster is imbalanced)
- [ ] Can adjust CPU/Memory thresholds
- [ ] Settings can be changed and persist
- [ ] Test migration works (optional, use non-critical guest)

### Boot Persistence
- [ ] Container set to start on boot: `pct config $CTID | grep onboot`
- [ ] Services enabled: `pct exec $CTID -- systemctl is-enabled proxmox-balance proxmox-collector.timer nginx`
- [ ] Reboot test: `pct reboot $CTID && sleep 30 && curl http://<container-ip>/api/health`

---

## 🐛 Common Installation Issues

### Issue: Container won't start

**Symptoms:** `pct start $CTID` fails or container shows as stopped

**Solutions:**
```bash
# Check container configuration
pct config $CTID

# Check for errors
pct start $CTID
# Read error message

# Common fixes:
# - Wrong storage specified
# - Insufficient resources on host
# - Network configuration error

# Check host resources
free -h
df -h

# Try starting in debug mode
pct start $CTID --debug
```

### Issue: SSH authentication fails

**Symptoms:** Cannot SSH from container to nodes

**Solutions:**
```bash
# Verify SSH key exists
pct exec $CTID -- ls -la /root/.ssh/

# Check key permissions
pct exec $CTID -- chmod 700 /root/.ssh
pct exec $CTID -- chmod 600 /root/.ssh/id_ed25519
pct exec $CTID -- chmod 644 /root/.ssh/id_ed25519.pub

# Regenerate if needed
pct exec $CTID -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q

# Get public key
pct exec $CTID -- cat /root/.ssh/id_ed25519.pub

# Add to each node
ssh root@<node> "echo 'PASTE_KEY_HERE' >> /root/.ssh/authorized_keys"

# Test connection with verbose output
pct exec $CTID -- ssh -vvv root@<node> "echo OK"
```

### Issue: Python dependencies fail to install

**Symptoms:** `pip install` commands fail

**Solutions:**
```bash
# Check internet connectivity from container
pct exec $CTID -- ping -c 3 8.8.8.8
pct exec $CTID -- curl -I https://pypi.org

# Update pip
pct exec $CTID -- /opt/proxmox-balance-manager/venv/bin/pip install --upgrade pip

# Try installing one package at a time
pct exec $CTID -- /opt/proxmox-balance-manager/venv/bin/pip install flask
pct exec $CTID -- /opt/proxmox-balance-manager/venv/bin/pip install flask-cors
pct exec $CTID -- /opt/proxmox-balance-manager/venv/bin/pip install gunicorn

# If still failing, check Python version
pct exec $CTID -- python3 --version
# Should be 3.8 or higher
```

### Issue: Nginx returns 502 Bad Gateway

**Symptoms:** Web interface shows 502 error

**Solutions:**
```bash
# Check if Flask is running
pct exec $CTID -- systemctl status proxmox-balance

# If not running, check logs
pct exec $CTID -- journalctl -u proxmox-balance -n 50

# Common causes:
# 1. Python syntax error in app.py
pct exec $CTID -- /opt/proxmox-balance-manager/venv/bin/python3 -m py_compile /opt/proxmox-balance-manager/app.py

# 2. Missing Python packages
pct exec $CTID -- /opt/proxmox-balance-manager/venv/bin/python3 -c "import flask, flask_cors; print('OK')"

# 3. Wrong port in Nginx config
pct exec $CTID -- grep proxy_pass /etc/nginx/sites-available/proxmox-balance
# Should show: proxy_pass http://127.0.0.1:5000;

# Restart Flask service
pct exec $CTID -- systemctl restart proxmox-balance
```

### Issue: DHCP IP not detected

**Symptoms:** Installer can't determine container IP

**Solutions:**
```bash
# Check if container has IP
pct exec $CTID -- ip addr show eth0

# If no IP, check DHCP server
# Look for DHCP offers in container logs
pct exec $CTID -- journalctl -n 50 | grep -i dhcp

# Manually restart networking
pct exec $CTID -- systemctl restart networking

# Or configure static IP instead
pct set $CTID -net0 name=eth0,bridge=vmbr0,ip=10.0.0.131/24,gw=10.0.0.1
pct reboot $CTID
```

### Issue: Nodes not auto-detected

**Symptoms:** Installer asks for manual node entry

**Solutions:**
```bash
# Test detection methods manually

# Method 1: corosync.conf
grep -oP '(?<=name: ).*' /etc/pve/corosync.conf

# Method 2: /etc/pve/nodes/
ls /etc/pve/nodes/

# Method 3: pvecm
pvecm status

# Method 4: pvesh
pvesh get /nodes --output-format json | jq -r '.[].node'

# If all fail, manually enter your node hostnames when prompted
```

---

## 📚 Next Steps

After successful installation:

1. **Read the Usage Guide** - [Main README](../README.md#-usage)
2. **Configure Tagging Rules** - [Tagging Documentation](../README.md#tagging-guests)
3. **Review API Documentation** - [API.md](API.md)
4. **Setup Backup Strategy** - [Backup Instructions](../README.md#-backup-instructions)
5. **Join Community Discussions** - [GitHub Discussions](https://github.com/Pr0zak/ProxBalance/discussions)

---

## 🆘 Need Help?

- **Run Diagnostics**: `bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/check-status.sh)" _ $CTID`
- **Check Troubleshooting Guide**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Open an Issue**: [GitHub Issues](https://github.com/Pr0zak/ProxBalance/issues)
- **Ask Questions**: [GitHub Discussions](https://github.com/Pr0zak/ProxBalance/discussions)

---

[⬆ Back to README](../README.md)