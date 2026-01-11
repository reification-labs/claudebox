#!/bin/bash
# Unit tests for commands.env.sh (development environment management)
# Run with: bash tests/test_commands_env.sh
#
# Command Structure:
#   claudebox env list              -> _env_list()    - List environments
#   claudebox env add <env>         -> _env_add()     - Add environment
#   claudebox env remove <env>      -> _env_remove()  - Remove environment
#   claudebox env install <pkg>     -> _env_install() - Install apt package

set -e

echo "=============================================="
echo "ClaudeBox Commands Env Tests"
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

echo "1. File existence"
echo "-----------------"

# Test: commands.env.sh exists
test_env_file_exists() {
    [[ -f "$LIB_DIR/commands.env.sh" ]]
}
run_test "commands.env.sh exists" test_env_file_exists

echo
echo "2. Router and subcommand functions"
echo "-----------------------------------"

# Source the env commands file if it exists
if [[ -f "$LIB_DIR/commands.env.sh" ]]; then
    source "$CLAUDEBOX_ROOT/lib/project.sh"
    source "$LIB_DIR/commands.env.sh"
fi

# Test: _cmd_env router exists
test_cmd_env_exists() {
    declare -f _cmd_env >/dev/null 2>&1
}
run_test "_cmd_env() router exists" test_cmd_env_exists

# Test: _env_list subcommand exists
test_env_list_exists() {
    declare -f _env_list >/dev/null 2>&1
}
run_test "_env_list() for 'claudebox env list'" test_env_list_exists

# Test: _env_add subcommand exists
test_env_add_exists() {
    declare -f _env_add >/dev/null 2>&1
}
run_test "_env_add() for 'claudebox env add'" test_env_add_exists

# Test: _env_remove subcommand exists
test_env_remove_exists() {
    declare -f _env_remove >/dev/null 2>&1
}
run_test "_env_remove() for 'claudebox env remove'" test_env_remove_exists

# Test: _env_install subcommand exists
test_env_install_exists() {
    declare -f _env_install >/dev/null 2>&1
}
run_test "_env_install() for 'claudebox env install'" test_env_install_exists

# Test: _env_help subcommand exists
test_env_help_exists() {
    declare -f _env_help >/dev/null 2>&1
}
run_test "_env_help() for 'claudebox env help'" test_env_help_exists

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
