# SKILL: audit-export — Audit Log Export and Analysis

Reads and filters structured audit logs from `~/.openclaw/audit/`.

## Usage

```bash
skills/audit-export/audit-export [OPTIONS]
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--date YYYY-MM-DD` | Filter to a specific date | — |
| `--days N` | Include the last N days (including today) | 1 |
| `--agent NAME` | Filter by agent name | all agents |
| `--action TYPE` | Filter by action type | all actions |
| `--format json\|csv\|text` | Output format | `json` |
| `--output /path/to/file` | Write to file instead of stdout | stdout |
| `--help` | Show help | — |

## Examples

```bash
# Show today's audit log (JSON, stdout)
skills/audit-export/audit-export

# Last 7 days
skills/audit-export/audit-export --days 7

# All auth denials in the last 30 days
skills/audit-export/audit-export --days 30 --action auth_denied

# Only forge4's actions today
skills/audit-export/audit-export --agent forge4

# Export last month as CSV
skills/audit-export/audit-export --days 30 --format csv --output ~/audit-march.csv

# Human-readable text format
skills/audit-export/audit-export --days 7 --format text

# Specific date
skills/audit-export/audit-export --date 2026-03-15
```

## Output Formats

### json (default)
One JSON object per line (JSONL passthrough):
```json
{"ts": 1743174000, "agent": "atlas4", "action": "skill_exec", "skill": "cost-tracker"}
{"ts": 1743174060, "agent": "atlas4", "action": "auth_denied", "sender": "telegram:999"}
```

### csv
Comma-separated with header row:
```
ts,agent,user,action,skill,result,reason
1743174000,atlas4,telegram:833846354,skill_exec,cost-tracker,success,
1743174060,atlas4,,auth_denied,,,user not in allowlist
```

### text
Human-readable, one event per line:
```
2026-03-28 22:00:00 [atlas4] skill_exec cost-tracker (user: telegram:833846354) → success
2026-03-28 22:01:00 [atlas4] auth_denied sender: telegram:999 — user not in allowlist
```

## Rotation

Audit files older than 30 days are compressed by `scripts/audit-rotate.sh`. The export tool reads both `.jsonl` and `.jsonl.gz` files transparently.

## Log Location

```
~/.openclaw/audit/YYYY-MM-DD.jsonl
~/.openclaw/audit/YYYY-MM-DD.jsonl.gz   ← compressed (>30 days old)
```

See `devops/audit-log.md` for the full audit log specification.
