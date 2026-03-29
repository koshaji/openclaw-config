# Authentik Setup Guide

> **Status:** Planned — Phase 3
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 4 (Security — OAuth 2 / PKCE)
> **Reference:** [github.com/goauthentik/authentik](https://github.com/goauthentik/authentik)

Authentik is an open-source Identity Provider (IdP) for OAuth 2.0 / OIDC / SAML.
It provides SSO, MFA, and social login for self-hosted deployments.

## Why Authentik for OpenClaw

OpenClaw currently uses a flat allowlist for authorization. Authentik would provide:
- OAuth 2.0 / PKCE authentication for the gateway
- SSO for the LiteLLM and Langfuse dashboards
- Group-based RBAC (maps to Casbin roles in Phase 3)
- Audit logs for login events

## Status

This guide is a stub. Implementation is planned for Phase 3 (Multi-User/Teams).

**Decision point:** Choose between Authentik and Authelia (see `docs/AUTHELIA_SETUP.md`).
Authentik is heavier but more featureful. Authelia is lighter but less flexible.

## Planned Implementation

- Docker Compose deployment alongside LiteLLM
- OpenClaw gateway OAuth 2.0 integration
- Telegram bot → Authentik identity linking
- Group sync to Casbin RBAC policies

## See Also

- `docs/AUTHELIA_SETUP.md` — lighter alternative
- `docs/MULTI_USER_SETUP.md` — full multi-user setup guide
- `devops/rbac-config.md` — RBAC configuration
- [Authentik Docs](https://docs.goauthentik.io/)
