#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import json
import sys
import re
from pathlib import Path
from mako.template import Template

import mdbook.utils as md_utils
from ipgen.lib import IpTemplate


REPO_TOP = Path(__file__).parents[1].resolve()
SUBST_RE = r"\$\{(?P<substitution>.*)\}"
CTRL_STRUCT_RE = (r"(?P<indentation> *)% (?P<keyword>(for|if|while|match))"
                  + r"(?P<condition>.*?):"
                  + r"(?P<action>[.\n]*?)"
                  + r"(?P=indentation)% end(?P=keyword)")  # same level of indentation
TAG_RE = r"<%/?(?P<tag>.*?)>"


def get_parameters(tpl_filepath):
    if isinstance(tpl_filepath, str):
        tpl_filepath = (REPO_TOP / tpl_filepath).resolve()
    tpldir_set = set(REPO_TOP.glob("hw/ip_templates/*")) & set(tpl_filepath.parents)
    if tpldir_set:
        return IpTemplate.from_template_path(tpldir_set.pop()).params.as_dicts()
    return None


def make_parameter_table(parameters):
    if parameters is None:
        return "\t*unknown, no template description file found*"
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
        if not src_path or ".tpl" not in src_path or ".tpldesc" in src_path:
            continue

        params = get_parameters(src_path)

        content = Template(text=chapter["content"])
        header = f"""This is a templated file.
It can be generated with the following parameters:

{make_parameter_table(params)}

"""

        try:
            assert params is not None

            # replace empty string defaults with key name
            for param in params:
                if param["default"] == "":
                    param["default"] = param["name"]

            default_values = {p["name"]: p["default"] for p in params}
            content = content.render(**default_values)
            header += ("Below is the default instantiation of the template.\n"
                       "See top-specific instantiations for other examples.")

        # data not available for substitutions and control structures
        # manually indicate parts of the template
        except (AssertionError, KeyError, TypeError, ValueError):

            content = re.sub(SUBST_RE, r"`\g<substitution>` *(template)*", chapter["content"])
            content = re.sub("% (elif|else|case)( .*):", r"`\1\2:` *(template)*", content)
            content = re.sub(CTRL_STRUCT_RE, r"`\g<indentation>\g<keyword> \g<condition>:`"
                                             r" *(template)*\n\g<action>\n"
                                             r"`\g<indentation>end\g<condition>` *(template)*",
                             content)
            content = re.sub(TAG_RE, r"`\0` *(template `\g<tag>` tag)*", content)

            header += ("See top-specific instantiations for examples of how"
                       "the template is instantiated.")

        chapter["content"] = header + "\n\n___\n\n" + content

    # Dump the book into stdout.
    print(json.dumps(book))
