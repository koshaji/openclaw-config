# Compliance Guide

Guide for deploying OpenClaw in regulated environments (SOC 2, GDPR, ISO 27001,
HIPAA-adjacent). Covers data classification, retention policies, audit requirements,
and control mappings.

---

## Data Classification

OpenClaw processes and stores the following data categories:

| Data Type | Location | Sensitivity | Retention |
|---|---|---|---|
| Conversation messages | Session store (in-memory / files) | High | Session lifetime |
| Audit logs | `~/.openclaw/audit/*.jsonl` | Medium | 90 days (configurable) |
| User profiles | `~/.openclaw/workspace/USERS/*.md` | Medium | Until user removed |
| User memory | `~/.openclaw/workspace/memory/users/` | High | Until user deleted |
| API keys | `~/.openclaw/.env` | Critical | Until rotated |
| Cost/usage metrics | `~/.openclaw/audit/*.jsonl` | Low | 90 days |
| RBAC policy | `~/.openclaw/rbac/policy.csv` | Medium | Until changed |

### Data Sensitivity Definitions

| Level | Definition | Handling |
|---|---|---|
| **Critical** | API keys, credentials | `.env` only, never logged, 1Password |
| **High** | Personal conversations, user memory | Encrypted at rest, access controlled |
| **Medium** | Audit logs, user profiles | Access controlled, retention enforced |
| **Low** | Usage metrics, cost data | Standard retention |

---

## Audit Log Requirements

### Format

All OpenClaw operations produce structured JSONL audit entries:

```json
{
  "ts": 1743174060,
  "agent": "atlas4",
  "sender": "telegram:833846354",
  "action": "skill_exec",
  "resource": "audit-export",
  "args": ["--days", "7"],
  "result": "PERMIT",
  "reason": "casbin permit — roles: owner",
  "mode": "casbin",
  "prev_hash": "sha256:abc123...",
  "hash": "sha256:def456..."
}
```

### Hash-Chain Integrity (Phase 3)

Starting with Phase 3, audit entries include a hash chain:
- `prev_hash`: SHA-256 of the previous entry (or `genesis` for the first)
- `hash`: SHA-256 of the current entry content including `prev_hash`

To verify integrity:

```bash
skills/audit-export/audit-export --verify --days 30
```

This catches any tampering or deletion of audit entries.

### Retention Policy

| Log Type | Default Retention | Configurable |
|---|---|---|
| Daily audit logs (`YYYY-MM-DD.jsonl`) | 90 days | Yes |
| Auth denial log (`auth-denials.jsonl`) | 365 days | Yes |
| Compressed archives (`.jsonl.gz`) | 365 days | Yes |

Configure in `~/.openclaw/config.yaml`:

```yaml
audit:
  retention_days: 90
  compress_after_days: 7
  deletion_policy: auto  # auto | manual | never
```

Rotation is handled by `scripts/audit-rotate.sh`. Schedule via cron or systemd timer.

### Append-Only Enforcement

For SOC 2 compliance, audit logs should be append-only and tamper-evident:

```bash
# Make audit directory append-only (Linux — requires root)
sudo chattr +a ~/.openclaw/audit/

# Verify
lsattr ~/.openclaw/audit/
# Expected: ----a--------e-- ~/.openclaw/audit/
```

Note: `chattr +a` means only `root` can remove the attribute. Suitable for production.

---

## GDPR Considerations

### Data Subject Rights

OpenClaw must support the following rights upon request:

#### Right of Access (Article 15)

Provide all data stored about a user:

```bash
# Export all data for telegram:833846354
IDENTITY="telegram:833846354"

# 1. Audit log entries
skills/audit-export/audit-export --days 365 --format json | \
  python3 -c "
import sys, json
for line in sys.stdin:
    entry = json.loads(line)
    if entry.get('sender') == '$IDENTITY':
        print(line, end='')
" > /tmp/gdpr-audit-$IDENTITY.json

# 2. User profile
cat ~/.openclaw/workspace/USERS/telegram-*.md | grep -l "$IDENTITY" | xargs cat

# 3. Memory files
ls ~/.openclaw/workspace/memory/users/

echo "Data export complete."
```

#### Right to Erasure (Article 17) — Right to be Forgotten

```bash
# Remove user from RBAC policy
sed -i "/telegram:833846354/d" ~/.openclaw/rbac/policy.csv

# Archive (don't delete immediately — check retention obligations)
mkdir -p ~/.openclaw/gdpr-archive/
mv ~/.openclaw/workspace/USERS/telegram-833846354.md \
   ~/.openclaw/gdpr-archive/

# Archive memory (retain for audit period, then delete)
mv ~/.openclaw/workspace/memory/users/alice \
   ~/.openclaw/gdpr-archive/memory-alice-$(date +%Y%m%d)

# Schedule final deletion after retention period expires
echo "DELETE ~/.openclaw/gdpr-archive/memory-alice-* on $(date -d '+90 days' +%Y-%m-%d)" \
   >> ~/.openclaw/gdpr-deletion-schedule.txt

echo "Erasure queued. Final deletion scheduled per retention policy."
```

#### Right to Rectification (Article 16)

Update user profile data:

```bash
nano ~/.openclaw/workspace/USERS/telegram-833846354.md
# Correct any inaccurate information
```

#### Right to Data Portability (Article 20)

Export in machine-readable format (JSON):

```bash
skills/audit-export/audit-export --days 365 --format json > user-data-export.json
```

### Data Minimization

OpenClaw recommendations:
- Enable `logging.redactSensitive: true` in the gateway config
- Do not log full message bodies (log metadata only)
- Do not store API keys in audit logs (they're in `.env` only)
- Purge session stores for inactive users per your retention policy

### Data Processing Agreement (DPA)

For LLM API providers:
- **Anthropic:** Review at [anthropic.com/legal/privacy](https://www.anthropic.com/legal/privacy)
- **OpenAI:** Review at [openai.com/policies/privacy-policy](https://openai.com/policies/privacy-policy)

For GDPR compliance, ensure you have a DPA with each provider before processing
EU personal data. LiteLLM can route EU users to EU-region endpoints where available.

---

## SOC 2 Control Mapping

SOC 2 Type II covers five Trust Service Criteria (TSC). Below is how OpenClaw
config maps to each:

### CC6 — Logical and Physical Access Controls

| Control | OpenClaw Implementation |
|---|---|
| CC6.1 — Access restrictions | Casbin RBAC (`~/.openclaw/rbac/policy.csv`) |
| CC6.2 — Authentication credentials | `.env` secrets, 1Password via Vault4 |
| CC6.3 — Access review | Quarterly review of `policy.csv` and USERS/ profiles |
| CC6.6 — Unauthorized access detection | Auth denial log (`auth-denials.jsonl`) |
| CC6.7 — Transmission of confidential info | HTTPS (TLS 1.2+) via reverse proxy |
| CC6.8 — Malware protection | Host OS security baseline (`devops/security-baseline.md`) |

### CC7 — System Operations

| Control | OpenClaw Implementation |
|---|---|
| CC7.1 — Vulnerability management | `scripts/security-setup` baseline, unattended upgrades |
| CC7.2 — Monitoring of system components | `workflows/security-sentinel/` + health checks |
| CC7.3 — Change management | Git commits with signed tags for config changes |
| CC7.4 — Incident response | `devops/machine-security-review.md` procedures |

### CC8 — Change Management

| Control | OpenClaw Implementation |
|---|---|
| CC8.1 — Change authorization | Git + PR workflow (all config changes reviewed) |
| CC8.1 — Testing before deployment | Phase validation tests (`tests/phase*-validation.sh`) |

### CC9 — Risk Mitigation

| Control | OpenClaw Implementation |
|---|---|
| CC9.1 — Risk assessment | `ARCHITECTURE_REVIEW.md`, `GAP_ANALYSIS_SUMMARY.md` |
| CC9.2 — Third-party risk | DPA review for Anthropic/OpenAI (see above) |

### A1 — Availability

| Control | OpenClaw Implementation |
|---|---|
| A1.1 — Capacity planning | Cost quotas (`scripts/cost-tracker/check-quotas.sh`) |
| A1.2 — Environmental protections | `devops/watchdog.md`, systemd/launchd auto-restart |
| A1.3 — Backup and recovery | `devops/mac/ai.openclaw.workspace-backup.plist` |

---

## Checklist for Regulated Environments

### Pre-Deployment

- [ ] Reviewed data classification (above) and documented your specific data flows
- [ ] Confirmed DPA with each LLM provider (Anthropic, OpenAI, etc.)
- [ ] Set up Casbin RBAC with least-privilege roles
- [ ] Enabled hash-chain audit logging (`audit-export --verify` works)
- [ ] Configured audit log retention policy (90+ days for SOC 2)
- [ ] Enabled append-only audit directory (`chattr +a` or equivalent)
- [ ] Secrets stored in 1Password/Vault, not in plaintext files
- [ ] Gateway bound to loopback or internal network (not 0.0.0.0)
- [ ] TLS configured on reverse proxy (if exposing externally)
- [ ] 2FA enabled for admin identities (via Authelia or Authentik)

### Ongoing Operations

- [ ] Weekly: Review `auth-denials.jsonl` for anomalies
- [ ] Monthly: Run `audit-export --verify` to check hash chain integrity
- [ ] Quarterly: Review and audit `policy.csv` — remove departed users
- [ ] Quarterly: Rotate API keys
- [ ] Annually: Full vendor risk assessment (Anthropic, OpenAI DPAs)
- [ ] On user departure: Execute Right to Erasure procedure (see above)
- [ ] On incident: Follow `devops/machine-security-review.md` procedures

### Evidence Collection (for Auditors)

```bash
# Generate compliance evidence bundle
EVIDENCE_DIR=~/compliance-evidence-$(date +%Y%m%d)
mkdir -p "$EVIDENCE_DIR"

# 1. Access control evidence
cp ~/.openclaw/rbac/policy.csv "$EVIDENCE_DIR/rbac-policy.csv"
ls ~/.openclaw/workspace/USERS/ > "$EVIDENCE_DIR/user-list.txt"

# 2. Audit log sample (last 30 days)
skills/audit-export/audit-export --days 30 --format json \
  --output "$EVIDENCE_DIR/audit-30days.json"

# 3. Hash chain verification
skills/audit-export/audit-export --verify --days 30 \
  > "$EVIDENCE_DIR/audit-integrity-check.txt" 2>&1

# 4. Config snapshot
git -C /path/to/openclaw-config log --oneline -20 \
  > "$EVIDENCE_DIR/config-change-log.txt"

echo "Evidence bundle: $EVIDENCE_DIR"
```

---

## ISO 27001 Alignment

OpenClaw's config structure maps to ISO 27001 Annex A controls:

| Annex A Control | OpenClaw Feature |
|---|---|
| A.9 — Access control | Casbin RBAC + allowlist |
| A.10 — Cryptography | `.env` secrets management, TLS |
| A.12 — Operations security | Audit logging, monitoring workflows |
| A.16 — Incident management | Security sentinel workflow |
| A.18 — Compliance | This document + retention policies |

---

## See Also

- `devops/security-baseline.md` — security requirements
- `devops/audit-log.md` — audit log specification
- `devops/rbac-config.md` — RBAC configuration
- `skills/audit-export/SKILL.md` — audit log export and verification
- `docs/MULTI_USER_SETUP.md` — multi-user setup (includes GDPR erasure)
- `docs/LANGFUSE_SETUP.md` — LLM observability (tracing for compliance)
