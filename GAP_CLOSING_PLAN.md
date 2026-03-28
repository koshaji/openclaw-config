# OpenClaw Config — Gap-Closing Plan

> **Status:** Draft v2 — March 2026  
> **Based on:** Competitive analysis vs AlphaClaw Apex, ClawHQ, OpenClaw Direct MCP, ClawFire  
> **Research:** Open-source ecosystem, community repos (unisone/openclaw-config, digitalknk/openclaw-runbook)  
> **Prepared by:** Forge4 (automated analysis)

---

## 1. Executive Summary

openclaw-config is the most complete open-source, self-hosted AI assistant configuration
layer available today. It offers a thoughtfully designed agent architecture, a strong
skills ecosystem, mature DevOps tooling, and the only production-tested multi-gateway
fleet coordination pattern in the space.

However, compared to commercial competitors (AlphaClaw Apex, ClawHQ, OpenClaw Direct
MCP, ClawFire), it has meaningful gaps in five strategic areas:

1. **Operations** — Fleet management requires SSH; competitors offer zero-SSH control
2. **Economics** — No cost visibility; competitors offer per-model/per-agent dashboards
3. **Teams** — Single-user design; competitors support teams with RBAC
4. **Security** — Solid baseline but lacks automated auth hardening (OAuth 2 / PKCE)
5. **Resilience** — Good health checks but limited true auto-repair

This document maps each gap, references the best open-source tools to integrate (rather
than build from scratch), and provides a phased roadmap.

**Community repos already solving sub-problems:**
- [`unisone/openclaw-config`](https://github.com/unisone/openclaw-config) — Production
  hardening (ThrottleInterval: 5, secret management, session watchdog, agent swarm
  orchestration with smart routing and learning loop). **Reference this first.**
- [`digitalknk/openclaw-runbook`](https://github.com/digitalknk/openclaw-runbook) — Cost
  controls, coordinator/worker patterns, quota-checking scripts, device hygiene guide.
  Honest post-honeymoon operational wisdom.

**Existing strengths to preserve throughout:**
- ✅ Declarative desired-state drift detection (`machine-setup.md`, `machine-setup-linux.md`)
- ✅ Tailscale-native architecture (zero public exposure)
- ✅ Comprehensive health check agent with escalation-to-debugger
- ✅ Free/open source MIT license
- ✅ No databases, no frameworks — markdown and standalone scripts
- ✅ Production-tested multi-gateway coordination via Slack bus

---

## 2. Community Repo Intelligence

Before going into gaps, here's what the wider openclaw-config community has already
solved that this repo should absorb:

### From `unisone/openclaw-config` (v2026.02.27)

**Critical bug fixes in default OpenClaw installs** (their production hardening guide):

| Bug | Impact | Fix |
|-----|--------|-----|
| `${VAR}` syntax broken (issue #9627) | Secrets resolve to plaintext on `doctor` writes | Remove all placeholders from config; use `.env` only |
| API keys leak to LLMs (issue #11202) | All provider keys sent to current model on every turn | `.env`-only approach; zero secrets in `openclaw.json` |
| Exponential crash backoff (issue #4632) | 5-minute recovery downtime after repeated crashes | Add `ThrottleInterval: 5` to LaunchAgent/systemd unit |

**Session management suite** (worth adopting wholesale):
- `session-watchdog.sh` — autonomous stale/maxed session cleanup
- `session-metrics.sh` — metrics snapshots for monitoring
- `session-ops-weekly-report.sh` — weekly ops report to persistent logs
- `session-cleanup.sh` / `session-store-hygiene.sh` — incident response tools

**Agent swarm orchestration** (`workflows/agent-swarm-orchestration.md`):
- Smart model routing with a **learning loop** — tracks task outcomes, overrides keyword
  routing rules with actual performance data after ≥3 similar tasks
- Deterministic agent health checks with **auto-respawn** (max 3 attempts)
- Triple AI code review (Codex + Claude + Gemini)
- Screenshot gate for UI PRs

### From `digitalknk/openclaw-runbook`

**Security patterns** (from `examples/security-hardening.md`):
- Tool policies with `allow`/`deny` lists — especially `exec` and `cron` restriction by
  default (agents that don't need shell shouldn't have it)
- Cost model config: per-model `cost.input`/`cost.output` pricing in `openclaw.json`
- **Device pairing hygiene** (`openclaw devices list/remove/clear`) — stale paired
  devices are persistent entry points; monthly review cadence
- Gateway bind: `"bind": "loopback"` — never expose the gateway port to the network

**Cost controls** (from `examples/security-hardening.md`):
- `check-quotas.sh` — script to check API quota usage across providers
- Hard rules: never give Opus to monitoring agents, cron-scheduled agents, or
  public-facing agents
- Provider dashboard limits ($500/day) with SMS/email alerts at 50%/80%

**Operational patterns** (from `guide.md`):
- Coordinator vs. worker model — one "brain" agent delegates to cheaperspecialized agents
- Cost-first model selection: start with a routing matrix based on task type vs. model cost
- Session context hygiene: compaction thresholds, pruning policies

These community findings should inform which gaps are "already solved elsewhere" vs.
genuinely open problems.

---

## 3. Gap Analysis

### Gap 1: Zero-SSH Fleet Management

| Field | Detail |
|-------|--------|
| **Priority** | P1 |
| **Effort** | L |
| **Competitor benchmark** | AlphaClaw Apex — zero-SSH fleet via API mesh; ClawFire — NL fleet commands via MCP bridge |

#### Current State

`devops/fleet.md` (via `.claude/commands/fleet.md`) manages remote machines using direct
SSH connections over Tailscale. Every fleet operation — health checks, updates, restarts,
config pushes — requires an active SSH session to each machine.

Affected files:
- `.claude/commands/fleet.md` — all remote ops use `ssh <host>` directly
- `devops/machine-setup.md` — verifies SSH Remote Login as a manual prerequisite
- `devops/machine-setup-linux.md` — same SSH dependency

#### Open-Source Options to Evaluate

**Option A: Ansible Pull Mode** ([github.com/ansible/ansible](https://github.com/ansible/ansible))

Ansible's `ansible-pull` subcommand inverts the push model: each fleet node runs a cron
job that pulls a playbook from a Git repo and executes it locally. No inbound SSH
required on nodes.

```
Master (git repo) ← polls ← Fleet Node cron (ansible-pull)
```

**Fit for openclaw-config:** Medium. Ansible adds a significant dependency (Python +
ansible on every node). It's overkill for the current use case. But the *pattern* —
nodes pull config from a central source rather than master pushing to nodes — is
directly applicable and can be implemented with just `git pull` + a shell script.

**Option B: Netbird** ([github.com/netbirdio/netbird](https://github.com/netbirdio/netbird))

WireGuard-based overlay network. Not a fleet manager, but it provides the secure
network layer for zero-SSH communication. Fleet nodes connect to each other via an
encrypted mesh without inbound ports.

**Fit:** Better used in combination with the agent-based pattern (see below). Netbird
provides the network; OpenClaw's message channels provide the command protocol.

**Option C: OpenClaw's own message channels (recommended)**

The most architecturally clean solution for openclaw-config specifically: fleet nodes
run a cron-based "fleet agent" that polls for commands via the existing OpenClaw message
channel infrastructure. No new tools required.

Each fleet node already runs an OpenClaw gateway. The master can reach each gateway via
Tailscale-secured HTTPS — no SSH needed. Commands are delivered as messages; results
come back as message responses.

This is the pattern `unisone/openclaw-config`'s agent-swarm-orchestration approximates:
"spawn an agent on a node, get results back, no SSH". Apply the same pattern fleet-wide.

#### Proposed Solution

1. **`devops/fleet-agent.md`** — New: desired-state spec for a fleet inbox/outbox agent.
   Runs as a lightweight cron on each fleet node. Polls for commands from master (via
   OpenClaw message API), executes safe operations (restart, update, health-report),
   returns results.

2. **`skills/fleet-agent/`** — New UV script (inspired by Ansible pull-mode *pattern* but
   without Ansible as a dependency): fetches pending fleet commands from
   `~/.openclaw/fleet-inbox/`, executes them, writes to `~/.openclaw/fleet-outbox/`.

3. **Update `.claude/commands/fleet.md`** — Add `--no-ssh` mode that routes commands
   through the message API instead of SSH. Keep SSH as the bootstrap/fallback path for
   newly provisioned nodes.

4. **`devops/machine-setup.md` / `machine-setup-linux.md`** — Add "Fleet Agent Setup"
   section to desired-state spec. `ThrottleInterval: 5` from `unisone/openclaw-config`
   should be added here too (critical fix for the exponential backoff bug).

**What we're standing on:** Ansible's pull-mode *pattern* (nodes pull, not master push),
implemented with OpenClaw's own primitives rather than adding Ansible as a dependency.

---

### Gap 2: Cost Tracking and Usage Dashboards

| Field | Detail |
|-------|--------|
| **Priority** | P1 |
| **Effort** | M |
| **Competitor benchmark** | ClawHQ — real-time per-model/per-agent cost dashboard, spend alerts, budget caps |

#### Current State

Zero cost visibility in this repo. No files track or report API spend. The health-check
agent and `workflows/cron-healthcheck/AGENT.md` monitor gateway liveness and cron
errors but have no awareness of token consumption or dollar costs.

`digitalknk/openclaw-runbook` has a `check-quotas.sh` script and per-model cost
configuration, but these are manual/advisory — not automated alerting.

#### Open-Source Options to Evaluate

**Option A: LiteLLM Proxy** ([github.com/BerriAI/litellm](https://github.com/BerriAI/litellm))

Self-hosted proxy that intercepts all LLM API calls, tracks tokens per model per virtual
key (which map to agents/users), enforces budget limits, and exposes a dashboard.

```
OpenClaw → LiteLLM proxy → Anthropic/OpenAI/etc.
             ↕
        cost database
             ↕
         dashboard
```

**Features relevant to us:**
- Per-model, per-user/agent spend tracking via virtual keys
- Hard budget caps (block requests when limit exceeded)
- OpenAI-compatible API — OpenClaw just points to the proxy
- Self-hosted, open-source (MIT)
- Integrates with Langfuse for tracing

**Fit:** High for organizations that want a real-time dashboard. The proxy approach is
architecturally clean — all cost tracking is external to openclaw-config. Tradeoff:
adds a new service to deploy and maintain.

**Option B: Langfuse** ([github.com/langfuse/langfuse](https://github.com/langfuse/langfuse))

LLM observability platform. Tracks cost + latency per execution, per span, per user.
Supports Anthropic, OpenAI, and 50+ providers. Self-hostable (requires ClickHouse +
Redis + S3).

**Features relevant to us:**
- Cost tracking per agent session, per skill call, per cron run
- Agent graph visualization
- Prompt versioning
- Alert webhooks on cost anomalies
- OpenTelemetry-compatible

**Fit:** Excellent for observability but heavyweight (ClickHouse + Redis + S3). Better
for teams than individuals.

**Option C: Lightweight cost tracker (recommended for individuals)**

Inspired by `digitalknk/openclaw-runbook`'s `check-quotas.sh` and cost config pattern.
No new services — just a UV script that parses gateway logs for token usage metadata
(most LLM APIs return `usage.input_tokens` / `usage.output_tokens` in API responses,
which appear in gateway logs), applies pricing, writes daily JSON summaries.

```
gateway logs → cost-tracker script → ~/.openclaw/costs/YYYY-MM-DD.json → alerts
```

This is the right default for openclaw-config's philosophy (no new infrastructure).
LiteLLM is the right path for organizations that want a dashboard.

#### Proposed Solution

**Two tiers, choose based on scale:**

**Tier 1 — Individual/small team (no new infrastructure):**

1. **`skills/cost-tracker/`** — New UV script. Parses gateway logs for token usage data.
   Applies per-model pricing from a config file (format borrowed from
   `digitalknk/openclaw-runbook`'s cost model pattern). Writes to
   `~/.openclaw/costs/YYYY-MM-DD.json`.

2. **`workflows/cost-sentinel/AGENT.md`** — New workflow. Runs daily. Reads cost tracker
   output, compares against configurable budgets in `rules.md`, alerts admin if
   thresholds exceeded. Produces a weekly spend digest (inspired by
   `unisone/openclaw-config`'s `session-ops-weekly-report.sh` pattern).

3. **`devops/health-check.md`** — Add a daily cost check: read yesterday's total, alert
   if any agent exceeded daily budget. Add the "never give Opus to monitoring agents"
   rule from `digitalknk/openclaw-runbook` as a documented health check checklist item.

4. **`templates/TOOLS.md`** — Add cost configuration template section with per-model
   pricing (matching `digitalknk`'s `openclaw.json` cost config format).

**Tier 2 — Teams wanting a dashboard:**

5. **`docs/LITELLM_SETUP.md`** — New: guide for deploying LiteLLM proxy alongside
   openclaw-config. Covers: Docker compose setup, virtual key per agent, budget caps,
   pointing OpenClaw at the proxy endpoint. Reference:
   [github.com/BerriAI/litellm](https://github.com/BerriAI/litellm).

6. **`docs/LANGFUSE_SETUP.md`** — New: guide for deploying Langfuse for full LLM
   observability. Reference: [github.com/langfuse/langfuse](https://github.com/langfuse/langfuse).

Cost data format (Tier 1, `~/.openclaw/costs/YYYY-MM-DD.json`):
```json
{
  "date": "2026-03-28",
  "by_agent": {
    "main": { "input_tokens": 120000, "output_tokens": 18000, "estimated_usd": 2.34 },
    "security-sentinel": { "input_tokens": 45000, "output_tokens": 6000, "estimated_usd": 0.89 }
  },
  "by_model": {
    "anthropic/claude-opus-4-6": { "calls": 12, "estimated_usd": 2.10 },
    "anthropic/claude-sonnet-4-6": { "calls": 87, "estimated_usd": 1.13 }
  },
  "total_estimated_usd": 3.23
}
```

---

### Gap 3: Multi-User / Teams Support

| Field | Detail |
|-------|--------|
| **Priority** | P2 |
| **Effort** | XL |
| **Competitor benchmark** | ClawHQ — team workspaces, per-user contexts, admin console; AlphaClaw Apex — org-level fleet management |

#### Current State

The entire design is single-user. `USER.md` describes one human. `MEMORY.md` is one
person's curated context. `SOUL.md` defines one assistant's personality relative to one
user.

The `FLEET_BOOT_PATTERNS.md` document discusses multiple agents but not multiple users
per agent.

#### Open-Source Options to Evaluate

For multi-user identity management at the application layer:

**Option A: Channel-level identity (recommended for most deployments)**

OpenClaw already provides sender identity in every message: Telegram user ID, Discord
user ID, phone number for WhatsApp. For most team deployments, routing based on these
IDs — without a separate IdP — is sufficient.

**Option B: Authentik** ([github.com/goauthentik/authentik](https://github.com/goauthentik/authentik))

Self-hosted, full-featured IdP. OAuth2/OIDC-certified (including PKCE), modern UI, flow
engine for custom auth flows, LDAP/AD integration. Rated best balance of power and
usability for SMBs/teams. Requires a server to run.

**Fit:** Excellent for organizations that already need SSO (overlap with Gap 6). For
teams that just want "multiple people can use the assistant," it's overkill. The
channel-identity approach handles 90% of cases.

**Option C: Authelia** ([github.com/authelia/authelia](https://github.com/authelia/authelia))

Lightweight forward-auth proxy. 20-30MB memory footprint. OIDC-certified. Best for
simple homelab/small-team setups where you want 2FA and access rules without full IdP
complexity.

**Fit:** Good as a gateway layer in front of the OpenClaw web UI (if exposed). Not
suited for the message-channel identity problem.

#### Proposed Solution

A teams layer built on channel-level identity, not a new IdP:

1. **`templates/TEAM.md`** — New template: team profile. Defines shared team context
   (org name, team purpose, shared knowledge base). Loaded alongside individual `USER.md`
   files.

2. **`templates/USERS/USER-template.md`** — Template for per-team-member profiles.
   Each file has: name, Telegram/Discord/WhatsApp ID, role (maps to RBAC from Gap 5),
   timezone, preferences.

3. **`skills/user-router/`** — New UV script. Given an incoming message's sender identity
   (Telegram ID, phone, etc.), looks up the corresponding `USERS/USER-{name}.md` and
   returns the user context for the session.

4. **`docs/MULTI_USER_SETUP.md`** — New guide: deploying a shared assistant for a small
   team using channel-identity routing. Includes memory isolation strategy:

```
~/.openclaw/workspace/
├── MEMORY.md              # Team-shared memory (never personal)
├── memory/
│   ├── shared/            # Team knowledge base
│   ├── users/
│   │   ├── alice/         # Alice's private memory
│   │   └── bob/           # Bob's private memory
│   └── projects/          # Shared project context
```

5. For teams needing full SSO: **`docs/AUTHENTIK_SETUP.md`** — Guide for deploying
   Authentik as the IdP and bridging it to OpenClaw user identity. Reference:
   [github.com/goauthentik/authentik](https://github.com/goauthentik/authentik).

---

### Gap 4: Natural Language Fleet Control

| Field | Detail |
|-------|--------|
| **Priority** | P3 |
| **Effort** | M |
| **Competitor benchmark** | OpenClaw Direct MCP — NL commands via MCP bridge; ClawFire — conversational fleet management |

#### Current State

Fleet management requires knowing the `/fleet` slash command. While well-designed, it's
not accessible to non-technical fleet operators.

The MCP ecosystem (Model Context Protocol) has standardized exactly this pattern: expose
infrastructure operations as MCP tools that any Claude session can invoke via natural
language.

#### Open-Source Options to Evaluate

**Option A: MCP (Model Context Protocol)** ([modelcontextprotocol.io](https://modelcontextprotocol.io))

Open protocol (Anthropic-originated, now community-governed) that standardizes how LLMs
interact with external tools. An MCP server exposes fleet operations as typed tools.
The LLM translates natural language intent into tool invocations.

```
"Check if all agents are healthy"
  → Claude (MCP client)
  → fleet-mcp-server (MCP server)
  → fleet operations
  → structured results back to Claude
  → natural language summary
```

**Available MCP servers relevant to fleet management:**
- **Bifrost** — Production MCP gateway with security isolation, observability, and
  grouping for multi-team deployments
- **mcp-shell** — Generic shell command execution over MCP (risky without RBAC)
- **Custom MCP servers** — Simple to implement; MCP SDKs available for Python and Node

**Fit:** High. OpenClaw already uses Claude Code, which is MCP-aware. Exposing fleet
operations as an MCP server lets any Claude session invoke them without knowing the
syntax. The gap is just writing the MCP server wrapper around existing operations.

**Option B: `unisone/openclaw-config` agent swarm orchestration pattern**

Their `route-task.sh` + `spawn-agent.sh` + learning loop is exactly what "NL fleet
control" looks like from the inside — the orchestrator agent translates intent to
specific operations via learned routing rules. The architecture document is at:
`workflows/agent-swarm-orchestration.md` in their repo.

**What they solved:** Smart routing based on task description → right agent + right model.
The learning loop builds a `patterns.json` that improves routing over time.

**Fit:** Directly applicable to fleet management. Adopt this pattern for
`workflows/fleet-commander/`.

**Option C: Ruflo** ([github.com/ruvnet/ruflo](https://github.com/ruvnet/ruflo))

Open-source swarm orchestration platform purpose-built for Claude (v3.5+, MIT license).
Supports hierarchical (queen/worker) and mesh (peer-to-peer) swarm patterns out of the
box. Ships with 100+ pre-built agents, is MCP-native, and supports multi-LLM routing
(Claude / GPT / Gemini with smart model selection).

**Key capabilities:**
- Self-optimizing routing (SONA) — learns which agent/model handles each task best
- Fault-tolerant consensus with auto-respawn (similar to `unisone`'s health loop, but
  built-in rather than scripted)
- HNSW vector search and RAG built-in — no separate embedding service required
- 324MB Docker image (`npx ruflo` also works for local use)
- MCP-native — exposes swarm operations as MCP tools, directly consumable by Claude

**Fit: HIGH** — Ruflo directly solves both the NL fleet control problem *and* the
broader swarm orchestration challenge. It could replace the custom `fleet-commander`
workflow entirely, providing a production-ready swarm layer instead of a hand-rolled
script-based orchestrator. Recommended evaluation path: use Ruflo's swarm patterns for
agent coordination, MCP for the tool interface.

#### Proposed Solution

**Evaluate Ruflo before building custom.** Ruflo's swarm orchestration capabilities
(SONA routing, auto-respawn, MCP-native tooling) may replace the need for a custom
`fleet-commander` workflow entirely. Pilot Ruflo first; fall back to the custom MCP
approach if Ruflo's operational overhead outweighs its benefits for the deployment scale.

1. **`docs/RUFLO_SETUP.md`** — New: evaluation guide for deploying Ruflo as the swarm
   orchestration layer. Covers Docker / npx setup, configuring queen/worker topology for
   the openclaw-config fleet, connecting Ruflo's MCP interface to Claude sessions, and
   mapping existing fleet operations to Ruflo agents.

2. **`workflows/fleet-commander/AGENT.md`** — New workflow implementing the
   `unisone/openclaw-config` smart-routing pattern for fleet operations (fallback if
   Ruflo evaluation does not pan out). Accepts NL commands, routes to the appropriate
   fleet operation, maintains a learning log of what operations were most effective.

3. **`skills/fleet-mcp-server/`** — New UV script that runs a lightweight MCP server
   exposing fleet operations as typed tools (used alongside or instead of Ruflo):
   - `fleet_health_check(machines: list[str])` → health status
   - `fleet_update(machines: list[str], component: str)` → deploy update
   - `fleet_restart(machines: list[str], graceful: bool)` → restart gateways
   - `fleet_status()` → full fleet inventory

4. **Update `.claude/commands/fleet.md`** — Add NL entry point: when invoked without
   structured arguments, route to `fleet-commander` workflow. Reference the MCP server
   for programmatic invocation.

5. **`docs/MCP_FLEET_SETUP.md`** — Guide for connecting the fleet MCP server to a
   Claude session. References the MCP protocol spec and explains how to register the
   server.

**What we're standing on:** Ruflo (swarm orchestration + MCP-native tooling) as the
recommended first-pass; MCP (open protocol) + `unisone/openclaw-config`'s smart routing
pattern as the fallback for teams that prefer a lighter-weight custom solution.

---

### Gap 5: Permissions and RBAC

| Field | Detail |
|-------|--------|
| **Priority** | P2 |
| **Effort** | L |
| **Competitor benchmark** | OpenClaw Direct MCP — OAuth 2 + PKCE scope enforcement; AlphaClaw Apex — role-based operation permissions |

#### Current State

No access control layer. Any message that reaches the gateway has full operator trust.
The health check admin model is the only distinction between users — for notification
routing only, not permission gating.

`digitalknk/openclaw-runbook` has per-agent tool policies (`allow`/`deny` lists) in
`openclaw.json`, which is the right first step but is config-level, not user-level.

#### Open-Source Options to Evaluate

**Option A: Casbin** ([github.com/casbin/casbin](https://github.com/casbin/casbin))

Multi-language authorization library (Python, Node.js, Go, etc.) that enforces policies
via a CONF model file + policy file. Config-driven: change from ACL to RBAC to ABAC by
editing files, no code changes.

Key capabilities for openclaw-config:
- **Native RBAC with role hierarchies** — perfect for Owner → Admin → Operator →
  Observer chain
- **Domain-based multi-tenancy** — per-channel or per-team role scoping
- **Embeddable** — sub-50ms policy checks; can be embedded directly in a UV skill script
- **AI agent focus (2025 updates)** — Casbin blog explicitly covers MCP scope
  enforcement (`mcp:tools:weather` style scopes) and OAuth OBO flows for agent
  hierarchies
- **File-based storage** — policies stored in plaintext files, consistent with
  openclaw-config's file-first philosophy

**Fit:** Very high. Casbin's Python library (`casbin` on PyPI) can be imported directly
into a UV skill script. Policies live in `~/.openclaw/rbac/policy.csv` (Casbin format).
No server required.

**Option B: OPA (Open Policy Agent)** ([github.com/open-policy-agent/opa](https://github.com/open-policy-agent/opa))

CNCF-graduated policy engine using Rego language. Stronger for cloud-native/Kubernetes
environments. Rego is more expressive than Casbin's CONF format but has a steeper
learning curve.

**Fit:** Overkill for a single-machine or small-fleet deployment. Better suited if
openclaw-config is deployed in a Kubernetes environment or if policies need to interact
with external systems.

**Recommendation: Casbin for Phase 2, OPA as Phase 3 option for enterprise deployments.**

#### Proposed Solution

1. **`devops/rbac-config.md`** — New: desired-state spec for RBAC. Defines role
   hierarchy (Owner → Admin → Operator → Observer) and per-channel user assignments.
   Written in human-readable markdown; the `rbac` skill converts it to Casbin policy
   format on deploy.

2. **`skills/rbac/`** — New UV script using [Casbin Python](https://github.com/casbin/pycasbin)
   (`pip install casbin`). Given a user identity and requested operation, checks the
   Casbin policy and returns permit/deny. Reads from
   `~/.openclaw/rbac/policy.csv` and `~/.openclaw/rbac/model.conf`.

   Casbin model for openclaw-config:
   ```ini
   [request_definition]
   r = sub, obj, act

   [policy_definition]
   p = sub, obj, act

   [role_definition]
   g = _, _

   [policy_effect]
   e = some(where (p.eft == allow))

   [matchers]
   m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
   ```

3. **`templates/AGENTS.md`** — Add RBAC integration section: agents check role before
   executing any tool with side effects. Template code for the permission check.

4. **`devops/machine-security-review.md`** — Add RBAC audit section: verify
   `rbac/policy.csv` exists, is not world-readable, roles are assigned.

5. **`devops/machine-setup.md` / `machine-setup-linux.md`** — Add RBAC setup to
   desired-state specification.

**Pre-RBAC quick win (Phase 2 start):** A simple allowlist in
`~/.openclaw/authorized-users` (one Telegram ID per line) provides meaningful protection
with 10 lines of code. Ship this first, then layer Casbin on top in Phase 3.

---

### Gap 6: Enterprise Readiness (Audit Logs, Compliance, SSO)

| Field | Detail |
|-------|--------|
| **Priority** | P3 |
| **Effort** | XL |
| **Competitor benchmark** | ClawHQ — centralized audit logs, SOC 2 posture, SSO via SAML/OIDC |

#### Current State

`devops/machine-setup.md` has a `command-logger` hook for raw audit trailing. But there
is no structured, machine-readable audit format, no log shipping, no SSO, and no
compliance posture documentation.

`digitalknk/openclaw-runbook` has data retention policies and `logging.redactSensitive`
configuration, which is a good start.

#### Open-Source Options: SSO

**Authentik** ([github.com/goauthentik/authentik](https://github.com/goauthentik/authentik))

Best balance for teams:
- Full IdP (not just a proxy like Authelia)
- OIDC-certified including PKCE
- SAML support (for legacy enterprise apps)
- Modern admin UI with flow-based auth
- Moderate resource use (lighter than Keycloak)
- Self-hosted Docker Compose deployment

**Authelia** ([github.com/authelia/authelia](https://github.com/authelia/authelia))

Better for individuals/homelabs:
- Lightweight forward-auth proxy (20-30MB)
- OIDC-certified
- No SAML
- Perfect for protecting the OpenClaw web dashboard behind 2FA
- No separate user management beyond the config file

**Keycloak** ([github.com/keycloak/keycloak](https://github.com/keycloak/keycloak))

Enterprise-grade but heavy:
- Full SAML + OIDC + LDAP/AD
- Battle-tested at Netflix, Cisco scale
- High resource requirements
- Only warranted if organization already uses Keycloak

**Recommendation:** Authentik for teams wanting SSO; Authelia for individuals wanting
2FA on the web UI.

#### Proposed Solution

1. **`devops/audit-log.md`** — New: specification for a structured, append-only audit
   log. Every agent action with side effects writes a JSON entry to
   `~/.openclaw/audit/YYYY-MM-DD.jsonl`:
   ```json
   {"ts": 1743174000, "agent": "main", "user": "alice@telegram", "action": "skill_exec",
    "skill": "quo", "args": ["call", "+14155551234"], "session": "abc123"}
   ```
   Complements `digitalknk/openclaw-runbook`'s `logging.redactSensitive` config —
   structured audit goes to this log, sensitive content is redacted per their pattern.

2. **`skills/audit-export/`** — New UV script. Exports audit JSONL to configurable
   destinations: local file, S3 bucket, syslog, webhook. Supports time-range filtering.

3. **`devops/machine-setup.md`** — Extend the Hooks section to write structured audit
   entries (not just raw command logs). Add audit directory to desired-state verification.

4. **`docs/COMPLIANCE_GUIDE.md`** — New: guidance for organizations wanting to use
   openclaw-config in regulated environments. Maps architecture to common compliance
   frameworks. References `digitalknk`'s data retention config patterns.

5. **`docs/AUTHENTIK_SETUP.md`** — New: SSO deployment guide using Authentik. Covers:
   Docker Compose setup, creating an OAuth2/OIDC provider, configuring OpenClaw to
   validate tokens, mapping Authentik groups to openclaw-config RBAC roles.

6. **`docs/AUTHELIA_SETUP.md`** — New: lightweight 2FA guide for protecting the OpenClaw
   web dashboard with Authelia as a forward-auth proxy.

---

### Gap 7: Automated Security Hardening

| Field | Detail |
|-------|--------|
| **Priority** | P1 |
| **Effort** | M |
| **Competitor benchmark** | OpenClaw Direct MCP — OAuth 2 + PKCE automated setup; AlphaClaw Apex — one-click hardening |

#### Current State

`devops/machine-security-review.md` is excellent but reactive. It detects and reports;
it doesn't enforce.

**Critical: `unisone/openclaw-config` has already identified and fixed the three most
dangerous default behaviors** (issues #9627, #11202, #4632). This repo must incorporate
those fixes immediately — they are not optional improvements, they are correctness bugs.

`digitalknk/openclaw-runbook` adds:
- Gateway bind to loopback (never expose to network)
- Tool policy `allow`/`deny` lists
- Device pairing hygiene process
- `logging.redactSensitive: "tools"`

#### Open-Source Pattern: Defense-in-Depth Layers

The security hardening literature (OWASP LLM Top 10, referenced in
`digitalknk/openclaw-runbook`) recommends layered defense for LLM agents:

| Layer | Tool/Pattern | Status in this repo |
|-------|-------------|---------------------|
| Secrets management | `.env` file (chmod 600) | Partially — add `${VAR}` warning |
| Network | Tailscale (zero public ports) | ✅ Already done |
| Process auth | Gateway token (`GATEWAY_TOKEN` in `.env`) | Partially |
| Tool policies | `allow`/`deny` in `openclaw.json` | Not in templates |
| Prompt injection | System prompt hardening in `AGENTS.md` | Partially |
| Audit logging | Structured audit log | Gap 6 |
| RBAC | Casbin | Gap 5 |
| SSO | Authentik/Authelia | Gap 6 |

#### Proposed Solution

1. **Immediate absorption from `unisone/openclaw-config`:**

   Update `devops/machine-setup.md` with:
   ```
   CRITICAL: Add ThrottleInterval: 5 to LaunchAgent/systemd unit (GitHub issue #4632)
   CRITICAL: Remove all secrets from openclaw.json — use .env only (GitHub issues #9627, #11202)
   ```

   Update `devops/mac/ai.openclaw.gateway.plist` and `devops/linux/openclaw-gateway.service`
   with `ThrottleInterval: 5` (or equivalent `RestartSec=5` in systemd).

2. **Absorption from `digitalknk/openclaw-runbook`:**

   Update `templates/AGENTS.md` with tool policy defaults:
   ```json
   "tools": {
     "deny": ["exec", "cron", "gateway", "nodes"]
   }
   ```
   (Only grant `exec` to agents that explicitly need it.)

   Add device hygiene to `devops/machine-security-review.md`:
   ```
   Monthly: openclaw devices list → verify all paired devices → remove unknown
   ```

   Add `logging.redactSensitive: "tools"` to config templates.

3. **`devops/security-baseline.md`** — New: non-negotiable security baseline (gates
   installation). References OWASP LLM Top 10 sections relevant to OpenClaw's
   architecture.

4. **`skills/security-setup/`** — New UV script. One-time setup that:
   - Validates all secrets are in `.env` (not `openclaw.json`)
   - Sets `chmod 700 ~/.openclaw` and `chmod 600 ~/.openclaw/.env`
   - Validates gateway bind is loopback
   - Adds `ThrottleInterval: 5` to LaunchAgent/systemd unit if missing
   - Generates initial device inventory for monthly review

5. **`skills/openclaw/SKILL.md`** — Add security baseline check to install checklist.

6. **`devops/machine-security-review.md`** — Add `setup` subcommand that runs
   security-baseline checks as a blocking prerequisite. Reference both community repos
   as sources.

---

### Gap 8: Self-Healing (Full Crash Detection + Auto-Repair)

| Field | Detail |
|-------|--------|
| **Priority** | P1 |
| **Effort** | M |
| **Competitor benchmark** | AlphaClaw Apex — PID watchdog, auto-restart with state recovery, config rollback |

#### Current State

`devops/health-check.md` is strong — 30-minute cycle, gateway liveness, model catalog,
cron monitoring, escalation to debugger. The `skills/gateway-restart/SKILL.md` has
graceful restart logic.

Gaps in the self-healing loop:
1. **30-minute detection window** — crash not noticed for up to 30 minutes
2. **No PID watchdog** — nothing restarts the gateway immediately on crash
3. **Exponential backoff bug** — without `ThrottleInterval: 5`, recovery degrades to
   5 minutes after repeated crashes
4. **No config rollback** — bad config update → no auto-rollback path
5. **Backup frequency** — every 4 hours; potential 4-hour state loss window

**`unisone/openclaw-config` has already partially solved this:**
- `production-hardening/scripts/healthcheck.sh` — 5-minute health monitoring with
  auto-restart
- `ThrottleInterval: 5` fix — eliminates exponential backoff
- `session-watchdog.sh` — stale/maxed session cleanup
- `backup-config.sh` — daily backups with integrity verification

#### Open-Source Patterns to Apply

**systemd WatchdogSec** (Linux-native, no dependencies)

The systemd watchdog pattern: a service sets `WatchdogSec=30` in its unit file. If it
doesn't receive a `sd_notify("WATCHDOG=1")` ping within 30 seconds, systemd kills and
restarts it.

For services that don't natively support the watchdog protocol (like the OpenClaw
gateway), a companion script can run the gateway and send watchdog pings on its behalf:

```ini
# openclaw-gateway.service
[Service]
Type=notify
ExecStart=/usr/local/bin/openclaw gateway start
WatchdogSec=60
Restart=on-failure
RestartSec=5
StartLimitIntervalSec=0
```

`StartLimitIntervalSec=0` disables the restart rate limiter entirely (equivalent to
`ThrottleInterval: 5` for macOS launchd).

**macOS launchd ThrottleInterval**

Already documented by `unisone/openclaw-config`. Direct adoption:
```xml
<key>ThrottleInterval</key>
<integer>5</integer>
```

**Monit** ([mmonit.com/monit](https://mmonit.com/monit))

Process supervisor that watches PIDs, restarts on failure, and can monitor file
changes, port availability, and resource consumption. Widely used for self-healing
Linux daemons. No Docker or Kubernetes required.

```
check process openclaw with pidfile /var/run/openclaw.pid
  start program = "/usr/local/bin/openclaw gateway start"
  stop program = "/usr/local/bin/openclaw gateway stop"
  if failed port 18789 protocol http then restart
  if 3 restarts within 5 cycles then alert
```

**Fit:** Medium. Monit adds a new daemon to install. The systemd watchdog pattern is
lighter-weight and already in the Linux ecosystem. The macOS equivalent is launchd's
built-in restart behavior with `ThrottleInterval`.

#### Proposed Solution

**Tier 1 — Immediate (absorb from `unisone/openclaw-config`):**

1. Add `ThrottleInterval: 5` to `devops/mac/ai.openclaw.gateway.plist`
2. Add `RestartSec=5` + `StartLimitIntervalSec=0` to Linux systemd unit
3. Update `devops/mac/ai.openclaw.workspace-backup.plist` — change interval 4h→2h
4. Update `devops/linux/openclaw-workspace-backup.timer` — same
5. Adopt `healthcheck.sh` pattern from `unisone`: 5-minute cycle, immediate restart on
   gateway down (current repo uses 30-minute cycle)
6. Update `devops/mac/ai.openclaw.health-check.plist` to 5-minute interval

**Tier 2 — New watchdog infrastructure:**

7. **`devops/watchdog.md`** — New: desired-state spec for a PID watchdog. Covers both
   macOS (launchd with proper `ThrottleInterval`) and Linux (systemd `WatchdogSec`).
   References systemd watchdog pattern and monit as an alternative.

8. **`devops/linux/openclaw-gateway.service`** — New: systemd service unit with
   watchdog configuration:
   - `WatchdogSec=60`
   - `Restart=on-failure`
   - `RestartSec=5`
   - `StartLimitIntervalSec=0`

9. **Config rollback mechanism:**
   - Before any config change via health check or debugger agent, write:
     `~/.openclaw/config-backups/openclaw.json.{timestamp}`
   - Keep last 5 backups
   - Health check adds: "if gateway down after recent config backup exists → offer
     rollback to last-known-good"

10. **`devops/health-check.md`** — Add "immediate restart mode": if `openclaw health`
    fails, don't wait for next cycle — immediately attempt restart via
    `gateway-restart skill`. Change detection interval from 30 to 5 minutes.

---

## 4. Implementation Roadmap

### Phase 1 — Quick Wins (Weeks 1–2)
*Absorb community discoveries, fix critical bugs, improve base resilience*

| Task | Source | Files | Effort |
|------|--------|-------|--------|
| Add `ThrottleInterval: 5` to macOS plist | `unisone/openclaw-config` | `devops/mac/ai.openclaw.gateway.plist` | S |
| Add `RestartSec=5`+`StartLimitIntervalSec=0` to Linux unit | `unisone/openclaw-config` | `devops/linux/openclaw-gateway.service` (new) | S |
| Document `${VAR}` broken + `.env` fix | `unisone/openclaw-config` | `devops/machine-setup.md`, `devops/security-baseline.md` | S |
| Add API key leak warning + `.env`-only config | `unisone/openclaw-config` | `devops/machine-setup.md`, `templates/TOOLS.md` | S |
| Reduce health check to 5-minute interval | `unisone/openclaw-config` | `devops/mac/ai.openclaw.health-check.plist`, `devops/linux/openclaw-health-check.timer` | S |
| Increase backup to 2-hour interval | self | `devops/mac/ai.openclaw.workspace-backup.plist`, `devops/linux/openclaw-workspace-backup.timer` | S |
| Add tool policy defaults to `AGENTS.md` template | `digitalknk/openclaw-runbook` | `templates/AGENTS.md` | S |
| Add device pairing hygiene to security review | `digitalknk/openclaw-runbook` | `devops/machine-security-review.md` | S |
| Add `logging.redactSensitive` to config templates | `digitalknk/openclaw-runbook` | `templates/TOOLS.md` | S |
| Adopt session management scripts | `unisone/openclaw-config` | `scripts/session-management/` (new) | M |

### Phase 2 — Core Gaps (Weeks 3–8)
*Cost tracking, watchdog, RBAC allowlist, audit log foundation*

| Task | Open-Source Tool | Files | Effort |
|------|-----------------|-------|--------|
| Cost tracker UV script (gateway log parsing) | Custom (inspired by `digitalknk` `check-quotas.sh`) | `skills/cost-tracker/` | M |
| Cost sentinel workflow | Custom | `workflows/cost-sentinel/AGENT.md` | M |
| LiteLLM setup guide (for teams) | [LiteLLM](https://github.com/BerriAI/litellm) | `docs/LITELLM_SETUP.md` | M |
| PID watchdog service files (macOS + Linux) | systemd `WatchdogSec` / launchd | `devops/watchdog.md`, `devops/linux/openclaw-gateway.service` | M |
| Config rollback mechanism | Custom | `devops/health-check.md` update | S |
| Immediate restart in health check | Custom | `devops/health-check.md` | S |
| Allowlist-based auth (pre-RBAC) | Custom | `skills/rbac/` (v1), `devops/rbac-config.md` | M |
| Fleet agent (zero-SSH pilot) | Ansible pull-mode *pattern* | `devops/fleet-agent.md`, `skills/fleet-agent/` | L |
| Structured audit log spec | Custom | `devops/audit-log.md`, hooks in `devops/machine-setup.md` | M |
| Security setup script | Custom | `skills/security-setup/` | M |
| `security-baseline.md` desired-state | Custom | `devops/security-baseline.md` | S |

### Phase 3 — Enterprise (Weeks 9–16)
*Full RBAC with Casbin, SSO, teams, audit export*

| Task | Open-Source Tool | Files | Effort |
|------|-----------------|-------|--------|
| Full RBAC with Casbin | [pycasbin](https://github.com/casbin/pycasbin) | `skills/rbac/` (v2), `devops/rbac-config.md` | L |
| RBAC integration in AGENTS.md template | Casbin | `templates/AGENTS.md` | S |
| Multi-user memory isolation | Custom | `docs/MULTI_USER_SETUP.md`, `templates/TEAM.md` | M |
| User router skill | Custom | `skills/user-router/` | M |
| Audit export skill | Custom | `skills/audit-export/` | M |
| SSO with Authentik (guide) | [Authentik](https://github.com/goauthentik/authentik) | `docs/AUTHENTIK_SETUP.md` | M |
| SSO with Authelia (guide) | [Authelia](https://github.com/authelia/authelia) | `docs/AUTHELIA_SETUP.md` | S |
| Compliance guide | Custom | `docs/COMPLIANCE_GUIDE.md` | M |
| Langfuse setup guide (for enterprise observability) | [Langfuse](https://github.com/langfuse/langfuse) | `docs/LANGFUSE_SETUP.md` | M |

### Phase 4 — Advanced (Weeks 17+)
*NL fleet control, smart routing, swarm orchestration*

| Task | Open-Source Tool | Files | Effort |
|------|-----------------|-------|--------|
| Evaluate Ruflo swarm integration | Ruflo ([ruvnet/ruflo](https://github.com/ruvnet/ruflo)) | `docs/RUFLO_SETUP.md`, `workflows/fleet-commander/` | M |
| Fleet MCP server | [MCP protocol](https://modelcontextprotocol.io) | `skills/fleet-mcp-server/` | M |
| NL fleet commander workflow | `unisone` smart routing pattern | `workflows/fleet-commander/AGENT.md` | M |
| NL entry point in `/fleet` command | Custom | `.claude/commands/fleet.md` | S |
| Agent swarm orchestration (adopt `unisone` pattern) | `unisone/openclaw-config` | `workflows/agent-swarm/` | L |
| OPA integration guide (enterprise policy) | [OPA](https://github.com/open-policy-agent/opa) | `docs/OPA_SETUP.md` | M |

---

## 5. Architecture Decisions

### AD-1: Stand on Giants, Don't Rebuild Them

**Decision:** Integrate existing open-source tools rather than building equivalents from
scratch. Where integration is too heavy, borrow the *pattern* and implement with
openclaw-config's existing primitives.

**Decision table:**

| Gap | Tool to Integrate | How |
|-----|------------------|-----|
| Cost tracking (individuals) | Custom log parser | UV script, no external dependency |
| Cost tracking (teams) | LiteLLM proxy | Docker Compose guide + configuration doc |
| RBAC | pycasbin | `pip install casbin` in UV skill; policies in flat files |
| SSO | Authentik or Authelia | Docker Compose guide + OpenClaw config doc |
| NL fleet | MCP protocol | UV-based MCP server wrapping existing operations |
| Self-healing | systemd WatchdogSec / launchd `ThrottleInterval` | Platform-native, no new deps |
| Fleet pull-mode | Ansible pattern (not Ansible itself) | OpenClaw message channels as the transport |

### AD-2: Community Repos as Upstream Sources

**Decision:** Treat `unisone/openclaw-config` and `digitalknk/openclaw-runbook` as
upstream sources for patterns and findings. When they've solved something, adopt their
solution rather than duplicating effort.

**Concrete absorptions:**
- `unisone`: `ThrottleInterval: 5`, secret management, session watchdog scripts,
  agent swarm orchestration pattern
- `digitalknk`: Tool policy defaults, cost model config format, device pairing hygiene,
  `check-quotas.sh` pattern

**Rationale:** These repos reflect real production experience. Their bug fixes (#9627,
#11202, #4632) have been validated against live deployments. Ignoring them wastes the
community's collective learning.

### AD-3: No New Infrastructure for Individuals, Guided Paths for Teams

**Decision:** Every gap must have a "no new services" solution for individuals. Teams
can opt into additional infrastructure with documented setup guides.

| Gap | Individual path | Team path |
|-----|----------------|-----------|
| Cost tracking | UV log parser | LiteLLM proxy |
| Auth | Allowlist file | Casbin RBAC + Authentik SSO |
| Observability | File-based audit log | Langfuse |
| Fleet access | Message channel agent | MCP server |

### AD-4: Tailscale as the Trust Boundary

**Decision:** Tailscale remains the primary network security layer. All fleet
communication travels over Tailscale. The gateway binds to loopback only (per
`digitalknk/openclaw-runbook` recommendation).

**Rationale:** Tailscale provides network-layer encryption and authentication for free.
This means the zero-SSH fleet agent model (message channels over Tailscale) is
architecturally sound — the transport is already secured.

### AD-5: File-First, Policy-as-Markdown

**Decision:** RBAC configs, audit logs, cost data — all stored as flat files. Casbin
policy files are CSV (two lines per rule). All are diffable, committable, auditable
without tooling.

**Constraint from Casbin's design:** Casbin policy format (`policy.csv`) is already
file-native and designed for this pattern.

---

## 6. New Files and Modules

Complete file tree of additions and modifications:

```
openclaw-config/
│
├── devops/
│   ├── watchdog.md                          # NEW: PID watchdog spec (systemd + launchd)
│   ├── security-baseline.md                 # NEW: Non-negotiable security baseline
│   ├── audit-log.md                         # NEW: Structured audit log spec
│   ├── fleet-agent.md                       # NEW: Zero-SSH fleet agent spec
│   ├── rbac-config.md                       # NEW: RBAC desired-state spec (Casbin)
│   ├── health-check.md                      # MODIFY: 5-min interval, immediate restart,
│   │                                        #   cost check, config rollback awareness
│   ├── machine-security-review.md           # MODIFY: Add device hygiene, ThrottleInterval
│   │                                        #   check, redactSensitive check
│   ├── machine-setup.md                     # MODIFY: ThrottleInterval fix, .env-only
│   │                                        #   secrets, watchdog service, security
│   │                                        #   baseline prereqs
│   ├── machine-setup-linux.md               # MODIFY: Same as machine-setup.md additions
│   ├── notification-routing.md              # MODIFY: Add team broadcast lane
│   │
│   ├── mac/
│   │   ├── ai.openclaw.gateway.plist        # MODIFY: Add ThrottleInterval: 5
│   │   ├── ai.openclaw.health-check.plist   # MODIFY: Interval 1800s → 300s (5 min)
│   │   ├── ai.openclaw.watchdog.plist       # NEW: macOS watchdog companion
│   │   └── ai.openclaw.workspace-backup.plist  # MODIFY: Interval 14400s → 7200s (2h)
│   │
│   └── linux/
│       ├── openclaw-gateway.service         # NEW: systemd unit with WatchdogSec=60,
│       │                                   #   RestartSec=5, StartLimitIntervalSec=0
│       ├── openclaw-gateway.timer           # NEW (if needed for timer-based start)
│       ├── openclaw-health-check.timer      # MODIFY: OnUnitActiveSec=5min
│       ├── openclaw-watchdog.service        # NEW: Linux watchdog unit
│       └── openclaw-workspace-backup.timer  # MODIFY: OnUnitActiveSec=2h
│
├── skills/
│   ├── cost-tracker/                        # NEW: API cost tracking (log parser)
│   │   ├── SKILL.md
│   │   └── cost-tracker
│   │
│   ├── security-setup/                      # NEW: One-time security hardening script
│   │   ├── SKILL.md                         #   validates .env, chmod, ThrottleInterval,
│   │   └── security-setup                   #   gateway bind, device inventory
│   │
│   ├── rbac/                               # NEW: Casbin-based RBAC enforcement
│   │   ├── SKILL.md
│   │   ├── rbac                             # UV script (pip install casbin)
│   │   └── policy/
│   │       ├── model.conf                   # Casbin model definition
│   │       └── policy.csv.template          # Policy template
│   │
│   ├── audit-export/                        # NEW: Audit log export
│   │   ├── SKILL.md
│   │   └── audit-export
│   │
│   ├── fleet-agent/                         # NEW: Zero-SSH fleet command agent
│   │   ├── SKILL.md
│   │   └── fleet-agent
│   │
│   ├── fleet-mcp-server/                    # NEW: MCP server for fleet operations
│   │   ├── SKILL.md
│   │   └── fleet-mcp-server                 # MCP SDK-based UV script
│   │
│   ├── fleet-nl/                            # NEW: NL interface for fleet operations
│   │   ├── SKILL.md
│   │   └── fleet-nl
│   │
│   ├── user-router/                         # NEW: Per-sender context routing
│   │   ├── SKILL.md
│   │   └── user-router
│   │
│   └── openclaw/
│       └── SKILL.md                         # MODIFY: Add security-baseline check,
│                                            #   .env warning, ThrottleInterval check
│
├── workflows/
│   ├── cost-sentinel/                       # NEW: Cost monitoring + alerting workflow
│   │   └── AGENT.md
│   │
│   └── fleet-commander/                     # NEW: NL fleet management workflow
│       └── AGENT.md                         # Uses unisone smart-routing pattern
│
├── scripts/
│   ├── session-management/                  # NEW: Adopt from unisone/openclaw-config
│   │   ├── README.md
│   │   ├── session-watchdog.sh
│   │   ├── session-metrics.sh
│   │   ├── session-ops-weekly-report.sh
│   │   ├── session-cleanup.sh
│   │   └── session-store-hygiene.sh
│   │
│   └── cost-tracker/                        # NEW: Shell-based quota checker
│       └── check-quotas.sh                  # Inspired by digitalknk pattern
│
├── templates/
│   ├── TEAM.md                              # NEW: Team profile template
│   ├── AGENTS.md                            # MODIFY: Add RBAC section, tool policy
│   │                                        #   defaults (deny exec/cron), multi-user
│   │                                        #   section, prompt injection defenses
│   ├── TOOLS.md                             # MODIFY: Add cost config section (model
│   │                                        #   pricing), device inventory section
│   └── USERS/                              # NEW: Per-user profile directory
│       └── USER-template.md
│
├── docs/
│   ├── MULTI_USER_SETUP.md                  # NEW: Team deployment guide
│   ├── COMPLIANCE_GUIDE.md                  # NEW: Enterprise compliance guidance
│   ├── LITELLM_SETUP.md                     # NEW: LiteLLM proxy integration guide
│   ├── LANGFUSE_SETUP.md                    # NEW: Langfuse observability guide
│   ├── AUTHENTIK_SETUP.md                   # NEW: Authentik SSO integration guide
│   ├── AUTHELIA_SETUP.md                    # NEW: Authelia 2FA guide
│   ├── MCP_FLEET_SETUP.md                   # NEW: MCP fleet server guide
│   ├── OPA_SETUP.md                         # NEW: OPA enterprise policy guide (Phase 4)
│   └── FLEET_BOOT_PATTERNS.md               # MODIFY: Add fleet-agent pull pattern
│
└── .claude/
    └── commands/
        └── fleet.md                         # MODIFY: Add --no-ssh mode, NL entry point
```

---

## 7. Open-Source Tool Reference Card

Quick reference for all recommended integrations:

| Gap | Tool | License | Repo | Complexity |
|-----|------|---------|------|-----------|
| Cost tracking (teams) | LiteLLM | MIT | [github.com/BerriAI/litellm](https://github.com/BerriAI/litellm) | Medium (Docker) |
| Observability (enterprise) | Langfuse | MIT | [github.com/langfuse/langfuse](https://github.com/langfuse/langfuse) | High (ClickHouse) |
| RBAC | Casbin (pycasbin) | Apache 2.0 | [github.com/casbin/pycasbin](https://github.com/casbin/pycasbin) | Low (embedded) |
| Policy engine (enterprise) | OPA | Apache 2.0 | [github.com/open-policy-agent/opa](https://github.com/open-policy-agent/opa) | High (service) |
| SSO (teams) | Authentik | MIT | [github.com/goauthentik/authentik](https://github.com/goauthentik/authentik) | Medium (Docker) |
| SSO (individuals) | Authelia | Apache 2.0 | [github.com/authelia/authelia](https://github.com/authelia/authelia) | Low (binary) |
| Swarm orchestration | Ruflo | MIT | [github.com/ruvnet/ruflo](https://github.com/ruvnet/ruflo) | Medium (Docker/npx) |
| NL fleet control | MCP protocol | MIT | [modelcontextprotocol.io](https://modelcontextprotocol.io) | Low (UV script) |
| Self-healing (Linux) | systemd watchdog | GPL | Built-in Linux | None (native) |
| Self-healing (macOS) | launchd ThrottleInterval | proprietary | Built-in macOS | None (native) |
| Fleet network layer | Netbird | BSD | [github.com/netbirdio/netbird](https://github.com/netbirdio/netbird) | Low |
| Zero-trust access alt. | Octelium | Apache 2.0 | [github.com/octelium/octelium](https://github.com/octelium/octelium) | High |
| Session management | `unisone/openclaw-config` | MIT | [github.com/unisone/openclaw-config](https://github.com/unisone/openclaw-config) | None (copy scripts) |
| Security patterns | `digitalknk/openclaw-runbook` | MIT | [github.com/digitalknk/openclaw-runbook](https://github.com/digitalknk/openclaw-runbook) | None (read + adopt) |

---

## 8. Success Metrics

For each phase, criteria for "done":

### Phase 1 Success (Weeks 1–2)
- [ ] `ThrottleInterval: 5` in all gateway service files
- [ ] No secrets in `openclaw.json` template (`.env`-only)
- [ ] Health check runs every 5 minutes (down from 30)
- [ ] Backup runs every 2 hours (down from 4)
- [ ] Tool policy defaults (`deny exec/cron`) in `AGENTS.md` template
- [ ] Device hygiene process in `machine-security-review.md`
- [ ] Session management scripts adopted from `unisone/openclaw-config`

### Phase 2 Success (Weeks 3–8)
- [ ] Cost data available in `~/.openclaw/costs/` after first full day
- [ ] Cost sentinel alerts on budget overrun
- [ ] Gateway crash → restart in < 60 seconds (watchdog active)
- [ ] Backup frequency: 2 hours, integrity-verified
- [ ] Unauthorized user rejected via allowlist
- [ ] Structured audit log entries for all skill executions
- [ ] Fleet operations possible without SSH on at least one test node

### Phase 3 Success (Weeks 9–16)
- [ ] Casbin RBAC: Observer cannot run skills, Operator cannot change config
- [ ] Multi-user memory isolation working (Alice's memory ≠ Bob's)
- [ ] SSO guide validated against a real Authentik deployment
- [ ] Audit logs exportable via `audit-export` skill
- [ ] Compliance guide covers GDPR data retention requirements

### Phase 4 Success (Weeks 17+)
- [ ] "Check if all agents are healthy" → fleet-commander responds correctly
- [ ] Fleet MCP server callable from any Claude session
- [ ] Agent swarm orchestration (smart routing + learning loop) deployed
- [ ] `/fleet` command usable without knowing CLI syntax

---

## 9. What We're NOT Building

To avoid scope creep and maintain the "no lock-in" philosophy:

- **No real-time dashboard** — File-based cost summaries and digest reports are enough
  for individuals. Teams get LiteLLM (existing project).
- **No custom IdP** — Authentik and Authelia exist and are excellent. We document
  integration, not reimplement.
- **No Kubernetes operator** — openclaw-config targets self-hosted machines, not K8s
  clusters. The systemd/launchd watchdog pattern is sufficient.
- **No custom RBAC engine** — pycasbin is mature, embeddable, and file-native.
  Don't build what Casbin already is.
- **No vendor-specific cloud integrations** — This repo stays cloud-agnostic. Guides
  can reference AWS/GCP/Azure but the core remains portable.

---

*This plan is a living document. Update as implementation progresses and new competitive
intelligence emerges. Last updated: March 2026.*