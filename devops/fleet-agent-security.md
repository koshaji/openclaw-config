# Fleet Agent Security — Threat Model and Security Boundary

This document defines the security boundary, threat model, and allowed operations for the OpenClaw zero-SSH fleet agent.

---

## Overview

The fleet agent enables centralized management of multiple OpenClaw instances (nodes) without requiring SSH access. Commands flow from a master node to fleet agents via a secure message channel (e.g., a private Telegram group or dedicated message bus).

**Zero-SSH model:** No inbound SSH ports. All management is outbound/pull-based or via the gateway message relay.

---

## Threat Model

### Assets to Protect

| Asset | Sensitivity | Concern |
|-------|-------------|---------|
| 1Password secrets / `.env` files | Critical | Exfiltration |
| Gateway API keys / tokens | High | Unauthorized access |
| Host filesystem (outside `~/.openclaw/`) | Medium | Unauthorized modification |
| Network configuration | Medium | Redirect / pivot attacks |
| User/system credentials | High | Privilege escalation |
| Audit logs | Medium | Tampering to cover tracks |

### Threat Actors

1. **Compromised master node** — A fleet-connected agent receives commands from a master that has been taken over
2. **Message channel eavesdropping** — Commands intercepted or replayed
3. **Rogue command injection** — An attacker sends crafted fleet commands without authorization
4. **Overprivileged operations** — A legitimate command unintentionally performs destructive actions

### Attack Vectors

- Unsigned or invalidly-signed fleet commands
- Replayed commands (same signature, different context)
- Command payload manipulation (valid signature, injected shell arguments)
- Lateral movement via file access or network config changes

---

## Allowed Operations (Allowlist ONLY)

The fleet agent operates on an **explicit allowlist**. Any operation not listed below is **blocked by default**.

### Permitted Operations

| Operation | Description | Risk Level |
|-----------|-------------|------------|
| `health_report` | Read-only system status: CPU, memory, disk, gateway status | Low |
| `gateway_restart` | Graceful restart of the OpenClaw gateway process only | Low |
| `config_pull` | Pull updated config from a trusted git repository (read-only) | Low |
| `update_gateway` | Download and install the latest openclaw binary | Medium |
| `log_export` | Ship recent log files to the master node | Low |

### Operation Constraints

**`health_report`**
- Reads: system metrics, process list filtered to openclaw, gateway status
- Writes: nothing
- Network: none

**`gateway_restart`**
- Only invokes `launchctl kickstart` (macOS) or `systemctl restart openclaw-gateway` (Linux)
- Cannot specify arbitrary process names or commands
- Logs restart event to audit log

**`config_pull`**
- Only pulls from the pre-configured git remote (set in `openclaw.json`)
- Read-only git operation (`git pull --ff-only`)
- Cannot modify the git remote URL
- Cannot execute post-pull scripts unless pre-approved in config

**`update_gateway`**
- Only downloads from the official OpenClaw release URL (hardcoded or config-pinned)
- Verifies checksum before installing
- Backs up current binary before replacing
- Does not auto-restart (requires separate `gateway_restart` command)

**`log_export`**
- Ships only files from `~/.openclaw/logs/` and `~/.openclaw/audit/`
- Filename filtering: only `*.log`, `*.jsonl`, `*.jsonl.gz`
- Cannot read arbitrary file paths
- Strips any lines matching secret patterns (API keys, passwords) before export

---

## Blocked by Default

The following operations are **explicitly blocked** and cannot be enabled via config:

| Operation | Reason |
|-----------|--------|
| Arbitrary shell execution | Highest-risk vector; entire attack surface |
| File writes outside `~/.openclaw/` | Prevents system tampering |
| File reads outside `~/.openclaw/` | Prevents data exfiltration |
| Reading `~/.openclaw/secrets/` or `.env` files | Prevents credential theft |
| Network configuration changes | Prevents redirect/pivot attacks |
| User or credential management | Prevents privilege escalation |
| Installing packages or binaries (other than openclaw) | Prevents supply chain attacks |
| Modifying systemd units or launchd plists (other than openclaw-specific) | Prevents persistence |
| Disabling or modifying audit logging | Prevents log tampering |

---

## Authentication

### HMAC-SHA256 Command Signing

All fleet commands must be signed with a shared secret. Commands without a valid signature are **rejected and logged**.

**Signature scheme:**

```
HMAC-SHA256(secret, canonical_payload)
```

Where `canonical_payload` is:
```
{timestamp}:{agent_id}:{operation}:{nonce}:{payload_json}
```

**Example command envelope:**
```json
{
  "ts": 1743174000,
  "agent_id": "mini4",
  "op": "health_report",
  "nonce": "a1b2c3d4e5f6",
  "payload": {},
  "sig": "e3b0c44298fc1c149afbf4c8996fb924..."
}
```

### Replay Protection

- Commands are rejected if `ts` is more than **300 seconds** (5 minutes) from the current time
- `nonce` is stored for 10 minutes; duplicate nonces are rejected
- Both checks must pass for a command to be accepted

### Key Management

- The shared secret is stored in `~/.openclaw/fleet-secret` (mode `600`)
- The secret is **never** transmitted in the message channel
- Secret rotation requires manual update on all nodes and the master
- Use a minimum 256-bit (32-byte) random secret:
  ```bash
  openssl rand -hex 32 > ~/.openclaw/fleet-secret
  chmod 600 ~/.openclaw/fleet-secret
  ```

---

## Audit Logging

All fleet command events are logged to the structured audit log:

```json
{"ts": 1743174000, "agent": "mini4", "action": "fleet_command", "op": "health_report", "result": "success"}
{"ts": 1743174060, "agent": "mini4", "action": "fleet_command_rejected", "op": "shell_exec", "reason": "operation not in allowlist"}
{"ts": 1743174120, "agent": "mini4", "action": "fleet_command_rejected", "op": "gateway_restart", "reason": "invalid signature"}
```

Rejected commands are always logged — they may indicate an attack in progress.

---

## Incident Response

If a fleet agent receives an unusually high number of rejected commands:

1. Check `~/.openclaw/audit/` for patterns (same operation, different nonces)
2. Consider rotating the fleet secret immediately
3. Notify the master node operator via out-of-band channel
4. Review recent `log_export` and `config_pull` operations for anomalies

---

## Security Checklist

- [ ] Fleet secret is 256+ bits random, stored at `~/.openclaw/fleet-secret` (mode 600)
- [ ] Audit logging is active and writing to `~/.openclaw/audit/`
- [ ] `audit-rotate.sh` is scheduled (cron or systemd timer)
- [ ] `authorized-users` file is configured (opt-in access control)
- [ ] Gateway runs as a non-root user
- [ ] `~/.openclaw/` directory is mode 700
- [ ] No inbound ports open except the gateway's local port (127.0.0.1 only)
- [ ] Fleet secret rotation schedule is defined (recommend: quarterly or on personnel change)
