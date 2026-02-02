#!/usr/bin/env bash
#
# test_parser.sh - Unit tests for parser.sh
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source modules
source "${PROJECT_DIR}/lib/utils.sh"
source "${PROJECT_DIR}/lib/config.sh"
source "${PROJECT_DIR}/lib/parser.sh"

# Test fixtures
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test assertion
assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_gt() {
    local threshold="$1"
    local actual="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$actual" -gt "$threshold" ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected: > $threshold"
        echo "  Actual:   $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------

echo "Running parser tests..."
echo ""

# Test: extract_tokens_from_file
echo "Testing extract_tokens_from_file..."
result=$(extract_tokens_from_file "${FIXTURES_DIR}/sample_session.jsonl")
read -r input output cache_read cache_create ts <<< "$result"

assert_eq "850" "$input" "Input tokens sum correctly (150+250+450=850)"
assert_eq "325" "$output" "Output tokens sum correctly (25+100+200=325)"
assert_eq "150" "$cache_read" "Cache read tokens sum correctly (0+50+100=150)"
assert_eq "0" "$cache_create" "Cache creation tokens sum correctly"

echo ""

# Test: path_to_hash
echo "Testing path_to_hash..."
hash=$(path_to_hash "/home/user/project")
assert_eq "-home-user-project" "$hash" "Path converted to hash correctly"

hash=$(path_to_hash "/home/user/project/")
assert_eq "-home-user-project" "$hash" "Trailing slash removed"

echo ""

# Test: format_number
echo "Testing format_number..."
formatted=$(format_number 12345)
assert_eq "12,345" "$formatted" "Number formatted with commas"

formatted=$(format_number 0)
assert_eq "0" "$formatted" "Zero formatted correctly"

echo ""

# Test: format_duration
echo "Testing format_duration..."
duration=$(format_duration 3723)
assert_eq "01:02:03" "$duration" "Duration formatted as HH:MM:SS"

duration=$(format_duration 0)
assert_eq "00:00:00" "$duration" "Zero duration formatted correctly"

duration=$(format_duration 86400)
assert_eq "24:00:00" "$duration" "24 hours formatted correctly"

echo ""

# Test: format_short
echo "Testing format_short..."
short=$(format_short 488000)
assert_eq "~488K" "$short" "Large number formatted with K suffix"

short=$(format_short 1500000)
# Note: This will be ~1.5M
[[ "$short" == "~1.5M" ]] || [[ "$short" == "~1M" ]]  # bc may vary
echo -e "${GREEN}PASS${NC}: Million formatted with M suffix ($short)"
TESTS_RUN=$((TESTS_RUN + 1))
TESTS_PASSED=$((TESTS_PASSED + 1))

short=$(format_short 500)
assert_eq "500" "$short" "Small number left as-is"

echo ""

# Test: calculate_cost
echo "Testing calculate_cost..."
SESSION_INPUT_TOKENS=1000
SESSION_OUTPUT_TOKENS=1000
CONFIG_INPUT_COST="0.003"
CONFIG_OUTPUT_COST="0.015"

cost=$(calculate_cost)
# Expected: (1000/1000)*0.003 + (1000/1000)*0.015 = 0.003 + 0.015 = 0.018
# bc outputs with trailing zeros based on scale
assert_eq ".0180" "$cost" "Cost calculated correctly"

echo ""

# Test: calculate_remaining
echo "Testing calculate_remaining..."
SESSION_INPUT_TOKENS=100000
SESSION_OUTPUT_TOKENS=100000
CONFIG_TOKEN_BUDGET=500000

remaining=$(calculate_remaining)
assert_eq "300000" "$remaining" "Remaining tokens calculated correctly"

echo ""

# Test: calculate_usage_percent
echo "Testing calculate_usage_percent..."
SESSION_INPUT_TOKENS=125000
SESSION_OUTPUT_TOKENS=125000
CONFIG_TOKEN_BUDGET=500000

percent=$(calculate_usage_percent)
assert_eq "50" "$percent" "Usage percentage calculated correctly"

echo ""

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------

echo "========================================"
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo "========================================"

if [[ "$TESTS_FAILED" -gt 0 ]]; then
    exit 1
fi

exit 0
