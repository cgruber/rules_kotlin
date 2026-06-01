"""Providers for Kotlin/Native rules."""

KtNativeInfo = provider(
    doc = "A Kotlin/Native .klib produced by kt_native_library.",
    fields = {
        "klib": "the .klib File produced by this target",
        "konan_target": "the konan target this klib was compiled for (e.g. linux_x64)",
        "module_name": "the module name",
        "transitive_klibs": "depset of .klib Files needed to compile against this target",
    },
)
