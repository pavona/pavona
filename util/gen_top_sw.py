#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Generate top-specific C, Rust, and/or Bazel software files

C files generated (relative to <outdir>/sw/autogen):
    - tests/
      - plic_all_irqs_test.c
      - alert_test.c      # only if top has alert_handler module
    - .clang-format
    - top_<topname><addr_space_suffix>.c
    - top_<topname><addr_space_suffix>_memory.h
    - top_<topname>_memory.ld

Rust files generated (relative to <outdir>/sw/autogen):
    - chip/
      - mod.rs
      - top_<topname><addr_space_suffix>.rs
(Also generates sw/host/ot_hal/src/top/autogen/<topname><addr_space_suffix>.rs)

Bazel files generated (relative to <outdir>):
  - sw/autogen/
    - tests/BUILD
    - BUILD
  - data/autogen
    - BUILD
    - defs.bzl
"""
import argparse
from pathlib import Path
import logging as log
from topgen.lib import load_cfg, find_module, get_ip_hjson_path, get_addr_space_suffix
from mako.lookup import TemplateLookup
from mako.template import Template
from mako import exceptions

from basegen.typing import ConfigT
from topgen.typing import IpBlocksT
from topgen.rust import TopGenRust
from topgen.c_test import TopGenCTest
import version_file
from reggen.ip_block import IpBlock
from topgen.clocks import Clocks
from topgen.resets import Resets


REPO_TOP = Path(__file__).parents[1].resolve()
TOPGEN_TEMPLATE_PATH = Path(__file__).parent.resolve() / "topgen" / "templates"
HEADER = """//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
// util/gen_top_sw.py -t {}"""


def render_template(template_path: str, rendered_path: Path, topcfg: ConfigT,
                    name_to_block: dict, **other_info):
    """Render template to file, optionally with secure permissions for sensitive files"""
    template_contents = generate_top(topcfg, name_to_block,
                                     str(template_path), **other_info)
    rendered_path.parent.mkdir(exist_ok=True, parents=True)
    rendered_path.write_text(template_contents, encoding="UTF-8")


def generate_top(top: ConfigT, name_to_block: IpBlocksT, tpl_filename: str,
                 **kwargs: dict[str, object]) -> None:
    top_tpl = Template(filename=tpl_filename,
                       lookup=TemplateLookup([TOPGEN_TEMPLATE_PATH, "/"]))

    try:
        return top_tpl.render(top=top, name_to_block=name_to_block, **kwargs)
    except:  # noqa: E722
        log.error(exceptions.text_error_template().render())
        return ""


def generate_rust(topname, topcfg, name_to_block, out_path, version_stamp,
                  src_tree_top, topgen_template_path) -> None:
    # Create Rust output directory
    rsformat_dir = out_path / "sw/autogen/chip/"
    rsformat_dir.mkdir(parents=True, exist_ok=True)

    # Generating Rust device description for external sw usage
    render_template(topgen_template_path / 'toplevel_mod.rs.tpl',
                    rsformat_dir / 'mod.rs', topcfg, name_to_block)

    for addr_space in topcfg['addr_spaces']:
        addr_space_suffix = get_addr_space_suffix(addr_space)

        # The Rust file needs some complex information, so we initialize this
        # object to store it.
        rs_helper = TopGenRust(topcfg, name_to_block, version_stamp)

        # Generate Rust device-side files
        rsformat_dir = out_path / "sw/autogen/chip/"
        render_template(topgen_template_path / 'toplevel.rs.tpl',
                        rsformat_dir / f"top_{topname}{addr_space_suffix}.rs",
                        topcfg, name_to_block,
                        addr_space=addr_space['name'],
                        helper=rs_helper)

        # Generate Rust host-side files
        rsformat_dir = src_tree_top / 'sw/host/ot_hal/src/top/autogen'
        rsformat_dir.mkdir(parents=True, exist_ok=True)
        render_template(topgen_template_path / 'host_toplevel.rs.tpl',
                        rsformat_dir / f"{topname}{addr_space_suffix}.rs",
                        topcfg, name_to_block,
                        addr_space=addr_space['name'],
                        helper=rs_helper)


def generate_c(topcfg, name_to_block, root_paths, out_paths, c_helper, gencmd_c,
               default_addr_space="hart"):
    top_name = "top_" + topcfg["name"]

    for root, path in zip(root_paths, out_paths):
        sw_dir = path / "sw" / "autogen"
        sw_dir.mkdir(parents=True, exist_ok=True)

        test_dir = sw_dir / "tests"
        test_dir.mkdir(parents=True, exist_ok=True)

        # "clang-format" -> "sw/autogen/.clang-format"
        cformat_tplpath = TOPGEN_TEMPLATE_PATH / "clang-format"
        cformat_path = sw_dir / ".clang-format"
        cformat_path.write_text(cformat_tplpath.read_text())

        # Save the header macro prefix into `c_helper`
        rel_header_dir = sw_dir.relative_to(root)
        c_helper.header_macro_prefix = (
            "OPENTITAN_" +
            str(rel_header_dir).replace("/", "_").upper())

        for addr_space in topcfg['addr_spaces']:
            addr_space_suffix = get_addr_space_suffix(addr_space, default=default_addr_space)

            # "toplevel.h.tpl" -> "sw/autogen/{top_name}{addr_space_suffix}.h"
            cheader_path = sw_dir / f"{top_name}{addr_space_suffix}.h"
            render_template(TOPGEN_TEMPLATE_PATH / "toplevel.h.tpl",
                            cheader_path,
                            topcfg, name_to_block,
                            addr_space=addr_space['name'],
                            helper=c_helper,
                            gencmd=gencmd_c)

            # Save the relative header path into `c_helper`
            rel_header_path = cheader_path.relative_to(root)
            c_helper.header_path = str(rel_header_path)

            # "toplevel.c.tpl" -> "sw/autogen/{top_name}{addr_space_suffix}.c"
            render_template(TOPGEN_TEMPLATE_PATH / "toplevel.c.tpl",
                            sw_dir / f"{top_name}{addr_space_suffix}.c",
                            topcfg, name_to_block,
                            helper=c_helper,
                            addr_space=addr_space['name'],
                            gencmd=gencmd_c)

            # "toplevel_memory.h.tpl" -> "sw/autogen/{top_name}{addr_space_suffix}_memory.h"
            render_template(TOPGEN_TEMPLATE_PATH / "toplevel_memory.h.tpl",
                            sw_dir / f"{top_name}{addr_space_suffix}_memory.h",
                            topcfg, name_to_block,
                            addr_space=addr_space['name'],
                            helper=c_helper,
                            gencmd=gencmd_c)

        # "toplevel_memory.ld.tpl" -> "sw/autogen/{top_name}_memory.ld"
        render_template(
            TOPGEN_TEMPLATE_PATH / "toplevel_memory.ld.tpl",
            sw_dir / f"{top_name}_memory.ld",
            topcfg, name_to_block,
            addr_space=default_addr_space,
            helper=c_helper,
            gencmd=gencmd_c)

        render_template(
            TOPGEN_TEMPLATE_PATH / "plic_all_irqs_test.c.tpl",
            test_dir / "plic_all_irqs_test.c",
            topcfg, name_to_block,
            helper=c_helper,
            addr_space=default_addr_space,
            gencmd=gencmd_c)

        # Render alert tests only if there is really an alert handler
        if find_module(topcfg['module'], 'alert_handler'):
            render_template(
                TOPGEN_TEMPLATE_PATH / "alert_test.c.tpl",
                test_dir / "alert_test.c",
                topcfg, name_to_block,
                helper=c_helper,
                addr_space=default_addr_space,
                gencmd=gencmd_c)


def generate_bazel(topcfg, name_to_block, root_paths, out_paths, c_helper, gencmd_bzl,
                   default_addr_space="hart"):
    for path in out_paths:
        sw_dir = path / "sw" / "autogen"
        sw_dir.mkdir(parents=True, exist_ok=True)

        data_dir = path / "data" / "autogen"
        data_dir.mkdir(parents=True, exist_ok=True)

        # "toplevel_BUILD.tpl" -> "sw/autogen/BUILD"
        render_template(TOPGEN_TEMPLATE_PATH / "toplevel_BUILD.tpl",
                        sw_dir / "BUILD",
                        topcfg, name_to_block,
                        helper=c_helper,
                        gencmd=gencmd_bzl)

        # "data_BUILD.h.tpl" -> "data/autogen/BUILD"
        render_template(TOPGEN_TEMPLATE_PATH / "data_BUILD.tpl",
                        data_dir / "BUILD",
                        topcfg, name_to_block,
                        gencmd=gencmd_bzl)

        # "data_defs.bzl.tpl" -> "data/autogen/defs.bzl"
        render_template(TOPGEN_TEMPLATE_PATH / "data_defs.bzl.tpl",
                        data_dir / "defs.bzl",
                        topcfg, name_to_block,
                        gencmd=gencmd_bzl)

        # "BUILD.tpl" -> "sw/autogen/tests" (autogenerate tests)
        render_template(
            TOPGEN_TEMPLATE_PATH / "BUILD.tpl",
            sw_dir / "tests" / "BUILD",
            topcfg, name_to_block,
            helper=c_helper,
            addr_space=default_addr_space,
            gencmd=gencmd_bzl)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--completecfg", "-t",
                        type=Path,
                        required=True,
                        help="Complete top level configuration Hjson.")
    parser.add_argument("--sw", "-s",
                        type=str,
                        default="all",
                        choices={"all", "c", "rust", "bazel"},
                        help="Type of software to generate from/for top level. Must be one of:"
                             " 'all', 'c', 'rust', 'bazel'.")
    parser.add_argument("--outdir", "-o",
                        type=Path,
                        default=None,
                        help="Target output directory. Defaults to $(dirname completecfg)/../..")
    parser.add_argument("--version-stamp", "--vs",
                        type=Path,
                        default=None,
                        help='If version stamping, the location of workspace version stamp file.')
    parser.add_argument("--default-addr-space", "-d",
                        type=str,
                        default="hart",
                        help="Default address space for C headers and tests. Defaults to 'hart'.")
    parser.add_argument("--verbose", "-v",
                        type=bool)
    args = parser.parse_args()

    completecfg = load_cfg(args.completecfg)
    outdir = args.outdir or args.completecfg.parents[2].resolve()

    name_to_block = {}
    for module in completecfg["module"]:
        block_type = module["type"]
        ip_hjson = get_ip_hjson_path(block_type, completecfg, REPO_TOP)
        name_to_block[block_type] = IpBlock.from_path(str(ip_hjson), [])

        # fix translation between Python None and value "null" in Hjson
        if "null" in module["base_addrs"]:
            module["base_addrs"][None] = module["base_addrs"]["null"]

    completecfg["clocks"] = Clocks(completecfg["clocks"])
    completecfg["resets"] = Resets(completecfg["resets"], completecfg["clocks"])

    # The C files needs some complex information, so we initialize this
    # object to store it.
    c_helper = TopGenCTest(completecfg, name_to_block)

    # Since SW does not use FuseSoC and instead expects those files always
    # to be in hw/top_{topname}/sw/autogen, we currently create these files
    # twice:
    # - Once under {outdir}/sw/autogen
    # - Once under hw/top_{topname}/sw/autogen
    topname = "top_" + completecfg["name"]
    if outdir != REPO_TOP / "hw" / topname:
        root_paths = [outdir.resolve(), REPO_TOP]
        out_paths = [outdir.resolve(), (REPO_TOP / "hw" / topname).resolve()]
    else:
        root_paths = [REPO_TOP]
        out_paths = [(REPO_TOP / "hw" / topname).resolve()]

    # Extract version stamp from file
    version_stamp = version_file.VersionInformation(args.version_stamp)

    if args.sw in ("c", "all"):
        gencmd_c = HEADER.format(args.completecfg.relative_to(REPO_TOP))
        generate_c(completecfg, name_to_block, root_paths, out_paths, c_helper, gencmd_c,
                   args.default_addr_space)
    if args.sw in ("rust", "all"):
        generate_rust(completecfg["name"], completecfg, name_to_block, outdir,
                      version_stamp, REPO_TOP, TOPGEN_TEMPLATE_PATH)
    if args.sw in ("bazel", "all"):
        gencmd_bzl = HEADER.replace("//", "#").format(args.completecfg.relative_to(REPO_TOP))
        generate_bazel(completecfg, name_to_block, root_paths, out_paths, c_helper, gencmd_bzl,
                       args.default_addr_space)


if __name__ == "__main__":
    main()
