# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "cores",
    srcs = [
        "acc_model.core",
    ],
)

filegroup(
    name = "cc_files",
    srcs = [
        "acc_model.cc",
        "acc_model.h",
        "acc_model_dpi.h",
        "acc_trace_checker.cc",
        "acc_trace_checker.h",
        "acc_trace_entry.cc",
        "acc_trace_entry.h",
        "iss_wrapper.cc",
        "iss_wrapper.h",
    ],
)

filegroup(
    name = "dpi_files",
    srcs = [
        "acc_model_dpi.svh",
    ],
)

filegroup(
    name = "rtl_files",
    srcs = [
        "acc_core_model.sv",
        "acc_rf_snooper_if.sv",
        "acc_stack_snooper_if.sv",
    ],
)
