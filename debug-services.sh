#!/usr/bin/env bash

# ProxBalance Service Debugger
# Diagnoses why services aren't starting

CTID="${1:-100}"

echo "=== ProxBalance Service Debugger for Container $CTID ==="
echo ""

# Check if container is running
echo "[1] Container Status"
pct status $CTID
echo ""

# Check if Python venv exists
echo "[2] Python Virtual Environment"
pct exec $CTID -- test -d /opt/proxmox-balance-manager/venv && echo "✓ venv exists" || echo "✗ venv missing"
pct exec $CTID -- test -f /opt/proxmox-balance-manager/venv/bin/gunicorn && echo "✓ gunicorn installed" || echo "✗ gunicorn missing"
pct exec $CTID -- test -f /opt/proxmox-balance-manager/venv/bin/python3 && echo "✓ python3 in venv" || echo "✗ python3 missing"
echo ""

# Check if app files exist
echo "[3] Application Files"
pct exec $CTID -- test -f /opt/proxmox-balance-manager/app.py && echo "✓ app.py exists" || echo "✗ app.py missing"
pct exec $CTID -- test -f /opt/proxmox-balance-manager/collector.py && echo "✓ collector.py exists" || echo "✗ collector.py missing"
pct exec $CTID -- test -f /opt/proxmox-balance-manager/config.json && echo "✓ config.json exists" || echo "✗ config.json missing"
echo ""

# Check service files
echo "[4] Service Files"
pct exec $CTID -- test -f /etc/systemd/system/proxmox-balance.service && echo "✓ API service file exists" || echo "✗ API service file missing"
pct exec $CTID -- test -f /etc/systemd/system/proxmox-collector.service && echo "✓ Collector service file exists" || echo "✗ Collector service file missing"
pct exec $CTID -- test -f /etc/systemd/system/proxmox-collector.timer && echo "✓ Timer file exists" || echo "✗ Timer file missing"
echo ""

# Show service file content
echo "[5] API Service File Content"
pct exec $CTID -- cat /etc/systemd/system/proxmox-balance.service 2>/dev/null || echo "File not found"
echo ""

# Try to start service manually and show output
echo "[6] Manual Service Start Attempt"
pct exec $CTID -- systemctl daemon-reload
echo "Starting proxmox-balance..."
pct exec $CTID -- systemctl start proxmox-balance 2>&1 || true
sleep 2

# Check status
echo ""
echo "[7] Service Status"
pct exec $CTID -- systemctl status proxmox-balance --no-pager -l

echo ""
echo "[8] Recent Logs"
pct exec $CTID -- journalctl -u proxmox-balance -n 30 --no-pager

echo ""
echo "[9] Test Python Import"
pct exec $CTID -- /opt/proxmox-balance-manager/venv/bin/python3 -c "import flask; import flask_cors; print('✓ Flask imports OK')" 2>&1

echo ""
echo "[10] Test App Syntax"
pct exec $CTID -- /opt/proxmox-balance-manager/venv/bin/python3 -m py_compile /opt/proxmox-balance-manager/app.py 2>&1 && echo "✓ app.py syntax OK" || echo "✗ app.py has syntax errors"

echo ""
echo "=== Debug Complete ==="
