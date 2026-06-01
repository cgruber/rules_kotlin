#!/usr/bin/env bash
# Manual e2e (not a hermetic Bazel test): cross-compile the kt_native_binary to linux_x64
# via Bazel, then run it in a bare Linux container with no JRE to prove it's a real
# native binary. Requires Docker.
set -euo pipefail
cd "$(dirname "$0")"

echo "== building //:hello for linux_x64 via Bazel =="
bazel build //:hello --platforms=//:linux_x64
bin="$(bazel cquery //:hello --platforms=//:linux_x64 --output=files 2>/dev/null)"
abs="$PWD/$bin"
echo "built: $bin"
file "$abs"

echo "== running in bare ubuntu:22.04 (linux/amd64), which has no java =="
docker run --rm --platform linux/amd64 -v "$abs:/hello.kexe:ro" ubuntu:22.04 \
  bash -c 'printf "java present? "; (command -v java || echo "NO (no JRE in container)"); echo "--- output ---"; /hello.kexe'
