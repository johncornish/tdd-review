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
