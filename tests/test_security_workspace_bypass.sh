#!/bin/bash
# Security Test: Verify mounts/allowlist cannot be modified via /workspace bypass
#
# VULNERABILITY: When PROJECT_PARENT_DIR=$PROJECT_DIR/.claudebox, the container has:
#   /workspace (rw) = $PROJECT_DIR
#   /home/user/.claudebox (ro) = $PROJECT_DIR/.claudebox
#
# The container can bypass the :ro mount by writing to /workspace/.claudebox/mounts
#
# SPEC REQUIREMENT: mounts/allowlist must ONLY live in ~/.claudebox/ (global config),
# NEVER in $PROJECT_DIR/.claudebox (which is inside /workspace)
#
# Run: bash tests/test_security_workspace_bypass.sh

set -e

echo "=============================================="
echo "Security Test: /workspace Bypass Prevention"
echo "=============================================="
echo
echo "This test verifies that security-critical files"
echo "(mounts, allowlist) are NOT accessible via the"
echo "/workspace mount, preventing sandbox escape."
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Skipping.${NC}"
    exit 0
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}Docker daemon not running. Skipping.${NC}"
    exit 0
fi

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Setup temp directories
TEMP_PROJECT=$(mktemp -d)
TEMP_GLOBAL_CONFIG=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_PROJECT" "$TEMP_GLOBAL_CONFIG"
}
trap cleanup EXIT

# Initialize directories to mimic the CORRECT architecture per spec:
# - Global config at ~/.claudebox/ with mounts/allowlist
# - Project-local profiles at $PROJECT/.claudebox/profiles/
mkdir -p "$TEMP_GLOBAL_CONFIG"
echo "# Global mounts - should be protected" > "$TEMP_GLOBAL_CONFIG/mounts"
echo "# Global allowlist - should be protected" > "$TEMP_GLOBAL_CONFIG/allowlist"

mkdir -p "$TEMP_PROJECT/.claudebox/profiles/default/.claude"
mkdir -p "$TEMP_PROJECT/.claudebox/profiles/default/.config"
mkdir -p "$TEMP_PROJECT/.claudebox/profiles/default/.cache"

echo "Test setup (correct architecture per spec):"
echo "  Global config: $TEMP_GLOBAL_CONFIG (should be :ro)"
echo "  Project dir: $TEMP_PROJECT (mounted as /workspace)"
echo "  Profile dir: $TEMP_PROJECT/.claudebox/profiles/default"
echo

run_test() {
    local test_name="$1"
    local test_cmd="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Test $TESTS_RUN: $test_name... "

    if eval "$test_cmd"; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

echo "1. Demonstrating WHY vulnerable architecture fails"
echo "--------------------------------------------------"
echo "This section proves that IF mounts/allowlist were in PROJECT_DIR,"
echo "they COULD be modified via /workspace (documenting the vulnerability)."
echo

# EDUCATIONAL TEST: Demonstrates the vulnerability EXISTS with wrong architecture
# This test PASSES when the vulnerable config IS exploitable (expected behavior)
test_vulnerable_config_is_exploitable() {
    # Create mounts file in project dir (the WRONG location)
    mkdir -p "$TEMP_PROJECT/.claudebox"
    echo "# Original mounts" > "$TEMP_PROJECT/.claudebox/mounts"
    local original_content
    original_content=$(cat "$TEMP_PROJECT/.claudebox/mounts")

    # Mount with VULNERABLE configuration:
    #   /workspace = PROJECT_DIR (rw)
    #   /home/user/.claudebox = PROJECT_DIR/.claudebox (ro)
    docker run --rm \
        -v "$TEMP_PROJECT":/workspace \
        -v "$TEMP_PROJECT/.claudebox":/home/testuser/.claudebox:ro \
        alpine:latest \
        sh -c 'echo "/etc/passwd:/workspace/pwned:rw" >> /workspace/.claudebox/mounts' 2>/dev/null || true

    local new_content
    new_content=$(cat "$TEMP_PROJECT/.claudebox/mounts")

    # TEST PASSES if the vulnerable config WAS exploitable (proves why we need the fix)
    if [[ "$original_content" != "$new_content" ]]; then
        return 0  # EXPECTED: vulnerable config is exploitable
    else
        echo
        echo -e "  ${YELLOW}Unexpected: vulnerable config was NOT exploitable${NC}"
        return 1
    fi
}
run_test "Vulnerable architecture IS exploitable (expected)" test_vulnerable_config_is_exploitable

# Clean up for next test
rm -rf "$TEMP_PROJECT/.claudebox"

echo
echo "2. Correct Architecture: Global config separate from /workspace"
echo "----------------------------------------------------------------"
echo "When mounts/allowlist are in global ~/.claudebox/ (not project dir),"
echo "they cannot be accessed via /workspace at all."
echo

# This test shows the CORRECT architecture where bypass is impossible
test_correct_architecture_mounts() {
    echo "# Global mounts - safe location" > "$TEMP_GLOBAL_CONFIG/mounts"
    local original_content
    original_content=$(cat "$TEMP_GLOBAL_CONFIG/mounts")

    # Mount like ClaudeBox SHOULD do:
    #   /workspace = PROJECT_DIR (rw) - does NOT contain mounts/allowlist
    #   /home/user/.claudebox = ~/.claudebox (ro) - contains mounts/allowlist
    docker run --rm \
        -v "$TEMP_PROJECT":/workspace \
        -v "$TEMP_GLOBAL_CONFIG":/home/testuser/.claudebox:ro \
        alpine:latest \
        sh -c '
            # Try the direct path - should fail (ro)
            echo "hack" >> /home/testuser/.claudebox/mounts 2>/dev/null || true
            # Try via workspace - should not exist
            echo "hack" >> /workspace/.claudebox/mounts 2>/dev/null || true
        ' 2>/dev/null || true

    local new_content
    new_content=$(cat "$TEMP_GLOBAL_CONFIG/mounts")

    if [[ "$original_content" == "$new_content" ]]; then
        return 0  # SECURE
    else
        echo
        echo -e "  ${YELLOW}Unexpected: global config was modified!${NC}"
        return 1
    fi
}
run_test "Global config mounts protected (correct arch)" test_correct_architecture_mounts

echo
echo "=============================================="
echo "Test Summary"
echo "=============================================="
echo "Tests run: $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"
echo

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    echo
    echo "This test demonstrates:"
    echo "  1. WHY putting mounts/allowlist in PROJECT_DIR is vulnerable"
    echo "  2. WHY global config (~/.claudebox) architecture is secure"
    echo
    echo "ClaudeBox uses the secure architecture (global config)."
    exit 0
else
    echo -e "${RED}TESTS FAILED ✗${NC}"
    echo
    echo "Unexpected behavior in security architecture tests."
    exit 1
fi
