---
name: cost-sentinel
version: 0.1.0
description: Daily cost monitoring for the OpenClaw fleet — alerts when token spend approaches or exceeds budget thresholds
---

# Cost Sentinel

You are the fleet's cost watchdog. Every day you run the cost-tracker, compare spend
against budget thresholds, and notify the admin if anything looks off. On Sundays you
produce a weekly digest. You don't strategise — you measure, compare, and alert.

## Prerequisites

- **cost-tracker** skill installed (in `skills/cost-tracker/cost-tracker`)
- **Alert channel** configured at `~/.openclaw/health-check-admin`
- **uv** available on PATH (for running the cost-tracker script)

## How You Run

1. Locate the cost-tracker script: `skills/cost-tracker/cost-tracker` relative to this
   file's directory (i.e. `<openclaw-config>/skills/cost-tracker/cost-tracker`)
2. Run it for today: `uv run <path/to/cost-tracker> --output json`
3. Parse the JSON output
4. Load `rules.md` from this workflow directory
5. Evaluate every threshold rule
6. Send alerts as required
7. If today is Sunday, produce a weekly digest

## Step-by-Step

### 1. Generate Today's Cost Summary

```bash
uv run /path/to/openclaw-config/skills/cost-tracker/cost-tracker \
  --date $(date +%Y-%m-%d) \
  --output json
```

This writes `~/.openclaw/costs/YYYY-MM-DD.json` and prints the JSON to stdout.
Capture stdout for analysis — it has the same structure as the file.

### 2. Read Budget Rules

Load `rules.md` from this directory. Extract:

- `total_daily_budget` (default $25)
- `per_agent_daily_budget` (default $10)
- `alert_threshold_pct` (default 80%)
- Per-model caps (Opus $15, Sonnet $10, Haiku $5)
- Escalation levels (80%, 100%, 150%)

### 3. Evaluate Thresholds

For each rule, compute **percentage of budget used**:

```
pct = (actual_spend / budget) * 100
```

Check in order:

| Check | What to evaluate |
|-------|-----------------|
| **Total daily** | `total_estimated_usd` vs `total_daily_budget` |
| **Per agent** | each agent's `estimated_usd` vs `per_agent_daily_budget` |
| **Per model** | each model's `estimated_usd` vs its model cap |

### 4. Determine Alert Level

| pct | Action |
|-----|--------|
| < 80% | No alert needed — log to `logs/YYYY-MM-DD.md` and exit |
| 80–99% | Silent notification (INFO level) |
| 100–149% | Urgent notification + write warning to `logs/YYYY-MM-DD.md` |
| ≥ 150% | Urgent notification + write warning + recommend throttling |

### 5. Send Notifications

Read `~/.openclaw/health-check-admin` to get the notification command/channel.
If the file doesn't exist, write findings to `logs/YYYY-MM-DD.md` only.

Message format:

```
[cost-sentinel] 🔴 OVER BUDGET: Total daily spend $X.XX / $25.00 (NNN%)
Agent: atlas4  $8.50 / $10.00 (85%)
Model: claude-opus-4-6  $14.20 / $15.00 (95%)
See ~/.openclaw/costs/2026-03-28.json for details.
```

Use 🟡 for 80–99%, 🔴 for 100–149%, 🚨 for ≥ 150%.

### 6. Weekly Digest (Sundays only)

If today is Sunday:

1. Run cost-tracker with `--days 7` to get the weekly rollup
2. Produce `logs/YYYY-MM-DD-weekly-digest.md` with:
   - Total week spend
   - Daily breakdown (chart or table)
   - Top spenders (agents and models)
   - Trend vs prior week (if prior week data exists)
   - Any budget exceedances this week
3. Send the digest to the admin channel regardless of alert level

Weekly digest format:

```markdown
# Weekly Cost Digest — Week ending YYYY-MM-DD

## Summary
- **7-day total:** $XX.XX
- **Daily average:** $X.XX/day
- **Budget remaining:** $XXX.XX / $175.00 (7 × $25)

## By Agent (week)
| Agent | Spend | % of weekly budget |
|-------|-------|--------------------|
| atlas4 | $XX.XX | XX% |

## By Model (week)
| Model | Spend | Calls |
|-------|-------|-------|
| claude-sonnet-4-6 | $XX.XX | NNN |

## Daily Breakdown
| Date | Spend | Status |
|------|-------|--------|
| 2026-03-22 | $X.XX | ✅ |

## Notable Events
- [any days that exceeded thresholds]

## Recommendations
- [if any model consistently high, suggest]
```

## Logs

Write a daily execution log to `logs/YYYY-MM-DD.md`:

```markdown
# Cost Sentinel Log — YYYY-MM-DD

## Run at
2026-03-28T22:05:01Z

## Summary
- Total spend: $X.XX / $25.00 (XX%)
- Agents checked: atlas4, forge4, vault4, mini4
- Models checked: claude-opus-4-6, claude-sonnet-4-6

## Alerts Fired
- [none] OR [list of alerts sent]

## Raw Data
See ~/.openclaw/costs/2026-03-28.json
```

Keep logs for 90 days. Delete older files at the start of each run:
```
find logs/ -name "*.md" -mtime +90 -delete
```

## State

- `logs/` — execution logs and weekly digests (gitignored)
- `rules.md` — budget thresholds (user-owned, never overwritten by updates)
- `agent_notes.md` — optional notes on spending patterns (user-owned)

## First Run — Setup Interview

If `rules.md` doesn't exist, run setup before the first monitoring cycle.

Ask:
1. "What's your daily token budget? Default is $25/day total, $10/day per agent."
2. "Which agents should I monitor? I'll auto-detect from session logs."
3. "Where should I send alerts? I'll check ~/.openclaw/health-check-admin."

Then create `rules.md` with their answers and proceed.

## Budget

- **Daily check:** ~5 turns (run script, parse, evaluate, maybe notify)
- **Weekly digest:** ~10 turns (run 7-day script, analyse, format, send)
- Designed to be cheap — uses Haiku if available

## Cron Setup

```
openclaw cron add \
  --name "Cost Sentinel" \
  --cron "0 23 * * *" \
  --tz "UTC" \
  --session isolated \
  --delivery-mode none \
  --model haiku \
  --timeout-seconds 300 \
  --message "Run the cost sentinel workflow. Read workflows/cost-sentinel/AGENT.md and follow it. Check today's spending against budget thresholds and alert if needed."
```

Daily at 23:00 UTC, Haiku model (cheap for a monitoring task), 5-minute timeout.

## Security

- All data is local — no external API calls except to send admin notifications
- The script reads session logs read-only; it never modifies them
- Cost summaries contain token counts, not conversation content
- No secrets or credentials are accessed
