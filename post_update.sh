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

# Update systemd service files (for new services/timers)
echo "Updating systemd services..."
if [ -d /opt/proxmox-balance-manager/systemd ]; then
    cp /opt/proxmox-balance-manager/systemd/*.service /etc/systemd/system/ 2>&1
    cp /opt/proxmox-balance-manager/systemd/*.timer /etc/systemd/system/ 2>&1
    systemctl daemon-reload 2>&1

    # Enable and start automigrate timer if it exists and isn't already enabled
    if [ -f /etc/systemd/system/proxmox-balance-automigrate.timer ]; then
        if ! systemctl is-enabled proxmox-balance-automigrate.timer >/dev/null 2>&1; then
            echo "  ✓ Enabling automigrate timer..."
            systemctl enable proxmox-balance-automigrate.timer 2>&1
            systemctl start proxmox-balance-automigrate.timer 2>&1
        fi
    fi

    # Enable and start recommendations timer if it exists and isn't already enabled
    if [ -f /etc/systemd/system/proxmox-balance-recommendations.timer ]; then
        if ! systemctl is-enabled proxmox-balance-recommendations.timer >/dev/null 2>&1; then
            echo "  ✓ Enabling recommendations timer..."
            systemctl enable proxmox-balance-recommendations.timer 2>&1
            systemctl start proxmox-balance-recommendations.timer 2>&1
        fi
    fi

    echo "✓ Systemd services updated"
fi

echo "Post-update tasks complete"
