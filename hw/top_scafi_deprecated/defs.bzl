# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#

load("//rules/pavona:hw.bzl", "pavona_top")
load("//hw/top_scafi_deprecated/data/autogen:defs.bzl", "SCAFI_DEPRECATED_IPS")

SCAFI_DEPRECATED = pavona_top(
    name = "scafi_deprecated",
    hjson = "//hw/top_scafi_deprecated/data/autogen:top_scafi_deprecated.gen.hjson",
    top_lib = "//hw/top_scafi_deprecated/sw/autogen:top_scafi_deprecated",
    top_rtl = "//hw/top_scafi_deprecated:rtl_files",
    top_verilator_core = ["lowrisc:dv:top_scafi_deprecated_chip_verilator_sim"],
    top_verilator_binary = {"binary": ["lowrisc_dv_top_scafi_deprecated_chip_verilator_sim_0.1/sim-verilator/Vchip_sim_tb"]},
    top_ld = "//hw/top_scafi_deprecated/sw/autogen:top_scafi_deprecated_memory",
    ips = SCAFI_DEPRECATED_IPS,
    secret_cfgs = {
        "testing": "//hw/top_scafi_deprecated/data/autogen:top_scafi_deprecated.secrets.testing.gen.hjson",
    },
)
