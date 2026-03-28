# Session Management Scripts

Bash utilities for managing OpenClaw sessions. Adopted and adapted from
[`unisone/openclaw-config`](https://github.com/unisone/openclaw-config) production
hardening patterns.

## Scripts

### `session-watchdog.sh`

**Purpose:** Detect and clean stale or zombie sessions automatically.

**What it does:**
- Lists all active OpenClaw sessions via `openclaw sessions list`
- Identifies sessions exceeding the age threshold (default: 2 hours)
- Identifies sessions exceeding memory usage threshold (default: 512MB)
- Optionally terminates stale sessions (dry-run by default)

**Usage:**
```bash
# Dry run (see what would be cleaned, don't act)
./session-watchdog.sh

# Actually terminate stale sessions
./session-watchdog.sh --kill

# Custom thresholds
MAX_AGE_HOURS=4 MAX_MEM_MB=1024 ./session-watchdog.sh --kill
```

**Deployment:** Run every 30 minutes via cron or launchd alongside health checks.

---

### `session-metrics.sh`

**Purpose:** Capture session telemetry for monitoring and trending.

**What it does:**
- Counts active sessions
- Captures oldest and newest session ages
- Records total memory usage across all sessions
- Appends a JSON line to `~/.openclaw/logs/session-metrics.jsonl`

**Usage:**
```bash
./session-metrics.sh

# Read recent metrics
tail -10 ~/.openclaw/logs/session-metrics.jsonl | jq .
```

**Deployment:** Run every 5 minutes. Useful for detecting session leaks over time.

---

### `session-cleanup.sh`

**Purpose:** Force cleanup of all non-essential sessions for incident response.

**What it does:**
- Identifies and terminates all sessions except the most recent active one
- Can terminate ALL sessions (nuclear option — requires `--force-all`)
- Logs all terminated sessions for audit trail
- Sends notification if admin channel is configured

**Usage:**
```bash
# Terminate all stale/old sessions, keep newest active
./session-cleanup.sh

# NUCLEAR: terminate all sessions including active
./session-cleanup.sh --force-all

# Dry run
./session-cleanup.sh --dry-run
```

**When to use:**
- Gateway is slow or unresponsive
- Suspecting runaway session loops
- Incident response / security events
- Before a planned restart

---

## Installation

```bash
# Make scripts executable
chmod +x scripts/session-management/*.sh

# Optionally add to PATH
ln -s "$(pwd)/scripts/session-management/session-watchdog.sh" ~/.local/bin/openclaw-session-watchdog
ln -s "$(pwd)/scripts/session-management/session-metrics.sh" ~/.local/bin/openclaw-session-metrics
ln -s "$(pwd)/scripts/session-management/session-cleanup.sh" ~/.local/bin/openclaw-session-cleanup
```

## Cron/Launchd Setup

Add to your health check cron or create a dedicated timer:

```bash
# crontab -e — every 30 minutes
*/30 * * * * /path/to/scripts/session-management/session-watchdog.sh --kill >> ~/.openclaw/logs/session-watchdog.log 2>&1

# Every 5 minutes for metrics
*/5 * * * * /path/to/scripts/session-management/session-metrics.sh >> ~/.openclaw/logs/session-metrics.log 2>&1
```

## Log Files

| File | Content |
|------|---------|
| `~/.openclaw/logs/session-watchdog.log` | Watchdog runs and terminations |
| `~/.openclaw/logs/session-metrics.jsonl` | JSONL metrics snapshots |
| `~/.openclaw/logs/session-cleanup.log` | Cleanup runs and audit trail |

## Credits

Session management patterns adapted from
[`unisone/openclaw-config`](https://github.com/unisone/openclaw-config) v2026.02.27
production hardening guide.
