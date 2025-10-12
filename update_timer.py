#!/usr/bin/env python3
"""Update systemd timer based on config"""
import json
import subprocess
import sys
import os

CONFIG_FILE = "/opt/proxmox-balance-manager/config.json"
TIMER_FILE = "/etc/systemd/system/proxmox-collector.timer"

try:
    with open(CONFIG_FILE, "r") as f:
        config = json.load(f)
    
    interval_minutes = config.get("collection_interval_minutes", 60)
    
    timer_content = f"""[Unit]
Description=Proxmox Balance Manager Data Collector Timer
Requires=proxmox-collector.service

[Timer]
OnBootSec=1min
OnUnitActiveSec={interval_minutes}min

[Install]
WantedBy=timers.target
"""
    
    with open(TIMER_FILE, "w") as f:
        f.write(timer_content)
    
    # Reload systemd with full path
    systemctl = "/usr/bin/systemctl"
    subprocess.run([systemctl, "daemon-reload"], check=True)
    subprocess.run([systemctl, "restart", "proxmox-collector.timer"], check=True)
    
    print(f"Timer updated: collection every {interval_minutes} minutes")
    sys.exit(0)
    
except Exception as e:
    print(f"Error: {str(e)}", file=sys.stderr)
    import traceback
    traceback.print_exc()
    sys.exit(1)
