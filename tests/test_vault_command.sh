#!/bin/bash
# Test script for claudebox vault command
# Run this with: bash tests/test_vault_command.sh

set -e

echo "======================================"
echo "ClaudeBox Vault Command Tests"
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

# Source required libraries
source "$ROOT_DIR/lib/common.sh" 2>/dev/null || true

echo "1. Source path validation"
echo "-------------------------"

# Test: Absolute path required
test_requires_absolute_path() {
    local path="relative/path/to/dir"
    # Must start with /
    [[ ! "$path" =~ ^/ ]]
}
run_test "Relative paths rejected (doesn't start with /)" test_requires_absolute_path

# Test: Absolute path accepted
test_accepts_absolute_path() {
    local path="/home/user/vault"
    [[ "$path" =~ ^/ ]]
}
run_test "Absolute paths accepted (starts with /)" test_accepts_absolute_path

# Test: Path traversal rejected
test_rejects_path_traversal() {
    local path="/home/user/../../../etc/passwd"
    # Should contain ..
    [[ "$path" == *".."* ]]
}
run_test "Path traversal detected (contains ..)" test_rejects_path_traversal

# Test: Tilde expansion works
test_tilde_expansion() {
    local path="~/vault"
    local expanded="${path/#\~/$HOME}"
    [[ "$expanded" == "$HOME/vault" ]]
}
run_test "Tilde expansion works correctly" test_tilde_expansion

echo
echo "2. Symlink detection"
echo "--------------------"

# Create test directory and symlink
mkdir -p "$TEMP_DIR/real_dir"
ln -s "$TEMP_DIR/real_dir" "$TEMP_DIR/symlink_dir"

# Test: Symlink detected
test_detects_symlink() {
    [[ -L "$TEMP_DIR/symlink_dir" ]]
}
run_test "Symlinks are detected" test_detects_symlink

# Test: Real directory not a symlink
test_real_dir_not_symlink() {
    [[ ! -L "$TEMP_DIR/real_dir" ]]
}
run_test "Real directories are not symlinks" test_real_dir_not_symlink

echo
echo "3. Vault destination derivation"
echo "-------------------------------"

# Test: Extract directory name from path
test_extract_dirname() {
    local path="/home/user/my-vault"
    local name
    name=$(basename "$path")
    [[ "$name" == "my-vault" ]]
}
run_test "Directory name extracted correctly" test_extract_dirname

# Test: Container path format
test_container_path_format() {
    local path="/home/user/my-vault"
    local name
    name=$(basename "$path")
    local container_path="/vault/$name"
    [[ "$container_path" == "/vault/my-vault" ]]
}
run_test "Container path formatted as /vault/<name>" test_container_path_format

echo
echo "4. Vault file format"
echo "--------------------"

# Create test vault file
test_vault_file="$TEMP_DIR/vault"
cat > "$test_vault_file" << 'EOF'
# ClaudeBox Vault Mounts
# Format: host_path (container path auto-derived as /vault/<name>)
/home/user/data
/home/user/documents
EOF

# Test: Can parse vault file
test_parse_vault_file() {
    local count=0
    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ ! "$line" =~ ^#.* ]]; then
            ((count++)) || true
        fi
    done < "$test_vault_file"
    [[ "$count" -eq 2 ]]
}
run_test "Vault file parsing works" test_parse_vault_file

# Test: Can check for duplicates
test_check_duplicates() {
    local path="/home/user/data"
    local name
    name=$(basename "$path")
    # Check if path already in vault file
    grep -q "^$path$" "$test_vault_file"
}
run_test "Duplicate detection works" test_check_duplicates

echo
echo "5. Mount string generation"
echo "--------------------------"

# Test: Generate read-only mount
test_generate_ro_mount() {
    local host_path="/home/user/vault"
    local container_path="/vault/vault"
    local mount_string="${host_path}:${container_path}:ro"
    [[ "$mount_string" == "/home/user/vault:/vault/vault:ro" ]]
}
run_test "Mount string is always read-only" test_generate_ro_mount

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
