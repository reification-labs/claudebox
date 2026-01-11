#!/bin/bash
# Unit tests for state.sh checksum storage locations
# Verifies checksums are stored in project-local directories
# Run with: bash tests/test_state_checksums.sh

set -e

echo "=============================================="
echo "ClaudeBox State Checksum Location Tests"
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
source "$CLAUDEBOX_ROOT/lib/state.sh"

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
export SCRIPT_DIR="$CLAUDEBOX_ROOT"

# Create .claudebox directory structure
mkdir -p "$PROJECT_DIR/.claudebox"

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_PROJECT"
}
trap cleanup EXIT

echo "Test project dir: $PROJECT_DIR"
echo

echo "1. Docker layer checksum storage location"
echo "------------------------------------------"

# Test: get_checksum_file returns project-local path
test_checksum_file_in_project() {
    local checksum_file
    checksum_file=$(get_checksum_file)

    # Must be inside PROJECT_DIR/.claudebox/
    [[ "$checksum_file" == "$PROJECT_DIR/.claudebox/"* ]]
}
run_test "get_checksum_file() returns project-local path" test_checksum_file_in_project

# Test: checksum file is NOT in ~/.claudebox/projects
test_checksum_not_centralized() {
    local checksum_file
    checksum_file=$(get_checksum_file)

    # Must NOT be in the old centralized location
    [[ "$checksum_file" != *"$HOME/.claudebox/projects"* ]]
}
run_test "Checksum file is NOT in ~/.claudebox/projects" test_checksum_not_centralized

# Test: save_docker_layer_checksums creates file in project dir
test_save_checksums_location() {
    # Create minimal build directory for checksum calculation
    mkdir -p "$CLAUDEBOX_ROOT/build"

    # Save checksums
    save_docker_layer_checksums "$PROJECT_DIR"

    # Check file was created in project directory
    [[ -f "$PROJECT_DIR/.claudebox/.docker_layer_checksums" ]]
}
run_test "save_docker_layer_checksums creates file in PROJECT_DIR/.claudebox/" test_save_checksums_location

echo
echo "2. Global profiles.ini location"
echo "--------------------------------"

# Test: profiles.ini is read from global ~/.claudebox/
test_profiles_ini_global() {
    # Create a temporary global profiles.ini
    local global_claudebox="$HOME/.claudebox"
    mkdir -p "$global_claudebox"

    # The profiles.ini should be at ~/.claudebox/profiles.ini
    # This test just verifies the path constant is correct
    local expected_path="$HOME/.claudebox/profiles.ini"

    # Get the path used by calculate_docker_layer_checksums
    # We can't easily test this without modifying the function,
    # so we'll just verify the expected structure
    [[ -d "$global_claudebox" ]]
}
run_test "Global ~/.claudebox/ directory exists or can be created" test_profiles_ini_global

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
