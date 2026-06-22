#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
r"""Top Module Generator
"""
import argparse
from dataclasses import dataclass
import logging as log
import os
import sys
from collections import OrderedDict, defaultdict
from copy import deepcopy
from pathlib import Path
from typing import Callable, Dict, List, NamedTuple, Optional

import hjson
import tlgen
from basegen.typing import ConfigT, ParamsT
from design.lib.LcStEnc import LcStEnc
from ipgen import (IpBlockRenderer, IpConfig, IpDescriptionOnlyRenderer,
                   IpTemplate, TemplateRenderError)
from ipgen.clkmgr_gen import get_clkmgr_params
from mako import exceptions
from mako.lookup import TemplateLookup
from mako.template import Template
from raclgen.lib import DEFAULT_RACL_CONFIG
from reggen import access, gen_rtl, gen_sec_cm_testplan, window
from reggen.countermeasure import CounterMeasure
from reggen.ip_block import IpBlock
from topgen import get_hjsonobj_xbars
from topgen import intermodule as im
from topgen import lib as lib
from topgen import merge_top, validate_top
from topgen.secure_prng import SecurePrngFactory
from topgen.lib import find_modules, load_cfg, write_file_secure
from topgen.merge import (
    amend_alert, amend_interrupt, amend_pinmux_io, amend_racl,
    amend_reset_request, amend_resets, amend_wkup, commit_alert_modules,
    commit_interrupt_modules, commit_outgoing_alert_modules,
    commit_outgoing_interrupt_modules, connect_clocks,
    create_alert_lpgs, elaborate_instance, extract_clocks,
    commit_alert_connections)
from topgen.typing import IpBlocksT
from topgen.validate import validate_seed_cfg
from topgen.params import (get_alert_handler_params, get_pinmux_params, get_pwrmgr_params,
                           get_rstmgr_params, get_flash_ctrl_params, get_otp_ctrl_params,
                           get_ac_range_check_params, get_racl_params, get_rv_plic_params,
                           get_basic_ipgen_params)

# Common header for generated files
warnhdr = """//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
"""
lichdr = """// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
"""
genhdr = lichdr + warnhdr

GENCMD = ("// util/topgen.py -t hw/{top_name}/data/{top_name}.hjson\n"
          "//                -o hw/{top_name}/")

SRCTREE_TOP = Path(__file__).parents[1].resolve()

TOPGEN_TEMPLATE_PATH = SRCTREE_TOP / "util" / "topgen" / "templates"
IP_RAW_PATH = SRCTREE_TOP / "hw" / "ip"
IP_TEMPLATES_PATH = SRCTREE_TOP / "hw" / "ip_templates"


@dataclass
class Seed:
    """Holds the seeds value along with its identifier"""
    seed_mode: str
    value: int


class UniquifiedModules(object):
    """This holds the uniquified name for all uniquified modules."""

    def __init__(self):
        self.modules: Dict[str, str] = {}

    def add_module(self, name: str, uniquified_name: str):
        if name == uniquified_name:
            return
        if (name in self.modules and uniquified_name != self.modules[name]):
            raise SystemExit(f"Multiple renames for module {name}")
        self.modules[name] = uniquified_name

    def get_uniq_name(self, name: str) -> Optional[str]:
        return self.modules.get(name)


uniquified_modules = UniquifiedModules()


class IpAttrs(NamedTuple):
    """Hold IP block, and path to hjson."""
    ip_block: IpBlock
    hjson_path: Path
    top_only: bool
    instances: List[object]


def _ipgen_render_prelude(template_name: str, topname: str,
                          params: ParamsT) -> (str, IpTemplate, IpConfig):
    module_name = (params.get("module_instance_name", template_name)
                   if params else template_name)
    top_name = f"top_{topname}"
    instance_name = f"{top_name}_{module_name}"
    ip_template = IpTemplate.from_template_path(IP_TEMPLATES_PATH /
                                                template_name)
    params.update({
        "topname": topname,
        "uniquified_modules": uniquified_modules.modules
    })

    try:
        ip_config = IpConfig(ip_template.params, instance_name, params)
    except ValueError as e:
        log.error(f"Unable to render IP template {template_name!r}: {str(e)}")
        sys.exit(1)
    return (module_name, ip_template, ip_config)


def ipgen_hjson_render(template_name: str, topname: str,
                       params: ParamsT) -> IpBlock:
    """ Render an IP hjson template for a specific toplevel using ipgen.

    Renders the hjson template as a string and returns an IpBlock
    constructed from it.

    Aborts the program execution in case of an error.
    """
    (_module_name, ip_template,
     ip_config) = _ipgen_render_prelude(template_name, topname, params)

    try:
        ip_desc = IpDescriptionOnlyRenderer(ip_template, ip_config).render()
    except TemplateRenderError as e:
        log.error(e.verbose_str())
        sys.exit(1)
    return IpBlock.from_text(
        ip_desc, [], f"ipgen description from {ip_template.template_path}")


def ipgen_render(template_name: str, topname: str, params: ParamsT,
                 out_path: Path) -> None:
    """ Render an IP template for a specific toplevel using ipgen.

    The generated IP block is placed in the "ip_autogen" directory of the
    toplevel.

    Aborts the program execution in case of an error.
    """
    (module_name, ip_template,
     ip_config) = _ipgen_render_prelude(template_name, topname, params)

    try:
        renderer = IpBlockRenderer(ip_template, ip_config)
        renderer.render(out_path / "ip_autogen" / module_name,
                        overwrite_output_dir=True, no_top=False)
    except TemplateRenderError as e:
        log.error(e.verbose_str())
        sys.exit(1)


def generate_top(top: ConfigT, name_to_block: IpBlocksT, tpl_filename: str,
                 **kwargs: Dict[str, object]) -> None:
    top_tpl = Template(filename=tpl_filename,
                       lookup=TemplateLookup([TOPGEN_TEMPLATE_PATH, "/"]))

    try:
        return top_tpl.render(top=top, name_to_block=name_to_block, **kwargs)
    except:  # noqa: E722
        log.error(exceptions.text_error_template().render())
        return ""


def configure_xbars(top: ConfigT) -> None:
    """Complete all xbar configs in the top config.

    Run validate and elaborate, and create the inter_signal_lists.
    """

    def create_inter_signal(name: str, act: str) -> Dict[str, str]:
        name_suffix = name.replace(".", "__")
        inter_signal: OrderedDict() = {
            "name": f"tl_{name_suffix}",
            "struct": "tl",
            "package": "tlul_pkg",
            "type": "req_rsp",
            "act": act,
        }
        return inter_signal

    def create_inter_signal_list(xar):
        isl = []
        for i, node in enumerate(xbar.hosts, 1):
            inter_signal = create_inter_signal(node.name, "rsp")
            isl.append(inter_signal)
        for i, node in enumerate(xbar.devices, 1):
            inter_signal = create_inter_signal(node.name, "req")
            isl.append(inter_signal)
        return isl

    for obj in top["xbar"]:
        objname = obj["name"]
        xbar = tlgen.validate(obj)
        if not tlgen.elaborate(xbar):
            log.error(f"Elaboration of xbar {objname} failed:\n" +
                      repr(vars(xbar)))
            raise SystemExit(sys.exc_info()[1])
        inter_signal_list = create_inter_signal_list(xbar)
        obj["inter_signal_list"] = inter_signal_list


def generate_ipgen(top: ConfigT, module: ConfigT, params: ParamsT,
                   out_path: Path) -> None:
    topname = top["name"]
    template_name = module["template_type"]
    module_name = module["type"]
    module_instance_name = params.get("module_instance_name")
    if module_instance_name and module_instance_name != module_name:
        raise ValueError(
            f"Unexpected module_instance_name: expected {module_name}, got "
            f"{module_instance_name}")
    uniq_name = uniquified_modules.get_uniq_name(template_name)
    if uniq_name and uniq_name != module_instance_name:
        raise ValueError(
            f"Unexpected uniquified name: expected {module_instance_name}, "
            f"got {uniq_name}")
    ipgen_render(module["template_type"], topname, params, out_path)


def generate_outgoing_alerts(top: ConfigT, out_path: Path) -> None:
    log.info("Generating outgoing alert definitions")

    def render_template(template_path: Path, rendered_path: Path,
                        **other_info):
        template_contents = generate_top(top, None, str(template_path),
                                         **other_info)

        rendered_path.parent.mkdir(exist_ok=True, parents=True)
        with rendered_path.open(mode="w", encoding="UTF-8") as fout:
            fout.write(template_contents)

    for alert_group, alerts in top['outgoing_alert'].items():
        # Outgoing alert definition
        # 'outgoing_alerts.hjson.tpl' -> 'data/autogen/{top_name}.sv'
        render_template(TOPGEN_TEMPLATE_PATH / 'outgoing_alerts.hjson.tpl',
                        out_path / 'data' / 'autogen' /
                        f'outgoing_alerts_{alert_group}.hjson',
                        alert_group=alert_group,
                        alerts=alerts)


def generate_outgoing_interrupts(top: ConfigT, out_path: Path) -> None:
    log.info("Generating outgoing interrupt definitions")

    def render_template(template_path: Path, rendered_path: Path,
                        **other_info):
        template_contents = generate_top(top, None, str(template_path),
                                         **other_info)

        rendered_path.parent.mkdir(exist_ok=True, parents=True)
        with rendered_path.open(mode="w", encoding="UTF-8") as fout:
            fout.write(template_contents)

    for interrupt_group, interrupts in top["outgoing_interrupt"].items():
        # Outgoing interrupt definition
        # "outgoing_interrupts.hjson.tpl" -> "data/autogen/{top_name}.sv"
        render_template(TOPGEN_TEMPLATE_PATH / "outgoing_interrupts.hjson.tpl",
                        out_path / "data" / "autogen" /
                        f"outgoing_interrupts_{interrupt_group}.hjson",
                        interrupt_group=interrupt_group,
                        interrupts=interrupts)


def generate_regfile_from_path(hjson_path: Path,
                               generated_rtl_path: Path) -> None:
    """Generate RTL register file from path and check countermeasure labels"""
    obj = IpBlock.from_path(str(hjson_path), [])

    # If this block has countermeasures, we grep for RTL annotations in
    # all .sv implementation files and check whether they match up
    # with what is defined inside the Hjson.
    sv_files = generated_rtl_path.glob("*.sv")
    rtl_names = CounterMeasure.search_rtl_files(sv_files)
    obj.check_cm_annotations(rtl_names, str(hjson_path))
    gen_rtl.gen_rtl(obj, str(generated_rtl_path))
    if gen_sec_cm_testplan.gen_sec_cm_testplan(obj, hjson_path.parent):
        sys.exit(1)


def create_mem(name: str, item: dict[str, object], addrsep: int, regwidth: int) -> window.Window:
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


def _amend_block_reset_connections(module: ConfigT,
                                   default_power_domain: str) -> None:
    for port, reset in module["reset_connections"].items():
        if isinstance(reset, str):
            if "domain" not in module:
                domain = default_power_domain
            else:
                if len(module["domain"]) > 1:
                    raise ValueError(
                        f"{module['name']} reset connection {reset} "
                        "has no assigned domain")
                domain = module["domain"][0]
            module["reset_connections"][port] = {
                'name': reset,
                'domain': domain,
            }


def amend_reset_connections(topcfg: ConfigT) -> None:
    """Complete the reset connections information for each module.

    Add an explicit domain entry for each reset connection.
    The reset_connections are dictionaries keyed by a port name and
    with a value that can be just a string or a dictionary with a name
    and a domain. When the value is just a string determine the domain
    as the module's domain, or the default domain from the topcfg.
    """
    default_power_domain = topcfg["power"]["default"]
    for module in topcfg["module"]:
        _amend_block_reset_connections(module, default_power_domain)
    for xbar in topcfg["xbar"]:
        _amend_block_reset_connections(xbar, default_power_domain)


def create_generic_ip_blocks(topcfg: ConfigT, alias_cfgs: Dict[str, ConfigT],
                             cfg_path: Path,
                             out_path: Path) -> Dict[str, IpAttrs]:
    """Create IpAttrs for each generic ip type.

    Most importantly, IpAttrs holds the IpBlock.

    Raise an exception if any module's "attr" flag is invalid.
    """

    def handle_instance(top_only: bool) -> None:
        if top_only:
            hjson_path = cfg_path / "ip" / ip_type / "data" / f"{ip_type}.hjson"
        else:
            hjson_path = IP_RAW_PATH / ip_type / "data" / f"{ip_type}.hjson"
        if ip_type in ip_attrs:
            ip_attrs[ip_type].instances.append(instance)
        else:
            ip_block = IpBlock.from_path(str(hjson_path), [])
            if ip_type in alias_cfgs:
                ip_block = ip_block.alias_from_raw(
                    False, alias_cfgs[ip_type], f"alias file for {ip_type}")
            ip_attrs[ip_type] = IpAttrs(ip_block=ip_block,
                                        hjson_path=hjson_path,
                                        top_only=top_only,
                                        instances=[instance])

    ip_attrs = {}
    invalid_attr_instances = []
    for instance in topcfg["module"]:
        ip_type = instance["type"]
        if "attr" not in instance:
            handle_instance(top_only=False)
        elif lib.is_top_reggen(instance):
            handle_instance(top_only=True)
        elif lib.is_ipgen(instance):
            continue
        else:
            invalid_attr_instances.append(instance)
    if invalid_attr_instances:
        log.error("The following instances have invalid attributes, "
                  "listed as (instance, attr):"
                  ", ".join("({}, {})".format(inst, inst["attr"])
                            for inst in invalid_attr_instances))
        raise SystemExit(sys.exc_info()[1])
    return ip_attrs


def create_ipgen_ip_block(topname: str, template_name: str, module_name: str,
                          params: ParamsT,
                          alias_cfgs: Dict[str, ConfigT]) -> IpBlock:
    ip_block = ipgen_hjson_render(template_name, topname, params)
    if module_name in alias_cfgs:
        ip_block = ip_block.alias_from_raw(False, alias_cfgs[module_name],
                                           f"alias file for {module_name}")
    return ip_block


def create_ipgen_blocks(topcfg: ConfigT, alias_cfgs: Dict[str, ConfigT],
                        cfg_path: Path, out_path: Path,
                        name_to_block: IpBlocksT) -> Dict[str, IpAttrs]:
    """Create IpAttrs for each ipgen ip type.

    Most importantly, IpAttrs holds the IpBlock. The order in which
    ipgens are processed is important since they have interdependencies.
    All generic Ip blocks should already be created, so the dependencies
    that matter are only amongst ipgens.

    Prior to the generation of each ip we run some of the merge_top
    functions that provide information to such ip, based on all ips
    that have already been generated. This means the merge_top functions
    need to filter out ip blocks that don't yet have an ip block.

    A non-exhaustive list of edges between blocks follows, with a -> b
    meaning a must precede b:
    - racl_ctrl -> all_others
    - flash_ctrl -> pinmux
    - otp_ctrl -> pinmux
    - pinmux -> pwrmgr
    - pwrmgr -> rstmgr
    - all_others -> alert_handler
    - all_others -> rv_plic

    This implies a circular dependency between alert_handler and rv_plic,
    but it is worked out in the last merge_top pass, since at that point
    the total number of alerts and interrupts is set correctly.
    """

    def insert_ip_attrs(module: ConfigT, params: ParamsT):
        template_name = module["template_type"]
        module_name = module["type"]
        log.info(f"Ipgen for {module_name} from template {template_name}")
        hjson_path = (out_path / "ip_autogen" / module_name / "data" /
                      f"{module_name}.hjson")
        ip_block = create_ipgen_ip_block(topname, template_name, module_name,
                                         params, alias_cfgs)
        name_to_block[module_name] = ip_block
        ip_attrs[module_name] = IpAttrs(
            hjson_path=hjson_path,
            ip_block=ip_block,
            top_only=False,
            instances=ipgen_instances[template_name])

    topname = topcfg["name"]
    ip_attrs = {}
    ipgen_instances = defaultdict(list)
    multi_instance_ipgens = []
    for inst in topcfg["module"]:
        if lib.is_ipgen(inst):
            template_type = inst["template_type"]
            if (template_type not in ["rv_plic", "alert_handler"] and
               template_type in ipgen_instances):
                multi_instance_ipgens.append(inst)
            else:
                ipgen_instances[inst["template_type"]].append(inst)
    if multi_instance_ipgens:
        raise SystemExit("There are ipgen modules with multiple instances: "
                         f"{multi_instance_ipgens}")

    if "gpio" in ipgen_instances:
        instance = ipgen_instances["gpio"][0]
        insert_ip_attrs(instance, get_basic_ipgen_params(topcfg, "gpio"))
    if "pwm" in ipgen_instances:
        instance = ipgen_instances["pwm"][0]
        insert_ip_attrs(instance, get_basic_ipgen_params(topcfg, "pwm"))
    if "racl_config" in topcfg:
        amend_racl(topcfg, name_to_block, allow_missing_blocks=True)
        assert "racl_ctrl" in ipgen_instances
        instance = ipgen_instances["racl_ctrl"][0]
        insert_ip_attrs(instance, get_racl_params(topcfg))
    if "clkmgr" in ipgen_instances:
        instance = ipgen_instances["clkmgr"][0]
        insert_ip_attrs(instance, get_clkmgr_params(topcfg))
    if "flash_ctrl" in ipgen_instances:
        instance = ipgen_instances["flash_ctrl"][0]
        insert_ip_attrs(instance, get_flash_ctrl_params(topcfg))
    if "otp_ctrl" in ipgen_instances:
        instance = ipgen_instances["otp_ctrl"][0]
        insert_ip_attrs(instance, get_otp_ctrl_params(topcfg, cfg_path))
    if "ac_range_check" in ipgen_instances:
        instance = ipgen_instances["ac_range_check"][0]
        insert_ip_attrs(instance, get_ac_range_check_params(topcfg))

    if "rv_core_ibex" in ipgen_instances:
        instance = ipgen_instances["rv_core_ibex"][0]
        insert_ip_attrs(instance, get_basic_ipgen_params(topcfg, "rv_core_ibex"))

    # Pinmux depends on flash_ctrl and otp_ctrl
    if "pinmux" in ipgen_instances:
        amend_pinmux_io(topcfg, name_to_block)
        instance = ipgen_instances["pinmux"][0]
        insert_ip_attrs(instance, get_pinmux_params(topcfg))

    # Pwrmgr depends on pinmux
    # Add pwrmgr after necessary amends
    amend_wkup(topcfg, name_to_block, allow_missing_blocks=True)
    amend_reset_request(topcfg, name_to_block, allow_missing_blocks=True)
    if "pwrmgr" in ipgen_instances:
        insert_ip_attrs(ipgen_instances["pwrmgr"][0],
                        get_pwrmgr_params(topcfg))
    # Add rstmgr after necessary amends
    amend_resets(topcfg, name_to_block, allow_missing_blocks=True)
    if "rstmgr" in ipgen_instances:
        insert_ip_attrs(ipgen_instances["rstmgr"][0],
                        get_rstmgr_params(topcfg))
    # Add alert_handler(s)
    amend_alert(topcfg, name_to_block, allow_missing_blocks=True)
    if "alert_handler" in ipgen_instances:
        for alert_handler_inst in ipgen_instances["alert_handler"]:
            name = alert_handler_inst["name"]
            alert_handler_params = get_alert_handler_params(topcfg, name)
            insert_ip_attrs(alert_handler_inst, alert_handler_params)
    # Add rv_plic
    amend_interrupt(topcfg, name_to_block, allow_missing_blocks=True)
    for inst in ipgen_instances.get("rv_plic", []):
        insert_ip_attrs(inst, get_rv_plic_params(topcfg, inst["name"]))

    return ip_attrs


def _process_top(
        topcfg: ConfigT, args: argparse.Namespace, cfg_path: Path,
        out_path: Path,
        alias_cfgs: Dict[str,
                         ConfigT]) -> (ConfigT, IpBlocksT, Dict[str, Path]):
    """Generate the full top config file.

    This creates ip_blocks for all ips used by this top config and uses
    them to further populate the top config. It can raise exceptions for
    errors found in the process.
    """
    # Prepare the topcfg.
    extract_clocks(topcfg)
    ip_attrs = create_generic_ip_blocks(topcfg, alias_cfgs, cfg_path, out_path)
    name_to_block = {name: attrs.ip_block for name, attrs in ip_attrs.items()}
    ipgen_attrs = create_ipgen_blocks(topcfg, alias_cfgs, cfg_path, out_path,
                                      name_to_block)
    ip_attrs.update(ipgen_attrs)

    # Connect idle signals to clkmgr. This could be done right after clkmgr
    # generation if all transactional units are generic or are generated
    # prior to clkmgr.
    for attrs in ip_attrs.values():
        for inst in attrs.instances:
            inst_name = inst["name"]
            log.info(f"elaborating {inst_name}")
            elaborate_instance(inst, attrs.ip_block)
    connect_clocks(topcfg, name_to_block)

    # Read the crossbars under the top directory
    hjson_dir = Path(args.topcfg).parent
    xbar_objs = get_hjsonobj_xbars(hjson_dir)

    log.info("Detected crossbars: " + ", ".join(k for k in xbar_objs.keys()))

    topcfg, error = validate_top(topcfg, name_to_block, xbar_objs)
    if error != 0:
        raise SystemExit("Error occured while validating top.hjson")

    completecfg = merge_top(topcfg, name_to_block, xbar_objs)
    name_to_hjson: Dict[str,
                        Path] = {k: v.hjson_path
                                 for k, v in ip_attrs.items()}
    # rv_plic is generated after alert_handler so the alert_handler ip_block
    # needs to be updated because rv_plic alerts were not visible when the
    # alert_handler ip_block was created.
    alert_handlers = find_modules(topcfg["module"], "alert_handler", True)
    for alert_handler in alert_handlers:
        template_name = alert_handler["template_type"]
        module_name = alert_handler["type"]
        params = get_alert_handler_params(topcfg, module_name)
        name_to_block[module_name] = create_ipgen_ip_block(
            topcfg["name"], template_name, module_name, params, alias_cfgs)
    return completecfg, name_to_block, name_to_hjson


def complete_topcfg(topcfg: ConfigT, name_to_block: IpBlocksT) -> None:
    commit_alert_modules(topcfg, name_to_block)
    commit_alert_connections(topcfg, name_to_block)
    commit_interrupt_modules(topcfg, name_to_block)
    commit_outgoing_alert_modules(topcfg, name_to_block)
    commit_outgoing_interrupt_modules(topcfg, name_to_block)


def generate_full_ipgens(args: argparse.Namespace, topcfg: ConfigT,
                         name_to_block: Dict[str, ConfigT],
                         alias_cfgs: Dict[str, ConfigT], cfg_path: Path,
                         out_path: Path) -> None:

    # TODO, there are no interdependencies between ips so do them in any
    # order, which means could just iterate over all in the topcfg.

    def generate_modules(template_type: str,
                         single_instance: bool,
                         get_params: Callable[[Dict, Dict, Path], None] = None) -> None:
        modules = ipgens_by_template_type[template_type]
        if len(modules) > 1 and single_instance:
            raise SystemExit(f"Cannot have more than one {template_type} per top")
        for module in modules:
            log.info(f'Generating {module["type"]} with ipgen from template {template_type}')
            if get_params:
                args = (topcfg,) if single_instance else (topcfg, module["name"])
                params = get_params(*args)
            else:
                params = get_basic_ipgen_params(topcfg, template_type)
            generate_ipgen(topcfg, module, params, out_path)

    ipgens_by_template_type = defaultdict(list)
    for m in topcfg["module"]:
        if m.get("attr") == "ipgen":
            ipgens_by_template_type[m["template_type"]].append(m)

    generate_modules("clkmgr", single_instance=True, get_params=get_clkmgr_params)
    generate_modules("flash_ctrl", single_instance=True, get_params=get_flash_ctrl_params)
    if not args.no_plic and \
       not args.alert_handler_only:
        generate_modules("rv_plic", single_instance=False, get_params=get_rv_plic_params)
    if args.plic_only:
        sys.exit()

    # Generate Alert Handler if there is an instance
    generate_modules("alert_handler",
                     single_instance=False,
                     get_params=get_alert_handler_params)
    if args.alert_handler_only:
        sys.exit()

    # Generate outgoing alerts
    generate_outgoing_alerts(topcfg, out_path)

    # Generate outgoing interrupts
    generate_outgoing_interrupts(topcfg, out_path)

    generate_modules("otp_ctrl", single_instance=True,
                     get_params=lambda topcfg: get_otp_ctrl_params(topcfg, out_path))

    # Generate Pinmux
    generate_modules("pinmux", single_instance=True, get_params=get_pinmux_params)

    # Generate Pwrmgr if there is an instance
    generate_modules("pwrmgr", single_instance=True, get_params=get_pwrmgr_params)

    # Generate rstmgr if there is an instance
    generate_modules("rstmgr", single_instance=True, get_params=get_rstmgr_params)

    # Generate gpio if there is an instance
    generate_modules("gpio", single_instance=True)

    # Generate rv_core_ibex if there is an instance
    generate_modules("rv_core_ibex", single_instance=True)
    # Generate pwm if there is an instance
    generate_modules("pwm", single_instance=True)

    # Generate ac_range_check
    generate_modules("ac_range_check",
                     single_instance=True,
                     get_params=get_ac_range_check_params)

    # Generate RACL collateral
    if "racl_config" in topcfg:
        generate_modules("racl_ctrl", single_instance=True, get_params=get_racl_params)


def _check_countermeasures(completecfg: ConfigT, name_to_block: IpBlocksT,
                           name_to_hjson: Dict[str, Path]) -> bool:
    success = True
    for name, hjson_path in name_to_hjson.items():
        log.debug("name %s, hjson %s", name, hjson_path)
        sv_files = (hjson_path.parents[1] / 'rtl').glob('*.sv')
        rtl_names = CounterMeasure.search_rtl_files(sv_files)
        log.debug("Checking countermeasures for %s.", name)
        success &= name_to_block[name].check_cm_annotations(
            rtl_names, hjson_path.name)
        success &= name_to_block[name].check_regwens()
    if success:
        log.info("All Hjson declared countermeasures are implemented in RTL.")
    else:
        log.error("Countermeasure checks failed.")
    return success


def dump_completecfg(cfg: ConfigT, out_path: Path) -> None:
    topname = cfg["name"]
    top_name = f"top_{topname}"
    cfg_dir = out_path / "data/autogen"
    cfg_dir.mkdir(parents=True, exist_ok=True)
    genhjson_path = cfg_dir / f"{top_name}.gen.hjson"
    seed_mode = cfg['seed']['topgen_seed'].seed_mode
    secretgenhjson_path = cfg_dir / f"{top_name}.secrets.{seed_mode}.gen.hjson"

    # Sanitize the top config and create separate files for secrets
    dump_cfg = deepcopy(cfg)

    # Seed goes into the secrets file
    secret_cfg = {}
    secret_cfg["seed"] = dump_cfg.pop("seed")
    secret_cfg["module"] = []

    # Filter params list for secret params and move that to the secrets file
    for module in dump_cfg["module"]:
        secret_params = [p for p in module["param_list"] if p.get("randtype")]
        module["param_list"][:] = [p for p in module["param_list"] if not p.get("randtype")]

        if secret_params:
            # Pass a minimal set of information of a module such that tools that
            # consume the .secret.gen.hjson have all necessary information
            module_with_secret_params = {
                "name": module["name"],
                "type": module["type"],
                "base_addrs": module["base_addrs"],
                "memory": module["memory"],
                "param_list": secret_params
            }
            if module.get("template_type"):
                module_with_secret_params["template_type"] = module["template_type"]
            # OTP map contains secret parameters, so we need to pass it to the
            # secrets file.
            if module.get("otp_mmap"):
                module_with_secret_params["otp_mmap"] = module.pop("otp_mmap")
            secret_cfg["module"].append(module_with_secret_params)

    genhjson_path.write_text(genhdr + GENCMD.format(top_name=top_name) + "\n" +
                             hjson.dumps(dump_cfg, for_json=True, default=vars) +
                             '\n')
    # Write secrets file with secure permissions
    secrets_content = (genhdr + GENCMD.format(top_name=top_name) + "\n" +
                       hjson.dumps(secret_cfg, for_json=True, default=vars) + '\n')
    write_file_secure(secretgenhjson_path, secrets_content)


def main():
    parser = argparse.ArgumentParser(prog="topgen")
    parser.add_argument("--topcfg",
                        "-t",
                        required=True,
                        help="`top_{name}.hjson` file.")
    parser.add_argument("--seedcfg",
                        "-s",
                        required=True,
                        help="top_{name} seed configuration file.")
    parser.add_argument(
        "--outdir",
        "-o",
        help="""Target TOP directory.
             Module is created under rtl/. (default: dir(topcfg)/..)
             """)  # yapf: disable
    parser.add_argument("--hjson-path",
                        help="""
          If defined, topgen uses supplied path to search for ip hjson.
          This applies only to ip's with the `reggen_only` attribute.
          If an hjson is located both in the conventional path and the alternate
          path, the alternate path has priority.
        """)
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose")
    parser.add_argument(
        '--version-stamp',
        type=Path,
        default=None,
        help=
        'If version stamping, the location of workspace version stamp file.')

    # Generator options: 'no' series. Cannot combine with 'only' series.
    parser.add_argument(
        "--no-plic",
        action="store_true",
        help="If defined, topgen doesn't generate the interrupt controller RTLs."
    )
    # Generator options: 'only' series. cannot combined with 'no' series
    parser.add_argument(
        "--plic-only",
        action="store_true",
        help="If defined, the tool generates RV_PLIC RTL and Hjson only")
    parser.add_argument(
        "--alert-handler-only",
        action="store_true",
        help="If defined, the tool generates alert handler hjson only")
    parser.add_argument("--alias-files",
                        nargs="+",
                        type=Path,
                        default=None,
                        help="""
          If defined, topgen uses supplied alias hjson file(s) to override the
          generic register definitions when building the RAL model. This
          argument is only relevant in conjunction with the `--top_ral` switch.
        """)

    args = parser.parse_args()

    # check combinations
    if args.no_plic and (args.plic_only or args.alert_handler_only):
        log.error(
            "'no' series options cannot be used with 'only' series options")
        raise SystemExit(sys.exc_info()[1])

    # Don't print warnings when querying the list of blocks.
    log_level = (log.DEBUG if args.verbose else None)

    log.basicConfig(format="%(filename)s:%(lineno)d: %(levelname)s: %(message)s",
                    level=log_level)

    if not args.outdir:
        outdir = Path(args.topcfg).parents[1]
        log.info("TOP directory not given. Using %s", (outdir))
    elif not Path(args.outdir).is_dir():
        log.error("'--outdir' should point to writable directory")
        raise SystemExit(sys.exc_info()[1])
    else:
        outdir = Path(args.outdir)

    if args.hjson_path is not None:
        log.info(f"Alternate hjson path is {args.hjson_path}")

    out_path = Path(outdir)
    cfg_path = Path(args.topcfg).parents[1]

    topcfg = load_cfg(args.topcfg)

    # Load the seed config from the separate configuration file
    seed_cfg = load_cfg(args.seedcfg)
    seed_error = validate_seed_cfg(topcfg, seed_cfg)
    if seed_error:
        sys.exit(1)

    seed_mode = seed_cfg.pop("name")
    topcfg["seed"] = {}
    for seed_name, seed_value in seed_cfg.items():
        topcfg["seed"][seed_name] = Seed(seed_mode, seed_value)

    # Add domain information to each module's reset_connections
    amend_reset_connections(topcfg)

    # Read external alert mappings for all available alert handlers and inject
    # them to the alert handler's module definition.
    # TODO: make this part of amend_alert and amend_interrupt
    if 'incoming_alert' not in topcfg:
        topcfg['incoming_alert'] = {}
    if 'incoming_interrupt' not in topcfg:
        topcfg['incoming_interrupt'] = OrderedDict()

    for m in topcfg['module']:
        if m.get('template_type') == 'alert_handler':
            for alert_mappings_path in m.get('incoming_alert', []):
                mapping = load_cfg(
                    Path(args.topcfg).parent / alert_mappings_path)
                for alert_group, alerts in mapping.items():
                    topcfg['incoming_alert'][alert_group] = alerts
        elif m.get('template_type') == 'rv_plic':
            for irq_mappings_path in m.get('incoming_interrupt', []):
                irq_mapping = load_cfg(
                    Path(args.topcfg).parent / irq_mappings_path)
                for irq_group, irqs in irq_mapping.items():
                    topcfg['incoming_interrupt'][irq_group] = irqs

    # The generation of ipgen modules needs to be carefully orchestrated to
    # avoid performing multiple passes when creating the complete top
    # configuration. Please refer to the description in util/topgen/README.md.
    #
    # This performs multiple passes until the complete top configuration
    # doesn't change.
    #
    # This fix is related to #2083
    maximum_passes = 3

    # topgen generates IP blocks and associated Hjson configuration in multiple
    # steps. In each step, the ipgen peripheral's IP Hjson configuration is
    # regenerated from the updated top configuration, which can induce further
    # changes to the toplevel configuration.
    #
    # To generate the chip-level RAL we need to run the full generation step,
    # but ultimately only care about the toplevel configuration (a single Hjson
    # file). Since we don't have a better way at the moment, we dump all output
    # into a temporary directory, and delete it after the fact, retaining only
    # the toplevel configuration.
    out_path_gen = out_path

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

    topname = topcfg["name"]
    cfg_copy = deepcopy(topcfg)
    cfg_last_dump = None
    for pass_idx in range(maximum_passes):
        log.info("Generation pass {}".format(pass_idx + 1))
        # Use the same seed for each pass to have stable random constants.
        SecurePrngFactory.create("topgen", topcfg["seed"]["topgen_seed"].value)
        # Insert the config file path of the HJSON to allow parsing files
        # relative the config directory
        cfg_copy["cfg_path"] = Path(args.topcfg).parent
        completecfg, name_to_block, name_to_hjson = _process_top(
            cfg_copy, args, cfg_path, out_path_gen, alias_cfgs)
        # Delete config path before dumping, not needed
        del completecfg["cfg_path"]
        cfg_dump = hjson.dumps(completecfg, for_json=True, default=vars)
        if pass_idx > 0 and cfg_dump == cfg_last_dump:
            log.info("process_top converged after {} passes".format(pass_idx + 1))
            break
        else:
            cfg_last_dump = cfg_dump
        cfg_copy = completecfg
    else:
        log.error("Too many process_top passes without convergence")
        raise SystemExit(sys.exc_info()[1])

    complete_topcfg(completecfg, name_to_block)
    create_alert_lpgs(completecfg, name_to_block)

    configure_xbars(completecfg)

    # All IPs are generated. Connect phase now
    # Find {memory, module} <-> {xbar} connections first.
    im.autoconnect(completecfg, name_to_block)

    # Generic Inter-module connection
    im.elab_intermodule(completecfg)

    # Dump the complete top config
    dump_completecfg(completecfg, out_path)

    topname = topcfg["name"]
    top_name = f"top_{topname}"

    # Re-set the seed because generate_full_ipgens uses the same RNG again from the beginning
    SecurePrngFactory.create("topgen", topcfg["seed"]["topgen_seed"].value)

    def render_template(template_path: str, rendered_path: Path,
                        secure: bool = False, **other_info):
        """Render template to file, optionally with secure permissions for sensitive files"""
        template_contents = generate_top(completecfg, name_to_block,
                                         str(template_path), **other_info)

        if secure:
            # Use the write_file_secure for writting file with restricted file permissions
            write_file_secure(rendered_path, template_contents)
        else:
            rendered_path.parent.mkdir(exist_ok=True, parents=True)
            rendered_path.write_text(template_contents, encoding="UTF-8")

    # Header for SV files
    gencmd_sv = warnhdr + "//\n" + GENCMD.format(top_name=top_name) + "\n"

    # Top and chiplevel templates are top-specific
    top_template_path = SRCTREE_TOP / "hw" / top_name / "templates"

    # SystemVerilog Top:
    # "toplevel.sv.tpl" -> "rtl/autogen/{top_name}.sv"
    render_template(top_template_path / "toplevel.sv.tpl",
                    out_path / "rtl" / "autogen" / f"{top_name}.sv",
                    gencmd=gencmd_sv)

    # Multiple chip-levels (ASIC, FPGA, Verilator, etc)
    for target in completecfg["targets"]:
        target_name = target["name"]
        render_template(top_template_path / "chiplevel.sv.tpl",
                        out_path /
                        f"rtl/autogen/chip_{topname}_{target_name}.sv",
                        gencmd=gencmd_sv,
                        target=target)

    # compile-time random netlist constants
    gencmd_rnd_cnst_sv = gencmd_sv + f"""//
// File is generated based on the following seed configuration:
//   {os.path.relpath(args.seedcfg, SRCTREE_TOP)}
"""
    topgen_seed = completecfg["seed"]["topgen_seed"]
    seed_mode = topgen_seed.seed_mode
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

    for m in completecfg["module"]:
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

    render_template(TOPGEN_TEMPLATE_PATH / "toplevel_rnd_cnst_pkg.sv.tpl",
                    out_path / rnd_cnst_path / rnd_cnst_sv_file,
                    secure=True, gencmd=gencmd_rnd_cnst_sv)

    # Create verible waiver file for the random constant package for long lines.
    rnd_cnst_vbl_file_path = out_path / rnd_cnst_path / f"{rnd_cnst_file}.vbl"
    with rnd_cnst_vbl_file_path.open(mode="w", encoding="UTF-8") as fout:
        fout.write((lichdr + gencmd_rnd_cnst_sv).replace("//", "#") + f"""
# These lines are too long due to templating
waive --rule=line-length --location="{rnd_cnst_sv_file}"
""")
    render_template(TOPGEN_TEMPLATE_PATH / "core_file.core.tpl",
                    out_path / rnd_cnst_path / f"top_{topname}_{seed_mode}_rnd_cnst_pkg.core",
                    package=f"lowrisc:{topname}_constants:{seed_mode}_rnd_cnst_pkg:0.1",
                    description="Random netlist constant package",
                    virtual_package="lowrisc:virtual_constants:rnd_cnst_pkg",
                    dependencies=rnd_cnst_deps,
                    files=[rnd_cnst_sv_file],
                    files_veriblelint_waiver=rnd_cnst_vbl_file)

    racl_config = completecfg.get('racl', DEFAULT_RACL_CONFIG)
    render_template(TOPGEN_TEMPLATE_PATH / 'top_racl_pkg.sv.tpl',
                    out_path / 'rtl' / 'autogen' / 'top_racl_pkg.sv',
                    gencmd=gencmd_sv,
                    topcfg=completecfg,
                    racl_config=racl_config)
    render_template(TOPGEN_TEMPLATE_PATH / 'toplevel_racl_pkg.sv.tpl',
                    out_path / 'rtl' / 'autogen' /
                    f'top_{topname}_racl_pkg.sv',
                    gencmd=gencmd_sv,
                    topcfg=completecfg,
                    racl_config=racl_config)

    if lib.find_module(topcfg["module"], "lc_ctrl"):
        lc_state_def_file = load_cfg(IP_RAW_PATH / "lc_ctrl" / "data" / "lc_ctrl_state.hjson")
        lc_seed = topcfg["seed"]["lc_ctrl_seed"]
        lc_st_enc = LcStEnc(lc_state_def_file, lc_seed.value)
        lc_st_enc_path = f"rtl/autogen/{lc_seed.seed_mode}"
        lc_st_enc_file = "lc_ctrl_token_pkg.sv"
        render_template(IP_RAW_PATH / "lc_ctrl" / "rtl" / "lc_ctrl_state_pkg.sv.tpl",
                        IP_RAW_PATH / "lc_ctrl" / "rtl" / "lc_ctrl_state_pkg.sv",
                        lc_st_enc=lc_st_enc)
        render_template(IP_RAW_PATH / "lc_ctrl" / "rtl" / "lc_ctrl_token_pkg.sv.tpl",
                        out_path / lc_st_enc_path / lc_st_enc_file,
                        secure=True, lc_st_enc=lc_st_enc)
        render_template(TOPGEN_TEMPLATE_PATH / "core_file.core.tpl",
                        out_path / lc_st_enc_path /
                        f"top_{topname}_{lc_seed.seed_mode}_lc_ctrl_token_pkg.core",
                        package=(
                            f"lowrisc:{topname}_constants:"
                            f"{lc_seed.seed_mode}_lc_ctrl_token_pkg:0.1"
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
    if completecfg["alert"]:
        tb_files += ["tb__alert_handler_connect.sv"]

    for fname in tb_files:
        tpl_fname = "%s.tpl" % (fname)
        xbar_chip_data_path = TOPGEN_TEMPLATE_PATH / tpl_fname
        template_contents = generate_top(completecfg,
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
    template_contents = generate_top(completecfg, name_to_block,
                                     str(alert_handler_chip_data_path))

    rendered_dir = out_path / "dv/env/autogen"
    rendered_dir.mkdir(parents=True, exist_ok=True)
    rendered_path = rendered_dir / "chip_env_pkg__params.sv"

    with rendered_path.open(mode="w", encoding="UTF-8") as fout:
        fout.write(template_contents)


if __name__ == "__main__":
    main()
