# Compliance Guide

> **Status:** Planned — Phase 3
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 4 (Enterprise Compliance)
> **Target:** Compliance checklist and configuration for regulated environments

## Overview

This guide covers compliance considerations for OpenClaw deployments in regulated environments (SOC 2, ISO 27001, GDPR, HIPAA-adjacent).

## Status

This guide is a stub. Implementation is planned for Phase 3.

## Planned Sections

1. **Data Classification** — What OpenClaw stores and where
2. **Audit Log Requirements** — Retention, integrity, tamper-evidence
3. **Access Control** — RBAC setup for compliance teams
4. **Data Residency** — Keeping data in specific regions
5. **Incident Response** — What to do when something goes wrong
6. **Vendor Assessment** — Anthropic/OpenAI data processing agreements
7. **SOC 2 Checklist** — Control mapping for SOC 2 Type II
8. **GDPR Considerations** — Data subject rights, retention, DPA

## Current Compliance Posture (Phase 1-2)

From `devops/security-baseline.md`:
- ✅ Secrets in `.env` only (no keys in config files)
- ✅ Gateway bound to loopback (no public exposure)
- ✅ Audit logs in `~/.openclaw/audit/` (append-only JSONL)
- ✅ `logging.redactSensitive: true` recommended
- ⚠️  Audit logs are append-only but not tamper-evident (no hash chain — planned Phase 3)
- ❌ No formal data retention policy enforced
- ❌ No GDPR data subject access/deletion tooling

## See Also

- `devops/security-baseline.md` — security requirements
- `devops/audit-log.md` — audit log specification
- `docs/MULTI_USER_SETUP.md` — multi-user RBAC
