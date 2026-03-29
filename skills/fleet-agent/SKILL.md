# fleet-agent

> **Status:** Phase 2 — Implemented
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 1 (Zero-SSH Fleet Operations)
> **Target:** Zero-SSH fleet command agent using inbox/outbox pattern with HMAC-SHA256 auth

## Overview

`fleet-agent` is a UV script that implements the fleet inbox/outbox pattern described in `devops/fleet-agent-security.md`. It allows the fleet commander (Atlas4) to issue commands to remote machines without SSH, by reading signed command files from a shared inbox directory.

## Security Model

See `devops/fleet-agent-security.md` for the full threat model. Key points:
- **Allowlist-only**: only operations explicitly permitted can be executed
- **HMAC-SHA256 signatures**: every command is signed; replayed or forged commands are rejected
- **Nonce tracking**: prevents replay attacks within a configurable time window
- **Audit log**: every operation (permitted or denied) is logged to `~/.openclaw/audit/`

## Usage

```bash
# Run as a daemon (polls inbox every 30s)
./skills/fleet-agent/fleet-agent daemon

# Process one command file
./skills/fleet-agent/fleet-agent process ~/.openclaw/fleet-inbox/cmd-abc123.json

# Check agent status
./skills/fleet-agent/fleet-agent status

# List pending commands
./skills/fleet-agent/fleet-agent list
```

## Inbox/Outbox Pattern

```
# On the fleet commander machine:
~/.openclaw/fleet-inbox/cmd-<uuid>.json   ← signed command files
~/.openclaw/fleet-outbox/result-<uuid>.json  ← results

# Command format (cmd-abc123.json):
{
  "id": "abc123",
  "ts": 1742000000,
  "nonce": "<random-hex>",
  "operation": "gateway_restart",
  "args": {},
  "hmac": "<sha256-hex>"
}
```

## Permitted Operations

Defined in `devops/fleet-agent.md`:
- `gateway_status` — read gateway health
- `gateway_restart` — graceful restart (wraps gateway-restart skill)
- `session_cleanup` — run session cleanup script
- `metrics_snapshot` — capture session metrics
- `config_get <key>` — read config value (read-only)

## Files

- `SKILL.md` — this file
- `fleet-agent` — UV script
- See also: `devops/fleet-agent.md`, `devops/fleet-agent-security.md`
