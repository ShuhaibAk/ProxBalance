# ProxBalance
<div align="center">

<img src="assets/logo.svg" alt="ProxBalance Logo" width="200"/>

<br/>
<br/>

![ProxBalance Logo](https://img.shields.io/badge/ProxBalance-Cluster_Optimization-1e40af?style=for-the-badge)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Python](https://img.shields.io/badge/python-3.8+-blue.svg?style=for-the-badge)](https://www.python.org/downloads/)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE_7%2B-orange.svg?style=for-the-badge)](https://www.proxmox.com/)

**Automated cluster load balancing and intelligent VM/CT migration for Proxmox VE**

[Quick Start](#-quick-start) • [Features](#-features) • [Usage](#-usage) • [Documentation](#-documentation)

---

### 🎯 Install in One Command

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install.sh)"
```

**⏱️ Complete setup in under 5 minutes!**  
Run on a Proxmox host, creates an LXC container with ProxBalance installed.

➡️ **[Detailed Installation Guide](docs/INSTALL.md#-quick-install-recommended)**

---

</div>

---

## 🎯 Overview

ProxBalance is a comprehensive web-based cluster balance analyzer and automated migration manager for Proxmox VE. It continuously monitors your cluster's resource utilization and provides intelligent migration recommendations to keep your infrastructure balanced and efficient.

### Why ProxBalance?

- **Real-time Monitoring** - Track CPU, memory, and load across all nodes
- **Smart Recommendations** - Migration suggestions based on historical data
- **Anti-Affinity Rules** - Tag-based system to enforce workload separation
- **One-Click Migrations** - Execute individual or batch migrations from the web UI
- **Zero Downtime** - Online migration for VMs, restart migration for containers
- **Dark Mode** - Beautiful, modern interface with light/dark themes

---

## ✨ Features

### 📊 Cluster Monitoring
- **Real-time metrics** for CPU, memory, and system load across all nodes
- **Historical analysis** using Proxmox RRD data (1-hour timeframe) for trend-based decisions
- **Automatic discovery** of all VMs (qemu) and containers (lxc) across the cluster
- **Health indicators** with customizable threshold alerts
- **Cached data architecture** - Fast API responses using JSON cache with atomic writes
- **Background collection** - Data gathered via systemd timer without blocking UI

### 🤖 Intelligent Balancing
- **Smart migration recommendations** based on node load and resource availability
  - Uses historical averages when available, falls back to current metrics
  - Considers both CPU and memory thresholds
  - Selects smallest guests first for efficient rebalancing
- **Anti-affinity enforcement** to prevent conflicting workloads on same nodes
  - Validates exclusion groups before suggesting migrations
  - Prevents migrations that would violate affinity rules
- **Ignore tags** to protect critical VMs from automatic migration
- **Batch migration** support with async execution for cluster-wide rebalancing
  - Non-blocking migrations run in background
  - Individual migration status tracking

### 🎨 Modern Web Interface
- **React-based dashboard** with real-time updates
- **Dark/light mode** support
- **Responsive design** for desktop and mobile
- **Configurable refresh intervals** for backend collection and UI updates
- **Live migration status** tracking with progress indicators

### 🔧 Advanced Configuration
- **Tag-based rules** for fine-grained control
  - `ignore` - Exclude from automatic migrations
  - `exclude_<group>` - Anti-affinity groups (prevents guests with same tag from being on same node)
- **Customizable thresholds** for CPU (40-90%) and memory (50-95%)
- **Flexible scheduling** with adjustable collection intervals (5-240 minutes)
- **SSH-based architecture** using ed25519 keys for secure, direct Proxmox control
- **Automatic configuration validation** with detailed error messages
- **Dynamic timer updates** - collection intervals update systemd timer in real-time

---

## 🚀 Quick Start

### Prerequisites

- Proxmox VE 7.0 or higher
- Root access to Proxmox host
- Network connectivity between container and all nodes
- Minimum: 2GB RAM, 2 CPU cores, 8GB disk
- Recommended: 4GB RAM, 2 CPU cores, 16GB disk

### Installation

#### Automated Install (Recommended)

```bash
# On your Proxmox host, run:
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install.sh)"
```

The installer will:
1. **Auto-detect your cluster nodes** using multiple methods (corosync.conf, /etc/pve/nodes/, pvecm, pvesh)
2. **Create an unprivileged LXC container** (default ID: next available, auto-incremented)
3. **Configure networking** - DHCP (auto-detected) or static IP
4. **Install all dependencies** - Python 3.8+, Flask, Gunicorn, Nginx, jq, curl, git
5. **Setup SSH keys** - Generate ed25519 keys and distribute to all nodes in parallel
6. **Deploy and start all services** - API, collector timer, and web server
7. **Trigger initial data collection** - Background collection starts immediately
8. **Verify installation** - Tests SSH connectivity and service status

#### Manual Install

See [docs/INSTALL.md](docs/INSTALL.md) for detailed step-by-step instructions.

### Initial Configuration

The installer automatically configures most settings, but you should verify:

1. **Access the web interface**: `http://<container-ip>`
   - The installer displays the URL at completion

2. **Wait for initial data collection** (2-5 minutes)
   - First collection runs automatically
   - View progress: `pct exec <ctid> -- journalctl -u proxmox-collector -f`

3. **Verify cluster detection**
   - Check that all nodes appear in the dashboard
   - Verify SSH connectivity to all nodes

4. **Adjust settings** (optional)
   - Click ⚙️ Settings icon
   - Customize collection intervals (default: 60 min)
   - Customize UI refresh intervals (default: 15 min)

### Quick Health Check

Run the status checker script:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/check-status.sh)" _ <container-id>
```

This provides a comprehensive health report including:
- Container status
- Service status
- Cache age and content
- API health
- SSH connectivity to all nodes

---

## ⚙️ Configuration

### Configuration File

Location: `/opt/proxmox-balance-manager/config.json`

```json
{
  "collection_interval_minutes": 60,
  "ui_refresh_interval_minutes": 15,
  "proxmox_host": "10.0.0.3"
}
```

### Configuration Options

| Option | Description | Default | Range |
|--------|-------------|---------|-------|
| `collection_interval_minutes` | How often to collect cluster data | 60 | 5-240 |
| `ui_refresh_interval_minutes` | How often the UI auto-refreshes | 15 | 5-120 |
| `proxmox_host` | Primary Proxmox host IP | Auto-detected | Any valid IP/hostname |

**Note:** Set UI interval ≤ backend interval for best experience.

### Updating Configuration

#### Via Web Interface
1. Click ⚙️ Settings icon
2. Adjust intervals using sliders
3. Click "Save Settings"
4. Services restart automatically

#### Via Command Line

```bash
# View current settings
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh show

# Set backend collection interval
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-backend 30

# Set UI refresh interval
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-ui 15

# Set both intervals at once
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-both 45
```

---

## 📖 Usage

### Tagging Guests

**Ignore tag** - Prevent automatic migration:
```bash
pvesh set /nodes/<node-name>/qemu/<vmid>/config --tags "ignore"
```

**Anti-affinity tags** - Keep workloads separated:
```bash
# Example: Firewall VMs that must be on different nodes
pvesh set /nodes/<node1>/qemu/<vmid1>/config --tags "exclude_firewall"
pvesh set /nodes/<node2>/qemu/<vmid2>/config --tags "exclude_firewall"

# Example: Database servers with anti-affinity
pvesh set /nodes/<node1>/qemu/<vmid1>/config --tags "exclude_database"
pvesh set /nodes/<node2>/qemu/<vmid2>/config --tags "exclude_database"
```

**Multiple tags** - Combine ignore with anti-affinity:
```bash
pvesh set /nodes/<node>/qemu/<vmid>/config --tags "ignore;exclude_firewall"
```

### API Endpoints

```bash
# Health check
curl http://<container-ip>/api/health

# Get cluster analysis
curl http://<container-ip>/api/analyze

# Get migration recommendations
curl -X POST http://<container-ip>/api/recommendations \
  -H "Content-Type: application/json" \
  -d '{"cpu_threshold": 60, "mem_threshold": 70}'

# Trigger data refresh
curl -X POST http://<container-ip>/api/refresh

# Execute single migration
curl -X POST http://<container-ip>/api/migrate \
  -H "Content-Type: application/json" \
  -d '{
    "vmid": 100,
    "source_node": "pve1",
    "target_node": "pve2",
    "type": "VM"
  }'

# Execute batch migrations
curl -X POST http://<container-ip>/api/migrate/batch \
  -H "Content-Type: application/json" \
  -d '{
    "migrations": [
      {"vmid": 100, "source_node": "pve1", "target_node": "pve2", "type": "VM"},
      {"vmid": 101, "source_node": "pve1", "target_node": "pve3", "type": "CT"}
    ]
  }'

# Get configuration
curl http://<container-ip>/api/config

# Update configuration
curl -X POST http://<container-ip>/api/config \
  -H "Content-Type: application/json" \
  -d '{
    "collection_interval_minutes": 30,
    "ui_refresh_interval_minutes": 15
  }'
```

### Useful Commands

```bash
# Check all service status
pct exec <ctid> -- systemctl status proxmox-balance proxmox-collector.timer nginx

# View API logs
pct exec <ctid> -- journalctl -u proxmox-balance -f

# View collector logs
pct exec <ctid> -- journalctl -u proxmox-collector -f

# Check cache file
pct exec <ctid> -- jq '.' /opt/proxmox-balance-manager/cluster_cache.json | head -50

# Manually trigger collection
pct exec <ctid> -- systemctl start proxmox-collector.service

# Restart all services
pct exec <ctid> -- systemctl restart proxmox-balance proxmox-collector.timer nginx

# Check SSH connectivity to nodes
pct exec <ctid> -- bash -c 'for node in pve1 pve2 pve3; do echo -n "$node: "; ssh root@$node "echo OK"; done'
```
---

## 📸 Screenshots

### Main Dashboard
![ProxBalance Dashboard](docs/images/dashboard.png)
*Main dashboard showing cluster status, resource metrics, and migration recommendations*

### Node Status & Resource Monitoring
![Node Status](docs/images/node-status.png)
*Real-time view of all cluster nodes with CPU, memory, cores, and guest distribution*

### Migration Recommendations
![Migration Recommendations](docs/images/recommendations.png)
*Intelligent migration suggestions with detailed reasoning and one-click execution*

### Tagged Guests & Affinity Rules
![Tagged Guests](docs/images/tagged-guests.png)
*Visual management of ignored guests and anti-affinity groups for workload separation*

### Settings Configuration
![Settings Panel](docs/images/settings.png)
*Easy configuration of collection intervals, UI refresh rates, and thresholds*

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Web Browser                       │
│              http://<container-ip>                  │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│                    Nginx                            │
│         (Static files + API proxy)                  │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│              Flask API (Gunicorn)                   │
│         Port 5000 - REST endpoints                  │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│          cluster_cache.json (Cache)                 │
│         (Read by API, written by collector)         │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│       Background Collector (systemd timer)          │
│    Runs every N minutes, collects via SSH           │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│            Proxmox Cluster (SSH)                    │
│        pvesh commands to nodes via SSH              │
└─────────────────────────────────────────────────────┘
```

### Components

- **Frontend**: React with Tailwind CSS (single-page application in index.html)
- **Backend API**: Flask + Gunicorn (Python 3.8+) on port 5000
- **Web Server**: Nginx (reverse proxy + static files) on port 80
- **Data Collector**: Python script (collector.py) with systemd timer
- **Cache**: JSON file (cluster_cache.json) with atomic writes for fast API responses
- **Communication**: SSH with ed25519 keys (passwordless key-based auth)
- **Configuration Manager**: update_timer.py dynamically updates systemd timers
- **Settings CLI**: manage_settings.sh for command-line configuration management

---

## 📁 Project Structure

```
ProxBalance/
├── app.py                      # Flask API server (8 endpoints)
├── collector.py                # Background data collector with RRD analysis
├── index.html                  # React web interface (single-page app)
├── config.json                 # Runtime configuration file
├── config.example.json         # Example configuration template
├── manage_settings.sh          # Settings CLI tool
├── update_timer.py             # Dynamic systemd timer updater
├── install.sh                  # Automated installer with node auto-detection
├── bootstrap-install.sh        # Bootstrap installer (downloads and runs install.sh)
├── check-status.sh             # Comprehensive status checker script
├── debug-services.sh           # Service debugger tool
├── systemd/
│   ├── proxmox-balance.service       # Flask API systemd service
│   ├── proxmox-collector.service     # Data collector service
│   └── proxmox-collector.timer       # Dynamic collection timer
├── nginx/
│   └── proxmox-balance               # Nginx reverse proxy config
├── docs/
│   ├── INSTALL.md                    # Detailed installation guide
│   └── TROUBLESHOOTING.md            # Comprehensive troubleshooting guide
├── assets/
│   ├── logo.svg                      # ProxBalance logo
│   └── favicon.svg                   # Browser favicon
├── LICENSE                     # MIT License
├── CONTRIBUTING.md             # Contribution guidelines
└── README.md                   # This file
```

---

## 🔒 Security

ProxBalance uses SSH key-based authentication to communicate with Proxmox nodes:

- **No passwords stored** - All authentication via SSH keys
- **Unprivileged container** - Runs as unprivileged LXC
- **Local network only** - Designed for internal cluster networks
- **API on localhost** - Nginx proxies, no direct external access to Flask

### Security Best Practices

1. **Use unprivileged LXC container** (default in installer)
2. **Implement firewall rules** to restrict web interface access
3. **Consider SSL/TLS** with Let's Encrypt if exposing externally
4. **Regular audits** - Review migration logs for unexpected activity
5. **SSH key rotation** - Periodically regenerate SSH keys
6. **Network isolation** - Run on management VLAN if possible

### Optional Security Hardening

```bash
# Firewall rules (UFW)
pct exec <ctid> -- apt-get install -y ufw
pct exec <ctid> -- ufw allow from <your-network>/24 to any port 80
pct exec <ctid> -- ufw enable

# SSL/TLS with Let's Encrypt
pct exec <ctid> -- apt-get install -y certbot python3-certbot-nginx
pct exec <ctid> -- certbot --nginx -d your-domain.com
```

---

## 🛠️ Troubleshooting

### Quick Diagnostics

```bash
# Run comprehensive status check
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/check-status.sh)" _ <ctid>

# Debug service issues
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/debug-services.sh)" _ <ctid>
```

### Common Issues

#### No cached data available

```bash
# Trigger manual collection
pct exec <ctid> -- systemctl start proxmox-collector.service

# Watch collection progress
pct exec <ctid> -- journalctl -u proxmox-collector -f

# Check if cache file exists
pct exec <ctid> -- ls -lh /opt/proxmox-balance-manager/cluster_cache.json
```

#### API not responding (502 Bad Gateway)

```bash
# Check Flask service
pct exec <ctid> -- systemctl status proxmox-balance

# Restart Flask
pct exec <ctid> -- systemctl restart proxmox-balance

# View recent logs
pct exec <ctid> -- journalctl -u proxmox-balance -n 50
```

#### SSH connectivity issues

```bash
# Test SSH from container
pct exec <ctid> -- ssh root@<node-name> "echo OK"

# Check SSH key exists
pct exec <ctid> -- ls -la /root/.ssh/id_ed25519*

# Regenerate SSH key if needed
pct exec <ctid> -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q

# Get public key to add to nodes
pct exec <ctid> -- cat /root/.ssh/id_ed25519.pub
```

#### Migrations failing

```bash
# Verify guest exists on source node
ssh root@<source-node> "pct list | grep <vmid>"  # for CT
ssh root@<source-node> "qm list | grep <vmid>"   # for VM

# Check for locks
ssh root@<source-node> "pct config <vmid> | grep lock"

# View Proxmox task log
ssh root@<source-node> "pvesh get /nodes/<source-node>/tasks"
```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for detailed solutions and comprehensive troubleshooting guides.

---

## 📊 Performance Recommendations

### Cluster Size Guidelines

| Cluster Size | Backend Interval | UI Interval | Expected RAM Usage |
|--------------|------------------|-------------|--------------------|
| 1-20 guests  | 15-30 min        | 10-15 min   | ~200MB            |
| 21-50 guests | 30-60 min        | 15-30 min   | ~250MB            |
| 51-100 guests| 60-120 min       | 30-60 min   | ~300MB            |
| 100+ guests  | 120-240 min      | 60-120 min  | ~400MB            |

### Resource Usage

- **Container Idle**: ~200MB RAM, <5% CPU
- **During Collection**: ~50-100MB RAM spike, 10-20% CPU for 30-60 seconds
- **Network**: Minimal (SSH queries only, ~100KB per collection)
- **Storage**: <100MB total, cache file grows with cluster size

### Optimization Tips

1. **Large clusters** (100+ guests): Increase intervals to reduce overhead
2. **Real-time monitoring**: Use shorter intervals for critical clusters
3. **Resource-constrained hosts**: Increase intervals, allocate more RAM to container
4. **Multiple networks**: Ensure low-latency connection between container and all nodes

---

## 📝 Version History

### Latest Version: 1.1.0 (January 2025)

**Core Features:**
- Real-time cluster monitoring with historical RRD data analysis (1-hour timeframe)
- Intelligent migration recommendations using averages when available
- Tag-based anti-affinity rules (`ignore`, `exclude_<group>`)
- Batch migration support with async, non-blocking execution
- Configurable collection intervals (5-240 minutes) with dynamic systemd timer updates
- Modern React-based web UI with dark/light mode support

**Installation & Deployment:**
- Automated installer with multi-method cluster node auto-detection
- Parallel SSH key distribution to all cluster nodes
- Bootstrap installer for one-command deployment
- Unprivileged LXC container deployment
- Automatic IP detection (DHCP) with static IP option

**API & Backend:**
- 8 REST API endpoints (health, analyze, refresh, recommendations, migrate, migrate/batch, config GET/POST)
- Flask + Gunicorn WSGI server on port 5000
- Nginx reverse proxy on port 80
- Cached data architecture with atomic JSON writes
- Configuration validation with detailed error messages

**Administration Tools:**
- Comprehensive status checker (check-status.sh)
- Service debugger (debug-services.sh)
- Settings management CLI (manage_settings.sh)
- Web-based settings configuration with auto-restart

**Security:**
- SSH-based communication using ed25519 keys
- Unprivileged container architecture
- No stored passwords or credentials
- Local network design

---

## 💬 Community & Support

### 🐛 Found a Bug?
Open an [issue](https://github.com/Pr0zak/ProxBalance/issues) with:
- Your Proxmox VE version
- Container configuration (`pct config <ctid>`)
- Steps to reproduce
- Logs from status checker script

### 💡 Feature Request?
We'd love to hear your ideas! Open a [feature request](https://github.com/Pr0zak/ProxBalance/issues/new) or start a [discussion](https://github.com/Pr0zak/ProxBalance/discussions).

### 🤝 Want to Contribute?
Contributions are welcome! See our [CONTRIBUTING.md](CONTRIBUTING.md) guide.

### 📣 Share Your Experience
Using ProxBalance? Share your setup:
- [r/Proxmox](https://reddit.com/r/Proxmox)
- [r/homelab](https://reddit.com/r/homelab)
- [Proxmox Forums](https://forum.proxmox.com/)

---

## ⭐ Show Your Support

If ProxBalance helps you manage your Proxmox cluster:
- ⭐ **Star this repository** on GitHub
- 📢 **Share it** with the homelab community
- 🐛 **Report bugs** to help improve
- 💡 **Suggest features** you'd like to see
- 🤝 **Contribute** code or documentation

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Proxmox VE** - Excellent open-source virtualization platform
- **React** - UI framework
- **Flask** - Python web framework
- **Tailwind CSS** - Utility-first CSS framework
- **Community Contributors** - Thank you for testing, feedback, and improvements!

---

<div align="center">

**Made with ❤️ for the Proxmox community**

[⬆ Back to Top](#proxbalance)

</div>
