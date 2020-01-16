# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
workspace(name = "io_bazel_rules_kotlin")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_jar")
load("//kotlin/internal/repositories:repositories.bzl", "github_archive")

RULES_ANDROID_TAG = "0.1.1"
RULES_ANDROID_SHA = "cd06d15dd8bb59926e4d65f9003bfc20f9da4b2519985c27e190cddc8b7a7806"

RULES_JVM_EXTERNAL_TAG = "3.0"
RULES_JVM_EXTERNAL_SHA = "62133c125bf4109dfd9d2af64830208356ce4ef8b165a6ef15bbff7460b35c3a"

RULES_NODEJS_VERSION = "0.36.1"
RULES_NODEJS_SHA = "3356c6b767403392bab018ce91625f6d15ff8f11c6d772dc84bc9cada01c669a"

BAZEL_TOOLCHAINS_VERSION = "be10bee3010494721f08a0fccd7f57411a1e773e"
BAZEL_TOOLCHAINS_SHA = "5962fe677a43226c409316fcb321d668fc4b7fa97cb1f9ef45e7dc2676097b26"

SKYLIB_VERSION = "0.8.0"
SKYLIB_SHA = "2ea8a5ed2b448baf4a6855d3ce049c4c452a6470b1efd1504fdb7c1c134d220a"

PROTOBUF_GIT_COMMIT = "09745575a923640154bcf307fba8aedff47f240a"  # v3.8.0, as of 2019-05-28
PROTOBUF_SHA = "76ee4ba47dec6146872b6cd051ae5bd12897ef0b1523d5aeb56d81a5a4ca885a"

BAZEL_DEPS_VERSION = "0.1.0"
BAZEL_DEPS_SHA = "05498224710808be9687f5b9a906d11dd29ad592020246d4cd1a26eeaed0735e"


local_repository(name = "node_example", path = "examples/node")

http_archive(
    name = "build_bazel_rules_android",
    sha256 = RULES_ANDROID_SHA,
    strip_prefix = "rules_android-0.1.1",
    url = "https://github.com/bazelbuild/rules_android/archive/v%s.zip" % RULES_ANDROID_TAG,
)

github_archive(
    name = "com_google_protobuf",
    commit = PROTOBUF_GIT_COMMIT,
    repo = "google/protobuf",
    sha256 = PROTOBUF_SHA,
)

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")
protobuf_deps()

http_archive(
    name = "bazel_skylib",
    urls = ["https://github.com/bazelbuild/bazel-skylib/archive/%s.tar.gz" % SKYLIB_VERSION],
    strip_prefix = "bazel-skylib-%s" % SKYLIB_VERSION,
    sha256 = SKYLIB_SHA,
)

http_jar(
    name = "bazel_deps",
    sha256 = BAZEL_DEPS_SHA,
    url = "https://github.com/hsyed/bazel-deps/releases/download/v%s/parseproject_deploy.jar" % BAZEL_DEPS_VERSION,
)

http_archive(
    name = "bazel_toolchains",
    sha256 = BAZEL_TOOLCHAINS_SHA,
    strip_prefix = "bazel-toolchains-%s" % BAZEL_TOOLCHAINS_VERSION,
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-toolchains/archive/%s.tar.gz" % BAZEL_TOOLCHAINS_VERSION,
        "https://github.com/bazelbuild/bazel-toolchains/archive/%s.tar.gz" % BAZEL_TOOLCHAINS_VERSION,
    ],
)

# Creates toolchain configuration for remote execution with BuildKite CI
# for rbe_ubuntu1604
load("@bazel_toolchains//rules:rbe_repo.bzl", "rbe_autoconfig")
rbe_autoconfig(name = "buildkite_config")

load("//kotlin:kotlin.bzl", "kotlin_repositories", "kt_register_toolchains")
kotlin_repositories()
kt_register_toolchains()

# The following are to support building and running nodejs examples from src/test
http_archive(
    name = "build_bazel_rules_nodejs",
    sha256 = RULES_NODEJS_SHA,
    url = "https://github.com/bazelbuild/rules_nodejs/releases/download/{0}/rules_nodejs-{0}.tar.gz".format(RULES_NODEJS_VERSION),
)
load("@build_bazel_rules_nodejs//:defs.bzl", "yarn_install")
yarn_install(
    name = "node_ws",
    package_json = "@node_example//:package.json",
    yarn_lock = "@node_example//:yarn.lock",
)

http_archive(
    name = "rules_jvm_external",
    sha256 = RULES_JVM_EXTERNAL_SHA,
    strip_prefix = "rules_jvm_external-%s" % RULES_JVM_EXTERNAL_TAG,
    url = "https://github.com/bazelbuild/rules_jvm_external/archive/%s.zip" % RULES_JVM_EXTERNAL_TAG,
)
load("@rules_jvm_external//:defs.bzl", "maven_install")
maven_install(
    artifacts = [
        "org.jetbrains.kotlinx:atomicfu-js:0.13.1",
        "org.jetbrains.kotlinx:kotlinx-coroutines-core-js:1.3.2",
    ],
    repositories = [
        "https://maven-central.storage.googleapis.com/repos/central/data/",
        "https://repo1.maven.org/maven2",
    ],
)
