# Architecture Review — openclaw-config (Enhanced Fork)

> Reviewer: Forge4 (acting as Senior Architect)
> Date: March 28, 2026
> Scope: Full repository audit — every file read and assessed

## Executive Summary

This fork is a **well-conceived but half-built house**. The planning documents (GAP_CLOSING_PLAN.md, ATLAS4_REVIEW.md) are genuinely excellent — they reflect deep competitive analysis, smart open-source tool selection, and a sound layered architecture. Phase 1 (config fixes, hardened templates, session management scripts) is **solidly implemented** and delivers real value over upstream. Phase 2 is **partially implemented**: cost-tracker, audit-export, check-auth, and gateway-restart are working UV scripts with good code quality, but the gap plan promises far more than exists.

The core risk is **credibility**. The README claims this fork adds RBAC, fleet agent support, and cost tracking — and technically it does, but what exists is Phase 2 scaffolding, not production systems. The RBAC is a flat-file allowlist with no integration points. The cost tracker parses session logs but has an **unverified assumption** about whether those logs actually contain token usage data in the expected format. The fleet agent security spec is a detailed threat model document, not running code.

**Recommendation:** Fix the critical and major issues below (estimated 2-3 days of work), then proceed to Phase 3. The foundation is sound; the gaps are execution gaps, not design gaps.

## Scorecard

| Area | Score (1-5) | Notes |
|------|-------------|-------|
| Architecture Coherence | 4 | Strong design, good layering. Dependency chain is mostly correct. |
| Code Quality | 3.5 | UV scripts are well-structured. One confirmed bug in watchdog.sh. RBAC fails open on file read error. |
| Completeness | 2.5 | Phase 1: ~95% done. Phase 2: ~40% done. Many promised files don't exist. |
| Security Posture | 3 | Good baseline. Allowlist fails open. No integration between RBAC and anything else. Audit logs are append-only but not tamper-resistant. |
| Operational Readiness | 3 | Phase 1 changes are deployable. Phase 2 scripts need testing against real data. |
| Documentation Quality | 4 | Genuinely excellent. GAP_CLOSING_PLAN.md is one of the better architecture docs I've reviewed. |
| What's Missing | 2.5 | Large number of promised-but-absent files. No integration tests. |
| Competitive Assessment | 3 | Meaningfully better than upstream. Still aspirational vs commercial competitors. |

## Detailed Findings

### Critical Issues (must fix before any deployment)

#### C1: Bug in `scripts/watchdog.sh` — undefined variable `$THRESHOLD`

**File:** `scripts/watchdog.sh`, line 47
**Issue:** The log message references `$THRESHOLD` but the variable is named `FAIL_THRESHOLD`. With `set -euo pipefail`, this will cause the script to exit on the first health check failure with an "unbound variable" error, meaning the watchdog **never actually restarts the gateway**.

```bash
# Line 47 (broken):
log "Health check FAILED (consecutive failures: $new_fails / $THRESHOLD)"
# Should be:
log "Health check FAILED (consecutive failures: $new_fails / $FAIL_THRESHOLD)"
```

**Impact:** The macOS watchdog is non-functional. This is the self-healing component.

#### C2: RBAC `check-auth` fails open on file read errors

**File:** `skills/rbac/check-auth`, line 81
**Issue:** If the authorized-users file exists but can't be read (permissions error, disk issue, race condition), the script logs a warning and returns `True` (PERMIT). This means a corrupted or permission-changed allowlist **silently disables all access control**.

```python
# Current behavior:
except Exception as e:
    print(f"WARNING: could not read authorized-users file: {e}", file=sys.stderr)
    # Fail open (backward compatible) — could change to fail closed in Phase 3
    return True
```

**Fix:** Fail closed. If the file exists but can't be read, that's a security-relevant error. Return `False` and log the denial.

#### C3: Cost tracker's data source assumption is unverified

**File:** `skills/cost-tracker/cost-tracker` — scans `~/.openclaw/agents/*/sessions/*.jsonl`
**Issue:** The ATLAS4_REVIEW.md explicitly flagged this as Enhancement 4: "Do OpenClaw gateway logs actually contain token usage data?" This has not been verified. The cost tracker parses for `usage.input`, `usage.output`, `usage.cacheRead`, `usage.cacheWrite` fields in JSONL session logs. If the actual OpenClaw session log format doesn't include these fields, the cost tracker will silently produce `$0.00` summaries — correct behavior, but useless.

**Impact:** The entire cost-tracking pipeline (cost-tracker → cost-sentinel → budget alerts) may produce zero useful data.

**Fix:** Before any deployment, run the cost tracker against real session logs and verify the output. Document the actual JSONL schema found. If the fields don't exist, the cost tracker needs a different data source (API response interceptor, or LiteLLM becomes mandatory even for individuals).

### Major Issues (should fix before Phase 3)

#### M1: 13+ promised files from GAP_CLOSING_PLAN.md don't exist

The gap plan's Section 6 ("New Files and Modules") lists a complete file tree. Many Phase 2 and all Phase 3/4 files are absent:

**Missing Phase 2 files:**
- `skills/security-setup/` — One-time security hardening script (promised in Gap 7)
- `skills/fleet-agent/` — Zero-SSH fleet command agent (promised in Gap 1)
- `devops/fleet-agent.md` — Fleet agent desired-state spec
- `devops/rbac-config.md` — RBAC desired-state spec
- `scripts/session-management/session-ops-weekly-report.sh` — Weekly ops report
- `scripts/session-management/session-store-hygiene.sh` — Store hygiene script
- `scripts/cost-tracker/check-quotas.sh` — Shell-based quota checker

**Missing Phase 3 files:**
- `skills/user-router/` — Per-sender context routing
- `templates/TEAM.md` — Team profile template
- `templates/USERS/` — Per-user profile directory
- All `docs/` guides (LITELLM, LANGFUSE, AUTHENTIK, AUTHELIA, MULTI_USER, COMPLIANCE, MCP_FLEET, RUFLO, OPA)

**Missing Phase 4 files:**
- `skills/fleet-mcp-server/` — MCP server for fleet operations
- `skills/fleet-nl/` — NL fleet interface
- `workflows/fleet-commander/` — NL fleet management workflow

**Impact:** The README and gap plan create expectations that don't match reality. This is a credibility issue for anyone evaluating the fork.

**Fix:** Either create stub files with "Planned — Phase N" headers, or update the gap plan to clearly mark what's implemented vs. planned.

#### M2: No integration between RBAC and any other component

The `check-auth` script exists and works in isolation, but nothing calls it. The gateway-restart skill doesn't check authorization. The cost-tracker doesn't check authorization. The audit-export doesn't check authorization. The AGENTS.md template mentions RBAC but as a "placeholder."

For RBAC to have any value, at least one operational skill needs to integrate the check-auth call as a pre-flight gate. Without integration, it's dead code.

#### M3: Audit logging is write-only — no integrity protection

The audit log spec (`devops/audit-log.md`) defines an append-only JSONL format with daily rotation and compression. Good design. But:

1. **No integrity verification.** An attacker who gains file access can modify or delete audit entries with no detection. No checksums, no hash chaining, no remote copy.
2. **No write integration.** The audit log spec shows how to write entries (Python/Bash snippets), but no skill or workflow actually writes to `~/.openclaw/audit/YYYY-MM-DD.jsonl`. The `check-auth` script writes to a separate file (`auth-denials.jsonl`), not the daily structured log.
3. **audit-export reads from daily files**, but nothing produces them yet.

**Fix:** At minimum, add a hash chain (each entry includes the SHA-256 of the previous entry). For real tamper resistance, implement a daily checksum that gets written to a separate location or logged externally.

#### M4: Session management scripts reference `openclaw` CLI but may not match actual CLI

Scripts like `session-watchdog.sh`, `session-metrics.sh`, and `session-cleanup.sh` call `openclaw gateway call status --json` and parse the output. The actual CLI behavior, output format, and available subcommands haven't been verified against the current OpenClaw CLI version.

**Impact:** Scripts may fail at runtime if the CLI's actual output format differs from what's expected.

#### M5: Gateway-restart skill uses hardcoded log path and format assumptions

**File:** `skills/gateway-restart/gateway-restart`
**Issues:**
1. `LOG_DIR = Path("/tmp/openclaw")` — hardcoded path that may not match the actual gateway log location
2. Parses JSON log entries looking for `entry.get("2", "")` (pino field "2") — very fragile; if log format changes, the entire activity detection breaks
3. Comment acknowledges: "Telegram messages don't produce web-inbound/web-auto-reply markers" — meaning the log-based activity detection is incomplete for the most common channel

#### M6: No test coverage for Phase 2 scripts

`tests/phase1-validation.sh` is excellent for Phase 1 config validation, but there are zero tests for:
- `cost-tracker` (no sample JSONL to parse, no expected output to compare)
- `check-auth` (no test cases for edge cases like empty file, malformed identities, missing file)
- `audit-export` (no test fixtures)
- `gateway-restart` (no mock gateway status)

The existing `tests/test_*.py` files are upstream tests for upstream skills (asana, fathom, etc.) — none cover fork additions.

### Minor Issues (nice to have)

#### m1: `pricing.json` template has `_comment` field that's non-standard

The `templates/costs/pricing.json` includes `_comment` and `_updated` fields. These are silently ignored by the cost-tracker (which only looks up model keys), but they'd cause issues if someone fed the file to a strict JSON schema validator.

#### m2: Version inconsistency

`VERSION` file says `0.18.0`, but `README.md` badge says `2.0.0-alpha`. The CHANGELOG says `2.0.0-alpha`. Pick one.

#### m3: `watchdog-notify.sh` runs as an infinite loop via `ExecStartPost`

`ExecStartPost` runs synchronously — systemd waits for it to finish before considering the service started. Since `watchdog-notify.sh` has an infinite `while true` loop, the gateway service will **never reach the "started" state** in systemd. It should be a separate service unit or run as a background process (`ExecStartPost=/bin/bash -c '/opt/openclaw/scripts/watchdog-notify.sh &'`).

#### m4: `config-rollback.sh` restore uses `date -r` which is macOS-only

Line in `cmd_list()`: `date -r "$EPOCH"` is macOS syntax. The script has a fallback `date -d "@${EPOCH}"` for Linux, but the error suppression (`2>/dev/null`) means if both fail, the timestamp shows as "unknown" silently.

#### m5: `GAP_CLOSING_PLAN.md` references `devops/fleet.md` but the actual file is `.claude/commands/fleet.md`

Minor path inconsistency in the gap analysis — the fleet command isn't in devops/.

#### m6: `CONTRIBUTING.md` mentions `uv run --with pytest pytest tests/ -v` but the existing test files are upstream tests, not fork tests

#### m7: Templates have HTML-style `<!-- comments -->` that are visible to markdown renderers

The `TOOLS.md` template uses HTML comments for placeholder guidance. These render as invisible in most markdown viewers but clutter the raw file. Consider using a different approach or documenting that users should replace them.

### Strengths (what's done well)

#### S1: GAP_CLOSING_PLAN.md is exceptional

This is one of the best architecture planning documents I've seen in a community fork. It:
- Correctly identifies competitive gaps with specific competitor benchmarks
- Evaluates multiple open-source options for each gap with honest fit assessments
- Makes clear architecture decisions with rationale
- Provides a realistic phased roadmap with dependencies
- References community repos and gives them proper credit

#### S2: UV script convention is clean and consistent

All Phase 2 scripts use the `#!/usr/bin/env -S uv run --script` pattern with inline `pyproject.toml`-style dependency declarations. This means zero install steps — just run the script. The code quality across `cost-tracker`, `check-auth`, `audit-export`, and `gateway-restart` is consistently good:
- Proper argument parsing with `argparse`
- Error handling with informative messages
- Multiple output formats (JSON, CSV, text)
- Clear function decomposition

#### S3: Cost-tracker script is well-designed (assuming the data source works)

The cost-tracker handles:
- Multi-model pricing with configurable rates
- Cache token tracking (read and write separately)
- Agent-level and model-level aggregation
- Multi-day rollups with daily averages
- Automatic pricing.json creation on first run
- Rich terminal output with graceful fallback

If the session log format assumption holds, this is ready for production.

#### S4: Security baseline document is thorough and actionable

`devops/security-baseline.md` is a genuine checklist with verify commands, fix commands, and rationale for each requirement. The compliance checklist at the end is immediately useful. Good references to OWASP and community repos.

#### S5: Phase 1 validation test is a model for future testing

`tests/phase1-validation.sh` is a well-structured bash test harness with:
- Color-coded output
- Pass/fail/warn tracking
- Verbose mode
- Content-positive and content-negative checks
- Clear section organization

This pattern should be replicated for Phase 2.

#### S6: Watchdog infrastructure is architecturally sound

The split between process-level restart (launchd/systemd native) and health-level watchdog (companion script checking HTTP endpoint) is the right design. The macOS and Linux implementations are appropriately platform-native rather than trying to abstract across both.

#### S7: Fleet agent security spec is defense-in-depth

`devops/fleet-agent-security.md` defines a proper threat model with:
- Explicit allowlist of permitted operations (not a denylist)
- HMAC-SHA256 command signing with replay protection
- Nonce tracking with time-window validation
- Clear separation of read-only vs. write operations
- Blocked-by-default list that can't be overridden

This is the right security model even though the implementation doesn't exist yet.

#### S8: Community attribution is excellent

Proper credit to upstream (TechNickAI), production hardening (unisone), and operational patterns (digitalknk). The gap plan explicitly documents which ideas came from which source, with links.

## Gap Closure Assessment

Updated comparison table showing actual state after Phase 1 + partial Phase 2:

| Gap | Planned State | Actual State | Truly Closed? |
|-----|--------------|--------------|---------------|
| **Self-Healing (crash recovery)** | ThrottleInterval + PID watchdog + config rollback | ThrottleInterval ✅, watchdog scripts exist but macOS has a bug ⚠️, config rollback ✅ | **Mostly closed** (fix watchdog bug) |
| **Security Hardening** | .env-only + baseline spec + tool policies + prompt injection defense | .env-only ✅, baseline spec ✅, tool policies ✅, prompt injection in AGENTS.md ✅ | **Closed for Phase 1 scope** |
| **Health Check Interval** | 5 min (down from 30) | 5 min in plist/timer files ✅ | **Closed** |
| **Backup Interval** | 2h (down from 4h) | 2h in plist/timer files ✅ | **Closed** |
| **Linux Gateway Service** | systemd unit with WatchdogSec | Unit exists ✅, but watchdog-notify.sh has ExecStartPost issue ⚠️ | **Mostly closed** (fix ExecStartPost) |
| **Cost Tracking** | Log parser + budget alerts + weekly digest | Parser script exists ✅, sentinel workflow spec exists ✅, **data source unverified** ⚠️ | **Partially closed** — code exists but may not work |
| **RBAC** | Phase 2: allowlist, Phase 3: Casbin | Allowlist script exists ✅, but nothing integrates it ❌ | **Scaffolded, not closed** |
| **Audit Logging** | Structured JSONL + export + rotation | Spec ✅, export script ✅, rotation script ✅, **nothing writes to the logs** ❌ | **Scaffolded, not closed** |
| **Fleet Agent (Zero-SSH)** | Fleet inbox/outbox agent + security spec | Security spec ✅, **no agent code** ❌ | **Spec only** |
| **Session Management** | Watchdog + metrics + cleanup | Three scripts ✅, adapted from unisone | **Closed** |
| **Multi-User / RBAC** | Casbin + user router + memory isolation | Not started ❌ | **Not closed** (Phase 3) |
| **NL Fleet Control** | MCP server + fleet commander | Not started ❌ | **Not closed** (Phase 4) |
| **Enterprise (SSO, Compliance)** | Authentik/Authelia guides + compliance doc | Not started ❌ | **Not closed** (Phase 3) |

**Honest assessment:** Phase 1 gaps are genuinely closed. Phase 2 is ~40% complete — the scripts exist but lack integration, testing, and data source verification. Phases 3 and 4 are planning documents only.

**vs. commercial competitors:** The fork is meaningfully better than upstream for security hardening and operational resilience. It's still not competitive with AlphaClaw Apex or ClawHQ on cost tracking (unverified), RBAC (unintegrated), or fleet management (spec only). It's closer to parity than upstream, but "closer" is not "there."

## Recommendations

Prioritized by impact and effort:

1. **Fix C1: watchdog.sh `$THRESHOLD` bug** — 1 minute fix, restores self-healing
2. **Fix C2: check-auth fail-closed** — 5 minute fix, significant security improvement
3. **Verify C3: cost tracker data source** — Run against real session logs. If it works, document the schema. If not, pivot to alternative data source.
4. **Fix m3: watchdog-notify.sh ExecStartPost** — Make it a background process or separate service unit
5. **Fix m2: Version inconsistency** — Align VERSION file with README/CHANGELOG
6. **Create Phase 2 integration tests** — Sample JSONL fixtures + expected outputs for cost-tracker and audit-export. Test cases for check-auth edge cases.
7. **Integrate check-auth into at least one skill** — Gateway-restart is the natural first candidate
8. **Write audit log entries from check-auth** — Currently writes to separate `auth-denials.jsonl`; should also write to the daily structured log
9. **Add stub files for promised-but-missing modules** — With "Planned — Phase N" headers, so the repo doesn't look like vaporware
10. **Add hash-chain integrity to audit logs** — Each entry includes SHA-256 of previous entry

## Files Reviewed

Every file listed below was read in full during this audit:

### Root
- `README.md`
- `CONTRIBUTING.md`
- `CHANGELOG.md`
- `MIGRATION.md`
- `GAP_CLOSING_PLAN.md`
- `ATLAS4_REVIEW.md`
- `GAP_ANALYSIS_SUMMARY.md`
- `VERSION`

### devops/
- `devops/security-baseline.md`
- `devops/watchdog.md`
- `devops/audit-log.md`
- `devops/fleet-agent-security.md`
- `devops/health-check.md`
- `devops/machine-security-review.md`
- `devops/machine-setup.md`
- `devops/machine-setup-linux.md`
- `devops/notification-routing.md`
- `devops/mac/ai.openclaw.gateway.plist`
- `devops/mac/ai.openclaw.health-check.plist`
- `devops/mac/ai.openclaw.watchdog.plist`
- `devops/mac/ai.openclaw.workspace-backup.plist`
- `devops/linux/openclaw-gateway.service`
- `devops/linux/openclaw-health-check.service`
- `devops/linux/openclaw-health-check.timer`
- `devops/linux/openclaw-watchdog.service`
- `devops/linux/openclaw-workspace-backup.service`
- `devops/linux/openclaw-workspace-backup.timer`

### skills/
- `skills/cost-tracker/SKILL.md`
- `skills/cost-tracker/cost-tracker` (full Python source)
- `skills/rbac/SKILL.md`
- `skills/rbac/check-auth` (full Python source)
- `skills/audit-export/SKILL.md`
- `skills/audit-export/audit-export` (full Python source)
- `skills/gateway-restart/SKILL.md`
- `skills/gateway-restart/gateway-restart` (full Python source)
- `skills/openclaw/SKILL.md`

### workflows/
- `workflows/cost-sentinel/AGENT.md`
- `workflows/cost-sentinel/rules.md`
- `workflows/security-sentinel/AGENT.md`
- `workflows/security-sentinel/agent_notes.md`
- `workflows/cron-healthcheck/AGENT.md`

### scripts/
- `scripts/watchdog.sh`
- `scripts/watchdog-notify.sh`
- `scripts/config-rollback.sh`
- `scripts/audit-rotate.sh`
- `scripts/session-management/README.md`
- `scripts/session-management/session-watchdog.sh`
- `scripts/session-management/session-metrics.sh`
- `scripts/session-management/session-cleanup.sh`

### templates/
- `templates/AGENTS.md`
- `templates/TOOLS.md`
- `templates/authorized-users.template`
- `templates/costs/pricing.json`
- `templates/BOOT.md`
- `templates/HEARTBEAT.md`
- `templates/IDENTITY.md`
- `templates/MEMORY.md`
- `templates/SOUL.md`
- `templates/USER.md`
- `templates/multi-agent-slack-bus.json`

### tests/
- `tests/phase1-validation.sh`
- `tests/__init__.py`
- `tests/test_asana.py` (upstream)
- `tests/test_fathom.py` (upstream)
- `tests/test_fireflies.py` (upstream)
- `tests/test_followupboss.py` (upstream)
- `tests/test_limitless.py` (upstream)
- `tests/test_parallel.py` (upstream)
- `tests/test_quo.py` (upstream)

### docs/
- `docs/FLEET_BOOT_PATTERNS.md`
- `docs/FLEET_BOOT_PATTERNS_RESEARCH.md`
- `docs/MULTI_AGENT_COMMUNICATION.md`

### .claude/
- `.claude/commands/fleet.md`
- `.claude/commands/update-model.md`
- `.claude/commands/fleet-announce.md`
- `.claude/agents/openclaw-debugger.md`

**Total files read: 65+**

---

*This review is intentionally critical. The goal is to identify what needs fixing before Phase 3, not to evaluate whether the project has merit — it clearly does. The planning quality is exceptional; the execution needs to catch up.*
