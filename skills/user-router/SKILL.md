# user-router

> **Status:** Planned — Phase 3
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 3 (Team Support + Per-User Context)
> **Target:** Route incoming messages to per-user agent contexts with memory isolation

## Overview

`user-router` enables multi-user support by routing incoming messages to isolated agent contexts based on sender identity. Each user gets their own:
- Memory namespace (`~/.openclaw/users/<identity>/memory/`)
- User profile (`templates/USERS/<identity>.md`)
- Permission scope (from RBAC allowlist)

## Planned Usage

```bash
# Register a new user
./skills/user-router/user-router register telegram:111222333 --name "Alice" --role user

# List registered users  
./skills/user-router/user-router list

# Check a user's context
./skills/user-router/user-router context telegram:111222333
```

## Integration Point

When implemented, user-router will be called by the gateway before each turn to:
1. Identify the sender
2. Load their user profile from `templates/USERS/`
3. Set the memory namespace for this turn
4. Inject user context into the system prompt

## Prerequisites

- Phase 2: `skills/rbac/check-auth` must be working (identity → permit/deny)
- Phase 3: Casbin RBAC for fine-grained per-user permissions
- Phase 3: Per-user memory namespacing in the gateway

## See Also

- `templates/USERS/USER-template.md` — user profile template
- `templates/TEAM.md` — team configuration
- `docs/MULTI_USER_SETUP.md` — full multi-user setup guide
- `devops/rbac-config.md` — RBAC configuration
