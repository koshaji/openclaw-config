# Ruflo Setup Guide

> **Status:** Phase 4 — Reference Guide
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 4 (NL Fleet Control — Swarm Orchestration)
> **Reference:** [github.com/ruvnet/ruflo](https://github.com/ruvnet/ruflo)

## What is Ruflo?

Ruflo is an open-source **swarm orchestration framework for Claude Code** (and compatible
AI agents). It enables multi-agent workflows where a "queen" agent decomposes complex
tasks and delegates to "worker" agents that execute in parallel.

Key capabilities:
- **Queen/worker pattern** — one coordinator agent spawns and manages worker agents
- **Parallel task execution** — workers run concurrently, not sequentially
- **Result aggregation** — queen collects and synthesizes worker outputs
- **Agent health monitoring** — detects stuck/failed workers and respawns
- **Natural language task routing** — describe what you want, Ruflo routes it

Ruflo is purpose-built for Claude Code (the same runtime as OpenClaw agents), making
integration straightforward.

---

## Ruflo vs Native Fleet Commander

Use this table to decide when to reach for Ruflo vs OpenClaw's built-in fleet commander:

| Scenario | Use | Reason |
|----------|-----|--------|
| "check if all machines are healthy" | **Fleet Commander** | Simple read op, no parallelism needed |
| "restart the gateway on mac-mini-01" | **Fleet Commander** | Single targeted write op |
| "review the last 100 PRs and categorize them" | **Ruflo** | Complex task needing parallel workers |
| "run code review on 20 files simultaneously" | **Ruflo** | Classic swarm use case |
| "research 5 topics and write a report" | **Ruflo** | Multi-source parallel research |
| "push config to 3 machines" | **Fleet Commander** | Structured fleet op, not a swarm task |
| "refactor the entire codebase" | **Ruflo** | Complex decomposition + parallelism |
| Scheduled fleet health monitoring | **Fleet Commander** | Periodic, structured, lightweight |
| Ad-hoc complex multi-step tasks | **Ruflo** | Needs dynamic decomposition |

**Rule of thumb:**
- Fleet operations (health, restart, update, config, logs) → **Fleet Commander**
- Complex AI tasks requiring multiple agents working in parallel → **Ruflo**

---

## Installation

### Option 1: npx (no install, always latest)

```bash
npx ruflo init
npx ruflo start
```

### Option 2: Global install

```bash
npm install -g ruflo
ruflo init
ruflo start
```

### Option 3: One-liner setup

```bash
curl -fsSL https://raw.githubusercontent.com/ruvnet/ruflo/main/install.sh | bash
```

### Verify installation

```bash
ruflo --version
ruflo status
```

---

## Integration with openclaw-config

### Topology mapping

OpenClaw's fleet topology maps naturally to Ruflo's queen/worker pattern:

```
OpenClaw fleet:          Ruflo equivalent:
  atlas4 (brain)    →     queen agent
  forge4 (executor) →     worker agent (code/build tasks)
  vault4 (security) →     worker agent (security/credentials)
  nova4 (research)  →     worker agent (research tasks)
```

Atlas4 acts as the queen: it receives complex tasks, decomposes them using Ruflo, and
delegates sub-tasks to worker agents that execute in parallel.

### Configuration

Create `~/.openclaw/ruflo/ruflo.json`:

```json
{
  "queen": {
    "agent": "atlas4",
    "model": "anthropic/claude-opus-4-5",
    "maxWorkers": 4,
    "taskTimeout": 300
  },
  "workers": [
    {
      "name": "forge4",
      "model": "anthropic/claude-sonnet-4-5",
      "capabilities": ["code", "build", "test", "documentation"],
      "maxConcurrent": 2
    },
    {
      "name": "vault4",
      "model": "anthropic/claude-sonnet-4-5",
      "capabilities": ["security", "credentials", "review"],
      "maxConcurrent": 1
    }
  ],
  "taskDecomposition": {
    "enabled": true,
    "maxDepth": 3,
    "parallelThreshold": 2
  },
  "healthMonitor": {
    "enabled": true,
    "checkIntervalSec": 30,
    "maxRespawnAttempts": 3
  }
}
```

### Use Ruflo for complex tasks, Fleet Commander for fleet ops

```
# Complex task → Ruflo
Atlas4: "Ruflo, review all open PRs and create a prioritized fix list"
  → Queen decomposes: [fetch PRs] [analyze each] [aggregate] [write report]
  → Workers execute in parallel
  → Atlas4 gets synthesized result

# Fleet op → Fleet Commander
Atlas4: /fleet check health
  → Fleet Commander routes to fleet_health_check()
  → fleet-mcp-server queries all machines
  → Structured result returned
```

---

## Docker Deployment

Ruflo ships a **324MB lite Docker image** suitable for VPS deployment:

```bash
# Pull the lite image
docker pull ruvnet/ruflo:lite

# Run with OpenClaw config mounted
docker run -d \
  --name ruflo \
  -v ~/.openclaw:/root/.openclaw \
  -v $(pwd):/workspace \
  -p 3000:3000 \
  ruvnet/ruflo:lite

# Check status
docker logs ruflo
```

### Docker Compose (alongside OpenClaw gateway)

Add to your existing `docker-compose.yml`:

```yaml
services:
  openclaw-gateway:
    image: openclaw/gateway:latest
    # ... existing config

  ruflo:
    image: ruvnet/ruflo:lite
    volumes:
      - ~/.openclaw:/root/.openclaw
      - ./openclaw-config:/workspace
    ports:
      - "127.0.0.1:3000:3000"  # Bind to loopback only
    environment:
      - OPENCLAW_AGENT_ID=atlas4
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    depends_on:
      - openclaw-gateway
    restart: unless-stopped
```

---

## Swarm Configuration for Fleet Management

For fleet-management swarms, configure Ruflo to use the fleet-mcp-server as a tool
source. This lets Ruflo workers call fleet operations as part of complex workflows.

### MCP bridge setup

Create `~/.openclaw/ruflo/mcp-bridge.json`:

```json
{
  "mcpServers": {
    "fleet": {
      "command": "/path/to/openclaw-config/skills/fleet-mcp-server/fleet-mcp-server",
      "args": [],
      "env": {
        "OPENCLAW_AGENT_ID": "atlas4"
      }
    }
  }
}
```

With this bridge, Ruflo workers can call `fleet_health_check`, `fleet_restart`, etc.
as native tools within swarm tasks.

### Example: Parallel fleet audit

```
Queen task: "Audit all fleet machines and produce a health report"
  ↓ Ruflo decomposes:
  Worker 1: fleet_health_check(["mac-mini-01"]) + fleet_logs("mac-mini-01", 200)
  Worker 2: fleet_health_check(["mac-mini-02"]) + fleet_logs("mac-mini-02", 200)
  Worker 3: fleet_health_check(["mac-mini-03"]) + fleet_logs("mac-mini-03", 200)
  ↓ All workers run in parallel
  Queen aggregates: produces structured health report with per-machine findings
```

This is faster than the fleet commander's sequential approach for large fleets.
For fleets with ≤3 machines, the fleet commander is simpler and sufficient.

---

## Performance Considerations

### VPS sizing recommendations

| Fleet size | Task complexity | Recommended VPS |
|------------|----------------|-----------------|
| 1–3 machines | Simple ops | 1 vCPU, 2GB RAM (fleet commander, no Ruflo needed) |
| 4–10 machines | Mixed | 2 vCPU, 4GB RAM (Ruflo lite + fleet commander) |
| 10+ machines | Complex audits | 4 vCPU, 8GB RAM (full Ruflo + dedicated fleet MCP server) |
| Enterprise | Multi-region | 8+ vCPU, 16GB RAM, consider Ruflo clustering |

### Resource overhead

- Fleet commander (no Ruflo): ~50MB RAM at rest
- Ruflo lite (Docker): ~324MB image, ~150–300MB RAM when idle
- fleet-mcp-server: ~30MB RAM (UV process, on-demand)
- Each active Ruflo worker: ~100–200MB RAM

### When NOT to use Ruflo

- You have ≤3 fleet machines → fleet commander is sufficient
- Your tasks are sequential (one thing at a time) → no parallelism benefit
- RAM is constrained (<2GB available) → skip Ruflo, use fleet commander only
- You need strict ordering guarantees → Ruflo's parallel execution may not suit

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Workers not spawning | Max workers limit hit | Increase `maxWorkers` in ruflo.json |
| Task timeout | Worker took too long | Increase `taskTimeout` or break task into smaller pieces |
| MCP tools not available | Bridge not configured | Check `mcp-bridge.json` path |
| Docker container exits | Missing env vars | Set `ANTHROPIC_API_KEY` in docker-compose.yml |
| Queen stuck | Task too complex to decompose | Provide more specific task description |

## See Also

- `workflows/fleet-commander/AGENT.md` — native NL fleet commander
- `skills/fleet-mcp-server/SKILL.md` — MCP server (Ruflo bridge target)
- `workflows/agent-swarm/AGENT.md` — agent swarm orchestration workflow
- [Ruflo GitHub](https://github.com/ruvnet/ruflo) — upstream documentation
- [MCP Protocol](https://modelcontextprotocol.io) — protocol Ruflo uses for tool access
