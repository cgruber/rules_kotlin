#!/usr/bin/env bash
# e2e: run a kt_native_binary and assert its output.
set -euo pipefail
bin="$1"
echo "--- running native binary: $bin ---"
out="$("$bin")"
echo "$out"
[[ "$out" == *"Hello from Kotlin/Native"* ]] || { echo "FAIL: unexpected output"; exit 1; }
echo "E2E OK"
