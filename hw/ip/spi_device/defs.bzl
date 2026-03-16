# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

SPI_DEVICE = pavona_ip(
    name = "spi_device",
    hjson = "//hw/ip/spi_device/data:spi_device.hjson",
)
