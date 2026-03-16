# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

SYSRST_CTRL = pavona_ip(
    name = "sysrst_ctrl",
    hjson = "//hw/ip/sysrst_ctrl/data:sysrst_ctrl.hjson",
)
