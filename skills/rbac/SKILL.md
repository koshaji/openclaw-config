# SKILL: rbac — Authorization Control

Controls who can invoke skills and send commands to the OpenClaw gateway.
Supports two modes: **simple allowlist** (Phase 2) and **Casbin RBAC** (Phase 3).

## Quick Reference

```bash
# Basic identity check (allowlist or Casbin, auto-detected)
check-auth telegram:833846354

# Resource-scoped check (Casbin mode)
check-auth telegram:833846354 skill_exec
check-auth telegram:833846354 gateway_restart

# Resource + action check
check-auth telegram:833846354 config_write write

# Output: PERMIT or DENY (exit 0 or 1)
```

---

## Mode 1: Simple Allowlist (Phase 2)

### When It's Used

The allowlist mode is active when **Casbin policy files do NOT exist** at:
- `~/.openclaw/rbac/model.conf`
- `~/.openclaw/rbac/policy.csv`

This ensures full backward compatibility with Phase 2 deployments.

### How It Works

`check-auth` reads `~/.openclaw/authorized-users`. If the sender's identity is listed, they get `PERMIT`. Otherwise `DENY`.

**Fail-safe defaults:**
- File missing → `PERMIT` all (opt-in security model)
- File unreadable → `DENY` all (fail closed — security error)
- Empty file → `DENY` all

### The authorized-users File

Location: `~/.openclaw/authorized-users`

```
# OpenClaw Authorized Users
# One identity per line: platform:id
# Lines starting with # are comments. Blank lines are ignored.

telegram:833846354
discord:987654321
```

Copy `templates/authorized-users.template` to get started.

---

## Mode 2: Casbin RBAC (Phase 3)

### When It's Used

Casbin mode is active when both policy files exist:
- `~/.openclaw/rbac/model.conf`
- `~/.openclaw/rbac/policy.csv`

On first run (if files are absent but `casbin` is imported), defaults are auto-created.

### Setup

```bash
# 1. Create the RBAC directory
mkdir -p ~/.openclaw/rbac

# 2. Copy the model and policy templates
cp skills/rbac/policy/model.conf ~/.openclaw/rbac/model.conf
cp skills/rbac/policy/policy.csv.template ~/.openclaw/rbac/policy.csv

# 3. Edit policy.csv — assign your identity
nano ~/.openclaw/rbac/policy.csv
# → Add: g, telegram:YOUR_ID, owner

# 4. Test
check-auth telegram:YOUR_ID skill_exec
```

### Role Hierarchy

```
Owner        → All resources, all actions (including secret_access)
  └─ Admin   → skill_exec, config_write, fleet_manage, audit_read, gateway_restart
       └─ Operator  → skill_exec, audit_read, gateway_restart
            └─ Observer  → audit_read only
```

### Permission Scopes

| Resource | Description |
|---|---|
| `skill_exec` | Run any skill via the gateway |
| `config_write` | Modify `~/.openclaw/` config files |
| `fleet_manage` | Manage fleet agents (start/stop/update) |
| `audit_read` | Read audit logs via audit-export |
| `secret_access` | Access secrets (Vault4 / 1Password) |
| `gateway_restart` | Restart the OpenClaw gateway |

### Policy File Format

Location: `~/.openclaw/rbac/policy.csv`

```csv
# Permission rules: p, <role>, <resource>, <action>
p, owner, *, *
p, admin, skill_exec, *
p, operator, audit_read, *
p, observer, audit_read, *

# Role assignments: g, <identity>, <role>
g, telegram:833846354, owner
g, telegram:111222333, admin
g, discord:987654321, operator
```

### Model File

Location: `~/.openclaw/rbac/model.conf`

Uses Casbin's RBAC model with wildcard support in matchers. See
`skills/rbac/policy/model.conf` for the canonical definition.

```ini
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

## Identity Formats

| Platform | Format | Example |
|---|---|---|
| Telegram | `telegram:<user_id>` | `telegram:833846354` |
| Discord | `discord:<user_id>` | `discord:987654321` |
| Slack | `slack:<user_id>` | `slack:U012AB3CD` |
| WhatsApp | `whatsapp:<phone>` | `whatsapp:+61400000000` |

---

## Integration: Skill Pre-flight Check

Add to any skill script that needs authorization:

```bash
# In a shell skill wrapper:
IDENTITY="${OPENCLAW_CALLER_IDENTITY:-}"
RESULT=$(check-auth "$IDENTITY" skill_exec)
if [[ "$RESULT" != "PERMIT" ]]; then
    echo "Access denied for $IDENTITY" >&2
    exit 1
fi
```

```python
# In a Python UV script:
import subprocess, sys

def require_auth(identity: str, resource: str = "skill_exec") -> None:
    result = subprocess.run(
        ["check-auth", identity, resource],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"DENIED: {identity} cannot access {resource}", file=sys.stderr)
        sys.exit(1)
```

---

## Audit Trail

All authorization decisions are logged to `~/.openclaw/audit/YYYY-MM-DD.jsonl`:

```json
{"ts": 1743174060, "agent": "check-auth", "sender": "telegram:999", "action": "auth_check", "resource": "skill_exec", "args": "telegram:999 skill_exec *", "result": "DENY", "reason": "casbin deny — skill_exec/* not permitted for no role assigned", "mode": "casbin"}
```

`DENY` events are also written to `~/.openclaw/audit/auth-denials.jsonl` for quick scanning.

---

## Migration: Allowlist → Casbin

```bash
# Step 1: Install pycasbin (handled automatically by uv)
# Step 2: Set up policy files
mkdir -p ~/.openclaw/rbac
cp skills/rbac/policy/model.conf ~/.openclaw/rbac/model.conf
cp skills/rbac/policy/policy.csv.template ~/.openclaw/rbac/policy.csv

# Step 3: Migrate existing allowlist users to Operator role
while IFS= read -r line; do
    [[ "$line" =~ ^#|^$ ]] && continue
    echo "g, $line, operator" >> ~/.openclaw/rbac/policy.csv
done < ~/.openclaw/authorized-users

# Step 4: Promote your admin identity to owner
echo "g, telegram:YOUR_ID, owner" >> ~/.openclaw/rbac/policy.csv

# Step 5: Verify
check-auth telegram:YOUR_ID skill_exec  # → PERMIT
check-auth telegram:UNKNOWN skill_exec  # → DENY
```

---

## Files

| File | Description |
|---|---|
| `skills/rbac/check-auth` | Main authorization script (UV, auto-detects mode) |
| `skills/rbac/policy/model.conf` | Casbin RBAC model definition |
| `skills/rbac/policy/policy.csv.template` | Policy template with role hierarchy |
| `templates/authorized-users.template` | Phase 2 allowlist template |
| `~/.openclaw/authorized-users` | Runtime allowlist (Phase 2, not in repo) |
| `~/.openclaw/rbac/model.conf` | Runtime Casbin model (Phase 3, not in repo) |
| `~/.openclaw/rbac/policy.csv` | Runtime Casbin policy (Phase 3, not in repo) |
| `~/.openclaw/audit/YYYY-MM-DD.jsonl` | Daily structured audit log |
| `~/.openclaw/audit/auth-denials.jsonl` | Denial-only audit log (legacy compat) |
