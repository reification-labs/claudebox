#!/bin/bash
# Integration test: Verify read-only mounts are enforced by Docker
# Run this with: bash tests/test_mount_readonly.sh
#
# This test creates a temporary directory, mounts it as :ro inside a
# container, and verifies that write attempts fail with EROFS.

set -e

echo "=============================================="
echo "ClaudeBox Mount Read-Only Integration Test"
echo "=============================================="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Skipping integration tests.${NC}"
    exit 0
fi

# Check Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker daemon not running. Skipping integration tests.${NC}"
    exit 0
fi

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Setup
TEMP_DIR=$(mktemp -d)
TEST_FILE="$TEMP_DIR/test_file.txt"
echo "original content" > "$TEST_FILE"

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

    if eval "$test_cmd"; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

echo "Test directory: $TEMP_DIR"
echo

echo "1. Testing Docker :ro mount enforcement"
echo "----------------------------------------"

# Test: Read-only mount prevents writes
test_ro_prevents_write() {
    # Mount temp dir as :ro and try to write - should fail
    local output
    output=$(docker run --rm \
        -v "$TEMP_DIR:/test:ro" \
        alpine:latest \
        sh -c 'echo "modified" > /test/test_file.txt 2>&1' 2>&1) || true

    # Should contain "Read-only file system" or similar
    [[ "$output" == *"Read-only"* ]] || [[ "$output" == *"read-only"* ]] || [[ "$output" == *"EROFS"* ]]
}
run_test "Read-only mount prevents file modification" test_ro_prevents_write

# Test: Read-only mount allows reads
test_ro_allows_read() {
    local output
    output=$(docker run --rm \
        -v "$TEMP_DIR:/test:ro" \
        alpine:latest \
        cat /test/test_file.txt 2>&1)

    [[ "$output" == "original content" ]]
}
run_test "Read-only mount allows file reading" test_ro_allows_read

# Test: Read-only mount prevents new file creation
test_ro_prevents_create() {
    local output
    output=$(docker run --rm \
        -v "$TEMP_DIR:/test:ro" \
        alpine:latest \
        sh -c 'touch /test/new_file.txt 2>&1' 2>&1) || true

    [[ "$output" == *"Read-only"* ]] || [[ "$output" == *"read-only"* ]] || [[ "$output" == *"EROFS"* ]]
}
run_test "Read-only mount prevents file creation" test_ro_prevents_create

# Test: Read-only mount prevents deletion
test_ro_prevents_delete() {
    local output
    output=$(docker run --rm \
        -v "$TEMP_DIR:/test:ro" \
        alpine:latest \
        sh -c 'rm /test/test_file.txt 2>&1' 2>&1) || true

    [[ "$output" == *"Read-only"* ]] || [[ "$output" == *"read-only"* ]] || [[ "$output" == *"EROFS"* ]]
}
run_test "Read-only mount prevents file deletion" test_ro_prevents_delete

echo
echo "2. Testing Docker :rw mount allows writes"
echo "------------------------------------------"

# Test: Read-write mount allows writes
test_rw_allows_write() {
    docker run --rm \
        -v "$TEMP_DIR:/test:rw" \
        alpine:latest \
        sh -c 'echo "modified by docker" > /test/rw_test.txt'

    # Verify file was created on host
    [[ -f "$TEMP_DIR/rw_test.txt" ]] && \
    [[ "$(cat "$TEMP_DIR/rw_test.txt")" == "modified by docker" ]]
}
run_test "Read-write mount allows file creation" test_rw_allows_write

echo
echo "3. Verifying original file unchanged after :ro tests"
echo "-----------------------------------------------------"

test_original_unchanged() {
    [[ "$(cat "$TEST_FILE")" == "original content" ]]
}
run_test "Original file content preserved" test_original_unchanged

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
    echo "Docker correctly enforces :ro mount permissions."
    exit 0
else
    echo -e "${RED}Some tests failed ✗${NC}"
    exit 1
fi
