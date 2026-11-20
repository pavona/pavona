# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Rules for generating generic nonvolatile memory (NVM) maps that can be built
into image for multiple NVM types (OTP, Flash, ...).
"""

load("//rules:const.bzl", "hex")

def nvm_hex(v):
    return hex(v)

def nvm_partition(name, **kwargs):
    partition = {
        "name": name,
    }
    partition.update(kwargs)
    return json.encode(partition)

def nvm_json_builder(ctx):
    nvm = {}
    nvm["partitions"] = [json.decode(p) for p in ctx.attr.partitions]

    # For every partition with an "items" dictionary, expand the dictionary of
    # key:value pairs into a list of dicts, each of the form
    # {
    #   "name": key,
    #   "value": value
    # }
    # This format is expected by the NVM image generation tool
    for partition in nvm["partitions"]:
        if "items" in partition.keys():
            items = partition["items"]
            partition["items"] = [{"name": k, "value": v} for k, v in items.items()]

    file = ctx.actions.declare_file("{}.json".format(ctx.attr.name))
    ctx.actions.write(file, json.encode_indent(nvm))
    return file
