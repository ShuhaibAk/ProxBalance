# ProxBalance Troubleshooting Guide

Common issues and solutions for ProxBalance.

---

## 🔍 Quick Diagnostics

Run these commands to check system health:

```bash
# Check all services
pct exec <container-id> -- systemctl status proxmox-balance proxmox-collector.timer nginx

# Test API health
curl http://<container-ip>/api/health

# Check cache file exists and is recent
pct exec <container-id> -- ls -lh /opt/proxmox-balance-manager/cluster_cache.json
pct exec <container-id> -- jq '.collected_at' /opt/proxmox-balance-manager/cluster_cache.json
```

---

## ❌ Installation Issues

### Error: "Container ID already exists"

**Problem:** Container ID is already in use.

**Solution:**
```bash
# Check if container exists
pct status <container-id>

# If you want to remove it
pct stop <container-id>
pct destroy <container-id>

# Re-run installer
./install.sh
```

### Error: "Template not found"

**Problem:** Debian 12 template not available.

**Solution:**
```bash
# Update template list
pveam update

# List available templates
pveam available | grep debian

# Download manually
pveam download local debian-12-standard_12.2-1_amd64.tar.zst

# Re-run installer
./install.sh
```

### Error: Python dependencies fail to install

**Problem:** Network issues or repository problems.

**Solution:**
```bash
# Enter container
pct enter <container-id>

# Update pip
/opt/proxmox-balance-manager/venv/bin/pip install --upgrade pip

# Reinstall dependencies
/opt/proxmox-balance-manager/venv/bin/pip install flask flask-cors gunicorn

# Exit container
exit
```

---

## 🌐 Web Interface Issues

### Error: "502 Bad Gateway"

**Problem:** Flask API service not running.

**Solution:**
```bash
# Check Flask service status
pct exec <container-id> -- systemctl status proxmox-balance

# Check for errors in logs
pct exec <container-id> -- journalctl -u proxmox-balance -n 50

# Restart Flask service
pct exec <container-id> -- systemctl restart proxmox-balance

# Verify it's running
pct exec <container-id> -- systemctl status proxmox-balance
```

### Error: "Connection refused" or page won't load

**Problem:** Nginx not running or misconfigured.

**Solution:**
```bash
# Check nginx status
pct exec <container-id> -- systemctl status nginx

# Test nginx configuration
pct exec <container-id> -- nginx -t

# Check nginx logs
pct exec <container-id> -- tail -f /var/log/nginx/error.log

# Restart nginx
pct exec <container-id> -- systemctl restart nginx
```

### Web interface loads but shows no data

**Problem:** No cached data available yet.

**Solution:**
```bash
# Trigger manual collection
pct exec <container-id> -- systemctl start proxmox-collector.service

# Wait 60 seconds
sleep 60

# Check if cache file exists
pct exec <container-id> -- ls -lh /opt/proxmox-balance-manager/cluster_cache.json

# View cache content
pct exec <container-id> -- jq '.' /opt/proxmox-balance-manager/cluster_cache.json | head -30
```

---

## 📡 Data Collection Issues

### Error: "No cached data available"

**Problem:** Collector hasn't run successfully yet.

**Solution:**
```bash
# Check collector service status
pct exec <container-id> -- systemctl status proxmox-collector.timer

# Check collector logs
pct exec <container-id> -- journalctl -u proxmox-collector -n 50

# Run collector manually
pct exec <container-id> -- /opt/proxmox-balance-manager/venv/bin/python3 /opt/proxmox-balance-manager/collector.py

# Check for errors in output
```

### Error: "SSH connection failed"

**Problem:** SSH keys not configured properly.

**Solution:**
```bash
# Check if SSH key exists in container
pct exec <container-id> -- ls -la /root/.ssh/id_ed25519*

# Test SSH connection to Proxmox host
pct exec <container-id> -- ssh -v root@<proxmox-host-ip> "echo OK"

# If fails, regenerate and distribute key
pct exec <container-id> -- ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q

# Get public key
pct exec <container-id> -- cat /root/.ssh/id_ed25519.pub

# Add to Proxmox host
pct exec <container-id> -- cat /root/.ssh/id_ed25519.pub | ssh root@<proxmox-host-ip> "cat >> /root/.ssh/authorized_keys"

# For other nodes, add manually to each node's /root/.ssh/authorized_keys
```

### Error: "Command failed" in collector logs

**Problem:** pvesh command failing on Proxmox host.

**Solution:**
```bash
# Test pvesh command manually
ssh root@<proxmox-host-ip> "pvesh get /cluster/resources --output-format json"

# Check Proxmox API is responding
ssh root@<proxmox-host-ip> "pvesh get /version"

# Verify user has proper permissions
ssh root@<proxmox-host-ip> "pveum user list"
```

---

## 🔄 Migration Issues

### Migrations not executing

**Problem:** SSH to source node failing.

**Solution:**
```bash
# Test SSH to the source node
pct exec <container-id> -- ssh root@<source-node> "echo OK"

# Verify guest exists on that node
ssh root@<source-node> "pct list" | grep <vmid>
# or for VMs
ssh root@<source-node> "qm list" | grep <vmid>

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
ssh root@<source-node> "pct config <vmid>" | grep lock

# If locked, wait for operation to complete or unlock manually
ssh root@<source-node> "pct unlock <vmid>"
```

### Migration starts but fails mid-transfer

**Problem:** Network issues, insufficient resources, or storage problems.

**Solution:**
```bash
# Check Proxmox task log for specific error
ssh root@<source-node> "cat /var/log/pve/tasks/*"

# Common issues:
# - Not enough disk space on target
# - Network connectivity problems
# - Target node offline
# - Incompatible storage

# Verify target node status
ssh root@<target-node> "uptime"

# Check storage availability
ssh root@<target-node> "df -h"
```

---

## ⚙️ Configuration Issues

### Settings changes not taking effect

**Problem:** Services not restarted after config change.

**Solution:**
```bash
# Restart both services
pct exec <container-id> -- systemctl restart proxmox-balance
pct exec <container-id> -- systemctl restart proxmox-collector.timer

# Verify timer was updated
pct exec <container-id> -- systemctl cat proxmox-collector.timer
```

### Can't change collection interval

**Problem:** Timer file not updating.

**Solution:**
```bash
# Run update script manually
pct exec <container-id> -- /opt/proxmox-balance-manager/venv/bin/python3 /opt/proxmox-balance-manager/update_timer.py

# Check timer file was updated
pct exec <container-id> -- cat /etc/systemd/system/proxmox-collector.timer

# Reload systemd
pct exec <container-id> -- systemctl daemon-reload
pct exec <container-id> -- systemctl restart proxmox-collector.timer
```

---

## 🏷️ Tag Issues

### Tags not being recognized

**Problem:** Tag format incorrect or not saved.

**Solution:**
```bash
# Verify tag format (no spaces, semicolon OR space separated)
pvesh get /nodes/<node>/qemu/<vmid>/config | grep tags

# Correct format examples:
pvesh set /nodes/<node>/qemu/<vmid>/config --tags "ignore"
pvesh set /nodes/<node>/qemu/<vmid>/config --tags "exclude_group1"
pvesh set /nodes/<node>/qemu/<vmid>/config --tags "ignore;exclude_group1"

# Force data refresh
curl -X POST http://<container-ip>/api/refresh
```

### Affinity violations not detected

**Problem:** Tag names don't match or cache not updated.

**Solution:**
```bash
# Verify both guests have matching tags
pvesh get /nodes/<node1>/<type>/<vmid1>/config | grep tags
pvesh get /nodes/<node2>/<type>/<vmid2>/config | grep tags

# Example: Both should have "exclude_firewall" or similar
# Tag must be EXACT match

# Force refresh
pct exec <container-id> -- systemctl start proxmox-collector.service
sleep 60
```

---

## 📊 Performance Issues

### High CPU usage in container

**Problem:** Too frequent collection intervals.

**Solution:**
```bash
# Check current intervals
pct exec <container-id> -- cat /opt/proxmox-balance-manager/config.json

# Increase collection interval
pct exec <container-id> -- /opt/proxmox-balance-manager/manage_settings.sh set-backend 120

# For large clusters (100+ guests), use 120-240 minutes
```

### Slow web interface

**Problem:** UI refresh interval too aggressive or large cluster.

**Solution:**
```bash
# Increase UI refresh interval
pct exec <container-id> -- /opt/proxmox-balance-manager/manage_settings.sh set-ui 30

# For very large clusters, consider:
# - Backend: 120+ minutes
# - UI: 60+ minutes
```

---

## 🔐 Permission Issues

### Error: "Permission denied"

**Problem:** Container doesn't have proper permissions.

**Solution:**
```bash
# Verify container is unprivileged
pct config <container-id> | grep unprivileged

# Check file permissions in container
pct exec <container-id> -- ls -la /opt/proxmox-balance-manager/

# Fix permissions if needed
pct exec <container-id> -- chown -R root:root /opt/proxmox-balance-manager/
pct exec <container-id> -- chmod +x /opt/proxmox-balance-manager/*.py
pct exec <container-id> -- chmod +x /opt/proxmox-balance-manager/*.sh
```

---

## 🧹 Clean Reinstall

If all else fails, clean reinstall:

```bash
# Stop and destroy container
pct stop <container-id>
pct destroy <container-id>

# Remove any leftover SSH keys from Proxmox hosts
# (Optional - check /root/.ssh/authorized_keys on each node)

# Re-run installer
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install.sh)"
```

---

## 📝 Gathering Logs for Support

If you need to open an issue, gather these logs:

```bash
# Create log bundle
pct exec <container-id> -- bash -c "
journalctl -u proxmox-balance -n 100 > /tmp/api.log
journalctl -u proxmox-collector -n 100 > /tmp/collector.log
cat /var/log/nginx/error.log > /tmp/nginx.log
tar -czf /tmp/proxbalance-logs.tar.gz /tmp/*.log
"

# Copy to Proxmox host
pct pull <container-id> /tmp/proxbalance-logs.tar.gz ./proxbalance-logs.tar.gz

# Include in your issue:
# - Proxmox VE version
# - Container config: pct config <container-id>
# - ProxBalance version
# - Log bundle
```

---

## 🆘 Still Having Issues?

- 🐛 [Open an Issue](https://github.com/Pr0zak/ProxBalance/issues)
- 💬 [GitHub Discussions](https://github.com/Pr0zak/ProxBalance/discussions)
- 📖 [Main Documentation](https://github.com/Pr0zak/ProxBalance)

---

## 💡 Common Fixes Summary

| Issue | Quick Fix |
|-------|-----------|
| 502 Bad Gateway | `systemctl restart proxmox-balance` |
| No data showing | `systemctl start proxmox-collector.service` |
| SSH connection fails | Re-add SSH key to authorized_keys |
| Settings not saving | `systemctl restart proxmox-balance proxmox-collector.timer` |
| Migrations failing | Test SSH to source node |
| High CPU usage | Increase collection interval |
| Tags not working | Verify exact tag format |

---

[⬆ Back to README](../README.md)
