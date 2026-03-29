# USER Profile — [Full Name]

> **How to use this template:**
> 1. Copy to `~/.openclaw/workspace/USERS/<platform>-<id>.md`
>    Example: `USERS/telegram-833846354.md`
> 2. Fill in all sections. Remove placeholder text in [brackets].
> 3. Add the identity to `~/.openclaw/rbac/policy.csv` with the correct role.
> 4. Create the user's private memory directory:
>    `mkdir -p ~/.openclaw/workspace/memory/users/<username>/`
>
> The `user-router` script reads this file to inject user context into the agent's
> system prompt for every turn from this user.

---

## Identity

- **Name:** [Full name or preferred handle]
- **Role:** [owner | admin | operator | observer]
- **Timezone:** [e.g., Australia/Melbourne | America/New_York | Europe/London | UTC]
- **Language:** [en | fr | de | es | etc.]
- **Joined:** [YYYY-MM-DD — when this user was added]

## Identities

<!-- List ALL platform IDs for this person. user-router will match any of these. -->
<!-- Format: platform:id -->
<!-- Supported platforms: telegram, discord, whatsapp, slack -->

- telegram:[user_id]
- discord:[user_id]
- whatsapp:[+phone_number_E164_format]
- slack:[user_id]

## Context

<!-- This section is injected into the agent's system prompt for every turn from this user. -->
<!-- Be specific — the agent uses this to personalize responses. -->

- **Occupation:** [Role/job title, e.g., "Software engineer at Acme Corp"]
- **Expertise:** [Areas of expertise, e.g., "Python, DevOps, AWS, Kubernetes"]
- **Common requests:** [What they typically ask the agent, e.g., "Code review, debugging, docs"]
- **Active projects:** [Project names and brief description]
- **Team context:** [How they fit into the team, what they own]

## Preferences

<!-- Communication and formatting preferences. -->
<!-- These shape how the agent responds to this user. -->

- **Communication style:** [concise | detailed | casual | formal | bullet-heavy]
- **Response format:** [markdown | plain text | bullet points | code-heavy]
- **Code style:** [Python preferred | TypeScript | Go | language-agnostic]
- **Detail level:** [high-level summaries | step-by-step detail | both depending on context]
- **Avoid:** [Things the agent should never do, e.g., "Don't use jargon", "Don't be verbose"]
- **Always:** [Things the agent should always do, e.g., "Always include code examples"]
- **Humor:** [welcome | minimal | none]

## Memory

<!-- Where this user's private memory is stored. -->
<!-- The agent loads this path's MEMORY.md at the start of each session from this user. -->
<!-- Replace <username> with the user's slug (e.g., alice, bob). -->

- **Private memory path:** `~/.openclaw/workspace/memory/users/<username>/`
- **Daily notes:** `~/.openclaw/workspace/memory/users/<username>/YYYY-MM-DD.md`
- **Long-term memory:** `~/.openclaw/workspace/memory/users/<username>/MEMORY.md`
- **Personal projects:** `~/.openclaw/workspace/memory/users/<username>/projects/`

## RBAC

<!-- Role determines what this user can do via the agent. -->
<!-- Keep in sync with ~/.openclaw/rbac/policy.csv. -->
<!-- See devops/rbac-config.md for scope definitions. -->

- **Role:** [Matches the role listed under Identity — keep in sync with policy.csv]
- **Extra permissions:** [none | list any scopes granted beyond the role default]
- **Restrictions:** [none | list any scopes explicitly blocked for this user]

### Role Summary

| Role | skill_exec | config_write | fleet_manage | audit_read | secret_access | gateway_restart |
|---|---|---|---|---|---|---|
| owner | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| admin | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| operator | ✓ | ✗ | ✗ | ✓ | ✗ | ✓ |
| observer | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |

## Notes

<!-- Any additional context the agent should be aware of for this user. -->
<!-- Examples: special instructions, quirks, important history. -->

- [Add user-specific operational context here]

---

## Setup Checklist

- [ ] Copied template to `USERS/<platform>-<id>.md`
- [ ] Filled in all Identity fields
- [ ] Added all platform IDs to the Identities section
- [ ] Added RBAC entry: `g, <identity>, <role>` in `~/.openclaw/rbac/policy.csv`
- [ ] Created memory directory: `~/.openclaw/workspace/memory/users/<username>/`
- [ ] Initialized `MEMORY.md` in the memory directory
- [ ] Added user to `TEAM.md` member table
- [ ] Tested: `skills/user-router/user-router <identity>` returns correct profile

---

*Last updated: [YYYY-MM-DD]*
*Updated by: [who updated this profile]*
