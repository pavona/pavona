# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load(
    "//rules/pavona:defs.bzl",
    "fpga_params",
    "pavona_test",
)

package(default_visibility = ["//visibility:public"])

pavona_test(
    name = "xmodem_protocol",
    exec_env = {
        "//hw/top_earlgrey:fpga_cw310_rom_ext": None,
        "//hw/top_earlgrey:fpga_cw340_rom_ext": None,
    },
    fpga = fpga_params(
        assemble = "",
        binaries = {
            "//sw/device/silicon_creator/rom_ext/e2e/rescue:boot_test_slot_a": "boot_test",
        },
        changes_otp = True,
        test_cmd = """
            --clear-bitstream
            --bootstrap={rom_ext}
            --firmware={boot_test}
        """,
        test_harness = "//sw/host/tests/rescue:xmodem_protocol",
    ),
)

pavona_test(
    name = "usbdfu_protocol",
    exec_env = {
        "//hw/top_earlgrey:fpga_cw310_rom_ext": None,
        "//hw/top_earlgrey:fpga_cw340_rom_ext": None,
    },
    fpga = fpga_params(
        assemble = "",
        binaries = {
            "//sw/device/silicon_creator/rom_ext/e2e/rescue:boot_test_slot_a": "boot_test",
        },
        changes_otp = True,
        rom_ext = "//sw/device/silicon_creator/rom_ext:rom_ext_usbdfu",
        tags = ["skip_in_ci"],
        test_cmd = """
            --clear-bitstream
            --bootstrap={rom_ext}
            --firmware={boot_test}
            --trigger=strap
            --value=3
        """,
        test_harness = "//sw/host/tests/rescue:usbdfu_protocol",
    ),
)
