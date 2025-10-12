#!/usr/bin/env bash

# ProxBalance Status Checker
# Usage: ./check-status.sh [container-id]

set -euo pipefail

# Colors
RD='\033[0;31m'
YW='\033[1;33m'
GN='\033[0;32m'
BL='\033[0;34m'
CL='\033[0m'
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

CTID="${1:-334}"

echo -e "${BL}╔════════════════════════════════════════════════════════════════╗${CL}"
echo -e "${BL}║${CL}  ${GN}ProxBalance Status Check${CL} - Container ${YW}${CTID}${CL}                     ${BL}║${CL}"
echo -e "${BL}╚════════════════════════════════════════════════════════════════╝${CL}"
echo ""

# Check if container exists
if ! pct status "$CTID" &>/dev/null; then
    echo -e "${CROSS} Container ${CTID} not found"
    exit 1
fi

# Check container status
CT_STATUS=$(pct status "$CTID" | awk '{print $2}')
if [ "$CT_STATUS" = "running" ]; then
    echo -e "${CM} Container Status: ${GN}running${CL}"
else
    echo -e "${CROSS} Container Status: ${RD}${CT_STATUS}${CL}"
    exit 1
fi

# Get container IP
CONTAINER_IP=$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}')
if [ -n "$CONTAINER_IP" ]; then
    echo -e "${CM} Container IP: ${GN}${CONTAINER_IP}${CL}"
else
    echo -e "${CROSS} Could not determine container IP"
    CONTAINER_IP="localhost"
fi

echo ""
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${BL}Service Status${CL}"
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"

# Check API service
if pct exec "$CTID" -- systemctl is-active proxmox-balance.service &>/dev/null; then
    echo -e "${CM} API Service: ${GN}active${CL}"
else
    echo -e "${CROSS} API Service: ${RD}inactive${CL}"
fi

# Check collector timer
if pct exec "$CTID" -- systemctl is-active proxmox-collector.timer &>/dev/null; then
    echo -e "${CM} Collector Timer: ${GN}active${CL}"
    
    # Get next run time
    NEXT_RUN=$(pct exec "$CTID" -- systemctl list-timers proxmox-collector.timer 2>/dev/null | grep proxmox-collector | awk '{print $1, $2}')
    if [ -n "$NEXT_RUN" ]; then
        echo -e "   ${BL}Next collection: ${YW}${NEXT_RUN}${CL}"
    fi
else
    echo -e "${CROSS} Collector Timer: ${RD}inactive${CL}"
fi

# Check nginx
if pct exec "$CTID" -- systemctl is-active nginx.service &>/dev/null; then
    echo -e "${CM} Web Server: ${GN}active${CL}"
else
    echo -e "${CROSS} Web Server: ${RD}inactive${CL}"
fi

echo ""
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${BL}Data Collection Status${CL}"
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"

# Check if cache file exists
if pct exec "$CTID" -- test -f /opt/proxmox-balance-manager/cluster_cache.json; then
    echo -e "${CM} Cache File: ${GN}exists${CL}"
    
    # Get cache timestamp
    CACHE_TIME=$(pct exec "$CTID" -- jq -r '.collected_at // "unknown"' /opt/proxmox-balance-manager/cluster_cache.json 2>/dev/null)
    if [ "$CACHE_TIME" != "unknown" ] && [ -n "$CACHE_TIME" ]; then
        echo -e "   ${BL}Last collection: ${YW}${CACHE_TIME}${CL}"
        
        # Calculate age
        CACHE_EPOCH=$(date -d "$CACHE_TIME" +%s 2>/dev/null || echo "0")
        NOW_EPOCH=$(date +%s)
        AGE_SECONDS=$((NOW_EPOCH - CACHE_EPOCH))
        AGE_MINUTES=$((AGE_SECONDS / 60))
        
        if [ $AGE_MINUTES -lt 1 ]; then
            echo -e "   ${BL}Age: ${GN}< 1 minute${CL}"
        elif [ $AGE_MINUTES -lt 60 ]; then
            echo -e "   ${BL}Age: ${YW}${AGE_MINUTES} minutes${CL}"
        else
            AGE_HOURS=$((AGE_MINUTES / 60))
            echo -e "   ${BL}Age: ${YW}${AGE_HOURS} hours${CL}"
        fi
    fi
    
    # Get cluster summary
    NODE_COUNT=$(pct exec "$CTID" -- jq -r '.summary.total_nodes // 0' /opt/proxmox-balance-manager/cluster_cache.json 2>/dev/null)
    GUEST_COUNT=$(pct exec "$CTID" -- jq -r '.summary.total_guests // 0' /opt/proxmox-balance-manager/cluster_cache.json 2>/dev/null)
    
    if [ "$NODE_COUNT" != "0" ]; then
        echo -e "   ${BL}Nodes: ${GN}${NODE_COUNT}${CL}"
        echo -e "   ${BL}Guests: ${GN}${GUEST_COUNT}${CL}"
    fi
else
    echo -e "${CROSS} Cache File: ${RD}missing${CL}"
    echo -e "   ${YW}Data collection may still be in progress${CL}"
fi

echo ""
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${BL}API Health Check${CL}"
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"

# Test API endpoint
API_RESPONSE=$(curl -s -w "\n%{http_code}" "http://${CONTAINER_IP}/api/health" 2>/dev/null || echo "error\n000")
HTTP_CODE=$(echo "$API_RESPONSE" | tail -n1)
API_BODY=$(echo "$API_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${CM} API Status: ${GN}healthy${CL} (HTTP ${HTTP_CODE})"
    
    # Parse API response
    if command -v jq &>/dev/null; then
        API_STATUS=$(echo "$API_BODY" | jq -r '.status // "unknown"' 2>/dev/null)
        CACHE_AVAILABLE=$(echo "$API_BODY" | jq -r '.cache_available // false' 2>/dev/null)
        
        if [ "$CACHE_AVAILABLE" = "true" ]; then
            echo -e "   ${BL}Cache: ${GN}available${CL}"
        else
            echo -e "   ${BL}Cache: ${YW}not ready${CL}"
        fi
    fi
else
    echo -e "${CROSS} API Status: ${RD}unhealthy${CL} (HTTP ${HTTP_CODE})"
fi

# Test analyze endpoint
ANALYZE_RESPONSE=$(curl -s -w "\n%{http_code}" "http://${CONTAINER_IP}/api/analyze" 2>/dev/null || echo "error\n000")
ANALYZE_HTTP_CODE=$(echo "$ANALYZE_RESPONSE" | tail -n1)

if [ "$ANALYZE_HTTP_CODE" = "200" ]; then
    echo -e "${CM} Data Endpoint: ${GN}ready${CL}"
elif [ "$ANALYZE_HTTP_CODE" = "503" ]; then
    echo -e "${YW}⚠${CL} Data Endpoint: ${YW}collection in progress${CL}"
else
    echo -e "${CROSS} Data Endpoint: ${RD}error${CL} (HTTP ${ANALYZE_HTTP_CODE})"
fi

echo ""
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${BL}SSH Connectivity Test${CL}"
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"

# Detect nodes from config or cache
if pct exec "$CTID" -- test -f /opt/proxmox-balance-manager/cluster_cache.json; then
    NODES=$(pct exec "$CTID" -- jq -r '.nodes | keys[]' /opt/proxmox-balance-manager/cluster_cache.json 2>/dev/null | tr '\n' ' ')
elif command -v pvesh &>/dev/null; then
    NODES=$(pvesh get /nodes --output-format json 2>/dev/null | jq -r '.[].node' 2>/dev/null | tr '\n' ' ')
fi

if [ -n "$NODES" ]; then
    SSH_TEST_RESULTS=$(pct exec "$CTID" -- bash <<EOF
for node in $NODES; do
    if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no root@\$node 'echo OK' 2>/dev/null | grep -q OK; then
        echo "\$node:OK"
    else
        echo "\$node:FAILED"
    fi
done
EOF
)
    
    ALL_OK=true
    while IFS=: read -r node status; do
        if [ "$status" = "OK" ]; then
            echo -e "${CM} ${node}: ${GN}connected${CL}"
        else
            echo -e "${CROSS} ${node}: ${RD}failed${CL}"
            ALL_OK=false
        fi
    done <<< "$SSH_TEST_RESULTS"
    
    if [ "$ALL_OK" = false ]; then
        echo ""
        echo -e "${YW}Some SSH connections failed. Check SSH key configuration.${CL}"
    fi
else
    echo -e "${YW}⚠${CL} No nodes detected - cache may not be ready yet"
fi

echo ""
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${BL}Quick Actions${CL}"
echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo ""
echo -e "  ${YW}# Access web interface${CL}"
echo -e "  ${BL}http://${CONTAINER_IP}${CL}"
echo ""
echo -e "  ${YW}# Trigger manual collection${CL}"
echo -e "  ${BL}curl -X POST http://${CONTAINER_IP}/api/refresh${CL}"
echo -e "  ${BL}pct exec ${CTID} -- systemctl start proxmox-collector.service${CL}"
echo ""
echo -e "  ${YW}# View logs${CL}"
echo -e "  ${BL}pct exec ${CTID} -- journalctl -u proxmox-balance -f${CL}"
echo -e "  ${BL}pct exec ${CTID} -- journalctl -u proxmox-collector -f${CL}"
echo ""
echo -e "  ${YW}# Restart services${CL}"
echo -e "  ${BL}pct exec ${CTID} -- systemctl restart proxmox-balance${CL}"
echo ""
