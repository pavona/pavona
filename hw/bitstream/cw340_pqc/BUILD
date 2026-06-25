# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "bitstream",
    testonly = True,
    srcs = select({
        "//hw/bitstream:bitstream_skip": ["//hw/bitstream/universal:none"],
        "//hw/bitstream:bitstream_vivado": ["//hw/bitstream/vivado:fpga_cw340_pqc_test_rom"],
        "//hw/bitstream:bitstream_gcp_splice": ["@bitstreams//:chip_egret_cw340_pqc_bitstream"],
        "//conditions:default": ["@bitstreams//:chip_egret_cw340_pqc_bitstream"],
    }),
    tags = ["manual"],
)

filegroup(
    name = "mmi",
    testonly = True,
    srcs = select({
        "//hw/bitstream:bitstream_skip": ["//hw/bitstream/universal:none"],
        "//hw/bitstream:bitstream_vivado": ["//hw/bitstream/vivado:cw340_pqc_mmi"],
        "//hw/bitstream:bitstream_gcp_splice": ["@bitstreams//:chip_egret_cw340_pqc_mmi"],
        "//conditions:default": ["@bitstreams//:chip_egret_cw340_pqc_mmi"],
    }),
    tags = ["manual"],
)
