---
name: fleet-commander
version: 1.0.0
description: Natural language fleet management workflow
phase: 4
status: implemented
---

# Fleet Commander

> **Status:** Phase 4 — Implemented
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 4 (NL Fleet Control)
> **Reference pattern:** `unisone/openclaw-config` smart routing with learning loop

## Overview

Fleet Commander is a workflow agent that accepts natural language fleet commands and
translates them into specific fleet operations via the `fleet-mcp-server`. It bridges
the gap between human-readable intent and the structured tool calls required by the
fleet infrastructure.

**Primary use case:** Humans (and Atlas4) issue commands like:
- "check if all agents are healthy"
- "restart the gateway on mac-mini-01"
- "what's running on the fleet?"
- "push the latest config to all machines"

Fleet Commander translates these to the appropriate `fleet_*` tool calls, executes them,
and returns natural language summaries.

## Architecture

```
Human / Atlas4 (NL command)
    ↓
Fleet Commander (intent classification)
    ↓  ← routing-rules.md (static rules)
    ↓  ← patterns.json (learned overrides after ≥3 similar commands)
fleet-mcp-server (structured tool calls)
    ↓
fleet-agent (on each machine)
    ↓
Result → Fleet Commander (summarize)
    ↓
Human / Atlas4 (NL response)
```

## Invocation

### Via /fleet command (NL mode)
```
/fleet check if all agents are healthy
/fleet restart mac-mini-01
/fleet what happened on mac-mini-01 last night
```

### Via OpenClaw workflow scheduler
Configure as a periodic workflow in `~/.openclaw/workflows.json`:
```json
{
  "fleet-commander": {
    "schedule": "*/5 * * * *",
    "command": "Check fleet health and restart any unhealthy gateways"
  }
}
```

### Direct agent invocation
```
@atlas4 check fleet health
```

## Intent Classification

### Step 1: Keyword matching (routing-rules.md)

Classify the intent using the rules in `routing-rules.md`. Match against the user's
message and extract:
- **operation** — which fleet_* tool to call
- **machines** — which machines to target (or all if not specified)
- **parameters** — any additional arguments (graceful, lines, etc.)

### Step 2: Learning loop override (patterns.json)

After Step 1, check `~/.openclaw/fleet/routing-patterns.json`:
- If ≥3 historical examples of similar input map to a **different** operation, use the
  learned mapping instead of the static rule.
- Log every classification decision to the patterns file for future learning.

### Step 3: Disambiguation

If intent is ambiguous (e.g., "restart" without specifying machines), ask for
clarification before executing any write operations. Read operations can proceed on all
machines without confirmation.

Write operations (restart, update, config_push) require confirmation unless:
- The command explicitly names specific machines
- The user has confirmed within the last 60 seconds

### Step 4: Execution

Call the fleet-mcp-server tool with the classified parameters. Handle errors gracefully:
- Timeout → "No response from `<machine>` — fleet-agent may not be running"
- RBAC denied → "I don't have permission to run that operation. Contact your fleet admin."
- Machine not found → "Machine `<name>` not in fleet inventory. Check `~/.openclaw/fleet/inventory.json`"

### Step 5: Summary

Return a natural language summary of results:
- ✅ Success: "All 3 machines are healthy. Gateway running on all. Sessions: atlas4 (2), forge4 (0), nova4 (1)"
- ⚠️ Warning: "mac-mini-01 restarted successfully. mac-mini-02 timed out — check fleet-agent status"
- ❌ Failure: "Could not restart mac-mini-01: HMAC validation failed. The shared key may be out of sync."

## Autonomous Health Monitoring

When running as a scheduled workflow (every 5 minutes):

```
1. Call fleet_health_check(machines=None) → all machines
2. For each machine:
   a. Status "healthy"  → log, continue
   b. Status "degraded" → call fleet_restart(graceful=True), log
   c. Status "down"     → alert human immediately, attempt restart
   d. Status "timeout"  → alert human (fleet-agent may be stopped)
3. If >2 machines degraded simultaneously:
   → Do NOT auto-restart (cascading issue possible)
   → Alert human with full status report
4. Log all actions to ~/.openclaw/audit/fleet-commander.jsonl
```

**Auto-respawn limit:** Max 3 restart attempts per machine per hour. After 3 failures,
stop retrying and escalate to human. Log all attempts.

## Learning Loop

Every time Fleet Commander processes a command:
1. Record: input message, classified intent, tool called, result status
2. On next classification of similar input, check if learned patterns diverge from
   static rules. If ≥3 examples agree on a different mapping, prefer the learned one.
3. The patterns file (`~/.openclaw/fleet/routing-patterns.json`) is the authoritative
   learned state. It persists across sessions.

Human feedback can be provided:
- "That's wrong, I meant fleet_status not fleet_health_check" → records a correction
- Corrections have 3× weight in the learning loop

## Audit Trail

All actions are appended to `~/.openclaw/audit/fleet-commander.jsonl`:

```json
{
  "ts": "2026-03-29T00:05:00Z",
  "input": "check if all agents are healthy",
  "classified_as": "fleet_health_check",
  "routing_source": "static_rule",
  "machines": "all",
  "result_summary": "3/3 healthy",
  "duration_ms": 2341
}
```

## Escalation Policy

Always alert the human (via the configured notification channel) when:
- More than 2 machines are degraded at the same time
- A machine has been restarted 3 times in the last hour
- fleet-agent is unresponsive on any machine for >10 minutes
- A command requires RBAC elevation not currently granted

Never alert for:
- Routine health check completions (all healthy)
- Successful graceful restarts triggered autonomously
- Status queries

## Files

| File | Purpose |
|------|---------|
| `AGENT.md` | This file — workflow definition |
| `routing-rules.md` | Static intent → operation mapping |
| `patterns.json` | Empty learning log (seed file) |
| `~/.openclaw/fleet/routing-patterns.json` | Live learning state (gitignored) |
| `~/.openclaw/audit/fleet-commander.jsonl` | Action audit log |

## See Also

- `skills/fleet-mcp-server/SKILL.md` — the MCP server this workflow calls
- `skills/fleet-agent/SKILL.md` — the agent running on each fleet machine
- `.claude/commands/fleet.md` — the /fleet command (entry point for humans)
- `devops/fleet-agent-security.md` — security model for fleet operations
- `docs/RUFLO_SETUP.md` — Ruflo for complex swarm orchestration (complement, not replacement)
