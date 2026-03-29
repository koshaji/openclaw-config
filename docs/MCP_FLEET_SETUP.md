# Fleet MCP Server Setup Guide

> **Status:** Implemented — Phase 4
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 1 (Zero-SSH Fleet Operations) + Gap 4 (NL Fleet Control)
> **Skill:** `skills/fleet-mcp-server/`
> **Protocol:** [Model Context Protocol](https://modelcontextprotocol.io)

---

## Table of Contents

1. [What Is the Fleet MCP Server?](#1-what-is-the-fleet-mcp-server)
2. [Why Use It?](#2-why-use-it)
3. [Architecture Overview](#3-architecture-overview)
4. [Prerequisites](#4-prerequisites)
5. [Installation](#5-installation)
6. [Connecting to Claude Code / Claude Desktop](#6-connecting-to-claude-code--claude-desktop)
7. [Available Tools Reference](#7-available-tools-reference)
8. [Example Conversations](#8-example-conversations)
9. [RBAC Integration](#9-rbac-integration)
10. [Audit Logging](#10-audit-logging)
11. [Troubleshooting](#11-troubleshooting)
12. [Security Considerations](#12-security-considerations)
13. [See Also](#13-see-also)

---

## 1. What Is the Fleet MCP Server?

`fleet-mcp-server` is a [Model Context Protocol](https://modelcontextprotocol.io) server
that exposes fleet operations as typed, callable tools to AI agents and MCP-compatible
clients (Claude Desktop, Claude Code, OpenClaw, etc.).

It bridges the gap between:

- **Natural language commands** from an AI agent or human operator
- **The low-level inbox/outbox protocol** used by `fleet-agent` on each machine

When the fleet commander (Atlas4) receives a request like "check if all nodes are
healthy", it calls `fleet_health_check()` via this MCP server. The server handles
command construction, HMAC signing, delivery to each machine's inbox, polling for
results, and structured response assembly — all transparently.

---

## 2. Why Use It?

| Without Fleet MCP | With Fleet MCP |
|---|---|
| SSH into each machine manually | One tool call covers all machines |
| No access control on fleet ops | RBAC enforced per operation |
| No audit trail of who did what | Full audit log with timestamps |
| AI agents have no fleet visibility | AI can query status, restart, push config |
| Error-prone manual command sequences | Typed, validated, signed commands |

**The fleet MCP server is the recommended way for all AI agents and human operators
to interact with the fleet.** Direct SSH should be reserved for emergencies only.

---

## 3. Architecture Overview

```
Human / AI Agent
       │
       │  Natural language or direct tool call
       ▼
Fleet Commander Workflow  (workflows/fleet-commander/AGENT.md)
       │
       │  Maps intent → MCP tool call
       ▼
fleet-mcp-server  (skills/fleet-mcp-server/fleet-mcp-server)
       │
       │  1. RBAC check
       │  2. Build command JSON
       │  3. HMAC-SHA256 sign
       │  4. Write to fleet-inbox/cmd-<uuid>.json
       ▼
fleet-agent  (running on each target machine, polling inbox)
       │
       │  Executes the operation
       │  Writes result to fleet-outbox/result-<uuid>.json
       ▼
fleet-mcp-server  (polls outbox for result, up to 30s)
       │
       │  Aggregates results from all machines
       ▼
Structured response  →  AI agent  →  Human-readable summary
```

The command lifecycle:

1. **Command written** to `~/.openclaw/fleet-inbox/cmd-<uuid>.json` with HMAC signature
2. **fleet-agent** verifies signature, executes operation
3. **Result written** to `~/.openclaw/fleet-outbox/result-<uuid>.json`
4. **fleet-mcp-server** polls outbox, collects results (30s timeout)
5. **Aggregated response** returned to caller

---

## 4. Prerequisites

### 4.1 Fleet Agent on Each Node

Each machine in the fleet must have `fleet-agent` running. The agent:
- Polls `~/.openclaw/fleet-inbox/` for new command files
- Verifies HMAC-SHA256 signatures against the shared secret
- Executes allowed operations (restart, update, health-check, etc.)
- Writes results to `~/.openclaw/fleet-outbox/`

Install and start the fleet agent on each machine:

```bash
# On each target machine
cp skills/fleet-agent/fleet-agent ~/.openclaw/bin/fleet-agent
chmod +x ~/.openclaw/bin/fleet-agent
~/.openclaw/bin/fleet-agent --install-service   # installs as launchd (macOS) or systemd
~/.openclaw/bin/fleet-agent status
```

See `skills/fleet-agent/SKILL.md` for full agent setup instructions.

### 4.2 Inventory File

Create `~/.openclaw/fleet/inventory.json` describing all machines in your fleet:

```json
{
  "machines": [
    {
      "name": "mac-mini-01",
      "host": "mac-mini-01.your-tailnet.ts.net",
      "port": 18789,
      "role": "primary",
      "agents": ["atlas4", "forge4", "vault4"],
      "inbox": "/Users/admin/.openclaw/fleet-inbox",
      "outbox": "/Users/admin/.openclaw/fleet-outbox",
      "tags": ["production", "mac"]
    },
    {
      "name": "raspberry-pi-01",
      "host": "pi-01.your-tailnet.ts.net",
      "port": 18789,
      "role": "secondary",
      "agents": ["speedy4"],
      "inbox": "/home/pi/.openclaw/fleet-inbox",
      "outbox": "/home/pi/.openclaw/fleet-outbox",
      "tags": ["edge", "linux"]
    }
  ],
  "updated_at": "2026-03-29T00:00:00Z"
}
```

**Note:** For machines on Tailscale, use the Tailscale hostname or MagicDNS address.
For local machines (same host as the MCP server), use `localhost` or `127.0.0.1`.

### 4.3 HMAC Shared Secret

All fleet operations are signed with HMAC-SHA256 using a shared secret. The same
secret must be configured on:
- The `fleet-mcp-server` (source of commands)
- Each `fleet-agent` (command verifier/executor)

Generate the shared secret once and distribute it securely:

```bash
# Generate a strong random secret
openssl rand -hex 32 > ~/.openclaw/fleet/fleet-hmac-key
chmod 600 ~/.openclaw/fleet/fleet-hmac-key

# Distribute to each machine securely (via Tailscale + SCP, or 1Password)
# The fleet-agent reads from: ~/.openclaw/fleet/fleet-hmac-key
```

Alternatively, set via environment variable:

```bash
export FLEET_HMAC_SECRET="$(cat ~/.openclaw/fleet/fleet-hmac-key)"
```

### 4.4 Python 3.11+

The fleet-mcp-server is a UV inline script. UV will automatically manage Python
and install dependencies (`mcp>=1.0.0`, `anyio>=4.0.0`) on first run.

Install UV if not already present:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

---

## 5. Installation

```bash
# 1. Clone or update openclaw-config
cd ~/.openclaw/workspace
git clone https://github.com/your-org/openclaw-config.git
cd openclaw-config

# 2. Make the server executable
chmod +x skills/fleet-mcp-server/fleet-mcp-server

# 3. Verify it starts (will show usage if inventory is missing)
./skills/fleet-mcp-server/fleet-mcp-server --help
```

Expected output:

```
usage: fleet-mcp-server [-h] [--transport {stdio,sse}] [--port PORT] [--host HOST]

fleet-mcp-server — MCP server for fleet operations

options:
  -h, --help            show this help message and exit
  --transport {stdio,sse}
                        Transport type (default: stdio)
  --port PORT           SSE port (default: 8766)
  --host HOST           SSE bind host (default: localhost)
```

---

## 6. Connecting to Claude Code / Claude Desktop

### 6.1 stdio Transport (Recommended)

stdio is the standard MCP transport for local integrations. The MCP client spawns
the server as a subprocess and communicates via stdin/stdout.

**Claude Desktop** — add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "fleet": {
      "command": "uv",
      "args": [
        "run",
        "--script",
        "/Users/you/.openclaw/workspace/openclaw-config/skills/fleet-mcp-server/fleet-mcp-server"
      ],
      "env": {
        "FLEET_INVENTORY": "/Users/you/.openclaw/fleet/inventory.json",
        "FLEET_HMAC_SECRET": "your-shared-secret-here"
      }
    }
  }
}
```

**Claude Code** — add to `.claude/settings.json` in your project (or `~/.claude/settings.json` globally):

```json
{
  "mcpServers": {
    "fleet": {
      "command": "uv",
      "args": [
        "run",
        "--script",
        "~/.openclaw/workspace/openclaw-config/skills/fleet-mcp-server/fleet-mcp-server"
      ],
      "env": {
        "FLEET_INVENTORY": "~/.openclaw/fleet/inventory.json",
        "FLEET_HMAC_SECRET": "your-shared-secret-here"
      }
    }
  }
}
```

**OpenClaw** — add to `~/.openclaw/mcp.json`:

```json
{
  "mcpServers": {
    "fleet": {
      "command": "/Users/you/.openclaw/workspace/openclaw-config/skills/fleet-mcp-server/fleet-mcp-server",
      "args": [],
      "env": {
        "FLEET_HMAC_SECRET": "your-shared-secret-here"
      }
    }
  }
}
```

> **Security note:** Avoid hardcoding the HMAC secret. Instead:
> - Use `op run --` from 1Password CLI to inject secrets at runtime
> - Or reference a secrets file: `"FLEET_HMAC_SECRET": "file:~/.openclaw/fleet/fleet-hmac-key"`

### 6.2 SSE Transport (HTTP Server Mode)

SSE mode runs the server as a persistent HTTP server, useful for:
- Web frontends or dashboards
- Multiple MCP clients connecting to the same server
- Scenarios where spawning a subprocess per client is undesirable

Start the SSE server:

```bash
./skills/fleet-mcp-server/fleet-mcp-server --transport sse --port 8766
# SSE endpoint: http://localhost:8766/sse
```

Connect from an MCP client:

```json
{
  "mcpServers": {
    "fleet": {
      "url": "http://localhost:8766/sse"
    }
  }
}
```

**Note:** SSE mode binds to `localhost` by default. Do **not** expose port 8766 to
the internet without additional authentication (e.g., Tailscale + Authelia).

---

## 7. Available Tools Reference

The fleet-mcp-server exposes 6 tools to MCP clients:

### `fleet_status`

List all machines in the inventory with their current health status.

**RBAC:** `read`

**Parameters:** none

**Returns:**
```json
{
  "machines": [
    {
      "name": "mac-mini-01",
      "role": "primary",
      "agents": ["atlas4", "forge4"],
      "last_seen": "2026-03-29T08:00:00Z",
      "status": "online"
    }
  ],
  "total": 1,
  "online": 1,
  "offline": 0
}
```

---

### `fleet_health_check`

Run a health check on one or all machines. Returns agent status, resource usage,
gateway connectivity, and any active alerts.

**RBAC:** `read`

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `machines` | `list[str]` | No | Machine names to check. If omitted, checks all machines. |

**Returns:** Health report per machine including CPU, memory, disk, agent states.

---

### `fleet_restart`

Restart the OpenClaw gateway (and optionally all agents) on target machines.

**RBAC:** `write`

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `machines` | `list[str]` | Yes | Machine names to restart |
| `graceful` | `bool` | No | Wait for in-flight requests to complete (default: `true`) |
| `agents` | `list[str]` | No | Specific agents to restart (default: gateway only) |

**Returns:** Restart confirmation per machine with new process IDs.

---

### `fleet_update`

Pull the latest `openclaw-config` from git and apply updates on target machines.

**RBAC:** `write`

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `machines` | `list[str]` | Yes | Machine names to update |
| `component` | `str` | No | Specific component to update (`gateway`, `skills`, `all`) |
| `branch` | `str` | No | Git branch to pull (default: `main`) |

**Returns:** Update result per machine with git diff summary and restart status.

---

### `fleet_config_push`

Push a configuration fragment to target machines. The config is validated before
delivery and merged with the existing configuration.

**RBAC:** `admin`

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `machines` | `list[str]` | Yes | Machine names to push config to |
| `config` | `dict` | Yes | Configuration fragment to merge |
| `path` | `str` | No | Config path within `~/.openclaw/` (default: root config) |
| `dry_run` | `bool` | No | Validate without applying (default: `false`) |

**Returns:** Push result per machine with validation status and applied changes.

---

### `fleet_logs`

Retrieve recent log lines from a machine's OpenClaw gateway or a specific agent.

**RBAC:** `read`

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `machine` | `str` | Yes | Machine name |
| `lines` | `int` | No | Number of recent lines to return (default: `50`, max: `1000`) |
| `agent` | `str` | No | Filter logs to a specific agent (default: all agents) |
| `since` | `str` | No | ISO timestamp to filter from (e.g., `"2026-03-29T00:00:00Z"`) |

**Returns:** Log lines with timestamps, agent names, and log levels.

---

## 8. Example Conversations

### Check health of all machines

```
You: Check health of all machines

Atlas4: I'll run a health check across the fleet.

→ fleet_health_check()

Results:
  mac-mini-01 (primary): ✅ Online
    CPU: 12% | Memory: 4.2GB/16GB | Disk: 45GB/500GB free
    Agents: atlas4 ✅, forge4 ✅, vault4 ✅
    Gateway: responding (v2.1.0)
    
  raspberry-pi-01 (secondary): ⚠️ Warning
    CPU: 87% | Memory: 1.8GB/4GB | Disk: 2.1GB/32GB free
    Agents: speedy4 ✅
    Gateway: responding (v2.1.0)
    Alert: High CPU usage — consider restarting heavy workloads
```

### Restart gateway on a specific machine

```
You: Restart the gateway on mac-mini-01

Atlas4: Restarting gateway on mac-mini-01 gracefully.

→ fleet_restart(["mac-mini-01"], graceful=True)

mac-mini-01: Gateway restarted successfully
  Old PID: 4521 → New PID: 4892
  All agents reconnected (atlas4, forge4, vault4)
  Downtime: ~3.2 seconds
```

### Show recent logs from the primary node

```
You: Show me the last 100 lines of logs from the primary node

Atlas4: Fetching the last 100 log lines from mac-mini-01.

→ fleet_logs("mac-mini-01", lines=100)

[2026-03-29 08:00:01] [gateway] INFO  Session started: atlas4
[2026-03-29 08:00:02] [atlas4]  INFO  Heartbeat: 3 tasks pending
[2026-03-29 08:00:15] [forge4]  INFO  Subagent spawned: c5dfd5aa
[2026-03-29 08:01:30] [forge4]  INFO  Subagent completed: c5dfd5aa
...
```

### Push configuration to all machines

```
You: Enable verbose logging on all machines

Atlas4: I'll push a config update to enable verbose logging fleet-wide.

→ fleet_config_push(
    machines=["mac-mini-01", "raspberry-pi-01"],
    config={"logging": {"level": "verbose"}},
    dry_run=True
  )

Dry run validation passed for all machines.
Applying...

→ fleet_config_push(
    machines=["mac-mini-01", "raspberry-pi-01"],
    config={"logging": {"level": "verbose"}}
  )

mac-mini-01: Config applied ✅ (gateway restart not required)
raspberry-pi-01: Config applied ✅ (gateway restart not required)
```

### Check fleet status

```
You: What's the status of the fleet?

Atlas4: Checking fleet inventory.

→ fleet_status()

Fleet: 2 machines, 2 online
  mac-mini-01  [primary]  last seen: 8s ago  agents: 3
  raspberry-pi-01  [secondary]  last seen: 12s ago  agents: 1
```

---

## 9. RBAC Integration

### Role Hierarchy

The fleet-mcp-server enforces role-based access control for all tool calls.
Roles are defined in `~/.openclaw/fleet/rbac.json`:

```json
{
  "roles": {
    "atlas4":  ["read", "write"],
    "forge4":  ["read"],
    "vault4":  ["read", "write", "admin"],
    "nova4":   ["read"],
    "speedy4": ["read"]
  },
  "operations": {
    "read":  ["fleet_status", "fleet_health_check", "fleet_logs"],
    "write": ["fleet_restart", "fleet_update"],
    "admin": ["fleet_config_push"]
  }
}
```

### Permission Matrix

| Tool | read | write | admin |
|------|:----:|:-----:|:-----:|
| `fleet_status` | ✅ | ✅ | ✅ |
| `fleet_health_check` | ✅ | ✅ | ✅ |
| `fleet_logs` | ✅ | ✅ | ✅ |
| `fleet_restart` | ❌ | ✅ | ✅ |
| `fleet_update` | ❌ | ✅ | ✅ |
| `fleet_config_push` | ❌ | ❌ | ✅ |

### Identity Resolution

The server resolves the caller's identity from:

1. `OPENCLAW_AGENT_ID` environment variable (e.g., `atlas4`)
2. `X-Agent-Identity` HTTP header (SSE mode)
3. Falls back to `anonymous` if neither is set

If RBAC is not configured (`rbac.json` absent), all operations are permitted
(permissive mode for single-operator setups).

---

## 10. Audit Logging

All fleet operations — both permitted and denied — are logged to:

```
~/.openclaw/audit/fleet-mcp-server.jsonl
```

Each audit entry is a JSONL record:

```json
{
  "ts": "2026-03-29T08:15:30Z",
  "agent": "atlas4",
  "tool": "fleet_restart",
  "machines": ["mac-mini-01"],
  "args": {"graceful": true},
  "result": "ok",
  "command_ids": ["cmd-f3a2b1c4-8d9e-4f2a-b3c4-5d6e7f8a9b0c"],
  "prev_hash": "sha256:abc123...",
  "hash": "sha256:def456..."
}
```

### Hash-Chained Integrity

Audit entries are hash-chained using SHA-256 to detect tampering:
- Each entry includes `prev_hash` (hash of the previous entry)
- The first entry uses `genesis` as `prev_hash`
- This creates a tamper-evident chain

Verify audit log integrity:

```bash
./skills/audit-export/audit-export --verify
```

Expected output:
```
Checking 2026-03-29.jsonl... 847 entries, chain intact ✅
```

### Exporting Audit Logs

```bash
# Export last 30 days to CSV
./skills/audit-export/audit-export --format csv --days 30 > fleet-audit.csv

# Export to syslog
./skills/audit-export/audit-export --export-syslog --facility local1

# Export to S3
./skills/audit-export/audit-export --export-s3 s3://your-bucket/audit/
```

See `skills/audit-export/SKILL.md` for full export documentation.

---

## 11. Troubleshooting

### `inventory.json not found`

```
Error: Fleet inventory not found at /Users/you/.openclaw/fleet/inventory.json
```

**Fix:** Create the inventory file. See [Section 4.2](#42-inventory-file) for the format.

```bash
mkdir -p ~/.openclaw/fleet
# Create inventory.json with your machine list
```

### `HMAC key missing`

```
Warning: HMAC key not found. Commands will not be signed.
```

**Fix:** Generate and distribute the shared secret. See [Section 4.3](#43-hmac-shared-secret).

```bash
openssl rand -hex 32 > ~/.openclaw/fleet/fleet-hmac-key
chmod 600 ~/.openclaw/fleet/fleet-hmac-key
```

### `Command timeout` (no response from machine)

```
Error: Command cmd-abc123 timed out after 30s (no response from mac-mini-01)
```

**Possible causes:**
- `fleet-agent` is not running on `mac-mini-01` → `ssh mac-mini-01 'fleet-agent status'`
- Inbox/outbox path is wrong in inventory.json → verify paths match fleet-agent config
- Tailscale connectivity issue → `tailscale ping mac-mini-01`
- Firewall blocking inbox directory access (NFS/SMB) → check mount status

### `RBAC denied`

```
Error: RBAC denied: forge4 does not have 'write' permission for fleet_restart
```

**Fix:** Update `~/.openclaw/fleet/rbac.json` to grant the required role to the agent,
or use an agent with sufficient permissions (vault4 has admin).

### `MCP server not showing up in Claude Desktop`

1. Verify the config file path is correct for your OS:
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`
2. Validate JSON syntax: `python3 -m json.tool claude_desktop_config.json`
3. Restart Claude Desktop after making config changes
4. Check Claude Desktop logs: `~/Library/Logs/Claude/`

### `uv: command not found`

Install UV:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc  # or ~/.zshrc
```

Or use `python3` directly (UV is optional):

```bash
python3 ~/.openclaw/workspace/openclaw-config/skills/fleet-mcp-server/fleet-mcp-server
```

---

## 12. Security Considerations

### Use Tailscale for All Fleet Communication

Fleet commands are delivered via the local filesystem inbox/outbox, which should
only be accessible via Tailscale VPN. **Never expose the fleet inbox/outbox directories
to the public internet.**

Recommended setup:
- All machines joined to the same Tailscale network
- Access control lists (ACLs) in Tailscale restricting fleet ports to fleet machines only
- MagicDNS for stable hostnames across the fleet

### HMAC-SHA256 Command Signing

Every command written to `fleet-inbox/` includes an HMAC-SHA256 signature computed
with the shared secret. `fleet-agent` verifies this signature before executing any
command. This prevents:
- Rogue processes from injecting commands into the inbox
- Replay attacks (commands include a timestamp + UUID)
- Tampering with command arguments after signing

**Keep the HMAC secret secure:**
- Store in `~/.openclaw/fleet/fleet-hmac-key` with `chmod 600`
- Rotate the secret periodically
- Distribute only via secure channels (1Password, Tailscale + SCP)
- Never commit the secret to git

### MCP Server Authentication

When running in stdio mode, the MCP server inherits the permissions of the spawning
process. Ensure:
- Only trusted AI agents and operators have access to the MCP server binary
- `~/.openclaw/fleet/` is not world-readable (`chmod 700 ~/.openclaw/fleet/`)

When running in SSE mode:
- Bind to `localhost` only (default) unless using Tailscale
- Add Authelia or Authentik for HTTP-level authentication if multi-user access is needed
- See `docs/AUTHELIA_SETUP.md` for HTTP auth setup

### Least Privilege

- Grant agents only the roles they need (see [Section 9](#9-rbac-integration))
- `forge4` (executor) needs only `read` — never `admin`
- `vault4` (gatekeeper) holds `admin` for sensitive operations
- `atlas4` (brain) needs `read` + `write` for operational control

### Audit Log Protection

The audit log at `~/.openclaw/audit/fleet-mcp-server.jsonl` should be:
- Backed up regularly and stored off-machine
- Protected with `chmod 644` (readable by agents, not writable except by MCP server)
- Verified periodically with `audit-export --verify`
- Exported to immutable storage (S3 versioned bucket, syslog server) for compliance

---

## 13. See Also

| Resource | Description |
|---|---|
| `skills/fleet-mcp-server/SKILL.md` | Developer reference for the MCP server skill |
| `skills/fleet-agent/SKILL.md` | Fleet agent (receiver side) setup and operation |
| `workflows/fleet-commander/AGENT.md` | NL fleet commander workflow (Atlas4) |
| `devops/fleet-agent.md` | Fleet agent spec and supported operations |
| `devops/fleet-agent-security.md` | Full security threat model and analysis |
| `docs/RUFLO_SETUP.md` | Ruflo swarm integration (alternative for complex orchestration) |
| `docs/MULTI_USER_SETUP.md` | Multi-user RBAC and identity routing |
| `docs/COMPLIANCE_GUIDE.md` | Audit log compliance (GDPR, SOC 2) |
| `docs/AUTHELIA_SETUP.md` | HTTP authentication for SSE transport |
