#!/usr/bin/env bash
# phase3-validation.sh — Phase 3 Enterprise RBAC, Multi-User, SSO, Compliance
#
# Tests:
#   1. Casbin model.conf and policy.csv.template exist and are valid
#   2. RBAC role hierarchy (Owner has all perms, Observer only has audit_read)
#   3. user-router handles known and unknown identities
#   4. audit-export --verify with hash chain
#   5. All Phase 3 docs are non-stub (>100 lines each)
#   6. check-auth in allowlist fallback mode
#   7. check-auth in Casbin mode (with temp policy files)
#
# Usage:
#   bash tests/phase3-validation.sh
#   bash tests/phase3-validation.sh --verbose

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
SKIP=0
VERBOSE="${1:-}"

# ── Helpers ────────────────────────────────────────────────────────────────

green() { echo -e "\033[32m$*\033[0m"; }
red()   { echo -e "\033[31m$*\033[0m"; }
yellow(){ echo -e "\033[33m$*\033[0m"; }
bold()  { echo -e "\033[1m$*\033[0m"; }

pass() {
    PASS=$((PASS + 1))
    green "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    red "  ✗ $1"
    if [[ -n "${2:-}" ]]; then
        echo "    $2"
    fi
}

skip() {
    SKIP=$((SKIP + 1))
    yellow "  ⊘ $1 (skipped: $2)"
}

section() {
    echo ""
    bold "── $1 ──"
}

assert_file_exists() {
    local file="$1"
    local desc="${2:-$file}"
    if [[ -f "$file" ]]; then
        pass "$desc exists"
    else
        fail "$desc missing" "Expected: $file"
    fi
}

assert_file_min_lines() {
    local file="$1"
    local min_lines="$2"
    local desc="${3:-$file}"
    if [[ ! -f "$file" ]]; then
        fail "$desc missing"
        return
    fi
    local count
    count=$(wc -l < "$file")
    if [[ "$count" -ge "$min_lines" ]]; then
        pass "$desc has $count lines (≥ $min_lines)"
    else
        fail "$desc too short: $count lines (expected ≥ $min_lines)" \
             "This file may still be a stub."
    fi
}

assert_file_not_stub() {
    local file="$1"
    local desc="${2:-$file}"
    assert_file_min_lines "$file" 100 "$desc"
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local desc="${3:-contains '$pattern'}"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        pass "$file $desc"
    else
        fail "$file does not contain '$pattern'"
    fi
}

# ── Runtime detection ──────────────────────────────────────────────────────
# uv is the preferred runtime for OpenClaw UV scripts.
# In CI/test environments without uv, we fall back to python3 (strips UV metadata).

HAS_UV=0
if command -v uv &>/dev/null; then
    HAS_UV=1
fi

HAS_CASBIN=0
if python3 -c "import casbin" 2>/dev/null; then
    HAS_CASBIN=1
fi

# run_script: execute a UV script, falling back to python3 in environments without uv
run_script() {
    local script="$1"
    shift
    if [[ $HAS_UV -eq 1 ]]; then
        HOME="$TEST_HOME" "$script" "$@"
    else
        # Strip shebang + UV inline metadata, run directly with python3
        HOME="$TEST_HOME" python3 <(grep -v '^#!/' "$script" | grep -v '^# ///' | grep -v '^# requires-python' | grep -v '^# dep') "$@"
    fi
}

# ── Temporary workspace ────────────────────────────────────────────────────

TMPDIR="$(mktemp -d)"
trap "rm -rf $TMPDIR" EXIT

# Override HOME for testing so we don't pollute real ~/.openclaw
export TEST_HOME="$TMPDIR/home"
mkdir -p "$TEST_HOME/.openclaw/audit"
mkdir -p "$TEST_HOME/.openclaw/rbac"
mkdir -p "$TEST_HOME/.openclaw/workspace/USERS"

# ══════════════════════════════════════════════════════════════════════════
# 1. Casbin policy files exist and are valid
# ══════════════════════════════════════════════════════════════════════════

section "1. Casbin RBAC Policy Files"

assert_file_exists \
    "$REPO_ROOT/skills/rbac/policy/model.conf" \
    "skills/rbac/policy/model.conf"

assert_file_exists \
    "$REPO_ROOT/skills/rbac/policy/policy.csv.template" \
    "skills/rbac/policy/policy.csv.template"

# Validate model.conf structure
MODEL="$REPO_ROOT/skills/rbac/policy/model.conf"
for section_name in "request_definition" "policy_definition" "role_definition" "policy_effect" "matchers"; do
    if grep -q "\[$section_name\]" "$MODEL"; then
        pass "model.conf has [$section_name] section"
    else
        fail "model.conf missing [$section_name] section"
    fi
done

# Validate policy.csv.template has expected roles
POLICY_TPL="$REPO_ROOT/skills/rbac/policy/policy.csv.template"
for role in "owner" "admin" "operator" "observer"; do
    if grep -q "^p, $role," "$POLICY_TPL"; then
        pass "policy.csv.template has '$role' role"
    else
        fail "policy.csv.template missing '$role' role"
    fi
done

# Owner should have wildcard
if grep -q "^p, owner, \*, \*" "$POLICY_TPL"; then
    pass "policy.csv.template: owner has wildcard (*,*)"
else
    fail "policy.csv.template: owner missing wildcard (*,*)"
fi

# Observer should NOT have skill_exec
if grep -q "^p, observer, skill_exec" "$POLICY_TPL"; then
    fail "policy.csv.template: observer incorrectly has skill_exec"
else
    pass "policy.csv.template: observer has no skill_exec (correct)"
fi

# ══════════════════════════════════════════════════════════════════════════
# 2. RBAC role hierarchy via check-auth (allowlist fallback mode)
# ══════════════════════════════════════════════════════════════════════════

section "2. check-auth — Allowlist Fallback Mode"

CHECK_AUTH="$REPO_ROOT/skills/rbac/check-auth"
assert_file_exists "$CHECK_AUTH" "skills/rbac/check-auth"

# No allowlist file → everyone gets PERMIT
RESULT=$(run_script "$CHECK_AUTH" "telegram:999999999" 2>/dev/null || true)
if [[ "$RESULT" == "PERMIT" ]]; then
    pass "check-auth: no allowlist → PERMIT (opt-in security)"
else
    fail "check-auth: no allowlist should return PERMIT, got: $RESULT"
fi

# With allowlist file — authorized user → PERMIT
echo "telegram:833846354" > "$TEST_HOME/.openclaw/authorized-users"
RESULT=$(run_script "$CHECK_AUTH" "telegram:833846354" 2>/dev/null || true)
if [[ "$RESULT" == "PERMIT" ]]; then
    pass "check-auth: allowlist — authorized user → PERMIT"
else
    fail "check-auth: allowlist — authorized user should get PERMIT, got: $RESULT"
fi

# Unauthorized user → DENY
RESULT=$(run_script "$CHECK_AUTH" "telegram:000000000" 2>/dev/null || true)
if [[ "$RESULT" == "DENY" ]]; then
    pass "check-auth: allowlist — unauthorized user → DENY"
else
    fail "check-auth: allowlist — unauthorized user should get DENY, got: $RESULT"
fi

# ══════════════════════════════════════════════════════════════════════════
# 3. check-auth — Casbin RBAC mode
# ══════════════════════════════════════════════════════════════════════════

section "3. check-auth — Casbin RBAC Mode"

# Set up Casbin files in temp home
cp "$REPO_ROOT/skills/rbac/policy/model.conf" \
   "$TEST_HOME/.openclaw/rbac/model.conf"

cat > "$TEST_HOME/.openclaw/rbac/policy.csv" << 'POLICY'
p, owner, *, *
p, admin, skill_exec, *
p, admin, audit_read, *
p, operator, skill_exec, *
p, operator, audit_read, *
p, observer, audit_read, *

g, telegram:833846354, owner
g, telegram:111111111, operator
g, telegram:222222222, observer
POLICY

if [[ $HAS_CASBIN -eq 0 ]]; then
    for msg in \
        "Casbin: owner → skill_exec → PERMIT" \
        "Casbin: owner → secret_access → PERMIT" \
        "Casbin: observer → audit_read → PERMIT" \
        "Casbin: observer → skill_exec → DENY" \
        "Casbin: observer → secret_access → DENY" \
        "Casbin: unknown identity → DENY"; do
        skip "$msg" "pycasbin not installed in this environment"
    done
else
    # Owner should get PERMIT for all resources
    RESULT=$(run_script "$CHECK_AUTH" "telegram:833846354" skill_exec 2>/dev/null || true)
    if [[ "$RESULT" == "PERMIT" ]]; then
        pass "Casbin: owner → skill_exec → PERMIT"
    else
        fail "Casbin: owner should get PERMIT for skill_exec, got: $RESULT"
    fi

    RESULT=$(run_script "$CHECK_AUTH" "telegram:833846354" secret_access 2>/dev/null || true)
    if [[ "$RESULT" == "PERMIT" ]]; then
        pass "Casbin: owner → secret_access → PERMIT"
    else
        fail "Casbin: owner should get PERMIT for secret_access, got: $RESULT"
    fi

    # Observer should ONLY get PERMIT for audit_read
    RESULT=$(run_script "$CHECK_AUTH" "telegram:222222222" audit_read 2>/dev/null || true)
    if [[ "$RESULT" == "PERMIT" ]]; then
        pass "Casbin: observer → audit_read → PERMIT"
    else
        fail "Casbin: observer should get PERMIT for audit_read, got: $RESULT"
    fi

    RESULT=$(run_script "$CHECK_AUTH" "telegram:222222222" skill_exec 2>/dev/null || true)
    if [[ "$RESULT" == "DENY" ]]; then
        pass "Casbin: observer → skill_exec → DENY (correct)"
    else
        fail "Casbin: observer should get DENY for skill_exec, got: $RESULT"
    fi

    RESULT=$(run_script "$CHECK_AUTH" "telegram:222222222" secret_access 2>/dev/null || true)
    if [[ "$RESULT" == "DENY" ]]; then
        pass "Casbin: observer → secret_access → DENY (correct)"
    else
        fail "Casbin: observer should get DENY for secret_access, got: $RESULT"
    fi

    # Unknown identity → DENY
    RESULT=$(run_script "$CHECK_AUTH" "telegram:999999999" skill_exec 2>/dev/null || true)
    if [[ "$RESULT" == "DENY" ]]; then
        pass "Casbin: unknown identity → DENY"
    else
        fail "Casbin: unknown identity should get DENY, got: $RESULT"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════
# 4. user-router — known and unknown identities
# ══════════════════════════════════════════════════════════════════════════

section "4. user-router — Identity Resolution"

USER_ROUTER="$REPO_ROOT/skills/user-router/user-router"
assert_file_exists "$USER_ROUTER" "skills/user-router/user-router"

# Create a test user profile
cat > "$TEST_HOME/.openclaw/workspace/USERS/telegram-833846354.md" << 'PROFILE'
# Hani

## Identity
- **Name:** Hani
- **Role:** owner
- **Timezone:** Australia/Melbourne
- **Language:** en

## Identities
- telegram:833846354

## Preferences
- **Communication style:** concise
PROFILE

# Test known identity
CONTEXT=$(run_script "$USER_ROUTER" "telegram:833846354" 2>/dev/null || echo '{}')

if echo "$CONTEXT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['found']==True" 2>/dev/null; then
    pass "user-router: known identity → found=true"
else
    fail "user-router: known identity should have found=true"
fi

if echo "$CONTEXT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['role']=='owner'" 2>/dev/null; then
    pass "user-router: known identity → role=owner"
else
    fail "user-router: known identity should have role=owner"
fi

NAME=$(echo "$CONTEXT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null || echo "")
if [[ "$NAME" == "Hani" ]]; then
    pass "user-router: known identity → name=Hani"
else
    fail "user-router: known identity should have name=Hani, got: $NAME"
fi

# Test unknown identity — should return guest profile
GUEST=$(run_script "$USER_ROUTER" "telegram:999999999" 2>/dev/null || echo '{}')

if echo "$GUEST" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['found']==False" 2>/dev/null; then
    pass "user-router: unknown identity → found=false (guest)"
else
    fail "user-router: unknown identity should have found=false"
fi

if echo "$GUEST" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['role']=='observer'" 2>/dev/null; then
    pass "user-router: unknown identity → role=observer (guest default)"
else
    fail "user-router: unknown identity should have role=observer"
fi

# Test multi-platform identity (discord)
DISCORD_CTX=$(run_script "$USER_ROUTER" "discord:987654321" 2>/dev/null || echo '{}')
if echo "$DISCORD_CTX" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['found']==False" 2>/dev/null; then
    pass "user-router: discord identity → guest profile returned"
else
    fail "user-router: discord identity should return guest profile"
fi

# ══════════════════════════════════════════════════════════════════════════
# 5. audit-export hash chain
# ══════════════════════════════════════════════════════════════════════════

section "5. audit-export — Hash Chain Integrity"

AUDIT_EXPORT="$REPO_ROOT/skills/audit-export/audit-export"
assert_file_exists "$AUDIT_EXPORT" "skills/audit-export/audit-export"

# Check --verify flag is present in source
if grep -q "\-\-verify" "$AUDIT_EXPORT"; then
    pass "audit-export: --verify flag implemented"
else
    fail "audit-export: --verify flag missing from source"
fi

# Check hash chain fields in source
if grep -q "prev_hash" "$AUDIT_EXPORT"; then
    pass "audit-export: prev_hash field implemented"
else
    fail "audit-export: prev_hash field missing"
fi

if grep -q "compute_entry_hash" "$AUDIT_EXPORT"; then
    pass "audit-export: compute_entry_hash function present"
else
    fail "audit-export: compute_entry_hash function missing"
fi

# Check --export-s3 and --export-syslog are present
if grep -q "\-\-export-s3" "$AUDIT_EXPORT"; then
    pass "audit-export: --export-s3 flag implemented"
else
    fail "audit-export: --export-s3 flag missing"
fi

if grep -q "\-\-export-syslog" "$AUDIT_EXPORT"; then
    pass "audit-export: --export-syslog flag implemented"
else
    fail "audit-export: --export-syslog flag missing"
fi

# Create a test audit file with hash chain
TODAY=$(date +%Y-%m-%d)
TEST_AUDIT_FILE="$TEST_HOME/.openclaw/audit/${TODAY}.jsonl"

# Write test entries with hash chain (using Python to compute hashes)
python3 << PYEOF
import json, hashlib, time

def entry_content_for_hash(entry):
    content = {k: v for k, v in entry.items() if k not in ('hash', 'prev_hash')}
    return json.dumps(content, sort_keys=True, separators=(',', ':'))

def compute_hash(entry, prev_hash):
    content = entry_content_for_hash(entry) + prev_hash
    return 'sha256:' + hashlib.sha256(content.encode()).hexdigest()

prev_hash = 'genesis'
entries = []
for i in range(5):
    entry = {
        'ts': int(time.time()) + i,
        'agent': 'test-agent',
        'sender': 'telegram:833846354',
        'action': 'auth_check',
        'resource': 'skill_exec',
        'args': 'telegram:833846354 skill_exec *',
        'result': 'PERMIT',
        'reason': 'test entry',
    }
    entry['prev_hash'] = prev_hash
    h = compute_hash(entry, prev_hash)
    entry['hash'] = h
    prev_hash = h
    entries.append(entry)

with open('${TEST_AUDIT_FILE}', 'w') as f:
    for e in entries:
        f.write(json.dumps(e) + '\n')

print(f'Wrote {len(entries)} test entries to ${TEST_AUDIT_FILE}')
PYEOF

# Verify the hash chain passes
VERIFY_OUTPUT=$(run_script "$AUDIT_EXPORT" --verify --days 1 2>&1 || true)
if echo "$VERIFY_OUTPUT" | grep -q "intact"; then
    pass "audit-export --verify: valid chain → integrity confirmed"
else
    fail "audit-export --verify: expected 'intact', got: $VERIFY_OUTPUT"
fi

# Tamper with one entry and verify it fails
python3 << PYEOF
import json

lines = open('${TEST_AUDIT_FILE}').readlines()
entry = json.loads(lines[2])
entry['result'] = 'TAMPERED'
lines[2] = json.dumps(entry) + '\n'
open('${TEST_AUDIT_FILE}', 'w').writelines(lines)
print('Tampered entry 3')
PYEOF

VERIFY_FAIL=$(run_script "$AUDIT_EXPORT" --verify --days 1 2>&1; echo "EXIT:$?")
if echo "$VERIFY_FAIL" | grep -q "BROKEN\|mismatch"; then
    pass "audit-export --verify: tampered entry → hash chain broken (detected)"
else
    fail "audit-export --verify: tampered entry should be detected, got: $VERIFY_FAIL"
fi

# ══════════════════════════════════════════════════════════════════════════
# 6. Phase 3 docs — non-stub (>100 lines each)
# ══════════════════════════════════════════════════════════════════════════

section "6. Phase 3 Docs — Non-Stub (> 100 lines)"

DOCS=(
    "$REPO_ROOT/docs/AUTHENTIK_SETUP.md:Authentik SSO guide"
    "$REPO_ROOT/docs/AUTHELIA_SETUP.md:Authelia 2FA guide"
    "$REPO_ROOT/docs/COMPLIANCE_GUIDE.md:Compliance guide"
    "$REPO_ROOT/docs/LANGFUSE_SETUP.md:Langfuse observability guide"
    "$REPO_ROOT/docs/MULTI_USER_SETUP.md:Multi-user setup guide"
    "$REPO_ROOT/skills/rbac/SKILL.md:RBAC skill doc"
    "$REPO_ROOT/skills/user-router/SKILL.md:User-router skill doc"
    "$REPO_ROOT/devops/rbac-config.md:RBAC config spec"
    "$REPO_ROOT/templates/TEAM.md:TEAM.md template"
    "$REPO_ROOT/templates/USERS/USER-template.md:USER-template.md"
)

for entry in "${DOCS[@]}"; do
    file="${entry%%:*}"
    desc="${entry##*:}"
    assert_file_not_stub "$file" "$desc"
done

# ══════════════════════════════════════════════════════════════════════════
# 7. Content assertions — key concepts present in docs
# ══════════════════════════════════════════════════════════════════════════

section "7. Content Assertions — Key Concepts"

assert_contains "$REPO_ROOT/docs/AUTHENTIK_SETUP.md" "docker-compose" "contains Docker Compose"
assert_contains "$REPO_ROOT/docs/AUTHENTIK_SETUP.md" "oauth2\|OAuth2\|OIDC" "contains OAuth2/OIDC"
assert_contains "$REPO_ROOT/docs/AUTHELIA_SETUP.md" "forward_auth\|forward-auth" "contains forward-auth"
assert_contains "$REPO_ROOT/docs/AUTHELIA_SETUP.md" "TOTP\|totp" "contains TOTP"
assert_contains "$REPO_ROOT/docs/COMPLIANCE_GUIDE.md" "GDPR\|gdpr" "contains GDPR"
assert_contains "$REPO_ROOT/docs/COMPLIANCE_GUIDE.md" "SOC 2\|SOC2" "contains SOC 2"
assert_contains "$REPO_ROOT/docs/COMPLIANCE_GUIDE.md" "hash.chain\|hash chain" "contains hash chain"
assert_contains "$REPO_ROOT/docs/LANGFUSE_SETUP.md" "docker-compose\|docker compose" "contains Docker Compose"
assert_contains "$REPO_ROOT/docs/LANGFUSE_SETUP.md" "LiteLLM\|litellm" "contains LiteLLM integration"
assert_contains "$REPO_ROOT/docs/MULTI_USER_SETUP.md" "memory.*isolation\|isolation.*memory\|Memory Isolation" "contains memory isolation"
assert_contains "$REPO_ROOT/docs/MULTI_USER_SETUP.md" "user-router" "references user-router"
assert_contains "$REPO_ROOT/docs/MULTI_USER_SETUP.md" "check-auth" "references check-auth"

# ══════════════════════════════════════════════════════════════════════════
# Results
# ══════════════════════════════════════════════════════════════════════════

echo ""
bold "══════════════════════════════════════════"
if [[ $SKIP -gt 0 ]]; then
    yellow "  (Skipped $SKIP tests — install pycasbin/uv for full coverage)"
fi
if [[ $FAIL -eq 0 ]]; then
    green "Phase 3 Validation: ALL PASSED ($PASS passed, $SKIP skipped)"
else
    red "Phase 3 Validation: $FAIL FAILED, $PASS PASSED, $SKIP SKIPPED (total $((PASS + FAIL + SKIP)))"
fi
bold "══════════════════════════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
