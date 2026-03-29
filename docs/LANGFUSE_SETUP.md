# Langfuse Setup Guide

> **Status:** Planned — Phase 3
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 2 (Cost Visibility) + Gap 5 (Observability)
> **Reference:** [github.com/langfuse/langfuse](https://github.com/langfuse/langfuse)

Langfuse is an open-source LLM observability platform providing detailed traces, metrics,
and analytics for AI applications.

## What Langfuse Provides

- Full request/response tracing (prompt + completion)
- Token usage and cost tracking per trace
- Session-level analytics
- Evaluation scores and human feedback
- Integration with LiteLLM (recommended: set up LiteLLM first)

## Status

This guide is a stub. Implementation is planned for Phase 3 (Multi-User/Teams).

**Prerequisites:**
- Phase 2 LiteLLM setup (`docs/LITELLM_SETUP.md`)
- Docker Compose environment

## Planned Implementation

- Self-hosted Docker deployment
- LiteLLM → Langfuse callback integration
- Per-agent trace tagging
- Cost dashboard alongside LiteLLM dashboard

## See Also

- `docs/LITELLM_SETUP.md` — set up LiteLLM first (Phase 2)
- [Langfuse Docs](https://langfuse.com/docs)
- [Langfuse Self-Hosting](https://langfuse.com/docs/deployment/self-host)
