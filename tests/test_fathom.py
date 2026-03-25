"""Tests for Fathom skill.

Integration tests require FATHOM_API_KEY environment variable.
Tests auto-skip if the key is not available.
"""

import os
import subprocess
from datetime import UTC, datetime
from pathlib import Path

import pytest

# Path to the skill script
SKILL_PATH = str(Path(__file__).parent / ".." / "skills" / "fathom" / "fathom")

# Skip integration tests if no API key
HAS_API_KEY = bool(os.getenv("FATHOM_API_KEY"))
requires_api_key = pytest.mark.skipif(
    not HAS_API_KEY,
    reason="FATHOM_API_KEY not set - skipping integration tests",
)


def run_skill(*args: str, env: dict | None = None) -> subprocess.CompletedProcess:
    """Run the fathom skill with given arguments."""
    cmd = ["uv", "run", SKILL_PATH, *args]
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    return subprocess.run(
        cmd,
        check=False,
        capture_output=True,
        text=True,
        env=run_env,
    )


class TestHelp:
    """Tests for help command - no API key required."""

    def test_help_shows_usage(self):
        """Help command shows usage information."""
        result = run_skill("help", env={"FATHOM_API_KEY": ""})

        assert result.returncode == 0
        assert "Fathom" in result.stdout
        assert "recent" in result.stdout
        assert "search" in result.stdout

    def test_no_args_shows_help(self):
        """Running with no arguments shows help."""
        result = run_skill(env={"FATHOM_API_KEY": ""})

        assert result.returncode == 0
        assert "Commands:" in result.stdout


class TestValidation:
    """Tests for input validation - no API key required."""

    def test_missing_api_key_shows_error(self):
        """Missing API key shows helpful error."""
        result = run_skill("recent", env={"FATHOM_API_KEY": ""})

        assert result.returncode != 0
        assert "FATHOM_API_KEY" in result.stderr

    def test_search_requires_query(self):
        """Search without query shows error."""
        result = run_skill("search", env={"FATHOM_API_KEY": "fake-key"})

        assert result.returncode != 0
        assert "query" in result.stderr.lower()

    def test_date_requires_argument(self):
        """Date command without date shows error."""
        result = run_skill("date", env={"FATHOM_API_KEY": "fake-key"})

        assert result.returncode != 0
        assert "date" in result.stderr.lower()

    def test_date_validates_format(self):
        """Date command rejects invalid date format."""
        result = run_skill("date", "not-a-date", env={"FATHOM_API_KEY": "fake-key"})

        assert result.returncode != 0
        assert "YYYY-MM-DD" in result.stderr

    def test_date_rejects_invalid_date(self):
        """Date command rejects semantically invalid dates."""
        result = run_skill("date", "2026-13-45", env={"FATHOM_API_KEY": "fake-key"})

        assert result.returncode != 0

    def test_get_requires_id(self):
        """Get command without ID shows error."""
        result = run_skill("get", env={"FATHOM_API_KEY": "fake-key"})

        assert result.returncode != 0
        assert "id" in result.stderr.lower()

    def test_unknown_command_shows_error(self):
        """Unknown command shows error."""
        result = run_skill("typo", env={"FATHOM_API_KEY": "fake-key"})

        assert result.returncode != 0
        assert "unknown command" in result.stderr.lower()

    def test_recent_limit_must_be_positive(self):
        """Recent with limit 0 shows error."""
        result = run_skill("recent", "0", env={"FATHOM_API_KEY": "fake-key"})

        assert result.returncode != 0
        assert "1-50" in result.stderr

    def test_recent_limit_capped_at_50(self):
        """Recent with limit > 50 shows error (API max is 50)."""
        result = run_skill("recent", "51", env={"FATHOM_API_KEY": "fake-key"})

        assert result.returncode != 0
        assert "50" in result.stderr

    def test_recent_limit_must_be_numeric(self):
        """Recent with non-numeric limit shows error."""
        result = run_skill("recent", "abc", env={"FATHOM_API_KEY": "fake-key"})

        assert result.returncode != 0
        assert "number" in result.stderr.lower()

    def test_raw_requires_path(self):
        """Raw command without path shows error."""
        result = run_skill("raw", env={"FATHOM_API_KEY": "fake-key"})

        assert result.returncode != 0
        assert "path" in result.stderr.lower()


@requires_api_key
class TestRecentIntegration:
    """Integration tests for recent - require API key."""

    def test_recent_returns_results(self):
        """Recent command returns formatted meetings."""
        result = run_skill("recent", "1")

        assert result.returncode == 0
        assert result.stdout.strip()

    def test_recent_default_limit(self):
        """Recent without limit uses default."""
        result = run_skill("recent")

        assert result.returncode == 0


@requires_api_key
class TestSearchIntegration:
    """Integration tests for search - require API key."""

    def test_search_returns_results(self):
        """Search command returns formatted results."""
        result = run_skill("search", "meeting")

        assert result.returncode == 0

    def test_today_returns_results(self):
        """Today command runs successfully."""
        result = run_skill("today")

        assert result.returncode == 0


@requires_api_key
class TestDateIntegration:
    """Integration tests for date - require API key."""

    def test_date_returns_results(self):
        """Date command runs successfully for today's date."""
        today = datetime.now(UTC).strftime("%Y-%m-%d")
        result = run_skill("date", today)

        assert result.returncode == 0


@requires_api_key
class TestRawIntegration:
    """Integration tests for raw - require API key."""

    def test_raw_meetings_endpoint(self):
        """Raw command can hit the meetings endpoint."""
        result = run_skill("raw", "/meetings", '{"limit": "1"}')

        assert result.returncode == 0
        assert result.stdout.strip()
