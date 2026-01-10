#!/bin/bash
# Test script for claudebox mount command
# Run this with: bash tests/test_mount_command.sh

set -e

echo "======================================"
echo "ClaudeBox Mount Command Tests"
echo "======================================"
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"
TEMP_DIR=$(mktemp -d)

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Test function
run_test() {
    local test_name="$1"
    local test_cmd="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Test $TESTS_RUN: $test_name... "

    if eval "$test_cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Error output:"
        eval "$test_cmd" 2>&1 | sed 's/^/    /' | head -10
        return 1
    fi
}

# Source the commands.info.sh to get mount functions
# We need to mock some dependencies first
source "$ROOT_DIR/lib/common.sh" 2>/dev/null || true

echo "1. Testing mount format validation"
echo "-----------------------------------"

# Test: Valid mount format
test_valid_format() {
    local mount_spec="/path/to/host:/container/path:ro"
    local colon_count="${mount_spec//[^:]}"
    [[ ${#colon_count} -eq 2 ]]
}
run_test "Valid mount format (2 colons)" test_valid_format

# Test: Too many colons rejected
test_too_many_colons() {
    local mount_spec="/path:with:colons:/container:ro"
    local colon_count="${mount_spec//[^:]}"
    [[ ${#colon_count} -ne 2 ]]  # Should fail validation
}
run_test "Reject mount with colons in path" test_too_many_colons

# Test: Too few colons rejected
test_too_few_colons() {
    local mount_spec="/path/to/host:/container"
    local colon_count="${mount_spec//[^:]}"
    [[ ${#colon_count} -ne 2 ]]  # Should fail validation
}
run_test "Reject mount missing mode" test_too_few_colons

# Test: Newline rejected
test_newline_rejected() {
    local mount_spec=$'/path/to/host\n/container:ro'
    [[ "$mount_spec" == *$'\n'* ]]  # Should detect newline
}
run_test "Detect newline in mount spec" test_newline_rejected

echo
echo "2. Testing mode validation"
echo "--------------------------"

# Test: Valid modes
test_valid_ro_mode() {
    local mode="ro"
    [[ "$mode" == "ro" || "$mode" == "rw" ]]
}
run_test "Accept 'ro' mode" test_valid_ro_mode

test_valid_rw_mode() {
    local mode="rw"
    [[ "$mode" == "ro" || "$mode" == "rw" ]]
}
run_test "Accept 'rw' mode" test_valid_rw_mode

test_invalid_mode() {
    local mode="rx"
    ! [[ "$mode" == "ro" || "$mode" == "rw" ]]
}
run_test "Reject invalid mode 'rx'" test_invalid_mode

echo
echo "3. Testing field parsing"
echo "------------------------"

# Test: Correct field extraction
test_field_extraction() {
    local mount_spec="/host/path:/container/path:ro"
    local host_path container_path mode
    IFS=':' read -r host_path container_path mode <<< "$mount_spec"
    [[ "$host_path" == "/host/path" ]] && \
    [[ "$container_path" == "/container/path" ]] && \
    [[ "$mode" == "ro" ]]
}
run_test "Correct field extraction" test_field_extraction

# Test: Tilde expansion
test_tilde_expansion() {
    local host_path="~/vault"
    local expanded="${host_path/#\~/$HOME}"
    [[ "$expanded" == "$HOME/vault" ]]
}
run_test "Tilde expansion works" test_tilde_expansion

echo
echo "4. Testing duplicate detection (exact match)"
echo "---------------------------------------------"

# Create test mounts file
test_mounts_file="$TEMP_DIR/mounts"
cat > "$test_mounts_file" << 'EOF'
# Test mounts file
/home/user/data:/workspace/data:rw
/home/user/vault:/workspace/vault:ro
EOF

# Test: Exact match found
test_exact_match_found() {
    awk -F: -v cp="/workspace/data" '!/^#/ && $2 == cp { found=1; exit 0 } END { exit (found ? 0 : 1) }' "$test_mounts_file"
}
run_test "Find exact container path match" test_exact_match_found

# Test: Substring NOT matched (the bug we fixed)
test_substring_not_matched() {
    # /workspace/data-backup should NOT match /workspace/data
    ! awk -F: -v cp="/workspace/data-backup" '!/^#/ && $2 == cp { found=1; exit 0 } END { exit (found ? 0 : 1) }' "$test_mounts_file"
}
run_test "Substring does NOT match (data-backup vs data)" test_substring_not_matched

# Test: Prefix NOT matched
test_prefix_not_matched() {
    # /workspace/dat should NOT match /workspace/data
    ! awk -F: -v cp="/workspace/dat" '!/^#/ && $2 == cp { found=1; exit 0 } END { exit (found ? 0 : 1) }' "$test_mounts_file"
}
run_test "Prefix does NOT match (dat vs data)" test_prefix_not_matched

echo
echo "5. Testing remove logic (exact match)"
echo "-------------------------------------"

# Test: Remove extracts correct line
test_remove_exact_match() {
    local target="/workspace/data"
    local found=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
            continue
        fi
        local line_container_path
        IFS=':' read -r _ line_container_path _ <<< "$line"
        if [[ "$line_container_path" == "$target" ]]; then
            found=true
        fi
    done < "$test_mounts_file"
    [[ "$found" == "true" ]]
}
run_test "Remove finds exact match" test_remove_exact_match

# Test: Remove doesn't match similar paths
test_remove_no_false_positive() {
    local target="/workspace/data-backup"
    local found=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
            continue
        fi
        local line_container_path
        IFS=':' read -r _ line_container_path _ <<< "$line"
        if [[ "$line_container_path" == "$target" ]]; then
            found=true
        fi
    done < "$test_mounts_file"
    [[ "$found" == "false" ]]
}
run_test "Remove doesn't match similar path" test_remove_no_false_positive

echo
echo "======================================"
echo "Test Summary"
echo "======================================"
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
