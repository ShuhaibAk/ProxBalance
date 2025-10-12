#!/usr/bin/env python3
"""
Background data collector for Proxmox Balance Manager
Runs independently and saves data to cache file
"""

import subprocess
import json
import sys
import os
from datetime import datetime
from typing import Dict, List

CACHE_FILE = '/opt/proxmox-balance-manager/cluster_cache.json'
PROXMOX_HOST = "10.0.0.3"
SSH_OPTS = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "LogLevel=ERROR"]

class ProxmoxBalanceAnalyzer:
    def __init__(self):
        self.nodes = {}
        self.guests = {}
        
    def run_command(self, cmd: List[str]) -> str:
        """Execute command on Proxmox host via SSH"""
        try:
            ssh_cmd = ["/bin/ssh"] + SSH_OPTS + [f"root@{PROXMOX_HOST}"] + cmd
            result = subprocess.run(ssh_cmd, capture_output=True, text=True, timeout=30)
            if result.returncode != 0:
                raise Exception("Command failed: " + result.stderr)
            return result.stdout
        except Exception as e:
            raise Exception("Command failed: " + str(e))
    
    def get_cluster_resources(self) -> Dict:
        """Fetch cluster resources via pvesh"""
        output = self.run_command(["pvesh", "get", "/cluster/resources", "--output-format", "json"])
        return json.loads(output)
    
    def get_node_rrd_data(self, node: str) -> List[Dict]:
        """Fetch RRD performance data for a node"""
        try:
            output = self.run_command([
                "pvesh", "get", "/nodes/{}/rrddata".format(node),
                "--timeframe", "hour",
                "--output-format", "json"
            ])
            return json.loads(output)
        except:
            return []
    
    def get_guest_config(self, node: str, vmid: int, guest_type: str) -> Dict:
        """Fetch guest configuration including tags"""
        try:
            endpoint = "qemu" if guest_type == "qemu" else "lxc"
            output = self.run_command([
                "pvesh", "get", "/nodes/{}/{}/{}/config".format(node, endpoint, vmid),
                "--output-format", "json"
            ])
            return json.loads(output)
        except:
            return {}
    
    def parse_tags(self, tags_str: str) -> Dict:
        """Parse tags and extract ignore/exclude rules"""
        if not tags_str:
            return {"has_ignore": False, "exclude_groups": [], "all_tags": []}
        
        tags = [t.strip() for t in tags_str.replace(";", " ").split()]
        has_ignore = "ignore" in tags
        exclude_groups = [t for t in tags if t.startswith("exclude_")]
        
        return {
            "has_ignore": has_ignore,
            "exclude_groups": exclude_groups,
            "all_tags": tags
        }
    
    def calculate_node_metrics(self, node_data: Dict, rrd_data: List[Dict]) -> Dict:
        """Calculate current and historical metrics for a node"""
        metrics = {
            "current_cpu": node_data.get("cpu", 0) * 100,
            "current_mem": (node_data.get("mem", 0) / node_data.get("maxmem", 1)) * 100,
            "avg_cpu": 0,
            "max_cpu": 0,
            "avg_mem": 0,
            "max_mem": 0,
            "avg_load": 0,
            "has_historical": False
        }
        
        if rrd_data:
            cpu_values = [d["cpu"] * 100 for d in rrd_data if "cpu" in d and d["cpu"] is not None]
            mem_values = [(d["memused"] / d["memtotal"] * 100) for d in rrd_data 
                         if "memused" in d and "memtotal" in d and d["memtotal"] > 0]
            load_values = [d["loadavg"] for d in rrd_data if "loadavg" in d and d["loadavg"] is not None]
            
            if cpu_values:
                metrics["avg_cpu"] = sum(cpu_values) / len(cpu_values)
                metrics["max_cpu"] = max(cpu_values)
                metrics["has_historical"] = True
            
            if mem_values:
                metrics["avg_mem"] = sum(mem_values) / len(mem_values)
                metrics["max_mem"] = max(mem_values)
            
            if load_values:
                metrics["avg_load"] = sum(load_values) / len(load_values)
        
        return metrics
    
    def analyze_cluster(self) -> Dict:
        """Perform full cluster analysis"""
        resources = self.get_cluster_resources()
        
        nodes_raw = [r for r in resources if r["type"] == "node"]
        vms_raw = [r for r in resources if r["type"] == "qemu"]
        cts_raw = [r for r in resources if r["type"] == "lxc"]
        
        for node in nodes_raw:
            node_name = node["node"]
            rrd_data = self.get_node_rrd_data(node_name)
            metrics = self.calculate_node_metrics(node, rrd_data)
            
            self.nodes[node_name] = {
                "name": node_name,
                "status": node.get("status", "unknown"),
                "cpu_cores": node.get("maxcpu", 0),
                "total_mem_gb": node.get("maxmem", 0) / (1024**3),
                "uptime": node.get("uptime", 0),
                "metrics": metrics,
                "guests": []
            }
        
        for guest in vms_raw + cts_raw:
            vmid = guest["vmid"]
            node_name = guest["node"]
            guest_type = "VM" if guest["type"] == "qemu" else "CT"
            
            config = self.get_guest_config(node_name, vmid, guest["type"])
            tags_data = self.parse_tags(config.get("tags", ""))
            
            guest_info = {
                "vmid": vmid,
                "name": guest.get("name", "unnamed"),
                "type": guest_type,
                "node": node_name,
                "status": guest.get("status", "unknown"),
                "cpu_current": guest.get("cpu", 0) * 100,
                "mem_used_gb": guest.get("mem", 0) / (1024**3),
                "mem_max_gb": guest.get("maxmem", 0) / (1024**3),
                "disk_gb": guest.get("disk", 0) / (1024**3),
                "tags": tags_data
            }
            
            self.guests[vmid] = guest_info
            if node_name in self.nodes:
                self.nodes[node_name]["guests"].append(vmid)
        
        return self.generate_summary()
    
    def generate_summary(self) -> Dict:
        """Generate cluster summary"""
        total_guests = len(self.guests)
        ignored = sum(1 for g in self.guests.values() if g["tags"]["has_ignore"])
        excluded = sum(1 for g in self.guests.values() if g["tags"]["exclude_groups"])
        
        return {
            "timestamp": datetime.utcnow().isoformat() + 'Z',
            "nodes": self.nodes,
            "guests": self.guests,
            "summary": {
                "total_nodes": len(self.nodes),
                "total_guests": total_guests,
                "vms": sum(1 for g in self.guests.values() if g["type"] == "VM"),
                "containers": sum(1 for g in self.guests.values() if g["type"] == "CT"),
                "ignored_guests": ignored,
                "excluded_guests": excluded
            }
        }


def collect_data():
    """Collect cluster data and save to cache"""
    try:
        print(f"[{datetime.utcnow()}] Starting cluster data collection...")
        analyzer = ProxmoxBalanceAnalyzer()
        data = analyzer.analyze_cluster()
        
        # Add collection timestamp
        data['collected_at'] = datetime.utcnow().isoformat() + 'Z'
        
        # Write to cache file atomically
        temp_file = CACHE_FILE + '.tmp'
        with open(temp_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        # Atomic rename
        os.rename(temp_file, CACHE_FILE)
        
        print(f"[{datetime.utcnow()}] Data collection complete. Cache updated.")
        return True
        
    except Exception as e:
        print(f"[{datetime.utcnow()}] ERROR: {str(e)}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = collect_data()
    sys.exit(0 if success else 1)
