# Changelog

All notable changes to ProxBalance will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2025-01-13

### 🎉 Installation & Detection Improvements

Major improvements to the installer with better cluster detection and SSH distribution.

### ✨ Added

#### Installer Enhancements
- **Automatic cluster node detection** using multiple methods
  - Method 1: Parse `/etc/pve/corosync.conf`
  - Method 2: Scan `/etc/pve/nodes/` directory
  - Fallback to manual entry if auto-detection fails
- **Parallel SSH key distribution** across all detected nodes
  - Significantly faster setup for multi-node clusters
  - Real-time progress feedback for each node
  - Comprehensive connectivity testing from container
- **DHCP support** with automatic IP detection
  - No more manual IP configuration required
  - 30-second timeout with visual feedback
  - Graceful fallback for static IP scenarios
- **Improved storage selection** with storage type display
- **Enhanced container ID selection** with auto-detection of next available ID
- **Better error handling** throughout installation process

#### New Utility Scripts
- **check-status.sh** - Comprehensive health checker
  - Container status and IP detection
  - Service status for all components
  - Data collection status and cache age
  - API health verification
  - SSH connectivity tests to all nodes
  - Quick action commands reference
- **debug-services.sh** - Service debugger for troubleshooting
  - Python environment verification
  - Application file checks
  - Service file validation
  - Manual service start attempts
  - Detailed log analysis
  - Syntax checking for Python files
- **test-node-detection.sh** - Node detection tester
  - Tests all 4 detection methods
  - Validates primary host selection
  - Useful for debugging installation issues

### 🔧 Improved

#### Installation Process
- **Cleaner terminal output** with better formatting
- **Progress indicators** for long-running operations
- **Summary display** before proceeding with installation
- **Automatic service enablement** for container start on boot
- **Better timeout handling** for network operations
- **Enhanced SSH key generation** with ed25519 algorithm

#### SSH Configuration
- **Automated key distribution** eliminates manual steps
- **Bidirectional connectivity testing** (host → nodes and container → nodes)
- **Parallel operations** for faster multi-node setup
- **Detailed feedback** on success/failure per node
- **Graceful handling** of unreachable nodes

#### User Experience
- **Clear installation steps** with visual separators
- **Informative messages** throughout the process
- **Validation** of user inputs
- **Recovery options** for failed steps
- **Post-installation guide** with exact commands

### 📖 Documentation

- **Updated README.md** with:
  - Improved quick start section
  - Better command examples
  - Enhanced troubleshooting section
  - New utility script documentation
- **Updated INSTALL.md** with:
  - Clearer prerequisites
  - Step-by-step manual installation
  - SSH key setup instructions
  - Verification checklist
- **Enhanced TROUBLESHOOTING.md** with:
  - Common installation issues
  - SSH connectivity problems
  - Service startup failures
  - Cache and collection issues

### 🐛 Fixed

- Fixed node detection failures in single-node clusters
- Fixed SSH key distribution hanging on unreachable nodes
- Fixed DHCP IP detection timeout issues
- Fixed installer progress messages overlapping
- Improved error messages for missing dependencies

### 🔒 Security

- Enhanced SSH key permissions handling
- Improved validation of user inputs
- Better isolation of sensitive operations
- Automated cleanup of temporary files

---

## [1.0.0] - 2025-01-12

### 🎉 Initial Release

The first official release of ProxBalance - automated cluster load balancing for Proxmox VE!

### ✨ Added

#### Core Features
- Real-time cluster monitoring with CPU, memory, and load metrics
- Historical analysis using Proxmox RRD data for trend-based decisions
- Automatic discovery of all VMs and containers across the cluster
- Smart migration recommendations based on node load and resource availability
- Tag-based system for fine-grained control
  - `ignore` tag to exclude guests from automatic migration
  - `exclude_<group>` tags for anti-affinity rules
- One-click migration execution from web interface
- Batch migration support for cluster-wide rebalancing

#### Web Interface
- Beautiful React-based dashboard with Tailwind CSS
- Real-time updates with configurable refresh intervals
- Dark/light mode support
- Responsive design for desktop and mobile
- Live migration status tracking with progress indicators
- Node status overview with health indicators
- Guest distribution visualization
- Affinity rule violation detection and warnings

#### Backend & Architecture
- Flask API with Gunicorn workers
- Background data collector with systemd timer
- JSON-based caching for fast API responses
- SSH-based secure communication with Proxmox nodes
- Nginx reverse proxy for static files and API routing
- Unprivileged LXC container deployment
- Configurable collection intervals (5-240 minutes)
- Configurable UI refresh intervals (5-120 minutes)

#### Installation & Management
- Automated installer script (Proxmox VE Helper-Scripts style)
- Interactive setup with validation
- Automatic container creation and configuration
- SSH key generation and distribution
- Service configuration and startup
- Command-line settings management tool
- Health check API endpoint

#### Documentation
- Comprehensive README with usage examples
- Detailed installation guide
- API documentation with examples
- Troubleshooting guide
- Architecture documentation
- Security recommendations
- Contributing guidelines

### 🔒 Security
- SSH key-based authentication (no passwords)
- Unprivileged container operation
- Local network only design
- No direct external API access

### 📊 Performance
- Efficient caching system
- Minimal resource usage (~200MB RAM idle)
- Optimized for clusters of all sizes (1-100+ guests)
- Adjustable intervals based on cluster size

### 🎯 Requirements
- Proxmox VE 7.0 or higher
- Debian 12 LXC container
- Python 3.8+
- 2GB RAM, 2 CPU cores, 8GB disk (minimum)
- SSH access to all Proxmox nodes

---

## [Unreleased]

Features and improvements planned for future releases:

### 🚀 Planned Features
- [ ] Email notifications for critical imbalances
- [ ] Webhook support for external integrations
- [ ] Custom migration policies (CPU-priority, memory-priority, balanced)
- [ ] Historical trend graphs and analytics
- [ ] Multi-cluster support
- [ ] API authentication/authorization
- [ ] Scheduled maintenance windows
- [ ] Guest dependency chains (migrate related guests together)
- [ ] Cost optimization mode (consolidate to fewer nodes)
- [ ] High availability mode (distribute for redundancy)
- [ ] Automatic rebalancing based on schedules
- [ ] Integration with Proxmox backup server

### 🔧 Planned Improvements
- [ ] WebSocket support for real-time updates
- [ ] Progressive Web App (PWA) support
- [ ] Mobile app (iOS/Android)
- [ ] Prometheus metrics exporter
- [ ] Grafana dashboard templates
- [ ] Enhanced tag system with priorities
- [ ] Migration dry-run mode
- [ ] Rollback functionality
- [ ] Cluster health scoring
- [ ] Predictive analytics for future imbalances
- [ ] Storage usage monitoring and recommendations
- [ ] Network bandwidth monitoring
- [ ] Customizable notification thresholds

### 📖 Planned Documentation
- [ ] Video installation tutorial
- [ ] Use case examples and scenarios
- [ ] Best practices guide
- [ ] Integration guides (Home Assistant, Zabbix, etc.)
- [ ] API client libraries (Python, Go)
- [ ] Docker deployment option
- [ ] Kubernetes deployment option

---

## Version History Summary

### v1.1.0 Highlights
- **Automated node detection** - No more manual configuration
- **Parallel SSH distribution** - Faster multi-node setup
- **DHCP support** - Automatic IP detection
- **Status checker script** - Comprehensive health monitoring
- **Debug utilities** - Better troubleshooting tools

### v1.0.0 Highlights
- **Initial release** with core functionality
- **Web-based dashboard** for cluster monitoring
- **Smart migration engine** with tag-based rules
- **Automated installer** for easy deployment

---

## Versioning Strategy

ProxBalance follows Semantic Versioning:
- **MAJOR** version for incompatible API changes
- **MINOR** version for new functionality (backwards-compatible)
- **PATCH** version for bug fixes (backwards-compatible)

### Release Schedule

- **Major releases**: When significant architectural changes occur
- **Minor releases**: Monthly (feature additions)
- **Patch releases**: As needed (bug fixes)

---

## Migration Guide

### From v1.0.0 to v1.1.0

No breaking changes. Simply update to the latest version:

```bash
# Pull latest code
pct exec <ctid> -- bash -c "cd /opt/proxmox-balance-manager && git pull"

# Restart services
pct exec <ctid> -- systemctl restart proxmox-balance proxmox-collector.timer

# Verify update
pct exec <ctid> -- cat /opt/proxmox-balance-manager/CHANGELOG.md | head -20
```

### From Manual Installation to Automated Installer

If you previously installed manually and want to use v1.1.0:

1. Backup your configuration:
   ```bash
   pct exec <ctid> -- cp /opt/proxmox-balance-manager/config.json ~/config.backup.json
   ```

2. Note your SSH keys and custom settings

3. Destroy old container:
   ```bash
   pct stop <ctid>
   pct destroy <ctid>
   ```

4. Run new installer:
   ```bash
   bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install.sh)"
   ```

5. Restore custom settings if needed

---

## Testing Checklist for Releases

Before each release, verify:

- [ ] Installer completes successfully on fresh Proxmox install
- [ ] All nodes are detected automatically
- [ ] SSH keys are distributed to all nodes
- [ ] Web interface loads and displays data
- [ ] Migrations execute successfully (both VM and CT)
- [ ] Batch migrations work correctly
- [ ] Tags are recognized and enforced
- [ ] Configuration changes persist across restarts
- [ ] Status checker script works correctly
- [ ] All services start on boot
- [ ] Documentation is up to date
- [ ] No breaking API changes (minor/patch releases)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute to ProxBalance.

### Reporting Bugs

When reporting bugs, please include:
- ProxBalance version
- Proxmox VE version
- Container configuration
- Steps to reproduce
- Output from status checker script
- Relevant log entries

---

## Support

- 🐛 [Report Issues](https://github.com/Pr0zak/ProxBalance/issues)
- 💬 [Discussions](https://github.com/Pr0zak/ProxBalance/discussions)
- ⭐ [Star on GitHub](https://github.com/Pr0zak/ProxBalance)
- 📖 [Documentation](https://github.com/Pr0zak/ProxBalance)

---

[1.1.0]: https://github.com/Pr0zak/ProxBalance/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Pr0zak/ProxBalance/releases/tag/v1.0.0
[Unreleased]: https://github.com/Pr0zak/ProxBalance/compare/v1.1.0...HEAD