# SKILL: rbac — Authorization Control

Controls who can invoke skills and send commands to the OpenClaw gateway.

## Overview

Authorization is implemented in two phases:

| Phase | Mechanism | Status |
|-------|-----------|--------|
| Phase 2 | Simple allowlist (`~/.openclaw/authorized-users`) | ✅ Active |
| Phase 3 | Casbin RBAC (role-based, policy files) | 🗓 Planned |

---

## Phase 2: Simple Allowlist

### How It Works

The `check-auth` script reads `~/.openclaw/authorized-users`. If the sender's identity is in the file, they get `PERMIT`. If not, `DENY`.

**Backward compatible:** If the file does not exist, everyone gets `PERMIT` (opt-in security model).

### Identity Format

```
platform:id
```

Examples:
- `telegram:833846354`
- `discord:987654321`
- `slack:U012AB3CD`

### The authorized-users File

Location: `~/.openclaw/authorized-users`

```
# OpenClaw Authorized Users
# One identity per line: platform:id
# Lines starting with # are comments. Blank lines are ignored.

telegram:833846354
discord:987654321
```

A template is available at `templates/authorized-users.template`.

### Running check-auth

```bash
# Check a sender identity
skills/rbac/check-auth telegram:833846354
# Output: PERMIT or DENY

# Run as a pre-flight check in a skill wrapper
RESULT=$(skills/rbac/check-auth "${SENDER_IDENTITY}")
if [[ "$RESULT" != "PERMIT" ]]; then
    echo "Access denied"
    exit 1
fi
```

### Audit Trail

All `DENY` events are logged to `~/.openclaw/audit/auth-denials.jsonl`:

```json
{"ts": 1743174060, "action": "auth_denied", "sender": "telegram:999999999", "reason": "user not in allowlist"}
```

---

## Phase 3: Casbin RBAC (Planned)

Phase 3 will replace the flat allowlist with full role-based access control using [Casbin](https://casbin.org/).

### Planned Features

- **Roles:** `admin`, `operator`, `viewer`, `readonly`
- **Policies:** Fine-grained per-skill permissions (e.g., `operator` can run `gateway-restart` but not `config-pull`)
- **Policy files:** `~/.openclaw/rbac/policy.csv` + `~/.openclaw/rbac/model.conf`
- **Hot reload:** Policy changes take effect without gateway restart

### Planned Policy Format

```csv
# policy.csv
p, admin,    *,              *
p, operator, gateway-restart, exec
p, operator, health-check,   read
p, viewer,   *,              read

# Role assignments
g, telegram:833846354, admin
g, discord:987654321,  operator
```

### Migration Path

Phase 2 → Phase 3 migration:
1. Install Casbin Python library: `uv add casbin`
2. Generate initial `policy.csv` from existing `authorized-users` (all get `admin` role)
3. Replace `check-auth` calls with `check-auth-casbin` (drop-in replacement)
4. Tune policies as needed

---

## Files

| File | Description |
|------|-------------|
| `skills/rbac/check-auth` | Phase 2 allowlist check script (UV) |
| `templates/authorized-users.template` | Example authorized-users file |
| `~/.openclaw/authorized-users` | Runtime allowlist (not in repo) |
| `~/.openclaw/audit/auth-denials.jsonl` | Audit log of denied requests |
