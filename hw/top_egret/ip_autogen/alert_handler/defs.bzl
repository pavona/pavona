# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

ALERT_HANDLER = pavona_ip(
    name = "alert_handler",
    hjson = "//hw/top_egret/ip_autogen/alert_handler/data:alert_handler.hjson",
)
