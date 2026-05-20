# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

RACL_CTRL = pavona_ip(
    name = "racl_ctrl",
    hjson = "//hw/top_dragonfly/ip_autogen/racl_ctrl/data:racl_ctrl.hjson",
)
