# Multi-User Setup Guide

> **Status:** Planned — Phase 3
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 3 (Team Support + RBAC)
> **Target:** Full guide for setting up OpenClaw in a team environment

## Overview

This guide covers setting up OpenClaw for multi-user team environments with:
- Per-user memory isolation
- Role-based access control (Casbin)
- SSO via Authentik or Authelia
- Per-agent cost budgets via LiteLLM
- Shared audit logging

## Status

This guide is a stub. Implementation is planned for Phase 3.

## Planned Sections

1. **Prerequisites** — LiteLLM (Phase 2), Authentik/Authelia
2. **User Registration** — Adding users to the allowlist, assigning roles
3. **Memory Isolation** — Per-user memory namespacing
4. **RBAC Configuration** — Setting up Casbin policies
5. **SSO Integration** — Connecting Authentik/Authelia to OpenClaw
6. **Cost Per User** — LiteLLM virtual keys per user
7. **Audit Review** — How to review access logs for your team

## Quick Start (Phase 2 — Allowlist Only)

Until Phase 3 is ready, use the allowlist for basic access control:

```bash
# Copy template
cp templates/authorized-users.template ~/.openclaw/authorized-users

# Add team members
echo "telegram:111222333" >> ~/.openclaw/authorized-users
echo "telegram:444555666" >> ~/.openclaw/authorized-users

# Verify
skills/rbac/check-auth telegram:111222333  # Should print: PERMIT
skills/rbac/check-auth telegram:999000111  # Should print: DENY
```

## See Also

- `devops/rbac-config.md` — RBAC configuration spec
- `docs/LITELLM_SETUP.md` — cost per user (via virtual keys)
- `docs/AUTHENTIK_SETUP.md` — SSO option A
- `docs/AUTHELIA_SETUP.md` — SSO option B
- `templates/TEAM.md` — team configuration template
- `templates/USERS/USER-template.md` — user profile template
