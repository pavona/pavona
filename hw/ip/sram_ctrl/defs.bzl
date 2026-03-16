# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

SRAM_CTRL = pavona_ip(
    name = "sram_ctrl",
    hjson = "//hw/ip/sram_ctrl/data:sram_ctrl.hjson",
)
