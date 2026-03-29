#!/usr/bin/env bash
# audit-write.sh — Bash helper for writing structured audit log entries
#
# Usage: source this file, then call audit_log with 7 positional args:
#
#   source scripts/audit-write.sh
#   audit_log "atlas4" "telegram:833846354" "skill_exec" "cost-tracker" "--days 7" "success"
#
# Arguments:
#   $1  agent      — agent name (e.g. "atlas4")
#   $2  sender     — sender identity (e.g. "telegram:833846354")
#   $3  action     — action type (e.g. "skill_exec", "gateway_restart", "config_change")
#   $4  resource   — resource being acted on (e.g. "cost-tracker", "gateway")
#   $5  args       — arguments/parameters (use "" for none)
#   $6  result     — outcome: "success", "failure", "PERMIT", "DENY", etc.
#   $7  reason     — optional reason/details (use "" for none)
#
# Output:
#   Appends a JSON line to ~/.openclaw/audit/YYYY-MM-DD.jsonl
#   Uses UTC date for the filename to avoid timezone drift.
#
# Standard audit entry format matches devops/audit-log.md:
#   { ts, agent, sender, action, resource, args, result, reason }
#
# Example:
#   source /path/to/scripts/audit-write.sh
#   audit_log "mini4" "" "gateway_restart" "openclaw-gateway" "" "success" "scheduled maintenance"

OPENCLAW_AUDIT_DIR="${HOME}/.openclaw/audit"

audit_log() {
    local agent="${1:-unknown}"
    local sender="${2:-}"
    local action="${3:-unknown}"
    local resource="${4:-}"
    local args="${5:-}"
    local result="${6:-unknown}"
    local reason="${7:-}"

    # Create audit dir if needed
    mkdir -p "${OPENCLAW_AUDIT_DIR}" 2>/dev/null || return 1

    # Build today's log filename (UTC date)
    local today
    today=$(date -u '+%Y-%m-%d' 2>/dev/null || date '+%Y-%m-%d')
    local log_file="${OPENCLAW_AUDIT_DIR}/${today}.jsonl"

    # Get current UTC epoch timestamp
    local ts
    ts=$(date -u '+%s' 2>/dev/null || date '+%s')

    # Build JSON entry using printf to avoid quoting issues
    local entry
    entry=$(printf '{"ts":%d,"agent":"%s","sender":"%s","action":"%s","resource":"%s","args":"%s","result":"%s","reason":"%s"}' \
        "${ts}" \
        "${agent}" \
        "${sender}" \
        "${action}" \
        "${resource}" \
        "${args}" \
        "${result}" \
        "${reason}")

    # Append to daily log
    echo "${entry}" >> "${log_file}" 2>/dev/null || {
        echo "[audit-write] WARNING: could not write to ${log_file}" >&2
        return 1
    }
}
