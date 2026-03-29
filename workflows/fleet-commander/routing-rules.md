# Fleet Commander — Routing Rules

> These are the **static** routing rules used in Step 1 of intent classification.
> After ≥3 learned examples diverge, `~/.openclaw/fleet/routing-patterns.json` takes
> precedence. See `AGENT.md` for the full learning loop.

## Intent → Operation Mapping

### Health & Status

| Trigger phrases | Operation | Parameters |
|----------------|-----------|------------|
| "check health", "are agents healthy", "health check", "are you healthy" | `fleet_health_check()` | machines=null (all) |
| "what's running", "fleet status", "show machines", "list machines", "show fleet" | `fleet_status()` | — |
| "is `<machine>` healthy", "check `<machine>`" | `fleet_health_check()` | machines=[extracted name] |
| "how is `<machine>` doing", "status of `<machine>`" | `fleet_health_check()` | machines=[extracted name] |

**Examples:**
```
"check if all agents are healthy"       → fleet_health_check(machines=None)
"is mac-mini-01 healthy?"               → fleet_health_check(machines=["mac-mini-01"])
"what machines are in the fleet?"       → fleet_status()
"show me what's running"                → fleet_status()
```

---

### Restart & Recovery

| Trigger phrases | Operation | Parameters |
|----------------|-----------|------------|
| "restart", "reboot gateway", "restart gateway", "bounce" | `fleet_restart()` | graceful=True |
| "restart `<machine>`", "reboot `<machine>`" | `fleet_restart()` | machines=[extracted], graceful=True |
| "force restart", "kill and restart", "hard restart", "force reboot" | `fleet_restart()` | graceful=False |
| "restart all", "reboot all gateways" | `fleet_restart()` | machines=all, graceful=True |

**Decision rule:** Always use `graceful=True` unless the user explicitly says "force",
"kill", "hard", or "immediately". Confirm before restarting all machines at once.

**Examples:**
```
"restart the gateway on mac-mini-01"    → fleet_restart(machines=["mac-mini-01"], graceful=True)
"force restart mac-mini-01"             → fleet_restart(machines=["mac-mini-01"], graceful=False)
"restart all gateways"                  → CONFIRM FIRST, then fleet_restart(machines=all, graceful=True)
```

---

### Updates

| Trigger phrases | Operation | Parameters |
|----------------|-----------|------------|
| "update", "upgrade", "pull latest", "update openclaw" | `fleet_update()` | component="gateway" |
| "update `<machine>`", "upgrade `<machine>`" | `fleet_update()` | machines=[extracted], component="gateway" |
| "update all machines", "upgrade the fleet" | `fleet_update()` | machines=all, component="gateway" |
| "update skills", "refresh skills" | `fleet_update()` | component="skills" |
| "update everything", "full update" | `fleet_update()` | component="all" |
| "push config", "deploy config", "sync config", "push configuration" | `fleet_config_push()` | — |
| "push `<path>` to `<machine>`" | `fleet_config_push()` | extracted path+machine |

**Decision rule:** Updates are write operations — confirm before running on all machines.
Named specific machines can proceed without confirmation.

**Examples:**
```
"update mac-mini-01"                    → fleet_update(machines=["mac-mini-01"], component="gateway")
"pull the latest version on all nodes"  → CONFIRM FIRST, then fleet_update(all, "gateway")
"push config to mac-mini-01"            → fleet_config_push(machines=["mac-mini-01"], config_path=<ask>)
```

---

### Diagnostics

| Trigger phrases | Operation | Parameters |
|----------------|-----------|------------|
| "show logs", "get logs", "view logs" | `fleet_logs()` | machine=<ask>, lines=50 |
| "show logs for `<machine>`" | `fleet_logs()` | machine=extracted, lines=50 |
| "last `<N>` lines from `<machine>`" | `fleet_logs()` | machine=extracted, lines=N |
| "what happened", "what happened on `<machine>`" | `fleet_logs()` | machine=extracted, lines=100 |
| "errors", "show errors", "any errors on `<machine>`" | `fleet_logs()` | machine=extracted, lines=200 |
| "recent activity", "what's been going on" | `fleet_logs()` | machine=<ask if ambiguous>, lines=100 |

**Decision rule:** Log requests are read-only — no confirmation needed. If machine is
ambiguous (fleet has only 1 machine, use it automatically; otherwise ask).

**Examples:**
```
"show logs for mac-mini-01"             → fleet_logs(machine="mac-mini-01", lines=50)
"what happened on mac-mini-01?"         → fleet_logs(machine="mac-mini-01", lines=100)
"last 200 lines from mac-mini-01"       → fleet_logs(machine="mac-mini-01", lines=200)
```

---

## Ambiguity Resolution Rules

1. **Machine not specified (write op):** Ask "Which machine? Options: {inventory list}"
2. **Machine not specified (read op):** Run on all machines (for status/health) or ask (for logs)
3. **Conflicting signals:** Prefer the more specific/recent signal. "restart the gateway forcefully but gently" → ask for clarification.
4. **Unknown intent:** "I'm not sure how to map that to a fleet operation. Did you mean: [top 3 candidates]?"

## Confidence Threshold

- **High confidence (>0.85):** Execute immediately (read ops) or confirm once (write ops)
- **Medium confidence (0.60–0.85):** Show your interpretation first: "I'll call `fleet_restart(mac-mini-01, graceful=True)`. Proceed?"
- **Low confidence (<0.60):** Ask for clarification before doing anything

## Machine Name Extraction

Common patterns:
- "on `<machine>`" — extract `<machine>`
- "for `<machine>`" — extract `<machine>`
- "`<machine>`'s gateway" — extract `<machine>`
- Direct name mention (matches an entry in fleet inventory)

Always validate extracted names against `fleet_status()` inventory before use.
If name doesn't match exactly, suggest the closest inventory entry.
