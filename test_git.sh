#!/bin/bash
# Learning tests for git squash behavior

PASS=0
FAIL=0

setup_repo() {
    rm -rf /tmp/git_learn_repo
    mkdir /tmp/git_learn_repo
    cd /tmp/git_learn_repo
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    echo "a" > file.txt && git add . && git commit -q -m "first"
    echo "b" > file.txt && git add . && git commit -q -m "second"
    echo "c" > file.txt && git add . && git commit -q -m "third"
    echo "d" > file.txt && git add . && git commit -q -m "fourth"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
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

test_commit_tree_creates_new_root() {
    echo "TEST: commit-tree creates new root commit"
    setup_repo

    COMMITS=($(git rev-list --reverse HEAD))

    # Get tree of second commit (has content "b")
    tree=$(git rev-parse "${COMMITS[1]}^{tree}")

    # Create new root commit with that tree
    new_sha=$(git commit-tree "$tree" -m "squashed")

    # Verify it has no parent
    parent=$(git rev-parse "$new_sha^" 2>/dev/null || echo "none")
    assert_equals "none" "$parent" "new commit should have no parent"

    # Verify tree content
    git checkout -q "$new_sha"
    content=$(cat file.txt)
    assert_equals "b" "$content" "file should contain 'b'"

    cd /
    rm -rf /tmp/git_learn_repo
}

test_cherry_pick_after_commit_tree() {
    echo "TEST: cherry-pick after commit-tree"
    setup_repo

    COMMITS=($(git rev-list --reverse HEAD))

    # Create squashed commit with tree of second
    tree=$(git rev-parse "${COMMITS[1]}^{tree}")
    new_sha=$(git commit-tree "$tree" -m "squashed")

    # Reset to new commit
    git reset --hard "$new_sha"

    # Try cherry-pick of third commit
    # Store the SHA before trying
    third_sha="${COMMITS[2]}"

    git cherry-pick "$third_sha" 2>/dev/null
    result=$?

    if [[ $result -eq 0 ]]; then
        echo "  PASS: cherry-pick succeeded"
        ((PASS++))
        content=$(cat file.txt)
        assert_equals "c" "$content" "file should contain 'c' after cherry-pick"
    else
        echo "  INFO: cherry-pick returned $result, checking if conflict..."
        if [[ -f .git/CHERRY_PICK_HEAD ]]; then
            echo "  INFO: Cherry-pick in progress (conflict)"
            git cherry-pick --abort
        fi
        echo "  FAIL: cherry-pick did not succeed cleanly"
        ((FAIL++))
    fi

    cd /
    rm -rf /tmp/git_learn_repo
}

test_cherry_pick_with_strategy() {
    echo "TEST: cherry-pick with -X theirs strategy"
    setup_repo

    COMMITS=($(git rev-list --reverse HEAD))

    tree=$(git rev-parse "${COMMITS[1]}^{tree}")
    new_sha=$(git commit-tree "$tree" -m "squashed")
    git reset --hard "$new_sha"

    git cherry-pick -X theirs "${COMMITS[2]}" 2>/dev/null
    result=$?

    assert_equals "0" "$result" "cherry-pick with -X theirs should succeed"

    content=$(cat file.txt)
    assert_equals "c" "$content" "file should contain 'c'"

    cd /
    rm -rf /tmp/git_learn_repo
}

test_full_squash_workflow() {
    echo "TEST: full squash workflow - squash 2, keep 2"
    setup_repo

    COMMITS=($(git rev-list --reverse HEAD))

    # Squash first two commits
    tree=$(git rev-parse "${COMMITS[1]}^{tree}")
    new_sha=$(git commit-tree "$tree" -m "squashed first two")
    git reset --hard "$new_sha"

    # Cherry-pick third and fourth
    git cherry-pick -X theirs "${COMMITS[2]}" 2>/dev/null
    git cherry-pick -X theirs "${COMMITS[3]}" 2>/dev/null

    # Verify result
    count=$(git rev-list --count HEAD)
    assert_equals "3" "$count" "should have 3 commits (1 squashed + 2 cherry-picked)"

    content=$(cat file.txt)
    assert_equals "d" "$content" "file should contain 'd'"

    first_msg=$(git log --reverse --format=%s | head -1)
    assert_equals "squashed first two" "$first_msg" "first commit should be squashed"

    cd /
    rm -rf /tmp/git_learn_repo
}

# Run tests
echo "=== Git Learning Tests ==="
echo

test_commit_tree_creates_new_root
test_cherry_pick_after_commit_tree
test_cherry_pick_with_strategy
test_full_squash_workflow

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
