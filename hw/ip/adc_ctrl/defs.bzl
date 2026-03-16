# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

ADC_CTRL = pavona_ip(
    name = "adc_ctrl",
    hjson = "//hw/ip/adc_ctrl/data:adc_ctrl.hjson",
)
