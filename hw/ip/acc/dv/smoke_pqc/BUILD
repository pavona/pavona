# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//hw/top:defs.bzl", "opentitan_select_top_attr")
load("//rules:acc.bzl", "acc_binary")
load("//rules:fusesoc.bzl", "fusesoc_build")

package(default_visibility = ["//visibility:public"])

acc_binary(
    name = "smoke_test_nondeterministic",
    srcs = [
        "smoke_test.s",
    ],
    args = [
    ],
)

fusesoc_build(
    name = "verilator_acc",
    srcs = [
        "//hw:dpi_files",
        "//hw:dv_common_files",
        "//hw:rtl_files",
        "//hw:verilator_files",
        "//hw/ip/acc:sim_cc_files",
        "//hw/ip/acc:sim_cores",
        "//hw/ip/acc:sim_dpi_files",
        "//hw/ip/acc:sim_lint_files",
        "//hw/ip/acc:sim_rtl_files",
    ],
    cores = [
        "//hw:cores",
    ],
    data = ["//hw/ip/acc:rtl_files"],
    make_options = "//hw:make_options",
    output_groups = {
        "binary": [
            "lowrisc_ip_acc_top_sim_0.1/sim-verilator/Vacc_top_sim",
        ],
    },
    pre_system_flags = [
        "--flag",
        "pqc",
        "--mapping=lowrisc:prim_generic:all:0.1",
    ],
    systems = ["lowrisc:ip:acc_top_sim"],
    tags = [
        "manual",
        "verilator",
    ],
    target = "sim",
    verilator_options = "//hw:verilator_options",
)
