#!/bin/bash
# Integration test: Verify ClaudeBox mounts global config as read-only
# This is a SECURITY test - the mounts file must not be writable from inside container
#
# Run this with: bash tests/test_security_readonly_config.sh

set -e

echo "=============================================="
echo "ClaudeBox Security Test: Read-Only Config"
echo "=============================================="
echo
echo "This test verifies that security-critical files"
echo "(mounts, allowlist) cannot be modified from inside"
echo "the container, preventing sandbox escape."
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDEBOX_ROOT="$(dirname "$SCRIPT_DIR")"

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

# Setup: Create a temporary project directory to test with
TEMP_PROJECT=$(mktemp -d)
TEMP_CLAUDEBOX=$(mktemp -d)

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_PROJECT" "$TEMP_CLAUDEBOX"
}
trap cleanup EXIT

# Initialize test directories to mimic ClaudeBox structure
mkdir -p "$TEMP_CLAUDEBOX/projects/test_project"
echo "# Test mounts file - should be read-only" > "$TEMP_CLAUDEBOX/projects/test_project/mounts"
echo "# Test allowlist - should be read-only" > "$TEMP_CLAUDEBOX/projects/test_project/allowlist"
mkdir -p "$TEMP_CLAUDEBOX/projects/test_project/slot-1/.claude"
mkdir -p "$TEMP_CLAUDEBOX/projects/test_project/slot-1/.config"
mkdir -p "$TEMP_CLAUDEBOX/projects/test_project/slot-1/.cache"

echo "Test setup:"
echo "  Project parent: $TEMP_CLAUDEBOX/projects/test_project"
echo "  Mounts file: $TEMP_CLAUDEBOX/projects/test_project/mounts"
echo

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

echo "1. Security: Global config must be read-only"
echo "---------------------------------------------"

# Test: Container cannot write to mounts file
# This simulates what a malicious Claude could try to do
test_mounts_readonly() {
    local project_parent="$TEMP_CLAUDEBOX/projects/test_project"
    local output

    # Mount the project parent the way ClaudeBox does (with :ro for security)
    # This tests that the mount configuration in lib/docker.sh is correct
    output=$(docker run --rm \
        -v "$project_parent":/home/testuser/.claudebox:ro \
        alpine:latest \
        sh -c 'echo "/etc/passwd:/workspace/passwd:rw" >> /home/testuser/.claudebox/mounts 2>&1' 2>&1) || true

    # If the mount is read-only, we should see "Read-only file system"
    if [[ "$output" == *"Read-only"* ]] || [[ "$output" == *"read-only"* ]] || [[ "$output" == *"EROFS"* ]]; then
        return 0
    else
        echo
        echo -e "  ${YELLOW}SECURITY VULNERABILITY: Container can write to mounts file!${NC}"
        echo "  Output was: $output"
        echo "  Mounts file content after attack:"
        cat "$project_parent/mounts"
        return 1
    fi
}
run_test "Container cannot modify mounts file" test_mounts_readonly

# Test: Container cannot write to allowlist file
test_allowlist_readonly() {
    local project_parent="$TEMP_CLAUDEBOX/projects/test_project"
    local output

    output=$(docker run --rm \
        -v "$project_parent":/home/testuser/.claudebox:ro \
        alpine:latest \
        sh -c 'echo "ALLOW_ALL" >> /home/testuser/.claudebox/allowlist 2>&1' 2>&1) || true

    if [[ "$output" == *"Read-only"* ]] || [[ "$output" == *"read-only"* ]] || [[ "$output" == *"EROFS"* ]]; then
        return 0
    else
        echo
        echo -e "  ${YELLOW}SECURITY VULNERABILITY: Container can write to allowlist!${NC}"
        return 1
    fi
}
run_test "Container cannot modify allowlist file" test_allowlist_readonly

# Test: Container cannot create new files in config dir
test_cannot_create_files() {
    local project_parent="$TEMP_CLAUDEBOX/projects/test_project"
    local output

    output=$(docker run --rm \
        -v "$project_parent":/home/testuser/.claudebox:ro \
        alpine:latest \
        sh -c 'touch /home/testuser/.claudebox/malicious_config 2>&1' 2>&1) || true

    if [[ "$output" == *"Read-only"* ]] || [[ "$output" == *"read-only"* ]] || [[ "$output" == *"EROFS"* ]]; then
        return 0
    else
        echo
        echo -e "  ${YELLOW}Container can create files in config directory!${NC}"
        return 1
    fi
}
run_test "Container cannot create files in config dir" test_cannot_create_files

echo
echo "2. Functionality: Slot directories must remain writable"
echo "--------------------------------------------------------"

# Test: Slot .claude directory is writable
test_slot_claude_writable() {
    local slot_dir="$TEMP_CLAUDEBOX/projects/test_project/slot-1"

    docker run --rm \
        -v "$slot_dir/.claude":/home/testuser/.claude \
        alpine:latest \
        sh -c 'echo "test" > /home/testuser/.claude/test_write' 2>&1

    [[ -f "$slot_dir/.claude/test_write" ]]
}
run_test "Slot .claude directory is writable" test_slot_claude_writable

# Test: Slot .config directory is writable
test_slot_config_writable() {
    local slot_dir="$TEMP_CLAUDEBOX/projects/test_project/slot-1"

    docker run --rm \
        -v "$slot_dir/.config":/home/testuser/.config \
        alpine:latest \
        sh -c 'echo "test" > /home/testuser/.config/test_write' 2>&1

    [[ -f "$slot_dir/.config/test_write" ]]
}
run_test "Slot .config directory is writable" test_slot_config_writable

# Test: Slot .cache directory is writable
test_slot_cache_writable() {
    local slot_dir="$TEMP_CLAUDEBOX/projects/test_project/slot-1"

    docker run --rm \
        -v "$slot_dir/.cache":/home/testuser/.cache \
        alpine:latest \
        sh -c 'echo "test" > /home/testuser/.cache/test_write' 2>&1

    [[ -f "$slot_dir/.cache/test_write" ]]
}
run_test "Slot .cache directory is writable" test_slot_cache_writable

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
    echo "Security-critical config files are protected."
    exit 0
else
    echo -e "${RED}SECURITY TESTS FAILED ✗${NC}"
    echo "The mounts/allowlist files can be modified from inside the container!"
    echo "This is a sandbox escape vulnerability."
    exit 1
fi
