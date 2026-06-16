#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Generate top RAL model for DV from a complete top configuration. From templates, generate
<outdir>/chip_ral_pkg.sv, a top level's chip abstraction layer used for UVM.
"""
import argparse
import logging as log
from copy import deepcopy
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from basegen.typing import ConfigT
from topgen.typing import IpBlocksT
from topgen.lib import load_cfg, get_ip_hjson_path
from reggen import reg_block, params, window, access
from topgen.top import Top
from topgen.gen_dv import gen_dv
from reggen.ip_block import IpBlock


REPO_TOP = Path(__file__).parents[1].resolve()


def create_mem(name: str, item: dict[str, object], addrsep: int,
               regwidth: int) -> window.Window:
    byte_write = item.get("byte_write", "false").lower() == "true"
    data_intg_passthru = item.get("data_intg_passthru", "false").lower() == "true"

    item_size = item.get("size")
    if item_size is None:
        raise ValueError("Item describing memory window with no size")

    size_in_bytes = int(item_size, 0)
    num_regs = size_in_bytes // addrsep
    swaccess = access.SWAccess("top-level memory", item.get("swaccess", "rw"))

    return window.Window(name=name,
                         desc="(generated from top-level)",
                         unusual=False,
                         byte_write=byte_write,
                         data_intg_passthru=data_intg_passthru,
                         validbits=regwidth,
                         items=num_regs,
                         size_in_bytes=size_in_bytes,
                         offset=int(item.get("base_addr", "0"), 0),
                         swaccess=swaccess)


def generate_top_ral(topname: str, top: ConfigT, name_to_block: IpBlocksT,
                     dv_base_names: List[str], out_path: str) -> None:

    # construct top ral block
    regwidth = int(top["datawidth"])
    assert regwidth % 8 == 0
    addrsep = regwidth // 8

    # Generate a map from instance name to the block that it instantiates,
    # together with a map of interface addresses.
    inst_to_block: Dict[str, str] = {}
    if_addrs: Dict[Tuple[str, Optional[str]], int] = {}
    attrs: Dict[str, str] = {}

    for module in top["module"]:
        inst_name = module["name"]
        block_name = module["type"]
        block = name_to_block[block_name]
        if "attr" in module:
            attrs[inst_name] = module["attr"]

        inst_to_block[inst_name] = block_name
        for if_name in block.reg_blocks.keys():
            if_addr = {
                asid: int(addr, 0)
                for (asid, addr) in module["base_addrs"][if_name or "null"].items()
            }
            if_addrs[(inst_name, if_name)] = if_addr

    # Top-level may override the mem setting. Store the new type to
    # name_to_block. If no other instance uses the original type, delete it
    original_types = set()
    for module in top["module"]:
        if "memory" in module.keys() and len(module["memory"]) > 0:
            mod_name = module["name"]
            newtype = "{}_{}".format(module["type"], mod_name)
            assert newtype not in name_to_block

            # Take a copy of the block-level description of the thing that is
            # being instantiated as mod_name (so that we can configure it).
            block = deepcopy(name_to_block[module["type"]])

            # Update name_to_block and inst_to_block so that they point at the
            # new, more specific, information about the block.
            name_to_block[newtype] = block
            inst_to_block[mod_name] = newtype

            original_types.add(module["type"])

            # The instantiation might have requested a specific configuration
            # for some of the memories of the block. Apply that here.
            for mem_name, item in module["memory"].items():
                block_mem = block.memories.get(mem_name)
                if block_mem is None:
                    raise ValueError(f"The definition of {block.name} "
                                     f"(instantiated as {mod_name}) doesn't "
                                     f"declare a memory called {mem_name}.")

                # We only support memories with at most a single window (if
                # there are several, we don't know which one to customise)
                if len(block_mem.windows) > 1:
                    raise ValueError(f"The block {block.name} declares "
                                     f"multiple windows for its {mem_name} "
                                     f"memory, so topgen can't configure that "
                                     "memory.")

                # This is the new window to use
                win = create_mem(mem_name, item, addrsep, regwidth)

                # If the block doesn't define a window for this memory, we can
                # just make one. If it *does* define a window we can overwrite
                # it, but want to make sure we won't mess things up.
                if not block_mem.windows:
                    block_mem.windows = [win]
                else:
                    blk_win = block_mem.windows[0]

                    # Check we end up with the same number of "items" in the
                    # window (the window size divided by addrsep)
                    if win.items != blk_win.items:
                        raise ValueError(f"The {mod_name} instance of "
                                         f"{block.name} doesn't match number "
                                         f"of items for {mem_name}. Instance: "
                                         f"{win.items}; blk: {blk_win.items}")

                    # Check the byte_write setting matches
                    if win.byte_write != blk_win.byte_write:
                        raise ValueError(f"The {mod_name} instance of "
                                         f"{block.name} requests the memory "
                                         f"{mem_name} with byte_write="
                                         f"{win.byte_write}, but the block "
                                         f"declares it {blk_win.byte_write}.")

                    # Check the data_intg_passthru setting matches
                    if win.data_intg_passthru != blk_win.data_intg_passthru:
                        raise ValueError(f"The {mod_name} instance of "
                                         f"{block.name} requests the memory "
                                         f"{mem_name} with data_intg_passthru="
                                         f"{win.data_intg_passthru}, but the "
                                         f"block declares it as "
                                         f"{blk_win.data_intg_passthru}.")

                    # If we get here, the two definitions matched. Use the new
                    # one.
                    block_mem.windows[0] = win

                # At the moment the RAL template does not know about memories
                # but it knows about windows in memory blocks. Therefoe we
                # create an empty register block for RAL.
                if_name = mem_name
                block.reg_blocks[if_name] = reg_block.RegBlock(regwidth, params.ReggenParams(),
                                                               windows = block_mem.windows)

                if_addr = {
                    asid: int(addr, 0)
                    for (asid, addr) in module["base_addrs"][if_name].items()
                }
                if_addrs[(mod_name, if_name)] = if_addr

    for t in original_types:
        if t not in inst_to_block.values():
            del name_to_block[t]

    addr_spaces = {addr_space["name"] for addr_space in top["addr_spaces"]}
    chip = Top(topname, regwidth, addr_spaces, name_to_block, inst_to_block,
               if_addrs, [], attrs)

    # generate the top ral model with template
    return gen_dv(chip, dv_base_names, str(out_path))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--completecfg", "-t",
                        type=Path,
                        required=True,
                        help="Complete top configuration Hjson file.")
    parser.add_argument("--outdir", "-o",
                        type=Path,
                        help="Path to output directory. Defaults to $(dirname completecfg)/../..")
    parser.add_argument("--alias-files", "-a",
                        nargs="*",
                        type=Path,
                        help="Alias hjson file(s) for overriding generic register"
                        " definitions.")
    parser.add_argument("--dv-base-names", "-d",
                        nargs="+",
                        help="Names or prefix for the DV register classes from which"
                        " the register models are derived.")
    parser.add_argument("--verbose", "-v", action="store_true")
    args = parser.parse_args()

    outdir = args.outdir or args.completecfg.parents[2].resolve()
    outdir.mkdir(parents=True, exist_ok=True)
    if args.verbose:
        log.basicConfig(format="%(filename)s:%(lineno)d: %(levelname)s: %(message)s",
                        level=log.DEBUG)
    else:
        log.basicConfig(format="%(filename)s:%(lineno)d: %(levelname)s: %(message)s")

    # gather the given alias reg blocks, mapped by IP type
    alias_cfgs: Dict[str, ConfigT] = {}
    if args.alias_files:
        for alias in args.alias_files:
            alias_cfg = load_cfg(alias)
            if 'alias_target' not in alias_cfg:
                raise ValueError('Missing alias_target key '
                                 'in alias file {}.'.format(alias))
            alias_target = alias_cfg['alias_target'].lower()
            if alias_target in alias_cfgs:
                raise ValueError(f"Multiple alias targets for {alias_target}")
            alias_cfgs[alias_target] = alias_cfg

    # get information from complete topcfg
    completecfg = load_cfg(args.completecfg)
    topname = completecfg["name"]
    name_to_block = {}
    for module in completecfg["module"]:
        block_type = module["type"]

        ip_block = IpBlock.from_path(
            get_ip_hjson_path(block_type, completecfg, REPO_TOP), [])
        if block_type in alias_cfgs:
            ip_block = ip_block.alias_from_raw(
                False, alias_cfgs[block_type], f"alias file for {block_type}")

        name_to_block[block_type] = ip_block

    generate_top_ral(topname, completecfg, name_to_block, args.dv_base_names,
                     outdir)


if __name__ == "__main__":
    main()
