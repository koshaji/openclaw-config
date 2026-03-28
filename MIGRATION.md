# Migration Guide

How to upgrade from the upstream [TechNickAI/openclaw-config](https://github.com/TechNickAI/openclaw-config)
to this Enhanced Fork.

---

## Quick Migration (Recommended)

If you just want the critical bug fixes without switching to this fork:

### 1. Fix the ThrottleInterval (Issue #4632)

This prevents 5-minute outages after repeated gateway crashes.

**macOS** — edit `~/Library/LaunchAgents/ai.openclaw.gateway.plist` (or wherever your
gateway plist is):
```xml
<!-- Add inside the <dict>: -->
<key>ThrottleInterval</key>
<integer>5</integer>
```

Then reload: `launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist && launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist`

**Linux** — edit `/etc/systemd/user/openclaw-gateway.service` or `~/.config/systemd/user/openclaw-gateway.service`:
```ini
[Service]
Restart=on-failure
RestartSec=5
StartLimitIntervalSec=0
```

Then reload: `systemctl --user daemon-reload && systemctl --user restart openclaw-gateway`

### 2. Secure Your Secrets (Issues #9627, #11202)

Move ALL API keys out of `openclaw.json` and into `~/.openclaw/.env`:

```bash
# Check for exposed keys in openclaw.json
grep -E '(sk-|AIza|token|key|secret|password)' ~/.openclaw/openclaw.json

# Fix permissions
chmod 600 ~/.openclaw/.env
chmod 700 ~/.openclaw/
```

Never put `${VAR}` placeholders in `openclaw.json` — they write plaintext to disk on
`openclaw doctor`.

### 3. Reduce Health Check Interval

Edit `devops/mac/ai.openclaw.health-check.plist` — change `StartInterval` from 1800 to 300.
Edit `devops/linux/openclaw-health-check.timer` — change `OnUnitActiveSec` from 30min to 5min.

---

## Full Migration to This Fork

### Prerequisites

- OpenClaw running (any version of upstream openclaw-config)
- `gh` CLI authenticated, or HTTPS access to GitHub
- Backup your current config first (see step 0)

### Step 0: Backup

```bash
# Backup your current openclaw config
cp -r ~/src/openclaw-config ~/src/openclaw-config.upstream-backup
cp -r ~/.openclaw ~/.openclaw.backup-$(date +%Y%m%d)
```

### Step 1: Update Remote

```bash
cd ~/src/openclaw-config

# Add this fork as a remote
git remote add fork https://github.com/koshaji/openclaw-config.git

# Fetch fork changes
git fetch fork

# Check what's different
git log --oneline HEAD..fork/main
```

### Step 2: Merge or Rebase

**Option A (Merge — preserves your history):**
```bash
git merge fork/main --no-ff -m "Merge Enhanced Fork Phase 1 changes"
```

**Option B (Fresh clone — simpler for most users):**
```bash
cd ~/src
mv openclaw-config openclaw-config.old
git clone https://github.com/koshaji/openclaw-config.git
```

If using Option B, re-copy your personal templates:
```bash
# Copy your personal files from the backup (do NOT copy plist/service files — use the new ones)
cp ~/src/openclaw-config.old/templates/USER.md ~/src/openclaw-config/templates/
cp ~/src/openclaw-config.old/templates/SOUL.md ~/src/openclaw-config/templates/
```

### Step 3: Apply Service File Updates

#### macOS

Copy updated plist files and reload:
```bash
cp devops/mac/ai.openclaw.health-check.plist ~/Library/LaunchAgents/
cp devops/mac/ai.openclaw.workspace-backup.plist ~/Library/LaunchAgents/

# Reload services
for plist in ai.openclaw.health-check ai.openclaw.workspace-backup; do
    launchctl unload ~/Library/LaunchAgents/$plist.plist 2>/dev/null || true
    launchctl load ~/Library/LaunchAgents/$plist.plist
done
```

#### Linux (systemd)

```bash
# Copy the new gateway service (includes WatchdogSec and crash recovery fixes)
cp devops/linux/openclaw-gateway.service ~/.config/systemd/user/

# Copy updated timers
cp devops/linux/openclaw-health-check.timer ~/.config/systemd/user/
cp devops/linux/openclaw-workspace-backup.timer ~/.config/systemd/user/

# Reload and restart
systemctl --user daemon-reload
systemctl --user restart openclaw-health-check.timer
systemctl --user restart openclaw-workspace-backup.timer

# Enable the gateway service if not already running
systemctl --user enable --now openclaw-gateway.service
```

### Step 4: Security Baseline Check

Run the security baseline validation:
```bash
bash tests/phase1-validation.sh
```

Review any FAIL items in the output and address them per [devops/security-baseline.md](devops/security-baseline.md).

### Step 5: Verify

```bash
# Check gateway is running
openclaw gateway status

# Check health check is scheduled
# macOS:
launchctl list | grep openclaw
# Linux:
systemctl --user list-timers | grep openclaw
```

---

## What Changed in Templates

### templates/AGENTS.md

Added sections at the bottom:
- **RBAC (Role-Based Access Control)** — placeholder for Phase 2/3 implementation
- **Tool Policy Defaults** — deny exec/cron by default
- **Prompt Injection Defenses** — protection guidelines

**Action required:** If you have a deployed instance using the upstream `AGENTS.md`,
add the new sections from the fork version to your deployed file. Don't overwrite your
deployed file — append the new sections.

### templates/TOOLS.md

Added sections:
- **.env-only secrets** documentation
- **Device inventory** section for monthly hygiene review
- `logging.redactSensitive` configuration example

**Action required:** Review your deployed `TOOLS.md` and add any missing sections from
the fork version.

---

## Rollback

If you need to roll back to the upstream version:

```bash
cd ~/src/openclaw-config
git log --oneline | head -20
# Find the last upstream commit, then:
git checkout <upstream-commit-hash> -- .
```

Or restore from backup:
```bash
rm -rf ~/src/openclaw-config
mv ~/src/openclaw-config.upstream-backup ~/src/openclaw-config
```

---

## Getting Help

- Open an issue: https://github.com/koshaji/openclaw-config/issues
- Check the gap-closing plan: [GAP_CLOSING_PLAN.md](GAP_CLOSING_PLAN.md)
- Original upstream: https://github.com/TechNickAI/openclaw-config
