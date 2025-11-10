# Copyright The mldsa-native project authors
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "mldsa_native",
    srcs = [
        "mldsa_native_alloc.c",
        "mldsa_native_monobuild.c",
    ],
    hdrs = [
        "fips202_glue.h",
        "mldsa_native_alloc.h",
        "mldsa_native_config.h",
        "mldsa_native_monobuild.h",
    ],
    includes = ["."],
    deps = [
        "//sw/device/lib/crypto/impl:sha3",
        "@mldsa_native//:mldsa_native_sources",
    ],
)
