#!/usr/bin/env python3
"""
Proxmox Balance Manager - Flask API (with caching)
Reads from cache file for fast responses
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import subprocess
import json
import os
import sys
from datetime import datetime
from typing import Dict, List

app = Flask(__name__)
CORS(app)

CACHE_FILE = '/opt/proxmox-balance-manager/cluster_cache.json'
CONFIG_FILE = '/opt/proxmox-balance-manager/config.json'
SSH_OPTS = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "LogLevel=ERROR"]

def load_config():
    """Load configuration from config.json"""
    if not os.path.exists(CONFIG_FILE):
        return {
            "error": True,
            "message": f"Configuration file not found: {CONFIG_FILE}"
        }
    
    try:
        with open(CONFIG_FILE, 'r') as f:
            config = json.load(f)
    except json.JSONDecodeError as e:
        return {
            "error": True,
            "message": f"Invalid JSON in configuration file: {e}"
        }
    except Exception as e:
        return {
            "error": True,
            "message": f"Error reading configuration file: {e}"
        }
    
    if not config.get('proxmox_host'):
        return {
            "error": True,
            "message": "Missing 'proxmox_host' in configuration file"
        }
    
    if config.get('proxmox_host') == "CHANGE_ME":
        return {
            "error": True,
            "message": "Configuration not completed: proxmox_host is set to 'CHANGE_ME'"
        }
    
    return config

def read_cache() -> Dict:
    """Read cluster data from cache file"""
    try:
        if not os.path.exists(CACHE_FILE):
            return None
        
        with open(CACHE_FILE, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error reading cache: {str(e)}")
        return None

def trigger_collection():
    """Trigger background collection process"""
    try:
        subprocess.Popen([
            '/opt/proxmox-balance-manager/venv/bin/python3',
            '/opt/proxmox-balance-manager/collector.py'
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception as e:
        print(f"Error triggering collection: {str(e)}")
        return False


@app.route("/api/health", methods=["GET"])
def health_check():
    """Health check endpoint"""
    cache_data = read_cache()
    config = load_config()
    
    health_status = {
        "status": "healthy", 
        "timestamp": datetime.now().isoformat(),
        "cache_available": cache_data is not None,
        "cache_age": cache_data.get('collected_at') if cache_data else None
    }
    
    if config.get('error'):
        health_status["status"] = "configuration_error"
        health_status["config_error"] = config.get('message')
        return jsonify(health_status), 500
    
    return jsonify(health_status)


@app.route("/api/analyze", methods=["GET"])
def analyze_cluster():
    """Return cached cluster data"""
    try:
        # Check configuration first
        config = load_config()
        if config.get('error'):
            return jsonify({
                "success": False,
                "error": f"Configuration Error: {config.get('message')}\n\n"
                        f"Please edit {CONFIG_FILE} and set the proxmox_host value."
            }), 500
        
        data = read_cache()
        
        if data is None:
            trigger_collection()
            return jsonify({
                "success": False, 
                "error": "No cached data available. Collection in progress, please wait 30-60 seconds and refresh."
            }), 503
        
        return jsonify({"success": True, "data": data})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/refresh", methods=["POST"])
def refresh_data():
    """Trigger immediate data collection"""
    try:
        # Check configuration first
        config = load_config()
        if config.get('error'):
            return jsonify({
                "success": False,
                "error": f"Configuration Error: {config.get('message')}"
            }), 500
        
        trigger_collection()
        return jsonify({
            "success": True,
            "message": "Data collection triggered. Results will be available in 30-60 seconds."
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/recommendations", methods=["POST"])
def get_recommendations():
    """Generate recommendations from cached data"""
    try:
        data = request.json or {}
        cpu_threshold = float(data.get("cpu_threshold", 60.0))
        mem_threshold = float(data.get("mem_threshold", 70.0))
        
        cache_data = read_cache()
        if not cache_data:
            return jsonify({"success": False, "error": "No data available"}), 503
        
        try:
            recommendations = generate_recommendations(
                cache_data.get('nodes', {}),
                cache_data.get('guests', {}),
                cpu_threshold,
                mem_threshold
            )
        except Exception as e:
            print(f"Error in generate_recommendations: {str(e)}", file=sys.stderr)
            import traceback
            traceback.print_exc()
            return jsonify({"success": False, "error": f"Recommendation error: {str(e)}"}), 500
        
        return jsonify({
            "success": True,
            "recommendations": recommendations,
            "count": len(recommendations)
        })
    except Exception as e:
        print(f"Error in get_recommendations: {str(e)}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500


def generate_recommendations(nodes: Dict, guests: Dict, cpu_threshold: float, mem_threshold: float) -> List[Dict]:
    """Generate migration recommendations"""
    recommendations = []
    
    overloaded = []
    for node_name, node in nodes.items():
        try:
            metrics = node.get("metrics", {})
            cpu_check = metrics.get("avg_cpu", 0) if metrics.get("has_historical") else metrics.get("current_cpu", 0)
            mem_check = metrics.get("avg_mem", 0) if metrics.get("has_historical") else metrics.get("current_mem", 0)
            
            if cpu_check > cpu_threshold or mem_check > mem_threshold:
                overloaded.append({
                    "node": node_name,
                    "cpu": cpu_check,
                    "mem": mem_check,
                    "reason": "cpu" if cpu_check > cpu_threshold else "mem"
                })
        except Exception as e:
            print(f"Error processing node {node_name}: {str(e)}", file=sys.stderr)
            import traceback
            traceback.print_exc()
            continue
    
    for overload in overloaded:
        src_node = overload["node"]
        
        best_target = None
        best_score = 999999
        
        for tgt_name, tgt_node in nodes.items():
            try:
                if tgt_name == src_node or tgt_node.get("status") != "online":
                    continue
                
                tgt_metrics = tgt_node.get("metrics", {})
                tgt_cpu = tgt_metrics.get("avg_cpu", 0) if tgt_metrics.get("has_historical") else tgt_metrics.get("current_cpu", 0)
                tgt_mem = tgt_metrics.get("avg_mem", 0) if tgt_metrics.get("has_historical") else tgt_metrics.get("current_mem", 0)
                
                score = tgt_cpu + tgt_mem
                
                if score < best_score and tgt_cpu < 50 and tgt_mem < 60:
                    best_score = score
                    best_target = tgt_name
            except Exception as e:
                print(f"Error evaluating target node {tgt_name}: {str(e)}", file=sys.stderr)
                import traceback
                traceback.print_exc()
                continue
        
        if best_target:
            candidates = []
            for vmid in nodes[src_node].get("guests", []):
                try:
                    vmid_key = str(vmid) if str(vmid) in guests else vmid
                    
                    if vmid_key not in guests:
                        print(f"Warning: Guest {vmid} not found in guests dict", file=sys.stderr)
                        continue
                    
                    guest = guests[vmid_key]
                    if guest.get("status") == "running" and not guest.get("tags", {}).get("has_ignore", False):
                        candidates.append((vmid_key, guest.get("mem_max_gb", 0)))
                except Exception as e:
                    print(f"Error processing guest {vmid}: {str(e)}", file=sys.stderr)
                    import traceback
                    traceback.print_exc()
                    continue
            
            candidates.sort(key=lambda x: x[1])
            
            for vmid_key, _ in candidates[:3]:
                try:
                    guest = guests[vmid_key]
                    
                    conflict = False
                    if guest.get("tags", {}).get("exclude_groups", []):
                        for other_vmid in nodes[best_target].get("guests", []):
                            other_key = str(other_vmid) if str(other_vmid) in guests else other_vmid
                            if other_key not in guests:
                                continue
                            other = guests[other_key]
                            for excl_group in guest["tags"]["exclude_groups"]:
                                if excl_group in other.get("tags", {}).get("all_tags", []):
                                    conflict = True
                                    break
                    
                    if not conflict:
                        cmd_type = "qm" if guest.get("type") == "VM" else "pct"
                        cmd_flag = "--online" if guest.get("type") == "VM" else "--restart"
                        vmid_int = int(vmid_key) if isinstance(vmid_key, str) else vmid_key
                        recommendations.append({
                            "vmid": vmid_int,
                            "name": guest.get("name", "unknown"),
                            "type": guest.get("type", "unknown"),
                            "source_node": src_node,
                            "target_node": best_target,
                            "reason": "Balance {} load".format(overload["reason"].upper()),
                            "mem_gb": guest.get("mem_max_gb", 0),
                            "command": "{} migrate {} {} {}".format(cmd_type, vmid_int, best_target, cmd_flag)
                        })
                except Exception as e:
                    print(f"Error creating recommendation for guest {vmid_key}: {str(e)}", file=sys.stderr)
                    import traceback
                    traceback.print_exc()
                    continue
    
    return recommendations


@app.route("/api/migrate", methods=["POST"])
def execute_migration():
    """Execute a migration asynchronously"""
    try:
        data = request.json
        vmid = data.get("vmid")
        target = data.get("target_node")
        source = data.get("source_node")
        guest_type = data.get("type", "VM")
        
        if not vmid or not target:
            return jsonify({"success": False, "error": "Missing vmid or target_node"}), 400
        
        if not source:
            return jsonify({"success": False, "error": "Missing source_node"}), 400
        
        cmd = "qm" if guest_type == "VM" else "pct"
        flag = "--online" if guest_type == "VM" else "--restart"
        
        # Start migration in background (non-blocking)
        ssh_cmd = ["/bin/ssh"] + SSH_OPTS + [f"root@{source}", cmd, "migrate", str(vmid), target, flag]
        subprocess.Popen(ssh_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        trigger_collection()
        
        return jsonify({
            "success": True,
            "message": f"Migration of {guest_type} {vmid} from {source} to {target} started in background. Check Proxmox task logs for progress."
        })
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/migrate/batch", methods=["POST"])
def execute_batch_migration():
    """Execute multiple migrations asynchronously"""
    try:
        data = request.json
        migrations = data.get("migrations", [])
        
        if not migrations:
            return jsonify({"success": False, "error": "No migrations provided"}), 400
        
        print(f"Starting async batch migration of {len(migrations)} guests", file=sys.stderr)
        
        results = []
        for idx, mig in enumerate(migrations):
            try:
                vmid = mig.get("vmid")
                target = mig.get("target_node")
                source = mig.get("source_node")
                guest_type = mig.get("type")
                
                if not all([vmid, target, source, guest_type]):
                    results.append({
                        "vmid": vmid,
                        "success": False,
                        "error": "Missing required fields"
                    })
                    continue
                
                print(f"[{idx+1}/{len(migrations)}] Starting migration of {guest_type} {vmid} from {source} to {target}", file=sys.stderr)
                
                cmd = "qm" if guest_type == "VM" else "pct"
                flag = "--online" if guest_type == "VM" else "--restart"
                
                # Start migration in background (non-blocking)
                ssh_cmd = ["/bin/ssh"] + SSH_OPTS + [f"root@{source}", cmd, "migrate", str(vmid), target, flag]
                subprocess.Popen(ssh_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                
                results.append({
                    "vmid": vmid,
                    "success": True,
                    "message": "Migration started (running in background)"
                })
                print(f"  ✓ Migration of {vmid} started in background", file=sys.stderr)
                
            except Exception as e:
                results.append({
                    "vmid": vmid,
                    "success": False,
                    "error": str(e)
                })
                print(f"  ✗ Failed to start migration of {vmid}: {str(e)}", file=sys.stderr)
        
        # Trigger collection after a delay to allow migrations to progress
        trigger_collection()
        
        succeeded = sum(1 for r in results if r["success"])
        print(f"Batch migration initiated: {succeeded}/{len(migrations)} started", file=sys.stderr)
        
        return jsonify({
            "success": True,
            "results": results,
            "total": len(migrations),
            "succeeded": succeeded,
            "message": f"{succeeded} migration(s) started. Check Proxmox task logs for progress. Data will refresh automatically."
        })
        
    except Exception as e:
        print(f"Batch migration error: {str(e)}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/config", methods=["GET"])
def get_config():
    """Get current configuration"""
    try:
        config = load_config()
        
        if config.get('error'):
            return jsonify({
                "success": False,
                "error": config.get('message')
            }), 500
        
        return jsonify({"success": True, "config": config})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/config", methods=["POST"])
def update_config():
    """Update configuration"""
    try:
        import subprocess as sp
        
        data = request.json
        
        config = load_config()
        if config.get('error'):
            return jsonify({
                "success": False,
                "error": config.get('message')
            }), 500
        
        if "collection_interval_minutes" in data:
            config["collection_interval_minutes"] = int(data["collection_interval_minutes"])
        if "ui_refresh_interval_minutes" in data:
            config["ui_refresh_interval_minutes"] = int(data["ui_refresh_interval_minutes"])
        if "proxmox_host" in data:
            config["proxmox_host"] = str(data["proxmox_host"])
        
        with open(CONFIG_FILE, "w") as f:
            json.dump(config, f, indent=2)
        
        if "collection_interval_minutes" in data:
            update_script = "/opt/proxmox-balance-manager/update_timer.py"
            result = sp.run(["/opt/proxmox-balance-manager/venv/bin/python3", update_script], 
                          capture_output=True, text=True)
            if result.returncode != 0:
                return jsonify({
                    "success": False, 
                    "error": f"Failed to update timer: {result.stderr}"
                }), 500
        
        return jsonify({
            "success": True, 
            "message": "Configuration updated successfully",
            "config": config
        })
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)