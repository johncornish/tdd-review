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
