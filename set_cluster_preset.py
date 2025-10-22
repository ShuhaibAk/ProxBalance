#!/usr/bin/env python3
"""
Helper script to set cluster size presets for ProxBalance
Automatically configures optimal collection settings based on cluster size
"""

import json
import sys
import os

CONFIG_FILE = "/opt/proxmox-balance-manager/config.json"

# Cluster size presets
PRESETS = {
    "small": {
        "description": "Small cluster (< 30 VMs/CTs)",
        "collection_interval_minutes": 5,
        "collection_optimization": {
            "cluster_size": "small",
            "parallel_collection_enabled": True,
            "max_parallel_workers": 3,
            "skip_stopped_guest_rrd": True,
            "node_rrd_timeframe": "day",
            "guest_rrd_timeframe": "hour"
        }
    },
    "medium": {
        "description": "Medium cluster (30-100 VMs/CTs)",
        "collection_interval_minutes": 15,
        "collection_optimization": {
            "cluster_size": "medium",
            "parallel_collection_enabled": True,
            "max_parallel_workers": 5,
            "skip_stopped_guest_rrd": True,
            "node_rrd_timeframe": "day",
            "guest_rrd_timeframe": "hour"
        }
    },
    "large": {
        "description": "Large cluster (100+ VMs/CTs)",
        "collection_interval_minutes": 30,
        "collection_optimization": {
            "cluster_size": "large",
            "parallel_collection_enabled": True,
            "max_parallel_workers": 8,
            "skip_stopped_guest_rrd": True,
            "node_rrd_timeframe": "hour",
            "guest_rrd_timeframe": "hour"
        }
    },
    "custom": {
        "description": "Custom settings (manual configuration)",
        "collection_interval_minutes": 60,
        "collection_optimization": {
            "cluster_size": "custom",
            "parallel_collection_enabled": True,
            "max_parallel_workers": 5,
            "skip_stopped_guest_rrd": True,
            "node_rrd_timeframe": "day",
            "guest_rrd_timeframe": "hour"
        }
    }
}

def apply_preset(preset_name: str) -> bool:
    """Apply a cluster size preset to config.json"""
    if preset_name not in PRESETS:
        print(f"Error: Unknown preset '{preset_name}'", file=sys.stderr)
        print(f"Available presets: {', '.join(PRESETS.keys())}", file=sys.stderr)
        return False

    try:
        # Load current config
        with open(CONFIG_FILE, 'r') as f:
            config = json.load(f)

        # Apply preset
        preset = PRESETS[preset_name]
        config['collection_interval_minutes'] = preset['collection_interval_minutes']
        config['collection_optimization'] = preset['collection_optimization']

        # Write updated config
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)

        print(f"✓ Applied '{preset_name}' preset")
        print(f"  {preset['description']}")
        print(f"  Collection interval: {preset['collection_interval_minutes']} minutes")
        print(f"  Parallel workers: {preset['collection_optimization']['max_parallel_workers']}")
        print(f"  Node RRD timeframe: {preset['collection_optimization']['node_rrd_timeframe']}")
        print()
        print("Updating collection timer...")

        # Update systemd timer
        import subprocess
        try:
            subprocess.run(['/opt/proxmox-balance-manager/venv/bin/python3',
                          '/opt/proxmox-balance-manager/update_timer.py'],
                          check=True)
            print("✓ Timer updated successfully")
        except subprocess.CalledProcessError as e:
            print(f"Warning: Failed to update timer: {e}", file=sys.stderr)

        return True

    except Exception as e:
        print(f"Error applying preset: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return False

def show_presets():
    """Show available presets"""
    print("Available Cluster Size Presets:")
    print("=" * 70)
    for name, preset in PRESETS.items():
        print(f"\n{name.upper()}")
        print(f"  Description: {preset['description']}")
        print(f"  Collection interval: {preset['collection_interval_minutes']} minutes")
        opt = preset['collection_optimization']
        print(f"  Parallel workers: {opt['max_parallel_workers']}")
        print(f"  Skip stopped RRD: {opt['skip_stopped_guest_rrd']}")
        print(f"  Node timeframe: {opt['node_rrd_timeframe']}")
        print(f"  Guest timeframe: {opt['guest_rrd_timeframe']}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 set_cluster_preset.py <preset>")
        print("       python3 set_cluster_preset.py --list")
        print()
        show_presets()
        sys.exit(1)

    if sys.argv[1] in ['--list', '-l']:
        show_presets()
        sys.exit(0)

    preset_name = sys.argv[1].lower()
    success = apply_preset(preset_name)
    sys.exit(0 if success else 1)
