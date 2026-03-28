#!/usr/bin/env bash
# audit-rotate.sh — OpenClaw audit log rotation
#
# Actions:
#   1. Compress audit files older than 30 days (gzip)
#   2. Delete compressed files older than 90 days
#   3. Report disk usage of audit directory
#
# Run daily via cron or systemd timer:
#   0 2 * * * /opt/openclaw/scripts/audit-rotate.sh >> /tmp/audit-rotate.log 2>&1

set -euo pipefail

AUDIT_DIR="${HOME}/.openclaw/audit"
COMPRESS_AFTER_DAYS=30
DELETE_AFTER_DAYS=90

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [audit-rotate] $*"
}

# Nothing to do if audit dir doesn't exist
if [[ ! -d "$AUDIT_DIR" ]]; then
    log "Audit directory not found: $AUDIT_DIR — nothing to do"
    exit 0
fi

log "Starting audit log rotation in $AUDIT_DIR"

# ── Step 1: Compress files older than COMPRESS_AFTER_DAYS ───────────────────

log "Compressing .jsonl files older than ${COMPRESS_AFTER_DAYS} days..."

COMPRESSED_COUNT=0
while IFS= read -r -d '' FILE; do
    if gzip -f "$FILE"; then
        log "  Compressed: $(basename "$FILE")"
        COMPRESSED_COUNT=$((COMPRESSED_COUNT + 1))
    else
        log "  WARNING: Failed to compress: $FILE"
    fi
done < <(find "$AUDIT_DIR" -maxdepth 1 -name '*.jsonl' \
    -not -name '*.gz' \
    -mtime "+${COMPRESS_AFTER_DAYS}" \
    -print0 2>/dev/null)

if [[ "$COMPRESSED_COUNT" -gt 0 ]]; then
    log "Compressed $COMPRESSED_COUNT file(s)"
else
    log "No files needed compression"
fi

# ── Step 2: Delete compressed files older than DELETE_AFTER_DAYS ────────────

log "Deleting .jsonl.gz files older than ${DELETE_AFTER_DAYS} days..."

DELETED_COUNT=0
while IFS= read -r -d '' FILE; do
    rm -f "$FILE"
    log "  Deleted: $(basename "$FILE")"
    DELETED_COUNT=$((DELETED_COUNT + 1))
done < <(find "$AUDIT_DIR" -maxdepth 1 -name '*.jsonl.gz' \
    -mtime "+${DELETE_AFTER_DAYS}" \
    -print0 2>/dev/null)

if [[ "$DELETED_COUNT" -gt 0 ]]; then
    log "Deleted $DELETED_COUNT file(s)"
else
    log "No files needed deletion"
fi

# ── Step 3: Report disk usage ────────────────────────────────────────────────

log "Audit directory disk usage:"

# Total
TOTAL=$(du -sh "$AUDIT_DIR" 2>/dev/null | cut -f1)
log "  Total: $TOTAL"

# Breakdown by type
JSONL_COUNT=$(find "$AUDIT_DIR" -maxdepth 1 -name '*.jsonl' -not -name '*.gz' 2>/dev/null | wc -l | tr -d ' ')
GZ_COUNT=$(find "$AUDIT_DIR" -maxdepth 1 -name '*.jsonl.gz' 2>/dev/null | wc -l | tr -d ' ')

log "  Files: ${JSONL_COUNT} uncompressed, ${GZ_COUNT} compressed"

# Oldest and newest files
OLDEST=$(find "$AUDIT_DIR" -maxdepth 1 \( -name '*.jsonl' -o -name '*.jsonl.gz' \) \
    2>/dev/null | sort | head -n 1)
NEWEST=$(find "$AUDIT_DIR" -maxdepth 1 \( -name '*.jsonl' -o -name '*.jsonl.gz' \) \
    2>/dev/null | sort | tail -n 1)

if [[ -n "$OLDEST" ]]; then
    log "  Oldest: $(basename "$OLDEST")"
fi
if [[ -n "$NEWEST" ]]; then
    log "  Newest: $(basename "$NEWEST")"
fi

log "Rotation complete"
