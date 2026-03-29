# TEAM.md — Team Configuration

> Copy this file to `~/.openclaw/workspace/TEAM.md` and fill in your team details.
> This file configures the shared OpenClaw deployment for your team.

---

## Team Identity

- **Team Name:** [Your Team Name]
- **Organization:** [Organization Name]
- **Purpose:** [What this OpenClaw deployment is used for]
- **Gateway URL:** [Internal URL or Tailscale hostname, e.g., http://10.0.1.5:8000]
- **Primary Timezone:** [e.g., Australia/Melbourne]
- **Primary Contact:** [Identity, e.g., telegram:833846354]

---

## Members

<!-- List all team members. Each member needs a USER profile in USERS/ -->

| Name | Identity | Role | Timezone | Notes |
|---|---|---|---|---|
| Alice | telegram:111222333 | owner | Australia/Melbourne | Primary admin |
| Bob | discord:987654321 | admin | America/New_York | Backend developer |
| Carol | slack:U012AB3CD | operator | Europe/London | DevOps |
| Dave | whatsapp:+61400000000 | observer | Australia/Sydney | Stakeholder |

To add a member:
1. Add a row above
2. Copy `templates/USERS/USER-template.md` → `USERS/<platform>-<id>.md`
3. Add RBAC entry: `g, <identity>, <role>` in `~/.openclaw/rbac/policy.csv`

---

## RBAC Role Assignments

<!-- Summarizes role assignments for this team. Source of truth is policy.csv. -->

| Role | Description | Members |
|---|---|---|
| `owner` | Full access including secret_access | Alice |
| `admin` | All operations except secret_access | Bob |
| `operator` | Run skills, restart gateway, read audit | Carol |
| `observer` | Read-only audit access | Dave |

Default role for new team members: `observer`

---

## Shared Resources

<!-- Resources shared across the entire team -->

### Memory

- **Shared knowledge base:** `~/.openclaw/workspace/memory/shared/`
- **Project context:** `~/.openclaw/workspace/memory/projects/`
- **Team memory:** `~/.openclaw/workspace/MEMORY.md`

### Config

- **Pricing config:** `~/.openclaw/costs/pricing.json`
- **RBAC policy:** `~/.openclaw/rbac/policy.csv`
- **Authorized users:** `~/.openclaw/authorized-users` (Phase 2 fallback)

### Audit

- **Audit log retention:** 90 days
- **Audit directory:** `~/.openclaw/audit/`
- **Session cleanup threshold:** 2 hours (stale sessions)

---

## Communication Channels

<!-- Where OpenClaw sends team notifications and reports -->

| Channel | Purpose | Target |
|---|---|---|
| Primary | All agent responses | telegram:111222333 |
| Alerts | Security/error events | telegram:111222333 |
| Weekly reports | Cost + usage summary | telegram:111222333 |
| Audit events | Auth denials | telegram:111222333 |

---

## Cost Budgets

<!-- Per-agent daily/monthly cost limits. See docs/LITELLM_SETUP.md -->

| Agent | Daily Limit (USD) | Monthly Limit (USD) |
|---|---|---|
| atlas4 | $5.00 | $50.00 |
| forge4 | $10.00 | $100.00 |
| vault4 | $2.00 | $20.00 |
| Team total | $20.00 | $200.00 |

---

## Operational Notes

<!-- Team-specific procedures and context -->

### On-Call

- Primary on-call: Alice (telegram:111222333)
- Escalation: [phone/email]

### Secrets Management

- Secrets stored in: 1Password vault "[YourVaultName]"
- Secret access requests route through: Vault4 agent

### Incident Response

1. Alert fires → Primary on-call notified via Telegram
2. Check audit log: `audit-export --days 1 --format text`
3. Check gateway status: `openclaw gateway status`
4. Escalate if unresolved within 30 minutes

---

## See Also

- `templates/USERS/USER-template.md` — per-user profile template
- `docs/MULTI_USER_SETUP.md` — full setup guide
- `devops/rbac-config.md` — RBAC configuration spec
- `skills/rbac/SKILL.md` — authorization skill
- `skills/user-router/SKILL.md` — user routing skill
