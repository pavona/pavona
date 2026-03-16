# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

PINMUX = pavona_ip(
    name = "pinmux",
    hjson = "//hw/top_${topname}/ip_autogen/pinmux/data:pinmux.hjson",
)
