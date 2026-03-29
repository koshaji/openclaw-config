# OPA (Open Policy Agent) Setup Guide

> **Status:** Phase 4 — Reference Guide
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 3 (Advanced RBAC — Phase 4)
> **Reference:** [github.com/open-policy-agent/opa](https://github.com/open-policy-agent/opa)
> **CNCF Graduated Project:** Production-ready, cloud-native policy engine

## What is OPA?

Open Policy Agent (OPA) is a **CNCF graduated** general-purpose policy engine that
decouples policy decisions from your application code. Policies are written in **Rego**,
a declarative query language designed for policy.

Where Casbin (Phase 3) is a permission library embedded in your code, OPA is a
standalone policy service that your code queries. This separation makes policies:
- Auditable — every decision can be logged
- Testable — `opa test` runs against your policies
- Dynamic — policies can be updated without restarting your app
- Composable — policies can reference external data sources

---

## OPA vs Casbin: When to Use Each

| Capability | Casbin (Phase 3) | OPA (Phase 4) |
|------------|-----------------|---------------|
| Language | CSV policy files (`p, admin, read`) | Rego (declarative, Datalog-inspired) |
| Policy complexity | Simple RBAC, ABAC | Complex attribute-based, contextual |
| External data | Not natively | First-class (HTTP bundle loading) |
| Audit trail | Manual logging | Built-in decision logging |
| Testing | No built-in test runner | `opa test` — full test suite support |
| Performance | ~microseconds (embedded) | ~1ms (HTTP round-trip to sidecar) |
| K8s integration | Manual | Native (OPA Gatekeeper is a thing) |
| CNCF ecosystem | No | Yes — works with Envoy, Istio, etc. |
| Maintenance | Maintained | Heavily maintained (CNCF graduated) |

### Use Casbin when:
- Simple role-based rules (admin/editor/viewer)
- Single-machine deployments
- No external data sources needed
- Latency is critical (sub-millisecond)
- Team is not familiar with Rego

### Use OPA when:
- Kubernetes deployments
- Complex policies with multiple conditions (time, context, attributes)
- External data needed in policy decisions (e.g., check user in LDAP)
- Team/enterprise needs auditable policy decisions
- Migrating from Casbin for scaling teams
- Policy-as-code with proper testing pipeline

---

## Docker Deployment

### Standalone OPA server

```bash
docker run -d \
  --name opa \
  -p 127.0.0.1:8181:8181 \
  -v $(pwd)/policies:/policies \
  openpolicyagent/opa:latest \
  run --server --addr 0.0.0.0:8181 /policies
```

### As a sidecar alongside the OpenClaw gateway

```yaml
# docker-compose.yml
services:
  openclaw-gateway:
    image: openclaw/gateway:latest
    environment:
      - OPA_URL=http://opa:8181
    depends_on:
      - opa

  opa:
    image: openpolicyagent/opa:latest
    command: run --server --addr 0.0.0.0:8181 /policies
    volumes:
      - ./policies:/policies
    ports:
      - "127.0.0.1:8181:8181"
    restart: unless-stopped
```

### Without Docker (native binary)

```bash
# macOS
brew install opa

# Linux (ARM64)
curl -Lo opa https://github.com/open-policy-agent/opa/releases/latest/download/opa_linux_arm64
chmod +x opa && mv opa /usr/local/bin/

# Run server
opa run --server --addr 127.0.0.1:8181 ./policies/
```

---

## Writing Rego Policies for OpenClaw

### Directory structure

```
policies/
├── openclaw/
│   ├── authz.rego         # Main authorization policy
│   ├── fleet.rego         # Fleet operation permissions
│   ├── agents.rego        # Agent identity rules
│   └── test/
│       ├── authz_test.rego
│       └── fleet_test.rego
└── data/
    ├── agents.json        # Agent roles data
    └── operations.json    # Allowed operations per role
```

### Basic authorization policy (`policies/openclaw/authz.rego`)

```rego
package openclaw.authz

import future.keywords.if
import future.keywords.in

# Default deny
default allow := false

# Allow read operations for any authenticated agent
allow if {
    input.operation in data.operations.read
    agent_is_authenticated
}

# Allow write operations for agents with write role
allow if {
    input.operation in data.operations.write
    agent_has_role("write")
}

# Allow admin operations only for vault4 and designated admins
allow if {
    input.operation in data.operations.admin
    agent_has_role("admin")
}

# Helper: agent is authenticated (in known agents list)
agent_is_authenticated if {
    input.agent_id in data.agents
}

# Helper: agent has the given role
agent_has_role(role) if {
    data.agents[input.agent_id].roles[_] == role
}
```

### Fleet operation policy (`policies/openclaw/fleet.rego`)

```rego
package openclaw.fleet

import future.keywords.if
import future.keywords.in

# Default deny fleet operations
default allow_fleet_op := false

# Health checks and status queries: allow any authenticated agent
allow_fleet_op if {
    input.tool in {"fleet_status", "fleet_health_check", "fleet_logs"}
    agent_is_authenticated
}

# Restart: require write role + cannot restart all machines simultaneously
allow_fleet_op if {
    input.tool == "fleet_restart"
    agent_has_role("write")
    not restarting_all_machines
}

# Restart all: require explicit confirmation + admin role
allow_fleet_op if {
    input.tool == "fleet_restart"
    agent_has_role("admin")
    input.confirmed == true
}

# Update: require write role, only during maintenance windows
allow_fleet_op if {
    input.tool in {"fleet_update", "fleet_config_push"}
    agent_has_role("write")
    in_maintenance_window
}

# Time-based access: maintenance window (Sundays 02:00–06:00 UTC)
in_maintenance_window if {
    day := time.weekday(time.now_ns())
    day == 0  # Sunday
    hour := time.clock(time.now_ns())[0]
    hour >= 2
    hour < 6
}

# Override: admin can always act
allow_fleet_op if {
    agent_has_role("admin")
}

restarting_all_machines if {
    count(input.machines) == 0  # empty = all machines
}

agent_is_authenticated if {
    input.agent_id in data.agents
}

agent_has_role(role) if {
    data.agents[input.agent_id].roles[_] == role
}
```

### Agent data (`policies/data/agents.json`)

```json
{
  "atlas4": {
    "roles": ["read", "write"],
    "description": "Fleet brain — can read and write but not admin"
  },
  "forge4": {
    "roles": ["read"],
    "description": "Executor — read-only fleet access"
  },
  "vault4": {
    "roles": ["read", "write", "admin"],
    "description": "Security gatekeeper — full fleet access"
  }
}
```

### Testing policies

```bash
# Run all tests
opa test ./policies/ -v

# Example test file: policies/openclaw/test/fleet_test.rego
package openclaw.fleet_test

import data.openclaw.fleet

test_health_check_allowed {
    fleet.allow_fleet_op with input as {
        "agent_id": "forge4",
        "tool": "fleet_status"
    } with data.agents as {
        "forge4": {"roles": ["read"]}
    }
}

test_restart_denied_for_readonly_agent {
    not fleet.allow_fleet_op with input as {
        "agent_id": "forge4",
        "tool": "fleet_restart",
        "machines": ["mac-mini-01"]
    } with data.agents as {
        "forge4": {"roles": ["read"]}
    }
}
```

---

## Integrating OPA with fleet-mcp-server

Add OPA authorization check to the fleet-mcp-server RBAC layer:

```python
# In fleet-mcp-server, replace check_rbac() with OPA query:
import httpx

OPA_URL = os.environ.get("OPA_URL", "http://localhost:8181")

async def check_rbac_opa(agent_id: str, tool_name: str, args: dict) -> bool:
    """Check authorization via OPA."""
    payload = {
        "input": {
            "agent_id": agent_id,
            "tool": tool_name,
            "machines": args.get("machines", []),
            "confirmed": args.get("confirmed", False),
        }
    }
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{OPA_URL}/v1/data/openclaw/fleet/allow_fleet_op",
            json=payload,
            timeout=2.0,
        )
        return resp.json().get("result", False)
```

Set `OPA_URL` environment variable to enable OPA mode:
```bash
export OPA_URL=http://localhost:8181
./skills/fleet-mcp-server/fleet-mcp-server
```

When `OPA_URL` is not set, fleet-mcp-server falls back to the local `rbac.json` check
(Casbin-style). This ensures backward compatibility.

---

## OPA Decision Logging

OPA can log every policy decision for audit. Enable in OPA server config:

```yaml
# opa-config.yaml
decision_logs:
  console: true
  reporting:
    min_delay_seconds: 10
    max_delay_seconds: 60
```

Run with config:
```bash
opa run --server --config-file opa-config.yaml /policies
```

Decision log format:
```json
{
  "decision_id": "abc-123",
  "input": {"agent_id": "atlas4", "tool": "fleet_restart", "machines": ["mac-mini-01"]},
  "result": true,
  "timestamp": "2026-03-29T00:00:00Z",
  "path": "openclaw/fleet/allow_fleet_op",
  "metrics": {"timer_rego_eval_ns": 45123}
}
```

---

## Migration Path from Casbin to OPA

### Phase 1: Run side-by-side (no risk)

1. Deploy OPA alongside your existing Casbin setup
2. Log OPA decisions but don't enforce them yet
3. Compare OPA vs Casbin decisions for 2 weeks
4. Fix any policy discrepancies

### Phase 2: Switch to OPA for new operations

1. For any new fleet operations, write Rego policies first
2. Continue using Casbin for existing operations
3. Gradually port Casbin policies to Rego

### Phase 3: Full cutover

1. Remove Casbin dependency from fleet-mcp-server
2. Route all RBAC checks through OPA
3. Archive `~/.openclaw/fleet/rbac.json` (keep for reference)
4. OPA becomes the single source of policy truth

**Migration timeline:** 4–6 weeks for a careful migration. Rush it and you'll have
authorization gaps.

---

## When to Stay on Casbin

Not every deployment needs OPA. Stay on Casbin if:
- Your fleet has ≤5 machines and ≤3 agents
- Policies haven't changed in months
- No compliance/audit requirements for policy decisions
- Your team isn't already familiar with Rego
- You're running on a resource-constrained machine (<2GB RAM)

OPA adds operational complexity. Only pay that cost if you're getting the benefits.

## See Also

- `devops/rbac-config.md` — Casbin RBAC configuration (Phase 2–3)
- `skills/fleet-mcp-server/SKILL.md` — fleet MCP server with RBAC integration
- [OPA Documentation](https://www.openpolicyagent.org/docs/)
- [Rego Playground](https://play.openpolicyagent.org/) — test policies interactively
- [OPA Gatekeeper](https://github.com/open-policy-agent/gatekeeper) — Kubernetes admission control
