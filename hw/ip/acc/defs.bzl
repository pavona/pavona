# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/opentitan:hw.bzl", "opentitan_ip")

ACC = opentitan_ip(
    name = "acc",
    hjson = "//hw/ip/acc/data:acc.hjson",
)
