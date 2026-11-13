# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# This is a set of overlays to generate a generic, standard flash info image.
# Additional overlays can be applied on top to further customize the flash.
EGRET_STD_FLASH_INFO_OVERLAYS = [
    "@//hw/top_egret/data/flash_info:flash_info_json_factory_id",
    "@//hw/top_egret/data/flash_info:flash_info_json_creator_secret",
    "@//hw/top_egret/data/flash_info:flash_info_json_owner_secret",
    "@//hw/top_egret/data/flash_info:flash_info_json_wafer_auth_secret",
    "@//hw/top_egret/data/flash_info:flash_info_json_attestation_key_seeds",
    "@//hw/top_egret/data/flash_info:flash_info_json_owner_reserved0",
    "@//hw/top_egret/data/flash_info:flash_info_json_owner_reserved1",
    "@//hw/top_egret/data/flash_info:flash_info_json_owner_reserved2",
    "@//hw/top_egret/data/flash_info:flash_info_json_owner_reserved3",
    "@//hw/top_egret/data/flash_info:flash_info_json_factory_certs",
]
