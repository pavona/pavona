# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

SPI_HOST = pavona_ip(
    name = "spi_host",
    hjson = "//hw/ip/spi_host/data:spi_host.hjson",
)
