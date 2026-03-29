# Authentik Setup Guide

Authentik is an open-source Identity Provider (IdP) providing OAuth 2.0/OIDC, SAML,
SSO, and MFA for self-hosted deployments. Use it when you need enterprise-grade SSO
with social login, detailed audit trails, and rich group management.

> **Decision guide:** Use Authentik for teams of 5+ or when you need SAML, social login,
> or detailed login audit trails. For personal/small-team deployments, see `docs/AUTHELIA_SETUP.md`.

---

## What Authentik Provides for OpenClaw

- OAuth 2.0 / OIDC authentication for the OpenClaw gateway web UI
- SSO for LiteLLM and Langfuse dashboards (one login for all services)
- MFA (TOTP, WebAuthn, Duo)
- Group-based role management → mapped to Casbin RBAC roles
- Login event audit trail (separate from OpenClaw's operational audit log)
- Social login (Google, GitHub, Microsoft)

---

## Architecture

```
User Browser / Telegram Bot
        ↓
OpenClaw Gateway (port 8000)
        ↓ OAuth2 PKCE flow
Authentik (port 9000/9443)
        ↓ Groups
Casbin RBAC policy.csv
```

---

## Prerequisites

- Docker and Docker Compose
- A domain or internal DNS (e.g., `auth.yourdomain.com` or Tailscale hostname)
- 2GB+ RAM for Authentik server + worker
- PostgreSQL 12+ (included in the Compose file below)

---

## Docker Compose Deployment

Create `~/authentik/docker-compose.yml`:

```yaml
version: "3.4"

services:
  postgresql:
    image: docker.io/library/postgres:16-alpine
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
      start_period: 20s
      interval: 30s
      retries: 5
      timeout: 5s
    volumes:
      - database:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${PG_PASS:?error}
      POSTGRES_USER: ${PG_USER:-authentik}
      POSTGRES_DB: ${PG_DB:-authentik}

  redis:
    image: docker.io/library/redis:alpine
    command: --save 60 1 --loglevel warning
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "redis-cli ping | grep PONG"]
      start_period: 20s
      interval: 30s
      retries: 5
      timeout: 3s
    volumes:
      - redis:/data

  server:
    image: ghcr.io/goauthentik/server:2024.12.3
    restart: unless-stopped
    command: server
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: ${PG_USER:-authentik}
      AUTHENTIK_POSTGRESQL__NAME: ${PG_DB:-authentik}
      AUTHENTIK_POSTGRESQL__PASSWORD: ${PG_PASS}
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY:?error}
      AUTHENTIK_ERROR_REPORTING__ENABLED: "false"
    volumes:
      - ./media:/media
      - ./custom-templates:/templates
    ports:
      - "0.0.0.0:9000:9000"
      - "0.0.0.0:9443:9443"
    depends_on:
      postgresql:
        condition: service_healthy
      redis:
        condition: service_healthy

  worker:
    image: ghcr.io/goauthentik/server:2024.12.3
    restart: unless-stopped
    command: worker
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: ${PG_USER:-authentik}
      AUTHENTIK_POSTGRESQL__NAME: ${PG_DB:-authentik}
      AUTHENTIK_POSTGRESQL__PASSWORD: ${PG_PASS}
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY:?error}
      AUTHENTIK_ERROR_REPORTING__ENABLED: "false"
    volumes:
      - ./media:/media
      - ./certs:/certs
      - ./custom-templates:/templates
    depends_on:
      postgresql:
        condition: service_healthy
      redis:
        condition: service_healthy

volumes:
  database:
    driver: local
  redis:
    driver: local
```

Create `~/authentik/.env`:

```bash
# Generate with: openssl rand -base64 36
PG_PASS=your-postgres-password-here
AUTHENTIK_SECRET_KEY=your-secret-key-here-generate-with-openssl-rand-base64-36
PG_USER=authentik
PG_DB=authentik
```

Start Authentik:

```bash
cd ~/authentik
docker compose up -d

# Wait for startup (about 60 seconds)
docker compose logs -f server
```

Access the admin UI at `http://localhost:9000/if/flow/initial-setup/`.

---

## Initial Setup

1. Open `http://localhost:9000/if/flow/initial-setup/`
2. Create the admin account (email + password)
3. Navigate to **Admin Interface** → `http://localhost:9000/if/admin/`

---

## Creating an OAuth2/OIDC Provider for OpenClaw

### Step 1: Create a Provider

1. Go to **Applications** → **Providers** → **Create**
2. Select **OAuth2/OpenID Provider**
3. Configure:
   - **Name:** `OpenClaw Gateway`
   - **Client type:** `Confidential`
   - **Client ID:** Auto-generated (copy this — you'll need it)
   - **Client Secret:** Auto-generated (copy this)
   - **Authorization flow:** `default-provider-authorization-explicit-consent`
   - **Redirect URIs:** `http://localhost:8000/auth/callback` (or your gateway URL)
   - **Signing Key:** `authentik Self-signed Certificate`
   - **Scopes:** `email`, `profile`, `openid`, `groups`

4. Click **Save**

### Step 2: Create an Application

1. Go to **Applications** → **Applications** → **Create**
2. Configure:
   - **Name:** `OpenClaw`
   - **Slug:** `openclaw`
   - **Provider:** Select the provider created above
3. Click **Save**

### Step 3: Create Groups for RBAC Mapping

1. Go to **Directory** → **Groups** → **Create**
2. Create these groups:
   - `openclaw-owners`
   - `openclaw-admins`
   - `openclaw-operators`
   - `openclaw-observers`
3. Add users to appropriate groups

---

## Group to RBAC Role Mapping

In `~/.openclaw/rbac/policy.csv`, add group-based assignments:

```csv
# Authentik group → Casbin role mapping
# Add this section after your individual user assignments:

# When using Authentik, identities come as oidc:<email> or oidc:<sub>
# The OIDC token contains a "groups" claim — map it to roles:

# Direct user assignments (use Authentik user email or sub as identity)
g, oidc:alice@company.com, owner
g, oidc:bob@company.com, admin
g, oidc:carol@company.com, operator
g, oidc:dave@company.com, observer
```

For automatic group sync, use a script that reads Authentik's groups API and
updates `policy.csv`:

```bash
#!/usr/bin/env bash
# sync-authentik-groups.sh — Pull group memberships from Authentik API
# Run via cron or after Authentik webhooks

AUTHENTIK_URL="http://localhost:9000"
AUTHENTIK_TOKEN="your-api-token"

# Fetch members of openclaw-owners group
curl -s "$AUTHENTIK_URL/api/v3/core/groups/?name=openclaw-owners" \
  -H "Authorization: Token $AUTHENTIK_TOKEN" | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for group in data['results']:
    for user in group['users_obj']:
        print(f\"g, oidc:{user['email']}, owner\")
" >> ~/.openclaw/rbac/policy.csv
```

---

## Configuring OpenClaw to Validate Tokens

When OpenClaw's gateway supports OAuth2 validation (Phase 4+), configure it with:

```yaml
# ~/.openclaw/config.yaml (future schema)
auth:
  provider: oidc
  issuer: http://localhost:9000/application/o/openclaw/
  client_id: <CLIENT_ID_FROM_AUTHENTIK>
  client_secret: <CLIENT_SECRET_FROM_AUTHENTIK>
  scopes: [openid, email, profile, groups]
  redirect_uri: http://localhost:8000/auth/callback
  token_endpoint: http://localhost:9000/application/o/token/
  userinfo_endpoint: http://localhost:9000/application/o/userinfo/
  jwks_uri: http://localhost:9000/application/o/openclaw/jwks/
```

Until gateway OIDC support is built, use Authelia as a forward-auth proxy in front
of the gateway (see `docs/AUTHELIA_SETUP.md`).

---

## Protecting the LiteLLM Dashboard

1. In Authentik, create a new Application for LiteLLM
2. Set **Redirect URI** to: `http://localhost:4000/auth/callback`
3. Configure LiteLLM with the OAuth2 credentials
4. Or use Authentik's embedded outpost (proxy provider) to protect the dashboard:

```yaml
# In Authentik: Applications → Providers → Create → Proxy Provider
# Mode: Forward auth (single application)
# External host: http://localhost:4000
# Internal host: http://localhost:4000
```

---

## Troubleshooting

### Container won't start
```bash
docker compose logs postgresql   # Check DB init
docker compose logs server       # Check server errors
```

### "Secret key not set" error
```bash
# Generate a proper secret key
openssl rand -base64 36
# Add to .env: AUTHENTIK_SECRET_KEY=<result>
```

### Can't reach admin UI
```bash
# Check that port 9000 is not blocked
curl -I http://localhost:9000/
# Check container health
docker compose ps
```

### OIDC token validation fails
- Verify the issuer URL matches exactly (trailing slash matters)
- Check that the redirect URI in Authentik matches your gateway URL
- Verify client ID and secret are copied correctly

### Groups not appearing in token
- Edit the Provider → Scopes → Add `groups` to Property Mappings
- Or create a custom scope mapping that includes `ak_groups`

---

## See Also

- [Authentik Documentation](https://docs.goauthentik.io/)
- [Authentik GitHub](https://github.com/goauthentik/authentik)
- `docs/AUTHELIA_SETUP.md` — lighter alternative
- `docs/MULTI_USER_SETUP.md` — multi-user setup guide
- `devops/rbac-config.md` — RBAC configuration spec
