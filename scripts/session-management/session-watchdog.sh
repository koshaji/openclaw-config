#!/usr/bin/env bash
# session-watchdog.sh — Detect and clean stale OpenClaw sessions
#
# Adapted from unisone/openclaw-config production hardening patterns.
# Run periodically (every 30 min) to prevent session accumulation.
#
# Usage:
#   ./session-watchdog.sh              # Dry run (default)
#   ./session-watchdog.sh --kill       # Actually terminate stale sessions
#
# Configuration via environment variables:
#   MAX_AGE_HOURS     Max session age before considered stale (default: 2)
#   MAX_MEM_MB        Max memory per session before flagged (default: 512)
#   LOG_FILE          Where to write log output (default: ~/.openclaw/logs/session-watchdog.log)

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
readonly MAX_AGE_HOURS="${MAX_AGE_HOURS:-2}"
readonly MAX_MEM_MB="${MAX_MEM_MB:-512}"
readonly LOG_FILE="${LOG_FILE:-$HOME/.openclaw/logs/session-watchdog.log}"
readonly OPENCLAW="${OPENCLAW:-openclaw}"
readonly DRY_RUN="${DRY_RUN:-true}"

# Parse arguments
KILL_SESSIONS=false
for arg in "$@"; do
    case "$arg" in
        --kill) KILL_SESSIONS=true ;;
        --dry-run) ;;  # default
        --help|-h)
            echo "Usage: $0 [--kill] [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --kill      Terminate stale sessions (default: dry run)"
            echo "  --dry-run   Print what would be done without acting (default)"
            echo ""
            echo "Environment:"
            echo "  MAX_AGE_HOURS  Max session age in hours (default: 2)"
            echo "  MAX_MEM_MB     Max memory per session in MB (default: 512)"
            exit 0
            ;;
    esac
done

# ── Utilities ─────────────────────────────────────────────────────────────────
now_ts() { date +%s; }

log() {
    local level="$1"; shift
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [session-watchdog] [$level] $*" | tee -a "$LOG_FILE"
}

# ── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LOG_FILE")"

log "INFO" "Starting session watchdog (kill=$KILL_SESSIONS, max_age=${MAX_AGE_HOURS}h, max_mem=${MAX_MEM_MB}MB)"

# ── Check openclaw CLI availability ───────────────────────────────────────────
if ! command -v "$OPENCLAW" &>/dev/null; then
    log "ERROR" "openclaw CLI not found in PATH: $PATH"
    exit 1
fi

# ── Get session list ───────────────────────────────────────────────────────────
SESSIONS_OUTPUT=""
if ! SESSIONS_OUTPUT=$("$OPENCLAW" sessions list --json 2>/dev/null); then
    # Fallback: try without --json flag
    SESSIONS_OUTPUT=$("$OPENCLAW" sessions list 2>/dev/null) || {
        log "WARN" "Could not list sessions (openclaw sessions list failed). Skipping."
        exit 0
    }
fi

if [ -z "$SESSIONS_OUTPUT" ]; then
    log "INFO" "No sessions found."
    exit 0
fi

# ── Parse and evaluate sessions ───────────────────────────────────────────────
STALE_COUNT=0
TOTAL_COUNT=0
NOW=$(now_ts)
MAX_AGE_SECS=$((MAX_AGE_HOURS * 3600))

# Try JSON parsing first, fall back to line parsing
if echo "$SESSIONS_OUTPUT" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    # JSON output path
    while IFS= read -r session_json; do
        [ -z "$session_json" ] && continue
        TOTAL_COUNT=$((TOTAL_COUNT + 1))

        SESSION_ID=$(echo "$session_json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('id','unknown'))" 2>/dev/null || echo "unknown")
        CREATED_AT=$(echo "$session_json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('createdAt','0'))" 2>/dev/null || echo "0")
        MEM_MB=$(echo "$session_json" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('memoryMB','0'))" 2>/dev/null || echo "0")

        # Parse created_at timestamp
        if [[ "$CREATED_AT" =~ ^[0-9]+$ ]]; then
            AGE_SECS=$((NOW - CREATED_AT))
        else
            AGE_SECS=0
        fi

        AGE_HOURS=$((AGE_SECS / 3600))
        STALE=false

        if [ "$AGE_SECS" -gt "$MAX_AGE_SECS" ]; then
            STALE=true
            log "WARN" "Session $SESSION_ID is stale (age: ${AGE_HOURS}h, threshold: ${MAX_AGE_HOURS}h)"
        fi

        if [ "$(echo "$MEM_MB > $MAX_MEM_MB" | bc -l 2>/dev/null || echo 0)" -eq 1 ] 2>/dev/null; then
            STALE=true
            log "WARN" "Session $SESSION_ID exceeds memory threshold (${MEM_MB}MB > ${MAX_MEM_MB}MB)"
        fi

        if [ "$STALE" = "true" ]; then
            STALE_COUNT=$((STALE_COUNT + 1))
            if [ "$KILL_SESSIONS" = "true" ]; then
                log "INFO" "Terminating stale session $SESSION_ID"
                if "$OPENCLAW" sessions kill "$SESSION_ID" 2>/dev/null; then
                    log "INFO" "Terminated session $SESSION_ID"
                else
                    log "ERROR" "Failed to terminate session $SESSION_ID"
                fi
            else
                log "INFO" "[DRY RUN] Would terminate session $SESSION_ID"
            fi
        fi
    done < <(echo "$SESSIONS_OUTPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list):
    for s in data:
        print(json.dumps(s))
elif isinstance(data, dict) and 'sessions' in data:
    for s in data['sessions']:
        print(json.dumps(s))
" 2>/dev/null)
else
    # Plain text fallback — just count lines as a proxy for session count
    TOTAL_COUNT=$(echo "$SESSIONS_OUTPUT" | grep -c '\S' || echo 0)
    log "INFO" "Sessions output is not JSON. Total visible sessions: $TOTAL_COUNT"
    log "INFO" "Cannot evaluate individual session ages without JSON output."
    log "INFO" "Consider upgrading openclaw CLI for JSON session support."
fi

# ── Summary ───────────────────────────────────────────────────────────────────
log "INFO" "Watchdog complete: $TOTAL_COUNT sessions checked, $STALE_COUNT stale"

if [ "$STALE_COUNT" -gt 0 ] && [ "$KILL_SESSIONS" = "false" ]; then
    log "INFO" "Run with --kill to terminate stale sessions"
fi

exit 0
