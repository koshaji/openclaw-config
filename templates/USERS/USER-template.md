# USER Profile Template

> **Status:** Planned — Phase 3
> **Tracking:** GAP_CLOSING_PLAN.md, Gap 3 (Per-User Context Routing)
> **Target:** Per-user profile loaded by user-router to inject user context

<!-- Copy this file to templates/USERS/<platform>-<id>.md and fill it in -->
<!-- Example: templates/USERS/telegram-833846354.md -->

## Identity

- **Name:** [Full name or handle]
- **Identity:** [platform:id, e.g., telegram:833846354]
- **Role:** [admin | user | readonly]
- **Timezone:** [e.g., Australia/Melbourne]
- **Language:** [Preferred response language]

## Context

<!-- What the agent should know about this user -->
<!-- This is injected into the system prompt for each turn from this user -->

- **Occupation:** [Role/job]
- **Interests:** [What they typically ask about]
- **Preferences:** [Communication style, detail level, etc.]
- **Do not:** [Things to avoid]

## Memory Namespace

<!-- Where this user's memory files are stored -->

- **Daily notes:** `~/.openclaw/users/<identity>/memory/YYYY-MM-DD.md`
- **Long-term:** `~/.openclaw/users/<identity>/MEMORY.md`
- **Projects:** `~/.openclaw/users/<identity>/projects/`

## Permissions

<!-- Overrides from RBAC defaults, if any -->
<!-- Usually inherited from role in TEAM.md -->

- **Role:** [admin | user | readonly]
- **Extra permissions:** [none | specific skill overrides]
- **Restrictions:** [none | specific skill blocks]

## Notes

<!-- Operational notes specific to this user -->

_Add user-specific context here._
