# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's
unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills
without losing your notes, and share skills without leaking your infrastructure.

---

## Your Local Notes

<!-- Add your environment-specific notes below -->

### Contacts

<!-- Key contacts with their details -->
<!-- Example: -->
<!--
### Partner
- Phone: +1 xxx-xxx-xxxx
- iMessage: Yes
- WhatsApp: Yes
-->

### Calendar

<!-- Calendar configuration -->
<!-- Example: -->
<!--
- Primary: personal@email.com
- Work: work@company.com
-->

### Task Management

<!-- AGENTS.md Q&A vs Task flow uses the first available method: -->
<!-- 1. Asana (if configured below) -->
<!-- 2. Apple Notes (macOS — create/update a "Tasks" note in a folder named after you) -->
<!-- 3. Plain text file (~/tasks.md as markdown checklist) -->

<!-- Uncomment and fill in if Asana is available: -->
<!--
- Platform: Asana
- Workspace ID: 1234567890
- Project ID: 1234567890
- Assignee ID: 1234567890 (your assistant user)
-->

### Integrations

<!-- API keys, services, accounts -->
<!-- Document what's configured, not the secrets themselves -->

---

## Security Configuration

### Secrets (.env-only)

⚠️ **NEVER put API keys or secrets in `openclaw.json`.** Use `~/.openclaw/.env` only.

The `${VAR}` syntax in `openclaw.json` resolves to plaintext on `openclaw doctor`
(issue #9627). All provider keys in `openclaw.json` are sent to the LLM on every turn
(issue #11202).

**Correct pattern:**
```bash
# In ~/.openclaw/.env:
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
TELEGRAM_BOT_TOKEN=...

# openclaw.json should NOT contain any of these
```

**Set permissions:**
```bash
chmod 600 ~/.openclaw/.env
chmod 700 ~/.openclaw/
```

### Logging

Enable sensitive data redaction to protect tool call content in logs:

```json
// In ~/.openclaw/openclaw.json:
{
  "logging": {
    "redactSensitive": "tools"
  }
}
```

### Device Inventory (Review Monthly)

Run monthly: `openclaw devices list`
Remove any device you don't recognize: `openclaw devices remove <id>`

Document known devices here:
<!-- List your authorized devices below -->
<!--
- MacBook Pro (Home) — paired YYYY-MM-DD
- iPhone 15 — paired YYYY-MM-DD
- Linux VPS (prod) — paired YYYY-MM-DD
-->

---

Add whatever helps you do your job. This is your cheat sheet.
