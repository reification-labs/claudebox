#!/bin/bash
# Unit tests for commands.profile.sh (container profile management)
# Run with: bash tests/test_commands_profile.sh
#
# Command Structure:
#   claudebox profile list              -> _profile_list()    - List profiles
#   claudebox profile create            -> _profile_create()  - Create profile
#   claudebox profile run <num>         -> _profile_run()     - Run profile
#   claudebox profile remove [all]      -> _profile_remove()  - Remove profile(s)
#   claudebox profile kill [all]        -> _profile_kill()    - Kill container(s)

set -e

echo "=============================================="
echo "ClaudeBox Commands Profile Tests"
echo "=============================================="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Get script directory and source the libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDEBOX_ROOT="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$CLAUDEBOX_ROOT/lib"

# Source required libraries
source "$CLAUDEBOX_ROOT/lib/common.sh"

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

echo "1. File structure"
echo "-----------------"

# Test: commands.profile.sh exists
test_profile_file_exists() {
    [[ -f "$LIB_DIR/commands.profile.sh" ]]
}
run_test "commands.profile.sh exists" test_profile_file_exists

# Test: commands.slot.sh should NOT exist (renamed)
test_slot_file_removed() {
    [[ ! -f "$LIB_DIR/commands.slot.sh" ]]
}
run_test "commands.slot.sh removed (renamed to profile)" test_slot_file_removed

echo
echo "2. Router and subcommand functions"
echo "-----------------------------------"

# Source the profile commands file if it exists
if [[ -f "$LIB_DIR/commands.profile.sh" ]]; then
    # Source dependencies
    source "$CLAUDEBOX_ROOT/lib/project.sh"
    source "$CLAUDEBOX_ROOT/lib/state.sh"
    source "$CLAUDEBOX_ROOT/lib/docker.sh" 2>/dev/null || true
    source "$LIB_DIR/commands.profile.sh"
fi

# Test: _cmd_profile router exists
test_cmd_profile_exists() {
    declare -f _cmd_profile >/dev/null 2>&1
}
run_test "_cmd_profile() router exists" test_cmd_profile_exists

# Test: _profile_list subcommand exists
test_profile_list_exists() {
    declare -f _profile_list >/dev/null 2>&1
}
run_test "_profile_list() for 'claudebox profile list'" test_profile_list_exists

# Test: _profile_create subcommand exists
test_profile_create_exists() {
    declare -f _profile_create >/dev/null 2>&1
}
run_test "_profile_create() for 'claudebox profile create'" test_profile_create_exists

# Test: _profile_run subcommand exists
test_profile_run_exists() {
    declare -f _profile_run >/dev/null 2>&1
}
run_test "_profile_run() for 'claudebox profile run'" test_profile_run_exists

# Test: _profile_remove subcommand exists
test_profile_remove_exists() {
    declare -f _profile_remove >/dev/null 2>&1
}
run_test "_profile_remove() for 'claudebox profile remove'" test_profile_remove_exists

# Test: _profile_kill subcommand exists
test_profile_kill_exists() {
    declare -f _profile_kill >/dev/null 2>&1
}
run_test "_profile_kill() for 'claudebox profile kill'" test_profile_kill_exists

# Test: _profile_help subcommand exists
test_profile_help_exists() {
    declare -f _profile_help >/dev/null 2>&1
}
run_test "_profile_help() for 'claudebox profile help'" test_profile_help_exists

echo
echo "3. Old slot functions removed"
echo "-----------------------------"

# Test: _cmd_slots should NOT exist (old function)
test_cmd_slots_removed() {
    ! declare -f _cmd_slots >/dev/null 2>&1
}
run_test "_cmd_slots() removed (was old slot listing)" test_cmd_slots_removed

# Test: _cmd_slot should NOT exist (old function)
test_cmd_slot_removed() {
    ! declare -f _cmd_slot >/dev/null 2>&1
}
run_test "_cmd_slot() removed (was old slot runner)" test_cmd_slot_removed

# Test: _cmd_create should NOT exist (now _profile_create)
test_cmd_create_removed() {
    ! declare -f _cmd_create >/dev/null 2>&1
}
run_test "_cmd_create() removed (now _profile_create)" test_cmd_create_removed

# Test: _cmd_revoke should NOT exist (now _profile_remove)
test_cmd_revoke_removed() {
    ! declare -f _cmd_revoke >/dev/null 2>&1
}
run_test "_cmd_revoke() removed (now _profile_remove)" test_cmd_revoke_removed

# Test: _cmd_kill should NOT exist (now _profile_kill)
test_cmd_kill_removed() {
    ! declare -f _cmd_kill >/dev/null 2>&1
}
run_test "_cmd_kill() removed (now _profile_kill)" test_cmd_kill_removed

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
