#!/usr/bin/env bash
# config-rollback.sh — OpenClaw config backup, list, and restore utility
#
# Usage:
#   config-rollback.sh backup           — take a timestamped backup now
#   config-rollback.sh list             — list available backups
#   config-rollback.sh restore <name>   — restore a specific backup
#   config-rollback.sh restore latest   — restore the most recent backup
#
# Backups are stored in ~/.openclaw/config-backups/
# Only the 5 most recent backups are kept.

set -euo pipefail

CONFIG_FILE="${HOME}/.openclaw/openclaw.json"
BACKUP_DIR="${HOME}/.openclaw/config-backups"
MAX_BACKUPS=5

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [config-rollback] $*"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Ensure backup dir exists
mkdir -p "$BACKUP_DIR"

# ── Subcommands ─────────────────────────────────────────────────────────────

cmd_backup() {
    [[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"

    TIMESTAMP=$(date +%s)
    BACKUP_PATH="${BACKUP_DIR}/openclaw.json.${TIMESTAMP}"

    cp "$CONFIG_FILE" "$BACKUP_PATH"
    log "Backup created: $BACKUP_PATH"

    # Prune: keep only the most recent MAX_BACKUPS
    BACKUP_COUNT=$(find "$BACKUP_DIR" -name 'openclaw.json.*' | wc -l | tr -d ' ')
    if [[ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]]; then
        EXCESS=$((BACKUP_COUNT - MAX_BACKUPS))
        log "Pruning $EXCESS old backup(s) (keeping last $MAX_BACKUPS)..."
        find "$BACKUP_DIR" -name 'openclaw.json.*' \
            | sort \
            | head -n "$EXCESS" \
            | xargs rm -f
        log "Pruning complete"
    fi
}

cmd_list() {
    BACKUPS=$(find "$BACKUP_DIR" -name 'openclaw.json.*' | sort -r 2>/dev/null || true)

    if [[ -z "$BACKUPS" ]]; then
        echo "No backups found in $BACKUP_DIR"
        exit 0
    fi

    echo "Available backups (newest first):"
    echo ""
    INDEX=1
    while IFS= read -r BACKUP; do
        BASENAME=$(basename "$BACKUP")
        EPOCH=$(echo "$BASENAME" | sed 's/openclaw\.json\.//')
        # Format timestamp if it looks like a unix epoch
        if [[ "$EPOCH" =~ ^[0-9]+$ ]]; then
            HUMAN=$(date -r "$EPOCH" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d "@${EPOCH}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
            echo "  $INDEX. $BASENAME  ($HUMAN)"
        else
            echo "  $INDEX. $BASENAME"
        fi
        INDEX=$((INDEX + 1))
    done <<< "$BACKUPS"
    echo ""
}

cmd_restore() {
    local TARGET="${1:-}"
    [[ -n "$TARGET" ]] || die "Usage: config-rollback.sh restore <name|latest>"

    local BACKUP_PATH
    if [[ "$TARGET" == "latest" ]]; then
        BACKUP_PATH=$(find "$BACKUP_DIR" -name 'openclaw.json.*' | sort | tail -n 1)
        [[ -n "$BACKUP_PATH" ]] || die "No backups found in $BACKUP_DIR"
    else
        BACKUP_PATH="${BACKUP_DIR}/${TARGET}"
        # Also accept bare timestamp or full path
        [[ -f "$BACKUP_PATH" ]] || BACKUP_PATH="$TARGET"
        [[ -f "$BACKUP_PATH" ]] || die "Backup not found: $TARGET"
    fi

    log "Restoring from: $BACKUP_PATH"

    # Safety backup of current config before overwriting
    if [[ -f "$CONFIG_FILE" ]]; then
        SAFETY_BACKUP="${BACKUP_DIR}/openclaw.json.pre-restore.$(date +%s)"
        cp "$CONFIG_FILE" "$SAFETY_BACKUP"
        log "Safety backup of current config: $SAFETY_BACKUP"
    fi

    cp "$BACKUP_PATH" "$CONFIG_FILE"
    log "Config restored to: $CONFIG_FILE"

    # Restart gateway
    log "Restarting gateway..."
    if command -v launchctl &>/dev/null; then
        # macOS
        USER_UID=$(id -u)
        launchctl kickstart -k "gui/${USER_UID}/ai.openclaw.gateway" 2>&1 \
            && log "Gateway restarted via launchctl" \
            || log "WARNING: launchctl restart failed — restart manually"
    elif command -v systemctl &>/dev/null; then
        # Linux
        systemctl --user restart openclaw-gateway 2>&1 \
            && log "Gateway restarted via systemctl" \
            || log "WARNING: systemctl restart failed — restart manually"
    else
        log "WARNING: Could not detect init system. Please restart the gateway manually."
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
    backup)  cmd_backup ;;
    list)    cmd_list ;;
    restore) cmd_restore "${1:-}" ;;
    "")
        echo "Usage: config-rollback.sh <backup|list|restore>"
        echo ""
        echo "  backup           — take a timestamped backup of openclaw.json"
        echo "  list             — list available backups"
        echo "  restore <name>   — restore a specific backup by filename"
        echo "  restore latest   — restore the most recent backup"
        exit 1
        ;;
    *)
        die "Unknown command: $COMMAND. Use backup, list, or restore."
        ;;
esac
