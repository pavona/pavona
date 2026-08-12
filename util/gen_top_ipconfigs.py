#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Generate ipgen IP configuration files from a complete top configuration.

IP configurations correspond to either IP templates or xbars that a top level must instantiate.
Optionally, this tool can select which configuration files to generate.
"""
import argparse
import logging as log
from pathlib import Path
from typing import Dict
import hjson
from basegen.typing import ParamsT
from ipgen.lib import IpConfig, IpTemplate
from topgen.lib import load_cfg, is_ipgen
from topgen.merge import extract_clocks
from ipgen.clkmgr_gen import get_clkmgr_params

from topgen.secure_prng import SecurePrngFactory
from topgen.clocks import Clocks
from topgen.resets import Resets
from topgen.params import (get_alert_handler_params, get_pinmux_params, get_pwrmgr_params,
                           get_rstmgr_params, get_flash_ctrl_params, get_otp_ctrl_params,
                           get_ac_range_check_params, get_racl_params, get_rv_plic_params,
                           get_basic_ipgen_params)


REPO_TOP = Path(__file__).parents[1].resolve()
IP_TEMPLATES_PATH = REPO_TOP / "hw" / "ip_templates"

HEADER = """// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
// util/top_ipconfigs.py {} -o {}

"""


def get_params(topcfg: Dict[str, object], module: Dict, cfg_path: Path) -> ParamsT:
    if not isinstance(topcfg["clocks"], Clocks):
        topcfg["clocks"] = Clocks(topcfg["clocks"])
    if not isinstance(topcfg["resets"], Resets):
        topcfg["resets"] = Resets(topcfg["resets"], topcfg["clocks"])
    match module["template_type"]:
        case "alert_handler":
            return get_alert_handler_params(topcfg, module["name"])
        case "pinmux":
            return get_pinmux_params(topcfg)
        case "pwrmgr":
            return get_pwrmgr_params(topcfg)
        case "rstmgr":
            return get_rstmgr_params(topcfg)
        case "flash_ctrl":
            return get_flash_ctrl_params(topcfg)
        case "otp_ctrl":
            # complete top config should be within hw/top_*/data/autogen
            return get_otp_ctrl_params(topcfg, cfg_path)
        case "ac_range_check":
            return get_ac_range_check_params(topcfg)
        case "racl_ctrl":
            return get_racl_params(topcfg)
        case "rv_plic":
            return get_rv_plic_params(topcfg, module["name"])
        case "clkmgr":
            return get_clkmgr_params(topcfg)
        case _:
            return get_basic_ipgen_params(topcfg, module["template_type"])


def ipgen_is_selected(ip: dict, valid_ips: list[str] | None = None):
    if valid_ips is None:
        return True
    return (ip.get("template_type") in valid_ips
            or ip.get("name") in valid_ips
            or "xbar_" + ip.get("name") in valid_ips)  # for xbars


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--completecfg", "-t",
                        type=Path,
                        required=True,
                        help="Complete top configuration.")
    parser.add_argument("--seedcfg", "-s",
                        type=Path,
                        default=None,
                        help="Top seed configuration. Required for some ipgen IPs.")
    parser.add_argument("--outdir", "-o",
                        required=True,
                        type=Path,
                        help="Output directory.")
    parser.add_argument("--ips", "-i",
                        type=str,
                        nargs="*",
                        default=None,
                        help="Only get ipconfig file for specific ipgen template"
                        " types. If not specified, will generate ipconfigs for all"
                        " ipgen IPs within the top.")
    parser.add_argument("--xbars", "-x",
                        action=argparse.BooleanOptionalAction,
                        help="Create configuration Hjsons for the top level's xbars.")
    parser.add_argument("--verbose", "-v", action="store_true")
    args = parser.parse_args()

    log.basicConfig(format="%(filename)s:%(lineno)d: %(levelname)s: %(message)s",
                    level=log.DEBUG if args.verbose else log.ERROR)

    args.outdir.mkdir(parents=True, exist_ok=True)
    completecfg = load_cfg(args.completecfg)
    seedcfg = load_cfg(args.seedcfg) if args.seedcfg is not None else {}
    topdir = args.completecfg.parents[2].resolve()

    # can use either seed cfg or generated secrets cfg
    seed_value = (seedcfg.get("topgen_seed")
                  or seedcfg.get("seed", {}).get("topgen_seed", {}).get("value"))
    if seed_value is None:
        log.warning("no top level seed value found (may be required by some IPs)")

    extract_clocks(completecfg)

    ipgen_modules = [module for module in completecfg["module"]
                     if is_ipgen(module) and ipgen_is_selected(module, args.ips)]

    for module in ipgen_modules:
        log.info(f"generating ipconfig for {module['name']}")
        if seed_value is not None:
            SecurePrngFactory.create("topgen", seed_value)  # reset random seed every time

        params = get_params(completecfg, module, topdir)
        params |= {"topname": completecfg["name"], "uniquified_modules": {}}

        template = IpTemplate.from_template_path(
            IP_TEMPLATES_PATH / module["template_type"])

        module_name = params.get("module_instance_name", module["template_type"])
        inst_name = f"top_{completecfg['name']}_{module_name}"
        ip_config = IpConfig(template.params, inst_name, params)

        outfile = args.outdir / (ip_config.instance_name + ".ipconfig.hjson")
        ip_config.to_file(outfile, HEADER.format(args.completecfg.relative_to(REPO_TOP),
                                                 args.outdir.relative_to(REPO_TOP)))

    if args.xbars:
        for xbar in completecfg["xbar"]:
            if not ipgen_is_selected(xbar, args.ips):
                continue
            xbar_name = xbar["name"]
            log.info(f"generating xbar {xbar_name}")
            xbar_hjson_path = args.outdir / f"xbar_{xbar_name}.gen.hjson"
            xbar_hjson_path.write_text(HEADER.format(args.completecfg.relative_to(REPO_TOP),
                                                     args.outdir.relative_to(REPO_TOP))
                                       + hjson.dumps(xbar, for_json=True) + '\n')


if __name__ == "__main__":
    main()
