# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#

load("//rules/pavona:hw.bzl", "pavona_top")
load("//hw/top_egret/data/autogen:defs.bzl", "EGRET_IPS")
load("//hw/top_egret/data/otp:defs.bzl", "EGRET_OTP_SIGVERIFY_FAKE_KEYS", "EGRET_STD_OTP_OVERLAYS")

EGRET = pavona_top(
    name = "egret",
    hjson = "//hw/top_egret/data/autogen:top_egret.gen.hjson",
    top_lib = "//hw/top_egret/sw/autogen:top_egret",
    top_rtl = "//hw/top_egret:rtl_files",
    top_verilator_core = ["lowrisc:dv:top_egret_chip_verilator_sim"],
    top_verilator_binary = {"binary": ["lowrisc_dv_top_egret_chip_verilator_sim_0.1/sim-verilator/Vchip_sim_tb"]},
    top_ld = "//hw/top_egret/sw/autogen:top_egret_memory",
    otp_map = "//hw/top_egret/data/otp:otp_ctrl_mmap.hjson",
    std_otp_overlay = EGRET_STD_OTP_OVERLAYS,
    otp_sigverify_fake_keys = EGRET_OTP_SIGVERIFY_FAKE_KEYS,
    ips = EGRET_IPS,
    secret_cfgs = {
        "testing": "//hw/top_egret/data/autogen:top_egret.secrets.testing.gen.hjson",
    },
    silicon_creator_hooks = "//hw/top_egret/sw/device/silicon_creator:hooks",
)

EGRET_SLOTS = {
    "rom_ext_slot_a": "0x0",
    "rom_ext_slot_b": "0x80000",
    "owner_slot_a": "0x10000",
    "owner_slot_b": "0x90000",
    "rom_ext_size": "0x10000",
}
