# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

GPIO = pavona_ip(
    name = "gpio",
    hjson = "//hw/top_darjeeling/ip_autogen/gpio/data:gpio.hjson",
    ipconfig = "//hw/top_darjeeling/ip_autogen/gpio/data:top_darjeeling_gpio.ipconfig.hjson",
)
