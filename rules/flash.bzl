# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Rules for generating flash images."""

load("//rules/opentitan:transform.bzl", "convert_to_vmem", "scramble_flash")
load("//rules/opentitan:toolchain.bzl", "LOCALTOOLS_TOOLCHAIN")
load("//rules/opentitan:util.bzl", "assemble_for_test")

def _flash_partition(ctx):
    tc = ctx.toolchains[LOCALTOOLS_TOOLCHAIN]
    """Concatenate the contents of several pages into a single partition image."""

    output = ctx.actions.declare_file(ctx.label.name + ".img")
    max_page = max([int(page) for page in ctx.attr.pages.keys()])
    spec = [
        "{}@{}".format(src.files.to_list()[0].path, ctx.attr.page_size * int(page))
        for page, src in ctx.attr.pages.items()
    ]
    partition_img = assemble_for_test(
        ctx,
        ctx.label.name,
        spec,
        [
            dep
            for target in ctx.attr.pages.values()
            for dep in target.files.to_list()
        ],
        tc.tools.opentitantool,
        size = (max_page + 1) * ctx.attr.page_size,
    )
    return [DefaultInfo(files = depset([partition_img]))]

flash_partition = rule(
    implementation = _flash_partition,
    attrs = {
        "pages": attr.string_keyed_label_dict(
            doc = "Map of pages to include in the image, indexed by page number.",
        ),
        "page_size": attr.int(
            default = 0x800,
            doc = "Flash page size in bytes.",
        ),
    },
    toolchains = [LOCALTOOLS_TOOLCHAIN],
)

def _flash_image(ctx):
    # First convert to VMEM, then scramble according to flash
    # scrambling settings.
    vmem_base = convert_to_vmem(
        ctx,
        name = ctx.label.name,
        src = ctx.attr.partition.files.to_list()[0],
        word_size = 64,
    )
    scrambled_vmem = scramble_flash(
        ctx,
        src = vmem_base,
        otp = ctx.attr.otp.files.to_list()[0],
        otp_mmap = ctx.attr.otp_mmap,
        top_secret_cfg = ctx.attr.top_secret_cfg.files.to_list()[0],
        otp_data_perm = ctx.attr.otp_data_perm,
        suffix = "64.scr.vmem",
        _tool = ctx.attr._tool.files.to_list()[0],
    )
    return [DefaultInfo(files = depset([scrambled_vmem]))]

flash_image = rule(
    implementation = _flash_image,
    attrs = {
        "partition": attr.label(
            allow_single_file = [".img"],
            doc = "Flash partition image file built by flash_partition.",
        ),
        "otp": attr.label(
            allow_single_file = [".vmem"],
            doc = "The OTP settings.",
        ),
        "otp_mmap": attr.label(
            allow_single_file = True,
            doc = "The OTP memory mapping file.",
        ),
        "top_secret_cfg": attr.label(
            allow_single_file = True,
            default = "//hw/top:secrets",
            doc = "The secret configuration file.",
        ),
        "otp_data_perm": attr.label(
            default = "//util/design/data:data_perm",
            doc = "The OTP data permutation configuration.",
        ),
        "_tool": attr.label(
            default = "//util/design:gen-flash-img",
            executable = True,
            cfg = "exec",
        ),
    },
)
