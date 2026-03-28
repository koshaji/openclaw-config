<p align="center">
  <img src="https://img.shields.io/badge/OpenClaw-Config%20Enhanced%20Fork-D97757?style=for-the-badge&labelColor=1a1a2e" alt="OpenClaw Config Enhanced Fork">
  <br><br>
  <a href="https://github.com/koshaji/openclaw-config/releases"><img src="https://img.shields.io/badge/version-2.0.0--alpha-D97757?style=flat-square" alt="Version"></a>
  <img src="https://img.shields.io/badge/upstream-v0.17.0-blue?style=flat-square" alt="Based on upstream v0.17.0">
  <img src="https://img.shields.io/badge/python-3.11+-3776ab?style=flat-square&logo=python&logoColor=white" alt="Python 3.11+">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/security-hardened-brightgreen?style=flat-square" alt="Security Hardened">
  <a href="https://github.com/koshaji/openclaw-config/pulls"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square" alt="PRs Welcome"></a>
</p>

<p align="center">
  <strong>openclaw-config (Enhanced Fork)</strong><br>
  Security-hardened, cost-aware, fleet-ready OpenClaw configuration.<br>
  Built on <a href="https://github.com/TechNickAI/openclaw-config">TechNickAI/openclaw-config</a> with production fixes and enterprise-grade enhancements.
</p>

---

# openclaw-config (Enhanced Fork)

This is an enhanced fork of [TechNickAI/openclaw-config](https://github.com/TechNickAI/openclaw-config)
— the shared configuration layer for [OpenClaw](https://docs.anthropic.com/en/docs/claude-code)
personal AI assistants.

The upstream project is excellent. This fork adds **security hardening**, **cost tracking**,
**RBAC foundations**, **fleet agent support**, and **self-healing improvements** — all
documented in [GAP_CLOSING_PLAN.md](GAP_CLOSING_PLAN.md) and reviewed in
[ATLAS4_REVIEW.md](ATLAS4_REVIEW.md).

## What This Fork Adds

### vs. Upstream (TechNickAI/openclaw-config v0.17.0)

| Capability | Upstream | This Fork |
|------------|----------|-----------|
| **ThrottleInterval fix** (issue #4632 — exponential backoff on crash) | ❌ Missing | ✅ Fixed in all service files |
| **Secret management** (issues #9627, #11202 — API key leaks) | ⚠️ Templates may expose keys | ✅ .env-only, documented |
| **Health check interval** | 30 min | ✅ 5 min |
| **Backup interval** | 4 hours | ✅ 2 hours |
| **Linux gateway service** | ❌ Not included | ✅ systemd unit with WatchdogSec |
| **Security baseline spec** | ❌ Not included | ✅ devops/security-baseline.md |
| **Tool policy defaults** | ❌ Not documented | ✅ deny exec/cron by default |
| **Session management scripts** | ❌ Not included | ✅ watchdog, metrics, cleanup |
| **RBAC placeholder** | ❌ Not included | ✅ Foundation in AGENTS.md |
| **Phase 1 validation tests** | ❌ Not included | ✅ tests/phase1-validation.sh |

### Planned Additions (See GAP_CLOSING_PLAN.md)

- **Phase 2:** Cost tracking (gateway log parser), PID watchdog, allowlist-based auth
- **Phase 3:** Full RBAC with Casbin, multi-user memory isolation, audit log export
- **Phase 4:** NL fleet control via MCP, agent swarm orchestration

## Quick Start

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) running
on your machine.

**Install from this fork:**

```
Set up openclaw-config from https://github.com/koshaji/openclaw-config
```

**Or install upstream and migrate:**

```
Set up openclaw-config from https://github.com/TechNickAI/openclaw-config
```

Then follow [MIGRATION.md](MIGRATION.md) to apply this fork's improvements.

**Update later:**

```
Update my openclaw config
```

## Critical Security Fixes (Apply Immediately)

If you're running the upstream config, apply these fixes from production hardening
research (community repos `unisone/openclaw-config` and `digitalknk/openclaw-runbook`):

### 1. ThrottleInterval (Crash Recovery — Issue #4632)

Without this, repeated gateway crashes trigger exponential backoff, causing up to
5-minute outages.

**macOS** — add to your `ai.openclaw.gateway.plist`:
```xml
<key>ThrottleInterval</key>
<integer>5</integer>
```

**Linux** — add to your `openclaw-gateway.service`:
```ini
RestartSec=5
StartLimitIntervalSec=0
```

### 2. .env-Only Secrets (Issues #9627, #11202)

Never put API keys in `openclaw.json`. All secrets belong in `~/.openclaw/.env`.
See [devops/security-baseline.md](devops/security-baseline.md) for full requirements.

### 3. Health Check Interval

Change health check from 30 min → 5 min for faster crash detection. Service files in
this fork are already updated.

## Repository Structure

```
openclaw-config/
├── templates/          # Identity & operating instructions (copy to your workspace)
├── skills/             # Standalone UV scripts — no install needed
├── devops/
│   ├── mac/            # macOS launchd plist files (FIXED ThrottleInterval, intervals)
│   ├── linux/          # Linux systemd units (NEW: gateway.service with WatchdogSec)
│   ├── security-baseline.md  # NEW: Non-negotiable security requirements
│   └── ...             # Health check, machine setup, notification routing
├── scripts/
│   └── session-management/   # NEW: Watchdog, metrics, cleanup scripts
├── tests/
│   └── phase1-validation.sh  # NEW: Validate Phase 1 changes
├── docs/               # Deep-dive guides
├── GAP_CLOSING_PLAN.md # Phased roadmap for all enhancements
└── ATLAS4_REVIEW.md    # Architectural review and analysis
```

## Documentation

| Document | Purpose |
|----------|---------|
| [GAP_CLOSING_PLAN.md](GAP_CLOSING_PLAN.md) | Full roadmap: gaps vs. competitors, open-source integrations, 4-phase plan |
| [ATLAS4_REVIEW.md](ATLAS4_REVIEW.md) | Architectural review and recommendations |
| [devops/security-baseline.md](devops/security-baseline.md) | Non-negotiable security requirements |
| [MIGRATION.md](MIGRATION.md) | Upgrading from upstream openclaw-config |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |

## Skills

Inherits all upstream skills. See upstream README for full skill documentation.

## Credits

- **Upstream:** [TechNickAI/openclaw-config](https://github.com/TechNickAI/openclaw-config) — the foundation
- **Production hardening:** [unisone/openclaw-config](https://github.com/unisone/openclaw-config) — ThrottleInterval fix, session management, swarm orchestration
- **Operational wisdom:** [digitalknk/openclaw-runbook](https://github.com/digitalknk/openclaw-runbook) — cost controls, security patterns, device hygiene
- **Analysis:** Atlas4 (automated competitive analysis, March 2026)

## Development

```bash
# Run Phase 1 validation
bash tests/phase1-validation.sh

# Run upstream tests
uv run --with pytest pytest tests/ -v
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for branch strategy, PR process, and code style.

## License

MIT — same as upstream.

---

<p align="center">
  Enhanced fork maintained by <a href="https://github.com/koshaji">koshaji</a><br>
  Built on <a href="https://github.com/TechNickAI">TechNickAI</a>'s foundation<br>
  <sub>Your AI deserves to remember you — and stay secure doing it.</sub>
</p>
