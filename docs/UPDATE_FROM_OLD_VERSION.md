# Updating from Older Versions

If you're running an older version of ProxBalance, follow these instructions to safely update.

## Method 1: Web UI Update (Easiest)

Simply use the built-in update feature:

1. Open your ProxBalance web interface
2. Click **"System"** in the navigation
3. Click **"Update ProxBalance"**
4. The update will run automatically

**Note:** If you see warnings like "Build failed with exit code -15" or timeout messages, these are cosmetic. The update will still complete successfully. Once updated, future updates will be clean with no warnings.

## Method 2: Command Line Update (Recommended for Proxmox Hosts)

If ProxBalance is running in a Proxmox container (CT), run this from your **Proxmox host**:

```bash
# Replace with your container ID
CTID=<container-id>

pct exec $CTID -- bash -c '
cd /opt/proxmox-balance-manager &&
git fetch origin main &&
git pull origin main &&
bash post_update.sh &&
systemctl restart proxmox-balance
'
```

Verify the update:
```bash
pct exec $CTID -- bash -c 'cd /opt/proxmox-balance-manager && git log --oneline -1'
```

## Method 3: Manual Update (Direct SSH Access)

If you have SSH access directly to the ProxBalance server:

```bash
# SSH into your ProxBalance server
ssh root@<proxbalance-server>

# Navigate to installation directory
cd /opt/proxmox-balance-manager

# Pull latest changes
git fetch origin main
git pull origin main

# Run post-update tasks
bash post_update.sh

# Restart services
systemctl restart proxmox-balance

# Verify
git log --oneline -1
systemctl status proxmox-balance
```

## What Branch Should I Use?

- **main**: Stable releases (recommended for production)
- **dev**: Latest features and fixes (may be less stable)

To switch branches:
```bash
cd /opt/proxmox-balance-manager
git fetch origin
git checkout main  # or 'dev' for development branch
git pull origin main  # or 'dev'
bash post_update.sh
systemctl restart proxmox-balance
```

## Troubleshooting

### "Build failed with exit code -15"

This is a known cosmetic error in older versions. The update still completes successfully. After updating once, this error will no longer appear.

### Services Not Restarting

Manually restart the services:
```bash
systemctl restart proxmox-balance
systemctl restart proxmox-collector.timer
systemctl restart nginx
```

### Web Interface Not Loading

Check service status:
```bash
systemctl status proxmox-balance
systemctl status nginx
```

If services are stopped, start them:
```bash
systemctl start proxmox-balance
systemctl start nginx
```

### Check Logs

View recent logs:
```bash
journalctl -u proxmox-balance -n 50
```

### Verify Installation

Confirm everything is working:
```bash
# Check current version
cd /opt/proxmox-balance-manager && git log --oneline -1

# Check services
systemctl is-active proxmox-balance nginx proxmox-collector.timer

# Test web interface
curl -s http://localhost/ | grep -q "ProxBalance" && echo "✓ Web UI working"
```

## Need Help?

- Documentation: https://github.com/Pr0zak/ProxBalance
- Report issues: https://github.com/Pr0zak/ProxBalance/issues
