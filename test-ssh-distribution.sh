#!/bin/bash

set -x  # Enable debug mode

SSH_PUBKEY="test_key_12345"
nodes="pve3 pve4 pve5 pve6"

echo "Creating temp file..."
tmpfile=$(mktemp)
echo "Temp file: $tmpfile"

echo "Starting SSH distribution..."
for node in $nodes; do
  echo "Launching background job for $node..."
  (
    echo "Inside subshell for $node"
    if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes -o LogLevel=ERROR root@"${node}" \
       "echo 'Testing ${node}'" </dev/null &>/dev/null; then
      echo "Success for $node, writing to $tmpfile"
      echo "${node}:OK" >> "$tmpfile"
    else
      echo "Failed for $node, writing to $tmpfile"
      echo "${node}:FAIL" >> "$tmpfile"
    fi
    echo "Finished subshell for $node"
  ) &
  echo "Background job launched for $node (PID: $!)"
done

echo "All background jobs launched, waiting..."
wait
echo "All jobs completed"

echo "Reading results from $tmpfile:"
cat "$tmpfile"

echo ""
echo "Processing results..."
for node in $nodes; do
  echo -n "  ${node}: "
  if grep -q "^${node}:OK$" "$tmpfile" 2>/dev/null; then
    echo "✓ Connected"
  else
    echo "✗ Failed"
  fi
done

rm -f "$tmpfile"
echo "Done!"
