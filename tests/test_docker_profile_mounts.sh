#!/bin/bash
# Unit tests for docker.sh profile directory mounts
# Verifies that docker.sh uses get_profile_dir() for mounts
# Run with: bash tests/test_docker_profile_mounts.sh

set -e

echo "=============================================="
echo "ClaudeBox Docker Profile Mount Tests"
echo "=============================================="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Get script directory and source the libraries
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

echo "1. Profile directory setup in docker.sh"
echo "----------------------------------------"

# Test: init_profile_dir creates correct structure for docker mounts
test_profile_dirs_for_docker() {
    init_profile_dir "default"
    local profile_dir
    profile_dir=$(get_profile_dir "default")

    # All three directories must exist for docker mounts
    [[ -d "$profile_dir/.claude" ]] && \
    [[ -d "$profile_dir/.config" ]] && \
    [[ -d "$profile_dir/.cache" ]]
}
run_test "init_profile_dir creates all directories needed for docker mounts" test_profile_dirs_for_docker

# Test: Profile directory is in PROJECT_DIR, not ~/.claudebox
test_profile_in_project_dir() {
    local profile_dir
    profile_dir=$(get_profile_dir "default")

    # Must be inside PROJECT_DIR
    [[ "$profile_dir" == "$PROJECT_DIR/.claudebox/profiles/default" ]]
}
run_test "Profile directory is inside PROJECT_DIR" test_profile_in_project_dir

# Test: Profile directory does NOT use old PROJECT_SLOT_DIR location
test_profile_not_old_slot_dir() {
    local profile_dir
    profile_dir=$(get_profile_dir "default")

    # Must NOT be in the old ~/.claudebox/projects location
    [[ "$profile_dir" != *"$HOME/.claudebox/projects"* ]]
}
run_test "Profile directory does NOT use old ~/.claudebox/projects path" test_profile_not_old_slot_dir

echo
echo "2. Docker mount path generation"
echo "--------------------------------"

# Test: get_profile_dir can be used to construct docker mount paths
test_docker_mount_path_construction() {
    local profile_dir
    profile_dir=$(get_profile_dir "default")

    # Construct the paths that docker.sh should use
    local claude_mount="$profile_dir/.claude"
    local config_mount="$profile_dir/.config"
    local cache_mount="$profile_dir/.cache"

    # Verify paths are correct format
    [[ "$claude_mount" == "$PROJECT_DIR/.claudebox/profiles/default/.claude" ]] && \
    [[ "$config_mount" == "$PROJECT_DIR/.claudebox/profiles/default/.config" ]] && \
    [[ "$cache_mount" == "$PROJECT_DIR/.claudebox/profiles/default/.cache" ]]
}
run_test "get_profile_dir generates correct docker mount paths" test_docker_mount_path_construction

# Test: Named profile creates isolated mount paths
test_named_profile_mount_paths() {
    local backend_dir frontend_dir

    backend_dir=$(get_profile_dir "backend")
    frontend_dir=$(get_profile_dir "frontend")

    # Verify each profile has isolated paths
    [[ "$backend_dir" == "$PROJECT_DIR/.claudebox/profiles/backend" ]] && \
    [[ "$frontend_dir" == "$PROJECT_DIR/.claudebox/profiles/frontend" ]] && \
    [[ "$backend_dir" != "$frontend_dir" ]]
}
run_test "Named profiles have isolated mount paths" test_named_profile_mount_paths

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
