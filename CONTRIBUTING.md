# Contributing to openclaw-config (Enhanced Fork)

Thanks for contributing! This fork exists to close the gap between openclaw-config and
commercial competitors — while keeping the open-source, file-first philosophy intact.

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable releases. Tagged with version numbers. |
| `develop` | Active development. All PRs target this branch. |
| `phase-N/*` | Phase-specific work (e.g. `phase-2/cost-tracker`) |
| `fix/*` | Bug fixes that need to go straight to `main` |

**Never commit directly to `main`** unless it's a critical hotfix. Even then, open a PR.

## Pull Request Process

1. **Fork** the repo and create your branch from `develop`
2. **One PR per concern** — don't bundle unrelated changes
3. **Update CHANGELOG.md** under `[Unreleased]` with your changes
4. **Run validation** before opening a PR:
   ```bash
   bash tests/phase1-validation.sh
   ```
5. **No personal data** — templates must be generic. No names, emails, API keys.
6. **PR title format:** `[Phase N] Short description` or `[Fix] Short description`
7. **Link the issue** if one exists

### PR Checklist

- [ ] Changes are in the right place (templates/ vs devops/ vs scripts/)
- [ ] No secrets or personal data in any file
- [ ] CHANGELOG.md updated under [Unreleased]
- [ ] Validation script passes (or new checks added for new features)
- [ ] Markdown is readable and well-formatted

## Code Style

### Markdown

- Use [markdownlint](https://github.com/DavidAnson/markdownlint) rules (see `.prettierrc`)
- Headers: use `##` for sections, `###` for subsections
- Tables: use for comparisons and quick reference, not prose
- No trailing whitespace
- Blank line before and after code blocks, headers, tables

Run Prettier on markdown files before committing:
```bash
npx prettier --write "**/*.md"
```

### UV Script Conventions

All skills are [UV scripts](https://docs.astral.sh/uv/guides/scripts/) — Python files
with inline dependency declarations.

Required structure:
```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "package>=1.0",
# ]
# ///
"""
Short description of what this script does.

Usage:
    skill-name <command> [args]
"""
```

Rules:
- **Self-contained** — no shared imports or project-level dependencies
- **Inline deps** — all `pip install` via UV script metadata
- **Version pinned** — use `>=X.Y` not just `package` in dependencies
- **No API keys in scripts** — read from environment or `.env` file
- **Help text** — `--help` must work without any API keys set

### Shell Scripts

- Use `#!/usr/bin/env bash` (not `/bin/bash`)
- `set -euo pipefail` at the top
- Quote all variables: `"$VARIABLE"` not `$VARIABLE`
- Use `readonly` for constants
- Error messages to stderr: `echo "Error: ..." >&2`
- Exit codes: 0 = success, 1 = general error, 2 = usage error

### Config Files (plist, service)

- Add comments explaining non-obvious settings
- Include a reference to the GitHub issue if fixing a known bug
- Follow existing formatting conventions in the file

## What We're Looking For

**High-value contributions:**
- Phase 1 fixes and improvements (see [GAP_CLOSING_PLAN.md](GAP_CLOSING_PLAN.md))
- Additional session management scripts
- Security baseline improvements
- Test coverage for existing features
- Documentation fixes and improvements

**Out of scope for this fork:**
- Personal configurations or workflows (keep those private)
- New external service integrations without thorough documentation
- Anything requiring a new running service for individual users

## Community Repos

If you've solved something in your own fork, we'd love to know! Open an issue linking
to your solution. We explicitly credit and adopt patterns from:

- [`unisone/openclaw-config`](https://github.com/unisone/openclaw-config) — production hardening
- [`digitalknk/openclaw-runbook`](https://github.com/digitalknk/openclaw-runbook) — operational patterns

## Questions

Open an issue with the `question` label. No question is too small.

## License

By contributing, you agree your contributions will be licensed under the MIT License.
