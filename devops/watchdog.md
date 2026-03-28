# Process Watchdog — Desired State Specification

This document defines the desired state for OpenClaw gateway process supervision on macOS and Linux.

---

## macOS (launchd)

### Built-in Restart (Phase 1 — already in place)

The main gateway plist (`~/Library/LaunchAgents/ai.openclaw.gateway.plist`) uses:

```xml
<key>KeepAlive</key>
<true/>
<key>ThrottleInterval</key>
<integer>5</integer>
```

launchd will automatically restart the gateway within 5 seconds if it exits for any reason.

### Verify It's Working

```bash
# Check if the gateway job is loaded and running
launchctl list | grep openclaw

# Expected output (PID non-zero = running):
# 12345   0   ai.openclaw.gateway

# If PID is "-", the job is loaded but not running (crashed):
# -       1   ai.openclaw.gateway
```

To manually force a restart:
```bash
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
```

### Companion Health Watchdog

For deeper health checking (beyond process-alive), a companion watchdog plist polls the HTTP health endpoint.

**File:** `devops/mac/ai.openclaw.watchdog.plist`  
**Script:** `scripts/watchdog.sh`

The watchdog runs every 60 seconds. If the health endpoint fails 3 consecutive times, it force-restarts the gateway via `launchctl kickstart -k`.

#### Install:

```bash
cp devops/mac/ai.openclaw.watchdog.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/ai.openclaw.watchdog.plist
```

#### Verify:

```bash
launchctl list | grep watchdog
# Should show ai.openclaw.watchdog with a non-zero PID
```

#### Logs:

```bash
tail -f /tmp/openclaw-watchdog.log
```

---

## Linux (systemd)

### Built-in Restart (Phase 1 — already in place)

The gateway service file (`devops/linux/openclaw-gateway.service`) includes:

```ini
[Service]
Restart=on-failure
RestartSec=5
WatchdogSec=60
```

systemd restarts the service within 5 seconds of failure.

### WatchdogSec and Type=notify

`WatchdogSec=60` tells systemd to kill and restart the service if it doesn't send a watchdog ping within 60 seconds. This requires the process to call `sd_notify("WATCHDOG=1")` periodically.

**If the gateway supports sd_notify natively:** Set `Type=notify` in the service file:

```ini
[Service]
Type=notify
WatchdogSec=60
```

**If the gateway does NOT support sd_notify:** Use the companion watchdog script instead:

Add to the service file:
```ini
[Service]
# Remove WatchdogSec (incompatible without sd_notify support)
# Instead, use the ExecStartPost watchdog helper:
ExecStartPost=/opt/openclaw/scripts/watchdog-notify.sh
```

The helper script (`scripts/watchdog-notify.sh`) polls the health endpoint and calls `systemd-notify WATCHDOG=1` on success.

#### Install watchdog-notify helper:

```bash
sudo cp scripts/watchdog-notify.sh /opt/openclaw/scripts/
sudo chmod +x /opt/openclaw/scripts/watchdog-notify.sh
sudo systemctl daemon-reload
sudo systemctl restart openclaw-gateway
```

#### Check watchdog status:

```bash
systemctl status openclaw-gateway
# Look for "Watchdog: 60s" in the output

journalctl -u openclaw-gateway -f
# Watch for watchdog pings and any restart events
```

---

## Config Rollback Mechanism

Before any config change, take a timestamped backup:

```bash
mkdir -p ~/.openclaw/config-backups
cp ~/.openclaw/openclaw.json ~/.openclaw/config-backups/openclaw.json.$(date +%s)
```

Keep only the last 5 backups (automatic cleanup in `config-rollback.sh`).

### Using config-rollback.sh

**List available backups:**
```bash
scripts/config-rollback.sh list
```

**Restore a specific backup:**
```bash
scripts/config-rollback.sh restore openclaw.json.1743174000
```

**Restore the most recent backup:**
```bash
scripts/config-rollback.sh restore latest
```

The script automatically restarts the gateway after restoring.

**Script:** `scripts/config-rollback.sh`

---

## Summary of Files

| File | Purpose |
|------|---------|
| `devops/mac/ai.openclaw.watchdog.plist` | macOS LaunchAgent for health watchdog |
| `scripts/watchdog.sh` | macOS health check + force-restart script |
| `scripts/watchdog-notify.sh` | Linux systemd watchdog ping helper |
| `scripts/config-rollback.sh` | Config backup, list, and restore utility |
