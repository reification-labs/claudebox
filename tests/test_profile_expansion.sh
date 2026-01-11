#!/bin/bash
# Test script for profile expansion during Dockerfile generation
# This tests that profiles with dependencies (e.g., elixir -> core) are properly expanded

echo "=============================================="
echo "ClaudeBox Profile Expansion Tests"
echo "=============================================="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

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
        echo "  Command: $test_cmd"
        echo "  Error output:"
        eval "$test_cmd" 2>&1 | sed 's/^/    /'
        return 1
    fi
}

# Setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"

# Source the config functions
source "$ROOT_DIR/lib/config.sh"

echo "1. Testing expand_profile() function"
echo "-------------------------------------"

# Test: expand_profile exists
run_test "expand_profile() function exists" "type -t expand_profile | grep -q function"

# Test: elixir expands to include core
run_test "elixir expands to 'core elixir'" '[[ "$(expand_profile elixir)" == "core elixir" ]]'

# Test: rust expands to include core
run_test "rust expands to 'core rust'" '[[ "$(expand_profile rust)" == "core rust" ]]'

# Test: go expands to include core
run_test "go expands to 'core go'" '[[ "$(expand_profile go)" == "core go" ]]'

# Test: c expands to include core and build-tools
run_test "c expands to 'core build-tools c'" '[[ "$(expand_profile c)" == "core build-tools c" ]]'

# Test: core stays as just core (no infinite recursion)
run_test "core stays as 'core'" '[[ "$(expand_profile core)" == "core" ]]'

echo
echo "2. Testing main.sh calls expand_profile()"
echo "-------------------------------------------"

# Test: main.sh must call expand_profile when generating Dockerfile
run_test "main.sh calls expand_profile()" 'grep -q "expand_profile" "$ROOT_DIR/main.sh"'

echo
echo "3. Testing profile expansion in Dockerfile generation"
echo "------------------------------------------------------"

# Create a temporary directory structure to test
TEMP_DIR=$(mktemp -d)
TEMP_PROJECT="$TEMP_DIR/test_project"
TEMP_CLAUDEBOX="$TEMP_PROJECT/.claudebox"
mkdir -p "$TEMP_CLAUDEBOX"

# Create a profiles.ini with just 'elixir'
cat > "$TEMP_CLAUDEBOX/profiles.ini" << 'EOF'
[profiles]
elixir
EOF

# Simulate the profile expansion logic from main.sh
simulate_expansion() {
    local profiles_file="$1"
    local expanded_profiles=()
    local seen_profiles=""
    local current_profiles=()

    # Read profiles from file
    while IFS= read -r line; do
        [[ -n "$line" ]] && current_profiles+=("$line")
    done < <(read_profile_section "$profiles_file" "profiles")

    # Expand profiles
    for profile in "${current_profiles[@]}"; do
        profile=$(echo "$profile" | tr -d '[:space:]')
        [[ -z "$profile" ]] && continue

        local expanded
        expanded=$(expand_profile "$profile")
        for exp_profile in $expanded; do
            if [[ " $seen_profiles " != *" $exp_profile "* ]]; then
                expanded_profiles+=("$exp_profile")
                seen_profiles+=" $exp_profile "
            fi
        done
    done

    echo "${expanded_profiles[*]}"
}

# Test: profiles.ini with 'elixir' expands to include 'core'
EXPANDED=$(simulate_expansion "$TEMP_CLAUDEBOX/profiles.ini")
run_test "profiles.ini 'elixir' expands to include 'core'" '[[ "$EXPANDED" == "core elixir" ]]'

# Test: core profile includes 'make' (needed for NIFs)
CORE_PACKAGES=$(get_profile_packages "core")
run_test "core profile includes 'make'" 'echo "$CORE_PACKAGES" | grep -q "make"'

# Test: core profile includes 'gcc' (needed for NIFs)
run_test "core profile includes 'gcc'" 'echo "$CORE_PACKAGES" | grep -q "gcc"'

# Test: multiple profiles deduplicate correctly
cat > "$TEMP_CLAUDEBOX/profiles.ini" << 'EOF'
[profiles]
elixir
rust
EOF
EXPANDED=$(simulate_expansion "$TEMP_CLAUDEBOX/profiles.ini")
# Should be "core elixir rust" - core only appears once
CORE_COUNT=$(echo "$EXPANDED" | tr ' ' '\n' | grep -c "^core$")
run_test "multiple profiles deduplicate 'core'" '[[ "$CORE_COUNT" -eq 1 ]]'

# Cleanup
rm -rf "$TEMP_DIR"

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
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
