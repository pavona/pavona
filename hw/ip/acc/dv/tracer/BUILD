# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "cores",
    srcs = [
        "acc_tracer.core",
    ],
)

filegroup(
    name = "lint_files",
    srcs = [
        "lint/acc_tracer_waivers.vlt",
    ],
)

filegroup(
    name = "cc_files",
    srcs = [
        "cpp/acc_trace_listener.h",
        "cpp/acc_trace_source.cc",
        "cpp/acc_trace_source.h",
        "cpp/log_trace_listener.cc",
        "cpp/log_trace_listener.h",
    ],
)

filegroup(
    name = "doc_files",
    srcs = [
        "README.md",
    ],
)

filegroup(
    name = "rtl_files",
    srcs = [
        "rtl/acc_trace_if.sv",
        "rtl/acc_tracer.sv",
    ],
)
