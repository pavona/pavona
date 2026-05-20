# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
load("//rules/pavona:hw.bzl", "pavona_ip")

AST = pavona_ip(
    name = "ast",
    hjson = "//hw/top_egret/ip/ast/data:ast.hjson",
)
