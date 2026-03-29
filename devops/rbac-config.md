# RBAC Configuration — Desired State Spec

> **Status:** Phase 3 (Casbin RBAC active) — Phase 2 (allowlist) supported as fallback
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 3 (Team Support + RBAC)
> **Implements:** `skills/rbac/check-auth` + `skills/user-router/user-router`

## Overview

OpenClaw uses a two-tier progressive RBAC model:

| Tier | Mechanism | Status |
|---|---|---|
| Phase 2 | Flat allowlist (`~/.openclaw/authorized-users`) | ✅ Active (fallback) |
| Phase 3 | Casbin RBAC (policy files, role hierarchy) | ✅ Active when policy files present |

The `check-auth` script auto-detects which mode to use based on whether
`~/.openclaw/rbac/model.conf` and `~/.openclaw/rbac/policy.csv` exist.

---

## Role Hierarchy

```
Owner
├── secret_access (exclusive — owner only)
├── All Admin permissions
│
Admin
├── skill_exec
├── config_write
├── fleet_manage
├── audit_read
├── gateway_restart
│
Operator
├── skill_exec
├── audit_read
├── gateway_restart
│
Observer
└── audit_read
```

Roles are strictly scoped — each role explicitly declares its permissions.
Inheritance is optional and configured in `policy.csv` via `g, child, parent` rules.

---

## Permission Scopes

| Scope | Description | Default Roles |
|---|---|---|
| `skill_exec` | Execute any installed skill | owner, admin, operator |
| `config_write` | Modify OpenClaw config files | owner, admin |
| `fleet_manage` | Start/stop/update fleet agents | owner, admin |
| `audit_read` | Read structured audit logs | owner, admin, operator, observer |
| `secret_access` | Access 1Password / Vault4 secrets | owner only |
| `gateway_restart` | Restart the OpenClaw gateway process | owner, admin, operator |

---

## File Locations

### Runtime Files (not in repo)

```
~/.openclaw/
├── authorized-users          # Phase 2 allowlist (one identity per line)
├── rbac/
│   ├── model.conf            # Casbin model definition
│   └── policy.csv            # Role assignments + permission rules
└── audit/
    ├── YYYY-MM-DD.jsonl      # Daily structured audit log
    └── auth-denials.jsonl    # Denial-only log (backward compat)
```

### Repository Templates

```
openclaw-config/
├── skills/rbac/
│   ├── check-auth            # Authorization script (UV)
│   ├── SKILL.md              # Skill documentation
│   └── policy/
│       ├── model.conf        # Casbin RBAC model
│       └── policy.csv.template  # Policy template
└── templates/
    └── authorized-users.template  # Phase 2 allowlist template
```

---

## Deployment Procedure

### Fresh Deployment (Phase 3 from the start)

```bash
# 1. Install dependency (auto-handled by uv on first run)
# pycasbin is declared inline in check-auth

# 2. Create RBAC directory and copy templates
mkdir -p ~/.openclaw/rbac
cp skills/rbac/policy/model.conf ~/.openclaw/rbac/model.conf
cp skills/rbac/policy/policy.csv.template ~/.openclaw/rbac/policy.csv

# 3. Edit policy.csv — set your owner identity
nano ~/.openclaw/rbac/policy.csv
# Uncomment/add: g, telegram:YOUR_ID, owner

# 4. Verify
skills/rbac/check-auth telegram:YOUR_ID skill_exec   # → PERMIT
skills/rbac/check-auth telegram:UNKNOWN skill_exec   # → DENY
```

### Upgrading from Phase 2 Allowlist

```bash
# 1. Set up Casbin files
mkdir -p ~/.openclaw/rbac
cp skills/rbac/policy/model.conf ~/.openclaw/rbac/model.conf
cp skills/rbac/policy/policy.csv.template ~/.openclaw/rbac/policy.csv

# 2. Migrate existing allowlist users to Operator role
while IFS= read -r line; do
    [[ "$line" =~ ^#|^$ ]] && continue
    echo "g, $line, operator" >> ~/.openclaw/rbac/policy.csv
done < ~/.openclaw/authorized-users

# 3. Promote your admin identity to owner
echo "g, telegram:YOUR_ID, owner" >> ~/.openclaw/rbac/policy.csv

# 4. Test — Casbin now active (both files exist)
skills/rbac/check-auth telegram:YOUR_ID skill_exec
```

---

## Policy File Format

```csv
# ~/.openclaw/rbac/policy.csv

# Permission rules
# p, <role>, <resource>, <action>
p, owner, *, *
p, admin, skill_exec, *
p, admin, config_write, *
p, admin, fleet_manage, *
p, admin, audit_read, *
p, admin, gateway_restart, *
p, operator, skill_exec, *
p, operator, audit_read, *
p, operator, gateway_restart, *
p, observer, audit_read, *

# User role assignments
# g, <platform:id>, <role>
g, telegram:833846354, owner
g, telegram:111222333, admin
g, discord:987654321, operator
g, slack:U012AB3CD, observer
```

---

## Model File Format

```ini
# ~/.openclaw/rbac/model.conf

[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[role_definition]
g = _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub) && (p.obj == "*" || r.obj == p.obj) && (p.act == "*" || r.act == p.act)
```

---

## Audit Requirements

All authorization decisions must be logged. The `check-auth` script automatically
writes to:

1. **Daily log** (`~/.openclaw/audit/YYYY-MM-DD.jsonl`) — all decisions (PERMIT + DENY)
2. **Denial log** (`~/.openclaw/audit/auth-denials.jsonl`) — DENY only (backward compat)

Log entry schema (from `devops/audit-log.md`):

```json
{
  "ts": 1743174060,
  "agent": "check-auth",
  "sender": "telegram:833846354",
  "action": "auth_check",
  "resource": "skill_exec",
  "args": "telegram:833846354 skill_exec *",
  "result": "PERMIT",
  "reason": "casbin permit — roles: owner",
  "mode": "casbin"
}
```

---

## SSO Integration

For teams using Authentik or Authelia for web SSO, map IdP groups to Casbin roles:

| Authentik/Authelia Group | Casbin Role |
|---|---|
| `openclaw-owners` | `owner` |
| `openclaw-admins` | `admin` |
| `openclaw-operators` | `operator` |
| `openclaw-observers` | `observer` |

See `docs/AUTHENTIK_SETUP.md` and `docs/AUTHELIA_SETUP.md` for full integration guides.

---

## Security Behavior Summary

| Condition | Result |
|---|---|
| Neither allowlist nor Casbin files exist | PERMIT all (opt-in security) |
| Only allowlist exists, identity present | PERMIT |
| Only allowlist exists, identity absent | DENY |
| Casbin files exist, policy matches | PERMIT |
| Casbin files exist, no policy match | DENY |
| Allowlist unreadable | DENY (fail closed) |
| Casbin error | DENY (fail closed) |

---

## See Also

- `skills/rbac/SKILL.md` — skill documentation and usage examples
- `skills/rbac/check-auth` — authorization script
- `skills/user-router/SKILL.md` — user routing and context injection
- `docs/MULTI_USER_SETUP.md` — full multi-user setup guide
- `docs/AUTHENTIK_SETUP.md` — SSO with Authentik
- `docs/AUTHELIA_SETUP.md` — SSO with Authelia
- `devops/audit-log.md` — audit log specification
- `devops/security-baseline.md` — security requirements
