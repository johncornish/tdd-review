#!/bin/bash
# Simple test runner - one test file, one implementation file

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

PASS=0
FAIL=0

# Colors
GREEN='\033[32m'
RED='\033[31m'
NC='\033[0m'

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}PASS${NC}: $msg"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC}: $msg"
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

test_add_and_get_note() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first"
    local sha
    sha=$(git rev-parse HEAD)

    add_note "$sha" "TPP violation" "commit too large"
    local result
    result=$(get_note "$sha")

    assert_equals "TPP violation: commit too large" "$result" "should store and retrieve note"

    cd /
    rm -rf "$test_repo"
}

test_get_test_command_for_file_maps_extensions() {
    assert_equals "npm test" "$(get_test_command_for_file "app.js")" "js -> npm test"
    assert_equals "npm test" "$(get_test_command_for_file "component.tsx")" "tsx -> npm test"
    assert_equals "pytest" "$(get_test_command_for_file "test_main.py")" "py -> pytest"
    assert_equals "./test.sh" "$(get_test_command_for_file "lib.sh")" "sh -> ./test.sh"
    assert_equals "" "$(get_test_command_for_file "README.md")" "md -> empty"
}

test_run_tests_for_commit_no_testable_files() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    # Create commit with only non-testable file
    echo "# README" > README.md && git add . && git commit -q -m "docs only"
    local sha
    sha=$(git rev-parse HEAD)

    # Should return 0 and produce no output
    local result
    result=$(run_tests_for_commit "$sha" 2>&1)
    local status=$?

    assert_equals "0" "$status" "should return 0 for no testable files"
    assert_equals "" "$result" "should produce no output"

    cd /
    rm -rf "$test_repo"
}

test_run_tests_for_commit_runs_full_suite() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    # Create a simple test script
    echo 'echo "tests passed"' > test.sh
    chmod +x test.sh
    git add . && git commit -q -m "add test"
    local sha
    sha=$(git rev-parse HEAD)

    # Run with full=true
    local result
    result=$(run_tests_for_commit "$sha" true 2>&1)

    [[ "$result" == *"tests passed"* ]] || { echo -e "  ${RED}FAIL${NC}: should run tests"; ((FAIL++)); cd /; rm -rf "$test_repo"; return; }
    echo -e "  ${GREEN}PASS${NC}: runs full test suite"
    ((PASS++))

    cd /
    rm -rf "$test_repo"
}

test_process_command_T_runs_full_suite() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo 'echo "full suite ran"' > test.sh
    chmod +x test.sh
    git add . && git commit -q -m "add test"

    COMMITS=($(git rev-list HEAD))
    CURRENT=0

    local result
    result=$(process_command "T" 2>&1)

    [[ "$result" == *"full suite ran"* ]] || { echo -e "  ${RED}FAIL${NC}: T should run full test suite"; ((FAIL++)); cd /; rm -rf "$test_repo"; return; }
    echo -e "  ${GREEN}PASS${NC}: T runs full test suite"
    ((PASS++))

    cd /
    rm -rf "$test_repo"
}

test_checkout_commit_switches_to_sha() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first"
    local sha1
    sha1=$(git rev-parse HEAD)
    echo "b" > file.txt && git add . && git commit -q -m "second"

    # Checkout first commit
    checkout_commit "$sha1"

    local current
    current=$(git rev-parse HEAD)
    assert_equals "$sha1" "$current" "should checkout to specified SHA"

    cd /
    rm -rf "$test_repo"
}

test_display_commit_shows_message_and_files() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "initial"
    echo "b" > feature.txt && git add . && git commit -q -m "add feature"
    local sha
    sha=$(git rev-parse HEAD)

    local result
    result=$(display_commit "$sha")

    # Should contain message and files
    [[ "$result" == *"add feature"* ]] || { echo -e "  ${RED}FAIL${NC}: missing commit message"; ((FAIL++)); return; }
    [[ "$result" == *"feature.txt"* ]] || { echo -e "  ${RED}FAIL${NC}: missing changed files"; ((FAIL++)); return; }
    echo -e "  ${GREEN}PASS${NC}: shows message and files"
    ((PASS++))

    cd /
    rm -rf "$test_repo"
}

test_process_command_quit_returns_exit() {
    # When
    process_command "q"
    local status=$?

    # Then
    assert_equals "1" "$status" "quit should return 1 (exit)"
}

test_process_command_next_increments_current() {
    # Given
    COMMITS=(sha1 sha2 sha3)
    CURRENT=0

    # When
    process_command "n"

    # Then
    assert_equals "1" "$CURRENT" "CURRENT should increment"
}

test_process_command_next_at_end_stays_put() {
    # Given
    COMMITS=(sha1 sha2)
    CURRENT=1

    # When
    process_command "n"

    # Then
    assert_equals "1" "$CURRENT" "CURRENT should not exceed bounds"
}

test_process_command_prev_decrements_current() {
    # Given
    COMMITS=(sha1 sha2 sha3)
    CURRENT=2

    # When
    process_command "p"

    # Then
    assert_equals "1" "$CURRENT" "CURRENT should decrement"
}

test_process_command_prev_at_start_stays_put() {
    # Given
    COMMITS=(sha1 sha2)
    CURRENT=0

    # When
    process_command "p"

    # Then
    assert_equals "0" "$CURRENT" "CURRENT should not go below 0"
}

test_process_command_help_shows_commands() {
    # When
    local result
    result=$(process_command "h" 2>&1)

    # Then
    [[ "$result" == *"next"* ]] || { echo -e "  ${RED}FAIL${NC}: help missing 'next'"; ((FAIL++)); return; }
    [[ "$result" == *"quit"* ]] || { echo -e "  ${RED}FAIL${NC}: help missing 'quit'"; ((FAIL++)); return; }
    echo -e "  ${GREEN}PASS${NC}: help shows commands"
    ((PASS++))
}

test_main_next_checks_out_commit() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first commit"
    local sha1
    sha1=$(git rev-parse HEAD)
    echo "b" > file.txt && git add . && git commit -q -m "second commit"
    local sha2
    sha2=$(git rev-parse HEAD)

    # Start at first commit
    git checkout -q "$sha1"

    # File should be "a" before navigation
    local before
    before=$(cat file.txt)
    assert_equals "a" "$before" "file should be 'a' before navigation"

    printf "n\nq\n" | bash -c "
        source '$SCRIPT_DIR/lib.sh'
        COMMITS=($sha1 $sha2)
        CURRENT=0
        main_loop
    " 2>&1

    # After 'n', file should be "b" (checked out second commit)
    local after
    after=$(cat file.txt)
    assert_equals "b" "$after" "file should be 'b' after navigating to second commit"

    cd /
    rm -rf "$test_repo"
}

test_main_next_advances_commit() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first commit"
    echo "b" > file.txt && git add . && git commit -q -m "second commit"

    local result
    result=$(printf "n\nq\n" | bash -c "
        source '$SCRIPT_DIR/lib.sh'
        COMMITS=(\$(git rev-list --reverse HEAD))
        CURRENT=0
        main_loop
    " 2>&1)

    [[ "$result" == *"second"* ]] || { echo -e "  ${RED}FAIL${NC}: next should show second commit"; ((FAIL++)); cd /; rm -rf "$test_repo"; return; }
    echo -e "  ${GREEN}PASS${NC}: next advances to next commit"
    ((PASS++))

    cd /
    rm -rf "$test_repo"
}

test_main_prev_checks_out_commit() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first commit"
    local sha1
    sha1=$(git rev-parse HEAD)
    echo "b" > file.txt && git add . && git commit -q -m "second commit"
    local sha2
    sha2=$(git rev-parse HEAD)

    # Start at second commit
    # File should be "b" before navigation
    local before
    before=$(cat file.txt)
    assert_equals "b" "$before" "file should be 'b' before navigation"

    printf "p\nq\n" | bash -c "
        source '$SCRIPT_DIR/lib.sh'
        COMMITS=($sha1 $sha2)
        CURRENT=1
        main_loop
    " 2>&1

    # After 'p', file should be "a" (checked out first commit)
    local after
    after=$(cat file.txt)
    assert_equals "a" "$after" "file should be 'a' after navigating to first commit"

    cd /
    rm -rf "$test_repo"
}

test_main_prev_goes_back() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first commit"
    echo "b" > file.txt && git add . && git commit -q -m "second commit"

    local result
    result=$(printf "n\np\nq\n" | bash -c "
        source '$SCRIPT_DIR/lib.sh'
        COMMITS=(\$(git rev-list --reverse HEAD))
        CURRENT=0
        main_loop
    " 2>&1)

    # After n, p - should be back at first
    [[ "$result" == *"first"* ]] || { echo -e "  ${RED}FAIL${NC}: prev should show first commit"; ((FAIL++)); cd /; rm -rf "$test_repo"; return; }
    echo -e "  ${GREEN}PASS${NC}: prev goes back to previous commit"
    ((PASS++))

    cd /
    rm -rf "$test_repo"
}

test_squash_range_combines_commits() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "initial"
    echo "b" > file.txt && git add . && git commit -q -m "second"
    echo "c" > file.txt && git add . && git commit -q -m "third"

    # Count before: 3 commits
    local before
    before=$(git rev-list --count HEAD)

    squash_range "HEAD~2..HEAD" "squashed commits"

    # Count after: 2 commits (initial + squashed)
    local after
    after=$(git rev-list --count HEAD)

    assert_equals "3" "$before" "should have 3 commits before"
    assert_equals "2" "$after" "should have 2 commits after squash"

    # Check the message
    local msg
    msg=$(git log -1 --format=%s)
    assert_equals "squashed commits" "$msg" "should have squash message"

    cd /
    rm -rf "$test_repo"
}

test_aggregate_feedback_compiles_notes() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    # Need 3 commits so range HEAD~2..HEAD includes 2 commits
    echo "a" > file.txt && git add . && git commit -q -m "initial"

    echo "b" > file.txt && git add . && git commit -q -m "first flagged"
    local sha1
    sha1=$(git rev-parse HEAD)
    add_note "$sha1" "TPP violation" "used switch case"

    echo "c" > file.txt && git add . && git commit -q -m "second commit"
    local sha2
    sha2=$(git rev-parse HEAD)
    add_note "$sha2" "commit too large" "combined two transformations"

    local result
    result=$(aggregate_feedback "HEAD~2..HEAD")

    [[ "$result" == *"TPP violation"* ]] || { echo -e "  ${RED}FAIL${NC}: missing first note category"; ((FAIL++)); cd /; rm -rf "$test_repo"; return; }
    [[ "$result" == *"used switch case"* ]] || { echo -e "  ${RED}FAIL${NC}: missing first note message"; ((FAIL++)); cd /; rm -rf "$test_repo"; return; }
    [[ "$result" == *"commit too large"* ]] || { echo -e "  ${RED}FAIL${NC}: missing second note category"; ((FAIL++)); cd /; rm -rf "$test_repo"; return; }
    [[ "$result" == *"second commit"* ]] || { echo -e "  ${RED}FAIL${NC}: missing commit message"; ((FAIL++)); cd /; rm -rf "$test_repo"; return; }
    echo -e "  ${GREEN}PASS${NC}: aggregates all notes with context"
    ((PASS++))

    cd /
    rm -rf "$test_repo"
}

test_main_flag_shows_prompts() {
    local result
    result=$(printf "f\ncat\nmsg\nq\n" | bash -c "
        source '$SCRIPT_DIR/lib.sh'
        COMMITS=(abc123)
        CURRENT=0
        main_loop
    " 2>&1)

    [[ "$result" == *"Category:"* ]] || { echo -e "  ${RED}FAIL${NC}: should prompt for category"; ((FAIL++)); return; }
    [[ "$result" == *"Message:"* ]] || { echo -e "  ${RED}FAIL${NC}: should prompt for message"; ((FAIL++)); return; }
    echo -e "  ${GREEN}PASS${NC}: flag shows prompts"
    ((PASS++))
}

test_main_flag_adds_note() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first commit"
    local sha
    sha=$(git rev-parse HEAD)

    # Flag with "TPP violation" category and "too large" message
    printf "f\nTPP violation\ntoo large\nq\n" | bash -c "
        source '$SCRIPT_DIR/lib.sh'
        COMMITS=(\$(git rev-list --reverse HEAD))
        CURRENT=0
        main_loop
    " 2>&1

    local note
    note=$(git notes --ref=tdd-review show "$sha" 2>/dev/null)

    assert_equals "TPP violation: too large" "$note" "flag should add git note"

    cd /
    rm -rf "$test_repo"
}

test_main_drop_asks_confirmation() {
    local result
    result=$(printf "d\nn\nq\n" | bash -c "
        source '$SCRIPT_DIR/lib.sh'
        COMMITS=(a b c)
        CURRENT=0
        main_loop
    " 2>&1)

    [[ "$result" == *"drop"* ]] || { echo -e "  ${RED}FAIL${NC}: should mention drop"; ((FAIL++)); return; }
    [[ "$result" == *"2"* ]] || { echo -e "  ${RED}FAIL${NC}: should show count of commits to drop"; ((FAIL++)); return; }
    echo -e "  ${GREEN}PASS${NC}: drop asks for confirmation"
    ((PASS++))
}

test_main_squash_to_current() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first"
    echo "b" > file.txt && git add . && git commit -q -m "second"
    echo "c" > file.txt && git add . && git commit -q -m "third"
    echo "d" > file.txt && git add . && git commit -q -m "fourth"

    # Navigate to commit 2 (index 1), then squash up to there
    printf "n\ns\nSquashed first two\nq\n" | bash -c "
        source '$SCRIPT_DIR/lib.sh'
        COMMITS=(\$(git rev-list --reverse HEAD))
        CURRENT=0
        main_loop
    " 2>&1

    # Should now have 3 commits: squashed + third + fourth
    local count
    count=$(git rev-list --count HEAD)
    assert_equals "3" "$count" "should have 3 commits after squash"

    # First commit message should be the squash message
    local msg
    msg=$(git log --reverse --format=%s | head -1)
    assert_equals "Squashed first two" "$msg" "should have squash message"

    cd /
    rm -rf "$test_repo"
}

test_main_drop_with_yes_resets() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first"
    echo "b" > file.txt && git add . && git commit -q -m "second"
    echo "c" > file.txt && git add . && git commit -q -m "third"

    local sha1
    sha1=$(git rev-list --reverse HEAD | head -1)

    # Navigate to first commit, then drop remaining
    printf "d\ny\n" | bash -c "
        source '$SCRIPT_DIR/lib.sh'
        COMMITS=(\$(git rev-list --reverse HEAD))
        CURRENT=0
        main_loop
    " 2>&1

    # Should now only have 1 commit
    local count
    count=$(git rev-list --count HEAD)
    assert_equals "1" "$count" "should have dropped to 1 commit"

    cd /
    rm -rf "$test_repo"
}

test_tdd_review_restores_head_on_quit() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first"
    echo "b" > file.txt && git add . && git commit -q -m "second"
    echo "c" > file.txt && git add . && git commit -q -m "third"

    local original_head
    original_head=$(git rev-parse HEAD)
    local original_file
    original_file=$(cat file.txt)
    assert_equals "c" "$original_file" "file should be 'c' before review"

    # Navigate forward from first commit, HEAD changes
    printf "n\nq\n" | "$SCRIPT_DIR/tdd-review" HEAD 2>&1

    # After review, HEAD should be restored
    local after_file
    after_file=$(cat file.txt)
    assert_equals "c" "$after_file" "file should be 'c' after quit (HEAD restored)"

    cd /
    rm -rf "$test_repo"
}

test_tdd_review_reads_config_file() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first commit"
    echo "b" > file.txt && git add . && git commit -q -m "second commit"

    # Create config file
    echo 'COMMIT_RANGE="HEAD"' > .tdd-review.conf

    # Run without arguments - should read from config
    local result
    result=$(printf "q\n" | "$SCRIPT_DIR/tdd-review" 2>&1)

    [[ "$result" == *"first commit"* ]] || { echo -e "  ${RED}FAIL${NC}: should read range from config"; ((FAIL++)); cd /; rm -rf "$test_repo"; return; }
    echo -e "  ${GREEN}PASS${NC}: reads commit range from config file"
    ((PASS++))

    cd /
    rm -rf "$test_repo"
}

test_tdd_review_binary_runs() {
    local test_repo
    test_repo=$(mktemp -d)
    cd "$test_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first commit"
    echo "b" > file.txt && git add . && git commit -q -m "second commit"

    # Run the binary with quit command
    local result
    result=$(printf "q\n" | "$SCRIPT_DIR/tdd-review" HEAD 2>&1)

    # Should show the first commit on startup
    [[ "$result" == *"first commit"* ]] || { echo -e "  ${RED}FAIL${NC}: should display first commit on startup"; ((FAIL++)); cd /; rm -rf "$test_repo"; return; }
    echo -e "  ${GREEN}PASS${NC}: binary runs and displays first commit"
    ((PASS++))

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
run_test test_add_and_get_note
run_test test_get_test_command_for_file_maps_extensions
run_test test_run_tests_for_commit_no_testable_files
run_test test_run_tests_for_commit_runs_full_suite
run_test test_process_command_T_runs_full_suite
run_test test_checkout_commit_switches_to_sha
run_test test_squash_range_combines_commits
run_test test_aggregate_feedback_compiles_notes
run_test test_display_commit_shows_message_and_files
run_test test_process_command_quit_returns_exit
run_test test_process_command_next_increments_current
run_test test_process_command_next_at_end_stays_put
run_test test_process_command_prev_decrements_current
run_test test_process_command_prev_at_start_stays_put
run_test test_process_command_help_shows_commands
run_test test_main_next_checks_out_commit
run_test test_main_next_advances_commit
run_test test_main_prev_checks_out_commit
run_test test_main_prev_goes_back
run_test test_main_flag_shows_prompts
run_test test_main_flag_adds_note
run_test test_main_drop_asks_confirmation
run_test test_main_squash_to_current
run_test test_main_drop_with_yes_resets
run_test test_tdd_review_restores_head_on_quit
run_test test_tdd_review_reads_config_file
run_test test_tdd_review_binary_runs

echo
echo -e "=== Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC} ==="
exit $FAIL
