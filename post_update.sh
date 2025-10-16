#!/bin/bash
# Post-update script that runs after git pull
# This ensures the new code is used for file operations

set -e

echo "Running post-update tasks..."

# Copy index.html to web root
echo "Updating web interface..."
cp /opt/proxmox-balance-manager/index.html /var/www/html/index.html 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Web interface updated"
else
    echo "⚠ Failed to update web interface"
fi

# Update Python dependencies
echo "Updating Python dependencies..."
if [ -f /opt/proxmox-balance-manager/requirements.txt ]; then
    /opt/proxmox-balance-manager/venv/bin/pip install -q --upgrade -r /opt/proxmox-balance-manager/requirements.txt 2>&1
else
    /opt/proxmox-balance-manager/venv/bin/pip install -q --upgrade flask flask-cors gunicorn requests proxmoxer 2>&1
fi
if [ $? -eq 0 ]; then
    echo "✓ Dependencies updated"
else
    echo "⚠ Dependency update had issues"
fi

# Restart services
echo "Restarting ProxBalance services..."
systemctl restart proxmox-balance 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Restarted API service"
else
    echo "⚠ Failed to restart API service"
fi

systemctl restart proxmox-collector.timer 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Restarted collector timer"
else
    echo "⚠ Failed to restart collector timer"
fi

echo "Post-update tasks complete"
