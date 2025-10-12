# ProxBalance Installation Guide

Complete step-by-step installation instructions for ProxBalance.

---

## 📋 Prerequisites

Before installing ProxBalance, ensure you have:

- **Proxmox VE 7.0+** (tested on 7.x and 8.x)
- **Root access** to Proxmox host
- **Static IP address** for the container
- **Network connectivity** between container and all nodes
- **SSH access** to all Proxmox nodes

### Resource Requirements

**Minimum:**
- 2GB RAM
- 2 CPU cores
- 8GB disk space

**Recommended:**
- 4GB RAM
- 2 CPU cores
- 16GB disk space

---

## 🚀 Installation Methods

### Option 1: Automated Installation (Recommended)

The automated installer will:
1. Create an LXC container
2. Install all dependencies
3. Configure SSH keys
4. Setup all services
5. Deploy the web interface

```bash
# Download installer
wget https://raw.githubusercontent.com/zak-forsyth/ProxBalance/main/install.sh

# Make it executable
chmod +x install.sh

# Run the installer
./install.sh
```

**The installer will prompt you for:**
- Container ID (default: 333)
- Container IP address
- Gateway IP
- Proxmox host IP (for SSH)

### Option 2: Manual Installation

For advanced users who want full control over the installation process.

---

## 📦 Manual Installation Steps

### Step 1: Download Debian Template

```bash
# Update template list
pveam update

# Download Debian 12 template
pveam download local debian-12-standard_12.2-1_amd64.tar.zst
```

### Step 2: Create Container

```bash
# Replace values as needed
CTID=333
IP_ADDRESS="<your-ip>/24"
GATEWAY="<your-gateway>"
HOSTNAME="pve-balance-mgr"

pct create $CTID local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname $HOSTNAME \
  --memory 2048 \
  --cores 2 \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=$IP_ADDRESS,gw=$GATEWAY \
  --unprivileged 1 \
  --features nesting=1

# Start container
pct start $CTID
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
  ssh \
  git

# Exit container
exit
```

### Step 4: Download ProxBalance

```bash
# From Proxmox host
cd /tmp
git clone https://github.com/zak-forsyth/ProxBalance.git

# Or download release
wget https://github.com/zak-forsyth/ProxBalance/archive/refs/heads/main.zip
unzip main.zip
cd ProxBalance-main
```

### Step 5: Deploy Files

```bash
CTID=333

# Create directories
pct exec $CTID -- mkdir -p /opt/proxmox-balance-manager
pct exec $CTID -- mkdir -p /var/www/html
pct exec $CTID -- mkdir -p /etc/nginx/sites-available
pct exec $CTID -- mkdir -p /etc/systemd/system

# Copy Python application files
pct push $CTID app.py /opt/proxmox-balance-manager/app.py
pct push $CTID collector.py /opt/proxmox-balance-manager/collector.py
pct push $CTID config.json /opt/proxmox-balance-manager/config.json
pct push $CTID update_timer.py /opt/proxmox-balance-manager/update_timer.py
pct push $CTID manage_settings.sh /opt/proxmox-balance-manager/manage_settings.sh

# Make scripts executable
pct exec $CTID -- chmod +x /opt/proxmox-balance-manager/*.py
pct exec $CTID -- chmod +x /opt/proxmox-balance-manager/*.sh

# Copy web interface
pct push $CTID index.html /var/www/html/index.html

# Copy systemd services
pct push $CTID systemd/proxmox-balance.service /etc/systemd/system/proxmox-balance.service
pct push $CTID systemd/proxmox-collector.service /etc/systemd/system/proxmox-collector.service
pct push $CTID systemd/proxmox-collector.timer /etc/systemd/system/proxmox-collector.timer

# Copy nginx configuration
pct push $CTID nginx/proxmox-balance /etc/nginx/sites-available/proxmox-balance
```

### Step 6: Setup Python Environment

```bash
# Create virtual environment and install dependencies
pct exec $CTID -- bash -c "
cd /opt/proxmox-balance-manager
python3 -m venv venv
source venv/bin/activate
pip install flask flask-cors gunicorn
deactivate
"
```

### Step 7: Configure Nginx

```bash
# Enable site
pct exec $CTID -- ln -s /etc/nginx/sites-available/proxmox-balance /etc/nginx/sites-enabled/
pct exec $CTID -- rm -f /etc/nginx/sites-enabled/default

# Test configuration
pct exec $CTID -- nginx -t

# If test passes, reload nginx
pct exec $CTID -- systemctl restart nginx
```

### Step 8: Setup SSH Keys

```bash
# Generate SSH key in container
pct exec $CTID -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""

# Get the public key
echo "Copy this key to all Proxmox nodes:"
pct exec $CTID -- cat /root/.ssh/id_ed25519.pub

# Add to each node manually, or use this loop (replace with your node names):
for node in node1 node2 node3 node4; do
  ssh root@$node "mkdir -p /root/.ssh"
  pct exec $CTID -- cat /root/.ssh/id_ed25519.pub | ssh root@$node "cat >> /root/.ssh/authorized_keys"
done

# Test connectivity (replace with your node names)
for node in node1 node2 node3 node4; do
  echo "Testing $node..."
  pct exec $CTID -- ssh -o StrictHostKeyChecking=no root@$node "echo OK"
done
```

### Step 9: Configure Application

Edit the configuration file:

```bash
pct exec $CTID -- nano /opt/proxmox-balance-manager/config.json
```

Update the `proxmox_host` value to your Proxmox host IP:

```json
{
  "collection_interval_minutes": 60,
  "ui_refresh_interval_minutes": 15,
  "proxmox_host": "<your-proxmox-host-ip>"
}
```

### Step 10: Enable and Start Services

```bash
# Reload systemd
pct exec $CTID -- systemctl daemon-reload

# Enable services
pct exec $CTID -- systemctl enable proxmox-balance
pct exec $CTID -- systemctl enable proxmox-collector.timer
pct exec $CTID -- systemctl enable nginx

# Start services
pct exec $CTID -- systemctl start proxmox-balance
pct exec $CTID -- systemctl start proxmox-collector.timer
pct exec $CTID -- systemctl start nginx

# Check service status
pct exec $CTID -- systemctl status proxmox-balance
pct exec $CTID -- systemctl status proxmox-collector.timer
pct exec $CTID -- systemctl status nginx
```

### Step 11: Initial Data Collection

```bash
# Trigger first collection
curl -X POST http://<container-ip>/api/refresh

# Wait 60 seconds for collection to complete
sleep 60

# Verify data was collected
curl http://<container-ip>/api/analyze | jq '.success'
```

### Step 12: Access Web Interface

Open your browser and navigate to:
```
http://<container-ip>
```

You should see the ProxBalance dashboard!

---

## 🔧 Post-Installation Configuration

### 1. Configure Collection Intervals

Via web interface:
1. Click ⚙️ Settings
2. Adjust Backend Collection Interval (5-240 minutes)
3. Adjust UI Refresh Interval (5-120 minutes)
4. Click Save Settings

Via command line:
```bash
# Show current settings
pct exec $CTID -- /opt/proxmox-balance-manager/manage_settings.sh show

# Set backend to 60 minutes
pct exec $CTID -- /opt/proxmox-balance-manager/manage_settings.sh set-backend 60

# Set UI to 15 minutes
pct exec $CTID -- /opt/proxmox-balance-manager/manage_settings.sh set-ui 15
```

### 2. Configure Guest Tags

To exclude specific guests from migration:
```bash
# Add ignore tag (replace node and vmid)
pvesh set /nodes/<node-name>/qemu/<vmid>/config --tags "ignore"
```

To enforce anti-affinity rules:
```bash
# Firewall VMs must be on different nodes
pvesh set /nodes/<node1>/qemu/<vmid1>/config --tags "exclude_firewall"
pvesh set /nodes/<node2>/qemu/<vmid2>/config --tags "exclude_firewall"
```

### 3. Adjust Thresholds

In the web interface:
- Use sliders to adjust CPU threshold (40-90%)
- Use sliders to adjust Memory threshold (50-95%)
- Recommendations update automatically

---

## 🔒 Security Hardening (Optional)

### 1. Firewall Rules

```bash
# Allow only specific IPs to access web interface
pct exec $CTID -- apt-get install -y ufw
pct exec $CTID -- ufw allow from <your-network>/24 to any port 80
pct exec $CTID -- ufw enable
```

### 2. SSL/TLS with Let's Encrypt

```bash
# Install certbot
pct exec $CTID -- apt-get install -y certbot python3-certbot-nginx

# Get certificate (requires public domain)
pct exec $CTID -- certbot --nginx -d your-domain.com

# Nginx will be automatically configured for HTTPS
```

### 3. Restrict SSH Access

In container, edit `/root/.ssh/config`:
```bash
Host <node-prefix>*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
```

---

## ✅ Verification Checklist

After installation, verify everything is working:

- [ ] Container is running: `pct status $CTID`
- [ ] Web interface loads: `http://<container-ip>`
- [ ] API responds: `curl http://<container-ip>/api/health`
- [ ] Data collection works: Check `/opt/proxmox-balance-manager/cluster_cache.json`
- [ ] Services are enabled:
  - [ ] `systemctl status proxmox-balance`
  - [ ] `systemctl status proxmox-collector.timer`
  - [ ] `systemctl status nginx`
- [ ] SSH connectivity to all nodes works
- [ ] Tags are recognized (if configured)
- [ ] Recommendations are generated
- [ ] Migrations work (test with non-critical guest)

---

## 🐛 Common Installation Issues

### Issue: Container won't start

**Solution:**
```bash
# Check container configuration
pct config $CTID

# Check logs
pct enter $CTID
journalctl -xe
```

### Issue: SSH authentication fails

**Solution:**
```bash
# Verify SSH key exists
pct exec $CTID -- ls -la /root/.ssh/

# Regenerate if needed
pct exec $CTID -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""

# Re-add to all nodes
pct exec $CTID -- cat /root/.ssh/id_ed25519.pub
# Manually add to each node's /root/.ssh/authorized_keys
```

### Issue: Python dependencies fail to install

**Solution:**
```bash
# Update pip
pct exec $CTID -- /opt/proxmox-balance-manager/venv/bin/pip install --upgrade pip

# Reinstall dependencies
pct exec $CTID -- /opt/proxmox-balance-manager/venv/bin/pip install flask flask-cors gunicorn
```

### Issue: Nginx returns 502 Bad Gateway

**Solution:**
```bash
# Check if Flask is running
pct exec $CTID -- systemctl status proxmox-balance

# Check Flask logs
pct exec $CTID -- journalctl -u proxmox-balance -n 50

# Restart Flask
pct exec $CTID -- systemctl restart proxmox-balance
```

---

## 📚 Next Steps

After successful installation:

1. Read the [Usage Guide](../README.md#-usage)
2. Configure [tagging rules](../README.md#tagging-guests)
3. Review [API documentation](API.md)
4. Setup [backup strategy](../README.md#-backup-instructions)
5. Join the community discussions

---

## 🆘 Need Help?

- Check [Troubleshooting Guide](TROUBLESHOOTING.md)
- Open an [Issue](https://github.com/zak-forsyth/ProxBalance/issues)
- Review [Discussions](https://github.com/zak-forsyth/ProxBalance/discussions)

---

[⬆ Back to README](../README.md)
