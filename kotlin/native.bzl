"""Public API for Kotlin/Native rules.

M1 (source-only klib compilation):
- kt_native_library: compile .kt -> .klib for the resolved konan target.

The konan target is selected by Bazel toolchain resolution (the build's --platforms),
not a rule attribute. See thoughts/shared/plans/2026-06-01-kotlin-native-m1-design.md.
"""

load("//kotlin/internal/native:binary.bzl", _kt_native_binary = "kt_native_binary")
load("//kotlin/internal/native:library.bzl", _kt_native_library = "kt_native_library")
load("//kotlin/internal/native:providers.bzl", _KtNativeInfo = "KtNativeInfo")

kt_native_library = _kt_native_library
kt_native_binary = _kt_native_binary
KtNativeInfo = _KtNativeInfo
