# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Code to generate crossbar RTL."""

import logging as log
from typing import Any, List, Tuple

from mako import exceptions  # type: ignore
from mako.template import Template  # type: ignore
import importlib.resources

from .xbar import Xbar


def generate(xbar: Xbar, outpath: str, library_name: str = "ip") -> List[Tuple[str, Any]]:
    """Create top-level crossbar module.

    This assumes that the model has been elaborated already. Returns a list of
    pairs of files to write, each in the form (path, contents).
    """
    xbar_rtl_tpl = Template(
        filename=str(importlib.resources.files('tlgen') / 'xbar.rtl.sv.tpl'))
    xbar_pkg_tpl = Template(
        filename=str(importlib.resources.files('tlgen') / 'xbar.pkg.sv.tpl'))
    xbar_core_tpl = Template(
        filename=str(importlib.resources.files('tlgen') / 'xbar.core.tpl'))
    xbar_hjson_tpl = Template(
        filename=str(importlib.resources.files('tlgen') / 'xbar.hjson.tpl'))
    xbar_build_tpl = Template(
        filename=str(importlib.resources.files('tlgen') / 'xbar.BUILD.tpl'))
    xbar_databuild_tpl = Template(
        filename=str(importlib.resources.files('tlgen') / 'xbar.data_BUILD.tpl'))
    try:
        out_rtl = xbar_rtl_tpl.render(xbar=xbar)
        out_pkg = xbar_pkg_tpl.render(xbar=xbar)
        out_core = xbar_core_tpl.render(xbar=xbar,
                                        library_name=library_name)
        out_hjson = xbar_hjson_tpl.render(xbar=xbar)
        out_build = xbar_build_tpl.render(xbar=xbar, outpath=outpath)
        out_databuild = xbar_databuild_tpl.render(xbar=xbar, outpath=outpath)
    except:  # noqa: E722
        log.error(exceptions.text_error_template().render())

    results = []
    results.append(("rtl/autogen/xbar_%s.sv" % (xbar.name), out_rtl))
    results.append(("rtl/autogen/tl_%s_pkg.sv" % (xbar.name), out_pkg))
    results.append(("xbar_%s.core" % (xbar.name), out_core))
    results.append(("data/autogen/xbar_%s.hjson" % (xbar.name), out_hjson))
    results.append(("BUILD", out_build))
    results.append(("data/BUILD", out_databuild))

    return results
