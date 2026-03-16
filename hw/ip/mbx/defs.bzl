# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

MBX = pavona_ip(
    name = "mbx",
    hjson = "//hw/ip/mbx/data:mbx.hjson",
)
