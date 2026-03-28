#!/usr/bin/env bash
# phase1-validation.sh — Validate all Phase 1 changes in openclaw-config (Enhanced Fork)
#
# Checks that all Phase 1 bug fixes and additions are correctly in place.
# Run this after migration from upstream to verify the fork is properly applied.
#
# Usage:
#   bash tests/phase1-validation.sh
#   bash tests/phase1-validation.sh --verbose
#
# Exit codes:
#   0 — All checks passed
#   1 — One or more checks failed

set -uo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
VERBOSE=false
PASS=0
FAIL=0
WARN=0

for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=true ;;
        --help|-h)
            echo "Usage: $0 [--verbose]"
            echo ""
            echo "Validates Phase 1 changes in openclaw-config (Enhanced Fork)"
            echo ""
            echo "Options:"
            echo "  --verbose, -v    Show details for passing checks too"
            exit 0
            ;;
    esac
done

# ── Output helpers ─────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

# Disable colors if not a terminal
if [ ! -t 1 ]; then
    GREEN=''; RED=''; YELLOW=''; CYAN=''; NC=''
fi

section() {
    echo ""
    echo -e "${CYAN}══ $* ══${NC}"
}

pass() {
    PASS=$((PASS + 1))
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${GREEN}  ✓ PASS${NC} — $*"
    else
        echo -e "${GREEN}  ✓ PASS${NC} — $*"
    fi
}

fail() {
    FAIL=$((FAIL + 1))
    echo -e "${RED}  ✗ FAIL${NC} — $*"
}

warn() {
    WARN=$((WARN + 1))
    echo -e "${YELLOW}  ⚠ WARN${NC} — $*"
}

info() {
    if [ "$VERBOSE" = "true" ]; then
        echo "         $*"
    fi
}

# ── Validation Functions ───────────────────────────────────────────────────────

check_file_exists() {
    local path="$1"
    local desc="$2"
    if [ -f "$REPO_DIR/$path" ]; then
        pass "$desc exists"
        return 0
    else
        fail "$desc missing: $path"
        return 1
    fi
}

check_file_contains() {
    local path="$1"
    local pattern="$2"
    local desc="$3"
    local full_path="$REPO_DIR/$path"

    if [ ! -f "$full_path" ]; then
        fail "$desc — file missing: $path"
        return 1
    fi

    if grep -q "$pattern" "$full_path" 2>/dev/null; then
        pass "$desc"
        info "Found: $(grep -m1 "$pattern" "$full_path" | sed 's/^[[:space:]]*//')"
        return 0
    else
        fail "$desc — pattern not found in $path"
        info "Looking for: $pattern"
        return 1
    fi
}

check_file_not_contains() {
    local path="$1"
    local pattern="$2"
    local desc="$3"
    local full_path="$REPO_DIR/$path"

    if [ ! -f "$full_path" ]; then
        warn "$desc — file missing (can't check): $path"
        return 0
    fi

    if ! grep -qE "$pattern" "$full_path" 2>/dev/null; then
        pass "$desc"
        return 0
    else
        fail "$desc — found prohibited pattern in $path"
        info "Found: $(grep -mE1 "$pattern" "$full_path" | head -3 | sed 's/^[[:space:]]*//')"
        return 1
    fi
}

# ── START ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    Phase 1 Validation — openclaw-config Enhanced Fork ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo "Repo: $REPO_DIR"

# ── SECTION 1: Fork Identity Files ────────────────────────────────────────────
section "Fork Identity Files"

check_file_exists "README.md" "README.md"
check_file_contains "README.md" "Enhanced Fork" "README.md identifies as Enhanced Fork"
check_file_contains "README.md" "TechNickAI" "README.md credits upstream"
check_file_contains "README.md" "unisone" "README.md credits unisone community repo"
check_file_contains "README.md" "digitalknk" "README.md credits digitalknk community repo"

check_file_exists "CONTRIBUTING.md" "CONTRIBUTING.md"
check_file_contains "CONTRIBUTING.md" "develop" "CONTRIBUTING.md documents branch strategy"
check_file_contains "CONTRIBUTING.md" "uv run" "CONTRIBUTING.md documents UV script conventions"

check_file_exists "CHANGELOG.md" "CHANGELOG.md"
check_file_contains "CHANGELOG.md" "2.0.0-alpha" "CHANGELOG.md has v2.0.0-alpha entry"
check_file_contains "CHANGELOG.md" "ThrottleInterval" "CHANGELOG.md documents ThrottleInterval fix"

check_file_exists "MIGRATION.md" "MIGRATION.md"
check_file_contains "MIGRATION.md" "ThrottleInterval" "MIGRATION.md covers ThrottleInterval fix"
check_file_contains "MIGRATION.md" ".env" "MIGRATION.md covers .env secret migration"

check_file_exists "GAP_CLOSING_PLAN.md" "GAP_CLOSING_PLAN.md"
check_file_exists "ATLAS4_REVIEW.md" "ATLAS4_REVIEW.md"

# ── SECTION 2a: ThrottleInterval Fix (macOS) ───────────────────────────────────
section "ThrottleInterval Fix (Issue #4632)"

HEALTH_PLIST="devops/mac/ai.openclaw.health-check.plist"
if check_file_exists "$HEALTH_PLIST" "macOS health-check.plist"; then
    check_file_contains "$HEALTH_PLIST" "<key>ThrottleInterval</key>" \
        "health-check.plist has ThrottleInterval key"
    check_file_contains "$HEALTH_PLIST" "<integer>5</integer>" \
        "health-check.plist ThrottleInterval = 5"
fi

BACKUP_PLIST="devops/mac/ai.openclaw.workspace-backup.plist"
if check_file_exists "$BACKUP_PLIST" "macOS workspace-backup.plist"; then
    check_file_contains "$BACKUP_PLIST" "<key>ThrottleInterval</key>" \
        "workspace-backup.plist has ThrottleInterval key"
    check_file_contains "$BACKUP_PLIST" "<integer>5</integer>" \
        "workspace-backup.plist ThrottleInterval = 5"
fi

GATEWAY_SERVICE="devops/linux/openclaw-gateway.service"
if check_file_exists "$GATEWAY_SERVICE" "Linux openclaw-gateway.service"; then
    check_file_contains "$GATEWAY_SERVICE" "RestartSec=5" \
        "gateway.service has RestartSec=5"
    check_file_contains "$GATEWAY_SERVICE" "StartLimitIntervalSec=0" \
        "gateway.service has StartLimitIntervalSec=0"
    check_file_contains "$GATEWAY_SERVICE" "WatchdogSec=60" \
        "gateway.service has WatchdogSec=60"
    check_file_contains "$GATEWAY_SERVICE" "Restart=on-failure" \
        "gateway.service has Restart=on-failure"
fi

# ── SECTION 2c: Health Check Interval ─────────────────────────────────────────
section "Health Check Interval (30min → 5min)"

if [ -f "$REPO_DIR/$HEALTH_PLIST" ]; then
    # Check that StartInterval is 300 (5 min) not 1800 (30 min)
    if grep -q "<integer>300</integer>" "$REPO_DIR/$HEALTH_PLIST"; then
        # Make sure there's a StartInterval context around it
        if grep -B2 "<integer>300</integer>" "$REPO_DIR/$HEALTH_PLIST" | grep -q "StartInterval"; then
            pass "health-check.plist StartInterval = 300 (5 min)"
        else
            warn "health-check.plist has 300 but context unclear — verify StartInterval manually"
        fi
    else
        fail "health-check.plist StartInterval should be 300 (5 min)"
    fi

    if grep -q "<integer>1800</integer>" "$REPO_DIR/$HEALTH_PLIST"; then
        fail "health-check.plist still has old 1800s (30 min) interval"
    else
        pass "health-check.plist does not have old 1800s interval"
    fi
fi

HEALTH_TIMER="devops/linux/openclaw-health-check.timer"
if check_file_exists "$HEALTH_TIMER" "Linux health-check.timer"; then
    check_file_contains "$HEALTH_TIMER" "OnUnitActiveSec=5min" \
        "health-check.timer interval = 5min"
    check_file_not_contains "$HEALTH_TIMER" "OnUnitActiveSec=30min" \
        "health-check.timer not using old 30min interval"
fi

# ── SECTION 2d: Backup Interval ───────────────────────────────────────────────
section "Backup Interval (4h → 2h)"

if [ -f "$REPO_DIR/$BACKUP_PLIST" ]; then
    if grep -q "<integer>7200</integer>" "$REPO_DIR/$BACKUP_PLIST"; then
        pass "workspace-backup.plist StartInterval = 7200 (2h)"
    else
        fail "workspace-backup.plist StartInterval should be 7200 (2h)"
    fi

    if grep -q "<integer>14400</integer>" "$REPO_DIR/$BACKUP_PLIST"; then
        fail "workspace-backup.plist still has old 14400s (4h) interval"
    else
        pass "workspace-backup.plist does not have old 14400s interval"
    fi
fi

BACKUP_TIMER="devops/linux/openclaw-workspace-backup.timer"
if check_file_exists "$BACKUP_TIMER" "Linux workspace-backup.timer"; then
    check_file_contains "$BACKUP_TIMER" "OnUnitActiveSec=2h" \
        "workspace-backup.timer interval = 2h"
    check_file_not_contains "$BACKUP_TIMER" "OnUnitActiveSec=4h" \
        "workspace-backup.timer not using old 4h interval"
fi

# ── SECTION 2b: .env-Only Secrets ─────────────────────────────────────────────
section ".env-Only Secrets Documentation (Issues #9627, #11202)"

check_file_contains "templates/TOOLS.md" "\.env" \
    "TOOLS.md documents .env-only secrets"
check_file_contains "templates/TOOLS.md" "chmod 600" \
    "TOOLS.md documents .env permissions"
check_file_contains "devops/security-baseline.md" "\.env" \
    "security-baseline.md documents .env requirement"
check_file_contains "devops/security-baseline.md" "#9627\|issue #9627\|issues #9627" \
    "security-baseline.md references issue #9627"

# Check that template files don't contain raw API key patterns
check_file_not_contains "templates/TOOLS.md" "sk-ant-\|sk-[a-z]" \
    "TOOLS.md has no hardcoded API keys"
check_file_not_contains "templates/AGENTS.md" "sk-ant-\|sk-[a-z]" \
    "AGENTS.md has no hardcoded API keys"

# ── SECTION 3: Security Baseline ──────────────────────────────────────────────
section "Security Baseline"

BASELINE="devops/security-baseline.md"
if check_file_exists "$BASELINE" "devops/security-baseline.md"; then
    check_file_contains "$BASELINE" "loopback" \
        "security-baseline.md requires gateway bind loopback"
    check_file_contains "$BASELINE" "chmod 600" \
        "security-baseline.md requires .env chmod 600"
    check_file_contains "$BASELINE" "devices list\|devices remove" \
        "security-baseline.md has device pairing hygiene"
    check_file_contains "$BASELINE" 'deny.*exec\|exec.*deny' \
        "security-baseline.md has tool deny policy"
    check_file_contains "$BASELINE" "redactSensitive" \
        "security-baseline.md recommends logging.redactSensitive"
fi

check_file_contains "templates/AGENTS.md" "RBAC\|Role-Based" \
    "AGENTS.md has RBAC section"
check_file_contains "templates/AGENTS.md" "Prompt Injection" \
    "AGENTS.md has prompt injection defense"
check_file_contains "templates/AGENTS.md" "deny.*exec\|exec.*deny\|deny.*cron" \
    "AGENTS.md has tool policy defaults"

# ── SECTION 4: Session Management Scripts ─────────────────────────────────────
section "Session Management Scripts"

check_file_exists "scripts/session-management/README.md" "session-management README.md"
check_file_exists "scripts/session-management/session-watchdog.sh" "session-watchdog.sh"
check_file_exists "scripts/session-management/session-metrics.sh" "session-metrics.sh"
check_file_exists "scripts/session-management/session-cleanup.sh" "session-cleanup.sh"

# Check scripts are executable (or at least not empty)
for script in session-watchdog.sh session-metrics.sh session-cleanup.sh; do
    SCRIPT_PATH="$REPO_DIR/scripts/session-management/$script"
    if [ -f "$SCRIPT_PATH" ] && [ -s "$SCRIPT_PATH" ]; then
        if head -1 "$SCRIPT_PATH" | grep -q "#!/"; then
            pass "$script has shebang line"
        else
            warn "$script missing shebang line"
        fi
        if grep -q "set -" "$SCRIPT_PATH"; then
            pass "$script has error handling (set -...)"
        else
            warn "$script missing 'set -euo pipefail' or equivalent"
        fi
    fi
done

# ── SECTION 5: Tests ──────────────────────────────────────────────────────────
section "Test Infrastructure"

check_file_exists "tests/phase1-validation.sh" "tests/phase1-validation.sh (this script)"

# ── SUMMARY ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}══ Summary ══${NC}"
echo -e "  ${GREEN}✓ Passed: $PASS${NC}"
echo -e "  ${RED}✗ Failed: $FAIL${NC}"
if [ "$WARN" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ Warnings: $WARN${NC}"
fi
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}All Phase 1 checks passed! ✓${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}$FAIL check(s) failed. Review the FAIL lines above and apply the relevant fixes.${NC}"
    echo ""
    echo "See MIGRATION.md for fix instructions."
    echo ""
    exit 1
fi
