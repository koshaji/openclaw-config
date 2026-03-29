# fleet-mcp-server

> **Status:** Planned — Phase 4
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 4 (NL Fleet Control)
> **Target:** MCP (Model Context Protocol) server exposing fleet operations to the fleet commander

## Overview

`fleet-mcp-server` is an MCP server that Atlas4 (the fleet commander) uses to issue fleet operations via natural language. It translates NL commands into validated, HMAC-signed command files that fleet agents on each machine will execute.

## Status

This skill is planned for Phase 4. Evaluate Ruflo (`docs/RUFLO_SETUP.md`) first — if Ruflo covers this use case, this skill may not be built.

## Planned MCP Tools

```
fleet_list_machines()      → List all registered fleet machines with health
fleet_gateway_status(machine)  → Get gateway health for a specific machine
fleet_gateway_restart(machine, force=False)  → Graceful/force restart
fleet_session_cleanup(machine)  → Clean stale sessions
fleet_broadcast(operation, args)  → Send operation to all machines
fleet_result_poll(command_id)   → Poll for result of async command
```

## Integration with fleet-agent

Fleet-mcp-server generates signed command files that fleet-agent processes:

```
Atlas4 calls fleet_gateway_restart("mac-mini-home")
    → fleet-mcp-server validates operation against allowlist
    → Signs command with HMAC-SHA256
    → Writes to ~/.openclaw/fleet-inbox/cmd-<uuid>.json
    → Returns command_id to Atlas4
Atlas4 calls fleet_result_poll(command_id)
    → Returns result from ~/.openclaw/fleet-outbox/result-<uuid>.json
```

## See Also

- `skills/fleet-agent/SKILL.md` — receiving end (Phase 2)
- `workflows/fleet-commander/AGENT.md` — fleet commander workflow
- `devops/fleet-agent.md` — fleet agent spec
- `devops/fleet-agent-security.md` — security model
- `docs/MCP_FLEET_SETUP.md` — setup guide
- `docs/RUFLO_SETUP.md` — alternative approach
