#!/bin/bash
# Unit tests for migrate.sh (migration from old to new structure)
# Run with: bash tests/test_migrate.sh
#
# Migration converts:
#   OLD: ~/.claudebox/projects/{slug}_{crc32}/{hash}/
#   NEW: $PROJECT/.claudebox/profiles/{name}/

set -e

echo "=============================================="
echo "ClaudeBox Migration Tests"
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
source "$CLAUDEBOX_ROOT/lib/migrate.sh"

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

echo "1. Function definitions"
echo "-----------------------"

# Test: has_old_structure function exists
test_has_old_structure_exists() {
    declare -f has_old_structure >/dev/null 2>&1
}
run_test "has_old_structure() exists" test_has_old_structure_exists

# Test: list_old_projects function exists
test_list_old_projects_exists() {
    declare -f list_old_projects >/dev/null 2>&1
}
run_test "list_old_projects() exists" test_list_old_projects_exists

# Test: get_old_project_path function exists
test_get_old_project_path_exists() {
    declare -f get_old_project_path >/dev/null 2>&1
}
run_test "get_old_project_path() exists" test_get_old_project_path_exists

# Test: list_old_slots function exists
test_list_old_slots_exists() {
    declare -f list_old_slots >/dev/null 2>&1
}
run_test "list_old_slots() exists" test_list_old_slots_exists

# Test: migrate_project function exists
test_migrate_project_exists() {
    declare -f migrate_project >/dev/null 2>&1
}
run_test "migrate_project() exists" test_migrate_project_exists

# Test: archive_old_structure function exists
test_archive_old_structure_exists() {
    declare -f archive_old_structure >/dev/null 2>&1
}
run_test "archive_old_structure() exists" test_archive_old_structure_exists

# Test: _cmd_migrate function exists
test_cmd_migrate_exists() {
    declare -f _cmd_migrate >/dev/null 2>&1
}
run_test "_cmd_migrate() for 'claudebox migrate'" test_cmd_migrate_exists

echo
echo "2. Detection logic"
echo "------------------"

# Test: has_old_structure returns appropriate value
test_has_old_structure_logic() {
    # This test just verifies the function runs without error
    # Actual result depends on whether old structure exists
    has_old_structure
    local result=$?
    # Either 0 (true, old structure exists) or 1 (false) is valid
    [[ $result -eq 0 ]] || [[ $result -eq 1 ]]
}
run_test "has_old_structure() runs without error" test_has_old_structure_logic

# Test: list_old_slots pattern matching (8-char hex)
test_list_old_slots_pattern() {
    # Create temp directory with test structure
    local test_dir
    test_dir=$(mktemp -d)

    # Create fake slot directories (8-char hex names)
    mkdir -p "$test_dir/12345678"
    mkdir -p "$test_dir/abcdef01"
    mkdir -p "$test_dir/not-a-slot" # Should NOT be found
    mkdir -p "$test_dir/commands"   # Should NOT be found

    # Count slots found
    local count
    count=$(list_old_slots "$test_dir" | wc -l | tr -d ' ')

    # Cleanup
    rm -rf "$test_dir"

    # Should find exactly 2 hex-named directories
    [[ "$count" -eq 2 ]]
}
run_test "list_old_slots() finds only 8-char hex dirs" test_list_old_slots_pattern

echo
echo "3. Archive naming"
echo "-----------------"

# Test: archive directory uses timestamp, not just date
# This prevents data loss if migration runs twice on same day
test_archive_has_timestamp() {
    # Archive dir should include time (HHMMSS), not just date
    # Pattern: archive-YYYYMMDD_HHMMSS or similar with time component
    grep -q 'archive-.*%H%M%S\|archive-.*_[0-9]\{6\}' "$CLAUDEBOX_ROOT/lib/migrate.sh" || \
    grep -qE 'archive-\$\(date \+%Y%m%d_%H%M%S\)' "$CLAUDEBOX_ROOT/lib/migrate.sh"
}
run_test "Archive directory includes timestamp (prevents same-day collision)" test_archive_has_timestamp

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
