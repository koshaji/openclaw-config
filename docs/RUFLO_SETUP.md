# Ruflo Setup Guide

> **Status:** Planned — Phase 4
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 4 (NL Fleet Control — Ruflo Option C)
> **Reference:** [github.com/ruvnet/ruflo](https://github.com/ruvnet/ruflo)

## Overview

Ruflo is an open-source swarm orchestration framework for AI agents. It provides:
- Multi-agent coordination patterns (broadcast, consensus, delegation)
- Natural language fleet control interface
- Agent health monitoring and auto-recovery
- Async task distribution with result aggregation

## Status

This guide is a stub. Ruflo evaluation is the **first task in Phase 4** per the gap plan.

From `GAP_CLOSING_PLAN.md`:
> **Evaluate Ruflo swarm integration** before building custom fleet-commander.
> Ruflo may eliminate the need for a custom MCP server + fleet-commander workflow.

## Decision Criteria

Adopt Ruflo if it provides:
- [ ] Zero-SSH fleet command delivery (compatible with inbox/outbox pattern)
- [ ] HMAC-signed command validation
- [ ] Audit logging to OpenClaw audit format
- [ ] Reasonable resource overhead (<100MB RAM per node)
- [ ] Active maintenance (commits within 6 months)

Build custom fleet-commander (`workflows/fleet-commander/AGENT.md`) if Ruflo doesn't fit.

## Planned Evaluation Tasks

1. Deploy Ruflo locally alongside OpenClaw
2. Test fleet command delivery to 2 agents
3. Evaluate security model vs `devops/fleet-agent-security.md` requirements
4. Benchmark resource usage
5. Document findings and make adopt/build decision

## See Also

- `docs/MCP_FLEET_SETUP.md` — MCP server alternative
- `workflows/fleet-commander/AGENT.md` — custom fleet commander
- `devops/fleet-agent-security.md` — security requirements
