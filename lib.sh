#!/bin/bash
# TDD Review - Implementation

parse_test_names() {
    local msg="$1"
    echo "$msg" | grep -oP '\[PASS\]\s+\K\S+'
}
