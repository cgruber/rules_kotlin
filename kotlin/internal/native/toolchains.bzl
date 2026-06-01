"""The Kotlin/Native toolchain: one registered toolchain per (exec host, konan target).

Mirrors define_kt_toolchain (kotlin/internal/toolchains.bzl) but carries the konan
distribution + target string instead of the JVM compiler. A single host distribution
can cross-compile klibs for every target, so all of a host's toolchains reference the
same `konan_home`, differing only in `konan_target` + `target_compatible_with`.
"""

KT_NATIVE_TOOLCHAIN_TYPE = Label("//kotlin/internal/native:kt_native_toolchain_type")

def _kt_native_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        konanc = ctx.file.konanc,
        konan_home = ctx.attr.konan_home[DefaultInfo].files,
        konan_target = ctx.attr.konan_target,
        # Pre-staged LLVM/sysroot/cross-toolchain bundle (for binary linking). May be None
        # for klib-only setups; kt_native_binary requires it.
        konan_deps = ctx.attr.konan_deps[DefaultInfo].files if ctx.attr.konan_deps else None,
    )]

_kt_native_toolchain = rule(
    doc = "A Kotlin/Native toolchain. Use define_kt_native_toolchain, not this directly.",
    implementation = _kt_native_toolchain_impl,
    attrs = {
        "konan_deps": attr.label(
            doc = "filegroup of the pre-staged konan dependency bundle (dependencies/ tree)",
        ),
        "konan_home": attr.label(
            doc = "filegroup of the whole konan distribution tree",
            mandatory = True,
        ),
        "konan_target": attr.string(
            doc = "the konan target this toolchain compiles for (e.g. macos_arm64)",
            mandatory = True,
        ),
        "konanc": attr.label(
            doc = "the konanc launcher",
            allow_single_file = True,
            mandatory = True,
        ),
    },
    provides = [platform_common.ToolchainInfo],
)

def define_kt_native_toolchain(
        name,
        konan_target,
        konanc,
        konan_home,
        exec_compatible_with,
        target_compatible_with,
        konan_deps = None,
        visibility = ["//visibility:public"]):
    """Defines a native toolchain impl + its registration (one per (exec, target))."""
    impl_name = name + "_impl"
    _kt_native_toolchain(
        name = impl_name,
        konan_target = konan_target,
        konanc = konanc,
        konan_home = konan_home,
        konan_deps = konan_deps,
        visibility = visibility,
    )
    native.toolchain(
        name = name,
        toolchain_type = KT_NATIVE_TOOLCHAIN_TYPE,
        toolchain = ":" + impl_name,
        exec_compatible_with = exec_compatible_with,
        target_compatible_with = target_compatible_with,
        visibility = visibility,
    )
