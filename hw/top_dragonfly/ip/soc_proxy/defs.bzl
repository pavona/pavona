# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

SOC_PROXY = pavona_ip(
    name = "soc_proxy",
    hjson = "//hw/top_dragonfly/ip/soc_proxy/data:soc_proxy.hjson",
)
