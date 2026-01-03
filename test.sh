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

test_get_commits_lists_commits_in_range() {
    # Create temp repo
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    # Create commits
    echo "a" > file.txt && git add . && git commit -q -m "first"
    echo "b" > file.txt && git add . && git commit -q -m "second"
    echo "c" > file.txt && git add . && git commit -q -m "third"

    local result
    result=$(get_commits "HEAD~2..HEAD" | wc -l)

    assert_equals "2" "$result" "should list 2 commits"

    # Cleanup
    cd /
    rm -rf "$test_repo"
}

test_get_commit_message() {
    # Create temp repo
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "my commit message"
    local sha
    sha=$(git rev-parse HEAD)

    local result
    result=$(get_commit_message "$sha")

    assert_equals "my commit message" "$result" "should return commit message"

    cd /
    rm -rf "$test_repo"
}

test_get_changed_files() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file1.txt && git add . && git commit -q -m "first"
    echo "b" > file2.txt && echo "c" > file3.txt && git add . && git commit -q -m "add two files"
    local sha
    sha=$(git rev-parse HEAD)

    local result
    result=$(get_changed_files "$sha")

    assert_equals "file2.txt
file3.txt" "$result" "should list changed files"

    cd /
    rm -rf "$test_repo"
}

# --- RUN TESTS ---

echo "=== Running Tests ==="
echo

run_test test_parse_commit_message_extracts_passing_tests
run_test test_parse_commit_message_extracts_fail_to_pass_tests
run_test test_parse_config_reads_commit_range
run_test test_get_commits_lists_commits_in_range
run_test test_get_commit_message
run_test test_get_changed_files

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
