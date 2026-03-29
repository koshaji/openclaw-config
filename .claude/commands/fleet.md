---
description:
  "Manage OpenClaw installations across multiple servers - assess state, push updates,
  notify users. Supports natural language commands and --no-ssh MCP mode."
argument-hint: "[server-name | --no-ssh | NL command]"
version: 0.2.0
---

# Fleet Management 🚀

<objective>
Manage OpenClaw installations across your servers. You're the fleet manager — know each
machine personally, their quirks, their users, what they need.
</objective>

<architecture>
Push from master. **The machine you're running this command on is the master.** Compare
fleet servers against this machine's OpenClaw installation (~/.openclaw/ or ~/clawd/),
not against each other.

**Fleet data:** `~/openclaw-fleet/*.md` — one file per remote server. The master has no
fleet file — it's the source of truth. </architecture>

<behavior>
When invoked, read the fleet files, understand current state, identify what needs
attention, and offer to help. Be proactive — don't just report status, offer to fix
things.

Interpret intent naturally. Adapt to what's asked. Sometimes that's a quick health
check, sometimes a full assessment, sometimes pushing an update.

After meaningful updates (new skills, new workflows), offer to notify the admin (if
specified in fleet file). Draft something friendly and contextual. Routine maintenance
doesn't need notifications.

**When sending notifications to admin:** Send from the agent's identity (from
IDENTITY.md on that machine), NOT from the user's personal account. The admin should see
messages from "Bob Steel" or "Cora", not from Gil or Julianna. Use the agent identity as
the sender when crafting messages.

Escalate to the fleet owner when things break that were working. Don't escalate routine
success or expected states. </behavior>

<boundaries>
Be proactive, not reckless. Offering to help is good. Guessing or brute-forcing when
you're missing info is not. If something critical is unknown, ask — don't try random
things hoping one works.
</boundaries>

<graceful-restarts>
When restarting a gateway (local or remote), **always use the gateway-restart skill**
instead of raw `openclaw gateway restart` or `launchctl kickstart`. This prevents
interrupting active conversations or cron jobs mid-execution.

```bash
# Local graceful restart
skills/gateway-restart/gateway-restart restart

# Remote graceful restart
skills/gateway-restart/gateway-restart restart --remote <ssh-host>

# Check if gateway is busy without restarting
skills/gateway-restart/gateway-restart status --remote <ssh-host>

# Force restart when waiting isn't appropriate
skills/gateway-restart/gateway-restart restart --force --remote <ssh-host>
```

The skill waits up to 5 minutes (configurable via `--timeout`) for active queries and
cron jobs to complete before restarting. If the timeout expires, it exits with an error
— use `--force` to override.

**When to use --force:** Only when the gateway is unhealthy and needs immediate restart
regardless of active work (e.g., memory leak, hung process, unresponsive to status
queries). </graceful-restarts>

<post-update-verification>
After EVERY `openclaw update` on any machine, you MUST verify models before moving on:

```bash
openclaw models list | grep -w missing
```

If ANY configured model shows `missing`, the update changed the model catalog and broke
those model IDs.

**Stop the fleet operation.** List all affected machines and their missing models, then
tell the user to run `/update-model` for each one. Do not batch — each machine may need
different model IDs based on its provider configuration. Do not attempt to fix model IDs
inline — the `/update-model` command has mandatory safeguards you cannot replicate from
memory.

Cron job model overrides are not covered by global config fixes. Include any cron jobs
with model errors in the list so the user can address them with `/update-model` too.

This is not optional. Model ID formats change between OpenClaw versions (e.g. hyphens to
dots). Broken model IDs cause silent cron failures that only surface hours later.
</post-update-verification>

<fleet-file-format>
Each server: `~/openclaw-fleet/<server-name>.md`

<!-- prettier-ignore -->
```markdown
# Display Name

**Host:** IP or hostname
**User:** SSH username
**Tailscale:** yes/no

## Notify

- **Admin:** admin name (if notifications go to fleet admin instead of local user)
- **Channel:** iMessage | WhatsApp | Slack | none
- **Target:** phone or handle
- **Style:** brief | detailed

_Note: When Admin is specified, send notifications FROM the agent (per IDENTITY.md), not from the user's personal account._

## Current State

_Last assessed: Feb 3, 2026 at 2:30pm_

- **OpenClaw version:** X.Y.Z
- **Gateway:** running | not running | unknown
- **Skills:** installed skills
- **Workflows:** configured workflows

## Gaps

What needs attention

## Update History

- **Feb 3, 2026:** What was done
```

</fleet-file-format>

## Natural Language Mode

When invoked with a natural language command (no structured flags), the fleet command
routes to the **fleet-commander workflow** for intent classification and execution.

```
/fleet check if all agents are healthy
/fleet restart the gateway on mac-mini-01
/fleet what happened on mac-mini-01 last night?
/fleet show me the fleet status
/fleet push config to all machines
```

The fleet commander:
1. Classifies your intent using `workflows/fleet-commander/routing-rules.md`
2. Extracts machine names and parameters from your message
3. Calls the appropriate `fleet_*` tool via `skills/fleet-mcp-server/`
4. Returns a natural language summary of results

**Confirmation policy:** Read operations (health check, status, logs) run immediately.
Write operations (restart, update, config push) ask for confirmation before executing,
unless you name specific machines explicitly and use confident language.

**Learning:** Every command is logged to `~/.openclaw/fleet/routing-patterns.json`.
After ≥3 similar commands, the commander learns your preferences and stops asking for
confirmation on familiar operations.

---

## --no-ssh Mode

Pass `--no-ssh` to route fleet operations through the MCP server instead of direct SSH.
This is the recommended mode for machines where SSH is not available or not desired.

```bash
# Check health without SSH
/fleet --no-ssh check health

# Restart via MCP server
/fleet --no-ssh restart mac-mini-01

# Push config via MCP server
/fleet --no-ssh push config to mac-mini-01

# Start the MCP server in SSE mode (for persistent use)
./skills/fleet-mcp-server/fleet-mcp-server --transport sse --port 8766
```

**When to use `--no-ssh`:**

| Scenario | Recommendation |
|----------|---------------|
| SSH enabled on all machines | Default SSH mode (faster, simpler) |
| Machines behind NAT / firewall | `--no-ssh` via fleet-agent |
| Scripted/automated operations | `--no-ssh` via MCP server |
| NL commands from Atlas4 | Always uses `--no-ssh` / MCP server |
| Tailscale available | Either mode works; `--no-ssh` preferred |

**How `--no-ssh` works:**

The `--no-ssh` flag routes commands through the fleet-agent inbox/outbox pattern:
1. Command is HMAC-signed and written to `~/.openclaw/fleet-inbox/cmd-<uuid>.json`
2. `fleet-agent` on the target machine picks it up (polls every 30s)
3. Result is written to `~/.openclaw/fleet-outbox/result-<uuid>.json`
4. The fleet command reads the result and returns it

Prerequisites for `--no-ssh` mode:
- `fleet-agent` must be running on each target machine (`skills/fleet-agent/fleet-agent daemon`)
- Shared HMAC key must be configured (`~/.openclaw/fleet/fleet-hmac-key`)
- Fleet inventory must be populated (`~/.openclaw/fleet/inventory.json`)

See `skills/fleet-mcp-server/SKILL.md` for full setup instructions.
