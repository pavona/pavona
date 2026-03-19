# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:flash.bzl", "flash_image", "flash_partition")

FLASH_PAGE_SIZE = 0x800

# TODO: Replace these `genrule`s that fill the flash pages with all zeroes with
# targets that generate the correct contents as necessary.
[
    genrule(
        name = page,
        outs = ["{}.img".format(page)],
        cmd = "dd if=/dev/zero of=$(location :{}.img) bs={} count=1 2>/dev/null".format(
            page,
            FLASH_PAGE_SIZE,
        ),
    )
    for page in [
        # Bank 0 pages
        "factory_id",
        "creator_secret",
        "owner_secret",
        "wafer_auth_secret",
        "attestation_key_seeds",
        "owner_reserved_0",
        "owner_reserved_1",
        "owner_reserved_2",
        "owner_reserved_3",
        "factory_certs",
        # Bank 1 pages
        "boot_data_0",
        "boot_data_1",
        "owner_slot_0",
        "owner_slot_1",
        "creator_reserved_0",
        "owner_reserved_4",
        "owner_reserved_5",
        "owner_reserved_6",
        "owner_reserved_7",
        "dice_certs",
        # Unallocated pages
        "unallocated",
    ]
]

flash_partition(
    name = "flash0_info0",
    pages = {
        "0": ":factory_id",
        "1": ":creator_secret",
        "2": ":owner_secret",
        "3": ":wafer_auth_secret",
        "4": ":attestation_key_seeds",
        "5": ":owner_reserved_0",
        "6": ":owner_reserved_1",
        "7": ":owner_reserved_2",
        "8": ":owner_reserved_3",
        "9": ":factory_certs",
    },
)

flash_partition(
    name = "flash0_info1",
    pages = {
        "0": ":unallocated",
        "1": ":unallocated",
        "2": ":unallocated",
        "3": ":unallocated",
        "4": ":unallocated",
        "5": ":unallocated",
        "6": ":unallocated",
        "7": ":unallocated",
        "8": ":unallocated",
        "9": ":unallocated",
    },
)

flash_partition(
    name = "flash0_info2",
    pages = {
        "0": ":unallocated",
        "1": ":unallocated",
        "2": ":unallocated",
        "3": ":unallocated",
        "4": ":unallocated",
        "5": ":unallocated",
        "6": ":unallocated",
        "7": ":unallocated",
        "8": ":unallocated",
        "9": ":unallocated",
    },
)

flash_partition(
    name = "flash1_info0",
    pages = {
        "0": ":boot_data_0",
        "1": ":boot_data_1",
        "2": ":owner_slot_0",
        "3": ":owner_slot_1",
        "4": ":creator_reserved_0",
        "5": ":owner_reserved_4",
        "6": ":owner_reserved_5",
        "7": ":owner_reserved_6",
        "8": ":owner_reserved_7",
        "9": ":dice_certs",
    },
)

flash_partition(
    name = "flash1_info1",
    pages = {
        "0": ":unallocated",
        "1": ":unallocated",
        "2": ":unallocated",
        "3": ":unallocated",
        "4": ":unallocated",
        "5": ":unallocated",
        "6": ":unallocated",
        "7": ":unallocated",
        "8": ":unallocated",
        "9": ":unallocated",
    },
)

flash_partition(
    name = "flash1_info2",
    pages = {
        "0": ":unallocated",
        "1": ":unallocated",
        "2": ":unallocated",
        "3": ":unallocated",
        "4": ":unallocated",
        "5": ":unallocated",
        "6": ":unallocated",
        "7": ":unallocated",
        "8": ":unallocated",
        "9": ":unallocated",
    },
)

# Flash scrambled VMEM images.
[
    flash_image(
        name = "flash{}_info{}_{}".format(bank, partition, lc_state),
        otp = "//hw/top_earlgrey/data/otp:img_{}".format(lc_state),
        otp_mmap = "//hw/top_earlgrey/data/otp:otp_ctrl_mmap.hjson",
        partition = ":flash{}_info{}".format(bank, partition),
        visibility = ["//visibility:public"],
    )
    for bank in range(2)
    for partition in range(3)
    for lc_state in [
        "dev",
        "rma",
        "test_locked0",
        "test_locked1",
        "test_locked2",
        "test_locked3",
        "test_locked4",
        "test_locked5",
        "test_locked6",
        "test_unlocked0",
        "test_unlocked1",
        "test_unlocked1_initial",
        "test_unlocked2",
        "test_unlocked3",
        "test_unlocked4",
        "test_unlocked5",
        "test_unlocked6",
        "test_unlocked7",
        "prod",
        "prod_end",
        "exec_disabled",
        "bootstrap_disabled",
        "raw",
    ]
]
