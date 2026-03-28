# Structured Audit Log — Specification

This document defines the desired state for OpenClaw's structured audit logging system.

---

## Overview

All significant agent actions are logged to daily JSONL files. This enables:
- Security auditing (who did what, when)
- Debugging and replay
- Compliance and accountability
- Export and analysis tooling

---

## Log Location

```
~/.openclaw/audit/YYYY-MM-DD.jsonl
```

One file per day. Each line is a complete JSON object (newline-delimited JSON).

Example:
```
~/.openclaw/audit/2026-03-28.jsonl
~/.openclaw/audit/2026-03-29.jsonl
~/.openclaw/audit/2026-03-29.jsonl.gz   ← compressed after 30 days
```

---

## Log Format

Each entry is a JSON object on a single line:

```json
{"ts": 1743174000, "agent": "atlas4", "user": "telegram:833846354", "action": "skill_exec", "skill": "cost-tracker", "args": ["--days", "7"], "session": "abc123", "result": "success"}
{"ts": 1743174060, "agent": "atlas4", "user": "telegram:833846354", "action": "auth_denied", "reason": "user not in allowlist", "sender": "telegram:999999999"}
{"ts": 1743174120, "agent": "forge4", "user": "telegram:833846354", "action": "skill_exec", "skill": "gateway-restart", "args": [], "session": "def456", "result": "success"}
{"ts": 1743174180, "agent": "atlas4", "action": "gateway_start", "result": "success"}
{"ts": 1743174240, "agent": "vault4", "user": "telegram:833846354", "action": "secret_read", "skill": "1password", "session": "ghi789", "result": "success"}
```

---

## Field Reference

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `ts` | integer | Unix timestamp (seconds since epoch) |
| `agent` | string | Agent name (`atlas4`, `forge4`, `vault4`, `mini4`) |
| `action` | string | Action type (see Action Types below) |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `user` | string | Requester identity (`telegram:123456789`) |
| `skill` | string | Skill name invoked |
| `args` | array | CLI arguments passed to the skill |
| `session` | string | Session ID for correlating related events |
| `result` | string | Outcome: `success`, `error`, `timeout` |
| `reason` | string | Human-readable reason (especially for denials/errors) |
| `sender` | string | Original sender identity (for auth events) |
| `error` | string | Error message if `result` is `error` |
| `duration_ms` | integer | Execution duration in milliseconds |

---

## Action Types

| Action | Description |
|--------|-------------|
| `skill_exec` | A skill was invoked |
| `skill_error` | A skill failed with an error |
| `auth_denied` | A request was denied by the allowlist |
| `auth_permitted` | A request was explicitly permitted (high-value ops) |
| `gateway_start` | Gateway process started |
| `gateway_stop` | Gateway process stopped |
| `gateway_restart` | Gateway was restarted |
| `config_change` | Config file was modified |
| `config_rollback` | Config was rolled back to a previous version |
| `secret_read` | A secret was accessed via Vault |
| `fleet_command` | A fleet command was received |
| `fleet_command_rejected` | A fleet command was rejected (bad signature, blocked op) |

---

## Writing Audit Entries

Agents write to the audit log by appending to the current day's file:

```python
import json, time
from pathlib import Path

def audit_log(agent: str, action: str, **kwargs):
    entry = {"ts": int(time.time()), "agent": agent, "action": action, **kwargs}
    audit_dir = Path.home() / ".openclaw" / "audit"
    audit_dir.mkdir(parents=True, exist_ok=True)
    date_str = time.strftime("%Y-%m-%d")
    log_file = audit_dir / f"{date_str}.jsonl"
    with log_file.open("a") as f:
        f.write(json.dumps(entry) + "\n")
```

Bash:
```bash
audit_log() {
    local entry="$1"
    local audit_dir="$HOME/.openclaw/audit"
    mkdir -p "$audit_dir"
    echo "$entry" >> "$audit_dir/$(date +%Y-%m-%d).jsonl"
}

audit_log "$(jq -n --arg ts "$(date +%s)" --arg agent "atlas4" --arg action "skill_exec" \
    '{ts: ($ts|tonumber), agent: $agent, action: $action}')"
```

---

## Rotation and Retention

Managed by `scripts/audit-rotate.sh`:

| Age | Action |
|-----|--------|
| < 30 days | Raw JSONL (uncompressed) |
| 30–90 days | Compressed (`.jsonl.gz`) |
| > 90 days | Deleted |

Run via cron or systemd timer:
```bash
# crontab: run at 2am daily
0 2 * * * /opt/openclaw/scripts/audit-rotate.sh >> /tmp/audit-rotate.log 2>&1
```

---

## Export and Analysis

Use the `audit-export` skill to query logs:

```bash
# Today's logs
skills/audit-export/audit-export

# Last 7 days, only skill_exec actions
skills/audit-export/audit-export --days 7 --action skill_exec

# Export to CSV
skills/audit-export/audit-export --days 30 --format csv --output /tmp/audit.csv

# Filter by agent
skills/audit-export/audit-export --agent atlas4 --days 7
```

See `skills/audit-export/SKILL.md` for full documentation.

---

## File Permissions

```bash
chmod 700 ~/.openclaw/audit
chmod 600 ~/.openclaw/audit/*.jsonl
```

Audit logs may contain sensitive information (user IDs, skill arguments). Keep them private.
