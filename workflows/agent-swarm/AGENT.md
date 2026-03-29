---
name: agent-swarm
version: 1.0.0
description: Smart multi-agent swarm orchestration with learning loop
phase: 4
status: implemented
pattern: unisone/openclaw-config
---

# Agent Swarm Orchestration

> **Status:** Phase 4 — Implemented
> **Pattern source:** `unisone/openclaw-config` smart routing + learning loop
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 4 (Agent Swarm Orchestration)

## Overview

The agent swarm workflow enables Atlas4 (the queen agent) to decompose complex tasks
and delegate sub-tasks to specialist worker agents running in parallel. It implements
the smart model routing + learning loop pattern from `unisone/openclaw-config`.

**Use when:**
- A task has multiple independent sub-components that can run simultaneously
- Different parts of a task benefit from different models (e.g., code → sonnet, research → sonar)
- You need parallel execution and result aggregation
- Task complexity justifies spawning multiple sub-agents

**Don't use for:**
- Simple sequential tasks (one agent is faster)
- Fleet operations (use fleet-commander instead)
- Tasks under 30 seconds (orchestration overhead not worth it)

---

## Architecture

```
Human → Atlas4 (queen)
         ↓
    [Task Decomposition]
    Break complex task into N sub-tasks
    Assign each sub-task to best model/agent
         ↓
    [Parallel Execution]
    Spawn worker agents concurrently
    Each worker has: task, model, timeout, context
         ↓
    [Health Monitoring]
    Monitor workers every 30s
    Respawn failed workers (max 3 attempts)
         ↓
    [Result Aggregation]
    Collect all worker outputs
    Run quality checks
    Synthesize final result
         ↓
    [Learning Loop]
    Record: task_type → model → quality_score → cost → latency
    Update routing-matrix.md overrides after ≥3 data points
         ↓
Human ← Atlas4 (synthesized result)
```

---

## Task Decomposition Algorithm

### Step 1: Classify task type

Match the task against known types in `routing-matrix.md`:
- Code generation, code review, research, documentation, testing, security audit
- If ambiguous, default to the model with the best general-purpose score

### Step 2: Identify parallelizable sub-tasks

Decompose the task into independent units. A sub-task is independent if:
- It does not depend on the output of another sub-task
- It can be described completely without referencing other sub-task results
- It has a clear, verifiable output format

**Example decomposition:**
```
Task: "Review the security of this codebase and suggest improvements"
  Sub-task 1: Analyze authentication code (security audit → opus)
  Sub-task 2: Scan for SQL injection patterns (code review → opus)
  Sub-task 3: Check dependency vulnerabilities (research → sonar-pro)
  Sub-task 4: Document findings in structured format (documentation → sonnet)
```

### Step 3: Assign models using routing matrix

Use `routing-matrix.md` for primary model assignment. Override with learned data from
`learning-log.json` if ≥3 historical examples show a different model performs better.

### Step 4: Spawn workers

Spawn each worker as a sub-agent with:
```json
{
  "task": "<specific sub-task description>",
  "model": "<assigned model>",
  "timeout_sec": 300,
  "output_format": "<expected format>",
  "quality_check": "<how to verify output>"
}
```

---

## Parallel Execution

Workers run concurrently. Atlas4 does not wait for one to finish before starting another.

**Concurrency limits:**
- Max 4 workers simultaneously (to stay within API rate limits)
- If task requires >4 workers, batch them in rounds of 4
- Cost guard: if estimated total cost > $5.00, ask for confirmation first

**Worker context:**
Each worker receives only what it needs — no shared state. If workers need to reference
common context (e.g., the same codebase), include it in each worker's task description.

---

## Health Monitoring & Auto-Respawn

Atlas4 monitors all active workers every 30 seconds:

```
Worker health states:
  active    → normal, let it run
  slow      → past 50% of timeout with <20% progress → warn, but don't kill
  stalled   → no output change for 3 consecutive checks → respawn
  failed    → explicit error or crash → respawn
  timed_out → exceeded timeout → respawn with shorter, more focused task
  done      → output available → collect result
```

**Respawn policy:**
- Max 3 respawn attempts per worker
- On respawn: same task, same model, +50% timeout
- After 3 failures: mark as failed, continue with partial results
- Escalate to human if >50% of workers fail

**Respawn log example:**
```json
{
  "worker_id": "worker-3",
  "task_type": "code_review",
  "attempts": 2,
  "failure_reason": "timeout",
  "respawned_at": "2026-03-29T00:15:00Z",
  "new_timeout_sec": 450
}
```

---

## Result Aggregation

Once all workers complete (or max retries exhausted):

1. **Collect outputs** — gather all worker results
2. **Quality check** — verify each output meets the specified format and quality bar
3. **Handle partial results** — if some workers failed, note gaps clearly in output
4. **Synthesize** — Atlas4 combines all outputs into a coherent final result
5. **Format** — produce output in the format the human requested

**Quality check criteria (per task type):**

| Task Type | Quality Check |
|-----------|--------------|
| Code generation | Runs without syntax errors, passes basic tests |
| Code review | Has specific file/line references, not generic advice |
| Research | Has citations/sources, not just opinions |
| Documentation | Complete, no TODO placeholders |
| Testing | Tests actually run and produce output |
| Security audit | Specific CVEs or patterns cited, not vague warnings |

If a worker output fails quality check, request revision (counts as respawn attempt).

---

## Learning Loop

After every swarm run, record the performance data:

```json
{
  "ts": "2026-03-29T00:00:00Z",
  "task_type": "code_review",
  "model_used": "anthropic/claude-opus-4-5",
  "quality_score": 0.92,
  "cost_usd": 0.34,
  "latency_sec": 87,
  "succeeded": true,
  "human_rating": null
}
```

**Learning trigger:** After ≥3 runs of the same task type with the same model:
- If a cheaper/faster model consistently achieves quality_score ≥ 0.85, update the
  routing matrix to prefer that model
- If the primary model consistently underperforms (<0.70), update fallback to be primary

Human feedback (`human_rating: 1–5`) has 3× weight in the learning calculation.

The live learning data is stored in `~/.openclaw/swarm/learning-log.json`
(gitignored — personal to each deployment). The seed template is at
`workflows/agent-swarm/learning-log.json`.

---

## Cost Controls

Before spawning any swarm, estimate total cost:

```
Estimated cost = sum(
  estimated_tokens(sub_task) × model_cost_per_token
  for each sub_task
)
```

**Thresholds:**
- Under $1.00 → proceed without confirmation
- $1.00–$5.00 → show estimate, proceed unless user says no
- Over $5.00 → require explicit confirmation: "Estimated cost: $X.XX. Proceed? (y/n)"
- Over $20.00 → always stop and ask, regardless of context

Per-model cost data is in `routing-matrix.md`.

---

## Triple Code Review Pattern

For security-critical or high-stakes code review tasks, use the triple-review pattern
from `unisone/openclaw-config`:

```
Sub-task 1: Primary review    (opus)
Sub-task 2: Secondary review  (sonnet — different model, catches different things)
Sub-task 3: Security scan     (sonar-pro — external knowledge, CVE patterns)

Aggregation: Atlas4 merges findings, deduplicates, ranks by severity
```

This catches bugs that any single model might miss due to training distribution biases.
Only use triple review for: security audits, financial logic, authentication code,
and any code that will be deployed to production.

---

## Files

| File | Purpose |
|------|---------|
| `AGENT.md` | This file — workflow definition |
| `routing-matrix.md` | Default task→model routing table |
| `learning-log.json` | Seed template for performance tracking |
| `~/.openclaw/swarm/learning-log.json` | Live learning data (gitignored) |

## See Also

- `docs/RUFLO_SETUP.md` — Ruflo for external swarm orchestration (alternative for very large swarms)
- `workflows/fleet-commander/AGENT.md` — fleet management (not swarm work)
- `devops/rbac-config.md` — ensure worker agents have appropriate permissions
