# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

SOC_DBG_CTRL = pavona_ip(
    name = "soc_dbg_ctrl",
    hjson = "//hw/ip/soc_dbg_ctrl/data:soc_dbg_ctrl.hjson",
)
