# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

RV_TIMER = pavona_ip(
    name = "rv_timer",
    hjson = "//hw/ip/rv_timer/data:rv_timer.hjson",
)
