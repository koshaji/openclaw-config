# OPA (Open Policy Agent) Setup Guide

> **Status:** Planned — Phase 4
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 3 (Advanced RBAC — Phase 4)
> **Reference:** [github.com/open-policy-agent/opa](https://github.com/open-policy-agent/opa)

## Overview

Open Policy Agent (OPA) is a general-purpose policy engine using the Rego language.
For OpenClaw, OPA would provide fine-grained, auditable policy enforcement beyond
what Casbin (Phase 3) offers.

## Why OPA (vs Casbin)?

| | Casbin (Phase 3) | OPA (Phase 4) |
|--|--|--|
| Language | CSV policies | Rego (declarative) |
| Complexity | Simple RBAC | Complex attribute-based policies |
| Audit | Basic logging | Policy decision logs |
| Ecosystem | Go-native | Large ecosystem, many integrations |
| Use case | Basic permit/deny | Complex contextual decisions |

OPA is planned for Phase 4 if Phase 3 Casbin policies become complex enough to warrant it.

## Status

This guide is a stub. Implementation is planned for Phase 4 only if Casbin RBAC
(Phase 3) proves insufficient for team needs.

## Planned Use Cases

- Time-based access control ("only allow gateway restarts during maintenance windows")
- Context-aware permissions ("atlas4 can run cost-tracker, but only for its own agent")
- Compliance policies ("deny requests that would expose PII")
- Multi-tenant isolation ("agent A cannot access agent B's sessions")

## See Also

- `devops/rbac-config.md` — RBAC configuration (Phase 2-3)
- `docs/COMPLIANCE_GUIDE.md` — compliance requirements
- [OPA Documentation](https://www.openpolicyagent.org/docs/)
