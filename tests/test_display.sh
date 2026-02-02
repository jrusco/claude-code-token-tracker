#!/usr/bin/env bash
#
# test_display.sh - Unit tests for display.sh
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source modules
source "${PROJECT_DIR}/lib/utils.sh"
source "${PROJECT_DIR}/lib/config.sh"
source "${PROJECT_DIR}/lib/parser.sh"
source "${PROJECT_DIR}/lib/display.sh"

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

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: $message"
        echo "  Expected to contain: $needle"
        echo "  Actual: $haystack"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------

echo "Running display tests..."
echo ""

# Test: get_usage_color
# Note: get_usage_color returns the escape sequence after echo -e processing
# so we compare by checking which color code is in the output
echo "Testing get_usage_color..."

# Helper to extract color code number from ANSI escape sequence
extract_color_code() {
    # Extract the number after [0; from the escape sequence
    echo "$1" | sed 's/.*\[0;\([0-9]*\)m.*/\1/'
}

color=$(get_usage_color 10)
color_code=$(extract_color_code "$color")
assert_eq "32" "$color_code" "Low usage returns green (code 32)"

color=$(get_usage_color 50)
color_code=$(extract_color_code "$color")
assert_eq "33" "$color_code" "Medium usage returns yellow (code 33)"

color=$(get_usage_color 90)
color_code=$(extract_color_code "$color")
assert_eq "31" "$color_code" "High usage returns red (code 31)"

color=$(get_usage_color 24)
color_code=$(extract_color_code "$color")
assert_eq "32" "$color_code" "24% usage returns green (boundary)"

color=$(get_usage_color 25)
color_code=$(extract_color_code "$color")
assert_eq "33" "$color_code" "25% usage returns yellow (boundary)"

color=$(get_usage_color 74)
color_code=$(extract_color_code "$color")
assert_eq "33" "$color_code" "74% usage returns yellow (boundary)"

color=$(get_usage_color 75)
color_code=$(extract_color_code "$color")
assert_eq "31" "$color_code" "75% usage returns red (boundary)"

echo ""

# Test: draw_hline
echo "Testing draw_hline..."
line=$(draw_hline 5)
assert_eq "-----" "$line" "Horizontal line draws correctly"

line=$(draw_hline 3 "=")
assert_eq "===" "$line" "Custom character works"

echo ""

# Test: draw_box_top
echo "Testing draw_box_top..."
top=$(draw_box_top 10)
assert_contains "+" "$top" "Box top contains corner"
assert_contains "--------" "$top" "Box top contains line"

echo ""

# Test: format_currency
echo "Testing format_currency..."
currency=$(format_currency 0.42)
assert_eq "\$0.42" "$currency" "Currency formatted correctly"

currency=$(format_currency 1.5)
assert_eq "\$1.50" "$currency" "Currency padded with zeros"

currency=$(format_currency 0)
assert_eq "\$0.00" "$currency" "Zero formatted correctly"

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
