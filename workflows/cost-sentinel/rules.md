# Cost Sentinel Rules

Configure your budget thresholds here. The cost-sentinel workflow reads this file on
every run. Edit freely — it's never overwritten by updates.

## Daily Budgets

- Total: $25/day
- Per agent: $10/day
- Alert at: 80% of budget

## Model Allocation

- Opus: max $15/day (don't waste on monitoring tasks)
- Sonnet: max $10/day
- Haiku: max $5/day

## Escalation

- 80%: Silent notification to admin
- 100%: Urgent notification + log warning
- 150%: Urgent notification + recommend throttling

## Weekly Budget

- Total: $150/week  (≈ 6 × $25/day, leaving headroom)
- Alert if any single day exceeds $40 (spike detection)

## Notifications

- Channel: read from ~/.openclaw/health-check-admin
- Weekly digest: every Sunday regardless of alert status
- Quiet hours: none (this is a monitoring task, always alert)

## Notes

- Costs are estimates based on public pricing — actual billed amounts may differ
- Cache tokens (read/write) are included in estimates
- If a model isn't in pricing.json, its cost shows as $0.00 (not zero spend — unknown)
- Update ~/.openclaw/costs/pricing.json when model prices change
