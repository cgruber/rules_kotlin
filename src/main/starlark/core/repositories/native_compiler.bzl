"""Repository rule + host table for the Kotlin/Native prebuilt distribution.

Parallels `kotlin_compiler_repository` (compiler.bzl): download_and_extract a
host-specific `kotlin-native-prebuilt-<os>-<arch>-<version>` archive and expose the
konanc launcher + the whole distribution tree.

M1 scope: source-only klib compilation. The distribution alone is sufficient for
`-produce library` (host and cross-target); no LLVM/sysroot download is required (that
is a binary-linking concern). See
thoughts/shared/research/2026-06-01-kotlin-native-klib-spike-findings.md.
"""

# Kotlin/Native version. Kept in lockstep with KOTLIN_CURRENT_COMPILER_RELEASE in
# versions.bzl (klibs are coupled to the compiler version that produced them).
KOTLIN_NATIVE_VERSION = "2.3.21"

# Per-host prebuilt distribution. Keyed by "<os>-<cpu>" as derived from the module
# extension's host detection. Add hosts as their sha256 is verified.
#
# NOTE: only the macOS arm64 host artifact is verified so far (the spike host). Other
# hosts have empty sha256 (non-reproducible / will warn) until verified — fill them in
# before relying on them.
KOTLIN_NATIVE_PREBUILT = {
    "macos-aarch64": struct(
        sha256 = "5418391a3b94d7bff6794668c8e813ebc471f46e04f828a35e88469c367efa4d",
        archive = "kotlin-native-prebuilt-macos-aarch64-{version}",
    ),
    "macos-x86_64": struct(
        sha256 = "",
        archive = "kotlin-native-prebuilt-macos-x86_64-{version}",
    ),
    "linux-x86_64": struct(
        sha256 = "",
        archive = "kotlin-native-prebuilt-linux-x86_64-{version}",
    ),
}

_URL_TEMPLATE = "https://github.com/JetBrains/kotlin/releases/download/v{version}/{archive}.tar.gz"

_BUILD = """\
package(default_visibility = ["//visibility:public"])

# The konanc launcher (a bash script that shells run_konan -> JVM).
exports_files(["bin/konanc"])

# The entire distribution tree (bin/, klib/, konan/) as compile inputs; konanc resolves
# run_konan + konan/lib jars + bundled platform klibs relative to itself.
filegroup(
    name = "home",
    srcs = glob(["**"], exclude = ["BUILD.bazel", "WORKSPACE", "MODULE.bazel"]),
)
"""

def _kotlin_native_compiler_impl(repository_ctx):
    attr = repository_ctx.attr
    repository_ctx.download_and_extract(
        url = attr.urls,
        sha256 = attr.sha256,
        stripPrefix = attr.strip_prefix,
    )
    repository_ctx.file("BUILD.bazel", _BUILD, executable = False)

    if not hasattr(repository_ctx, "repo_metadata"):
        return None
    return repository_ctx.repo_metadata(reproducible = attr.sha256 != "")

kotlin_native_compiler_repository = repository_rule(
    implementation = _kotlin_native_compiler_impl,
    attrs = {
        "sha256": attr.string(doc = "sha256 of the prebuilt archive"),
        "strip_prefix": attr.string(doc = "archive top-level directory to strip"),
        "urls": attr.string_list(doc = "URLs for the prebuilt archive", mandatory = True),
    },
)

# --- konan dependency bundle (LLVM / sysroot / cross-toolchain) for binary linking ---
#
# klib compilation needs none of these. Binary linking (`-produce program`) does: konanc
# otherwise downloads them to ~/.konan on first run. Pre-staging them (here) + reproducing
# konanc's `dependencies/.extracted` marker lets the link action run sandboxed with no
# network. Keyed by build host; a host's bundle covers all targets it can build (the
# LLVM/libffi/lldb are host artifacts, the *-gcc-* cross-toolchain is target-specific).
# Apple *targets* additionally need a local Xcode SDK (not vendorable here).
#
# NOTE: sha256 is empty pending pinning (the probe's cached tarballs were auto-removed
# after extraction). Repo fetch still works (non-reproducible warning); pin before relying.
_DEPS_BASE = "https://download.jetbrains.com/kotlin/native"

KOTLIN_NATIVE_DEPS = {
    "macos-aarch64": {
        # name (== archive top dir == konanc dependency dir) : (url, sha256)
        "llvm-19-aarch64-macos-essentials-81": (_DEPS_BASE + "/resources/llvm/19-aarch64-macos/llvm-19-aarch64-macos-essentials-81.tar.gz", ""),
        "lldb-4-macos": (_DEPS_BASE + "/lldb-4-macos.tar.gz", ""),
        "libffi-3.3-1-macos-arm64": (_DEPS_BASE + "/libffi-3.3-1-macos-arm64.tar.gz", ""),
        "x86_64-unknown-linux-gnu-gcc-8.3.0-glibc-2.19-kernel-4.9-2": (_DEPS_BASE + "/x86_64-unknown-linux-gnu-gcc-8.3.0-glibc-2.19-kernel-4.9-2.tar.gz", ""),
    },
}

_DEPS_BUILD = """\
package(default_visibility = ["//visibility:public"])

# The pre-staged konan dependency tree (dependencies/<dep>/ + dependencies/.extracted).
# kt_native_binary stages this into a writable KONAN_DATA_DIR so konanc skips its download.
filegroup(
    name = "deps",
    srcs = glob(["dependencies/**"], allow_empty = False),
)
"""

def _kotlin_native_deps_impl(repository_ctx):
    names = []
    for name, (url, sha256) in sorted(repository_ctx.attr.deps.items()):
        repository_ctx.download_and_extract(
            url = url,
            sha256 = sha256,
            output = "dependencies",
        )
        names.append(name)

    # The marker konanc reads to know which dependencies are already present.
    repository_ctx.file(
        "dependencies/.extracted",
        content = "\n".join(names) + "\n",
        executable = False,
    )
    repository_ctx.file("BUILD.bazel", _DEPS_BUILD, executable = False)

kotlin_native_deps_repository = repository_rule(
    implementation = _kotlin_native_deps_impl,
    attrs = {
        "deps": attr.string_list_dict(
            doc = "map of dependency dir name -> [url, sha256]",
            mandatory = True,
        ),
    },
)

def kotlin_native_deps_for_host(os_name, cpu_name):
    """Returns {name: [url, sha256]} of konan deps to stage for the host, or fails."""
    host = "{os}-{cpu}".format(os = os_name, cpu = cpu_name)
    table = KOTLIN_NATIVE_DEPS.get(host)
    if not table:
        fail("No Kotlin/Native dependency bundle configured for host '%s'" % host)
    return {name: [url, sha256] for name, (url, sha256) in table.items()}

def kotlin_native_dist_for_host(os_name, cpu_name):
    """Returns (url_list, sha256, strip_prefix) for the host, or fails if unsupported."""
    host = "{os}-{cpu}".format(os = os_name, cpu = cpu_name)
    spec = KOTLIN_NATIVE_PREBUILT.get(host)
    if not spec:
        fail("No Kotlin/Native prebuilt distribution configured for host '%s' (supported: %s)" %
             (host, ", ".join(sorted(KOTLIN_NATIVE_PREBUILT.keys()))))
    archive = spec.archive.format(version = KOTLIN_NATIVE_VERSION)
    url = _URL_TEMPLATE.format(version = KOTLIN_NATIVE_VERSION, archive = archive)
    return ([url], spec.sha256, archive)
