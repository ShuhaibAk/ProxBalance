# ProxBalance Troubleshooting Guide

Common issues and solutions for ProxBalance.

---

## 🔍 Quick Diagnostics

### Comprehensive Status Check

Run the automated status checker for a complete health report:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/check-status.sh)" _ <container-id>
```

This checks:
- ✅ Container status and IP
- ✅ All service status (API, Collector, Nginx)
- ✅ Data collection status and cache age
- ✅ API health and endpoints
- ✅ SSH connectivity to all cluster nodes
- ✅ Quick action commands

### Service Debugger

For deep service troubleshooting:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/debug-services.sh)" _ <container-id>
```

This verifies:
- ✅ Python virtual environment
- ✅ Application files
- ✅ Service configurations
- ✅ Manual service starts
- ✅ Import checks
- ✅ Syntax validation

### Manual Health Checks

```bash
# Check all services at once
pct exec <ctid> -- systemctl status proxmox-balance proxmox-collector.timer nginx

# Test API health
curl http://<container-ip>/api/health | jq

# Check cache file exists and is recent
pct exec <ctid> -- ls -lh /opt/proxmox-balance-manager/cluster_cache.json
pct exec <ctid> -- jq '.collected_at' /opt/proxmox-balance-manager/cluster_cache.json

# View recent API logs
pct exec <ctid> -- journalctl -u proxmox-balance -n 50

# View recent collector logs
pct exec <ctid> -- journalctl -u proxmox-collector -n 50
```

---

## ❌ Installation Issues

### Error: "Container ID already exists"

**Problem:** Container ID is already in use.

**Solution:**
```bash
# Check if container exists
pct status <ctid>

# If you want to remove it
pct stop <ctid>
pct destroy <ctid>

# Re-run installer (will auto-detect next available ID)
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install.sh)"
```

### Error: "Template not found"

**Problem:** Debian 12 template not available.

**Solution:**
```bash
# Update template list
pveam update

# List available templates
pveam available | grep debian-12

# Download template
pveam download local debian-12-standard_12.2-1_amd64.tar.zst

# Re-run installer
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install.sh)"
```

### Error: Python dependencies fail to install

**Problem:** Network issues or repository problems.

**Solution:**
```bash
# Enter container
pct enter <ctid>

# Update pip
/opt/proxmox-balance-manager/venv/bin/pip install --upgrade pip

# Reinstall dependencies
/opt/proxmox-balance-manager/venv/bin/pip install flask flask-cors gunicorn

# Exit container
exit

# Restart services
pct exec <ctid> -- systemctl restart proxmox-balance
```

### Error: Installer hangs during SSH distribution

**Problem:** Nodes are unreachable or SSH is slow.

**Solution:**
```bash
# The installer has built-in timeouts (10 seconds per node)
# If it hangs, press Ctrl+C and:

# 1. Check network connectivity
ping <node-ip>

# 2. Test SSH manually
ssh root@<node-ip> "echo OK"

# 3. Re-run installer - it will retry
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install.sh)"
```

### Error: DHCP IP not detected

**Problem:** Container didn't receive IP or detection timeout.

**Solution:**
```bash
# Check container network status
pct exec <ctid> -- ip addr show eth0

# If no IP, check DHCP server
# Then restart container networking
pct exec <ctid> -- systemctl restart networking

# Or reconfigure for static IP
pct set <ctid> -net0 name=eth0,bridge=vmbr0,ip=<your-ip>/24,gw=<gateway>
pct reboot <ctid>
```

---

## 🌐 Web Interface Issues

### Error: "502 Bad Gateway"

**Problem:** Flask API service not running.

**Solution:**
```bash
# Run the service debugger
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/debug-services.sh)" _ <ctid>

# Check Flask service status
pct exec <ctid> -- systemctl status proxmox-balance

# Check for errors in logs
pct exec <ctid> -- journalctl -u proxmox-balance -n 50

# Test Python imports
pct exec <ctid> -- /opt/proxmox-balance-manager/venv/bin/python3 -c "import flask; import flask_cors; print('OK')"

# Restart Flask service
pct exec <ctid> -- systemctl restart proxmox-balance

# Verify it's running
pct exec <ctid> -- systemctl is-active proxmox-balance
```

### Error: "Connection refused" or page won't load

**Problem:** Nginx not running or misconfigured.

**Solution:**
```bash
# Check nginx status
pct exec <ctid> -- systemctl status nginx

# Test nginx configuration
pct exec <ctid> -- nginx -t

# Check if nginx is listening
pct exec <ctid> -- netstat -tlnp | grep :80

# Check nginx logs
pct exec <ctid> -- tail -f /var/log/nginx/error.log

# Restart nginx
pct exec <ctid> -- systemctl restart nginx

# Verify site is enabled
pct exec <ctid> -- ls -l /etc/nginx/sites-enabled/
```

### Web interface loads but shows no data

**Problem:** No cached data available yet.

**Solution:**
```bash
# Check if cache file exists
pct exec <ctid> -- ls -lh /opt/proxmox-balance-manager/cluster_cache.json

# If missing, trigger manual collection
pct exec <ctid> -- systemctl start proxmox-collector.service

# Watch collection progress
pct exec <ctid> -- journalctl -u proxmox-collector -f

# Wait 60-90 seconds, then check cache
pct exec <ctid> -- jq '.collected_at' /opt/proxmox-balance-manager/cluster_cache.json

# If still failing, check collector logs for errors
pct exec <ctid> -- journalctl -u proxmox-collector -n 100
```

### Error: "Service temporarily unavailable"

**Problem:** Cache is empty or being collected.

**Solution:**
```bash
# This is normal on first access - wait 2-5 minutes for initial collection
# Check collection status
pct exec <ctid> -- systemctl status proxmox-collector.service

# View timer status
pct exec <ctid> -- systemctl list-timers proxmox-collector.timer

# Force immediate collection
pct exec <ctid> -- systemctl start proxmox-collector.service
sleep 90
curl http://<container-ip>/api/analyze | jq '.success'
```

---

## 📡 Data Collection Issues

### Error: "No cached data available"

**Problem:** Collector hasn't run successfully yet.

**Solution:**
```bash
# Check collector service status
pct exec <ctid> -- systemctl status proxmox-collector.timer

# Check collector logs for errors
pct exec <ctid> -- journalctl -u proxmox-collector -n 50

# Run collector manually to see errors
pct exec <ctid> -- /opt/proxmox-balance-manager/venv/bin/python3 /opt/proxmox-balance-manager/collector.py

# Check for SSH issues
pct exec <ctid> -- ssh root@<proxmox-host> "echo OK"
```

### Error: "SSH connection failed"

**Problem:** SSH keys not configured properly.

**Solution:**
```bash
# Check if SSH key exists in container
pct exec <ctid> -- ls -la /root/.ssh/id_ed25519*

# Test SSH connection to Proxmox host
pct exec <ctid> -- ssh -v root@<proxmox-host-ip> "echo OK"

# If fails, check SSH key on Proxmox host
ssh root@<proxmox-host-ip> "cat /root/.ssh/authorized_keys | grep $(pct exec <ctid> -- cat /root/.ssh/id_ed25519.pub | awk '{print $2}')"

# If missing, regenerate and distribute key
pct exec <ctid> -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q

# Get public key
pct exec <ctid> -- cat /root/.ssh/id_ed25519.pub

# Add to Proxmox host
pct exec <ctid> -- cat /root/.ssh/id_ed25519.pub | ssh root@<proxmox-host-ip> "cat >> /root/.ssh/authorized_keys"

# Test again
pct exec <ctid> -- ssh root@<proxmox-host-ip> "pvesh get /version"
```

### Error: SSH works but collection fails

**Problem:** pvesh command failing on Proxmox host.

**Solution:**
```bash
# Test pvesh command manually from container
pct exec <ctid> -- ssh root@<proxmox-host-ip> "pvesh get /cluster/resources --output-format json"

# Test on Proxmox host directly
ssh root@<proxmox-host-ip> "pvesh get /cluster/resources --output-format json"

# Check Proxmox API is responding
ssh root@<proxmox-host-ip> "pvesh get /version"

# Verify cluster status
ssh root@<proxmox-host-ip> "pvecm status"

# Check for permission issues
ssh root@<proxmox-host-ip> "pveum user list"
```

### Error: "Command failed" in collector logs

**Problem:** Specific pvesh command failing.

**Solution:**
```bash
# View full collector error
pct exec <ctid> -- journalctl -u proxmox-collector -n 100 --no-pager

# Test each command manually
pct exec <ctid> -- bash -c '
ssh root@<proxmox-host> "pvesh get /cluster/resources --output-format json" | jq .
ssh root@<proxmox-host> "pvesh get /nodes --output-format json" | jq .
ssh root@<proxmox-host> "pvesh get /nodes/<node>/rrddata --timeframe hour --output-format json" | jq .
'

# Check for timeouts
# Increase timeout in collector.py if needed:
# nano /opt/proxmox-balance-manager/collector.py
# Find: timeout=30
# Change to: timeout=60
```

---

## 🔄 Migration Issues

### Migrations not executing

**Problem:** SSH to source node failing.

**Solution:**
```bash
# Test SSH to the source node from container
pct exec <ctid> -- ssh root@<source-node> "echo OK"

# Verify guest exists on that node
ssh root@<source-node> "pct list | grep <vmid>"  # for containers
ssh root@<source-node> "qm list | grep <vmid>"   # for VMs

# Check guest status
ssh root@<source-node> "pct status <vmid>"  # for containers
ssh root@<source-node> "qm status <vmid>"   # for VMs

# Check Proxmox task log for migration errors
ssh root@<source-node> "pvesh get /nodes/<source-node>/tasks"
```

### Error: "VM/CT is locked"

**Problem:** Guest is already being migrated or has a lock.

**Solution:**
```bash
# Check guest status
ssh root@<source-node> "pct status <vmid>"
# or for VMs
ssh root@<source-node> "qm status <vmid>"

# Check for locks
ssh root@<source-node> "pct config <vmid> | grep lock"
ssh root@<source-node> "qm config <vmid> | grep lock"

# If locked, check what task is running
ssh root@<source-node> "pvesh get /nodes/<source-node>/tasks | grep <vmid>"

# If safe to do so, unlock manually
ssh root@<source-node> "pct unlock <vmid>"
ssh root@<source-node> "qm unlock <vmid>"

# Then retry migration
```

### Migration starts but fails mid-transfer

**Problem:** Network issues, insufficient resources, or storage problems.

**Solution:**
```bash
# Check Proxmox task log for specific error
ssh root@<source-node> "tail -100 /var/log/pve/tasks/*"

# Common issues to check:

# 1. Not enough disk space on target
ssh root@<target-node> "df -h"

# 2. Network connectivity problems
ping <target-node>
ssh root@<source-node> "ping -c 3 <target-node>"

# 3. Target node offline or degraded
ssh root@<target-node> "uptime"
ssh root@<target-node> "pvecm status"

# 4. Storage compatibility
ssh root@<target-node> "pvesm status"

# 5. Check for resource limits
ssh root@<target-node> "free -h"
ssh root@<target-node> "uptime"
```

### Batch migrations partially failing

**Problem:** Some migrations in batch succeed, others fail.

**Solution:**
```bash
# Check API logs for batch migration details
pct exec <ctid> -- journalctl -u proxmox-balance -n 100 | grep -A 5 "batch"

# Each migration in batch is independent
# Check logs on source node for failed migrations
for vmid in <failed-vmids>; do
  echo "Checking $vmid..."
  ssh root@<source-node> "pvesh get /nodes/<source-node>/tasks | grep $vmid | tail -5"
done

# Check if specific guests have locks or issues
ssh root@<source-node> "pct config <vmid> | grep -E 'lock|status'"

# Retry failed migrations individually through web interface
```

---

## ⚙️ Configuration Issues

### Settings changes not taking effect

**Problem:** Services not restarted after config change.

**Solution:**
```bash
# Always restart services after manual config edits
pct exec <ctid> -- systemctl restart proxmox-balance
pct exec <ctid> -- systemctl restart proxmox-collector.timer

# Verify timer was updated
pct exec <ctid> -- systemctl cat proxmox-collector.timer

# Check config file syntax
pct exec <ctid> -- jq '.' /opt/proxmox-balance-manager/config.json

# If using web interface, settings auto-restart services
# Check if update script ran successfully
pct exec <ctid> -- journalctl -u proxmox-balance -n 20 | grep -i config
```

### Can't change collection interval

**Problem:** Timer file not updating.

**Solution:**
```bash
# Run update script manually
pct exec <ctid> -- /opt/proxmox-balance-manager/venv/bin/python3 /opt/proxmox-balance-manager/update_timer.py

# Check if timer file was updated
pct exec <ctid> -- cat /etc/systemd/system/proxmox-collector.timer

# Reload systemd
pct exec <ctid> -- systemctl daemon-reload

# Restart timer
pct exec <ctid> -- systemctl restart proxmox-collector.timer

# Verify new interval
pct exec <ctid> -- systemctl list-timers proxmox-collector.timer
```

### Configuration file corrupted

**Problem:** Invalid JSON in config.json.

**Solution:**
```bash
# Check for JSON syntax errors
pct exec <ctid> -- jq '.' /opt/proxmox-balance-manager/config.json

# If corrupted, recreate with defaults
pct exec <ctid> -- bash -c 'cat > /opt/proxmox-balance-manager/config.json <<EOF
{
  "collection_interval_minutes": 60,
  "ui_refresh_interval_minutes": 15,
  "proxmox_host": "<your-proxmox-host-ip>"
}
EOF'

# Restart services
pct exec <ctid> -- systemctl restart proxmox-balance proxmox-collector.timer
```

---

## 🏷️ Tag Issues

### Tags not being recognized

**Problem:** Tag format incorrect or not saved.

**Solution:**
```bash
# Verify tag format on guest
pvesh get /nodes/<node>/qemu/<vmid>/config | grep tags

# Correct format examples:
pvesh set /nodes/<node>/qemu/<vmid>/config --tags "ignore"
pvesh set /nodes/<node>/qemu/<vmid>/config --tags "exclude_group1"
pvesh set /nodes/<node>/qemu/<vmid>/config --tags "ignore;exclude_group1"

# Tags should be lowercase, no spaces in tag names
# Use semicolon OR space to separate multiple tags

# Force data refresh after changing tags
curl -X POST http://<container-ip>/api/refresh

# Wait for collection to complete
sleep 90

# Verify tags in cache
pct exec <ctid> -- jq '.guests[] | select(.vmid == <vmid>) | .tags' /opt/proxmox-balance-manager/cluster_cache.json
```

### Affinity violations not detected

**Problem:** Tag names don't match or cache not updated.

**Solution:**
```bash
# Verify both guests have matching exclusion tags
pvesh get /nodes/<node1>/<type>/<vmid1>/config | grep tags
pvesh get /nodes/<node2>/<type>/<vmid2>/config | grep tags

# Example: Both should have "exclude_firewall" (exact match required)
# Tag must be identical on both guests

# Check if violation is shown in web interface
# Navigate to "Tagged Guests & Affinity Rules" section

# Force refresh
curl -X POST http://<container-ip>/api/refresh
sleep 90

# Check cache for violations
pct exec <ctid> -- jq '.guests[] | select(.tags.exclude_groups | length > 0)' /opt/proxmox-balance-manager/cluster_cache.json
```

### Ignore tag not preventing migrations

**Problem:** Tag not properly applied or cache outdated.

**Solution:**
```bash
# Verify ignore tag is set correctly
pvesh get /nodes/<node>/<type>/<vmid>/config | grep tags

# Should show: tags: ignore
# or: tags: ignore;other_tag

# Check if cache recognizes the tag
pct exec <ctid> -- jq '.guests[] | select(.vmid == <vmid>)' /opt/proxmox-balance-manager/cluster_cache.json

# Look for: "has_ignore": true

# If not showing, force cache refresh
pct exec <ctid> -- systemctl start proxmox-collector.service
sleep 90

# Verify in web interface - guest should appear in "Ignored Guests" section
```

---

## 📊 Performance Issues

### High CPU usage in container

**Problem:** Collection intervals too frequent for cluster size.

**Solution:**
```bash
# Check current intervals
pct exec <ctid> -- cat /opt/proxmox-balance-manager/config.json

# For large clusters (100+ guests), increase intervals:
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-backend 120
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-ui 60

# Monitor CPU usage
pct exec <ctid> -- top -b -n 1 | head -20

# Check for stuck processes
pct exec <ctid> -- ps aux | grep -E 'python|gunicorn'
```

### High memory usage

**Problem:** Large cluster generating big cache file.

**Solution:**
```bash
# Check cache file size
pct exec <ctid> -- ls -lh /opt/proxmox-balance-manager/cluster_cache.json

# Check container memory usage
pct exec <ctid> -- free -h

# For very large clusters (200+ guests):
# Increase container memory allocation
pct set <ctid> -memory 4096

# Or reduce data collection frequency
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-backend 240
```

### Slow web interface

**Problem:** UI refresh interval too aggressive or large cluster.

**Solution:**
```bash
# Increase UI refresh interval
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-ui 30

# For very large clusters:
# Backend: 120-240 minutes
# UI: 60-120 minutes

# Check if cache is too large
pct exec <ctid> -- du -h /opt/proxmox-balance-manager/cluster_cache.json

# Clear browser cache
# Hard refresh: Ctrl+F5 or Cmd+Shift+R
```

### Collection takes too long

**Problem:** Many nodes or slow SSH connections.

**Solution:**
```bash
# Check collection time in logs
pct exec <ctid> -- journalctl -u proxmox-collector -n 20 | grep -E 'Starting|complete'

# Test SSH latency to nodes
for node in pve1 pve2 pve3; do
  echo -n "$node: "
  time pct exec <ctid> -- ssh root@$node "echo OK" 2>/dev/null
done

# If SSH is slow, check network issues
# Consider increasing collection interval
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-backend 120
```

---

## 🔐 Permission Issues

### Error: "Permission denied"

**Problem:** Container or file permissions incorrect.

**Solution:**
```bash
# Check if container is unprivileged (recommended)
pct config <ctid> | grep unprivileged

# Check file permissions in container
pct exec <ctid> -- ls -la /opt/proxmox-balance-manager/

# Fix permissions if needed
pct exec <ctid> -- chown -R root:root /opt/proxmox-balance-manager/
pct exec <ctid> -- chmod +x /opt/proxmox-balance-manager/*.py
pct exec <ctid> -- chmod +x /opt/proxmox-balance-manager/*.sh

# Check SSH key permissions
pct exec <ctid> -- chmod 700 /root/.ssh
pct exec <ctid> -- chmod 600 /root/.ssh/id_ed25519
pct exec <ctid> -- chmod 644 /root/.ssh/id_ed25519.pub
```

### Error: Can't write to cache file

**Problem:** Filesystem permissions or disk full.

**Solution:**
```bash
# Check disk space
pct exec <ctid> -- df -h

# Check if directory is writable
pct exec <ctid> -- test -w /opt/proxmox-balance-manager && echo "Writable" || echo "Not writable"

# Check for file locks
pct exec <ctid> -- lsof /opt/proxmox-balance-manager/cluster_cache.json

# Fix ownership if needed
pct exec <ctid> -- chown root:root /opt/proxmox-balance-manager/cluster_cache.json
pct exec <ctid> -- chmod 644 /opt/proxmox-balance-manager/cluster_cache.json
```

---

## 🧹 Clean Reinstall

If all else fails, perform a clean reinstall:

```bash
# 1. Backup configuration (optional)
pct exec <ctid> -- cp /opt/proxmox-balance-manager/config.json ~/config.backup.json

# 2. Stop container
pct stop <ctid>

# 3. Destroy container
pct destroy <ctid>

# 4. Remove SSH keys from Proxmox nodes (optional but recommended)
for node in pve1 pve2 pve3 pve4; do
  ssh root@$node "sed -i '/ProxBalance/d' /root/.ssh/authorized_keys"
done

# 5. Re-run installer
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install.sh)"

# 6. Wait for initial collection
sleep 180

# 7. Run status check
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/check-status.sh)" _ <new-ctid>
```

---

## 📝 Gathering Logs for Support

If you need to open an issue, gather comprehensive logs:

```bash
# Run status checker and save output
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/check-status.sh)" _ <ctid> > status-report.txt 2>&1

# Create log bundle
pct exec <ctid> -- bash -c "
journalctl -u proxmox-balance -n 200 > /tmp/api.log
journalctl -u proxmox-collector -n 200 > /tmp/collector.log
journalctl -u nginx -n 100 > /tmp/nginx-service.log 2>/dev/null || true
cat /var/log/nginx/error.log > /tmp/nginx-error.log 2>/dev/null || true
jq '.' /opt/proxmox-balance-manager/config.json > /tmp/config.log 2>/dev/null || true
tar -czf /tmp/proxbalance-logs.tar.gz /tmp/*.log 2>/dev/null
"

# Copy to Proxmox host
pct pull <ctid> /tmp/proxbalance-logs.tar.gz ./proxbalance-logs.tar.gz

# Include in your issue:
# - Proxmox VE version: pveversion
# - Container config: pct config <ctid>
# - ProxBalance version from CHANGELOG.md
# - Status report: status-report.txt
# - Log bundle: proxbalance-logs.tar.gz
```

---

## 🆘 Still Having Issues?

### Before Opening an Issue

1. ✅ Run the status checker script
2. ✅ Run the debug services script
3. ✅ Check this troubleshooting guide thoroughly
4. ✅ Search existing issues on GitHub
5. ✅ Gather logs using the section above

### Where to Get Help

- 🐛 [Open an Issue](https://github.com/Pr0zak/ProxBalance/issues) with logs and details
- 💬 [GitHub Discussions](https://github.com/Pr0zak/ProxBalance/discussions) for questions
- 📖 [Main Documentation](https://github.com/Pr0zak/ProxBalance) for guides
- 🔧 [Installation Guide](INSTALL.md) for setup help

---

## 💡 Common Fixes Summary

| Issue | Quick Fix |
|-------|-----------|
| 502 Bad Gateway | `systemctl restart proxmox-balance` |
| No data showing | `systemctl start proxmox-collector.service` |
| SSH connection fails | Re-add SSH key to authorized_keys |
| Settings not saving | `systemctl restart proxmox-balance proxmox-collector.timer` |
| Migrations failing | Test SSH to source node and verify guest exists |
| High CPU usage | Increase collection interval to 120+ minutes |
| Tags not working | Verify exact tag format with no spaces |
| Cache file missing | Trigger manual collection and wait 90 seconds |
| Services won't start | Run debug-services.sh script |
| Unknown container IP | Check with status checker script |

---

[⬆ Back to README](../README.md)