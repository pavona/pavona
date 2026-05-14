#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import json
import sys
import hjson
from pathlib import Path

import mdbook.utils as md_utils
from ipgen.lib import IpTemplate


REPO_TOP = Path(__file__).parents[1].resolve()

TPLDESC_TEXT = """This is a templated IP that is based on the following parameters:
{}

See top-specific instantiations for more information."""

IPCONFIG_TEXT = """This IP was configured with the following parameters:
{}"""


def get_parameters(tpl_filepath):
    if isinstance(tpl_filepath, str):
        tpl_filepath = (REPO_TOP / tpl_filepath).resolve()
    tpldir = tpl_filepath.parents[1]
    return IpTemplate.from_template_path(tpldir).params.as_dicts()


def get_config_params(cfg_filepath):
    if isinstance(cfg_filepath, str):
        cfg_filepath = (REPO_TOP / cfg_filepath).resolve()
    params = []

    cfg_dict = hjson.loads(cfg_filepath.read_text())
    param_dict = cfg_dict["param_values"]
    dtgen_dict = cfg_dict.get("dtgen", {})

    for param_name in (param_dict | dtgen_dict).keys():
        dtgen_details = dtgen_dict.get(param_name)
        params.append({"name": param_name,
                       "value": param_dict.get(param_name, "default"),
                       "dtgen": f"{dtgen_details['name']} ({dtgen_details['type']})"
                                if dtgen_details is not None else ""})
    return params


def make_parameter_table(parameters, ip_cfg=False):
    if parameters is None:
        return "\t*unknown, no template description file found*"
    elif ip_cfg:
        param_table = ["| name | value | dtgen |",
                       "| ---- | ----- | ----- |"]
        for param_dict in parameters:
            param_table.append("| "
                               + " | ".join([str(param_dict[col])
                                             for col in ("name", "value", "dtgen")])
                               + " |")
    else:
        param_table = ["| name | type | default | dtgen | description |",
                       "| ---- | ---- | ------- | ----- | ----------- |"]
        for param_dict in parameters:
            param_table.append("| "
                               + " | ".join((param_dict["name"],
                                             param_dict["type"],
                                             str(param_dict["default"]),
                                             str("dtgen" in param_dict.keys()).lower(),
                                             param_dict.get("description", "none")))
                               + " |")
    return "\n".join(param_table)


if __name__ == "__main__":
    md_utils.supports_html_only()

    context, book = json.load(sys.stdin)

    for chapter in md_utils.chapters(book["sections"]):
        src_path = chapter["source_path"]

        # render template descriptions
        if ".tpldesc.hjson" in src_path:
            params = get_parameters(src_path)
            chapter["content"] = TPLDESC_TEXT.format(make_parameter_table(params))

        # render ip configurations
        elif ".ipconfig.hjson" in src_path:
            params = get_config_params(src_path)
            chapter["content"] = IPCONFIG_TEXT.format(
                make_parameter_table(params, True))

    # Dump the book into stdout.
    print(json.dumps(book))
