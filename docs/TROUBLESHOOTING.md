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
- ✅ Proxmox API token validation and connectivity
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

**Problem:** Network issues, PyPI repository problems, or missing build dependencies.

**Solution:**
```bash
# Enter container
pct enter <ctid>

# Check internet connectivity
ping -c 3 8.8.8.8
curl -I https://pypi.org

# Update pip to latest version
/opt/proxmox-balance-manager/venv/bin/pip install --upgrade pip

# Reinstall dependencies one by one
/opt/proxmox-balance-manager/venv/bin/pip install flask
/opt/proxmox-balance-manager/venv/bin/pip install flask-cors
/opt/proxmox-balance-manager/venv/bin/pip install gunicorn

# Verify installations
/opt/proxmox-balance-manager/venv/bin/pip list | grep -E 'Flask|gunicorn'

# Exit container
exit

# Restart services
pct exec <ctid> -- systemctl restart proxmox-balance
```

**Expected versions:**
- Flask: 3.x
- Flask-CORS: 4.x+
- Gunicorn: 21.x+

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

**Problem:** Flask API service not running or Gunicorn workers crashed.

**Solution:**
```bash
# Run the service debugger
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/debug-services.sh)" _ <ctid>

# Check Flask service status
pct exec <ctid> -- systemctl status proxmox-balance

# Check for errors in logs (look for Python tracebacks)
pct exec <ctid> -- journalctl -u proxmox-balance -n 50

# Test Python imports
pct exec <ctid> -- /opt/proxmox-balance-manager/venv/bin/python3 -c "import flask; import flask_cors; print('OK')"

# Test if app.py has syntax errors
pct exec <ctid> -- /opt/proxmox-balance-manager/venv/bin/python3 -m py_compile /opt/proxmox-balance-manager/app.py

# Check if port 5000 is listening
pct exec <ctid> -- netstat -tlnp | grep :5000

# Restart Flask service
pct exec <ctid> -- systemctl restart proxmox-balance

# Verify it's running
pct exec <ctid> -- systemctl is-active proxmox-balance

# Test API directly on port 5000
pct exec <ctid> -- curl -s http://127.0.0.1:5000/api/health | jq
```

**Common causes:**
1. **Missing config.json** - Service won't start without valid configuration
2. **Python syntax errors** - Check app.py for recent changes
3. **Port already in use** - Another process using port 5000
4. **Virtual environment issues** - venv/bin/python3 not found

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

**Problem:** Collector hasn't run successfully yet or cache file doesn't exist.

**Solution:**
```bash
# Check if cache file exists
pct exec <ctid> -- ls -lh /opt/proxmox-balance-manager/cluster_cache.json

# Check collector service status
pct exec <ctid> -- systemctl status proxmox-collector.timer

# Check when collector last ran
pct exec <ctid> -- systemctl list-timers proxmox-collector.timer

# Check collector logs for errors (look for "CONFIGURATION ERROR" or "RUNTIME ERROR")
pct exec <ctid> -- journalctl -u proxmox-collector -n 50

# Run collector manually to see detailed output
pct exec <ctid> -- /opt/proxmox-balance-manager/venv/bin/python3 /opt/proxmox-balance-manager/collector.py

# Check config.json is valid
pct exec <ctid> -- jq '.' /opt/proxmox-balance-manager/config.json

# Verify proxmox_host is set correctly (not "CHANGE_ME")
pct exec <ctid> -- jq -r '.proxmox_host' /opt/proxmox-balance-manager/config.json

# Check for SSH issues to proxmox_host
pct exec <ctid> -- ssh root@<proxmox-host> "echo OK"

# If SSH works, test pvesh command
pct exec <ctid> -- ssh root@<proxmox-host> "pvesh get /version"
```

**Configuration errors to check:**
1. `proxmox_host` is set to "CHANGE_ME" (must be real IP/hostname)
2. `proxmox_host` is unreachable or wrong value
3. SSH keys not distributed to proxmox_host
4. pvesh command not available on proxmox_host

### Error: "SSH connection failed"

**Problem:** SSH keys not configured properly or permissions incorrect.

**Solution:**
```bash
# Check if SSH key exists in container
pct exec <ctid> -- ls -la /root/.ssh/id_ed25519*

# Expected output:
# -rw------- 1 root root  411 Jan 15 12:00 /root/.ssh/id_ed25519
# -rw-r--r-- 1 root root   95 Jan 15 12:00 /root/.ssh/id_ed25519.pub

# Check SSH key permissions (must be 600 for private key)
pct exec <ctid> -- chmod 700 /root/.ssh
pct exec <ctid> -- chmod 600 /root/.ssh/id_ed25519
pct exec <ctid> -- chmod 644 /root/.ssh/id_ed25519.pub

# Test SSH connection with verbose output
pct exec <ctid> -- ssh -v root@<proxmox-host-ip> "echo OK"

# If fails with "Permission denied (publickey)", check if key is on host
ssh root@<proxmox-host-ip> "grep '$(pct exec <ctid> -- cat /root/.ssh/id_ed25519.pub | awk '{print $2}')' /root/.ssh/authorized_keys"

# If missing, distribute key to proxmox_host
pct exec <ctid> -- cat /root/.ssh/id_ed25519.pub | ssh root@<proxmox-host-ip> "mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys"

# Set proper permissions on Proxmox host
ssh root@<proxmox-host-ip> "chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys"

# Test again with StrictHostKeyChecking disabled
pct exec <ctid> -- ssh -o StrictHostKeyChecking=no root@<proxmox-host-ip> "pvesh get /version"
```

**Common SSH issues:**
1. **Wrong key algorithm** - Should be ed25519, not RSA
2. **Key permissions too open** - Private key must be 600
3. **authorized_keys wrong permissions** - Should be 600 on Proxmox host
4. **Multiple keys with conflicts** - Check for duplicate or conflicting entries
5. **SELinux/AppArmor blocking** - Rare, but check security logs

### Error: SSH works but collection fails

**Problem:** pvesh command failing on Proxmox host or data format unexpected.

**Solution:**
```bash
# Test each pvesh command that collector uses
pct exec <ctid> -- ssh root@<proxmox-host-ip> "pvesh get /cluster/resources --output-format json"

# Test RRD data collection (used for historical metrics)
pct exec <ctid> -- ssh root@<proxmox-host-ip> "pvesh get /nodes/<node-name>/rrddata --timeframe hour --output-format json"

# Test guest config retrieval
pct exec <ctid> -- ssh root@<proxmox-host-ip> "pvesh get /nodes/<node>/qemu/<vmid>/config --output-format json"

# Check if pvesh is available
ssh root@<proxmox-host-ip> "which pvesh"

# Check Proxmox API is responding
ssh root@<proxmox-host-ip> "pvesh get /version"

# Verify cluster status (ensure cluster is healthy)
ssh root@<proxmox-host-ip> "pvecm status"

# Check for API permission issues
ssh root@<proxmox-host-ip> "pveum user list"

# Test if timeout is the issue (default 30 seconds)
# Increase timeout in collector.py if needed:
# Edit line: result = subprocess.run(ssh_cmd, capture_output=True, text=True, timeout=30)
# Change to: timeout=60
```

**Specific pvesh errors:**
1. **"command failed"** - Check collector logs for exact pvesh command that failed
2. **"Connection timeout"** - Increase timeout in collector.py (line 62)
3. **"JSON decode error"** - pvesh returned invalid JSON (rare, but check Proxmox version)
4. **"Permission denied"** - Running as non-root on Proxmox host

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

**Problem:** SSH to source node failing or migration command errors.

**Solution:**
```bash
# Test SSH to the source node from container
pct exec <ctid> -- ssh root@<source-node> "echo OK"

# Verify guest exists on that node
ssh root@<source-node> "pct list | grep <vmid>"  # for containers
ssh root@<source-node> "qm list | grep <vmid>"   # for VMs

# Check guest status (must be running for online migration)
ssh root@<source-node> "pct status <vmid>"  # for containers
ssh root@<source-node> "qm status <vmid>"   # for VMs

# Check if guest is locked
ssh root@<source-node> "pct config <vmid> | grep lock"
ssh root@<source-node> "qm config <vmid> | grep lock"

# Test migration command manually (dry run)
# For VMs:
ssh root@<source-node> "qm migrate <vmid> <target-node> --online"

# For Containers:
ssh root@<source-node> "pct migrate <vmid> <target-node> --restart"

# Check Proxmox task log for migration errors
ssh root@<source-node> "pvesh get /nodes/<source-node>/tasks" | grep <vmid>

# View detailed task log
ssh root@<source-node> "cat /var/log/pve/tasks/*.log" | grep -A 20 "TASK.*<vmid>"
```

**Migration command details (from app.py):**
- **VMs**: `qm migrate <vmid> <target> --online` (line 320)
- **Containers**: `pct migrate <vmid> <target> --restart` (line 320)
- Executed via SSH with `subprocess.Popen` (non-blocking)
- SSH options: StrictHostKeyChecking=no, UserKnownHostsFile=/dev/null, LogLevel=ERROR

**Why migrations might fail:**
1. **Guest not running** - VMs need to be running for --online migration
2. **Insufficient space on target** - Check disk space
3. **Network issues** - Source and target nodes can't communicate
4. **Shared storage not available** - Storage not accessible on target
5. **Guest is locked** - Another operation in progress
6. **SSH key missing on source node** - Container can SSH to proxmox_host but not source node

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

**Problem:** Services not restarted after config change or update_timer.py failed.

**Solution:**
```bash
# Check config file syntax
pct exec <ctid> -- jq '.' /opt/proxmox-balance-manager/config.json

# If using web interface, check API logs for errors
pct exec <ctid> -- journalctl -u proxmox-balance -n 50 | grep -i config

# Manually run update_timer.py to update systemd timer
pct exec <ctid> -- /opt/proxmox-balance-manager/venv/bin/python3 /opt/proxmox-balance-manager/update_timer.py

# Verify timer file was updated with new interval
pct exec <ctid> -- cat /etc/systemd/system/proxmox-collector.timer

# Expected output should show:
# OnUnitActiveSec=<your-interval>min

# Reload systemd daemon
pct exec <ctid> -- systemctl daemon-reload

# Restart services
pct exec <ctid> -- systemctl restart proxmox-balance
pct exec <ctid> -- systemctl restart proxmox-collector.timer

# Verify new interval is active
pct exec <ctid> -- systemctl list-timers proxmox-collector.timer

# Check when next collection will run
pct exec <ctid> -- systemctl status proxmox-collector.timer
```

**What update_timer.py does:**
1. Reads `collection_interval_minutes` from config.json
2. Generates new timer file content
3. Writes to /etc/systemd/system/proxmox-collector.timer
4. Runs `systemctl daemon-reload`
5. Restarts proxmox-collector.timer

**If update_timer.py fails:**
- Check Python syntax: `python3 -m py_compile update_timer.py`
- Check permissions: Timer file must be writable by root
- Check systemctl path: Should be /usr/bin/systemctl

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

## 🤖 AI Recommendations Issues

### AI recommendations not appearing

**Problem:** AI features enabled but no recommendations showing.

**Solutions:**
```bash
# 1. Verify AI is enabled in config
pct exec <ctid> -- jq '.ai_enabled' /opt/proxmox-balance-manager/config.json
# Should return: true

# 2. Check AI provider is configured
pct exec <ctid> -- jq '.ai_provider, .ai_api_key' /opt/proxmox-balance-manager/config.json

# 3. Check API logs for AI errors
pct exec <ctid> -- journalctl -u proxmox-balance -n 100 | grep -i "ai\|anthropic\|openai\|ollama"

# 4. Test AI API connectivity manually
# For OpenAI:
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"

# For Anthropic:
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: YOUR_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"test"}]}'

# For Ollama:
curl http://<ollama-host>:11434/api/version
```

**Common Causes:**
- Invalid or expired API key
- Network connectivity issues
- Ollama service not running
- Insufficient API credits (OpenAI/Anthropic)
- Model name incorrect or not available

### Error: "AI API request failed"

**Problem:** AI provider returns errors.

**OpenAI Errors:**
```bash
# Error: 401 Unauthorized
# - Check API key is correct
# - Verify key hasn't been revoked at https://platform.openai.com/api-keys

# Error: 429 Rate Limit Exceeded
# - Reduce analysis frequency
# - Upgrade API plan
# - Wait and retry

# Error: 500 Internal Server Error
# - OpenAI service issue
# - Try again later
# - Switch to different provider temporarily
```

**Anthropic Errors:**
```bash
# Error: 401 authentication_error
# - Check API key format
# - Verify key at https://console.anthropic.com/settings/keys

# Error: 429 rate_limit_error
# - Reduce request frequency
# - Check usage limits

# Error: 529 overloaded_error
# - Anthropic service overloaded
# - Retry with exponential backoff
```

**Ollama Errors:**
```bash
# Error: Connection refused
# Ollama service not running

# Check Ollama status
ssh <ollama-host> systemctl status ollama

# Start Ollama
ssh <ollama-host> systemctl start ollama

# Error: Model not found
# Pull the model

ssh <ollama-host> ollama pull llama3.1:8b

# List available models
ssh <ollama-host> ollama list

# Error: Out of memory
# Model too large for available RAM
# - Use smaller model (llama3.1:8b instead of :70b)
# - Increase system RAM
# - Use quantized models (fewer bits)
```

### Ollama connection issues

**Problem:** Can't connect to Ollama from ProxBalance container.

**Solutions:**
```bash
# 1. Verify Ollama is accessible from container
pct exec <ctid> -- curl http://<ollama-host>:11434/api/version

# 2. Check firewall on Ollama host
# On Ollama host:
ufw status
# If blocking, allow ProxBalance container IP:
ufw allow from <container-ip> to any port 11434

# 3. Verify Ollama is listening on all interfaces
# On Ollama host, check:
ss -tlnp | grep 11434
# Should show 0.0.0.0:11434 or *:11434

# If only listening on 127.0.0.1, edit systemd service:
# /etc/systemd/system/ollama.service
# Add: Environment="OLLAMA_HOST=0.0.0.0:11434"
systemctl daemon-reload
systemctl restart ollama

# 4. Test model inference
ssh <ollama-host> 'ollama run llama3.1:8b "test"'
```

### AI recommendations are irrelevant or poor quality

**Problem:** AI suggests migrations that don't make sense.

**Solutions:**

1. **Adjust analysis time period:**
   - Short period (1h) = only recent trends, may miss patterns
   - Long period (7d) = comprehensive but may include old data
   - Recommended: 24h for most clusters

2. **Ensure sufficient historical data:**
   ```bash
   # Check RRD data availability in cache
   pct exec <ctid> -- jq '.nodes | .[].trend_data | length' /opt/proxmox-balance-manager/cluster_cache.json

   # Should show many data points (varies by period)
   # If low, wait for more data collection cycles
   ```

3. **Try different AI model:**
   - GPT-4: Most accurate, highest cost
   - Claude 3.5 Sonnet: Balanced accuracy/cost
   - GPT-3.5: Faster, lower cost, less accurate
   - Ollama llama3.1:70b: Best local model (if hardware allows)
   - Ollama llama3.1:8b: Faster local model, less accurate

4. **Review AI reasoning:**
   - AI recommendations include detailed reasoning
   - Read the explanation to understand why migration was suggested
   - May reveal insights about your cluster patterns

### AI recommendations include non-existent nodes

**Problem:** AI hallucinates node names or recommends migrations to nodes that don't exist.

**Solution:**

This should be prevented by the smart filtering feature in v2.0, but if it occurs:

```bash
# 1. Verify current filtering is working
pct exec <ctid> -- journalctl -u proxmox-balance -n 200 | grep "Filtered out"

# Should show lines like:
# "Filtered out 2 AI recommendations (hallucinated nodes or self-migrations)"

# 2. Check if issue persists after filtering
# View AI recommendations in web UI
# Any with target_node not in your cluster = bug, please report

# 3. Temporarily disable AI
# In Settings, toggle off "Enable AI Recommendations"
# Use traditional recommendations until issue resolved

# 4. Report the issue
# Open GitHub issue with:
# - AI provider and model used
# - Cluster configuration (node names)
# - Example of bad recommendation
```

**Note:** v2.0+ includes validation that:
- Filters recommendations where source == target
- Filters recommendations with target nodes not in cluster
- Prevents self-migrations
- Reports filtering statistics in logs

---

## 🏷️ Tag Issues

### Tags not being recognized

**Problem:** Tag format incorrect, not saved, or cache not refreshed.

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

# Verify tags in cache (check all three fields)
pct exec <ctid> -- jq '.guests[] | select(.vmid == <vmid>) | .tags' /opt/proxmox-balance-manager/cluster_cache.json

# Expected output:
# {
#   "has_ignore": true,           // true if "ignore" tag present
#   "exclude_groups": [           // array of exclude_* tags
#     "exclude_firewall"
#   ],
#   "all_tags": [                 // all tags as array
#     "ignore",
#     "exclude_firewall"
#   ]
# }
```

**How collector.py parses tags:**
1. Reads tags string from guest config via pvesh
2. Splits by semicolon (`;`) and space
3. Checks if "ignore" is in list → sets `has_ignore: true`
4. Extracts tags starting with "exclude_" → adds to `exclude_groups` array
5. Stores all tags in `all_tags` array

**Common tag mistakes:**
1. **Capital letters** - Use lowercase: "Ignore" won't work, use "ignore"
2. **Spaces in tag names** - "exclude firewall" won't work, use "exclude_firewall"
3. **Wrong separator** - Use `;` or space, not comma
4. **Typos in exclude prefix** - "exlude_firewall" won't work, must start with "exclude_"
5. **Cache not refreshed** - Always trigger refresh after tag changes

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

**Problem:** Collection intervals too frequent for cluster size or stuck processes.

**Solution:**
```bash
# Check current intervals
pct exec <ctid> -- cat /opt/proxmox-balance-manager/config.json

# Monitor CPU usage in real-time
pct exec <ctid> -- top -b -n 1 | head -20

# Check for stuck or zombie processes
pct exec <ctid> -- ps aux | grep -E 'python|gunicorn'

# Look for multiple collector processes (should only be 1 when running)
pct exec <ctid> -- ps aux | grep collector.py

# Check Gunicorn worker count (default is 4)
pct exec <ctid> -- ps aux | grep gunicorn | wc -l

# For large clusters (100+ guests), increase intervals:
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-backend 120
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-ui 60

# Check if collector is hanging (timeout issue)
pct exec <ctid> -- journalctl -u proxmox-collector -n 100 | grep -i timeout

# Check how long collections are taking
pct exec <ctid> -- journalctl -u proxmox-collector -n 50 | grep -E "Starting|complete"
```

**Expected CPU usage:**
- **Idle**: <5% CPU, ~200MB RAM
- **During collection**: 10-20% CPU spike for 30-90 seconds
- **API requests**: <5% CPU per request
- **Gunicorn workers**: 4 processes, each <50MB RAM

**If CPU consistently high:**
1. **Increase collection interval** - Reduce frequency of data gathering
2. **Reduce Gunicorn workers** - Edit proxmox-balance.service, change `-w 4` to `-w 2`
3. **Check for infinite loops** - Look for collector running continuously
4. **Optimize cluster size** - Larger clusters need longer intervals

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

**Problem:** Many nodes, large cluster, or slow SSH connections.

**Solution:**
```bash
# Check collection time in logs (look for start and complete timestamps)
pct exec <ctid> -- journalctl -u proxmox-collector -n 20 | grep -E 'Starting|complete'

# Example output:
# Jan 15 10:00:00 Starting cluster data collection...
# Jan 15 10:01:30 Data collection complete. Cache updated.
# (90 seconds is normal for large clusters)

# Test SSH latency to proxmox_host
time pct exec <ctid> -- ssh root@<proxmox-host> "echo OK"

# Test pvesh response time
time pct exec <ctid> -- ssh root@<proxmox-host> "pvesh get /cluster/resources --output-format json" > /dev/null

# Test RRD data retrieval time (slowest operation)
time pct exec <ctid> -- ssh root@<proxmox-host> "pvesh get /nodes/<node>/rrddata --timeframe hour --output-format json" > /dev/null

# Check network latency from container to host
pct exec <ctid> -- ping -c 10 <proxmox-host>

# If SSH is slow, check network issues
# Consider increasing collection interval
pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-backend 120

# Monitor a live collection
pct exec <ctid> -- systemctl start proxmox-collector.service && \
pct exec <ctid> -- journalctl -u proxmox-collector -f
```

**Collection time breakdown:**
1. **SSH connection** - 1-2 seconds per command
2. **Get cluster resources** - 2-5 seconds (all VMs/CTs)
3. **Get RRD data per node** - 3-10 seconds per node (historical metrics)
4. **Get guest configs** - 0.5-1 second per guest (for tags)
5. **Write cache file** - <1 second (atomic rename)

**Expected collection times:**
- **Small cluster (1-20 guests, 2-3 nodes)**: 30-60 seconds
- **Medium cluster (21-50 guests, 3-4 nodes)**: 60-120 seconds
- **Large cluster (50-100 guests, 4+ nodes)**: 120-180 seconds
- **Very large (100+ guests, 5+ nodes)**: 180-300 seconds

**If collection takes >5 minutes:**
1. Check if timeout is occurring (default 30 sec per SSH command)
2. Increase timeout in collector.py line 62: `timeout=60`
3. Check network latency and bandwidth
4. Consider running collector less frequently

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

| Issue | Quick Fix | Command |
|-------|-----------|---------|
| 502 Bad Gateway | Restart Flask API | `pct exec <ctid> -- systemctl restart proxmox-balance` |
| No data showing | Run collector manually | `pct exec <ctid> -- systemctl start proxmox-collector.service` |
| SSH connection fails | Check and fix SSH keys | `pct exec <ctid> -- ssh root@<proxmox-host> "echo OK"` |
| Settings not saving | Run update_timer.py | `pct exec <ctid> -- /opt/proxmox-balance-manager/venv/bin/python3 /opt/proxmox-balance-manager/update_timer.py` |
| Migrations failing | Test migration command | `ssh root@<source-node> "qm migrate <vmid> <target> --online"` |
| High CPU usage | Increase intervals | `pct exec <ctid> -- /opt/proxmox-balance-manager/manage_settings.sh set-backend 120` |
| Tags not working | Force cache refresh | `curl -X POST http://<container-ip>/api/refresh` |
| Cache file missing | Check config.json | `pct exec <ctid> -- jq -r '.proxmox_host' /opt/proxmox-balance-manager/config.json` |
| Services won't start | Check Python syntax | `pct exec <ctid> -- /opt/proxmox-balance-manager/venv/bin/python3 -m py_compile /opt/proxmox-balance-manager/app.py` |
| Unknown container IP | Use status checker | `bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/check-status.sh)" _ <ctid>` |
| Collection timeout | Increase timeout | Edit collector.py line 62: `timeout=60` |
| Invalid config.json | Validate JSON syntax | `pct exec <ctid> -- jq '.' /opt/proxmox-balance-manager/config.json` |

---

[⬆ Back to README](../README.md)