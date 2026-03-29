#!/usr/bin/env bash
# check-quotas.sh — Shell-based quota checker for cost-tracker integration
#
# > **Status:** Phase 2 — Stub
# > **Tracking:** GAP_CLOSING_PLAN.md, Gap 2 (Cost Visibility)
# > **Target:** Quick quota check for use in cron/heartbeat without Python
#
# This shell script wraps cost-tracker to check if daily/weekly costs
# exceed configured thresholds. Designed for use in cron jobs and
# heartbeat scripts where a full Python script would be too heavy.
#
# Usage:
#   ./check-quotas.sh              # Exit 0 if OK, 1 if over quota
#   ./check-quotas.sh --daily      # Check daily quota only
#   ./check-quotas.sh --weekly     # Check weekly quota only
#   DAILY_LIMIT=5.00 ./check-quotas.sh  # Override threshold
#
# Environment variables:
#   DAILY_LIMIT    Max USD per day (default: from ~/.openclaw/costs/rules.json)
#   WEEKLY_LIMIT   Max USD per week (default: from rules.json)
#   ALERT_CHANNEL  Channel to notify on threshold breach (e.g., telegram:833846354)
#
# TODO (Phase 2 completion):
#   - Read thresholds from ~/.openclaw/costs/rules.json
#   - Call cost-tracker --days 1 --json to get today's cost
#   - Compare against threshold
#   - Send alert via openclaw message if threshold exceeded

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
COST_TRACKER="${SCRIPT_DIR}/../skills/cost-tracker/cost-tracker"

if [[ ! -x "$COST_TRACKER" ]]; then
    # Try to find it on PATH
    COST_TRACKER="$(command -v cost-tracker 2>/dev/null || echo "")"
fi

if [[ -z "$COST_TRACKER" ]]; then
    echo "[check-quotas] ERROR: cost-tracker not found. Install it first." >&2
    exit 2
fi

echo "[check-quotas] This script is a stub — implementation pending Phase 2 completion"
echo "cost-tracker is available at: $COST_TRACKER"
echo "Run: $COST_TRACKER --days 1 to check today's costs"
exit 0
