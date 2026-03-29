# MCP Fleet Setup Guide

> **Status:** Planned — Phase 4
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 4 (NL Fleet Control via MCP)
> **Target:** Model Context Protocol server for fleet operations

## Overview

This guide covers setting up a fleet MCP server that allows the fleet commander (Atlas4) to issue natural language fleet commands that are validated, signed, and delivered to fleet agents.

## Status

This guide is a stub. Implementation is planned for Phase 4.

## Planned Architecture

```
User: "restart the gateway on all machines"
Atlas4 (NL interpreter)
    → fleet-commander workflow
    → fleet-mcp-server (MCP)
    → Validates + signs command
    → Writes to fleet-inbox/ on each machine
    → fleet-agent daemon processes
    → Writes results to fleet-outbox/
Atlas4 reads results and reports back
```

## Planned Sections

1. **MCP Server Setup** — `skills/fleet-mcp-server/`
2. **Fleet Commander Workflow** — `workflows/fleet-commander/AGENT.md`
3. **Command Signing** — HMAC-SHA256 command signing setup
4. **Machine Registration** — How to add new machines to the fleet
5. **Allowlist Configuration** — What operations are permitted
6. **Monitoring** — Fleet health dashboard

## See Also

- `devops/fleet-agent.md` — fleet agent desired-state spec
- `devops/fleet-agent-security.md` — security threat model
- `skills/fleet-agent/SKILL.md` — fleet agent skill (Phase 2)
- `docs/RUFLO_SETUP.md` — Ruflo swarm integration (Phase 4 alternative)
- `workflows/fleet-commander/AGENT.md` — fleet commander workflow
