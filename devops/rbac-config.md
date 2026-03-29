# RBAC Configuration — Desired State Spec

> **Status:** Phase 2 (allowlist) → Phase 3 (Casbin)
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 3 (Team Support + RBAC)
> **Implements:** `skills/rbac/check-auth` + planned Casbin integration

## Overview

OpenClaw uses a progressive RBAC model:
- **Phase 2:** Flat allowlist (`~/.openclaw/authorized-users`) — who can talk to the agent
- **Phase 3:** Casbin-based RBAC — who can do what with which resources

## Phase 2: Allowlist Configuration

The `authorized-users` file lives at `~/.openclaw/authorized-users`.
Copy the template to get started:

```bash
cp templates/authorized-users.template ~/.openclaw/authorized-users
```

### Format

```
# One identity per line. Platform:ID format.
# Lines starting with # are comments. Blank lines are ignored.
telegram:833846354
discord:987654321
slack:U012AB3CD
```

### Supported Platforms

| Platform | Format | Notes |
|----------|--------|-------|
| `telegram` | `telegram:<user_id>` | Numeric Telegram user ID |
| `discord` | `discord:<user_id>` | Numeric Discord user ID |
| `slack` | `slack:<user_id>` | Slack user ID (starts with U) |
| `whatsapp` | `whatsapp:<phone>` | E.164 format phone number |

### Security Behavior

- **File missing:** PERMIT all (opt-in security — backward compatible)
- **File exists but unreadable:** DENY all (fail closed — security error)
- **Empty file:** DENY all (no authorized users)
- **Identity in file:** PERMIT
- **Identity not in file:** DENY (logged to audit)

All checks are logged to `~/.openclaw/audit/YYYY-MM-DD.jsonl`.

### Integration Points

The following skills check authorization before executing:
- `skills/gateway-restart` — checks `OPENCLAW_CALLER_IDENTITY` env var
- (Phase 3) All skills will check via Casbin policy

## Phase 3: Casbin RBAC (Planned)

**Status:** Planned — not yet implemented  
**Reference:** [casbin/casbin](https://github.com/casbin/casbin)

Casbin provides policy-based RBAC with:
- Subject (user/agent), action (read/write/execute), resource (skill/config/etc)
- Policy files in `~/.openclaw/rbac/policy.csv`
- Model definition in `~/.openclaw/rbac/model.conf`

### Planned Policy Model (Phase 3)

```
# model.conf
[request_definition]
r = sub, act, obj

[policy_definition]
p = sub, act, obj

[role_definition]
g = _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub) && r.act == p.act && r.obj == p.obj
```

### Planned Policy File (Phase 3)

```csv
# policy.csv
p, admin, execute, gateway-restart
p, admin, execute, cost-tracker
p, admin, read, audit-export
p, user, execute, cost-tracker
p, user, read, audit-export

g, telegram:833846354, admin
g, telegram:111111111, user
```

## See Also

- `skills/rbac/check-auth` — Phase 2 implementation
- `skills/rbac/SKILL.md` — skill documentation
- `templates/authorized-users.template` — allowlist template
- `docs/MULTI_USER_SETUP.md` — full multi-user setup guide (Phase 3)
