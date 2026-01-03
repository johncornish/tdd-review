#!/bin/bash
# Simple test runner - one test file, one implementation file

source "$(dirname "$0")/lib.sh"

PASS=0
FAIL=0

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $msg"
        ((PASS++))
    else
        echo "  FAIL: $msg"
        echo "    Expected: '$expected'"
        echo "    Actual:   '$actual'"
        ((FAIL++))
    fi
}

run_test() {
    local name="$1"
    echo "TEST: $name"
    "$name"
}

# --- TESTS ---

test_parse_commit_message_extracts_passing_tests() {
    local msg="[TPP] (nil->constant): Return empty list

Tests:
[PASS] test_empty_returns_empty
[PASS] test_single_item

Transformation: (nil->constant)"

    local result
    result=$(parse_test_names "$msg")

    assert_equals "test_empty_returns_empty
test_single_item" "$result" "should extract test names"
}

test_parse_commit_message_extracts_fail_to_pass_tests() {
    local msg="[TPP] (unconditional->if): Add conditional

Tests:
[PASS] test_existing
[FAIL->PASS] test_new_case

Transformation: (unconditional->if)"

    local result
    result=$(parse_test_names "$msg")

    assert_equals "test_existing
test_new_case" "$result" "should extract both PASS and FAIL->PASS"
}

test_parse_config_reads_commit_range() {
    local config_file
    config_file=$(mktemp)
    echo 'COMMIT_RANGE="main..HEAD"' > "$config_file"

    local result
    result=$(parse_config "$config_file" "COMMIT_RANGE")

    assert_equals "main..HEAD" "$result" "should read COMMIT_RANGE"
    rm "$config_file"
}

# --- RUN TESTS ---

echo "=== Running Tests ==="
echo

run_test test_parse_commit_message_extracts_passing_tests
run_test test_parse_commit_message_extracts_fail_to_pass_tests
run_test test_parse_config_reads_commit_range

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
