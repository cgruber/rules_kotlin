"""kt_native_binary: link a Kotlin/Native executable (P3).

Compiles .kt sources + transitive klib deps into a native executable for the resolved
konan target (`-produce program`).

Binary linking needs the konan dependency bundle (LLVM + sysroot + cross-toolchain) that
klib compilation does not. The bundle is pre-fetched by the `kotlin_native_deps`
repository (at repo-fetch time) and staged into a writable KONAN_DATA_DIR by the link
launcher, so this action runs **sandboxed with no network** (verified for linux_x64 with
--sandbox_default_allow_network=false).

Caveat: Apple *targets* still need a local Xcode SDK for the platform sysroot (read from
the host via xcrun); that part is not vendorable. Non-Apple cross targets (e.g. linux_x64)
are fully hermetic. Host/target dependency coverage is whatever `kotlin_native_deps`
stages — see src/main/starlark/core/repositories/native_compiler.bzl.
"""

load("@rules_java//java:defs.bzl", "java_common")
load(":providers.bzl", "KtNativeInfo")
load(":toolchains.bzl", "KT_NATIVE_TOOLCHAIN_TYPE")

def _staged_deps_dir(deps_files):
    """Derive the `dependencies/` dir path from the pre-staged deps filegroup files."""
    for f in deps_files:
        idx = f.path.find("/dependencies/")
        if idx != -1:
            return f.path[:idx] + "/dependencies"
    fail("could not locate the konan 'dependencies' dir in the staged deps")

def _kt_native_binary_impl(ctx):
    tc = ctx.toolchains[KT_NATIVE_TOOLCHAIN_TYPE]
    if not tc.konan_deps:
        fail("kt_native_binary requires a toolchain with konan_deps (the LLVM/sysroot " +
             "bundle); the resolved %s toolchain has none." % tc.konan_target)
    java_runtime = ctx.attr._java_runtime[java_common.JavaRuntimeInfo]
    module_name = ctx.attr.module_name or ctx.label.name

    transitive = []
    for dep in ctx.attr.deps:
        info = dep[KtNativeInfo]
        if info.konan_target != tc.konan_target:
            fail("dep {dep} is for target {dt}, but this target is {t}".format(
                dep = dep.label,
                dt = info.konan_target,
                t = tc.konan_target,
            ))
        transitive.append(info.transitive_klibs)
    dep_klibs = depset(transitive = transitive)

    binary = ctx.actions.declare_file(ctx.label.name + ".kexe")
    out_base = binary.path[:-len(".kexe")]  # konanc -produce program appends .kexe
    konan_data_dir = ctx.label.name + ".konan_data"  # action-local scratch (writable)
    auto_cache_dir = ctx.label.name + ".autocache"
    staged_deps = _staged_deps_dir(tc.konan_deps.to_list())

    # launcher: <konanc> <konan_data_dir> <auto_cache_dir> <staged_deps_dir> [konanc args]
    args = ctx.actions.args()
    args.add(tc.konanc.path)
    args.add(konan_data_dir)
    args.add(auto_cache_dir)
    args.add(staged_deps)
    args.add("-produce", "program")
    args.add("-target", tc.konan_target)
    args.add("-module-name", module_name)
    args.add("-Xkonan-data-dir=" + konan_data_dir)
    args.add("-Xauto-cache-dir=" + auto_cache_dir)
    args.add("-o", out_base)
    args.add_all(dep_klibs, before_each = "-l")
    args.add_all(ctx.files.srcs)

    ctx.actions.run(
        executable = ctx.executable._launcher,
        arguments = [args],
        inputs = depset(
            ctx.files.srcs,
            transitive = [dep_klibs, tc.konan_home, tc.konan_deps, java_runtime.files],
        ),
        outputs = [binary],
        env = {
            "JAVA_HOME": java_runtime.java_home,
            "KONAN_DATA_DIR": konan_data_dir,
        },
        mnemonic = "KotlinNativeLink",
        progress_message = "Linking Kotlin/Native binary %{label} (" + tc.konan_target + ")",
    )

    return [DefaultInfo(files = depset([binary]))]

kt_native_binary = rule(
    doc = "Links a Kotlin/Native executable for the resolved target.",
    implementation = _kt_native_binary_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "kt_native_library targets (must be the same konan target).",
            providers = [KtNativeInfo],
        ),
        "module_name": attr.string(
            doc = "The Kotlin module name; defaults to the target name.",
        ),
        "srcs": attr.label_list(
            doc = "Kotlin sources (must define an entry point / main).",
            allow_files = [".kt"],
        ),
        "_java_runtime": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
            cfg = "exec",
        ),
        "_launcher": attr.label(
            default = Label("//kotlin/internal/native:konanc_link_launcher"),
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = [KT_NATIVE_TOOLCHAIN_TYPE],
)
