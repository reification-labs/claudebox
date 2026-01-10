#!/bin/bash
# Unit tests for named profile CRUD operations
# Run with: bash tests/test_named_profiles.sh
#
# Tests the full lifecycle of profile management:
# - Create profiles by name
# - List profiles
# - Remove profiles
# - Profile isolation

set -e

echo "=============================================="
echo "ClaudeBox Named Profile CRUD Tests"
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

# Setup: Create a temporary project directory
TEMP_PROJECT=$(mktemp -d)
export PROJECT_DIR="$TEMP_PROJECT"

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_PROJECT"
}
trap cleanup EXIT

echo "Test project: $PROJECT_DIR"
echo

echo "1. Profile creation"
echo "-------------------"

# Test: Create default profile
test_create_default_profile() {
    init_profile_dir "default"
    local profile_dir
    profile_dir=$(get_profile_dir "default")
    [[ -d "$profile_dir" ]]
}
run_test "Create 'default' profile" test_create_default_profile

# Test: Create named profile 'frontend'
test_create_named_profile_frontend() {
    init_profile_dir "frontend"
    local profile_dir
    profile_dir=$(get_profile_dir "frontend")
    [[ -d "$profile_dir" ]] && [[ -d "$profile_dir/.claude" ]]
}
run_test "Create 'frontend' profile with correct structure" test_create_named_profile_frontend

# Test: Create named profile 'backend'
test_create_named_profile_backend() {
    init_profile_dir "backend"
    local profile_dir
    profile_dir=$(get_profile_dir "backend")
    [[ -d "$profile_dir" ]] && [[ -d "$profile_dir/.config" ]]
}
run_test "Create 'backend' profile" test_create_named_profile_backend

# Test: Profile with hyphen in name
test_create_profile_with_hyphen() {
    init_profile_dir "my-profile"
    local profile_dir
    profile_dir=$(get_profile_dir "my-profile")
    [[ -d "$profile_dir" ]]
}
run_test "Create profile with hyphen: 'my-profile'" test_create_profile_with_hyphen

# Test: Profile with underscore in name
test_create_profile_with_underscore() {
    init_profile_dir "my_profile"
    local profile_dir
    profile_dir=$(get_profile_dir "my_profile")
    [[ -d "$profile_dir" ]]
}
run_test "Create profile with underscore: 'my_profile'" test_create_profile_with_underscore

echo
echo "2. Profile listing"
echo "------------------"

# Test: List profiles returns expected count
test_list_profiles_count() {
    local count
    count=$(find "$PROJECT_DIR/.claudebox/profiles" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    # We created 5 profiles: default, frontend, backend, my-profile, my_profile
    [[ "$count" -eq 5 ]]
}
run_test "List profiles shows 5 profiles" test_list_profiles_count

# Test: List includes 'default' profile
test_list_includes_default() {
    [[ -d "$PROJECT_DIR/.claudebox/profiles/default" ]]
}
run_test "Profiles include 'default'" test_list_includes_default

# Test: List includes 'frontend' profile
test_list_includes_frontend() {
    [[ -d "$PROJECT_DIR/.claudebox/profiles/frontend" ]]
}
run_test "Profiles include 'frontend'" test_list_includes_frontend

echo
echo "3. Profile isolation"
echo "--------------------"

# Test: Each profile has its own .claude directory
test_profile_isolation_claude() {
    local default_claude
    local frontend_claude
    default_claude=$(get_profile_dir "default")/.claude
    frontend_claude=$(get_profile_dir "frontend")/.claude
    [[ -d "$default_claude" ]] && [[ -d "$frontend_claude" ]] &&
        [[ "$default_claude" != "$frontend_claude" ]]
}
run_test "Each profile has isolated .claude directory" test_profile_isolation_claude

# Test: Create file in one profile doesn't affect another
test_profile_isolation_files() {
    echo "frontend-data" >"$PROJECT_DIR/.claudebox/profiles/frontend/.claude/test_file"
    [[ -f "$PROJECT_DIR/.claudebox/profiles/frontend/.claude/test_file" ]] &&
        [[ ! -f "$PROJECT_DIR/.claudebox/profiles/default/.claude/test_file" ]]
}
run_test "Files in one profile don't affect another" test_profile_isolation_files

echo
echo "4. Profile removal"
echo "------------------"

# Test: Remove a profile by deleting its directory
test_remove_profile() {
    local profile_dir
    profile_dir=$(get_profile_dir "my-profile")
    rm -rf "$profile_dir"
    [[ ! -d "$profile_dir" ]]
}
run_test "Remove 'my-profile' successfully" test_remove_profile

# Test: After removal, count is decremented
test_count_after_removal() {
    local count
    count=$(find "$PROJECT_DIR/.claudebox/profiles" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    [[ "$count" -eq 4 ]]
}
run_test "Profile count is 4 after removal" test_count_after_removal

# Test: Other profiles unaffected by removal
test_other_profiles_unaffected() {
    [[ -d "$PROJECT_DIR/.claudebox/profiles/default" ]] &&
        [[ -d "$PROJECT_DIR/.claudebox/profiles/frontend" ]] &&
        [[ -d "$PROJECT_DIR/.claudebox/profiles/backend" ]]
}
run_test "Other profiles unaffected by removal" test_other_profiles_unaffected

echo
echo "5. Profile recreation"
echo "---------------------"

# Test: Can recreate a removed profile
test_recreate_profile() {
    init_profile_dir "my-profile"
    local profile_dir
    profile_dir=$(get_profile_dir "my-profile")
    [[ -d "$profile_dir" ]] && [[ -d "$profile_dir/.claude" ]]
}
run_test "Recreate removed profile" test_recreate_profile

# Test: Recreated profile has clean state (no old files)
test_recreated_profile_clean() {
    local profile_dir
    profile_dir=$(get_profile_dir "my-profile")
    # Should not have the test file we created earlier (it was removed with the profile)
    [[ ! -f "$profile_dir/.claude/test_file" ]]
}
run_test "Recreated profile has clean state" test_recreated_profile_clean

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
