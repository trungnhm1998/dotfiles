#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
assert_eq "a" "a" "assert_eq matches"
assert_contains "hello world" "world" "assert_contains finds substring"
assert_exit 0 0 "assert_exit matches"
finish
