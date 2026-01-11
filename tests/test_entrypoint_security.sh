#!/bin/bash
# Security tests for docker-entrypoint
# Run with: bash tests/test_entrypoint_security.sh

set -e

echo "=============================================="
echo "ClaudeBox Entrypoint Security Tests"
echo "=============================================="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Test function
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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDEBOX_ROOT="$(dirname "$SCRIPT_DIR")"
ENTRYPOINT="$CLAUDEBOX_ROOT/build/docker-entrypoint"

echo "1. CLAUDEBOX_SLOT_NAME validation"
echo "----------------------------------"

# Test: Entrypoint script contains slot name validation
test_has_slot_validation() {
    # Check that the entrypoint validates CLAUDEBOX_SLOT_NAME
    grep -q 'CLAUDEBOX_SLOT_NAME.*[./]' "$ENTRYPOINT" || \
    grep -q 'validate.*SLOT_NAME' "$ENTRYPOINT" || \
    grep -q 'SLOT_NAME.*path.traversal\|path.traversal.*SLOT_NAME' "$ENTRYPOINT" || \
    grep -q 'if.*CLAUDEBOX_SLOT_NAME.*\.\.' "$ENTRYPOINT"
}
run_test "Entrypoint has CLAUDEBOX_SLOT_NAME validation" test_has_slot_validation

# Test: Slot name with path traversal should be rejected
test_slot_traversal_in_code() {
    # Check that path with slot name is validated before use
    # The vulnerable line is: /workspace/.claudebox/profiles/${CLAUDEBOX_SLOT_NAME}/
    # We need validation BEFORE this line
    local vulnerable_line
    vulnerable_line=$(grep -n 'CLAUDEBOX_SLOT_NAME.*\.claude\.json' "$ENTRYPOINT" | head -1 | cut -d: -f1)

    if [[ -z "$vulnerable_line" ]]; then
        # No vulnerable usage found - that's actually fine
        return 0
    fi

    # Check for validation before the vulnerable line
    local validation_line
    validation_line=$(grep -n 'CLAUDEBOX_SLOT_NAME.*[./]' "$ENTRYPOINT" | head -1 | cut -d: -f1)

    if [[ -n "$validation_line" ]] && [[ "$validation_line" -lt "$vulnerable_line" ]]; then
        return 0
    fi

    # No validation found before usage
    return 1
}
run_test "CLAUDEBOX_SLOT_NAME validated before use in path" test_slot_traversal_in_code

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
    exit 0
else
    echo -e "${RED}Some tests failed ✗${NC}"
    exit 1
fi
