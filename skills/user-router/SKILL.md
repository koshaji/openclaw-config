# SKILL: user-router — Multi-User Context Routing

Routes incoming messages to per-user agent contexts based on sender identity.
Each user gets isolated memory, a role-scoped RBAC profile, and injected preferences.

## Quick Reference

```bash
# Look up user context for an identity
user-router telegram:833846354

# Output (JSON):
# {
#   "identity": "telegram:833846354",
#   "name": "Hani",
#   "role": "owner",
#   "timezone": "Australia/Melbourne",
#   "memory_path": "~/.openclaw/workspace/memory/users/hani/",
#   "preferences": {...},
#   "profile_file": "~/.openclaw/workspace/USERS/telegram-833846354.md",
#   "found": true
# }
```

---

## Overview

`user-router` enables multi-user support by:

1. **Identifying the sender** from their platform identity (`telegram:ID`, `discord:ID`, etc.)
2. **Loading their user profile** from `~/.openclaw/workspace/USERS/<profile>.md`
3. **Returning structured user context** (name, role, timezone, preferences, memory path)
4. **Falling back to guest profile** if no matching profile exists

This context is injected into the agent's system prompt before each turn, giving
each user a personalized, memory-isolated experience.

---

## Identity Formats

| Platform | Format | Example |
|---|---|---|
| Telegram | `telegram:<user_id>` | `telegram:833846354` |
| Discord | `discord:<user_id>` | `discord:987654321` |
| WhatsApp | `whatsapp:<phone>` | `whatsapp:+61400000000` |
| Slack | `slack:<user_id>` | `slack:U012AB3CD` |

---

## User Profile Files

User profiles live in `~/.openclaw/workspace/USERS/`. The `user-router` script
searches by identity using two naming conventions:

1. **Platform-ID format:** `telegram-833846354.md`
2. **Slug format:** `alice.md` (must contain `telegram:833846354` in the `Identities` section)

### Profile Template

Copy `templates/USERS/USER-template.md` and fill it in:

```bash
cp templates/USERS/USER-template.md ~/.openclaw/workspace/USERS/telegram-833846354.md
nano ~/.openclaw/workspace/USERS/telegram-833846354.md
```

---

## Memory Isolation

Each user gets their own private memory namespace:

```
~/.openclaw/workspace/memory/
├── shared/               # Team-wide knowledge (all users can read)
├── users/
│   ├── alice/            # Alice's private memory
│   │   ├── MEMORY.md     # Long-term memory
│   │   └── 2026-03-29.md # Daily notes
│   └── bob/              # Bob's private memory
└── projects/             # Shared project context
```

The `memory_path` returned by `user-router` points to the user's private directory.
The agent loads this path's `MEMORY.md` instead of the global one.

---

## Guest Profile

If no matching profile exists, `user-router` returns a safe guest profile:

```json
{
  "identity": "telegram:999999999",
  "name": "Guest",
  "role": "observer",
  "timezone": "UTC",
  "memory_path": null,
  "preferences": {},
  "profile_file": null,
  "found": false
}
```

Guest users get Observer-level RBAC permissions (audit_read only) unless overridden
in `~/.openclaw/rbac/policy.csv`.

---

## Integration with RBAC

`user-router` provides context; `check-auth` enforces permissions. Use them together:

```bash
# Step 1: Get user context
CONTEXT=$(user-router telegram:833846354)
ROLE=$(echo "$CONTEXT" | python3 -c "import sys,json; print(json.load(sys.stdin)['role'])")

# Step 2: Check specific resource permission
check-auth telegram:833846354 skill_exec
```

Or in a Python skill:

```python
import subprocess, json, sys

def get_user_context(identity: str) -> dict:
    result = subprocess.run(
        ["user-router", identity],
        capture_output=True, text=True, check=True
    )
    return json.loads(result.stdout)

def require_auth(identity: str, resource: str = "skill_exec") -> None:
    result = subprocess.run(
        ["check-auth", identity, resource],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        sys.exit(1)

# Usage
ctx = get_user_context("telegram:833846354")
require_auth("telegram:833846354", "skill_exec")
print(f"Hello {ctx['name']}! Your role is {ctx['role']}.")
```

---

## Files

| File | Description |
|---|---|
| `skills/user-router/user-router` | Main script (UV) |
| `templates/USERS/USER-template.md` | User profile template |
| `~/.openclaw/workspace/USERS/` | Runtime user profiles (not in repo) |
| `~/.openclaw/workspace/memory/users/` | Per-user memory directories |
| `docs/MULTI_USER_SETUP.md` | Full multi-user setup guide |
| `devops/rbac-config.md` | RBAC configuration spec |

---

## See Also

- `skills/rbac/SKILL.md` — authorization control
- `docs/MULTI_USER_SETUP.md` — full team setup guide
- `templates/TEAM.md` — team configuration template
- `templates/USERS/USER-template.md` — user profile template
