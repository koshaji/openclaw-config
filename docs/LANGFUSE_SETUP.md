# Langfuse Setup Guide

Langfuse is an open-source LLM observability platform providing detailed traces,
cost analytics, evaluation scores, and session-level insights for AI applications.

> **Prerequisites:** Phase 2 LiteLLM setup (`docs/LITELLM_SETUP.md`). Langfuse integrates
> with LiteLLM via a callback — set up LiteLLM first.

---

## What Langfuse Provides

| Feature | Description |
|---|---|
| **Request tracing** | Full prompt + completion capture with timing |
| **Cost tracking** | Token usage and USD cost per request, per user, per agent |
| **Session analytics** | Multi-turn conversation grouping and analysis |
| **Evaluation scores** | Human feedback and automated scoring per trace |
| **Latency metrics** | P50/P95/P99 latency per model and endpoint |
| **Error tracking** | Failed requests with full context |
| **Dataset management** | Collect production examples for fine-tuning |

---

## Architecture

```
OpenClaw Agent
      ↓ LiteLLM SDK / proxy
LiteLLM Proxy (port 4000)
      ↓ langfuse callback
Langfuse Server (port 3000)
      ↓
PostgreSQL + ClickHouse (or MinIO)
      ↓
Langfuse Web Dashboard
```

---

## Docker Compose Deployment (Self-Hosted)

Create `~/langfuse/docker-compose.yml`:

```yaml
version: "3.5"

services:
  langfuse-server:
    image: langfuse/langfuse:2
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
      DATABASE_URL: postgresql://postgres:postgres@db:5432/langfuse
      NEXTAUTH_SECRET: ${NEXTAUTH_SECRET:-your-nextauth-secret-here}
      SALT: ${LANGFUSE_SALT:-your-salt-here}
      ENCRYPTION_KEY: ${ENCRYPTION_KEY:-your-32-byte-hex-key-here}
      NEXTAUTH_URL: http://localhost:3000
      TELEMETRY_ENABLED: "false"
      LANGFUSE_ENABLE_EXPERIMENTAL_FEATURES: "true"
      # Optional: restrict sign-up to specific email domain
      # AUTH_DOMAINS_WITH_SSO_ENFORCEMENT: "yourdomain.com"
    restart: unless-stopped

  db:
    image: postgres:15-alpine
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 3s
      timeout: 3s
      retries: 10
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: langfuse
    volumes:
      - langfuse-db:/var/lib/postgresql/data

volumes:
  langfuse-db:
    driver: local
```

Create `~/langfuse/.env`:

```bash
# Generate secrets:
# openssl rand -hex 32 → NEXTAUTH_SECRET
# openssl rand -hex 16 → LANGFUSE_SALT
# openssl rand -hex 32 → ENCRYPTION_KEY

NEXTAUTH_SECRET=your-nextauth-secret-here
LANGFUSE_SALT=your-salt-here
ENCRYPTION_KEY=your-32-byte-hex-key-here
```

Start Langfuse:

```bash
cd ~/langfuse
docker compose --env-file .env up -d

# Wait for startup (about 30 seconds)
docker compose logs -f langfuse-server | grep -m1 "ready"
```

Access the dashboard at `http://localhost:3000`. Create an admin account on first visit.

---

## Creating a Project and API Keys

1. Open `http://localhost:3000` → Create account → Create project (`openclaw`)
2. Go to **Settings** → **API Keys** → **Create new API key**
3. Copy the **Public Key** (starts with `pk-lf-...`) and **Secret Key** (starts with `sk-lf-...`)

---

## LiteLLM Integration

### Option A: LiteLLM Proxy Callback (Recommended)

Add to your LiteLLM `config.yaml`:

```yaml
litellm_settings:
  success_callback: ["langfuse"]
  failure_callback: ["langfuse"]

environment_variables:
  LANGFUSE_PUBLIC_KEY: "pk-lf-your-public-key"
  LANGFUSE_SECRET_KEY: "sk-lf-your-secret-key"
  LANGFUSE_HOST: "http://localhost:3000"
```

Restart LiteLLM:

```bash
docker compose restart litellm  # or systemctl restart litellm
```

Every LLM call through LiteLLM now appears as a trace in Langfuse automatically.

### Option B: Direct Python SDK (for custom instrumentation)

Add to your `~/.openclaw/.env`:

```bash
LANGFUSE_PUBLIC_KEY=pk-lf-your-public-key
LANGFUSE_SECRET_KEY=sk-lf-your-secret-key
LANGFUSE_HOST=http://localhost:3000
```

In Python skill scripts (add `langfuse` to UV inline dependencies):

```python
# /// script
# dependencies = ["langfuse>=2.0.0"]
# ///

from langfuse import Langfuse
import os

langfuse = Langfuse(
    public_key=os.environ["LANGFUSE_PUBLIC_KEY"],
    secret_key=os.environ["LANGFUSE_SECRET_KEY"],
    host=os.environ.get("LANGFUSE_HOST", "https://cloud.langfuse.com"),
)

# Create a trace for a session
trace = langfuse.trace(
    name="skill-execution",
    user_id="telegram:833846354",
    session_id="session-abc123",
    metadata={"agent": "forge4", "skill": "audit-export"},
)

# Create a span for an LLM call
span = trace.span(name="llm-call")
generation = span.generation(
    name="claude-response",
    model="claude-sonnet-4-5",
    input=[{"role": "user", "content": "Summarize the audit log"}],
)

# After the call, record the output and cost
generation.end(
    output="Here is the audit summary...",
    usage={"input": 150, "output": 200},
)

langfuse.flush()
```

### Option C: OpenTelemetry (Advanced)

LiteLLM also supports OpenTelemetry export to Langfuse for distributed tracing:

```yaml
# litellm config.yaml
litellm_settings:
  success_callback: ["otel"]

environment_variables:
  OTEL_ENDPOINT: "http://localhost:3000/api/public/otel/v1/traces"
  OTEL_HEADERS: "Authorization=Basic <base64(public:secret)>"
```

---

## Per-Agent Trace Tagging

Tag traces by agent name for easy filtering in the dashboard:

```python
# In your agent's session handler
trace = langfuse.trace(
    name="agent-turn",
    user_id=sender_identity,           # e.g., "telegram:833846354"
    session_id=session_id,
    tags=["agent:atlas4", "channel:telegram"],
    metadata={
        "agent": "atlas4",
        "channel": "telegram",
        "model": "claude-sonnet-4-5",
    },
)
```

In the Langfuse dashboard, filter by tag `agent:atlas4` to see only Atlas4's traces.

---

## Dashboard Walkthrough

### Traces View

`http://localhost:3000/traces`

- Each row = one LLM call (or session turn)
- Click a trace to see the full prompt + completion
- Filter by user_id, date range, model, or tags

### Sessions View

`http://localhost:3000/sessions`

- Groups multi-turn conversations by `session_id`
- Shows total tokens, cost, and duration per session

### Users View

`http://localhost:3000/users`

- Aggregated stats per `user_id`
- Total spend, number of traces, average latency

### Dashboard (Home)

- Total traces, tokens, and cost (daily/weekly/monthly)
- Model usage breakdown
- Error rate over time

### Cost Analytics

```
Settings → Projects → [Your Project] → Pricing
```

Set model prices (they may be out of date in the default config) to get accurate
USD cost calculations.

---

## Langfuse vs Built-in Cost Tracker

| Feature | Langfuse | `skills/cost-tracker` |
|---|---|---|
| Per-trace cost | ✅ Precise (prompt+completion tokens) | ✅ Estimated from audit log |
| Per-user breakdown | ✅ Native | ✅ Via sender filter |
| Dashboard UI | ✅ Full web dashboard | ❌ CLI only |
| Prompt capture | ✅ Full prompt/response logging | ❌ Not captured |
| Quota enforcement | ❌ Alerts only | ✅ Via LiteLLM virtual keys |
| GDPR — delete user data | ✅ User deletion API | ✅ Delete audit log entries |
| Setup complexity | Medium (Docker + LiteLLM) | Low (script only) |
| Resource usage | ~500MB RAM | Negligible |

**When to use Langfuse:**
- You need to see full prompts/responses for debugging
- You want per-user cost analytics with a UI
- You're evaluating model quality over time
- Team of 3+ who want visibility into LLM usage

**When to use just the cost-tracker:**
- Solo developer, no need for full traces
- Resource-constrained deployment
- GDPR: you don't want to store full message content

---

## Data Retention in Langfuse

Configure retention in `docker-compose.yml` environment:

```yaml
environment:
  # Retain traces for 90 days (SOC 2 compliant)
  LANGFUSE_DEFAULT_PROJECT_MAX_RETENTION_DAYS: "90"
```

To delete all data for a user (GDPR erasure):

```bash
# Via API
curl -X DELETE "http://localhost:3000/api/public/users/telegram%3A833846354" \
  -u "pk-lf-your-key:sk-lf-your-secret"
```

---

## Troubleshooting

### Traces not appearing in Langfuse
```bash
# Check LiteLLM logs for callback errors
docker compose logs litellm | grep -i langfuse

# Verify environment variables are set
docker compose exec litellm env | grep LANGFUSE

# Test connectivity from LiteLLM container
docker compose exec litellm curl -I http://langfuse-server:3000
```

### High memory usage
- Reduce `LANGFUSE_MAX_BATCH_EXPORT_ROWS` (default 1000)
- Add a read replica PostgreSQL for heavy query load
- Archive old traces: Dashboard → Settings → Data Retention

### Dashboard shows no cost data
- Go to Settings → Projects → Pricing → verify model names match LiteLLM
- LiteLLM must pass `model` in the request metadata

---

## See Also

- [Langfuse Documentation](https://langfuse.com/docs)
- [Langfuse Self-Hosting Guide](https://langfuse.com/docs/deployment/self-host)
- [LiteLLM + Langfuse Integration](https://docs.litellm.ai/docs/observability/langfuse_integration)
- `docs/LITELLM_SETUP.md` — set up LiteLLM first
- `skills/cost-tracker/SKILL.md` — built-in lightweight cost tracker
- `docs/COMPLIANCE_GUIDE.md` — compliance considerations for trace data
