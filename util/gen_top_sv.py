#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Generate top-level SystemVerilog from completecfg

This includes (relative to <outdir>/rtl/autogen):
- <outdir>/
  - rtl/autogen/
    - top_<topname>.sv
    - chip_<topname>_<target>.sv
    - top_<topname>_pkg.sv
    - top_<topname>_<memory>_pkg.sv
    - top_racl_pkg.sv
    - top_<topname>_racl_pkg.sv
    - <lc_ctrl seed mode>/
      - lc_ctrl_token_pkg.sv
      - top_<topname>_<lc_ctrl seed mode>_lc_ctrl_token_pkg.core
    - <topgen seed mode>/
      - top_<topname>_rnd_cnst_pkg.sv
      - top_<topname>_rnd_cnst_pkg.vbl
      - top_<topname>_<topgen seed mode>_rnd_cnst_pkg.core
  - dv/
    - autogen/
      - xbar_env_pkg__params.sv
      - tb__xbar_connect.sv
      - xbar_tgl_excl.cfg
      - rstmgr_tgl_excl.cfg
    - env/autogen/
      - chip_env_pkg__params.sv
(Also regenerates hw/ip/lc_ctrl/rtl/lc_ctrl_state_pkg.sv)

Tool generates, from templates and complete top config info, top level RTL, random constants, and
other needed hardware files (e.g., FuseSoC cores).
"""
import argparse
from pathlib import Path
import logging as log
from mako.template import Template
from mako.lookup import TemplateLookup
from mako import exceptions
from topgen.lib import (load_cfg, write_file_secure, get_ip_hjson_path, find_module,
                        find_module_by_name, get_addr_space_suffix)
from basegen.typing import ConfigT
from topgen.typing import IpBlocksT
from reggen.ip_block import IpBlock
from topgen.secure_prng import SecurePrngFactory
from design.lib.LcStEnc import LcStEnc
from raclgen.lib import DEFAULT_RACL_CONFIG
from topgen.clocks import Clocks, UnmanagedClocks
from topgen.resets import Resets, UnmanagedResets
from reggen.params import Parameter
from topgen.c_test import TopGenCTest


HEADER = """//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
//
// util/gen_top_sv.py --completecfg {}
//                    --seedcfg {}
"""
REPO_TOP = Path(__file__).parents[1].resolve()
IP_RAW_PATH = REPO_TOP / "hw" / "ip"
TOPGEN_TEMPLATE_PATH = Path(__file__).parent.resolve() / "topgen" / "templates"


def generate_top(top: ConfigT, name_to_block: IpBlocksT, tpl_filename: str,
                 **kwargs: dict[str, object]) -> None:
    top_tpl = Template(filename=tpl_filename,
                       lookup=TemplateLookup([TOPGEN_TEMPLATE_PATH, "/"]))

    try:
        return top_tpl.render(top=top, name_to_block=name_to_block, **kwargs)
    except:  # noqa: E722
        log.error(exceptions.text_error_template().render())
        return ""


def render_template(top: ConfigT, name_to_block: IpBlocksT, template_path: str, rendered_path: Path,
                    secure: bool = False, **other_info):
    """Render template to file, optionally with secure permissions for sensitive files"""
    template_contents = generate_top(top, name_to_block,
                                     str(template_path), **other_info)

    if secure:
        # Use the write_file_secure for writting file with restricted file permissions
        write_file_secure(rendered_path, template_contents)
    else:
        rendered_path.parent.mkdir(exist_ok=True, parents=True)
        rendered_path.write_text(template_contents, encoding="UTF-8")


def generate_sv(topcfg, seedcfg, out_path, name_to_block, top_template_path,
                gencmd_sv=HEADER.format("", "")):
    topname = topcfg["name"]
    top_name = "top_" + topname

    # SystemVerilog Top:
    # "toplevel.sv.tpl" -> "rtl/autogen/{top_name}.sv"
    render_template(topcfg, name_to_block,
                    top_template_path / "toplevel.sv.tpl",
                    out_path / "rtl" / "autogen" / f"{top_name}.sv",
                    gencmd=gencmd_sv)

    # Multiple chip-levels (ASIC, FPGA, Verilator, etc)
    for target in topcfg["targets"]:
        target_name = target["name"]
        render_template(topcfg, name_to_block,
                        top_template_path / "chiplevel.sv.tpl",
                        out_path /
                        f"rtl/autogen/chip_{topname}_{target_name}.sv",
                        gencmd=gencmd_sv,
                        target=target)

    # RACL
    racl_config = topcfg.get('racl', DEFAULT_RACL_CONFIG)
    render_template(topcfg, name_to_block,
                    TOPGEN_TEMPLATE_PATH / 'top_racl_pkg.sv.tpl',
                    out_path / 'rtl' / 'autogen' / 'top_racl_pkg.sv',
                    gencmd=gencmd_sv,
                    topcfg=topcfg,
                    racl_config=racl_config)
    render_template(topcfg, name_to_block,
                    TOPGEN_TEMPLATE_PATH / 'toplevel_racl_pkg.sv.tpl',
                    out_path / 'rtl' / 'autogen' /
                    f'top_{topname}_racl_pkg.sv',
                    gencmd=gencmd_sv,
                    topcfg=topcfg,
                    racl_config=racl_config)

    # "toplevel_pkg.sv.tpl" -> "rtl/autogen/{top_name}{addr_space_suffix}_pkg.sv"
    c_helper = TopGenCTest(topcfg, name_to_block)
    for addr_space in topcfg['addr_spaces']:
        addr_space_suffix = get_addr_space_suffix(addr_space)
        render_template(topcfg, name_to_block,
                        TOPGEN_TEMPLATE_PATH / "toplevel_pkg.sv.tpl",
                        out_path / "rtl" / "autogen" / f"{top_name}{addr_space_suffix}_pkg.sv",
                        helper=c_helper,
                        addr_space=addr_space,
                        gencmd=gencmd_sv)

    # lc_ctrl
    if find_module(topcfg["module"], "lc_ctrl"):
        lc_state_def_file = load_cfg(IP_RAW_PATH / "lc_ctrl" / "data" / "lc_ctrl_state.hjson")
        lc_seed = seedcfg["seed"]["lc_ctrl_seed"]
        lc_st_enc = LcStEnc(lc_state_def_file, int(lc_seed["value"]))
        lc_st_enc_path = f"rtl/autogen/{lc_seed['seed_mode']}"
        lc_st_enc_file = "lc_ctrl_token_pkg.sv"
        render_template(topcfg, name_to_block,
                        IP_RAW_PATH / "lc_ctrl" / "rtl" / "lc_ctrl_state_pkg.sv.tpl",
                        IP_RAW_PATH / "lc_ctrl" / "rtl" / "lc_ctrl_state_pkg.sv",
                        lc_st_enc=lc_st_enc)
        render_template(topcfg, name_to_block,
                        IP_RAW_PATH / "lc_ctrl" / "rtl" / "lc_ctrl_token_pkg.sv.tpl",
                        out_path / lc_st_enc_path / lc_st_enc_file,
                        secure=True, lc_st_enc=lc_st_enc)
        render_template(topcfg, name_to_block,
                        TOPGEN_TEMPLATE_PATH / "core_file.core.tpl",
                        out_path / lc_st_enc_path /
                        f"top_{topname}_{lc_seed['seed_mode']}_lc_ctrl_token_pkg.core",
                        package=(
                            f"lowrisc:{topname}_constants:"
                            f"{lc_seed['seed_mode']}_lc_ctrl_token_pkg:0.1"
                        ),
                        description="LC Controller Token Package",
                        virtual_package="lowrisc:virtual_constants:lc_ctrl_token_pkg",
                        dependencies=["lowrisc:ip:lc_ctrl_state_pkg"],
                        files=[lc_st_enc_file])

    # generate chip level xbar and alert_handler TB
    tb_files = [
        "xbar_env_pkg__params.sv", "tb__xbar_connect.sv",
        "xbar_tgl_excl.cfg", "rstmgr_tgl_excl.cfg"
    ]
    if topcfg["alert"]:
        tb_files += ["tb__alert_handler_connect.sv"]

    for fname in tb_files:
        tpl_fname = "%s.tpl" % (fname)
        xbar_chip_data_path = TOPGEN_TEMPLATE_PATH / tpl_fname
        template_contents = generate_top(topcfg,
                                         name_to_block,
                                         str(xbar_chip_data_path),
                                         gencmd=gencmd_sv)

        rendered_dir = out_path / "dv/autogen"
        rendered_dir.mkdir(parents=True, exist_ok=True)
        rendered_path = rendered_dir / fname

        with rendered_path.open(mode="w", encoding="UTF-8") as fout:
            fout.write(template_contents)

    # generate parameters for chip-level environment package
    tpl_fname = "chip_env_pkg__params.sv.tpl"
    alert_handler_chip_data_path = TOPGEN_TEMPLATE_PATH / tpl_fname
    template_contents = generate_top(topcfg, name_to_block,
                                     str(alert_handler_chip_data_path))

    rendered_dir = out_path / "dv/env/autogen"
    rendered_dir.mkdir(parents=True, exist_ok=True)
    rendered_path = rendered_dir / "chip_env_pkg__params.sv"

    with rendered_path.open(mode="w", encoding="UTF-8") as fout:
        fout.write(template_contents)


def reapply_random_params(topcfg, seedcfg):
    for mod_with_rnd in seedcfg["module"]:
        top_module = find_module_by_name(topcfg["module"], mod_with_rnd["name"])
        assert top_module is not None, "an IP block in the seed cfg was not found in the top config"
        for p in mod_with_rnd["param_list"]:
            top_module["param_list"].append(p)


def generate_from_random(topcfg, seedcfg, out_path, name_to_block, seed_path,
                         gencmd_sv=HEADER.format("", "")):
    topname = topcfg["name"]
    top_name = "top_" + topname

    # compile-time random netlist constants
    gencmd_rnd_cnst_sv = gencmd_sv + f"""//
// File is generated based on the following seed configuration:
//   {seed_path.resolve().relative_to(REPO_TOP)}
"""
    topgen_seed = seedcfg["seed"]["topgen_seed"]
    seed_mode = topgen_seed["seed_mode"]
    rnd_cnst_path = f"rtl/autogen/{seed_mode}"
    rnd_cnst_file = f"{top_name}_rnd_cnst_pkg"
    rnd_cnst_sv_file = f"{rnd_cnst_file}.sv"
    rnd_cnst_vbl_file = f"{rnd_cnst_file}.vbl"

    # Determine the dependencies for the random netlist constant package. This construction
    # depends on which modules are present in the top configuration and which require random
    # netlist constants.
    rnd_cnst_deps = []
    RND_CNST_DEPENDENCIES = {
        # ipgen-based modules (using template_type)
        "flash_ctrl": [f"lowrisc:{topname}_ip:flash_ctrl"],
        "otp_ctrl": [
            f"lowrisc:{topname}_ip:otp_ctrl_top_specific_pkg",
            "lowrisc:ip:otp_ctrl_pkg"
        ],
        "alert_handler": [f"lowrisc:{topname}_ip:alert_handler_pkg"],
        "rv_core_ibex": ["lowrisc:ibex:ibex_pkg"],

        # Direct IP modules (using type)
        "lc_ctrl": ["lowrisc:ip:lc_ctrl_pkg"],
        "sram_ctrl": ["lowrisc:ip:sram_ctrl_pkg"],
        "aes": ["lowrisc:ip:aes"],
        "kmac": ["lowrisc:ip:kmac_pkg"],
        "acc": ["lowrisc:ip:acc_pkg"],
        "keymgr": ["lowrisc:ip:keymgr_pkg"],
        "csrng": ["lowrisc:ip:csrng_pkg"],
    }

    for m in topcfg["module"]:
        template_type = m.get("template_type", "")
        if template_type and template_type in RND_CNST_DEPENDENCIES:
            deps = RND_CNST_DEPENDENCIES[template_type]
            rnd_cnst_deps.extend(deps)
            continue

        module_type = m["type"]
        if module_type in RND_CNST_DEPENDENCIES:
            deps = RND_CNST_DEPENDENCIES[module_type]
            rnd_cnst_deps.extend(deps)

    # Ensure the dependencies are unique and sorted
    rnd_cnst_deps = sorted(list(set(rnd_cnst_deps)))

    render_template(topcfg, name_to_block,
                    TOPGEN_TEMPLATE_PATH / "toplevel_rnd_cnst_pkg.sv.tpl",
                    out_path / rnd_cnst_path / rnd_cnst_sv_file,
                    secure=True, gencmd=gencmd_rnd_cnst_sv)

    # Create verible waiver file for the random constant package for long lines.
    rnd_cnst_vbl_file_path = out_path / rnd_cnst_path / f"{rnd_cnst_file}.vbl"
    with rnd_cnst_vbl_file_path.open(mode="w", encoding="UTF-8") as fout:
        fout.write("""# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
                   + (gencmd_rnd_cnst_sv).replace("//", "#") + f"""
# These lines are too long due to templating
waive --rule=line-length --location="{rnd_cnst_sv_file}"
""")
    render_template(topcfg, name_to_block,
                    TOPGEN_TEMPLATE_PATH / "core_file.core.tpl",
                    out_path / rnd_cnst_path / f"top_{topname}_{seed_mode}_rnd_cnst_pkg.core",
                    package=f"lowrisc:{topname}_constants:{seed_mode}_rnd_cnst_pkg:0.1",
                    description="Random netlist constant package",
                    virtual_package="lowrisc:virtual_constants:rnd_cnst_pkg",
                    dependencies=rnd_cnst_deps,
                    files=[rnd_cnst_sv_file],
                    files_veriblelint_waiver=rnd_cnst_vbl_file)


def recast_widths(intersignals: list):
    for ix, intersig in enumerate(intersignals):
        width = intersig["width"]
        if isinstance(width, Parameter):
            continue
        elif isinstance(width, dict):
            intersig["width"] = Parameter(
                width["name"],
                width.get("desc"),
                width["param_type"],
                width.get("unpacked_dimensions"),
                width["default"],
                width["local"],
                width["expose"],
                width.get("name_top"))
            intersig["width"].name_top = width["name_top"]
        else:
            intersig["width"] = int(width)


def correct_null(from_hjson):
    if from_hjson == "null":
        return None
    elif isinstance(from_hjson, dict):
        for k, v in from_hjson.items():
            from_hjson[k] = correct_null(v)
            proper_k = correct_null(k)
            if k != proper_k:
                from_hjson[proper_k] = from_hjson[k]
                del from_hjson[k]
    elif type(from_hjson) in (list, tuple, set):
        return type(from_hjson)(correct_null(item) for item in from_hjson)
    return from_hjson


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--completecfg", "-t",
                        required=True,
                        type=Path,
                        help="Complete top configuration Hjson.")
    parser.add_argument("--seedcfg", "-s",
                        required=True,
                        type=Path,
                        help="Top level random seed configuration.")
    parser.add_argument("--toplevel-template-path", "-p",
                        type=Path,
                        default=None,
                        help="Path to top-specific templates. Defaults to"
                        " $(dirname completecfg)/../../templates.")
    parser.add_argument("--outdir", "-o",
                        type=Path,
                        default=None,
                        help="Target output directory. Defaults to $(dirname completecfg)/../..")
    args = parser.parse_args()

    completecfg = load_cfg(args.completecfg)
    seedcfg = load_cfg(args.seedcfg)

    # correct object typing in top complete config
    completecfg["clocks"] = Clocks(completecfg["clocks"])
    completecfg["unmanaged_clocks"] = UnmanagedClocks(completecfg["unmanaged_clocks"])
    completecfg["resets"] = Resets(completecfg["resets"], completecfg["clocks"])
    completecfg["unmanaged_resets"] = UnmanagedResets(completecfg["unmanaged_resets"])
    reapply_random_params(completecfg, seedcfg)
    for intersig_set in completecfg["inter_signal"].keys():
        recast_widths(completecfg["inter_signal"][intersig_set])
    correct_null(completecfg)

    name_to_block = {}
    for module in completecfg["module"]:
        block_type = module["type"]
        ip_hjson = get_ip_hjson_path(block_type, completecfg, REPO_TOP)
        name_to_block[block_type] = IpBlock.from_path(str(ip_hjson), [])
        for intersig in module["inter_signal_list"]:
            recast_widths(module["inter_signal_list"])

    # correctly handle other arguments
    toplevel_template_path = (args.toplevel_template_path
                              or args.completecfg.parents[2] / "templates").resolve()
    outdir = args.outdir or args.completecfg.parents[2].resolve()

    # set random seed and generated file header
    SecurePrngFactory.create("topgen", int(seedcfg["seed"]["topgen_seed"]["value"]))
    gencmd_sv = HEADER.format(args.completecfg.relative_to(REPO_TOP),
                              args.seedcfg.relative_to(REPO_TOP))

    # generate files
    generate_sv(completecfg, seedcfg, outdir, name_to_block, toplevel_template_path, gencmd_sv)
    generate_from_random(completecfg, seedcfg, outdir, name_to_block, args.seedcfg, gencmd_sv)


if __name__ == "__main__":
    main()
