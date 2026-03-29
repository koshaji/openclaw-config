# USER Profile — [Full Name]

> Copy this file to `~/.openclaw/workspace/USERS/<platform>-<id>.md`
> Example: `USERS/telegram-833846354.md`
> Fill in all sections. Remove placeholder text in [brackets].

---

## Identity

- **Name:** [Full name or preferred handle]
- **Role:** [owner | admin | operator | observer]
- **Timezone:** [e.g., Australia/Melbourne]
- **Language:** [en | fr | de | etc.]

## Identities

<!-- List all platform IDs for this person. user-router will match any of these. -->

- telegram:[user_id]
- discord:[user_id]
- whatsapp:[+phone_number]
- slack:[user_id]

## Context

<!-- Injected into the system prompt for every turn from this user. -->
<!-- Tell the agent who this person is and how to work with them best. -->

- **Occupation:** [Role/job title, e.g., "Software engineer at Acme Corp"]
- **Expertise:** [Areas of expertise, e.g., "Python, DevOps, cloud infrastructure"]
- **Common requests:** [What they typically ask the agent to do]
- **Projects:** [Active projects context, e.g., "Building a SaaS product on AWS"]

## Preferences

- **Communication style:** [concise | detailed | casual | formal]
- **Response format:** [markdown | plain text | bullet points]
- **Code style:** [Python preferred | TypeScript | etc.]
- **Avoid:** [Things the agent should never do for this user]
- **Always:** [Things the agent should always do for this user]

## Memory

<!-- Where this user's private memory is stored. -->
<!-- Leave as default or customize. -->

- **Private memory:** `~/.openclaw/workspace/memory/users/[username]/`
- **Daily notes:** `~/.openclaw/workspace/memory/users/[username]/YYYY-MM-DD.md`
- **Long-term:** `~/.openclaw/workspace/memory/users/[username]/MEMORY.md`

## RBAC

<!-- Role is set above under Identity. -->
<!-- Add extra overrides here if needed — usually inherited from TEAM.md defaults. -->

- **Role:** [Matches the role above — keep in sync with policy.csv]
- **Extra permissions:** [none | list any extra scopes granted directly]
- **Restrictions:** [none | list any scopes explicitly denied]

## Notes

<!-- Operational notes the agent should be aware of. -->

- [Add any additional context, quirks, or instructions here]

---

*Last updated: [YYYY-MM-DD]*
*Updated by: [who updated this profile]*
