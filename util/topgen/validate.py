# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import logging as log
import re
from enum import Enum
from typing import Dict, List, Union

from basegen.typing import ConfigT
from reggen.ip_block import IpBlock
from topgen.resets import Resets, UnmanagedResets
from topgen.typing import IpBlocksT
from topgen.lib import find_module, find_modules
from basegen.validate import create_validator, all_validation_errors


TOPCFG_VALIDATOR = create_validator("urn:topgen:topcfg")
SEEDCFG_VALIDATOR = create_validator("urn:topgen:seedcfg")


# Supported PAD types.
# Needs to coincide with enum definition in prim_pad_wrapper_pkg.sv
class PadType(Enum):
    INPUT_STD = 'InputStd'
    BIDIR_STD = 'BidirStd'
    BIDIR_TOL = 'BidirTol'
    BIDIR_OD = 'BidirOd'
    ANALOG_IN0 = 'AnalogIn0'
    ANALOG_IN1 = 'AnalogIn1'
    DUAL_BIDIR_TOL = 'DualBidirTol'


def is_valid_pad_type(obj):
    try:
        PadType(obj)
    except ValueError:
        return False
    return True


class TargetType(Enum):
    MODULE = "module"
    XBAR = "xbar"


class Target:
    """Target class informs the checkers if we are validating a module or xbar
    """

    def __init__(self, target_type):
        # The type of this target
        self.target_type = target_type
        # The key to search against
        if target_type == TargetType.MODULE:
            self.key = "type"
        else:
            self.key = "name"


class Flash:
    """Flash class contains information regarding parameter defaults.
       For now, only expose banks / pages_per_bank for user configuration.
       For now, also enforce power of 2 requirement.
    """
    max_banks = 4
    max_pages_per_bank = 1024

    def __init__(self, mem, base_addrs):
        self.base_addrs = {
            asid: int(base, 16)
            for (asid, base) in base_addrs.items()
        }
        # The mem map was checked to contain all required keys.
        self.banks = mem['banks']
        self.data_width = mem['data_width']
        self.info_types = mem['info_types']
        self.infos_per_bank = mem['infos_per_bank']
        self.pages_per_bank = mem['pages_per_bank']
        self.program_resolution = mem['program_resolution']
        self.words_per_page = mem['words_per_page']
        self.integrity_width = mem['integrity_width']
        _word_bytes = self.data_width // 8
        self.size = hex(_word_bytes * self.words_per_page *
                        self.pages_per_bank * self.banks)
        self.check_values()

    def is_pow2(self, n):
        return (n != 0) and (n & (n - 1) == 0)

    def check_values(self):
        pow2_check = (self.is_pow2(self.banks) and
                      self.is_pow2(self.pages_per_bank) and
                      self.is_pow2(self.program_resolution))
        limit_check = ((self.banks <= Flash.max_banks) and
                       (self.pages_per_bank <= Flash.max_pages_per_bank))

        if not pow2_check:
            raise ValueError(
                'flash power of 2 check failed. A supplied parameter '
                'is not power of 2')

        if not limit_check:
            raise ValueError(
                'flash number of banks and pages per bank too large')

        if len(self.infos_per_bank) != self.info_types:
            raise ValueError(
                f'size of "infos_per_bank" ({len(self.infos_per_bank)}) '
                f'must match "info_types" ({self.info_types})')

    def _asdict(self):
        return {
            'banks': self.banks,
            'data_width': self.data_width,
            'info_types': self.info_types,
            'infos_per_bank': self.infos_per_bank,
            'pages_per_bank': self.pages_per_bank,
            'program_resolution': self.program_resolution,
            'size': self.size,
            'words_per_page': self.words_per_page
        }


# Check to see if each module/xbar defined in top.hjson exists as ip/xbar.hjson
# Also check there are not multiple definitions of ip/xbar.hjson for each top
# level definition
# If it does, return a dictionary of instance names to index in ip/xbarobjs
def check_target(top, name_to_block, tgtobj):
    error = 0

    tgt_type = tgtobj.target_type.value
    inst_key = tgtobj.key

    for cfg in top[tgt_type]:
        cfg_name = cfg['name'].lower()
        log.info("Checking target %s %s" % (tgt_type, cfg_name))

        if cfg[inst_key] not in name_to_block:
            log.error(f"Could not find ip_block for {cfg_name}")
            error += 1

    return error


def check_pad(top: ConfigT, pad: Dict, known_pad_names: Dict,
              valid_connections: List[str], prefix: str) -> int:
    error = 0

    # check name uniqueness
    if pad['name'] in known_pad_names:
        log.warning('Pad name {} is not unique'.format(pad['name']))
        error += 1
    known_pad_names[pad['name']] = 1

    if not is_valid_pad_type(pad['type']):
        log.warning('Unkown pad type {}'.format(pad['type']))
        error += 1

    if pad['bank'] not in top['pinout']['banks']:
        log.warning('Unkown io power bank {}'.format(pad['bank']))
        error += 1

    if pad['connection'] not in valid_connections:
        log.warning('Connection type {} of pad {} is invalid'.format(
            pad['connection'], pad['name']))
        error += 1

    pad.setdefault('port_type', 'inout')

    return error


def check_alerts(top: ConfigT, ip_name_to_block: IpBlocksT, prefix: str) -> int:
    if "alert" not in top:
        return 0
    errors = 0

    # Check alert_connections for all IPs
    alert_handlers = find_modules(top["module"], "alert_handler",
                                  use_base_template_type=True)
    handler_names = [handler["name"] for handler in alert_handlers]

    # Check that the default handler exists
    default_handler = top.get("default_alert_handler", None)
    if (default_handler is not None and
       default_handler not in handler_names):
        errors += 1
        log.error(f"{default_handler} (named as default alert handler) "
                  f"does not exist")

    for module in top["module"]:
        log.info(f"Checking alerts for {module['name']}")
        block = ip_name_to_block[module["type"]]
        errors += validate_alert(top, module, block, handler_names,
                                 default_handler)
    return errors


def check_incoming_alerts(top: ConfigT, prefix: str) -> int:
    if 'incoming_alert' not in top:
        return 0
    error = 0
    # TODO
    return error


def check_outgoing_alerts(top: ConfigT, prefix: str) -> int:
    if 'outgoing_alert' not in top:
        return 0
    error = 0
    # TODO
    return error


def check_outgoing_interrupts(top: ConfigT, prefix: str) -> int:
    if "outgoing_interrupt" not in top:
        return 0
    error = 0
    # TODO
    return error


def check_incoming_interrupts(top: ConfigT, prefix: str) -> int:
    error = 0
    # TODO
    return error


def check_pinout(top: ConfigT, prefix: str) -> int:
    error = 0

    known_names = {}
    for pad in top['pinout']['pads']:
        error += check_pad(top, pad, known_names,
                           ['direct', 'manual', 'muxed'], prefix + ' Pad')

    return error


def check_pinmux(top: ConfigT, prefix: str) -> int:
    error = 0

    # This is used for the direct connection accounting below,
    # where we tick off already connected direct pads.
    known_direct_pads = {}
    direct_pad_attr = {}
    for pad in top['pinout']['pads']:
        if pad['connection'] == 'direct':
            known_direct_pads[pad['name']] = 1
            direct_pad_attr[pad['name']] = pad['type']

    # Note: the actual signal crosscheck is deferred until the merge stage,
    # since we have no idea at this point which IOs comportable IPs expose.
    for sig in top['pinmux']['signals']:
        if sig['connection'] not in ['direct', 'manual', 'muxed']:
            log.warning(f'Invalid connection type {sig["connection"]}')
            error += 1

        # The pad needs to refer to a valid pad name in the pinout that is of
        # connection type "direct". We tick off all direct pads that have been
        # referenced in order to make sure there are no double connections
        # and unconnected direct pads.
        padname = sig.setdefault('pad', '')
        if padname != '':
            if padname in known_direct_pads:
                if known_direct_pads[padname] == 1:
                    known_direct_pads[padname] = 0
                    padattr = direct_pad_attr[padname]
                else:
                    log.warning(
                        f'Warning, direct pad {padname} is already connected')
                    error += 1
            else:
                log.warning('Unknown direct pad {}'.format(padname))
                error += 1

        # Check port naming scheme.
        port = sig.setdefault('port', '')
        pattern = r'^[a-zA-Z0-9_]*(\[[0-9]*\]){0,1}'
        matches = re.match(pattern, port)
        if matches is None:
            log.warning(f'Port name {port} has wrong format')
            error += 1

        # Check that only direct connections have pad keys
        if sig['connection'] == 'direct':
            if 'attr' in sig and sig['attr'] != padattr:
                log.warning(
                    'Direct connection of instance {} port {} pad attribute '
                    '{} does not match expected {}'.format(
                        sig['instance'], sig['port'], sig['attr'], padattr))
                error += 1
            # Since the signal is directly connected, we can automatically
            # infer the pad type needed to instantiate the correct attribute
            # CSR WARL module inside the pinmux.
            sig['attr'] = padattr

            if padname == '':
                log.warning(
                    'Instance {} port {} connection is of direct type and '
                    'therefore must have an associated pad name.'.format(
                        sig['instance'], sig['port']))
                error += 1
            if port == '':
                log.warning(
                    'Instance {} port {} connection is of direct type and '
                    'therefore must have an associated port name.'.format(
                        sig['instance'], sig['port']))
                error += 1
        elif sig['connection'] == 'muxed':
            # Muxed signals do not have a corresponding pad and attribute CSR,
            # since they first go through the pinmux matrix.
            if sig.setdefault('attr', '') != '':
                log.warning(
                    'Muxed connection of instance {} port {} must not have '
                    'an associated pad attribute field'.format(
                        sig['instance'], sig['port']))
                error += 1
            if padname != '':
                log.warning('Muxed connection of instance {} port {} '
                            'must not have an associated pad'.format(
                                sig['instance'], sig['port']))
                error += 1
        elif sig['connection'] == 'manual':
            # This pad attr key is only allowed in the manual case,
            # as there is no way to infer the pad type automatically.
            sig.setdefault('attr', 'BidirStd')
            if padname != '':
                log.warning('Manual connection of instance {} port {} '
                            'must not have an associated pad'.format(
                                sig['instance'], sig['port']))
                error += 1

    # At this point, all direct pads should have been ticked off.
    for key, val in known_direct_pads.items():
        if val == 1:
            log.warning('Direct pad {} has not been connected'.format(key))
            error += 1

    # Check added io_counts
    for k, counts in top.get('io_counts', {}).items():
        if k not in ['dedicated', 'muxed']:
            log.error(f'{prefix} Pinmux io counts unexpected key {k}')
            error += 1
    return error


def check_implementation_targets(top: ConfigT, prefix: str) -> int:
    error = 0
    known_names = {}
    for target in top['targets']:
        # check name uniqueness
        if target['name'] in known_names:
            log.warning('Target name {} is not unique'.format(target['name']))
            error += 1
        known_names[target['name']] = 1

        # Check special pad signals
        known_entry_names = {}
        for entry in target['pinmux']['special_signals']:

            # check name uniqueness
            if entry['name'] in known_entry_names:
                log.warning('Special pad name {} is not unique'.format(
                    entry['name']))
                error += 1
            known_entry_names[entry['name']] = 1

            # The pad key needs to refer to a valid pad name.
            is_muxed = False
            for pad in top['pinout']['pads']:
                if entry['pad'] == pad['name']:
                    is_muxed = pad['connection'] == 'muxed'
                    break
            else:
                log.warning('Unknown pad {}'.format(entry['pad']))
                error += 1

            if not is_muxed:
                # If this is not a muxed pad, we need to make sure this refers
                # to DIO that is NOT a manual pad.
                for sig in top['pinmux']['signals']:
                    if entry['pad'] == sig['pad']:
                        break
                else:
                    log.warning(
                        'Special pad {} cannot refer to a manual pad'.format(
                            entry['pad']))
                    error += 1

        # Check ports to remove
        for entry in target['pinout']['remove_ports']:
            # The pad key needs to refer to a valid pad name.
            for pad in top['pinout']['pads'] + target['pinout']['add_pads']:
                if entry == pad['name']:
                    break
            else:
                log.warning('Unknown pad {}'.format(entry))
                error += 1

        # Check pads to remove and stub out
        for entry in target['pinout']['remove_pads']:
            # The pad key needs to refer to a valid pad name.
            for pad in top['pinout']['pads']:
                if entry == pad['name']:
                    break
            else:
                log.warning('Unknown pad {}'.format(entry))
                error += 1

        # Check pads to add
        known_pad_names = {}
        for pad in top['pinout']['pads']:
            known_pad_names.update({pad['name']: 1})

        for pad in target['pinout']['add_pads']:
            error += check_pad(top, pad, known_pad_names, ['manual', 'manual_nopadring'],
                               prefix + ' Additional Pad')

    return error


def check_clocks_resets(top: ConfigT, ip_name_to_block: IpBlocksT,
                        xbar_name_to_block: IpBlocksT) -> int:

    error = 0

    # all defined clock/reset nets
    if isinstance(top['resets'], Resets):
        reset_nets = [reset.name for reset in top['resets'].nodes.values()]
    else:
        reset_nets = [reset['name'] for reset in top['resets']['nodes']]
    clock_srcs = list(top['clocks'].all_srcs.keys())
    unmanaged_clock_srcs = list(top['unmanaged_clocks'].clks.keys())
    unmanaged_resets = top.get('unmanaged_resets')
    if unmanaged_resets:
        if isinstance(unmanaged_resets, UnmanagedResets):
            unmanaged_reset_nets = [
                reset for reset in unmanaged_resets.resets.keys()
            ]
        else:
            unmanaged_reset_nets = [
                net for reset in unmanaged_resets for net in reset.values()
            ]

    # Check clock/reset port connection for all IPs
    for ipcfg in top['module']:
        ipcfg_name = ipcfg['type']
        log.info("Checking clock/resets for %s" % ipcfg_name)
        error += validate_reset(ipcfg, ip_name_to_block[ipcfg_name],
                                reset_nets, unmanaged_reset_nets)
        error += validate_clock(ipcfg, ip_name_to_block[ipcfg_name],
                                clock_srcs, unmanaged_clock_srcs)

        if error:
            log.error("module clock/reset checking failed")
            break

    # Check clock/reset port connection for all xbars
    for xbarcfg in top['xbar']:
        xbarcfg_name = xbarcfg['name'].lower()
        log.info("Checking clock/resets for xbar %s" % xbarcfg_name)
        error += validate_reset(xbarcfg, xbar_name_to_block[xbarcfg_name],
                                reset_nets, unmanaged_reset_nets, "xbar")
        error += validate_clock(xbarcfg, xbar_name_to_block[xbarcfg_name],
                                clock_srcs, unmanaged_clock_srcs, "xbar")

        if error:
            log.error("xbar clock/reset checking failed")
            break

    return error


def check_exported_resets(top: ConfigT, component: str) -> int:
    error = 0
    for key, resets in top.get('exported_rsts', {}).items():
        # TODO
        pass
    return error


# Checks the following
# - For each defined reset connection in top*.hjson, there exists a defined
#   port at the destination and defined reset net
# - There are the same number of defined connections as there are ports
def validate_reset(top: ConfigT,
                   inst: Union[IpBlock, ConfigT],
                   reset_nets: List[str],
                   unmanaged_reset_nets: List[str],
                   prefix="") -> int:
    # Gather inst port list
    error = 0

    # Handle either an IpBlock (generated by reggen) or an OrderedDict
    # (generated by topgen for a crossbar)
    if isinstance(inst, IpBlock):
        name = inst.name
        reset_signals = inst.clocking.reset_signals()
    else:
        name = inst['name']
        reset_signals = ([inst.get('reset_primary', 'rst_ni')] +
                         inst.get('other_reset_list', []))

    log.info(f"{prefix} {name} resets are {reset_signals}")

    # Check if reset connections are properly formatted
    # There are two options
    # The reset connection for a particular port must be a str
    # The reset connection for a particular port must be a dict
    # If value is a string, the module can only have ONE domain
    # If value is a dict, it must have the keys name / domain, and the
    # value of domain must match that defined for the module.
    for port, reset in top["reset_connections"].items():
        if isinstance(reset, str):
            top["reset_connections"][port] = {}
            top["reset_connections"][port]['name'] = reset

            if len(top["domain"]) > 1:
                raise ValueError(f"{top['name']} reset connection {reset} "
                                 "has no assigned domain")
            else:
                top["reset_connections"][port]['domain'] = top["domain"][0]

        if isinstance(reset, dict) and reset['domain'] not in top["domain"]:
            error += 1
            log.error(f"domain {reset['domain']} defined for reset "
                      f"{reset['name']} is not a domain of {top['name']}")

    # Check if the reset connections are fully populated
    if len(top['reset_connections']) != len(reset_signals):
        error += 1
        log.error(f"{prefix} {name} mismatched number of reset ports and nets")

    missing_port = [
        port for port in top['reset_connections'].keys()
        if port not in reset_signals
    ]

    if missing_port:
        error += 1
        log.error(f"{prefix} {name} Following reset ports do not exist:")
        [log.error(f"{port}") for port in missing_port]

    missing_net = [
        net['name'] for net in top['reset_connections'].values()
        if net['name'] not in reset_nets + unmanaged_reset_nets
    ]

    if missing_net:
        error += 1
        log.error(f"{prefix} {name} Following reset nets do not exist:")
        [log.error(f"{net}") for net in missing_net]

    return error


# Checks the following
# - For each defined clock_src in top*.hjson, there exists a defined port at
#   the destination and defined clock source
# - There are the same number of defined connections as there are ports
def validate_clock(top: ConfigT,
                   inst: Union[IpBlock, ConfigT],
                   clock_srcs: List[str],
                   unmanaged_clock_srcs: List[str],
                   prefix="") -> int:
    # Gather inst port list
    error = 0

    # Handle either an IpBlock (generated by reggen) or an OrderedDict
    # (generated by topgen for a crossbar)
    if isinstance(inst, IpBlock):
        name = inst.name
        clock_signals = inst.clocking.clock_signals(False)
    else:
        name = inst['name']
        clock_signals = ([inst.get('clock_primary', 'rst_ni')] +
                         inst.get('other_clock_list', []))

    if len(top['clock_srcs']) != len(clock_signals):
        error += 1
        log.error(f"{prefix} {name} mismatched number of clock ports and nets")

    missing_port = [
        port for port in top['clock_srcs'].keys() if port not in clock_signals
    ]

    if missing_port:
        error += 1
        log.error(f"{prefix} {name} Following clock ports do not exist:")
        [log.error(f"{port}") for port in missing_port]

    missing_net = []
    for port, net in top['clock_srcs'].items():
        net_name = net['clock'] if isinstance(net, Dict) else net

        if net_name not in clock_srcs and net_name not in unmanaged_clock_srcs:
            missing_net.append(net)

    if missing_net:
        error += 1
        log.error(f"{prefix} {name} Following clock nets do not exist:")
        [log.error(f"{net}") for net in missing_net]

    return error


def validate_alert(top, module, block, handlers, default_handler=None):
    """Checks that the alert_handler, if specified, exists.

    Note that it's possible for the module `alert_handler` to be null,
    the toplevel `default_alert_handler` to be null, or both, and for
    this not to be an error (in the case that a handler doesn't exist
    at all, like in Scafi_Deprecated).
    """
    errors = 0
    name = module.name if isinstance(module, IpBlock) else module['name']

    # Check that the named alert handler exists
    # (the default handler has already been checked)
    handler = default_handler
    if "alert_handler" in module:
        handler = module["alert_handler"]
        if handler is not None and handler not in handlers:
            errors += 1
            log.error(f"{name} specifies {handler} as alert handler but that "
                      f"alert handler doesn't exist")

    # If there are actually alerts, check that it makes sense:
    # - if the alert handler exists, that's ok
    # - otherwise, if the default handler exists, that's ok
    # - otherwise, if no handlers exist, that's ok
    if block.alerts and handler is None and handlers:
        errors += 1
        log.error(f"{name} doesn't define alert_handler (and "
                  "default_alert_handler isn't defined), but handlers are "
                  "available")

    return errors


def check_power_domains(top: ConfigT):

    # check that the default domain is valid
    if top['power']['default'] not in top['power']['domains']:
        raise ValueError(f"Default power domain {top['power']['default']} is "
                         "not a valid domain")

    # Check that each module, xbar, memory has a power domain defined.
    # If not, give it a default.
    # If there is one defined, check that it is a valid definition
    for end_point in top['module'] + top['xbar']:
        if 'domain' not in end_point:
            end_point['domain'] = [top['power']['default']]

        for d in end_point['domain']:
            if d not in top['power']['domains']:
                raise ValueError(
                    f"{end_point['name']} defined invalid domain {d}")


def check_modules(top: ConfigT, prefix: str) -> int:
    error = 0
    for m in top['module']:
        modname = m.get("name", "unnamed module")

        # these fields are mutually exclusive
        if 'base_addr' in m and 'base_addrs' in m:
            log.error("{} {} a module cannot define both the 'base_addr' "
                      "and 'base_addrs' keys at the same time".format(
                          prefix, modname))
            error += 1

        if 'base_addrs' in m and 'memory' in m:
            for intf, value in m['memory'].items():

                # if size is not declared, there must be extra config to
                # determine it
                if 'size' not in value and 'config' not in value:
                    raise ValueError(
                        f'{m["name"]} memory declaration has neither size '
                        'nor extra configuration.  Unable to determine '
                        'memory size')

                # check the memory regions correspond to the TL-UL interfaces
                if intf not in m['base_addrs']:
                    raise ValueError(
                        f'{prefix} {modname} memory region {intf} does not '
                        'correspond to any of the defined TL-UL interfaces')

                if 'size' not in value:
                    mem_type = value['config'].get('type', "")

                    if mem_type == "flash":
                        flash = Flash(value['config'], m['base_addrs'][intf])
                        value['size'] = flash.size
                        value['config'] = flash
                    else:
                        raise ValueError(
                            f'{m["name"]} memory config declaration does not '
                            'have a valid type')

                # make sure the linker region access attribute is valid
                attr = value.get('swaccess', 'unknown attribute')
                if attr not in ['ro', 'rw']:
                    log.error(
                        '{} {} swaccess attribute {} of memory region {} '
                        'is not valid'.format(prefix, modname, attr, intf))
                    error += 1
    return error


def validate_seed_cfg(top: ConfigT, seed_cfg: ConfigT):
    """
    Validates the seed config coming from an external file
    """
    # First determine the required keys depending on the top configuration
    if find_module(top["module"], "otp_ctrl") and "otp_img_seed" not in seed_cfg:
        raise KeyError("presence of otp_ctrl requires OTP image seed")
    if find_module(top["module"], "lc_ctrl") and "lc_ctrl_seed" not in seed_cfg:
        raise KeyError("presence of lc_ctrl requires LC controller seed")

    validation_errors = all_validation_errors(seed_cfg, SEEDCFG_VALIDATOR, "seedcfg")

    return int(len(validation_errors) > 0)


def validate_top(top: ConfigT, ip_name_to_block: IpBlocksT,
                 xbar_name_to_block: IpBlocksT, raw_top_data: dict) -> int:
    # return as it is for now
    error = len(all_validation_errors(raw_top_data, TOPCFG_VALIDATOR, "topcfg"))
    if error != 0:
        log.error("Top HJSON has top level errors. Aborting")
        return top, error

    component = top['name']

    # Check module instantiations
    error += check_modules(top, component)

    # MODULE  check
    error += check_target(top, ip_name_to_block, Target(TargetType.MODULE))

    # XBAR check
    error += check_target(top, xbar_name_to_block, Target(TargetType.XBAR))

    # Power domain check
    check_power_domains(top)

    error += check_exported_resets(top, component)

    # Clock / Reset check
    error += check_clocks_resets(top, ip_name_to_block, xbar_name_to_block)

    # RV_PLIC check

    # Pinout, pinmux and target checks
    # Note that these checks must happen in this order, as
    # the pinmux and target configs depend on the pinout.
    error += check_pinout(top, component)
    error += check_pinmux(top, component)
    error += check_implementation_targets(top, component)

    error += check_alerts(top, ip_name_to_block, component)
    error += check_incoming_alerts(top, component)
    error += check_outgoing_alerts(top, component)
    error += check_outgoing_interrupts(top, component)
    error += check_incoming_interrupts(top, component)

    return top, error
