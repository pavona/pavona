# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

I2C = pavona_ip(
    name = "i2c",
    hjson = "//hw/ip/i2c/data:i2c.hjson",
)
