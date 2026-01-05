#!/bin/bash
# TDD Review - Implementation

parse_test_names() {
    local msg="$1"
    echo "$msg" | grep -oP '\[(PASS|FAIL->PASS)\]\s+\K\S+'
}

parse_config() {
    local file="$1"
    local key="$2"
    grep "^${key}=" "$file" | cut -d'"' -f2
}

get_commits() {
    local range="$1"
    git rev-list --reverse "$range"
}

get_commit_message() {
    local sha="$1"
    git log -1 --format=%B "$sha" | head -1
}

get_changed_files() {
    local sha="$1"
    git diff-tree --no-commit-id --name-only -r --root "$sha"
}

checkout_commit() {
    local sha="$1"
    git checkout -q "$sha"
}

get_test_command_for_file() {
    local file="$1"
    case "$file" in
        *.js|*.ts|*.tsx) echo "npm test" ;;
        *.py) echo "pytest" ;;
        *.sh) echo "./test.sh" ;;
        *.rb) echo "rspec" ;;
        *.go) echo "go test" ;;
        *) echo "" ;;
    esac
}

run_tests_for_commit() {
    local sha="$1"
    local full="${2:-false}"
    local changed_files test_cmd

    changed_files=$(get_changed_files "$sha")

    # Determine test command from first testable file
    for file in $changed_files; do
        test_cmd=$(get_test_command_for_file "$file")
        [[ -n "$test_cmd" ]] && break
    done

    # No testable files - return silently
    [[ -z "$test_cmd" ]] && return 0

    if [[ "$full" == "true" ]]; then
        echo "Running: $test_cmd"
        eval "$test_cmd"
    fi
}

add_note() {
    local sha="$1"
    local category="$2"
    local message="$3"
    git notes --ref=tdd-review add -f -m "${category}: ${message}" "$sha"
}

get_note() {
    local sha="$1"
    git notes --ref=tdd-review show "$sha" 2>/dev/null || echo ""
}

squash_range() {
    local range="$1"
    local message="$2"
    # Extract the base commit from range (e.g., HEAD~2 from HEAD~2..HEAD)
    local base="${range%..*}"
    git reset --soft "$base"
    git commit -q -m "$message"
}

aggregate_feedback() {
    local range="$1"
    local commits
    commits=$(get_commits "$range")

    echo "# TDD Review Feedback"
    echo

    for sha in $commits; do
        local note
        note=$(get_note "$sha")
        if [[ -n "$note" ]]; then
            local msg
            msg=$(get_commit_message "$sha")
            local short_sha="${sha:0:7}"
            echo "## Commit: $short_sha - $msg"
            echo "**Flag**: $note"
            echo
        fi
    done
}

display_commit() {
    local sha="$1"
    local short_sha="${sha:0:7}"
    local msg
    msg=$(get_commit_message "$sha")
    local files
    files=$(get_changed_files "$sha")

    echo "=== Commit: $short_sha ==="
    echo "Message: $msg"
    echo ""
    echo "Files changed:"
    echo "$files" | sed 's/^/  /'
}

show_help() {
    echo "Commands:"
    echo "  n/next  - Next commit"
    echo "  p/prev  - Previous commit"
    echo "  T       - Run full test suite"
    echo "  f/flag  - Flag this commit"
    echo "  s/squash - Squash commits up to here"
    echo "  d/drop  - Drop remaining commits"
    echo "  q/quit  - Quit"
}

# Returns 0 = continue, 1 = exit
process_command() {
    local cmd="$1"
    case $cmd in
        n|next)
            if [[ $CURRENT -lt $((${#COMMITS[@]}-1)) ]]; then
                CURRENT=$((CURRENT + 1))
            fi
            ;;
        p|prev)
            if [[ $CURRENT -gt 0 ]]; then
                CURRENT=$((CURRENT - 1))
            fi
            ;;
        h|help) show_help ;;
        T) run_tests_for_commit "${COMMITS[$CURRENT]}" true ;;
        q|quit) return 1 ;;
    esac
    return 0
}

main_loop() {
    while read -n 1 cmd; do
        # Consume rest of line if any (handles piped input with newlines)
        read -r _ 2>/dev/null || true
        case $cmd in
            n|next|p|prev)
                local old_current=$CURRENT
                process_command "$cmd"
                if [[ $CURRENT -ne $old_current ]]; then
                    checkout_commit "${COMMITS[$CURRENT]}"
                    display_commit "${COMMITS[$CURRENT]}"
                    run_tests_for_commit "${COMMITS[$CURRENT]}"
                fi
                ;;
            h|help|T)
                process_command "$cmd"
                ;;
            q|quit)
                break
                ;;
            f|flag)
                local category message
                echo -n "Category: "
                read -r category
                echo -n "Message: "
                read -r message
                add_note "${COMMITS[$CURRENT]}" "$category" "$message"
                echo "Flagged."
                ;;
            s|squash)
                echo -n "Squash message: "
                read -r msg
                # Get tree of current commit
                local tree
                tree=$(git rev-parse "${COMMITS[$CURRENT]}^{tree}")
                # Create new commit with that tree
                local new_commit
                if git rev-parse "${COMMITS[0]}^" >/dev/null 2>&1; then
                    # Has parent - create commit with parent
                    local parent
                    parent=$(git rev-parse "${COMMITS[0]}^")
                    new_commit=$(git commit-tree "$tree" -p "$parent" -m "$msg")
                else
                    # No parent - create root commit
                    new_commit=$(git commit-tree "$tree" -m "$msg")
                fi
                # Reset to new commit
                git reset --hard "$new_commit"
                # Cherry-pick remaining commits (CURRENT+1 to end)
                local i
                for ((i=CURRENT+1; i<${#COMMITS[@]}; i++)); do
                    git cherry-pick "${COMMITS[$i]}" >/dev/null 2>&1
                done
                local squashed=$((CURRENT + 1))
                echo "Squashed $squashed commits into 1."
                break
                ;;
            d|drop)
                local remaining=$((${#COMMITS[@]} - CURRENT - 1))
                echo "This will drop $remaining commits. Continue? (y/n)"
                read -n 1 confirm
                read -r _ 2>/dev/null || true
                if [[ "$confirm" == "y" ]]; then
                    git reset --hard "${COMMITS[$CURRENT]}"
                    echo "Dropped $remaining commits."
                    break
                fi
                ;;
            h|help) show_help ;;
            q|quit) break ;;
        esac
    done
}
