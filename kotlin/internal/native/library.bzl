"""kt_native_library: source-only Kotlin/Native klib compilation (M1).

Compiles .kt sources to a .klib for the konan target supplied by the resolved
toolchain (NOT a rule attribute). Consumes other kt_native_library klibs of the same
target via `-l`. This is the BTA "klib compilation operation" seam; binary linking is a
separate future operation/rule.
"""

load("@rules_java//java:defs.bzl", "java_common")
load(":providers.bzl", "KtNativeInfo")
load(":toolchains.bzl", "KT_NATIVE_TOOLCHAIN_TYPE")

def _kt_native_library_impl(ctx):
    tc = ctx.toolchains[KT_NATIVE_TOOLCHAIN_TYPE]
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

    # Pass the full transitive klib closure as -l. konanc reads each klib's `depends=`
    # and must resolve those libraries by name, but konanc 2.3.x has no library
    # search-path flag — it only searches the directories of -l'd libraries. Direct-only
    # -l happens to work when all klibs are co-located (same Bazel package -> same bin
    # dir), but not when deps span packages. Passing the closure is robust regardless.
    # Cost: a klib's `depends=` then over-declares (lists transitive, not just direct).
    # Revisit at P6/P8 (search-path flag / symlink-into-one-dir) for clean metadata.
    dep_klibs = depset(transitive = transitive)

    klib = ctx.actions.declare_file(ctx.label.name + ".klib")
    out_base = klib.path[:-len(".klib")]  # konanc appends .klib

    # Action-local scratch (NOT declared outputs). konanc auto-caches stdlib/platform
    # deps into -Xauto-cache-dir; without redirecting it, it writes into the read-only
    # distribution repo and Bazel re-fetches it every build. konanc does not create the
    # auto-cache dir itself, so the launcher mkdir's both first.
    konan_data_dir = ctx.label.name + ".konan_data"
    auto_cache_dir = ctx.label.name + ".autocache"

    # Leading positionals are consumed by the launcher: konanc path, count of scratch
    # dirs to mkdir, then those dirs; the rest are konanc's own flags.
    args = ctx.actions.args()
    args.add(tc.konanc.path)
    args.add("2")
    args.add(auto_cache_dir)
    args.add(konan_data_dir)
    args.add("-produce", "library")
    args.add("-target", tc.konan_target)
    args.add("-module-name", module_name)
    args.add("-Xkonan-data-dir=" + konan_data_dir)
    args.add("-Xauto-cache-dir=" + auto_cache_dir)
    args.add("-o", out_base)
    args.add_all(dep_klibs, before_each = "-l")
    args.add_all(ctx.files.srcs)

    # konanc/run_konan launches a JVM; JAVA_HOME comes from the Bazel JDK toolchain
    # (hermetic — no client-env inheritance). The launcher sets its own PATH for `mkdir`;
    # `java` is found via JAVA_HOME, not PATH.
    ctx.actions.run(
        executable = ctx.executable._launcher,
        arguments = [args],
        inputs = depset(
            ctx.files.srcs,
            transitive = [dep_klibs, tc.konan_home, java_runtime.files],
        ),
        outputs = [klib],
        env = {
            "JAVA_HOME": java_runtime.java_home,
            "KONAN_DATA_DIR": konan_data_dir,
        },
        mnemonic = "KotlinNativeKlibCompile",
        progress_message = "Compiling Kotlin/Native klib %{label} (" + tc.konan_target + ")",
    )

    return [
        DefaultInfo(files = depset([klib])),
        KtNativeInfo(
            klib = klib,
            konan_target = tc.konan_target,
            module_name = module_name,
            transitive_klibs = depset([klib], transitive = transitive),
        ),
    ]

kt_native_library = rule(
    doc = "Compiles Kotlin sources into a Kotlin/Native .klib for the resolved target.",
    implementation = _kt_native_library_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "Other kt_native_library targets (must be the same konan target).",
            providers = [KtNativeInfo],
        ),
        "module_name": attr.string(
            doc = "The Kotlin module name; defaults to the target name.",
        ),
        "srcs": attr.label_list(
            doc = "Kotlin sources.",
            allow_files = [".kt"],
        ),
        "_java_runtime": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
            cfg = "exec",
        ),
        "_launcher": attr.label(
            default = Label("//kotlin/internal/native:konanc_launcher"),
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = [KT_NATIVE_TOOLCHAIN_TYPE],
    provides = [KtNativeInfo],
)
