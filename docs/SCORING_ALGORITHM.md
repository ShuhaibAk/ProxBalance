# ProxBalance Scoring Algorithm

Deep dive into ProxBalance's penalty-based scoring system and how it drives intelligent migration recommendations.

---

## Table of Contents

- [Overview](#overview)
- [Suitability Rating System](#suitability-rating-system)
- [Penalty-Based Scoring](#penalty-based-scoring)
- [How Recommendations Are Generated](#how-recommendations-are-generated)
- [Integration with Automated Migrations](#integration-with-automated-migrations)
- [Examples](#examples)
- [Configuration](#configuration)

---

## Overview

ProxBalance uses a sophisticated **penalty-based scoring algorithm** to evaluate potential migration targets. Instead of hard rules that disqualify nodes, the system applies penalties for undesirable conditions, allowing for flexible and intelligent decision-making even in challenging scenarios.

### Key Principles

1. **No Hard Disqualifications** - Every online node is always a potential target
2. **Cumulative Penalties** - Multiple factors contribute to a total penalty score
3. **Relative Comparison** - Nodes are ranked against each other, not absolute thresholds
4. **Flexible Decision Making** - Allows evacuating overloaded nodes without being blocked by restrictions
5. **User-Friendly Output** - Penalties converted to intuitive 0-100% Suitability Ratings

---

## Suitability Rating System

### What is a Suitability Rating?

The **Suitability Rating** is a percentage (0-100%) that indicates how suitable a target node is for a migration:

- **100%** = Perfect target (zero or minimal penalties)
- **75-99%** = Good target (low penalties)
- **50-74%** = Acceptable target (moderate penalties)
- **25-49%** = Poor target (high penalties)
- **0-24%** = Very poor target (severe penalties)

### How It's Calculated

1. **Calculate Raw Penalty Score** for each potential target node
2. **Find the Best Target** (lowest penalty score)
3. **Find the Worst Target** (highest penalty score)
4. **Normalize to Percentage**:
   ```
   Suitability = 100 - ((node_penalty - best_penalty) / (worst_penalty - best_penalty) * 100)
   ```

This means:
- The best node always gets 100% (or close to it)
- The worst node gets 0% (or close to it)
- Other nodes are distributed proportionally between them

### Why Percentages?

Raw penalty scores like "1247.3" are meaningless to users. A Suitability Rating of "87%" immediately conveys that this is a good target node, while "23%" clearly indicates a poor choice.

---

## Penalty-Based Scoring

### Core Penalty Factors

ProxBalance evaluates multiple factors when scoring target nodes. Each factor contributes penalties based on how undesirable the condition is.

#### 1. CPU Usage Penalty

Nodes with high CPU usage receive penalties to avoid overloading them:

```python
if cpu_usage > 70:
    penalty += (cpu_usage - 70) * 10  # 10 points per % over 70%
```

**Example:**
- Node at 75% CPU: +50 penalty points
- Node at 85% CPU: +150 penalty points
- Node at 95% CPU: +250 penalty points

#### 2. Memory Pressure Penalty

Similar to CPU, high memory usage adds penalties:

```python
if memory_usage > 70:
    penalty += (memory_usage - 70) * 10
```

**Example:**
- Node at 80% memory: +100 penalty points
- Node at 90% memory: +200 penalty points

#### 3. IOWait Penalty

**New in recent updates:** High I/O wait times indicate storage bottlenecks:

```python
if iowait > 5:
    penalty += iowait * 20  # Higher weight due to performance impact
```

**Example:**
- Node with 10% IOWait: +200 penalty points
- Node with 15% IOWait: +300 penalty points

IOWait penalties have higher weight (20x vs 10x) because I/O bottlenecks severely impact VM performance.

#### 4. Load Distribution Penalty

Prevents concentrating too many VMs on a single node:

```python
guest_count = len(guests_on_node)
penalty += guest_count * 5  # Encourages spreading workload
```

**Example:**
- Node with 10 VMs: +50 penalty points
- Node with 20 VMs: +100 penalty points

#### 5. Maintenance Mode Penalty

Nodes in maintenance mode receive massive penalties:

```python
if node_in_maintenance:
    penalty += 10000  # Effectively excludes from consideration
```

This ensures maintenance nodes are only used when absolutely no other options exist.

#### 6. Storage Compatibility Penalty

Nodes missing required storage receive severe penalties:

```python
if not has_all_required_storage:
    penalty += 5000  # Very high, but not infinite
```

This strongly discourages incompatible targets but doesn't make migrations impossible (useful for emergency evacuations).

#### 7. Anti-Affinity Violation Penalty

VMs with `exclude_*` tags get penalties for nodes already hosting VMs with the same tag:

```python
if same_exclusion_group_present:
    penalty += 1000  # Strong discouragement
```

**Example:** If VM has tag `exclude_database` and target node already has another VM with `exclude_database`, +1000 penalty is added.

#### 8. Source Node Penalty

Prevents recommending migration to the same node the VM is already on:

```python
if target_node == current_node:
    penalty += 999999  # Nearly infinite penalty
```

---

## How Recommendations Are Generated

### Step-by-Step Process

#### 1. Identify VMs Needing Migration

The system analyzes all VMs and containers to find those that should be migrated based on:

- **Source node is overloaded** (CPU > 80% or Memory > 80%)
- **Source node is in maintenance mode**
- **Anti-affinity violations** (VMs with same `exclude_*` tag on same node)
- **Manual triggers** (user requests recommendations)

#### 2. Score All Potential Targets

For each VM needing migration, ProxBalance scores every online node in the cluster:

```python
for target_node in all_online_nodes:
    penalty = 0

    # Apply all penalty factors
    penalty += cpu_penalty(target_node)
    penalty += memory_penalty(target_node)
    penalty += iowait_penalty(target_node)
    penalty += guest_count_penalty(target_node)
    penalty += maintenance_penalty(target_node)
    penalty += storage_penalty(target_node, vm)
    penalty += affinity_penalty(target_node, vm)
    penalty += source_node_penalty(target_node, vm.current_node)

    scores[target_node] = penalty
```

#### 3. Rank Targets by Penalty

Nodes are sorted by penalty score (lowest = best):

```python
sorted_targets = sorted(scores.items(), key=lambda x: x[1])
best_target = sorted_targets[0]  # Lowest penalty
```

#### 4. Convert to Suitability Ratings

Raw penalty scores are converted to user-friendly percentages:

```python
best_penalty = sorted_targets[0][1]
worst_penalty = sorted_targets[-1][1]

for node, penalty in scores.items():
    suitability = 100 - ((penalty - best_penalty) / (worst_penalty - best_penalty) * 100)
    ratings[node] = round(suitability, 1)
```

#### 5. Generate Recommendation

If the best target has acceptable suitability, a recommendation is created:

```python
if best_suitability >= minimum_threshold:  # e.g., 50%
    recommendation = {
        "vm": vm_name,
        "source": current_node,
        "target": best_target,
        "suitability": best_suitability,
        "reason": generate_reason(vm, current_node, best_target)
    }
```

---

## Integration with Automated Migrations

### How Automated Migrations Use Scoring

The automated migration system (`automigrate.py`) uses the same scoring algorithm with additional safety checks:

#### 1. Generate Recommendations

```python
recommendations = generate_migration_recommendations()
```

This uses the penalty-based scoring system described above.

#### 2. Filter by Confidence/Suitability

Only recommendations with high suitability ratings are considered:

```python
filtered = [r for r in recommendations if r['suitability'] >= min_confidence_score]
```

**Default:** 75% minimum suitability (configurable in settings)

#### 3. Apply Safety Checks

Additional validation before execution:

- **Duplicate Migration Check** - Query Proxmox cluster tasks to ensure VM isn't already being migrated
- **Resource Validation** - Verify target node has sufficient resources
- **Storage Validation** - Confirm all required storage exists on target
- **Tag Respect** - Honor `ignore` tags and whitelist mode
- **Cluster Health** - Verify quorum and node connectivity

#### 4. Execute Top Recommendations

Migrations are executed in priority order:

1. **Maintenance evacuations** (highest priority)
2. **Anti-affinity violations** (high priority)
3. **Overloaded node evacuations** (medium priority)
4. **Load balancing optimizations** (low priority)

#### 5. Rate Limiting

The system limits concurrent migrations:

```python
max_migrations_per_run = 3  # Configurable
```

This prevents overwhelming the cluster with simultaneous migrations.

#### 6. Infinite Polling with Resource Validation

**New enhancement:** The automation system continuously monitors running migrations:

- Polls Proxmox tasks API every 10 seconds
- Validates target node resources before marking migration complete
- Detects failures and logs detailed error information
- Prevents duplicate migrations by tracking in-progress tasks

---

## Examples

### Example 1: Simple Load Balancing

**Scenario:**
- VM 101 on node1 (CPU: 85%, Memory: 70%)
- Available targets: node2 (CPU: 40%, Memory: 50%), node3 (CPU: 60%, Memory: 65%)

**Scoring:**

**node2:**
- CPU penalty: 0 (under 70%)
- Memory penalty: 0 (under 70%)
- IOWait penalty: 0 (assume 2%)
- Guest count penalty: 60 (12 VMs * 5)
- **Total penalty: 60**

**node3:**
- CPU penalty: 0 (under 70%)
- Memory penalty: 0 (under 70%)
- IOWait penalty: 0 (assume 3%)
- Guest count penalty: 40 (8 VMs * 5)
- **Total penalty: 40**

**Suitability Ratings:**
- node3: 100% (best target, lowest penalty)
- node2: 0% (worst target, highest penalty)

**Recommendation:** Migrate VM 101 to node3 (100% suitability)

---

### Example 2: IOWait Consideration

**Scenario:**
- VM 102 (database server) needs migration
- node2: CPU 50%, Memory 55%, IOWait 15%
- node3: CPU 65%, Memory 70%, IOWait 3%

**Scoring:**

**node2:**
- CPU penalty: 0
- Memory penalty: 0
- IOWait penalty: 300 (15 * 20)
- Guest count penalty: 50
- **Total penalty: 350**

**node3:**
- CPU penalty: 0
- Memory penalty: 0
- IOWait penalty: 0
- Guest count penalty: 45
- **Total penalty: 45**

**Suitability Ratings:**
- node3: 100% (despite higher CPU/memory, IOWait is low)
- node2: 0% (high IOWait makes it unsuitable for database)

**Recommendation:** Migrate to node3 - IOWait penalties prioritize I/O performance

---

### Example 3: Anti-Affinity Enforcement

**Scenario:**
- VM 201 (tagged `exclude_firewall`) needs migration
- VM 202 (also tagged `exclude_firewall`) already on node2
- node2: CPU 40%, Memory 50%
- node3: CPU 60%, Memory 65%

**Scoring:**

**node2:**
- CPU penalty: 0
- Memory penalty: 0
- Affinity violation penalty: 1000
- Guest count penalty: 50
- **Total penalty: 1050**

**node3:**
- CPU penalty: 0
- Memory penalty: 0
- Affinity violation penalty: 0
- Guest count penalty: 60
- **Total penalty: 60**

**Suitability Ratings:**
- node3: 100% (no affinity violation)
- node2: 0% (affinity violation penalty dominates)

**Recommendation:** Migrate to node3 to maintain separation

---

### Example 4: Maintenance Evacuation

**Scenario:**
- node1 in maintenance mode with 5 VMs to evacuate
- node2: CPU 75%, Memory 80%, IOWait 8%
- node3: CPU 85%, Memory 90%, IOWait 12%

**Scoring for each VM:**

**node2:**
- CPU penalty: 50
- Memory penalty: 100
- IOWait penalty: 160
- Guest count penalty: increases with each migration
- **Initial penalty: ~310**

**node3:**
- CPU penalty: 150
- Memory penalty: 200
- IOWait penalty: 240
- Guest count penalty: increases with each migration
- **Initial penalty: ~590**

**Suitability Ratings:**
- node2: 100% (better despite being loaded)
- node3: 0% (worse, but still usable)

**Result:** All VMs evacuate to node2 first (100% suitability). If node2 becomes too loaded, later VMs may go to node3 as penalties equalize. **No hard disqualification** means evacuation always succeeds.

---

## Configuration

### Adjusting Penalty Weights (Web UI)

You can now customize penalty weights directly through the Web UI:

1. Navigate to **Settings** in the web interface
2. Expand the **Penalty Scoring Configuration** section
3. Modify values as needed:
   - **Time Period Weights** - Control how much weight to give recent vs. historical metrics
   - **CPU/Memory/IOWait Penalties** - Adjust severity of resource usage penalties
   - **Storage and HA Penalties** - Configure penalties for storage and high availability concerns
4. The UI provides real-time validation and helpful examples
5. Click **Save Penalty Config** to apply changes

#### Time Period Weights

These control how the algorithm balances current state vs. historical trends:

- **Current Weight** (default: 0.5) - Weight for current resource usage
- **24h Weight** (default: 0.3) - Weight for 24-hour average usage
- **7d Weight** (default: 0.2) - Weight for 7-day average usage

**Must sum to 1.0.** The UI will show a validation indicator.

**Example Configurations:**

```
# Default (balanced view)
Current: 0.5, 24h: 0.3, 7d: 0.2

# Short-term focus (6-hour window)
Current: 0.6, 24h: 0.4, 7d: 0.0

# Historical focus
Current: 0.2, 24h: 0.5, 7d: 0.3
```

#### Penalty Values

All penalty values can be:
- Set to **0** to disable that penalty
- Increased to make the algorithm more sensitive to that condition
- Must be **non-negative** (>= 0)

Changes are saved to `config.json` under the `penalty_scoring` key and take effect immediately.

### Minimum Suitability Threshold

Configure in Web UI or `config.json`:

```json
{
  "automation": {
    "min_confidence_score": 75
  }
}
```

- **75%** (default) - Conservative, only high-quality targets
- **60%** - Moderate, allows more migrations
- **50%** - Aggressive, migrates even to suboptimal targets

### Understanding Trade-offs

**Higher threshold (80-90%):**
- Fewer automated migrations
- Only migrate to very good targets
- May leave some VMs on overloaded nodes
- Lower risk of making things worse

**Lower threshold (50-60%):**
- More automated migrations
- Willing to use suboptimal targets
- Better evacuation success rate
- Higher risk of suboptimal placement

---

## Summary

ProxBalance's penalty-based scoring system provides:

1. **Flexibility** - No hard disqualifications allow intelligent decisions in all scenarios
2. **Transparency** - Clear Suitability Ratings (0-100%) are easy to understand
3. **Comprehensive Analysis** - Multiple factors considered: CPU, memory, IOWait, distribution, storage, affinity
4. **Safety** - High penalties for dangerous conditions without blocking emergency evacuations
5. **Automation-Ready** - Seamlessly integrates with automated migration system

The system balances competing priorities to find the best migration target while ensuring cluster stability and respecting user-defined constraints.

---

[⬆ Back to Documentation](README.md)
