#!/usr/bin/env bash
# Launcher for kt_native_binary (konanc -produce program) with PRE-STAGED konan deps.
#
# Binary linking needs the konan dependency bundle (LLVM / sysroot / cross-toolchain),
# which konanc otherwise downloads to ~/.konan on first run. This launcher stages the
# Bazel-provided, pre-fetched bundle into a writable KONAN_DATA_DIR — symlinking each
# dependency dir and regenerating the `dependencies/.extracted` marker — so konanc finds
# them and skips the download. That lets the link action run sandboxed with no network.
#
# Usage:
#   konanc_link_launcher.sh <konanc> <konan_data_dir> <auto_cache_dir> <staged_deps_dir> [konanc args...]
set -euo pipefail
export PATH="/usr/bin:/bin${PATH:+:$PATH}"

konanc="$1"
konan_data_dir="$2"
auto_cache_dir="$3"
staged_deps="$4"
shift 4

mkdir -p "$konan_data_dir/dependencies" "$auto_cache_dir"

# Symlink each pre-staged dependency dir into the writable KONAN_DATA_DIR/dependencies,
# and rebuild the .extracted marker to list exactly those dirs.
marker=""
for entry in "$staged_deps"/*; do
  name="$(basename "$entry")"
  ln -sfn "$PWD/$entry" "$konan_data_dir/dependencies/$name"
  marker+="$name"$'\n'
done
printf '%s' "$marker" > "$konan_data_dir/dependencies/.extracted"

exec "$konanc" "$@"
