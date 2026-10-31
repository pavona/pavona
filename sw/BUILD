# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "doc_files",
    srcs = glob(["**/*.md"]) + [
        "//sw:vendor_doc_files",
        "//sw/acc/code-snippets:README.md",
        "//sw/device:doc_files",
        "//sw/host:doc_files",
    ],
)

exports_files(glob(["vendor/veri-titan/gen/*.s"]))

filegroup(
    name = "vendor_doc_files",
    srcs = glob(["vendor/**/*.md"]),
)

cc_library(
    name = "cryptoc_sha256",
    srcs = ["vendor/cryptoc/sha256.c"],
    hdrs = [
        "vendor/cryptoc/include/cryptoc/hash-internal.h",
        "vendor/cryptoc/include/cryptoc/sha256.h",
    ],
    strip_include_prefix = "vendor/cryptoc/include",
)

cc_library(
    name = "cryptoc",
    srcs = glob(
        ["vendor/cryptoc/*.c"],
        exclude = [
            "vendor/cryptoc/sha512.c",
            "vendor/cryptoc/sha384.c",
            "vendor/cryptoc/*_unittest.c",
        ],
    ),
    hdrs = glob(["vendor/cryptoc/include/cryptoc/*.h"]),
    copts = select({
        # The compiler configured for the riscv32 target has a very strict
        # default configuration.
        "@platforms//cpu:riscv32": [
            "-Wno-error=implicit-int-conversion",
            "-Wno-error=sign-conversion",
        ],
        "//conditions:default": [],
    }),
    strip_include_prefix = "vendor/cryptoc/include",
)
