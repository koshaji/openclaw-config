# cost-tracker

Parse OpenClaw session logs to estimate token costs by agent and model.

## Usage

```
cost-tracker [--date YYYY-MM-DD] [--days N] [--agent NAME] [--output json|text]
```

### Arguments

| Flag | Default | Description |
|------|---------|-------------|
| `--date` | today | Generate summary for a specific date |
| `--days N` | — | Summarize the last N days (overrides `--date`) |
| `--agent NAME` | all | Filter output to a single agent |
| `--output` | text | Output format: `text` (human-readable) or `json` |

### Examples

```bash
# Today's spend — pretty printed
cost-tracker

# Yesterday
cost-tracker --date 2026-03-27

# Last 7-day rollup
cost-tracker --days 7

# Single agent, JSON output
cost-tracker --agent atlas4 --output json
```

## Output

### Text (default)

```
Cost Summary — 2026-03-28
═══════════════════════════════════════
By Agent:
  atlas4      $2.34  (120K in / 18K out)
  forge4      $0.89  (40K in / 12K out)

By Model:
  claude-opus-4-6    $2.10  12 calls
  claude-sonnet-4-6  $1.13  28 calls

Total: $3.23
═══════════════════════════════════════
```

### JSON

Written to `~/.openclaw/costs/YYYY-MM-DD.json`:

```json
{
  "date": "2026-03-28",
  "by_agent": {
    "atlas4": {
      "input_tokens": 120000,
      "output_tokens": 18000,
      "cache_read_tokens": 95000,
      "cache_write_tokens": 15000,
      "calls": 8,
      "estimated_usd": 2.34
    }
  },
  "by_model": {
    "anthropic/claude-opus-4-6": {
      "calls": 12,
      "input_tokens": 50000,
      "output_tokens": 10000,
      "cache_read_tokens": 30000,
      "cache_write_tokens": 8000,
      "estimated_usd": 1.50
    }
  },
  "total_estimated_usd": 3.23,
  "generated_at": "2026-03-28T22:00:00Z"
}
```

## Pricing Config

Pricing is loaded from `~/.openclaw/costs/pricing.json`. If the file doesn't exist, it
is created automatically with default Anthropic prices.

```json
{
  "anthropic/claude-opus-4-6": {
    "input_per_1m": 15.0,
    "output_per_1m": 75.0,
    "cache_read_per_1m": 1.5,
    "cache_write_per_1m": 3.75
  }
}
```

All prices are **USD per 1 million tokens**.

To update pricing: edit `~/.openclaw/costs/pricing.json` directly. The file is never
overwritten once created (user-owned config).

## Data Source

Reads `~/.openclaw/agents/*/sessions/*.jsonl`. Each JSONL line may contain:

```json
{
  "usage": {
    "input": 1200,
    "output": 350,
    "cacheRead": 8000,
    "cacheWrite": 19000,
    "totalTokens": 28550
  },
  "provider": "anthropic",
  "modelId": "claude-sonnet-4-6",
  "timestamp": "2026-03-28T14:32:10Z"
}
```

Lines without a `usage` field are silently skipped. The agent name is inferred from the
directory path (`agents/<name>/sessions/`).

## Timestamp Handling

`timestamp` field in JSONL is used for date bucketing. If absent, the file's
modification time is used as a fallback. All times are treated as UTC.

## How to Call This Skill

In an agent or workflow context, invoke the script directly:

```bash
uv run /path/to/openclaw-config/skills/cost-tracker/cost-tracker --output json
```

Or if installed on PATH:

```bash
cost-tracker --output json
```

The script will print the summary to stdout and write the JSON summary file.

## First-Run Behaviour

On first run, cost-tracker:

1. Creates `~/.openclaw/costs/` directory
2. Creates `~/.openclaw/costs/pricing.json` with default Anthropic pricing
3. Scans all available session logs for the requested date(s)
4. Writes the summary JSON

## Notes for Workflows

- The cost-sentinel workflow calls this script nightly.
- The JSON output file is the canonical record — pass `--output json` from workflows.
- Exit code 0 = success; non-zero = error parsing or writing files.
