# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

PWRMGR = pavona_ip(
    name = "pwrmgr",
    hjson = "//hw/top_earlgrey/ip_autogen/pwrmgr/data:pwrmgr.hjson",
    ipconfig = "//hw/top_earlgrey/ip_autogen/pwrmgr/data:top_earlgrey_pwrmgr.ipconfig.hjson",
    extension = "//hw/top/dt:pwrmgr_binding",
)
