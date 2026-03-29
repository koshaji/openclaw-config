# Fleet Agent — Desired State Spec

> **Status:** Phase 2
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 1 (Zero-SSH Fleet Operations)
> **Implements:** Security model from `devops/fleet-agent-security.md`

## Overview

The fleet agent enables zero-SSH management of remote machines. Instead of SSH, the fleet commander pushes signed command files to a shared inbox directory (e.g., Tailscale + synced folder, or a simple shared volume). The fleet agent on each machine polls the inbox, validates commands, executes permitted operations, and writes results to the outbox.

## Architecture

```
Fleet Commander (Atlas4)
    │
    │  Signs command with HMAC-SHA256
    ↓
~/.openclaw/fleet-inbox/cmd-<uuid>.json    ← command file
    │
    │  Fleet agent polls every 30s
    ↓
skills/fleet-agent/fleet-agent (running as daemon)
    │
    ├─ Validates HMAC signature
    ├─ Checks nonce freshness (reject if >5min old)
    ├─ Checks operation against allowlist
    ├─ Executes operation
    ├─ Writes audit log entry
    └─ Writes result
    ↓
~/.openclaw/fleet-outbox/result-<uuid>.json  ← result file
```

## Permitted Operations (Allowlist)

Only these operations may be executed. The list is intentionally narrow.

| Operation | Args | Risk | Notes |
|-----------|------|------|-------|
| `gateway_status` | none | Read | Returns health JSON |
| `gateway_restart` | `{force: bool}` | Low | Wraps gateway-restart skill |
| `session_cleanup` | `{dry_run: bool}` | Low | Runs session-cleanup.sh |
| `metrics_snapshot` | none | Read | Captures session-metrics.sh output |
| `config_get` | `{key: string}` | Read | Returns single config value |
| `security_audit` | none | Read | Runs security-setup check |
| `agent_version` | none | Read | Returns openclaw/agent version |

## Blocked Operations (Never Allowed)

These operations are explicitly blocked and cannot be enabled by any configuration:
- `exec` — arbitrary command execution
- `config_set` — writing config values
- `install` / `uninstall` — package operations
- `ssh` — SSH commands
- Any operation not in the allowlist

## Command File Format

```json
{
  "id": "abc123def456",
  "ts": 1742000000,
  "nonce": "a1b2c3d4e5f6",
  "operation": "gateway_restart",
  "args": {"force": false},
  "hmac": "sha256-hex-of-id+ts+nonce+operation+args"
}
```

## HMAC Signature

The HMAC-SHA256 key is stored in `~/.openclaw/.env` as `FLEET_SHARED_KEY`.
It must match on both the commander and agent machines.

```
HMAC input = id + ":" + ts + ":" + nonce + ":" + operation + ":" + json(args)
HMAC key   = FLEET_SHARED_KEY (from .env)
```

## Result File Format

```json
{
  "id": "abc123def456",
  "ts": 1742000030,
  "operation": "gateway_restart",
  "status": "success",
  "output": {"restarted": true, "waited_seconds": 12},
  "error": null
}
```

## Setup

1. Generate a shared key on the fleet commander:
   ```bash
   python3 -c "import secrets; print('FLEET_SHARED_KEY=' + secrets.token_hex(32))"
   ```
2. Add `FLEET_SHARED_KEY` to `~/.openclaw/.env` on ALL fleet machines (same key)
3. Install and enable the fleet agent daemon:
   ```bash
   chmod +x skills/fleet-agent/fleet-agent
   ./skills/fleet-agent/fleet-agent daemon &
   ```
4. Set up inbox/outbox sync (Tailscale shared folder, or similar)

## Security Requirements

- `FLEET_SHARED_KEY` must be in `.env`, never in `openclaw.json`
- Inbox directory should be `chmod 700`
- Nonce window: commands older than 300 seconds are rejected
- Nonces are tracked in `~/.openclaw/fleet-nonces.json` (rotated hourly)

## See Also

- `devops/fleet-agent-security.md` — full threat model
- `skills/fleet-agent/SKILL.md` — skill usage docs
- `skills/fleet-agent/fleet-agent` — implementation
