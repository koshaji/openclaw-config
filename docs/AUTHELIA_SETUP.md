# Authelia Setup Guide

Authelia is a lightweight open-source authentication and authorization server providing
2FA, SSO, and forward-auth protection for self-hosted applications. It acts as a
reverse-proxy companion — any request must pass Authelia before reaching your service.

> **Decision guide:** Use Authelia for personal deployments and small teams (1–10 people)
> where simplicity and low resource usage matter. For enterprise SSO with social login
> or SAML, see `docs/AUTHENTIK_SETUP.md`.

---

## What Authelia Provides for OpenClaw

- Single sign-on for LiteLLM and Langfuse dashboards
- 2FA via TOTP (Google Authenticator, Authy) or WebAuthn (hardware keys)
- Forward-auth protection for the OpenClaw gateway web UI
- Per-domain and per-path access rules
- File-based user management (no database needed for small deployments)
- Low resource usage (~50MB RAM)

---

## Architecture

```
Browser Request
      ↓
Nginx / Caddy (reverse proxy)
      ↓ forward-auth check
Authelia (port 9091)
      ↓ PERMIT
OpenClaw Gateway / LiteLLM / Langfuse
```

---

## Prerequisites

- Docker and Docker Compose
- Nginx or Caddy as reverse proxy
- A domain (can be internal: `*.home.lab` via `/etc/hosts` or Tailscale DNS)

---

## Docker Compose Deployment

Create `~/authelia/docker-compose.yml`:

```yaml
version: "3.3"

services:
  authelia:
    image: authelia/authelia:latest
    container_name: authelia
    volumes:
      - ./config:/config
    ports:
      - "9091:9091"
    restart: unless-stopped
    environment:
      TZ: Australia/Melbourne
    healthcheck:
      disable: true

  redis:
    image: redis:alpine
    container_name: authelia_redis
    volumes:
      - redis-data:/data
    restart: unless-stopped

volumes:
  redis-data:
```

---

## Configuration

Create `~/authelia/config/configuration.yml`:

```yaml
---
server:
  host: 0.0.0.0
  port: 9091

log:
  level: info
  file_path: /config/authelia.log

theme: dark

jwt_secret: your-jwt-secret-here  # openssl rand -hex 32

default_redirection_url: https://auth.yourdomain.com

totp:
  issuer: OpenClaw
  period: 30
  skew: 1

webauthn:
  disable: false
  display_name: OpenClaw
  attestation_conveyance_preference: indirect
  user_verification: preferred

authentication_backend:
  file:
    path: /config/users_database.yml
    password:
      algorithm: argon2id
      iterations: 1
      salt_length: 16
      parallelism: 8
      memory: 64

access_control:
  default_policy: deny

  rules:
    # Allow OpenClaw gateway — require at least 1FA
    - domain: gateway.yourdomain.com
      policy: one_factor

    # Protect LiteLLM dashboard — require 2FA
    - domain: litellm.yourdomain.com
      policy: two_factor
      subject: "group:openclaw-admins"

    # Protect Langfuse — require 2FA
    - domain: langfuse.yourdomain.com
      policy: two_factor
      subject: "group:openclaw-admins"

    # Public health endpoint (no auth)
    - domain: gateway.yourdomain.com
      resources:
        - "^/health$"
      policy: bypass

session:
  name: authelia_session
  secret: your-session-secret-here  # openssl rand -hex 32
  expiration: 3600     # 1 hour
  inactivity: 900      # 15 minutes
  remember_me_duration: 1M

  redis:
    host: authelia_redis
    port: 6379

regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m

storage:
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt
  # For production, use SMTP:
  # smtp:
  #   username: no-reply@yourdomain.com
  #   password: your-smtp-password
  #   host: smtp.gmail.com
  #   port: 587
  #   sender: no-reply@yourdomain.com
```

---

## User Database

Create `~/authelia/config/users_database.yml`:

```yaml
---
users:
  alice:
    displayname: "Alice"
    password: "$argon2id$v=19$m=65536,t=3,p=4$..."  # see below for generation
    email: alice@yourdomain.com
    groups:
      - openclaw-owners
      - openclaw-admins

  bob:
    displayname: "Bob"
    password: "$argon2id$v=19$..."
    email: bob@yourdomain.com
    groups:
      - openclaw-admins

  carol:
    displayname: "Carol"
    password: "$argon2id$v=19$..."
    email: carol@yourdomain.com
    groups:
      - openclaw-operators

  dave:
    displayname: "Dave"
    password: "$argon2id$v=19$..."
    email: dave@yourdomain.com
    groups:
      - openclaw-observers
```

Generate a password hash:

```bash
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'YourSecurePassword'
```

---

## TOTP Setup (2FA)

1. Start Authelia: `docker compose up -d`
2. Navigate to `http://localhost:9091`
3. Log in with your username/password
4. You'll be prompted to register TOTP:
   - Open Google Authenticator, Authy, or 1Password
   - Scan the QR code
   - Enter the 6-digit code to verify
5. 2FA is now active for your account

### WebAuthn (Hardware Key / Touch ID)

1. Log in and navigate to Settings → WebAuthn
2. Click **Add WebAuthn Device**
3. Insert your security key (YubiKey, etc.) or use Touch ID
4. Follow browser prompts
5. WebAuthn is now enabled as a 2FA option

---

## Nginx Integration

Add to your Nginx server blocks in `/etc/nginx/sites-available/openclaw`:

```nginx
# Authelia forward-auth endpoint
location /authelia {
    internal;
    set $upstream http://127.0.0.1:9091;
    proxy_pass_request_body off;
    proxy_pass $upstream/api/authz/forward-auth;
    proxy_set_header Content-Length "";
    proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $http_host;
}

# OpenClaw Gateway
server {
    listen 80;
    server_name gateway.yourdomain.com;

    location / {
        auth_request /authelia;
        auth_request_set $target_url $scheme://$http_host$request_uri;
        error_page 401 =302 https://auth.yourdomain.com/?rd=$target_url;

        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Authelia UI
server {
    listen 80;
    server_name auth.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:9091;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## Caddy Integration

Add to `Caddyfile`:

```caddyfile
# Authelia forward-auth middleware (snippet)
(authelia) {
    forward_auth localhost:9091 {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}

# OpenClaw Gateway
gateway.yourdomain.com {
    import authelia
    reverse_proxy localhost:8000
}

# LiteLLM Dashboard
litellm.yourdomain.com {
    import authelia
    reverse_proxy localhost:4000
}

# Langfuse
langfuse.yourdomain.com {
    import authelia
    reverse_proxy localhost:3000
}

# Authelia itself
auth.yourdomain.com {
    reverse_proxy localhost:9091
}
```

---

## Access Rules

Rules are evaluated top-to-bottom; first match wins.

```yaml
access_control:
  default_policy: deny  # Deny everything not explicitly allowed

  rules:
    # Per-domain, per-group rules
    - domain: gateway.yourdomain.com
      policy: one_factor
      subject:
        - "group:openclaw-owners"
        - "group:openclaw-admins"
        - "group:openclaw-operators"

    # Observers can only reach the audit dashboard
    - domain: gateway.yourdomain.com
      resources: ["^/audit/.*"]
      policy: one_factor
      subject: "group:openclaw-observers"

    # Admin-only: config and fleet management endpoints
    - domain: gateway.yourdomain.com
      resources: ["^/(config|fleet)/.*"]
      policy: two_factor
      subject: "group:openclaw-admins"

    # Health endpoint — no auth
    - domain: gateway.yourdomain.com
      resources: ["^/health$"]
      policy: bypass
```

---

## Group to RBAC Role Mapping

Authelia groups map to Casbin roles in `~/.openclaw/rbac/policy.csv`:

| Authelia Group | Casbin Role | Permissions |
|---|---|---|
| `openclaw-owners` | `owner` | All scopes including secret_access |
| `openclaw-admins` | `admin` | All except secret_access |
| `openclaw-operators` | `operator` | skill_exec, audit_read, gateway_restart |
| `openclaw-observers` | `observer` | audit_read only |

Add identity assignments using the format Authelia passes in headers
(`Remote-User` → typically the username):

```csv
# ~/.openclaw/rbac/policy.csv
g, authelia:alice, owner
g, authelia:bob, admin
g, authelia:carol, operator
g, authelia:dave, observer
```

---

## Troubleshooting

### Authelia container fails to start
```bash
docker compose logs authelia
# Common: missing config file, wrong YAML indentation, bad password hash
```

### "Invalid credentials" on login
```bash
# Regenerate password hash
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'NewPassword'
# Update users_database.yml
```

### TOTP code rejected
- Check that the server time is synchronized: `timedatectl status`
- Ensure `skew: 1` in TOTP config (allows ±30s drift)

### Nginx returns 401 even for authorized users
- Check Authelia logs: `docker compose logs authelia | grep -i auth`
- Verify `proxy_set_header X-Original-URL` is set correctly in Nginx
- Check that cookies are set on the correct domain

### WebAuthn doesn't work
- WebAuthn requires HTTPS — use Let's Encrypt or a self-signed cert
- Chrome/Firefox require `secure` context for WebAuthn

---

## See Also

- [Authelia Documentation](https://www.authelia.com/docs/)
- [Authelia GitHub](https://github.com/authelia/authelia)
- `docs/AUTHENTIK_SETUP.md` — feature-rich SSO alternative
- `docs/MULTI_USER_SETUP.md` — multi-user setup guide
- `devops/rbac-config.md` — RBAC configuration spec
