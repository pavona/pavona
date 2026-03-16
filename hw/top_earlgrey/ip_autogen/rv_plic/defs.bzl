# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

RV_PLIC = pavona_ip(
    name = "rv_plic",
    hjson = "//hw/top_earlgrey/ip_autogen/rv_plic/data:rv_plic.hjson",
)
