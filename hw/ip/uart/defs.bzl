# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

UART = pavona_ip(
    name = "uart",
    hjson = "//hw/ip/uart/data:uart.hjson",
)
