# ProxBalance Documentation

Complete documentation for ProxBalance - Automated cluster load balancing for Proxmox VE.

---

## 📚 Table of Contents

### Getting Started

- **[Installation Guide](INSTALL.md)** - Complete installation instructions
  - Quick install (one command)
  - Manual installation steps
  - Post-installation configuration
  - AI provider setup
  - Security hardening

- **[Quick Start](../README.md#-quick-start)** - Get up and running in 5 minutes
  - Prerequisites
  - One-command installation
  - Initial configuration

### Core Documentation

- **[Main README](../README.md)** - Project overview and quick reference
  - Features overview
  - Architecture diagram
  - API endpoints
  - Basic usage

- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Solutions to common issues
  - Installation problems
  - Service issues
  - Data collection problems
  - Migration issues
  - AI recommendations troubleshooting

### Advanced Features

- **[AI Features Guide](AI_FEATURES.md)** - AI-powered migration recommendations
  - AI provider setup (OpenAI, Anthropic, Ollama)
  - Configuration options
  - Analysis time periods
  - API usage
  - Best practices

- **[AI Quick Setup](AI_INSTALL.md)** - Fast AI configuration guide
  - Quick setup for each provider
  - Common configurations
  - Testing AI connectivity

### Development

- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute to ProxBalance
  - Code of conduct
  - Development setup
  - Pull request process
  - Coding standards

- **[Docker Development](DOCKER_DEV.md)** - Local development environment
  - Docker setup for testing
  - Development workflow
  - Testing procedures

---

## 🔍 Quick Navigation by Topic

### Installation & Setup
- [Quick Install](INSTALL.md#-quick-install-recommended)
- [Manual Installation](INSTALL.md#-manual-installation)
- [Post-Installation](INSTALL.md#-post-installation-configuration)
- [AI Setup](AI_INSTALL.md)

### Configuration
- [Basic Configuration](INSTALL.md#-post-installation-configuration)
- [AI Configuration](AI_FEATURES.md#configuration)
- [Collection Intervals](INSTALL.md#2-configure-collection-intervals)
- [Guest Tags](INSTALL.md#3-configure-guest-tags)

### Usage
- [API Endpoints](../README.md#api-endpoints)
- [Tagging Guests](../README.md#tagging-guests)
- [Migration Execution](../README.md#usage)

### Troubleshooting
- [Installation Issues](TROUBLESHOOTING.md#-installation-issues)
- [Web Interface Issues](TROUBLESHOOTING.md#-web-interface-issues)
- [Data Collection Issues](TROUBLESHOOTING.md#-data-collection-issues)
- [Migration Issues](TROUBLESHOOTING.md#-migration-issues)
- [AI Issues](TROUBLESHOOTING.md#-ai-recommendations-issues)

### AI Features
- [AI Overview](AI_FEATURES.md#overview)
- [Supported Providers](AI_FEATURES.md#ai-providers)
- [Configuration](AI_FEATURES.md#configuration)
- [API Usage](AI_FEATURES.md#api-usage)
- [Troubleshooting AI](AI_FEATURES.md#troubleshooting)

---

## 📖 Documentation by User Type

### For First-Time Users

1. Start with the [Main README](../README.md) for an overview
2. Follow the [Quick Install Guide](INSTALL.md#-quick-install-recommended)
3. Review [Post-Installation Configuration](INSTALL.md#-post-installation-configuration)
4. Learn about [Tagging Guests](../README.md#tagging-guests)

### For Administrators

1. [Installation Guide](INSTALL.md) - Full installation details
2. [Configuration Options](../README.md#-configuration) - Advanced settings
3. [API Endpoints](../README.md#api-endpoints) - Automation and scripting
4. [Troubleshooting Guide](TROUBLESHOOTING.md) - Common issues

### For Advanced Users

1. [AI Features Guide](AI_FEATURES.md) - AI-powered recommendations
2. [Architecture](../README.md#-architecture) - System design
3. [Contributing Guide](CONTRIBUTING.md) - Development setup
4. [Docker Development](DOCKER_DEV.md) - Local testing

---

## 🆘 Getting Help

### Quick Diagnostics

```bash
# Run comprehensive status check
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/check-status.sh)" _ <container-id>
```

### Support Resources

- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **GitHub Issues**: [Report a bug](https://github.com/Pr0zak/ProxBalance/issues)
- **GitHub Discussions**: [Ask questions](https://github.com/Pr0zak/ProxBalance/discussions)
- **Documentation Issues**: [Suggest improvements](https://github.com/Pr0zak/ProxBalance/issues/new)

---

## 📝 Documentation Structure

```
docs/
├── README.md                # This file - Documentation index
├── INSTALL.md              # Complete installation guide
├── TROUBLESHOOTING.md      # Problem-solving guide
├── AI_FEATURES.md          # AI recommendations documentation
├── AI_INSTALL.md           # Quick AI setup guide
├── CONTRIBUTING.md         # Contribution guidelines
├── DOCKER_DEV.md           # Development environment setup
└── images/                 # Screenshots and diagrams
    ├── dashboard.png
    ├── node-status.png
    ├── recommendations.png
    ├── settings.png
    └── tagged-guests.png
```

---

## 🔄 Documentation Updates

This documentation is for **ProxBalance v2.0** which includes:

- AI-powered migration recommendations
- Enhanced installer with visual progress
- Improved web UI with collapsible sections
- API-only authentication (no SSH)
- Configurable analysis time periods

For version history, see the [Main README](../README.md#-version-history).

---

## 🤝 Contributing to Documentation

Found a typo or want to improve the docs?

1. Fork the repository
2. Make your changes
3. Submit a pull request
4. See [CONTRIBUTING.md](CONTRIBUTING.md) for details

Documentation improvements are always welcome!

---

[⬆ Back to Main README](../README.md)
