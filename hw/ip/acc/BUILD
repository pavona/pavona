# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "rtl_files",
    srcs = glob(
        ["**"],
        exclude = [
            "dv/**",
            "doc/**",
            "README.md",
        ],
    ) + [
        "//hw/ip/acc/data:all_files",
    ],
)

filegroup(
    name = "doc_files",
    srcs = glob([
        "**/*.md",
        "**/*.svg",
    ]) + [
        "//hw/ip/acc/data:all_files",
        "//hw/ip/acc/dv/accsim:doc_files",
        "//hw/ip/acc/dv/memutil:doc_files",
        "//hw/ip/acc/dv/tracer:doc_files",
    ],
)

filegroup(
    name = "cores",
    srcs = [
        "acc.core",
        "acc_pkg.core",
    ],
)

filegroup(
    name = "sim_cores",
    srcs = [
        ":cores",
        "//hw/ip/acc/dv/memutil:cores",
        "//hw/ip/acc/dv/model:cores",
        "//hw/ip/acc/dv/tracer:cores",
        "//hw/ip/acc/dv/uvm/env/pqc_off_env_pkg:cores",
        "//hw/ip/acc/dv/uvm/env/pqc_on_env_pkg:cores",
        "//hw/ip/acc/dv/verilator:cores",
    ],
)

filegroup(
    name = "sim_lint_files",
    srcs = [
        "//hw/ip/acc/dv/tracer:lint_files",
        "//hw/ip/acc/dv/verilator:lint_files",
    ],
)

filegroup(
    name = "sim_dpi_files",
    srcs = [
        "//hw/ip/acc/dv/model:dpi_files",
    ],
)

filegroup(
    name = "sim_rtl_files",
    srcs = [
        "//hw/ip/acc/dv/memutil:rtl_files",
        "//hw/ip/acc/dv/model:rtl_files",
        "//hw/ip/acc/dv/tracer:rtl_files",
        "//hw/ip/acc/dv/uvm/env/pqc_off_env_pkg:rtl_files",
        "//hw/ip/acc/dv/uvm/env/pqc_on_env_pkg:rtl_files",
        "//hw/ip/acc/dv/verilator:rtl_files",
    ],
)

filegroup(
    name = "sim_cc_files",
    srcs = [
        "//hw/ip/acc/dv/memutil:cc_files",
        "//hw/ip/acc/dv/model:cc_files",
        "//hw/ip/acc/dv/tracer:cc_files",
        "//hw/ip/acc/dv/verilator:cc_files",
    ],
)
