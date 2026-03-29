# Changelog

All notable changes to openclaw-config (Enhanced Fork) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> This is a fork of [TechNickAI/openclaw-config](https://github.com/TechNickAI/openclaw-config).
> Upstream changes are merged periodically. Fork-specific changes are documented here.

---

## [Unreleased]

---

## [2.0.0-alpha] - 2026-03-28 (Phase 2 Complete)

### Critical Bug Fixes

- **C1: watchdog.sh undefined variable bug** — Fixed `$THRESHOLD` reference on line 47
  to use the correct variable `$FAIL_THRESHOLD`. This was a silent bug that always
  evaluated the threshold check against an empty string.

- **C2: check-auth fail-closed on read errors** — Changed the exception handler in
  `skills/rbac/check-auth` to DENY access when the authorized-users file EXISTS but
  cannot be read. Previously failed open (PERMIT) on any exception. Now:
  - File missing → PERMIT all (backward-compatible opt-in security)
  - File exists but unreadable → DENY all (fail-closed — security error)
  - Empty file → DENY all
  - Identity in file → PERMIT
  - Identity not in file → DENY

- **C3: Cost tracker data source verified** — Verified cost-tracker against real session
  JSONL logs. Schema confirmed: `usage.{input, output, cacheRead, cacheWrite, total}` at
  the top-level message object alongside `provider` and `model` fields. Added verified
  schema as inline documentation comment in `skills/cost-tracker/cost-tracker`.

### Major Additions

- **docs/LITELLM_SETUP.md** — Full Phase 2 guide for LiteLLM proxy setup: What is
  LiteLLM, Docker Compose deployment, per-agent virtual keys, pointing OpenClaw at the
  proxy, budget caps, dashboard access.

- **skills/security-setup/** — UV script that audits the OpenClaw deployment against
  `devops/security-baseline.md`. Checks: secrets in .env, dir permissions, gateway bind,
  service hardening, device inventory. Reports pass/fail with remediation commands.

- **skills/fleet-agent/** — Zero-SSH fleet command agent with HMAC-SHA256 authentication.
  Implements inbox/outbox pattern from `devops/fleet-agent-security.md`. Operations
  allowlist-only. Nonce-based replay protection. Full audit logging.

- **RBAC → gateway-restart integration (M2)** — Added `check_authorization()` function to
  `skills/gateway-restart/gateway-restart`. Reads caller identity from
  `OPENCLAW_CALLER_IDENTITY` env var, shells out to `check-auth`, aborts with error if
  DENY. Backward compatible: skip check if no identity configured.

- **Audit log producers (M3)** — `skills/rbac/check-auth` now writes ALL auth events
  (PERMIT and DENY) to `~/.openclaw/audit/YYYY-MM-DD.jsonl` in the standard format from
  `devops/audit-log.md`. Added `scripts/audit-write.sh` bash helper that any script can
  `source` to write audit entries.

- **tests/phase2-validation.sh** — Integration test suite for all Phase 2 deliverables.
  61 tests covering: critical fixes, stub files, RBAC integration, audit producers, script
  executability. Includes graceful skip when `uv` is not installed.

- **tests/fixtures/sample-session.jsonl** — Test fixture with real-format session JSONL
  for cost-tracker testing.

- **tests/fixtures/sample-audit.jsonl** — Test fixture for audit-export testing.

### Stub Files Created (Phase 3/4 Tracking)

All promised-but-missing modules from the gap plan now have stub files with phase tracking
and full documentation of what will be implemented:

- `skills/security-setup/SKILL.md` (Phase 2, now implemented)
- `skills/fleet-agent/SKILL.md` (Phase 2, now implemented)
- `devops/fleet-agent.md` — Fleet agent desired-state spec with allowlist and HMAC details
- `devops/rbac-config.md` — RBAC configuration spec (Phase 2 allowlist → Phase 3 Casbin)
- `scripts/session-management/session-ops-weekly-report.sh` (stub)
- `scripts/session-management/session-store-hygiene.sh` (stub)
- `scripts/cost-tracker/check-quotas.sh` (stub)
- `skills/user-router/SKILL.md` (Phase 3 stub)
- `templates/TEAM.md` — Team configuration template
- `templates/USERS/USER-template.md` — Per-user profile template
- `docs/LANGFUSE_SETUP.md` (Phase 3 stub)
- `docs/AUTHENTIK_SETUP.md` (Phase 3 stub)
- `docs/AUTHELIA_SETUP.md` (Phase 3 stub)
- `docs/MULTI_USER_SETUP.md` (Phase 3 stub)
- `docs/COMPLIANCE_GUIDE.md` (Phase 3 stub)
- `docs/MCP_FLEET_SETUP.md` (Phase 4 stub)
- `docs/RUFLO_SETUP.md` (Phase 4 stub)
- `docs/OPA_SETUP.md` (Phase 4 stub)
- `skills/fleet-mcp-server/SKILL.md` (Phase 4 stub)
- `workflows/fleet-commander/AGENT.md` (Phase 4 stub)

### Major Fixes

- **M4: Session management CLI compatibility** — Verified all session management scripts
  against OpenClaw CLI v2026.3.2. Added CLI compatibility table to README with verified
  commands: `openclaw sessions list --json`, `openclaw gateway call`, `openclaw cron list`.

- **M5: gateway-restart configurable LOG_DIR** — Made log directory configurable via
  `OPENCLAW_LOG_DIR` env var with `/tmp/openclaw` as fallback default.

### Minor Fixes

- **m2: Version consistency** — Updated `VERSION` to `2.0.0-alpha`

- **m3: watchdog-notify.sh ExecStartPost fix** — Added
  `devops/linux/openclaw-watchdog-notify.service` as a separate systemd unit for the
  watchdog-notify infinite loop. Updated `openclaw-gateway.service` with explanation
  comment. Running an infinite loop via ExecStartPost blocks systemd from considering
  the service started.

- **m4: config-rollback.sh date portability** — Added cross-platform date handling using
  `date --version` to detect GNU vs BSD date, then using the appropriate flag
  (`-d @epoch` vs `-r epoch`).

- **m5: Fleet command path fix** — Updated `GAP_CLOSING_PLAN.md` to reference the actual
  file `.claude/commands/fleet.md` instead of the non-existent `devops/fleet.md`.

---

## [2.0.0-alpha] - 2026-03-28

This is the first release of the Enhanced Fork, based on upstream v0.17.0. All changes
below are relative to TechNickAI/openclaw-config v0.17.0.

### Added

**Phase 4 Integration — Swarm Orchestration**
- Added Ruflo ([ruvnet/ruflo](https://github.com/ruvnet/ruflo)) as recommended swarm
  orchestration integration for Phase 4: NL fleet control + agent swarm coordination
- Updated `GAP_CLOSING_PLAN.md` Gap 4 with Ruflo as Option C alongside MCP and
  `unisone` smart-routing pattern; Proposed Solution updated to evaluate Ruflo before
  building custom fleet-commander
- Added `GAP_ANALYSIS_SUMMARY.md` — concise gap reference with all options per gap,
  including Ruflo under Gap 4
- Updated Phase 4 roadmap: "Evaluate Ruflo swarm integration" as first task
- Updated Section 7 Open-Source Tool Reference Card with Ruflo (MIT, Medium complexity)

**Fork Identity**
- `README.md` — Rewritten with fork identity, comparison table, security quick-start,
  credits to upstream and community repos (unisone, digitalknk)
- `CONTRIBUTING.md` — Branch strategy, PR process, code style guide
- `MIGRATION.md` — How to upgrade from upstream openclaw-config
- `ATLAS4_REVIEW.md` — Architectural review and competitive analysis
- `GAP_CLOSING_PLAN.md` — 4-phase roadmap for all enhancements

**Security**
- `devops/security-baseline.md` — Non-negotiable security requirements: gateway bind
  loopback, .env chmod 600, no secrets in config, device pairing hygiene, tool policy
  defaults, `logging.redactSensitive` recommendation

**Linux Infrastructure**
- `devops/linux/openclaw-gateway.service` — New systemd unit for the OpenClaw gateway
  with `WatchdogSec=60`, `Restart=on-failure`, `RestartSec=5`,
  `StartLimitIntervalSec=0` (fixes exponential backoff — issue #4632)

**Session Management Scripts**
- `scripts/session-management/README.md` — Overview of all session management scripts
- `scripts/session-management/session-watchdog.sh` — Autonomous stale session cleanup
- `scripts/session-management/session-metrics.sh` — Session count, age, memory metrics
- `scripts/session-management/session-cleanup.sh` — Force cleanup for incident response

**Tests**
- `tests/phase1-validation.sh` — Automated validation of all Phase 1 changes

### Changed

**Critical Bug Fixes**

- `devops/mac/ai.openclaw.health-check.plist` — Reduced `StartInterval` from 1800s
  (30 min) to 300s (5 min) for faster crash detection (based on
  `unisone/openclaw-config` production hardening)
- `devops/mac/ai.openclaw.workspace-backup.plist` — Reduced `StartInterval` from
  14400s (4 hours) to 7200s (2 hours); added `ThrottleInterval: 5` for crash recovery
  (issue #4632)
- `devops/linux/openclaw-health-check.timer` — Changed `OnUnitActiveSec` from 30min
  to 5min
- `devops/linux/openclaw-workspace-backup.timer` — Changed `OnUnitActiveSec` from
  4h to 2h

**Templates**

- `templates/AGENTS.md` — Added RBAC section placeholder, tool policy defaults
  (deny exec/cron by default per `digitalknk/openclaw-runbook`), prompt injection
  defense notes
- `templates/TOOLS.md` — Added .env-only secrets documentation, device inventory
  section, `logging.redactSensitive` configuration example

### Security Fixes

- Documented `${VAR}` syntax issue (#9627) — placeholders that resolve to plaintext
  on `doctor` writes; enforce `.env`-only approach
- Documented API key exposure issue (#11202) — all provider keys sent to LLM on every
  turn; enforce `.env`-only pattern in all templates
- Fixed exponential crash backoff (#4632) — `ThrottleInterval: 5` in launchd,
  `RestartSec=5`+`StartLimitIntervalSec=0` in systemd

### Credits

Fixes in this release incorporate production hardening research from:
- [`unisone/openclaw-config`](https://github.com/unisone/openclaw-config) — ThrottleInterval fix, session management patterns, health check interval
- [`digitalknk/openclaw-runbook`](https://github.com/digitalknk/openclaw-runbook) — Security patterns, tool policy defaults, device hygiene, cost model awareness

---

## Upstream History (TechNickAI/openclaw-config)

The following entries document upstream changes merged into this fork.

## [0.6.0] - 2026-02-02

### Added

- **Workflows** — Autonomous agents that run on a schedule with state and learning
  - `email-steward` — Manages inbox automatically (archives, deletes, alerts on urgent)
  - Workflows have: AGENT.md (algorithm), rules.md (user prefs), agent_notes.md
    (learning)
  - AGENT.md updates on sync (the algorithm improves)
  - User files (rules.md, agent_notes.md, logs/) are never overwritten

## [0.2.0] - 2026-02-01

### Added

- **Semantic memory search** with vector embeddings
  - LM Studio integration (local, free, recommended)
  - OpenAI API option for those who prefer cloud
  - EmbeddingGemma 300M model for 768-dim vectors
  - Verification test to ensure search works before completing setup
- **Skill versioning** — Each skill now has a version in frontmatter
- **Nightly auto-update** via heartbeat system
- Better install instructions (prompt-style, guides OpenClaw step by step)

### Changed

- **Consolidated setup into openclaw skill** — SETUP.md and SYNC.md absorbed into
  skills/openclaw/SKILL.md
- README Quick Start now has thorough copy-paste instructions
- openclaw skill now handles: setup, status, update, update --force
- VERSION bumped to 0.2.0

### Removed

- SETUP.md (now in openclaw skill)
- SYNC.md (now in openclaw skill)

## [0.1.0] - 2026-02-01

### Added

- Initial release
- Three-tier memory architecture (MEMORY.md, daily logs, deep knowledge)
- Task management system with GitHub-style checkboxes
- Decision-making framework (Bezos doors, certainty thresholds)
- Group chat behavior guidelines
- Heartbeat system for proactive checks
- **Templates:** AGENTS.md, SOUL.md, USER.md, TOOLS.md, HEARTBEAT.md, IDENTITY.md
- **Skills:** limitless, fireflies, quo, openclaw, and more
- Memory directory structure (people/, projects/, topics/, decisions/)

---

[Unreleased]: https://github.com/koshaji/openclaw-config/compare/v2.0.0-alpha...HEAD
[2.0.0-alpha]: https://github.com/koshaji/openclaw-config/compare/v0.17.0...v2.0.0-alpha
