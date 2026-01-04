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
    git diff-tree --no-commit-id --name-only -r "$sha"
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
    echo "  f/flag  - Flag this commit"
    echo "  q/quit  - Quit"
}

main_loop() {
    while read -n 1 cmd; do
        # Consume rest of line if any (handles piped input with newlines)
        read -r _ 2>/dev/null || true
        case $cmd in
            n|next)
                if [[ $CURRENT -lt $((${#COMMITS[@]}-1)) ]]; then
                    ((CURRENT++))
                    display_commit "${COMMITS[$CURRENT]}"
                fi
                ;;
            p|prev)
                if [[ $CURRENT -gt 0 ]]; then
                    ((CURRENT--))
                    display_commit "${COMMITS[$CURRENT]}"
                fi
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
            h|help) show_help ;;
            q|quit) break ;;
        esac
    done
}
