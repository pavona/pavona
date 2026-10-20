# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

PWRMGR = pavona_ip(
    name = "pwrmgr",
    hjson = "//hw/top_${topname}/ip_autogen/pwrmgr/data:pwrmgr.hjson",
    ipconfig = "//hw/top_${topname}/ip_autogen/pwrmgr/data:top_${topname}_pwrmgr.ipconfig.hjson",
    regs = "//hw/top_${topname}/ip_autogen/pwrmgr/rtl:regs",
    extension = "//hw/top/dt:pwrmgr_binding",
)
