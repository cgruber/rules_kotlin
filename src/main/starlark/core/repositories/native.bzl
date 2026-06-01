"""Module extension that provisions the Kotlin/Native prebuilt distribution.

Creates a single repository (`com_github_jetbrains_kotlin_native`) holding the host's
prebuilt distribution. A host distribution can cross-compile klibs for every supported
target, so one repo per build host is sufficient.
"""

load(
    ":native_compiler.bzl",
    "kotlin_native_compiler_repository",
    "kotlin_native_deps_for_host",
    "kotlin_native_deps_repository",
    "kotlin_native_dist_for_host",
)

KOTLIN_NATIVE_REPO = "com_github_jetbrains_kotlin_native"
KOTLIN_NATIVE_DEPS_REPO = "com_github_jetbrains_kotlin_native_deps"

def _normalize_os(name):
    name = name.lower()
    if name.startswith("mac"):
        return "macos"
    if name.startswith("linux"):
        return "linux"
    if name.startswith("windows"):
        return "windows"
    fail("Unsupported host OS for Kotlin/Native: %s" % name)

def _normalize_cpu(arch):
    arch = arch.lower()
    if arch in ("aarch64", "arm64"):
        return "aarch64"
    if arch in ("x86_64", "amd64"):
        return "x86_64"
    fail("Unsupported host CPU for Kotlin/Native: %s" % arch)

def _kotlin_native_impl(module_ctx):
    os_name = _normalize_os(module_ctx.os.name)
    cpu_name = _normalize_cpu(module_ctx.os.arch)
    urls, sha256, strip_prefix = kotlin_native_dist_for_host(os_name, cpu_name)

    kotlin_native_compiler_repository(
        name = KOTLIN_NATIVE_REPO,
        urls = urls,
        sha256 = sha256,
        strip_prefix = strip_prefix,
    )

    # Pre-staged LLVM/sysroot/cross-toolchain bundle for binary linking (kt_native_binary).
    kotlin_native_deps_repository(
        name = KOTLIN_NATIVE_DEPS_REPO,
        deps = kotlin_native_deps_for_host(os_name, cpu_name),
    )

    return module_ctx.extension_metadata(reproducible = True)

kotlin_native = module_extension(implementation = _kotlin_native_impl)
