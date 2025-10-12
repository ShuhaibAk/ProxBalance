#!/usr/bin/env bash

# Test Node Detection Script
# Tests all 4 methods used in the installer

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ProxBalance Node Detection Test                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

DETECTED_NODES=""

# Method 1: corosync.conf
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[Method 1] Testing corosync.conf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f /etc/pve/corosync.conf ]; then
    DETECTED_NODES=$(grep -oP '(?<=name: ).*' /etc/pve/corosync.conf 2>/dev/null | grep -v '^Cluster$' | tr '\n' ' ' | xargs)
    if [ -n "$DETECTED_NODES" ]; then
        echo "✓ Success: $DETECTED_NODES"
    else
        echo "✗ Failed: No nodes detected"
    fi
else
    echo "✗ Failed: /etc/pve/corosync.conf not found"
fi
echo ""

# Method 2: /etc/pve/nodes/
if [ -z "$DETECTED_NODES" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[Method 2] Testing /etc/pve/nodes/"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ -d /etc/pve/nodes ]; then
        DETECTED_NODES=$(ls /etc/pve/nodes/ 2>/dev/null | grep -E '^[a-zA-Z0-9]' | grep -v '^pve$' | tr '\n' ' ' | xargs)
        if [ -n "$DETECTED_NODES" ]; then
            echo "✓ Success: $DETECTED_NODES"
        else
            echo "✗ Failed: No nodes detected"
        fi
    else
        echo "✗ Failed: /etc/pve/nodes/ directory not found"
    fi
    echo ""
fi

# Method 3: pvecm status
if [ -z "$DETECTED_NODES" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[Method 3] Testing pvecm status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if command -v pvecm &> /dev/null; then
        DETECTED_NODES=$(pvecm status 2>/dev/null | grep -oP '(?<=Name:             ).*' | grep -v '^Cluster$' | xargs)
        if [ -n "$DETECTED_NODES" ]; then
            echo "✓ Success: $DETECTED_NODES"
        else
            echo "✗ Failed: No nodes detected"
        fi
    else
        echo "✗ Failed: pvecm command not found"
    fi
    echo ""
fi

# Method 4: pvesh without jq
if [ -z "$DETECTED_NODES" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[Method 4] Testing pvesh (manual JSON parsing)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if command -v pvesh &> /dev/null; then
        DETECTED_NODES=$(pvesh get /nodes 2>/dev/null | grep -oP '"node"\s*:\s*"[^"]*"' | cut -d'"' -f4 | grep -v '^Cluster$' | tr '\n' ' ' | xargs)
        if [ -n "$DETECTED_NODES" ]; then
            echo "✓ Success: $DETECTED_NODES"
        else
            echo "✗ Failed: No nodes detected"
        fi
    else
        echo "✗ Failed: pvesh command not found"
    fi
    echo ""
fi

# Remove duplicates and sort
DETECTED_NODES=$(echo "$DETECTED_NODES" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

# Final result
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Final Result                                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [ -n "$DETECTED_NODES" ]; then
    echo "✓ Detected Nodes: $DETECTED_NODES"
    
    # Count nodes
    NODE_COUNT=$(echo "$DETECTED_NODES" | wc -w)
    echo "✓ Total Count: $NODE_COUNT"
    
    # Determine primary host
    PRIMARY_HOST=$(echo "$DETECTED_NODES" | awk '{print $1}')
    CURRENT_HOST=$(hostname -s)
    
    echo "✓ Default Primary: $PRIMARY_HOST"
    echo "✓ Current Host: $CURRENT_HOST"
    
    if echo "$DETECTED_NODES" | grep -qw "$CURRENT_HOST"; then
        echo "✓ Current host is in cluster - will be used as primary"
    else
        echo "⚠ Current host not in detected list - will use first node as primary"
    fi
else
    echo "✗ FAILED: No nodes could be detected"
    echo ""
    echo "Please manually provide node information when running the installer."
fi

echo ""
