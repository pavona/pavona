# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules/pavona:util.bzl", "flatten")
load("//hw/top:defs.bzl", "ALL_IP_NAMES", "pavona_if_ip")
load("//rules/pavona:defs.bzl", "PAVONA_CPU")
load("//rules:autogen.bzl", "pavona_autogen_isr_testutils")

package(default_visibility = ["//visibility:public"])

pavona_autogen_isr_testutils(
    name = "isr_testutils",
    ips = ALL_IP_NAMES,
    target_compatible_with = [PAVONA_CPU],
    deps = [
               "//hw/top:top_lib",
               "//sw/device/lib/dif:rv_plic",
               "//sw/device/lib/testing/test_framework:check",
           ] + flatten([
               pavona_if_ip(
                   ip,
                   ["//sw/device/lib/dif/autogen:{}".format(ip)],
                   [],
               )
               for ip in ALL_IP_NAMES
           ]) +
           # There is a special dependency for the adc_ctrl, see testutils template.
           pavona_if_ip(
               "adc_ctrl",
               ["//sw/device/lib/dif:adc_ctrl"],
               [],
           ),
)
