#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
r"""Flash info memory map class, used to create the associated C headers,
documentation, and memory images for preloading.
"""
import logging as log
from math import ceil, log2
from pathlib import Path
from typing import Dict, List, Tuple

from basegen.typing import ConfigT
from design.mubi.prim_mubi import is_width_valid, mubi_value_as_int
import hjson
from tabulate import tabulate
from topgen.secure_prng import SecurePrngFactory

from design.lib.common import check_bool, check_int, random_or_hexvalue

# This must match the rtl parameter ScrmblBlockWidth / 8
SCRAMBLE_BLOCK_WIDTH = 8


def _validate_flash_info(flash_info: Dict):
    '''Validate flash entry'''
    flash_info.setdefault("depth", "1024")
    flash_info.setdefault("width", "2")
    flash_info.setdefault("page_size", "2048")
    flash_info["depth"] = check_int(flash_info["depth"])
    flash_info["width"] = check_int(flash_info["width"])
    flash_info["size"] = flash_info["depth"] * flash_info["width"]
    flash_info["addr_width"] = ceil(log2(check_int(flash_info["depth"])))
    flash_info["byte_addr_width"] = ceil(log2(flash_info["size"]))


# return aligned page size
# if remaining number of bytes are not perfectly aligned, truncate
def _avail_blocks(size: int) -> int:
    return int(size / SCRAMBLE_BLOCK_WIDTH)


# distribute number of blocks among free space in page
def _dist_blocks(num_blocks: int, items: List):
    num_items = len(items)

    if not num_items:
        return

    # Very slow looping
    for i in range(num_blocks):
        items[i % num_items]['size'] += SCRAMBLE_BLOCK_WIDTH


# distribute unused flash bits within a page
def _dist_page_unused(page: Dict):
    page_size = page["size"]
    page_allocated_size = 0

    for item in page['items']:
        page_allocated_size += item['size']

    # determine how many aligned blocks are left in the page
    leftover_blocks = _avail_blocks(page_size - page_allocated_size)

    # sponge items are items that will accept leftover allocation from a page
    sponge_items = [item for item in page['items'] if item['absorb']]

    # spread out the blocks
    _dist_blocks(leftover_blocks, sponge_items)


def _validate_page(page: Dict, generate_fresh_keys: bool):
    '''Validates a page within the Flash Info memory map'''
    page.setdefault("name", "unknown_name")
    page.setdefault("desc", "")
    log.info("Validating page {}".format(page["name"]))

    if not isinstance(page['items'], list):
        raise RuntimeError('the "items" key must contain a list')

    # validate items and calculate page size if necessary
    size = 0
    for item in page["items"]:
        _validate_item(item, generate_fresh_keys)
        size += item["size"]

    # Make sure this has integer type.
    page["size"] = check_int(page["size"])

    # Check that items are not too large for the page.
    if size > page["size"]:
        raise RuntimeError(
            f"Page {page['name']} items total to {size}B, but page size is {page['size']}B.")

    # Make sure page size is aligned.
    if page["size"] % SCRAMBLE_BLOCK_WIDTH:
        raise RuntimeError(
            f"Partition size must be {SCRAMBLE_BLOCK_WIDTH * 8}-bit aligned")


def _validate_item(item: Dict, generate_fresh_keys: bool):
    '''Validates an item within a page'''
    item.setdefault("name", "unknown_name")
    item.setdefault("size", "0")
    item.setdefault("ismubi", "false")
    item.setdefault("absorb", False)
    item.setdefault("desc", "")

    # make sure these have the correct types
    item["ismubi"] = check_bool(item["ismubi"])
    item["size"] = check_int(item["size"])
    item_width = item["size"] * 8

    # defaults are handled differently in case of mubi
    if item["ismubi"]:
        if not is_width_valid(item_width):
            raise RuntimeError("Mubi value {} has invalid width".format(
                item["name"]))
        # Convert default to correct mubi value
        item.setdefault("inv_default", "false")
        item["inv_default"] = check_bool(item["inv_default"])
        item["inv_default"] = mubi_value_as_int(item["inv_default"],
                                                item_width)
    else:
        # Generate random constant to be used when page has
        # not been initialized yet or when it is in error state.
        if generate_fresh_keys:
            prng = SecurePrngFactory.get("topgen")
            random_or_hexvalue(prng, item, "inv_default", item_width)


def _validate_type(ty: Dict, generate_fresh_keys: bool):
    '''Validates an flash info type'''
    if not isinstance(ty['pages'], list):
        raise RuntimeError('the "pages" key must contain a list')
    size = 0
    for page in ty["pages"]:
        if "size" not in page:
            page["size"] = ty["page_size"]
        _validate_page(page, generate_fresh_keys)
        size += page["size"]
    ty["size"] = size


def _validate_bank(bank: Dict, generate_fresh_keys: bool):
    '''Validates an flash info bank'''
    if not isinstance(bank['types'], list):
        raise RuntimeError('the "types" key must contain a list')
    size = 0
    for ty in bank["types"]:
        if "page_size" not in ty:
            ty["page_size"] = bank["page_size"]
        _validate_type(ty, generate_fresh_keys)
        size += ty["size"]
    bank["size"] = size


def _validate_mmap(config: Dict, generate_fresh_keys: bool) -> Dict:
    '''Validate the memory map configuration'''

    if not isinstance(config['banks'], list):
        raise RuntimeError('the "banks" key must contain a list')

    # validate inputs before use
    allocated = 0
    for bank in config["banks"]:
        if "page_size" not in bank:
            bank["page_size"] = config["flash_info"]["page_size"]
        _validate_bank(bank, generate_fresh_keys)
        allocated += bank['size']

    # Now that each page's size is defined and allocated,
    # distribute the remaining blocks to each `absorb` item
    # within a page.
    for bank in config["banks"]:
        bank_list = []
        for ty in bank["types"]:
            type_list = []
            for page in ty["pages"]:
                _dist_page_unused(page)

            # Determine offsets and generation dicts
            offset = 0
            page_dict = {}
            for j, page in enumerate(ty["pages"]):

                if page['name'] in page_dict:
                    raise RuntimeError('Page name {} is not unique'.format(
                        page['name']))

                page['offset'] = offset
                if check_int(page['offset']) % SCRAMBLE_BLOCK_WIDTH:
                    raise RuntimeError(f"Page {page['name']} offset must be "
                                       f"{SCRAMBLE_BLOCK_WIDTH * 8}-bit aligned")

                log.info("Page {} at offset {} size {}".format(
                    page["name"], page["offset"], page["size"]))

                # Loop over items within a page
                item_dict = {}
                for k, item in enumerate(page["items"]):
                    if item['name'] in item_dict:
                        raise RuntimeError('Item name {} is not unique'.format(
                            item['name']))
                    item['offset'] = offset
                    log.info("> Item {} at offset {} with size {}".format(
                        item["name"], offset, item["size"]))
                    offset += check_int(item["size"])
                    item_dict[item['name']] = k

                # check offsets and size
                if offset > check_int(page["offset"]) + check_int(page["size"]):
                    raise RuntimeError("Not enough space in page "
                                       "{} to accommodate all items. Bytes available "
                                       "= {}, bytes allocated to items = {}".format(
                                           page["name"], page["size"],
                                           offset - page["offset"]))

                offset = check_int(page["offset"]) + check_int(page["size"])

                page_dict.setdefault(page['name'], {'index': j, 'items': item_dict})
                type_list.append(page_dict)
            bank_list.append(type_list)

    if offset > config["flash_info"]["size"]:
        raise RuntimeError(
            "Flash Info is not big enough to store all pages. "
            "Bytes available {}, bytes required {}", config["flash_info"]["size"],
            offset)

    for bank_num, type_list in enumerate(bank_list):
        for type_num, page_dict in enumerate(type_list):
            log.info("Bank {} type {} pages: {}".format(
                bank_num,
                type_num,
                len(page_dict),
            ))
    log.info("Bytes available in Flash Info: {}".format(config["flash_info"]["size"]))
    log.info("Bytes required for pages: {}".format(offset))

    # return the bank[type[page->item]] data structure
    return bank_list


class FlashInfoMemMap():

    # This holds the config dict.
    config = {}
    # This holds the bank[type[page->item]] data structure for fast access.
    bank_list = []

    def __init__(self, config, generate_fresh_keys: bool = False):

        log.info('')
        log.info('Parse and translate Flash Info memory map.')
        log.info('')

        if "flash_info" not in config:
            raise RuntimeError("Missing flash info configuration.")
        if "banks" not in config:
            raise RuntimeError("Missing bank configuration.")

        # Validate Flash info config.
        _validate_flash_info(config["flash_info"])
        # Validate memory map.
        self.bank_list = _validate_mmap(config, generate_fresh_keys)

        self.config = config

        log.info('')
        log.info('Successfully parsed and translated Flash Info memory map.')
        log.info('')

    @classmethod
    def from_mmap_path(
        cls,
        mmap_path: Path,
        generate_fresh_keys: bool = False,
    ) -> 'FlashInfoMemMap':
        try:
            with open(mmap_path, 'r') as infile:
                config = hjson.load(infile)
        except OSError as e:
            log.error(f"Failed to open file: {e}")
            exit(1)
        except Exception as e:
            log.error(f"Some error loading {mmap_path} into hjson: {e}")
            exit(1)

        try:
            flash_info_mmap = cls(config, generate_fresh_keys)
        except RuntimeError as err:
            log.error(err)
            exit(1)
        return flash_info_mmap

    @classmethod
    def create_page_table(cls, mmap: ConfigT) -> str:
        header = [
            "Bank", "Type", "Page Number", "Page", "Description"
        ]
        table = [header]
        colalign = ("center", ) * len(header[:-1]) + ("left", )
        for bank_num, bank_dict in enumerate(mmap["banks"]):
            for type_num, type_dict in enumerate(bank_dict["types"]):
                for page_num, page_dict in enumerate(type_dict["pages"]):
                    desc = " ".join(page_dict.get("desc", "").split("\n"))
                    row = [
                        "", "",
                        str(page_num), page_dict["name"], desc
                    ]
                    if page_num == 0:
                        row[1] = str(type_num)
                        if type_num == 0:
                            row[0] = str(bank_num)
                    table.append(row)

        return tabulate(table,
                        headers="firstrow",
                        tablefmt="pipe",
                        colalign=colalign)

    @classmethod
    def create_mmap_table(cls, mmap: ConfigT) -> str:
        header = [
            "Bank", "Type", "Page Number", "Page", "Size [B]",
            "Item", "Byte Offset", "Size [B]"
        ]
        table = [header]
        colalign = ("center", ) * len(header)

        for bank_num, bank_dict in enumerate(mmap["banks"]):
            for type_num, type_dict in enumerate(bank_dict["types"]):
                for page_num, page_dict in enumerate(type_dict["pages"]):
                    for item_num, item in enumerate(page_dict["items"]):
                        name = item["name"]
                        if item_num > 0:
                            row = ["", "", "", "", ""]
                        else:
                            row = [
                                "", "", str(page_num),
                                page_dict["name"], str(page_dict["size"]),
                            ]
                            if page_num == 0:
                                row[1] = str(type_num)
                                if type_num == 0:
                                    row[0] = str(bank_num)

                        row.extend([
                            name, "0x{:03X}".format(check_int(item["offset"])),
                            str(item["size"])
                        ])

                        table.append(row)

        return tabulate(table,
                        headers="firstrow",
                        tablefmt="pipe",
                        colalign=colalign)

    @classmethod
    def create_description_table(cls, mmap: ConfigT) -> str:
        header = [
            "Bank", "Type", "Page Number", "Page",
            "Item", "Size [B]", "Description",
        ]
        table = [header]
        # Everything column center aligned, except the descriptions.
        colalign = ["center"] * len(header)
        colalign[-1] = "left"

        for bank_num, bank_dict in enumerate(mmap["banks"]):
            for type_num, type_dict in enumerate(bank_dict["types"]):
                for page_num, page_dict in enumerate(type_dict["pages"]):
                    for item_num, item in enumerate(page_dict["items"]):
                        if item_num > 0:
                            row = ["", "", "", ""]
                        else:
                            row = [
                                "", "",
                                str(page_num), page_dict["name"],
                            ]
                            if page_num == 0:
                                row[1] = str(type_num)
                                if type_num == 0:
                                    row[0] = str(bank_num)

                        desc = " ".join(item.get("desc", "").split("\n"))
                        row.extend([item["name"], str(item["size"]), desc])

                        table.append(row)

        return tabulate(table,
                        headers="firstrow",
                        tablefmt="pipe",
                        colalign=colalign)

    def all_pages(self) -> List[Tuple[int, int, int, Dict]]:
        ''' Get metadata for all pages across all banks/types'''
        return [
            (bank_num, type_num, page_num, len(ty["pages"]) == 1, page)
            for bank_num, bank in enumerate(self.config["banks"])
            for type_num, ty in enumerate(bank["types"])
            for page_num, page in enumerate(ty["pages"])
        ]

    def all_items(self) -> List[Tuple[Dict, Dict]]:
        ''' Get page name and item metadata of all items'''
        return [
            (page, item)
            for _, _, _, _, page in self.all_pages()
            for item in page["items"]
        ]
