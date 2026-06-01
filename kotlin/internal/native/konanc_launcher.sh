#!/usr/bin/env bash
# Launcher for konanc Bazel actions.
#
# konanc does not create its -Xauto-cache-dir (and writing the auto-cache into the
# read-only distribution repo makes Bazel re-fetch it every build). So this launcher
# creates N action-local scratch dirs, then execs konanc.
#
# Usage: konanc_launcher.sh <konanc> <num_dirs> <dir1> ... <dirN> [konanc args...]
#
# PATH is set here (only `mkdir` is needed) so the action env stays minimal; konanc finds
# `java` via JAVA_HOME (set by the rule from the Bazel JDK toolchain), not PATH.
set -euo pipefail
export PATH="/usr/bin:/bin${PATH:+:$PATH}"

konanc="$1"
num_dirs="$2"
shift 2

for ((i = 0; i < num_dirs; i++)); do
  mkdir -p "$1"
  shift
done

exec "$konanc" "$@"
