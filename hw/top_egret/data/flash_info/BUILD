# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//hw/top:defs.bzl", "pavona_require_top")
load("//rules:flash.bzl", "flash_info_json", "flash_info_page")

FLASH_PAGE_SIZE = 0x800

flash_info_json(
    name = "flash_info_json_factory_id",
    partitions = [
        flash_info_page(
            name = "FACTORY_ID",
            items = {},
        ),
    ],
)

flash_info_json(
    name = "flash_info_json_creator_secret",
    partitions = [
        flash_info_page(
            name = "CREATOR_SECRET",
            items = {
                "CREATOR_SECRET_KEY_SEED": "<random>",
            },
        ),
    ],
)

flash_info_json(
    name = "flash_info_json_owner_secret",
    partitions = [
        flash_info_page(
            name = "OWNER_SECRET",
            items = {
                "OWNER_SECRET_KEY_SEED": "<random>",
            },
        ),
    ],
)

flash_info_json(
    name = "flash_info_json_wafer_auth_secret",
    partitions = [
        flash_info_page(
            name = "WAFER_AUTH_SECRET",
            items = {
                "WAFER_AUTH_SECRET": "<random>",
            },
        ),
    ]
)

flash_info_json(
    name = "flash_info_json_attestation_key_seeds",
    partitions = [
        flash_info_page(
            name = "ATTESTATION_KEY_SEEDS",
            items = {
                "ATTESTATION_KEY_SEED_UDS": "<random>",
                "ATTESTATION_KEY_SEED_CDI0": "<random>",
                "ATTESTATION_KEY_SEED_CDI1": "<random>",
            },
        ),
    ],
)

flash_info_json(
    name = "flash_info_json_owner_reserved0",
    partitions = [
        flash_info_page(
            name = "OWNER_RESERVED0",
            items = {
                "OWNER_RESERVED0": "0x0",
            },
        ),
    ],
)

flash_info_json(
    name = "flash_info_json_owner_reserved1",
    partitions = [
        flash_info_page(
            name = "OWNER_RESERVED1",
            items = {
                "OWNER_RESERVED1": "0x0",
            },
        ),
    ],
)

flash_info_json(
    name = "flash_info_json_owner_reserved2",
    partitions = [
        flash_info_page(
            name = "OWNER_RESERVED2",
            items = {
                "OWNER_RESERVED2": "0x0",
            },
        ),
    ],
)

flash_info_json(
    name = "flash_info_json_owner_reserved3",
    partitions = [
        flash_info_page(
            name = "OWNER_RESERVED3",
            items = {
                "OWNER_RESERVED3": "0x0",
            },
        ),
    ],
)

flash_info_json(
    name = "flash_info_json_factory_certs",
    partitions = [
        flash_info_page(
            name = "FACTORY_CERTS",
            items = {
                "DICE_UDS_CERTIFICATE": "0x0",
            },
        ),
    ],
)
