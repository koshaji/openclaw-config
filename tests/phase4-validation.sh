#!/usr/bin/env bash
# Phase 4 Validation Tests
# Verifies all Phase 4 deliverables are in place and non-stub.
#
# Usage:
#   cd openclaw-config
#   ./tests/phase4-validation.sh
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
ERRORS=()

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    FAIL=$((FAIL + 1))
    ERRORS+=("$1")
}

warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

section() {
    echo ""
    echo "── $1 ──"
}

min_lines() {
    local file="$1"
    local min="$2"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    local count
    count=$(wc -l < "$file")
    [[ "$count" -ge "$min" ]]
}

contains() {
    local file="$1"
    local pattern="$2"
    grep -q "$pattern" "$file" 2>/dev/null
}

# ---------------------------------------------------------------------------
section "Task 1: Fleet MCP Server"
# ---------------------------------------------------------------------------

MCP_SKILL="$REPO_ROOT/skills/fleet-mcp-server/SKILL.md"
MCP_SCRIPT="$REPO_ROOT/skills/fleet-mcp-server/fleet-mcp-server"

if [[ -f "$MCP_SKILL" ]]; then
    pass "fleet-mcp-server/SKILL.md exists"
else
    fail "fleet-mcp-server/SKILL.md is missing"
fi

if min_lines "$MCP_SKILL" 100; then
    pass "fleet-mcp-server/SKILL.md is non-stub (≥100 lines)"
else
    fail "fleet-mcp-server/SKILL.md looks like a stub (<100 lines)"
fi

if [[ -f "$MCP_SCRIPT" ]]; then
    pass "fleet-mcp-server script exists"
else
    fail "fleet-mcp-server script is missing"
fi

if [[ -x "$MCP_SCRIPT" ]]; then
    pass "fleet-mcp-server script is executable"
else
    fail "fleet-mcp-server script is not executable (chmod +x)"
fi

# Check for MCP tool names (defined as tool_<name>() or referenced as string "fleet_<name>")
for tool in fleet_status fleet_health_check fleet_restart fleet_update fleet_config_push fleet_logs; do
    short="${tool#fleet_}"
    if grep -qE "def (tool_)?${tool}|\"${tool}\"|'${tool}'" "$MCP_SCRIPT" 2>/dev/null; then
        pass "MCP tool defined: $tool"
    else
        fail "MCP tool missing: $tool"
    fi
done

# Check for @server.list_tools or @server.call_tool
if contains "$MCP_SCRIPT" "@server.list_tools\|@server.call_tool"; then
    pass "MCP server decorators present"
else
    fail "MCP server decorators missing (@server.list_tools / @server.call_tool)"
fi

# Check for HMAC signing
if contains "$MCP_SCRIPT" "hmac\|HMAC"; then
    pass "HMAC signing present in fleet-mcp-server"
else
    fail "HMAC signing missing from fleet-mcp-server"
fi

# Check for audit logging
if contains "$MCP_SCRIPT" "audit\|AUDIT"; then
    pass "Audit logging present in fleet-mcp-server"
else
    fail "Audit logging missing from fleet-mcp-server"
fi

# Check for SSE/stdio transport support
if contains "$MCP_SCRIPT" "stdio\|sse\|SSE"; then
    pass "Transport mode support present (stdio/SSE)"
else
    fail "Transport mode support missing"
fi

# ---------------------------------------------------------------------------
section "Task 1b: Fleet Inventory Template"
# ---------------------------------------------------------------------------

INVENTORY="$HOME/.openclaw/fleet/inventory.json"
if [[ -f "$INVENTORY" ]]; then
    pass "~/.openclaw/fleet/inventory.json exists"
    if python3 -c "import json,sys; json.load(open('$INVENTORY'))" 2>/dev/null; then
        pass "inventory.json is valid JSON"
    else
        fail "inventory.json is invalid JSON"
    fi
    if contains "$INVENTORY" '"machines"'; then
        pass "inventory.json has 'machines' key"
    else
        fail "inventory.json missing 'machines' key"
    fi
else
    fail "~/.openclaw/fleet/inventory.json is missing"
fi

# ---------------------------------------------------------------------------
section "Task 2: NL Fleet Commander"
# ---------------------------------------------------------------------------

FC_AGENT="$REPO_ROOT/workflows/fleet-commander/AGENT.md"
FC_ROUTING="$REPO_ROOT/workflows/fleet-commander/routing-rules.md"
FC_PATTERNS="$REPO_ROOT/workflows/fleet-commander/patterns.json"

if [[ -f "$FC_AGENT" ]]; then
    pass "fleet-commander/AGENT.md exists"
else
    fail "fleet-commander/AGENT.md is missing"
fi

if min_lines "$FC_AGENT" 100; then
    pass "fleet-commander/AGENT.md is non-stub (≥100 lines)"
else
    fail "fleet-commander/AGENT.md looks like a stub (<100 lines)"
fi

if contains "$FC_AGENT" "learning\|Learning"; then
    pass "AGENT.md references learning loop"
else
    fail "AGENT.md missing learning loop documentation"
fi

if contains "$FC_AGENT" "fleet_health_check\|fleet_status\|fleet_restart"; then
    pass "AGENT.md references fleet MCP tools"
else
    fail "AGENT.md missing fleet MCP tool references"
fi

if [[ -f "$FC_ROUTING" ]]; then
    pass "fleet-commander/routing-rules.md exists"
else
    fail "fleet-commander/routing-rules.md is missing"
fi

if min_lines "$FC_ROUTING" 50; then
    pass "routing-rules.md is non-stub (≥50 lines)"
else
    fail "routing-rules.md looks like a stub (<50 lines)"
fi

# Check routing rules content
for intent in "fleet_health_check\|health_check" "fleet_status\|fleet status" "fleet_restart\|restart" "fleet_logs\|show logs"; do
    if grep -q "$intent" "$FC_ROUTING" 2>/dev/null; then
        pass "routing-rules.md has mapping for: ${intent%%\\*}"
    else
        fail "routing-rules.md missing mapping for: ${intent%%\\*}"
    fi
done

if [[ -f "$FC_PATTERNS" ]]; then
    pass "fleet-commander/patterns.json exists"
    if python3 -c "import json,sys; json.load(open('$FC_PATTERNS'))" 2>/dev/null; then
        pass "patterns.json is valid JSON"
    else
        fail "patterns.json is invalid JSON"
    fi
else
    fail "fleet-commander/patterns.json is missing"
fi

# ---------------------------------------------------------------------------
section "Task 3: Fleet Command NL Mode"
# ---------------------------------------------------------------------------

FLEET_CMD="$REPO_ROOT/.claude/commands/fleet.md"

if [[ -f "$FLEET_CMD" ]]; then
    pass ".claude/commands/fleet.md exists"
else
    fail ".claude/commands/fleet.md is missing"
fi

if contains "$FLEET_CMD" "Natural Language\|natural language\|NL mode"; then
    pass "fleet.md has NL mode section"
else
    fail "fleet.md missing NL mode section"
fi

if contains "$FLEET_CMD" "\-\-no-ssh\|no-ssh"; then
    pass "fleet.md has --no-ssh documentation"
else
    fail "fleet.md missing --no-ssh documentation"
fi

if contains "$FLEET_CMD" "fleet-commander\|fleet_health_check"; then
    pass "fleet.md references fleet-commander workflow"
else
    fail "fleet.md missing fleet-commander workflow reference"
fi

# ---------------------------------------------------------------------------
section "Task 4: Ruflo Integration Guide"
# ---------------------------------------------------------------------------

RUFLO="$REPO_ROOT/docs/RUFLO_SETUP.md"

if [[ -f "$RUFLO" ]]; then
    pass "docs/RUFLO_SETUP.md exists"
else
    fail "docs/RUFLO_SETUP.md is missing"
fi

if min_lines "$RUFLO" 100; then
    pass "RUFLO_SETUP.md is non-stub (≥100 lines)"
else
    fail "RUFLO_SETUP.md looks like a stub (<100 lines)"
fi

for keyword in "queen\|worker\|swarm" "Docker\|docker" "MCP\|mcp" "fleet-commander\|Fleet Commander" "installation\|Installation"; do
    if grep -q "$keyword" "$RUFLO" 2>/dev/null; then
        pass "RUFLO_SETUP.md covers: ${keyword%%\\*}"
    else
        fail "RUFLO_SETUP.md missing section on: ${keyword%%\\*}"
    fi
done

# ---------------------------------------------------------------------------
section "Task 5: OPA Guide"
# ---------------------------------------------------------------------------

OPA="$REPO_ROOT/docs/OPA_SETUP.md"

if [[ -f "$OPA" ]]; then
    pass "docs/OPA_SETUP.md exists"
else
    fail "docs/OPA_SETUP.md is missing"
fi

if min_lines "$OPA" 100; then
    pass "OPA_SETUP.md is non-stub (≥100 lines)"
else
    fail "OPA_SETUP.md looks like a stub (<100 lines)"
fi

for keyword in "Rego\|rego" "Casbin\|casbin" "Docker\|docker" "migration\|Migration" "sidecar\|alongside"; do
    if grep -q "$keyword" "$OPA" 2>/dev/null; then
        pass "OPA_SETUP.md covers: ${keyword%%\\*}"
    else
        fail "OPA_SETUP.md missing section on: ${keyword%%\\*}"
    fi
done

# ---------------------------------------------------------------------------
section "Task 6: Agent Swarm Orchestration"
# ---------------------------------------------------------------------------

SWARM_AGENT="$REPO_ROOT/workflows/agent-swarm/AGENT.md"
SWARM_MATRIX="$REPO_ROOT/workflows/agent-swarm/routing-matrix.md"
SWARM_LOG="$REPO_ROOT/workflows/agent-swarm/learning-log.json"

if [[ -f "$SWARM_AGENT" ]]; then
    pass "workflows/agent-swarm/AGENT.md exists"
else
    fail "workflows/agent-swarm/AGENT.md is missing"
fi

if min_lines "$SWARM_AGENT" 100; then
    pass "agent-swarm/AGENT.md is non-stub (≥100 lines)"
else
    fail "agent-swarm/AGENT.md looks like a stub (<100 lines)"
fi

for keyword in "learning\|Learning" "respawn\|Respawn\|health" "parallel\|Parallel" "aggregat\|Aggregat" "quality\|Quality"; do
    if grep -q "$keyword" "$SWARM_AGENT" 2>/dev/null; then
        pass "AGENT.md covers: ${keyword%%\\*}"
    else
        fail "AGENT.md missing: ${keyword%%\\*}"
    fi
done

if [[ -f "$SWARM_MATRIX" ]]; then
    pass "workflows/agent-swarm/routing-matrix.md exists"
else
    fail "workflows/agent-swarm/routing-matrix.md is missing"
fi

if min_lines "$SWARM_MATRIX" 30; then
    pass "routing-matrix.md is non-stub (≥30 lines)"
else
    fail "routing-matrix.md looks like a stub (<30 lines)"
fi

# Check routing matrix has expected task types
for task_type in "Code generation\|code generation" "Code review\|code review" "Security audit\|security audit" "Research\|research" "Documentation\|documentation" "Testing\|testing"; do
    if grep -qi "${task_type%%\\*}" "$SWARM_MATRIX" 2>/dev/null; then
        pass "routing-matrix.md has entry for: ${task_type%%\\*}"
    else
        fail "routing-matrix.md missing entry for: ${task_type%%\\*}"
    fi
done

if [[ -f "$SWARM_LOG" ]]; then
    pass "workflows/agent-swarm/learning-log.json exists"
    if python3 -c "import json,sys; json.load(open('$SWARM_LOG'))" 2>/dev/null; then
        pass "learning-log.json is valid JSON"
    else
        fail "learning-log.json is invalid JSON"
    fi
else
    fail "workflows/agent-swarm/learning-log.json is missing"
fi

# ---------------------------------------------------------------------------
echo ""
echo "══════════════════════════════════════════════"
echo " Phase 4 Validation Results"
echo "══════════════════════════════════════════════"
echo -e " ${GREEN}Passed:${NC} $PASS"
echo -e " ${RED}Failed:${NC} $FAIL"
echo ""

if [[ "${#ERRORS[@]}" -gt 0 ]]; then
    echo "Failures:"
    for err in "${ERRORS[@]}"; do
        echo -e "  ${RED}✗${NC} $err"
    done
    echo ""
fi

if [[ "$FAIL" -eq 0 ]]; then
    echo -e "${GREEN}All Phase 4 tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}$FAIL test(s) failed. Fix the issues above and re-run.${NC}"
    exit 1
fi
