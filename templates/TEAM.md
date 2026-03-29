# TEAM.md — Team Configuration

> **Status:** Planned — Phase 3
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 3 (Team Support)
> **Target:** Team-level configuration for multi-user deployments

<!-- Copy this template to ~/.openclaw/TEAM.md and fill in your team details -->

## Team Identity

- **Team Name:** [Your Team Name]
- **Organization:** [Organization Name]
- **Gateway URL:** [Internal URL or Tailscale hostname]
- **Timezone:** [e.g., Australia/Melbourne]
- **Primary Contact:** [Identity, e.g., telegram:833846354]

## Members

<!-- List team members. Each should have a USER profile in templates/USERS/ -->

| Name | Identity | Role | Notes |
|------|----------|------|-------|
| Alice | telegram:111222333 | admin | Primary admin |
| Bob | discord:987654321 | user | Developer |

## Roles

| Role | Permissions | Notes |
|------|-------------|-------|
| `admin` | All skills, config read/write | Full access |
| `user` | Cost-tracker, audit-export | Read/execute only |
| `readonly` | Status queries only | External stakeholders |

## Shared Resources

<!-- Resources shared across the team -->

- **Shared pricing config:** `~/.openclaw/costs/pricing.json`
- **Audit log retention:** 90 days
- **Session cleanup:** 2 hours (stale threshold)

## Notification Routing

<!-- Where to send team notifications -->

- **Alerts:** telegram:833846354 (admin channel)
- **Weekly reports:** telegram:833846354
- **Security events:** telegram:833846354 (immediate)

## Notes

<!-- Team-specific operational notes -->

_Add your team's operational context here._
