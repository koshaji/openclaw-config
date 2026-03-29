# Multi-User Setup Guide

Complete guide for deploying OpenClaw in a team environment with per-user memory isolation,
role-based access control, and optionally SSO.

---

## Overview

OpenClaw supports multi-user team deployments where:

- Each user has an isolated memory namespace
- Access is controlled via Casbin RBAC (roles: owner/admin/operator/observer)
- User context (name, timezone, preferences) is injected per turn
- Audit logs record every authorization decision
- Optionally, SSO via Authentik or Authelia manages identity

---

## Memory Isolation Architecture

```
~/.openclaw/workspace/
├── MEMORY.md                    # Team-shared long-term memory
├── TEAM.md                      # Team configuration
├── USERS/
│   ├── telegram-833846354.md    # Alice's user profile
│   └── telegram-111222333.md    # Bob's user profile
├── memory/
│   ├── shared/                  # Team knowledge base (all users can read)
│   │   ├── products.md
│   │   └── processes.md
│   ├── users/
│   │   ├── alice/               # Alice's private memory (only her sessions load this)
│   │   │   ├── MEMORY.md        # Alice's long-term memory
│   │   │   └── 2026-03-29.md    # Alice's daily notes
│   │   └── bob/                 # Bob's private memory
│   │       ├── MEMORY.md
│   │       └── 2026-03-29.md
│   └── projects/                # Shared project context
│       ├── alpha-project.md
│       └── beta-product.md
└── (agent workspace files)
```

**Key principles:**
- Private memory is only loaded in sessions from that user
- Shared memory is available to everyone
- User profiles contain context injected into the system prompt
- Team MEMORY.md holds knowledge relevant to the whole team

---

## Step-by-Step Setup

### Step 1: Configure RBAC

```bash
# Create RBAC directory
mkdir -p ~/.openclaw/rbac

# Copy templates
cp skills/rbac/policy/model.conf ~/.openclaw/rbac/model.conf
cp skills/rbac/policy/policy.csv.template ~/.openclaw/rbac/policy.csv

# Edit policy.csv — assign roles
nano ~/.openclaw/rbac/policy.csv
```

Add role assignments for each team member:

```csv
# Role assignments
g, telegram:833846354, owner    # Alice — owner
g, telegram:111222333, admin    # Bob — admin
g, discord:987654321, operator  # Carol — operator
g, slack:U012AB3CD, observer    # Dave — read-only
```

Verify:

```bash
skills/rbac/check-auth telegram:833846354 skill_exec   # → PERMIT
skills/rbac/check-auth slack:U012AB3CD skill_exec      # → DENY (observer has no skill_exec)
skills/rbac/check-auth slack:U012AB3CD audit_read      # → PERMIT
```

### Step 2: Create User Profiles

For each team member, create a profile in `~/.openclaw/workspace/USERS/`:

```bash
mkdir -p ~/.openclaw/workspace/USERS

# Copy template for Alice
cp templates/USERS/USER-template.md \
   ~/.openclaw/workspace/USERS/telegram-833846354.md

# Edit Alice's profile
nano ~/.openclaw/workspace/USERS/telegram-833846354.md
```

Fill in the key fields:

```markdown
## Identity
- **Name:** Alice
- **Role:** owner
- **Timezone:** Australia/Melbourne
- **Language:** en

## Identities
- telegram:833846354

## Preferences
- **Communication style:** concise
- **Response format:** markdown
```

Repeat for each team member.

### Step 3: Create the Memory Directory Structure

```bash
mkdir -p ~/.openclaw/workspace/memory/shared
mkdir -p ~/.openclaw/workspace/memory/users/alice
mkdir -p ~/.openclaw/workspace/memory/users/bob
mkdir -p ~/.openclaw/workspace/memory/projects

# Initialize each user's long-term memory
cat > ~/.openclaw/workspace/memory/users/alice/MEMORY.md << 'EOF'
# Alice's Long-Term Memory

<!-- Private memory for Alice. Not visible in other users' sessions. -->
EOF

cat > ~/.openclaw/workspace/memory/users/bob/MEMORY.md << 'EOF'
# Bob's Long-Term Memory
EOF
```

### Step 4: Configure Team Profile

```bash
cp templates/TEAM.md ~/.openclaw/workspace/TEAM.md
nano ~/.openclaw/workspace/TEAM.md
```

Fill in:
- Team name and purpose
- Member list (matching USERS/ profiles)
- Communication channels for alerts and reports
- Cost budgets per agent

### Step 5: Test User Routing

```bash
# Look up Alice's context
skills/user-router/user-router telegram:833846354
# Expected output: JSON with name, role, memory_path, etc.

# Look up an unknown identity (returns guest profile)
skills/user-router/user-router telegram:999999999
# Expected output: JSON with name=Guest, role=observer, found=false
```

### Step 6: Verify End-to-End

```bash
# Run the Phase 3 validation suite
bash tests/phase3-validation.sh
```

---

## How RBAC Integrates with User Routing

The flow for each incoming message:

```
1. Message arrives from telegram:833846354
         ↓
2. check-auth telegram:833846354 skill_exec
   → PERMIT (owner role has skill_exec)
         ↓
3. user-router telegram:833846354
   → { name: "Alice", role: "owner", memory_path: "...memory/users/alice/", ... }
         ↓
4. Agent loads:
   - ~/.openclaw/workspace/TEAM.md         (team context)
   - Alice's user profile (from USERS/)    (personal context)
   - ~/.openclaw/workspace/memory/users/alice/MEMORY.md  (private memory)
   - ~/.openclaw/workspace/memory/shared/  (team knowledge)
         ↓
5. Agent responds with Alice's context injected
```

---

## Adding a New Team Member

```bash
# 1. Create user profile
cp templates/USERS/USER-template.md \
   ~/.openclaw/workspace/USERS/telegram-<NEW_ID>.md
nano ~/.openclaw/workspace/USERS/telegram-<NEW_ID>.md

# 2. Add to RBAC policy
echo "g, telegram:<NEW_ID>, operator" >> ~/.openclaw/rbac/policy.csv

# 3. Create memory directory
mkdir -p ~/.openclaw/workspace/memory/users/<username>
echo "# <Username>'s Long-Term Memory" > \
   ~/.openclaw/workspace/memory/users/<username>/MEMORY.md

# 4. Update TEAM.md member list
nano ~/.openclaw/workspace/TEAM.md

# 5. Test
skills/rbac/check-auth telegram:<NEW_ID> skill_exec
skills/user-router/user-router telegram:<NEW_ID>
```

---

## Removing a Team Member

```bash
# 1. Remove from RBAC policy (edit and delete the g, line)
nano ~/.openclaw/rbac/policy.csv

# 2. Archive their profile (don't delete — keep for audit purposes)
mv ~/.openclaw/workspace/USERS/telegram-<ID>.md \
   ~/.openclaw/workspace/USERS/archived/telegram-<ID>.md

# 3. Archive their memory (GDPR: keep until retention period expires)
mv ~/.openclaw/workspace/memory/users/<username> \
   ~/.openclaw/workspace/memory/archived/<username>

# 4. Update TEAM.md
nano ~/.openclaw/workspace/TEAM.md

# 5. Verify denied
skills/rbac/check-auth telegram:<ID> skill_exec  # → DENY
```

---

## Cost Per User (LiteLLM Virtual Keys)

When using LiteLLM (see `docs/LITELLM_SETUP.md`), assign virtual keys per user
to enable per-user cost tracking and budget enforcement:

```bash
# Create a virtual key for Alice with $50/month budget
curl -X POST http://localhost:4000/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "telegram:833846354",
    "max_budget": 50.0,
    "budget_duration": "monthly",
    "metadata": {"name": "Alice", "role": "owner"}
  }'
```

Store the returned key in the user's profile under a `litellm_key` field (or in 1Password).

---

## SSO Integration

For teams that want centralized authentication:

| Option | Best For | Guide |
|---|---|---|
| **Authentik** | Enterprise, social login, SAML | `docs/AUTHENTIK_SETUP.md` |
| **Authelia** | Personal/small team, simple 2FA | `docs/AUTHELIA_SETUP.md` |

Both options map IdP groups to Casbin roles, so `policy.csv` remains the single source
of truth for permissions.

---

## Backup and Recovery

```bash
# Backup all user data
tar -czf ~/openclaw-users-backup-$(date +%Y%m%d).tar.gz \
  ~/.openclaw/workspace/USERS/ \
  ~/.openclaw/workspace/memory/users/ \
  ~/.openclaw/rbac/

# Restore
tar -xzf ~/openclaw-users-backup-YYYYMMDD.tar.gz -C ~/
```

---

## See Also

- `devops/rbac-config.md` — detailed RBAC spec
- `skills/rbac/SKILL.md` — authorization skill
- `skills/user-router/SKILL.md` — user routing skill
- `templates/TEAM.md` — team configuration template
- `templates/USERS/USER-template.md` — user profile template
- `docs/AUTHENTIK_SETUP.md` — SSO with Authentik
- `docs/AUTHELIA_SETUP.md` — SSO with Authelia
- `docs/LITELLM_SETUP.md` — cost tracking per user
- `docs/COMPLIANCE_GUIDE.md` — compliance checklist
