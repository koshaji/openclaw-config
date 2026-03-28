#!/usr/bin/env bash
# watchdog-notify.sh — systemd watchdog ping helper (Linux)
#
# Runs in background after gateway start, periodically pinging the health
# endpoint and notifying systemd watchdog. Use this when the gateway process
# does not natively support sd_notify.
#
# Usage in openclaw-gateway.service:
#   ExecStartPost=/opt/openclaw/scripts/watchdog-notify.sh
#
# Requires systemd-notify to be available (part of systemd).
# WatchdogSec must be set in the service unit (e.g. WatchdogSec=60).

set -euo pipefail

HEALTH_URL="http://127.0.0.1:18789/healthz"
# Ping interval: half of WatchdogSec to stay comfortably within the window
PING_INTERVAL=25
STARTUP_WAIT=10

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [watchdog-notify] $*" >&2
}

# Wait for gateway to start accepting requests
log "Waiting ${STARTUP_WAIT}s for gateway startup..."
sleep "$STARTUP_WAIT"

# Signal systemd that the service is ready (if Type=notify)
systemd-notify --ready 2>/dev/null || true
log "Sent READY=1 to systemd"

# Main watchdog loop
while true; do
    if curl -sf --max-time 5 "$HEALTH_URL" > /dev/null 2>&1; then
        # Health check passed — ping systemd watchdog
        systemd-notify WATCHDOG=1 2>/dev/null || true
        log "Health OK, watchdog pinged"
    else
        # Health check failed — do NOT ping systemd
        # systemd will kill and restart the service when WatchdogSec expires
        log "Health check FAILED — not pinging watchdog (systemd will restart)"
    fi

    sleep "$PING_INTERVAL"
done
