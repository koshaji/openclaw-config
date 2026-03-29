# LiteLLM Setup Guide

> **Status:** Phase 2 — Full Guide
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 2 (Cost Visibility)
> **Reference:** [github.com/BerriAI/litellm](https://github.com/BerriAI/litellm)

---

## What is LiteLLM and Why Use It?

[LiteLLM](https://github.com/BerriAI/litellm) is an open-source proxy that sits between OpenClaw and the LLM APIs (Anthropic, OpenAI, etc.). It provides:

| Feature | Benefit |
|---------|---------|
| **Unified API** | One endpoint for all providers (OpenAI-compatible format) |
| **Budget caps** | Hard spend limits per agent, per model, or globally |
| **Usage dashboard** | Web UI showing real-time cost by model and caller |
| **Virtual keys** | Issue separate API keys per agent — revoke without touching production keys |
| **Rate limiting** | Prevent runaway agents from burning budget |
| **Request logging** | Detailed per-request logs with token counts and costs |
| **Fallback routing** | Automatically route to cheaper model when budget is low |

For OpenClaw deployments, LiteLLM is the **recommended solution for cost visibility** in Phase 2 and multi-user RBAC in Phase 3. It turns the cost-tracker's "best-effort log parsing" into exact, real-time cost data.

---

## Architecture

```
OpenClaw Agent
    │
    │  Sends API requests to LiteLLM proxy
    ↓
http://127.0.0.1:4000  (LiteLLM Proxy)
    │
    ├─ Checks virtual key → applies per-agent budget
    ├─ Logs request + token counts + cost
    ├─ Routes to Anthropic/OpenAI/etc.
    │
    ↓
LLM Provider APIs (Anthropic, OpenAI, etc.)
```

---

## Docker Compose Setup

Create `docker-compose.litellm.yml` (or add to your existing compose file):

```yaml
version: "3.8"

services:
  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: litellm
    restart: unless-stopped
    ports:
      - "127.0.0.1:4000:4000"   # Bind to loopback only (security)
    volumes:
      - ./litellm-config.yaml:/app/config.yaml:ro
      - litellm-data:/data
    environment:
      # Master key — keep this secret, store in .env
      LITELLM_MASTER_KEY: "${LITELLM_MASTER_KEY}"
      # Database for usage tracking
      DATABASE_URL: "postgresql://litellm:litellm@litellm-db:5432/litellm"
      # Optionally set provider API keys here (or pass per-model below)
      ANTHROPIC_API_KEY: "${ANTHROPIC_API_KEY}"
      OPENAI_API_KEY: "${OPENAI_API_KEY}"
    depends_on:
      - litellm-db

  litellm-db:
    image: postgres:16-alpine
    container_name: litellm-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: litellm
      POSTGRES_USER: litellm
      POSTGRES_PASSWORD: litellm
    volumes:
      - litellm-db-data:/var/lib/postgresql/data

volumes:
  litellm-data:
  litellm-db-data:
```

**Create `litellm-config.yaml`:**

```yaml
model_list:
  # Anthropic models
  - model_name: claude-opus-4-6
    litellm_params:
      model: anthropic/claude-opus-4-6
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: claude-sonnet-4-6
    litellm_params:
      model: anthropic/claude-sonnet-4-6
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: claude-haiku-4-5
    litellm_params:
      model: anthropic/claude-haiku-4-5
      api_key: os.environ/ANTHROPIC_API_KEY

  # OpenAI models (optional)
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY

litellm_settings:
  # Enable per-request cost tracking
  success_callback: ["langfuse"]   # Optional: also log to Langfuse
  # Redact sensitive fields from logs
  redact_sensitive_info: true

general_settings:
  # Master key (can also set via LITELLM_MASTER_KEY env)
  master_key: os.environ/LITELLM_MASTER_KEY
  # Enable the management dashboard
  ui_username: admin
  ui_password: os.environ/LITELLM_UI_PASSWORD
```

**Start the proxy:**

```bash
# Add to ~/.openclaw/.env
LITELLM_MASTER_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
LITELLM_UI_PASSWORD=$(python3 -c "import secrets; print(secrets.token_hex(16))")

# Start
docker compose -f docker-compose.litellm.yml up -d

# Verify
curl http://127.0.0.1:4000/health
```

---

## Creating Virtual Keys Per Agent

Virtual keys let you issue separate API credentials per agent, with per-agent budgets. Revoke an agent's key without touching the real Anthropic/OpenAI keys.

**Via API (use master key):**

```bash
# Create a key for atlas4 with $50/month budget
curl -X POST http://127.0.0.1:4000/key/generate \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "key_alias": "atlas4",
    "max_budget": 50.0,
    "budget_duration": "1mo",
    "models": ["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5"],
    "metadata": {"agent": "atlas4", "environment": "production"}
  }'

# Create a key for forge4 with $30/month budget
curl -X POST http://127.0.0.1:4000/key/generate \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "key_alias": "forge4",
    "max_budget": 30.0,
    "budget_duration": "1mo",
    "models": ["claude-sonnet-4-6", "claude-haiku-4-5"],
    "metadata": {"agent": "forge4", "environment": "production"}
  }'
```

**Save the returned `key` values in `~/.openclaw/.env`:**

```bash
# ~/.openclaw/.env
LITELLM_ATLAS4_KEY=sk-...    # atlas4's virtual key
LITELLM_FORGE4_KEY=sk-...    # forge4's virtual key
```

---

## Pointing OpenClaw at the Proxy

Update each agent's configuration to use the LiteLLM proxy:

**In `openclaw.json` (or via `openclaw configure`):**

```json
{
  "gateway": {
    "anthropicBaseUrl": "http://127.0.0.1:4000",
    "apiKey": "${LITELLM_ATLAS4_KEY}"
  }
}
```

**Or set via environment in `~/.openclaw/.env`:**

```bash
# For atlas4
ANTHROPIC_BASE_URL=http://127.0.0.1:4000
ANTHROPIC_API_KEY=${LITELLM_ATLAS4_KEY}
```

**Verify the proxy is working:**

```bash
# Test direct API call through proxy
curl http://127.0.0.1:4000/v1/messages \
  -H "Authorization: Bearer ${LITELLM_ATLAS4_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-haiku-4-5",
    "max_tokens": 50,
    "messages": [{"role": "user", "content": "Say hello"}]
  }'
```

---

## Budget Caps Configuration

LiteLLM enforces hard budget caps. When exceeded, the virtual key returns a 429 error and OpenClaw will surface a "budget exceeded" message.

**Per-agent monthly budgets (set during key creation):**

```bash
# Update existing key budget
curl -X POST http://127.0.0.1:4000/key/update \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"key": "${LITELLM_ATLAS4_KEY}", "max_budget": 75.0}'
```

**Global budget cap (all agents combined):**

In `litellm-config.yaml`:
```yaml
general_settings:
  global_budget: 200.0          # $200 total across all keys
  global_budget_duration: "1mo"
  budget_reset_at: "2026-01-01T00:00:00"  # Monthly reset
```

**Alert on budget threshold (80%):**

```yaml
litellm_settings:
  budget_alerts:
    - type: "budget_crossed"
      threshold: 0.8   # Alert at 80% of budget
      webhook_url: "http://127.0.0.1:18789/webhook/litellm-alert"
```

---

## Dashboard Access

LiteLLM includes a web dashboard for real-time cost visibility.

**Access:** Open `http://127.0.0.1:4000/ui` in your browser.

Login with the `ui_username` and `ui_password` from your config.

**What you'll see:**
- Real-time spend by model and virtual key
- Request latency and error rates
- Budget utilization per agent
- Full request/response logs (with redaction)

**For Tailscale deployments:**

```bash
# Expose dashboard via Tailscale (don't expose to internet)
tailscale serve --bg http://127.0.0.1:4000
# Access at https://<hostname>.tail<network>.ts.net:4000/ui
```

---

## Integration with cost-tracker

Once LiteLLM is running, you can use it as a more reliable data source than session log parsing:

```bash
# Query LiteLLM spend API directly
curl "http://127.0.0.1:4000/spend/logs?start_date=2026-03-01&end_date=2026-03-31" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" | jq '.spend_logs[] | {key_alias, spend}'
```

**In cost-tracker** (future integration):

Add `--litellm` flag to cost-tracker to use the proxy API instead of session log parsing:

```bash
cost-tracker --litellm http://127.0.0.1:4000 --days 7
```

This will provide exact token counts and costs, eliminating the log-parsing uncertainty.

---

## Troubleshooting

**Proxy not starting:**
```bash
docker compose -f docker-compose.litellm.yml logs litellm
```

**API key rejected:**
```bash
# Verify key status
curl http://127.0.0.1:4000/key/info \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -d '{"key": "${LITELLM_ATLAS4_KEY}"}'
```

**Budget exceeded (429 errors):**
```bash
# Check current spend
curl "http://127.0.0.1:4000/spend/keys" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" | jq '.[] | select(.key_alias == "atlas4")'
```

---

## Security Notes

- **Never expose LiteLLM to the internet directly.** Use Tailscale or loopback only.
- Store `LITELLM_MASTER_KEY` in `~/.openclaw/.env`, never in `openclaw.json`.
- Rotate virtual keys quarterly or when an agent is decommissioned.
- Enable `redact_sensitive_info: true` to avoid logging prompt content.
- The LiteLLM UI password should be different from the master key.

---

## See Also

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [LiteLLM GitHub](https://github.com/BerriAI/litellm)
- `docs/LANGFUSE_SETUP.md` — observability integration (Phase 3)
- `workflows/cost-sentinel/AGENT.md` — automated budget alert workflow
- `templates/costs/pricing.json` — fallback pricing for cost-tracker
