#!/usr/bin/env bash
# session-cleanup.sh — Force cleanup of OpenClaw sessions for incident response
#
# Terminates all sessions except the most recent active one.
# Use during incidents, before restarts, or when the gateway is struggling.
#
# Adapted from unisone/openclaw-config production hardening patterns.
#
# Usage:
#   ./session-cleanup.sh              # Terminate all old sessions, keep newest
#   ./session-cleanup.sh --force-all  # NUCLEAR: terminate ALL sessions
#   ./session-cleanup.sh --dry-run    # Preview without acting
#
# ⚠️  WARNING: --force-all will interrupt active agent conversations.
#     Use only during incidents or planned maintenance.

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
readonly LOG_FILE="${LOG_FILE:-$HOME/.openclaw/logs/session-cleanup.log}"
readonly AUDIT_FILE="${AUDIT_FILE:-$HOME/.openclaw/logs/session-cleanup-audit.jsonl}"
readonly OPENCLAW="${OPENCLAW:-openclaw}"

# Parse arguments
FORCE_ALL=false
DRY_RUN=false
REASON="manual-cleanup"

for arg in "$@"; do
    case "$arg" in
        --force-all)   FORCE_ALL=true ;;
        --dry-run)     DRY_RUN=true ;;
        --reason=*)    REASON="${arg#--reason=}" ;;
        --help|-h)
            echo "Usage: $0 [--force-all] [--dry-run] [--reason=<reason>]"
            echo ""
            echo "Options:"
            echo "  --force-all         Terminate ALL sessions including the newest active one"
            echo "  --dry-run           Preview what would be done without acting"
            echo "  --reason=<reason>   Log the reason for cleanup (default: manual-cleanup)"
            echo ""
            echo "Examples:"
            echo "  $0                               # Clean old sessions, keep newest"
            echo "  $0 --force-all                   # Full reset (incident response)"
            echo "  $0 --dry-run                     # Preview actions"
            echo "  $0 --reason=security-incident    # Cleanup with audit trail"
            exit 0
            ;;
    esac
done

# ── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$AUDIT_FILE")"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EPOCH_TS=$(date +%s)
HOSTNAME=$(hostname -s 2>/dev/null || echo "unknown")
OPERATOR="${USER:-unknown}"

log() {
    local level="$1"; shift
    local msg="$*"
    echo "$TIMESTAMP [session-cleanup] [$level] $msg" | tee -a "$LOG_FILE"
}

audit() {
    local action="$1"
    local session_id="${2:-unknown}"
    local detail="${3:-}"
    python3 -c "
import json
print(json.dumps({
    'ts': '$TIMESTAMP',
    'epoch': $EPOCH_TS,
    'host': '$HOSTNAME',
    'operator': '$OPERATOR',
    'reason': '$REASON',
    'action': '$action',
    'session_id': '$session_id',
    'detail': '$detail',
    'dry_run': $([ "$DRY_RUN" = "true" ] && echo "true" || echo "false")
}))
" 2>/dev/null >> "$AUDIT_FILE" || echo "{\"ts\":\"$TIMESTAMP\",\"action\":\"$action\",\"session_id\":\"$session_id\"}" >> "$AUDIT_FILE"
}

# ── Safety checks ─────────────────────────────────────────────────────────────
if [ "$FORCE_ALL" = "true" ] && [ "$DRY_RUN" = "false" ]; then
    log "WARN" "⚠️  --force-all requested. This will terminate ALL sessions including active ones."
    log "WARN" "Reason: $REASON"
    log "WARN" "Proceeding in 5 seconds... Ctrl+C to abort"
    sleep 5
fi

log "INFO" "Starting session cleanup (force_all=$FORCE_ALL, dry_run=$DRY_RUN, reason=$REASON)"
audit "cleanup_start" "all" "force_all=$FORCE_ALL dry_run=$DRY_RUN"

# ── Check openclaw CLI ─────────────────────────────────────────────────────────
if ! command -v "$OPENCLAW" &>/dev/null; then
    log "ERROR" "openclaw CLI not found"
    exit 1
fi

# ── Get sessions ───────────────────────────────────────────────────────────────
SESSIONS_OUTPUT=""
if ! SESSIONS_OUTPUT=$("$OPENCLAW" sessions list --json 2>/dev/null); then
    SESSIONS_OUTPUT=$("$OPENCLAW" sessions list 2>/dev/null) || {
        log "WARN" "Could not list sessions. Nothing to clean."
        audit "cleanup_complete" "all" "no_sessions_found"
        exit 0
    }
fi

if [ -z "$SESSIONS_OUTPUT" ]; then
    log "INFO" "No sessions found. Nothing to clean."
    audit "cleanup_complete" "all" "no_sessions"
    exit 0
fi

# ── Identify sessions to terminate ────────────────────────────────────────────
TERMINATED=0
SKIPPED=0
ERRORS=0

if echo "$SESSIONS_OUTPUT" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    # Get sorted session IDs (newest last)
    SESSIONS_TO_KILL=$(echo "$SESSIONS_OUTPUT" | python3 -c "
import json, sys

data = json.load(sys.stdin)
sessions = data if isinstance(data, list) else data.get('sessions', [])

# Sort by createdAt ascending (oldest first)
sessions.sort(key=lambda s: s.get('createdAt', 0))

ids = [s.get('id', '') for s in sessions if s.get('id')]
print('\n'.join(ids))
" 2>/dev/null)

    TOTAL_SESSIONS=$(echo "$SESSIONS_TO_KILL" | grep -c '\S' || echo 0)
    log "INFO" "Found $TOTAL_SESSIONS sessions"

    # Unless --force-all, keep the last (newest) session
    SESSIONS_LIST=()
    while IFS= read -r session_id; do
        [ -n "$session_id" ] && SESSIONS_LIST+=("$session_id")
    done <<< "$SESSIONS_TO_KILL"

    KEEP_NEWEST=""
    if [ "$FORCE_ALL" = "false" ] && [ "${#SESSIONS_LIST[@]}" -gt 0 ]; then
        KEEP_NEWEST="${SESSIONS_LIST[-1]}"
        log "INFO" "Will keep newest session: $KEEP_NEWEST"
    fi

    for session_id in "${SESSIONS_LIST[@]}"; do
        if [ "$FORCE_ALL" = "false" ] && [ "$session_id" = "$KEEP_NEWEST" ]; then
            log "INFO" "Keeping session $session_id (newest active)"
            SKIPPED=$((SKIPPED + 1))
            audit "session_kept" "$session_id" "newest_active"
            continue
        fi

        if [ "$DRY_RUN" = "true" ]; then
            log "INFO" "[DRY RUN] Would terminate session $session_id"
            audit "session_would_terminate" "$session_id" "dry_run"
            TERMINATED=$((TERMINATED + 1))
        else
            log "INFO" "Terminating session $session_id"
            if "$OPENCLAW" sessions kill "$session_id" 2>/dev/null; then
                log "INFO" "✓ Terminated session $session_id"
                audit "session_terminated" "$session_id" "success"
                TERMINATED=$((TERMINATED + 1))
            else
                log "ERROR" "✗ Failed to terminate session $session_id"
                audit "session_terminate_failed" "$session_id" "error"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    done
else
    log "WARN" "Session output is not JSON. Cannot identify individual sessions."
    log "WARN" "Manual cleanup may be required."
    TOTAL_SESSIONS="unknown"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
log "INFO" "Cleanup complete: terminated=$TERMINATED, skipped=$SKIPPED, errors=$ERRORS"
audit "cleanup_complete" "all" "terminated=$TERMINATED skipped=$SKIPPED errors=$ERRORS"

if [ "$DRY_RUN" = "true" ]; then
    log "INFO" "Dry run — no sessions were actually terminated"
fi

if [ "$ERRORS" -gt 0 ]; then
    log "WARN" "$ERRORS session(s) failed to terminate. Review gateway logs."
    exit 1
fi

exit 0
