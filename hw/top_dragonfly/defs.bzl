# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#

load("//rules/pavona:hw.bzl", "pavona_top")
load("//hw/top_dragonfly/data/autogen:defs.bzl", "DRAGONFLY_IPS")
load("//hw/top_dragonfly/data/otp:defs.bzl", "DRAGONFLY_OTP_SIGVERIFY_FAKE_KEYS", "DRAGONFLY_STD_OTP_OVERLAYS")

DRAGONFLY = pavona_top(
    name = "dragonfly",
    hjson = "//hw/top_dragonfly/data/autogen:top_dragonfly.gen.hjson",
    top_lib = "//hw/top_dragonfly/sw/autogen:top_dragonfly",
    top_rtl = "//hw/top_dragonfly:rtl_files",
    top_verilator_core = ["lowrisc:dv:top_dragonfly_chip_verilator_sim"],
    top_verilator_binary = {"binary": ["lowrisc_dv_top_dragonfly_chip_verilator_sim_0.1/sim-verilator/Vchip_sim_tb"]},
    top_ld = "//hw/top_dragonfly/sw/autogen:top_dragonfly_memory",
    otp_map = "//hw/top_dragonfly/data/otp:otp_ctrl_mmap.hjson",
    std_otp_overlay = DRAGONFLY_STD_OTP_OVERLAYS,
    otp_sigverify_fake_keys = DRAGONFLY_OTP_SIGVERIFY_FAKE_KEYS,
    ips = DRAGONFLY_IPS,
    secret_cfgs = {
        "testing": "//hw/top_dragonfly/data/autogen:top_dragonfly.secrets.testing.gen.hjson",
    },
)

DRAGONFLY_SLOTS = {
    "sram_main": "0x10000000",
    "sram_main_size": "0x10000",
    "sram_ctn": "0x41000000",
    "rom_ext_sram_ctn": "0x0",
    "sram_ctn_size": "0x100000",
}
