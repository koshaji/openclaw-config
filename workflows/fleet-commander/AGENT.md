---
name: fleet-commander
version: 0.1.0-planned
description: Natural language fleet management workflow — Phase 4
status: planned
phase: 4
---

# Fleet Commander

> **Status:** Planned — Phase 4
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 4 (NL Fleet Control)
> **Target:** Autonomous fleet management agent using natural language

## Overview

Fleet Commander is a scheduled workflow that monitors and manages the OpenClaw fleet using natural language commands. It wraps the fleet-mcp-server to provide a conversational interface for fleet operations.

## Status

This workflow is planned for Phase 4. It depends on:
- Phase 2: `skills/fleet-agent/` — zero-SSH agent on each machine
- Phase 4: `skills/fleet-mcp-server/` — MCP server for fleet ops
- Phase 4: Evaluate Ruflo (`docs/RUFLO_SETUP.md`) as an alternative

## Planned Capabilities

1. **Fleet health monitoring** — Check all machines every 5 minutes
2. **Autonomous restarts** — Restart unhealthy gateways without human intervention
3. **Natural language commands** — "restart all machines", "show me fleet health"
4. **Escalation** — Alert the human if something can't be auto-resolved
5. **Audit trail** — All actions logged to `~/.openclaw/audit/`

## Algorithm (Planned)

```
Every 5 minutes:
1. Call fleet_list_machines() → get health for all machines
2. For each machine with status != "healthy":
   a. If gateway unreachable: call fleet_gateway_restart()
   b. If sessions stale: call fleet_session_cleanup()
   c. If unknown issue: alert human, don't act
3. Log all actions to audit log
4. If >2 machines degraded: alert human immediately

On human command:
1. Parse natural language intent
2. Validate against permitted operations
3. Execute via fleet-mcp-server
4. Report results
```

## See Also

- `skills/fleet-mcp-server/SKILL.md` — MCP server (Phase 4)
- `skills/fleet-agent/SKILL.md` — agent on each machine (Phase 2)
- `devops/fleet-agent.md` — fleet agent spec
- `docs/MCP_FLEET_SETUP.md` — setup guide
- `docs/RUFLO_SETUP.md` — Ruflo as alternative orchestrator
