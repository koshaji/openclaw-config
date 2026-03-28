# Atlas4 Review — Gap-Closing Plan Enhancement

> Reviewed: March 28, 2026
> Reviewer: Atlas4 (Opus 4.6)
> Original author: Forge4 (Sonnet 4.6)

## Review Verdict: GOOD with ENHANCEMENTS NEEDED

The plan is structurally sound. Tool selection is smart (pycasbin, LiteLLM, Authentik — all correct choices). The two-tier approach (individual/team) is the right architecture. Community repo absorption is well-researched.

However, the plan needs the following enhancements before execution.

---

## Enhancement 1: Testing Strategy

Every phase needs validation criteria that are **automatable**, not just checkboxes.

### Phase 1 Smoke Tests
```bash
# After ThrottleInterval fix:
# Simulate crash → verify restart within 10s (not 5min)

# After .env migration:
# grep for any API key patterns in openclaw.json → must return empty
# Verify .env exists with chmod 600

# After health check interval change:
# Check plist/timer interval = 300 (not 1800)
```

### Phase 2 Integration Tests
```bash
# Cost tracker: feed sample gateway log → verify JSON output matches schema
# Watchdog: kill gateway PID → verify restart within WatchdogSec window
# Allowlist: send message from unauthorized user → verify rejection
# Audit log: execute skill → verify JSONL entry written
```

Add `tests/` directory with validation scripts for each phase.

---

## Enhancement 2: Migration Guide

Existing openclaw-config users need a clear upgrade path:

```markdown
# MIGRATION.md

## From upstream TechNickAI/openclaw-config

1. Back up your current ~/.openclaw/workspace/
2. Review CHANGELOG.md for breaking changes
3. Run `skills/security-setup/` to apply security baseline
4. Update your plist/systemd files (ThrottleInterval, intervals)
5. Verify with `openclaw doctor --fix`

## From unisone/moltbot-config
(separate migration notes — their session management scripts may conflict)
```

---

## Enhancement 3: Fleet Agent Threat Model

The zero-SSH fleet agent MUST have a security boundary:

**Allowed operations (allowlist, not denylist):**
- `health_report` — read-only system status
- `gateway_restart` — graceful restart only
- `config_pull` — pull new config from git (read-only)
- `update_gateway` — pull latest openclaw binary
- `log_export` — ship logs to master

**Blocked by default:**
- Shell execution
- File writes outside ~/.openclaw/
- Network configuration changes
- User/credential management

This needs its own `devops/fleet-agent-security.md`.

---

## Enhancement 4: Verify Assumptions

Before building the cost tracker, verify:
- [ ] Do OpenClaw gateway logs actually contain token usage data?
- [ ] What log format? Where are logs stored?
- [ ] Can we parse `usage.input_tokens` / `usage.output_tokens` from them?

If logs don't have this, the cost tracker needs a different approach (API response interceptor or LiteLLM proxy becomes the only option even for individuals).

---

## Enhancement 5: Fork Identity

The fork needs:

### README.md (new)
- What this fork adds vs upstream
- Quick comparison table
- Installation (clone this instead of upstream)
- Link to GAP_CLOSING_PLAN.md

### CONTRIBUTING.md (new)
- How to contribute
- Branch strategy (main = stable, develop = active)
- PR template
- Code of conduct reference

### CHANGELOG.md (new)
- Track every phase completion
- Semantic versioning starting at v2.0.0 (fork identity)

---

## Enhancement 6: Dependency Graph

Some tasks MUST be sequenced:

```
Phase 1 (Foundation):
  ThrottleInterval fix ──┐
  .env-only secrets ─────┤
  Health check 5min ─────┼──→ Phase 2 (Core)
  Tool policy defaults ──┤     ├── Cost tracker (needs log format verified first)
  Session mgmt scripts ──┘     ├── Watchdog (needs ThrottleInterval first)
                               ├── Allowlist auth (independent)
                               ├── Audit log (independent)
                               └── Fleet agent (needs security spec first)
                                     │
                                     ▼
                               Phase 3 (Enterprise)
                                 ├── Casbin RBAC (needs allowlist working first)
                                 ├── SSO (needs RBAC working first)
                                 └── Multi-user (needs user-router + RBAC)
                                       │
                                       ▼
                                 Phase 4 (Advanced)
                                   ├── MCP server (needs fleet agent working)
                                   └── NL commander (needs MCP server)
```

---

## Enhancement 7: Alert Routing

Cost sentinel, security alerts, fleet alerts — where do they go?

Define in `devops/notification-routing.md`:
- **Urgent** (security breach, key leak): Telegram DM to admin + sound
- **Warning** (budget 80%, health degraded): Telegram DM, no sound
- **Info** (daily cost report, weekly digest): Telegram, silent
- **Debug** (audit entries, session metrics): Log files only

---

## Enhancement 8: Realistic Timelines

Phase 1 adjusted:
- **Week 1**: ThrottleInterval, .env secrets, health check interval, backup interval (4 tasks, all config changes)
- **Week 2**: Tool policies, device hygiene, redactSensitive, session scripts (4 tasks, documentation + script adoption)
- **Week 3**: Security baseline doc, testing, README/CONTRIBUTING (polish + validate)

Phase 2 adjusted: Weeks 4-10 (was 3-8, add buffer for assumption verification)

---

## Execution Order

1. ✅ Fork created (koshaji/openclaw-config)
2. 🔜 Create README.md, CONTRIBUTING.md, CHANGELOG.md (fork identity)
3. 🔜 Phase 1 Week 1: Config fixes (ThrottleInterval, .env, intervals)
4. 🔜 Phase 1 Week 2: Documentation + script adoption
5. 🔜 Phase 1 Week 3: Testing + polish
6. 🔜 Verify cost tracker assumptions before Phase 2
7. 🔜 Phase 2: Execute per dependency graph

---

*Plan enhanced. Ready for execution.*
