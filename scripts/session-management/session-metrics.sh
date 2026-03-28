#!/usr/bin/env bash
# session-metrics.sh — Capture OpenClaw session telemetry
#
# Appends a JSON line to ~/.openclaw/logs/session-metrics.jsonl with:
#   - Timestamp
#   - Session count
#   - Oldest/newest session ages
#   - Total and per-session memory usage
#   - Gateway status
#
# Usage:
#   ./session-metrics.sh
#   ./session-metrics.sh --print    # Also print to stdout
#
# Run every 5 minutes for meaningful trending data.

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
readonly METRICS_FILE="${METRICS_FILE:-$HOME/.openclaw/logs/session-metrics.jsonl}"
readonly LOG_FILE="${LOG_FILE:-$HOME/.openclaw/logs/session-metrics.log}"
readonly OPENCLAW="${OPENCLAW:-openclaw}"

PRINT_OUTPUT=false
for arg in "$@"; do
    case "$arg" in
        --print) PRINT_OUTPUT=true ;;
        --help|-h)
            echo "Usage: $0 [--print]"
            echo ""
            echo "Captures session metrics and appends to $METRICS_FILE"
            echo ""
            echo "Options:"
            echo "  --print    Also print the JSON line to stdout"
            exit 0
            ;;
    esac
done

# ── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$METRICS_FILE")"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [session-metrics] $*" >> "$LOG_FILE"
}

# ── Collect metrics ────────────────────────────────────────────────────────────
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EPOCH_TS=$(date +%s)
HOSTNAME=$(hostname -s 2>/dev/null || echo "unknown")

# Gateway status
GATEWAY_UP=false
GATEWAY_STATUS="unknown"
if "$OPENCLAW" gateway status &>/dev/null 2>&1; then
    GATEWAY_UP=true
    GATEWAY_STATUS="running"
else
    GATEWAY_STATUS="down"
fi

# Session data
SESSION_COUNT=0
OLDEST_AGE_SEC=0
NEWEST_AGE_SEC=0
TOTAL_MEM_MB=0

if SESSIONS_OUTPUT=$("$OPENCLAW" sessions list --json 2>/dev/null); then
    if echo "$SESSIONS_OUTPUT" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
        METRICS_JSON=$(echo "$SESSIONS_OUTPUT" | python3 -c "
import json, sys, time

data = json.load(sys.stdin)
sessions = data if isinstance(data, list) else data.get('sessions', [])

now = int(time.time())
count = len(sessions)
ages = []
mem_total = 0

for s in sessions:
    created = s.get('createdAt', 0)
    if isinstance(created, (int, float)) and created > 0:
        ages.append(now - int(created))
    mem = s.get('memoryMB', 0)
    if isinstance(mem, (int, float)):
        mem_total += mem

oldest = max(ages) if ages else 0
newest = min(ages) if ages else 0

print(json.dumps({
    'session_count': count,
    'oldest_age_sec': oldest,
    'newest_age_sec': newest,
    'total_mem_mb': round(mem_total, 1)
}))
" 2>/dev/null || echo '{"session_count":0,"oldest_age_sec":0,"newest_age_sec":0,"total_mem_mb":0}')

        SESSION_COUNT=$(echo "$METRICS_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('session_count',0))" 2>/dev/null || echo 0)
        OLDEST_AGE_SEC=$(echo "$METRICS_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('oldest_age_sec',0))" 2>/dev/null || echo 0)
        NEWEST_AGE_SEC=$(echo "$METRICS_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('newest_age_sec',0))" 2>/dev/null || echo 0)
        TOTAL_MEM_MB=$(echo "$METRICS_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('total_mem_mb',0))" 2>/dev/null || echo 0)
    else
        # Fallback: count lines
        SESSION_COUNT=$(echo "$SESSIONS_OUTPUT" | grep -c '\S' || echo 0)
    fi
fi

# System memory snapshot (if available)
SYS_MEM_JSON="{}"
if command -v free &>/dev/null; then
    SYS_MEM_JSON=$(free -m 2>/dev/null | awk '/^Mem:/ {
        printf "{\"total_mb\":%d,\"used_mb\":%d,\"free_mb\":%d}", $2, $3, $4
    }' || echo "{}")
fi

# ── Build output JSON ──────────────────────────────────────────────────────────
OUTPUT=$(python3 -c "
import json

record = {
    'ts': '$TIMESTAMP',
    'epoch': $EPOCH_TS,
    'host': '$HOSTNAME',
    'gateway_up': $GATEWAY_UP,
    'gateway_status': '$GATEWAY_STATUS',
    'sessions': {
        'count': $SESSION_COUNT,
        'oldest_age_sec': $OLDEST_AGE_SEC,
        'newest_age_sec': $NEWEST_AGE_SEC,
        'total_mem_mb': $TOTAL_MEM_MB
    },
    'system_memory': $SYS_MEM_JSON
}

print(json.dumps(record))
" 2>/dev/null || echo "{\"ts\":\"$TIMESTAMP\",\"epoch\":$EPOCH_TS,\"error\":\"python3 unavailable\"}")

# ── Write to metrics file ──────────────────────────────────────────────────────
echo "$OUTPUT" >> "$METRICS_FILE"
log "Metrics captured: sessions=$SESSION_COUNT, gateway=$GATEWAY_STATUS, mem=${TOTAL_MEM_MB}MB"

if [ "$PRINT_OUTPUT" = "true" ]; then
    echo "$OUTPUT" | python3 -m json.tool 2>/dev/null || echo "$OUTPUT"
fi

exit 0
