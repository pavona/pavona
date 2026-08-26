# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
import logging as log
from typing import Any, Dict, List, Optional, Tuple

from basegen.validate import create_validator, all_validation_errors
from basegen.lib import cast_hjson_values

from .item import Node, Host, Device, AsyncFifo, Socket1N, SocketM1
from .lib import simplify_addr
from .xbar import Xbar


XBAR_VALIDATOR = create_validator("urn:tlgen:xbar")

# Minimum device spacing that is checked during validation
# by inspecting the base addresses. Note that the validation
# script also ensures that base addresses are aligned with
# to this granularity.
MIN_DEVICE_SPACING = 0x100


def mk_node(typ: str, name: str, clock: str, reset: str) -> Node:
    """Create a graph node with the requested node type.

    This is just a wrapper around the constructors in item.py, and picks the
    right Python class for the textual requested node type.

    `typ` gives the name of the node type. `name` gives the name of the node.
    `clock` and `reset` give the names of the node's clock and reset signals.
    """
    if typ == "host":
        return Host(name, clock, reset)
    if typ == "device":
        return Device(name, clock, reset)
    if typ == "async_fifo":
        return AsyncFifo(name, clock, reset)
    if typ == "socket_1n":
        return Socket1N(1, name, clock, reset)
    if typ == "socket_m1":
        return SocketM1(1, name, clock, reset)

    log.error("Cannot process type {}".format(typ))
    raise


def checkNameExist(name: str, xbar: Xbar) -> bool:
    return name.lower() in [x.name for x in xbar.nodes]


def isOverlap(range1: Tuple[int, int], range2: Tuple[int, int]) -> bool:
    return not (range2[1] < range1[0] or range2[0] > range1[1])


def isNotMinSpacing(range1: Tuple[int, int], range2: Tuple[int, int]) -> bool:
    return not (range2[0] < range1[0] - MIN_DEVICE_SPACING or
                range2[0] >= range1[0] + MIN_DEVICE_SPACING)


def isNotAligned(base: int) -> bool:
    return ((base & (MIN_DEVICE_SPACING - 1)) != 0)


def checkAddressOverlap(addr: Tuple[int, int],
                        ranges: List[Tuple[int, int]]) -> bool:
    result = [(hex(x[0]), hex(x[1])) for x in ranges if isOverlap(x, addr)]
    return len(result) != 0


def checkAddressSpacing(addr: Tuple[int, int],
                        ranges: List[Tuple[int, int]]) -> bool:
    result = [x for x in ranges if isNotMinSpacing(x, addr)]
    return len(result) != 0


# this returns 1 if the size mask overlaps with the address base
def checkBaseSizeOverlap(addr_base: int, size: int) -> int:
    return ((size - 1) & addr_base)


def get_string_keys(what: str, raw: object) -> List[str]:
    if not isinstance(raw, dict):
        raise ValueError(f"{what} should be a dict and is {raw}.")

    ret: List[str] = []
    for k, v in raw.items():
        if not isinstance(k, str):
            raise ValueError(f"{what} had a key of {k}, not a string.")
        ret.append(k)

    return ret


def validate(obj: Dict[Any, Any]) -> Optional[Xbar]:
    xbar = Xbar()
    xbar.name = obj["name"].lower()
    xbar.clock = obj["clock"].lower()
    xbar.reset = obj["reset"].lower()
    addr_ranges: Dict[str, List[Tuple[int, int]]] = {}

    # validate Hjson format first
    hjson_good = validate_hjson(obj)
    if not hjson_good:
        message = f"Hjson structure error for xbar {xbar.name}"
        log.error(message)
        raise SystemExit(message)

    # collection of all clocks and resets of this xbar
    xbar.clocks = get_string_keys("clock_connections",
                                  obj.get("clock_connections", {}))
    xbar.resets = get_string_keys("reset_connections",
                                  obj.get("reset_connections", {}))

    # Nodes
    for nodeobj in obj["nodes"]:

        if checkNameExist(nodeobj["name"], xbar):
            log.error("Duplicated name: %s" % (nodeobj["name"]))
            raise SystemExit("Duplicated name in the configuration")

        clock = nodeobj["clock"].lower() if "clock" in nodeobj.keys(
        ) else xbar.clock

        reset = nodeobj["reset"].lower() if "reset" in nodeobj.keys(
        ) else xbar.reset

        if clock not in xbar.clocks:
            log.error(
                "Clock %s for module %s does not exist in xbar_%s, check xbar hjson"
                % (clock, nodeobj['name'], obj['name']))
            raise SystemExit("Clock does not exist")

        if reset not in xbar.resets:
            log.error(
                "Reset %s for module %s does not exist in xbar_%s, check xbar hjson"
                % (reset, nodeobj['name'], obj['name']))
            raise SystemExit("Reset does not exist")

        node = mk_node(typ=nodeobj["type"].lower(),
                       name=nodeobj["name"].lower(),
                       clock=clock,
                       reset=reset)

        if isinstance(node, Host):
            node.addr_spaces = set()
            addr_space = nodeobj.get('addr_space')
            if addr_space is None:
                raise ValueError(f"Node {node.name} has type "
                                 f"'host' but no addr_space")
            else:
                # This should have been checked because of the 's' typing
                # defined by the node dictionary
                assert isinstance(addr_space, str)
                node.addr_spaces.add(addr_space)

        if isinstance(node, Device):
            node.xbar = nodeobj["xbar"]
            node.addr_ranges = {}
            node.addr_spaces = set()

            # Compact the address ranges
            if node.xbar:
                nodeobj["addr_range"] = simplify_addr(nodeobj, obj, nodeobj["addr_space"])

            # Note that only xbar nodes should have multiple ranges for a given
            # ASID, but downstream xbar-to-xbar edges only support one ASID.
            for addr in nodeobj["addr_range"]:
                for asid, base_addr in addr["base_addrs"].items():
                    addr_range = addr_ranges.setdefault(asid, [])
                    address_from = int(base_addr, 0)
                    size = int(addr["size_byte"], 0)
                    address_to = address_from + size - 1

                    addr_entry = (address_from, address_to)

                    if isNotAligned(address_from):
                        log.error(
                            "Address bases must be aligned to 0x%x blocks. "
                            "Check the config. Addr(0x%x - 0x%x)."
                            % (MIN_DEVICE_SPACING, addr_entry[0], addr_entry[1]))
                        raise SystemExit("Base alignment error occurred")

                    if checkAddressOverlap(addr_entry, addr_range):
                        log.error(
                            "Address is overlapping. Check the config. Addr(0x%x - 0x%x). "
                            % (addr_entry[0], addr_entry[1]))
                        raise SystemExit("Address overlapping error occurred")

                    if checkAddressSpacing(addr_entry, addr_range):
                        log.error(
                            "Address bases must be spaced at least 0x%x apart. "
                            "Check the config. Addr(0x%x - 0x%x)."
                            % (MIN_DEVICE_SPACING, addr_entry[0], addr_entry[1]))
                        raise SystemExit("Address overlapping error occurred")

                    addr_range.append(addr_entry)
                    node_addr_range = node.addr_ranges.setdefault(asid, [])
                    node_addr_range.append(addr_entry)
                    node.addr_spaces.add(asid)

        node.pipeline = False
        node.req_fifo_pass = False
        node.rsp_fifo_pass = False

        if isinstance(node, Device) or isinstance(node, Host):
            node.pipeline = nodeobj.get("pipeline", False)
            node.req_fifo_pass = nodeobj.get("req_fifo_pass", False)
            node.rsp_fifo_pass = nodeobj.get("rsp_fifo_pass", False)

        xbar.nodes.append(node)

    # Edge
    for host in obj["connections"].keys():
        # host: [device]
        for device in obj["connections"][host]:
            xbar.connect_nodes(host.lower(), device.lower())

    return xbar


def validate_hjson(obj: Dict[Any, Any]) -> bool:
    """Check well-formedness of obj as a parsed hjson crossbar.

    Return True if well-formed and False otherwise. This may modify obj.
    """
    if "type" not in obj:
        obj["type"] = "xbar"
    if "name" not in obj:
        log.error("Component has no name. Aborting.")
        return False

    validation_errors = all_validation_errors(cast_hjson_values(obj), XBAR_VALIDATOR, "xbar")

    return len(validation_errors) == 0
