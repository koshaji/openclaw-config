# Authelia Setup Guide

> **Status:** Planned — Phase 3
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 4 (Security — OAuth 2 / PKCE)
> **Reference:** [github.com/authelia/authelia](https://github.com/authelia/authelia)

Authelia is a lightweight open-source authentication and authorization server
providing 2FA, SSO, and access control for self-hosted applications.

## Why Authelia for OpenClaw

Authelia is the lighter alternative to Authentik:
- Single binary, lower resource usage (~50MB RAM)
- Good for personal deployments and small teams
- Integrates with nginx/traefik as a forward-auth provider
- File-based user management (no database required for small deployments)

## Status

This guide is a stub. Implementation is planned for Phase 3 (Multi-User/Teams).

**Decision point:** Choose between Authelia and Authentik (see `docs/AUTHENTIK_SETUP.md`).
Authelia is better for personal/small-team use. Authentik for enterprise-style deployments.

## Planned Implementation

- Docker Compose deployment
- Forward-auth integration with nginx reverse proxy
- Protect LiteLLM and Langfuse dashboards
- File-based user/group config mapped to RBAC roles

## See Also

- `docs/AUTHENTIK_SETUP.md` — feature-rich alternative
- `docs/MULTI_USER_SETUP.md` — full multi-user setup guide
- [Authelia Docs](https://www.authelia.com/docs/)
