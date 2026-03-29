# Agent Swarm — Routing Matrix

> Default task→model routing for swarm orchestration.
> Learning loop overrides these defaults after ≥3 historical examples diverge.
> See `AGENT.md` for the full learning algorithm.

## Routing Matrix

| Task Type | Primary Model | Fallback | Max Cost/Task | Notes |
|-----------|--------------|----------|---------------|-------|
| Code generation | sonnet | haiku | $0.50 | sonnet quality/cost balance is ideal |
| Code review | opus | sonnet | $1.00 | opus catches subtle logic errors |
| Research | sonar-pro | sonar | $0.30 | Real-time web access for current info |
| Documentation | sonnet | haiku | $0.20 | sonnet handles context well; haiku for simple docs |
| Testing | haiku | sonnet | $0.15 | haiku is fast enough for test generation |
| Security audit | opus | sonnet | $2.00 | Never compromise on security analysis |
| Summarization | haiku | sonnet | $0.05 | Cheapest capable model |
| Data analysis | sonnet | opus | $0.40 | sonnet handles structured data well |
| Architecture review | opus | sonnet | $1.50 | Complex reasoning requires top model |
| Refactoring | sonnet | haiku | $0.60 | sonnet understands code intent |
| Bug investigation | sonnet | opus | $0.80 | Start with sonnet; escalate to opus if needed |
| Compliance check | opus | sonnet | $1.00 | Accuracy critical; use best model |

## Model Aliases

These aliases map to the current best model in each tier.
Update when model versions change — do not hardcode version numbers in task configs.

| Alias | Current Model | Cost Tier |
|-------|--------------|-----------|
| `opus` | `anthropic/claude-opus-4-5` | Highest |
| `sonnet` | `anthropic/claude-sonnet-4-5` | Mid |
| `haiku` | `anthropic/claude-haiku-3-5` | Lowest |
| `sonar-pro` | `perplexity/sonar-pro` | Mid (web search) |
| `sonar` | `perplexity/sonar` | Low (web search) |

## Routing Rules

### 1. Security-critical tasks always use opus

No exceptions for:
- Security audits
- Authentication code review  
- Cryptography review
- Compliance checks
- Any task involving PII handling

Cost guard still applies ($2.00/task max), but DO NOT downgrade to sonnet just to save money.

### 2. Monitoring and cron agents always use haiku

Per `digitalknk/openclaw-runbook` recommendation: never give opus or sonnet to
monitoring agents, cron-scheduled agents, or public-facing agents.

Monitoring tasks that use this matrix: always assign `haiku`, ignore primary model column.

### 3. Research tasks need web-enabled models

Use `sonar-pro` or `sonar` for any task requiring:
- Current events, news, prices
- Documentation for libraries released after model training cutoff
- Competitive analysis requiring up-to-date information
- Any "what's the latest..." query

Fall back to `sonnet` only if Perplexity is unavailable.

### 4. Fallback escalation

If primary model returns quality_score < 0.60, automatically retry with fallback model.
This is a one-time retry — if fallback also fails, mark as failed and surface to human.

Do NOT silently fall back without logging the fallback decision.

### 5. Parallel task model diversity

When running ≥3 workers on similar tasks (e.g., triple code review), intentionally use
different models to maximize coverage:
```
Worker 1: primary model (opus/sonnet)
Worker 2: different model (sonnet/haiku)
Worker 3: web-enabled model (sonar-pro) for external context
```

This catches blind spots from training distribution biases.

---

## Learning Matrix Overrides

When the learning loop has ≥3 data points for a task type:

1. If a cheaper model achieves ≥0.85 quality consistently → promote it to primary
2. If primary model achieves <0.70 quality consistently → demote, promote fallback
3. Human ratings override computed quality scores (3× weight)

Override format in `~/.openclaw/swarm/learning-log.json`:
```json
{
  "overrides": {
    "documentation": {
      "primary": "haiku",
      "reason": "learned: haiku achieves 0.91 avg quality at 1/5 the cost",
      "data_points": 7,
      "confidence": 0.89,
      "updated_at": "2026-03-29T00:00:00Z"
    }
  }
}
```

---

## Cost Budget by Swarm Type

| Swarm Type | Typical Sub-tasks | Estimated Total Cost |
|------------|------------------|---------------------|
| Code review (single file) | 2–3 | $0.50–$2.00 |
| Security audit (codebase) | 4–6 | $2.00–$8.00 |
| Research report | 3–5 | $0.50–$1.50 |
| Full PR review | 3 | $1.50–$3.00 |
| Documentation generation | 2–4 | $0.30–$0.80 |
| Refactor planning | 2–3 | $0.60–$1.50 |

Before spawning a swarm, estimate cost using these ranges and apply the thresholds
from `AGENT.md` (ask confirmation if >$5.00).
