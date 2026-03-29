#!/usr/bin/env bash
# watchdog.sh — OpenClaw gateway health watchdog (macOS/launchd)
#
# Checks the gateway health endpoint. If it fails 3 consecutive times,
# force-restarts the gateway via launchctl.
#
# Designed to run every 60s via ai.openclaw.watchdog.plist.
# Logs to /tmp/openclaw-watchdog.log (captured by the plist).

set -euo pipefail

HEALTH_URL="http://127.0.0.1:18789/healthz"
GATEWAY_LABEL="ai.openclaw.gateway"
FAIL_THRESHOLD=3
STATE_FILE="/tmp/openclaw-watchdog-fails"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [watchdog] $*"
}

# Read current consecutive failure count
read_fails() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "0"
    fi
}

# Write failure count
write_fails() {
    echo "$1" > "$STATE_FILE"
}

# Attempt health check
if curl -sf --max-time 5 "$HEALTH_URL" > /dev/null 2>&1; then
    log "Health check OK"
    write_fails 0
    exit 0
fi

# Health check failed
current_fails=$(read_fails)
new_fails=$((current_fails + 1))
write_fails "$new_fails"

log "Health check FAILED (consecutive failures: $new_fails / $FAIL_THRESHOLD)"

if [[ "$new_fails" -lt "$FAIL_THRESHOLD" ]]; then
    log "Below threshold ($FAIL_THRESHOLD), waiting for next cycle"
    exit 0
fi

# Threshold reached — force restart
log "ALERT: $FAIL_THRESHOLD consecutive failures. Force-restarting gateway..."

# Get current user UID for launchctl (user services need gui/<uid>)
USER_UID=$(id -u)

if launchctl kickstart -k "gui/${USER_UID}/${GATEWAY_LABEL}" 2>&1; then
    log "Gateway restarted via launchctl kickstart"
    write_fails 0
else
    log "ERROR: launchctl kickstart failed. Manual intervention may be required."
    exit 1
fi
