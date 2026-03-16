# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

RV_CORE_IBEX = pavona_ip(
    name = "rv_core_ibex",
    hjson = "//hw/top_englishbreakfast/ip_autogen/rv_core_ibex/data:rv_core_ibex.hjson",
    ipconfig = "//hw/top_englishbreakfast/ip_autogen/rv_core_ibex/data:top_englishbreakfast_rv_core_ibex.ipconfig.hjson",
)
