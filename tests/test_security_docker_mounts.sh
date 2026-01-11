#!/bin/bash
# Security tests for docker.sh mount behavior
# Tests for: tmux opt-in, profile symlink rejection
# Run with: bash tests/test_security_docker_mounts.sh

set -e

echo "=============================================="
echo "ClaudeBox Docker Mount Security Tests"
echo "=============================================="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDEBOX_ROOT="$(dirname "$SCRIPT_DIR")"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

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

echo "1. Tmux Socket Mounting - Must Be Opt-In"
echo "-----------------------------------------"
echo "GPT review: Tmux socket mounting allows container to send keystrokes to host."
echo "This is a host escape vector and must be opt-in only."
echo

# Test: Tmux code must be gated behind CLAUDEBOX_WRAP_TMUX check
test_tmux_opt_in_gate() {
    # The tmux socket mounting block must be inside an if-check for CLAUDEBOX_WRAP_TMUX
    # Pattern: if [[ "$CLAUDEBOX_WRAP_TMUX" == "true" ]] (or similar) BEFORE tmux socket variable

    # Get line numbers of relevant patterns
    local tmux_gate_line tmux_socket_var_line

    # Look for the opt-in gate
    tmux_gate_line=$(grep -n 'CLAUDEBOX_WRAP_TMUX.*true' "$CLAUDEBOX_ROOT/lib/docker.sh" | head -1 | cut -d: -f1)

    # Look for first tmux_socket variable declaration (the actual code, not comments)
    tmux_socket_var_line=$(grep -n 'local tmux_socket=' "$CLAUDEBOX_ROOT/lib/docker.sh" | head -1 | cut -d: -f1)

    # Gate must exist and come BEFORE socket variable declaration
    [[ -n "$tmux_gate_line" ]] && [[ -n "$tmux_socket_var_line" ]] && [[ "$tmux_gate_line" -lt "$tmux_socket_var_line" ]]
}
run_test "Tmux socket mounting gated behind CLAUDEBOX_WRAP_TMUX check" test_tmux_opt_in_gate

# Test: Comment documents the security reason
test_tmux_security_comment() {
    grep -q 'SECURITY.*[Tt]mux.*opt.in\|[Tt]mux.*keystroke\|[Tt]mux.*host escape' "$CLAUDEBOX_ROOT/lib/docker.sh"
}
run_test "Tmux code has security comment explaining opt-in requirement" test_tmux_security_comment

echo
echo "2. Profile Directory Symlink Check"
echo "-----------------------------------"
echo "Gemini review: Malicious repo could replace profile dirs with symlinks"
echo "to ~/.ssh, allowing data exfiltration even with read-only mounts."
echo

# Test: docker.sh checks for symlinks before mounting profile directories
test_profile_symlink_check_exists() {
    # Must have -L check for profile directories before mounting
    grep -q '\-L.*profile\|profile.*\-L\|symlink.*profile\|SECURITY.*symlink' "$CLAUDEBOX_ROOT/lib/docker.sh"
}
run_test "docker.sh has symlink check for profile directories" test_profile_symlink_check_exists

# Test: Symlink check covers .claude, .config, .cache, .venv
test_symlink_check_all_dirs() {
    # Either check each explicitly OR use a loop over subdirs
    local docker_sh="$CLAUDEBOX_ROOT/lib/docker.sh"

    # Check for loop pattern (preferred)
    if grep -q 'for subdir in.*\.claude.*\.config.*\.cache.*\.venv' "$docker_sh"; then
        return 0
    fi

    # Or individual checks
    grep -q '\-L.*\.claude' "$docker_sh" && \
    grep -q '\-L.*\.config' "$docker_sh" && \
    grep -q '\-L.*\.cache' "$docker_sh"
}
run_test "Symlink check covers all profile subdirectories" test_symlink_check_all_dirs

# Test: Symlink detection results in error (not just warning)
test_symlink_causes_error() {
    # Should call error() when symlink detected, not just warn()
    grep -A5 '\-L.*profile\|\-L.*check_path' "$CLAUDEBOX_ROOT/lib/docker.sh" | grep -q 'error'
}
run_test "Symlink detection causes error (blocks execution)" test_symlink_causes_error

echo
echo "3. NET_ADMIN/NET_RAW Capabilities"
echo "----------------------------------"
echo "GPT review: These caps are high-privilege. Only needed when firewall is enabled."
echo

# Test: no-new-privileges security option should be present
test_no_new_privileges() {
    grep -q 'no-new-privileges' "$CLAUDEBOX_ROOT/lib/docker.sh"
}
run_test "docker.sh includes --security-opt no-new-privileges" test_no_new_privileges

echo
echo "=============================================="
echo "Test Summary"
echo "=============================================="
echo "Tests run: $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"
echo

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo -e "${GREEN}All security tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}SECURITY TESTS FAILED ✗${NC}"
    echo
    echo "These tests verify critical security controls."
    echo "Fix the issues before merging."
    exit 1
fi
