#!/bin/bash
# Unit tests for profile directory functions
# Run with: bash tests/test_profile_dir.sh

set -e

echo "=============================================="
echo "ClaudeBox Profile Directory Tests"
echo "=============================================="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Get script directory and source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDEBOX_ROOT="$(dirname "$SCRIPT_DIR")"

# Source required libraries
source "$CLAUDEBOX_ROOT/lib/common.sh"
source "$CLAUDEBOX_ROOT/lib/project.sh"

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

# Setup
TEMP_PROJECT=$(mktemp -d)
export PROJECT_DIR="$TEMP_PROJECT"

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_PROJECT"
}
trap cleanup EXIT

echo "Test project dir: $PROJECT_DIR"
echo

echo "1. get_profile_dir() function"
echo "------------------------------"

# Test: get_profile_dir returns project-local path
test_profile_dir_default() {
    local result
    result=$(get_profile_dir "default")
    [[ "$result" == "$PROJECT_DIR/.claudebox/profiles/default" ]]
}
run_test "get_profile_dir('default') returns project-local path" test_profile_dir_default

# Test: get_profile_dir with custom name
test_profile_dir_custom() {
    local result
    result=$(get_profile_dir "backend")
    [[ "$result" == "$PROJECT_DIR/.claudebox/profiles/backend" ]]
}
run_test "get_profile_dir('backend') returns correct path" test_profile_dir_custom

# Test: get_profile_dir defaults to 'default' when no arg
test_profile_dir_no_arg() {
    local result
    result=$(get_profile_dir)
    [[ "$result" == "$PROJECT_DIR/.claudebox/profiles/default" ]]
}
run_test "get_profile_dir() with no arg defaults to 'default'" test_profile_dir_no_arg

# Test: Profile dir is inside PROJECT_DIR (not ~/.claudebox)
test_profile_not_in_home() {
    local result
    result=$(get_profile_dir "test")
    # Should NOT contain ~/.claudebox/projects
    [[ "$result" != *"$HOME/.claudebox/projects"* ]]
}
run_test "Profile dir is NOT in ~/.claudebox/projects" test_profile_not_in_home

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
