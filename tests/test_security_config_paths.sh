#!/bin/bash
# Unit Test: Verify security-critical file paths are in global config
#
# SPEC REQUIREMENT: mounts/allowlist must be in ~/.claudebox/ (global config),
# NOT in $PROJECT_DIR/.claudebox (which is inside /workspace and writable)
#
# Run: bash tests/test_security_config_paths.sh

set -e

echo "=============================================="
echo "Unit Test: Security Config Path Verification"
echo "=============================================="
echo
echo "Verifying that mounts/allowlist paths point to"
echo "global config (~/.claudebox), not project dir."
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDEBOX_ROOT="$(dirname "$SCRIPT_DIR")"

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

echo "1. Checking docker.sh uses global config for mounts"
echo "----------------------------------------------------"

# Test: docker.sh should define global_config_dir as $HOME/.claudebox
test_docker_global_config_defined() {
    grep -q 'global_config_dir="\$HOME/.claudebox"' "$CLAUDEBOX_ROOT/lib/docker.sh"
}
run_test "docker.sh defines global_config_dir as \$HOME/.claudebox" test_docker_global_config_defined

# Test: docker.sh should use global_config_dir for mounts_file
test_docker_mounts_uses_global() {
    grep -q 'mounts_file="\$global_config_dir/mounts"' "$CLAUDEBOX_ROOT/lib/docker.sh"
}
run_test "docker.sh uses global_config_dir for mounts_file" test_docker_mounts_uses_global

# Test: docker.sh should mount global_config_dir as .claudebox:ro
test_docker_mounts_global_ro() {
    grep -q '\$global_config_dir.*\.claudebox:ro' "$CLAUDEBOX_ROOT/lib/docker.sh"
}
run_test "docker.sh mounts global_config_dir as .claudebox:ro" test_docker_mounts_global_ro

echo
echo "2. Checking commands.info.sh uses global config"
echo "------------------------------------------------"

# Test: allowlist should use $HOME/.claudebox
test_allowlist_global_path() {
    grep -q 'allowlist_file="\$HOME/.claudebox/allowlist"' "$CLAUDEBOX_ROOT/lib/commands.info.sh"
}
run_test "allowlist uses \$HOME/.claudebox path" test_allowlist_global_path

# Test: mounts command should use $HOME/.claudebox
test_mount_cmd_global_path() {
    grep -q 'mounts_file="\$HOME/.claudebox/mounts"' "$CLAUDEBOX_ROOT/lib/commands.info.sh"
}
run_test "mount command uses \$HOME/.claudebox path" test_mount_cmd_global_path

echo
echo "3. Negative tests: Should NOT use PROJECT_PARENT_DIR for security files"
echo "------------------------------------------------------------------------"

# Test: docker.sh mounts_file should NOT use PROJECT_PARENT_DIR
test_docker_no_project_parent_mounts() {
    ! grep -q 'mounts_file="\$PROJECT_PARENT_DIR/mounts"' "$CLAUDEBOX_ROOT/lib/docker.sh"
}
run_test "docker.sh does NOT use PROJECT_PARENT_DIR for mounts" test_docker_no_project_parent_mounts

# Test: commands.info.sh allowlist should NOT use PROJECT_PARENT_DIR
test_info_no_project_parent_allowlist() {
    ! grep -q 'allowlist_file="\$PROJECT_PARENT_DIR/allowlist"' "$CLAUDEBOX_ROOT/lib/commands.info.sh"
}
run_test "commands.info.sh does NOT use PROJECT_PARENT_DIR for allowlist" test_info_no_project_parent_allowlist

# Test: commands.info.sh mounts should NOT use PROJECT_PARENT_DIR
test_info_no_project_parent_mounts() {
    ! grep -q 'mounts_file="\$PROJECT_PARENT_DIR/mounts"' "$CLAUDEBOX_ROOT/lib/commands.info.sh"
}
run_test "commands.info.sh does NOT use PROJECT_PARENT_DIR for mounts" test_info_no_project_parent_mounts

echo
echo "4. Checking ~/.claudebox created with secure permissions"
echo "---------------------------------------------------------"

# Test: main.sh should create ~/.claudebox with 0700 permissions
test_claudebox_dir_permissions() {
    # Check that chmod 0700 is applied after mkdir (SC2174 compliant)
    grep -q 'chmod 0700.*\.claudebox\|chmod.*700.*\$HOME/.claudebox' "$CLAUDEBOX_ROOT/main.sh"
}
run_test "main.sh creates ~/.claudebox with 0700 permissions" test_claudebox_dir_permissions

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
    echo "Security config paths correctly point to global config."
    exit 0
else
    echo -e "${RED}SECURITY PATH TESTS FAILED ✗${NC}"
    echo
    echo "mounts/allowlist MUST be read from ~/.claudebox/ (global config),"
    echo "NOT from \$PROJECT_DIR/.claudebox (which is inside /workspace)"
    echo
    echo "See: specs/2026-01-10_01-51_profile-refactor.md"
    exit 1
fi
