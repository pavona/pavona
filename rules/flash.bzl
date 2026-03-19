# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Rules for generating flash images."""

load("//hw/top:defs.bzl", "pavona_select_top_attr")
load("//rules:nvm.bzl", "nvm_json_builder", "nvm_partition")

def flash_info_page(name, **kwargs):
    return nvm_partition(name, **kwargs)

def _flash_info_json_impl(ctx):
    return [DefaultInfo(files = depset([nvm_json_builder(ctx)]))]

flash_info_json = rule(
    implementation = _flash_info_json_impl,
    attrs = {
        "partitions": attr.string_list(doc = "A list of serialized partitions from flash_info_page."),
    },
)

STD_FLASH_INFO_OVERLAYS = pavona_select_top_attr("std_flash_info_overlay")
