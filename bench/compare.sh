#!/bin/sh
# M1 comparison matrix. Each run writes bench/out/<stamp>-<model>-<mode>-<effort>/{report.md,results.jsonl}.
# Usage (from bench/):  ./compare.sh [extra bench args, e.g. --game azul]
set -e
cd "$(dirname "$0")"
: "${ANTHROPIC_API_KEY:?export ANTHROPIC_API_KEY first}"
swift build -c release -q
B=.build/release/bench
$B run --model claude-opus-5-5   --mode json      "$@"
$B run --model claude-opus-5-5   --mode citations "$@"
$B run --model claude-sonnet-5-5 --mode json      "$@"
$B run --model claude-haiku-5-5  --mode json      "$@"
ls -1d out/*/ | tail -4
