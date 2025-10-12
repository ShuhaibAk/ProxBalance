# Changelog

All notable changes to ProxBalance will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### 📖 Planned Documentation
- [ ] Video installation tutorial
- [ ] Use case examples
- [ ] Best practices guide
- [ ] Integration guides (Home Assistant, etc.)
- [ ] API client libraries

---

## Version History

### Versioning Strategy

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

### From Manual Installation to Automated Installer

If you previously installed manually and want to use the automated installer:

1. Backup your configuration:
   ```bash
   pct exec <container-id> -- cp /opt/proxmox-balance-manager/config.json ~/config.backup.json
   ```

2. Note your SSH keys and settings

3. Destroy old container:
   ```bash
   pct stop <container-id>
   pct destroy <container-id>
   ```

4. Run new installer:
   ```bash
   bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install.sh)"
   ```

5. Restore custom settings if needed

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute to ProxBalance.

---

## Support

- 🐛 [Report Issues](https://github.com/Pr0zak/ProxBalance/issues)
- 💬 [Discussions](https://github.com/Pr0zak/ProxBalance/discussions)
- ⭐ [Star on GitHub](https://github.com/Pr0zak/ProxBalance)

---

[1.0.0]: https://github.com/Pr0zak/ProxBalance/releases/tag/v1.0.0
[Unreleased]: https://github.com/Pr0zak/ProxBalance/compare/v1.0.0...HEAD
