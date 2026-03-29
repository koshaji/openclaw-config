# security-setup

> **Status:** Phase 2 — Implemented
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 7 (Security Hardening)
> **Target:** One-time security hardening audit that validates the deployment against devops/security-baseline.md

## Overview

`security-setup` is a UV script that performs a security audit of the OpenClaw deployment and reports pass/fail for each check with remediation commands.

## Usage

```bash
# Run security audit (read-only, no changes)
./skills/security-setup/security-setup

# Auto-fix safe issues
./skills/security-setup/security-setup --fix

# Output as JSON for scripting
./skills/security-setup/security-setup --json
```

## What It Checks

1. **Secrets in .env** — verifies no API keys are in `openclaw.json`
2. **File permissions** — `chmod 700 ~/.openclaw` and `chmod 600 ~/.openclaw/.env`
3. **Gateway bind** — verifies gateway is bound to loopback (not 0.0.0.0)
4. **Service hardening** — `ThrottleInterval`/`RestartSec` in service files
5. **Device inventory** — lists all paired devices and flags stale entries
6. **Tool policies** — verifies exec/cron are deny-by-default per AGENTS.md

## Output Format

```
✅ PASS  Secrets in .env only (no keys in openclaw.json)
✅ PASS  ~/.openclaw permissions: drwx------ (700)
✅ PASS  ~/.openclaw/.env permissions: -rw------- (600)
❌ FAIL  Gateway bind: 0.0.0.0 (should be 127.0.0.1)
         Fix: openclaw config set gateway.bind loopback
✅ PASS  ThrottleInterval: 5 (macOS) / RestartSec=5 (Linux)
⚠️  WARN  3 paired devices (2 not seen in >30 days)
         Fix: openclaw devices list && openclaw devices revoke <id>
```

## Files

- `SKILL.md` — this file (skill description for OpenClaw)
- `security-setup` — UV script (see below)

## Installation

No installation required. UV handles dependencies inline:

```bash
chmod +x skills/security-setup/security-setup
./skills/security-setup/security-setup
```
