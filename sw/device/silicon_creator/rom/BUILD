# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@rules_fuzzing//fuzzing:cc_defs.bzl", "cc_fuzz_test")
load("@rules_pkg//pkg:mappings.bzl", "pkg_files")
load("//hw/top:defs.bzl", "pavona_if_ip", "pavona_require_ip", "pavona_select_top")
load("//rules:cross_platform.bzl", "dual_cc_library", "dual_inputs")
load("//rules:files.bzl", "output_groups")
load("//rules:linker.bzl", "ld_library")
load(
    "//rules/pavona:defs.bzl",
    "PAVONA_CPU",
    "fpga_params",
    "pavona_binary",
    "pavona_manual_test",
    "pavona_test",
)
load("//rules/pavona:legacy.bzl", "legacy_rom_targets")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "doc_files",
    srcs = glob([
        "**/*.md",
        "**/*.svg",
        "**/*.png",
    ]) + [
        "//sw/device/silicon_creator/rom/data:rom_e2e_testplan.hjson",
        "//sw/device/silicon_creator/rom/data:rom_manual_testplan.hjson",
        "//sw/device/silicon_creator/rom/hooks:README.md",
        "//sw/device/silicon_creator/rom/keys:README.md",
    ],
)

dual_cc_library(
    name = "boot_policy_ptrs",
    srcs = dual_inputs(
        host = ["mock_boot_policy_ptrs.cc"],
        shared = ["boot_policy_ptrs.c"],
    ),
    hdrs = dual_inputs(
        host = ["mock_boot_policy_ptrs.h"],
        shared = ["boot_policy_ptrs.h"],
    ),
    deps = dual_inputs(
        # On designs with onboard flash, ROM_EXT is held there; otherwise it
        # lives in CTN memory, which is governed by the soc_proxy.
        host = [
            "//sw/device/lib/base:global_mock",
            "//sw/device/silicon_creator/testing:rom_test",
            "@googletest//:gtest",
        ],
        shared = [
            "//sw/device/silicon_creator/lib:manifest",
        ] + pavona_if_ip(
            "flash_ctrl",
            ["//hw/top/dt:flash_ctrl"],
            ["//hw/top/dt:soc_proxy"],
        ),
    ),
)

cc_library(
    name = "boot_policy",
    srcs = ["boot_policy.c"],
    hdrs = ["boot_policy.h"],
    deps = [
        ":boot_policy_ptrs",
        "//sw/device/lib/base:hardened",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib:manifest",
        "//sw/device/silicon_creator/lib:shutdown",
        "//sw/device/silicon_creator/lib/base:chip",
    ] + pavona_if_ip(
        "flash_ctrl",
        ["//sw/device/silicon_creator/lib:boot_data"],
        [],
    ),
)

cc_test(
    name = "boot_policy_unittest",
    srcs = ["boot_policy_unittest.cc"],
    # This test checks boot_data and manifest priority order, both of which are
    # irrelevant in designs where the ROM_EXT is loaded to CTN SRAM.
    target_compatible_with = pavona_require_ip("flash_ctrl"),
    deps = [
        ":boot_policy",
        "//sw/device/silicon_creator/testing:rom_test",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "bootstrap",
    srcs = ["bootstrap.c"],
    hdrs = ["bootstrap.h"],
    deps = [
        "//hw/top:gpio_c_regs",
        "//hw/top:otp_ctrl_c_regs",
        "//hw/top/dt",
        "//sw/device/lib/base:abs_mmio",
        "//sw/device/lib/base:bitfield",
        "//sw/device/lib/base:hardened",
        "//sw/device/silicon_creator/lib:bootstrap",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib/base:chip",
        "//sw/device/silicon_creator/lib/drivers:otp",
    ] + pavona_if_ip(
        "flash_ctrl",
        [
            "//hw/top:flash_ctrl_c_regs",
            "//sw/device/silicon_creator/lib/drivers:flash_ctrl",
        ],
        [],
    ),
)

cc_test(
    name = "bootstrap_unittest",
    srcs = ["bootstrap_unittest.cc"],
    deps = [
        ":bootstrap",
        "//hw/top:flash_ctrl_c_regs",
        "//hw/top:gpio_c_regs",
        "//hw/top:otp_ctrl_c_regs",
        "//sw/device/silicon_creator/lib:bootstrap_unittest_util",
        "@googletest//:gtest_main",
    ],
)

# To test this target, you must specify `--config=asan-libfuzzer`.
cc_fuzz_test(
    name = "bootstrap_fuzz_test",
    srcs = ["bootstrap_fuzz_test.cc"],
    tags = [
        "fuzzer",
        "manual",
    ],
    deps = [
        ":bootstrap",
        "//sw/device/silicon_creator/lib:bootstrap_fuzzer_util",
        "@abseil-cpp//absl/types:span",
    ],
)

cc_library(
    name = "boot_second_rom",
    srcs = ["boot_second_rom.c"],
    hdrs = ["boot_second_rom.h"],
    deps = [
        ":boot_policy",
        ":rom_cfi",
        "//hw/top/dt:rom_ctrl",
        "//sw/device/lib/base:csr",
        "//sw/device/silicon_creator/lib:rom_patch",
        "//sw/device/silicon_creator/lib/base:boot_measurements",
        "//sw/device/silicon_creator/lib/drivers:epmp",
    ],
)

cc_library(
    name = "boot_rom_ext",
    srcs = ["boot_rom_ext.c"],
    hdrs = ["boot_rom_ext.h"],
    defines = pavona_if_ip(
        "keymgr_dpe",
        ["HAS_KEYMGR_DPE"],
        ["HAS_KEYMGR"],
    ) + pavona_select_top(
        {
            "egret": ["DISCRETE_OTP_MAP"],
            "dragonfly": ["INTEGRATED_OTP_MAP"],
        },
        [],
    ),
    deps = [
        ":boot_policy",
        ":boot_policy_ptrs",
        ":rom_cfi",
        ":rom_epmp",
        ":sigverify_keys_ecdsa_p256",
        ":sigverify_keys_spx",
        ":sigverify_otp_keys",
        "//sw/device/lib/base:csr",
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:memory",
        "//sw/device/silicon_creator/lib:acc_boot_services",
        "//sw/device/silicon_creator/lib:boot_data",
        "//sw/device/silicon_creator/lib:boot_log",
        "//sw/device/silicon_creator/lib:cfi",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib:manifest",
        "//sw/device/silicon_creator/lib:shutdown",
        "//sw/device/silicon_creator/lib:stack_utilization",
        "//sw/device/silicon_creator/lib/base:boot_measurements",
        "//sw/device/silicon_creator/lib/base:sec_mmio",
        "//sw/device/silicon_creator/lib/base:util",
        "//sw/device/silicon_creator/lib/drivers:alert",
        "//sw/device/silicon_creator/lib/drivers:epmp",
        "//sw/device/silicon_creator/lib/drivers:hmac",
        "//sw/device/silicon_creator/lib/drivers:ibex",
        "//sw/device/silicon_creator/lib/drivers:lifecycle",
        "//sw/device/silicon_creator/lib/drivers:otp",
        "//sw/device/silicon_creator/lib/drivers:retention_sram",
        "//sw/device/silicon_creator/lib/drivers:rnd",
        "//sw/device/silicon_creator/lib/drivers:rstmgr",
        "//sw/device/silicon_creator/lib/sigverify",
    ] + pavona_if_ip(
        "flash_ctrl",
        ["//sw/device/silicon_creator/lib/drivers:flash_ctrl"],
        [],
    ) + pavona_if_ip(
        "keymgr_dpe",
        ["//sw/device/silicon_creator/lib/drivers:keymgr_dpe"],
        ["//sw/device/silicon_creator/lib/drivers:keymgr"],
    ),
)

cc_library(
    name = "rom_isrs",
    srcs = [
        "rom_isrs.c",
    ] + pavona_if_ip(
        "flash_ctrl",
        ["//sw/device/silicon_creator/lib:flash_exc_handler"],
        [],
    ),
    hdrs = ["rom_isrs.h"],
    defines = [
        "INTERRUPT_HANDLER=rom_interrupt_handler",
    ],
    target_compatible_with = [PAVONA_CPU],
    deps = [
        "//sw/device/lib/base:csr",
        "//sw/device/lib/base:macros",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib:shutdown",
    ],
)

cc_library(
    name = "sigverify_otp_keys",
    srcs = ["sigverify_otp_keys.c"],
    hdrs = ["sigverify_otp_keys.h"],
    defines = pavona_select_top(
        {
            "egret": ["DISCRETE_OTP_MMAP"],
            "dragonfly": ["INTEGRATED_OTP_MMAP"],
        },
        ["DISCRETE_OTP_MMAP"],
    ),
    deps = [
        ":sigverify_key_types",
        "//hw/top:otp_ctrl_c_regs",
        "//hw/top/dt",
        "//sw/device/lib/base:macros",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib/drivers:hmac",
        "//sw/device/silicon_creator/lib/drivers:lifecycle",
        "//sw/device/silicon_creator/lib/drivers:otp",
        "//sw/device/silicon_creator/lib/drivers:rnd",
    ],
)

cc_library(
    name = "sigverify_key_types",
    hdrs = ["sigverify_key_types.h"],
    defines = pavona_select_top(
        {
            "dragonfly": ["OTP_KEY_ROLE"],
        },
        [],
    ),
    deps = [
        "//sw/device/silicon_creator/lib/sigverify:ecdsa_p256_key",
        "//sw/device/silicon_creator/lib/sigverify:rsa_key",
        "//sw/device/silicon_creator/lib/sigverify:spx_key",
    ],
)

cc_library(
    name = "sigverify_keys_ecdsa_p256",
    srcs = [
        "sigverify_keys_ecdsa_p256.c",
    ],
    hdrs = [
        "sigverify_keys_ecdsa_p256.h",
    ],
    deps = [
        ":sigverify_key_types",
        ":sigverify_otp_keys",
        "//sw/device/lib/base:macros",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib/drivers:lifecycle",
        "//sw/device/silicon_creator/lib/sigverify",
        "//sw/device/silicon_creator/lib/sigverify:ecdsa_p256_key",
    ],
)

cc_library(
    name = "sigverify_keys_spx",
    srcs = [
        "sigverify_keys_spx.c",
    ],
    hdrs = [
        "sigverify_keys_spx.h",
    ],
    deps = [
        ":sigverify_key_types",
        ":sigverify_otp_keys",
        "//hw/top:otp_ctrl_c_regs",
        "//sw/device/lib/base:macros",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib/drivers:lifecycle",
        "//sw/device/silicon_creator/lib/sigverify",
        "//sw/device/silicon_creator/lib/sigverify:spx_key",
    ],
)

cc_library(
    name = "rom_cfi",
    srcs = ["rom_cfi.c"],
    hdrs = ["rom_cfi.h"],
    deps = [
        "//sw/device/silicon_creator/lib:cfi",
    ],
)

cc_library(
    name = "rom_epmp",
    srcs = [
        "rom_epmp.c",
        "rom_epmp_init.S",
    ],
    hdrs = ["rom_epmp.h"],
    defines = pavona_if_ip(
        "flash_ctrl",
        ["HAS_FLASH_CTRL"],
        [],
    ) + pavona_select_top(
        {
            "egret": ["PAVONA_IS_EGRET"],
            "dragonfly": [
                "PAVONA_IS_DRAGONFLY",
                "HAS_ROM_CTRL1",
            ],
        },
        [],
    ),
    target_compatible_with = [PAVONA_CPU],
    deps = [
        "//hw/top/dt:rom_ctrl",
        "//hw/top/dt:sram_ctrl",
        "//sw/device/lib/base:bitfield",
        "//sw/device/lib/base:csr",
        "//sw/device/lib/base:memory",
        "//sw/device/silicon_creator/lib:epmp_state",
        "//sw/device/silicon_creator/lib/drivers:epmp",
        "//sw/device/silicon_creator/lib/drivers:lifecycle",
    ] + pavona_if_ip(
        "flash_ctrl",
        ["//hw/top/dt:flash_ctrl"],
        ["//hw/top/dt:soc_proxy"],
    ) + pavona_select_top(
        {
            "egret": ["//hw/top_egret/sw/autogen:top_egret"],
            "dragonfly": ["//hw/top_dragonfly/sw/autogen:top_dragonfly"],
        },
        [],
    ),
)

cc_library(
    name = "rom_state",
    srcs = ["rom_state.c"],
    hdrs = ["rom_state.h"],
    target_compatible_with = [PAVONA_CPU],
    deps = [
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:macros",
        "//sw/device/silicon_creator/lib:cfi",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib:shutdown",
    ],
    alwayslink = True,
)

cc_library(
    name = "rom_lib",
    srcs = [
        "rom.c",
        "rom.h",
        "rom_start.S",
    ],
    defines = pavona_if_ip(
        "flash_ctrl",
        ["HAS_FLASH_CTRL"],
        [],
    ) + pavona_if_ip(
        "sensor_ctrl",
        ["HAS_SENSOR_CTRL"],
        [],
    ) + pavona_select_top(
        {
            "egret": ["DISCRETE_OTP_MAP"],
            "dragonfly": [
                "INTEGRATED_OTP_MAP",
                "HAS_ROM_CTRL1",
            ],
        },
        [],
    ),
    target_compatible_with = [PAVONA_CPU],
    deps = [
        ":bootstrap",
        ":rom_cfi",
        ":rom_epmp",
        ":rom_state",
        "//hw/top:csrng_c_regs",
        "//hw/top:edn_c_regs",
        "//hw/top:otp_ctrl_c_regs",
        "//hw/top:rstmgr_c_regs",
        "//hw/top/dt:rom_ctrl",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base:bitfield",
        "//sw/device/lib/base:csr",
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:macros",
        "//sw/device/lib/base:memory",
        "//sw/device/lib/base:multibits",
        "//sw/device/lib/crt",
        "//sw/device/lib/runtime:hart",
        "//sw/device/silicon_creator/lib:boot_log",
        "//sw/device/silicon_creator/lib:chip_info",
        "//sw/device/silicon_creator/lib:epmp_state",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib:irq_asm",
        "//sw/device/silicon_creator/lib:manifest",
        "//sw/device/silicon_creator/lib:shutdown",
        "//sw/device/silicon_creator/lib/base:chip",
        "//sw/device/silicon_creator/lib/base:sec_mmio",
        "//sw/device/silicon_creator/lib/base:static_critical",
        "//sw/device/silicon_creator/lib/base:util",
        "//sw/device/silicon_creator/lib/drivers:ast",
        "//sw/device/silicon_creator/lib/drivers:epmp",
        "//sw/device/silicon_creator/lib/drivers:lifecycle",
        "//sw/device/silicon_creator/lib/drivers:otp",
        "//sw/device/silicon_creator/lib/drivers:pinmux",
        "//sw/device/silicon_creator/lib/drivers:pwrmgr",
        "//sw/device/silicon_creator/lib/drivers:retention_sram",
        "//sw/device/silicon_creator/lib/drivers:rnd",
        "//sw/device/silicon_creator/lib/drivers:rstmgr",
        "//sw/device/silicon_creator/lib/drivers:uart",
        "//sw/device/silicon_creator/lib/drivers:watchdog",
        "@rom_hooks",
    ] + pavona_if_ip(
        "flash_ctrl",
        ["//sw/device/silicon_creator/lib/drivers:flash_ctrl"],
        [],
    ) + pavona_if_ip(
        "sensor_ctrl",
        [
            "//hw/top:sensor_ctrl_c_regs",
            "//sw/device/silicon_creator/lib/drivers:sensor_ctrl",
        ],
        [],
    ) + pavona_select_top(
        {
            "egret": [":boot_rom_ext"],
            "dragonfly": [":boot_second_rom"],
        },
        [],
    ),
    alwayslink = True,
)

[
    # Generate targets with `sim_dv` and `sim_verilator` suffixes as expected
    # by dvsim.
    alias(
        name = "rom_{}".format(env),
        actual = ":rom",
    )
    for env in [
        "sim_dv",
        "sim_verilator",
    ]
]

ld_library(
    name = "rom_common",
    includes = ["rom_common.ld"],
    deps = ["//sw/device:info_sections"],
)

ld_library(
    name = "rom_single_stage",
    script = "rom_single_stage.ld",
    deps = [
        ":rom_common",
        "//hw/top:top_memory_ld",
    ],
)

ld_library(
    name = "rom_dual_stage",
    script = "rom_dual_stage.ld",
    deps = [
        ":rom_common",
        "//hw/top:top_memory_ld",
    ],
)

pavona_binary(
    name = "rom",
    collect_code_coverage = 0,
    exec_env = [
        "//hw/top_egret:fpga_cw310",
        "//hw/top_egret:fpga_cw340",
        "//hw/top_egret:sim_dv_base",
        "//hw/top_egret:sim_verilator_base",
        "//hw/top_egret:sim_qemu_base",
        "//hw/top_egret:silicon_creator",
        "//hw/top_dragonfly:sim_dv_base",
        "//hw/top_dragonfly:sim_verilator_base",
    ],
    kind = "rom",
    linker_script = pavona_select_top(
        {
            "egret": ":rom_single_stage",
            "dragonfly": ":rom_dual_stage",
        },
        ":rom_single_stage_ld",
    ),
    transitive_features = [
        "use_lld",
        "lto",
        "minsize",
    ],
    deps = [
        ":rom_lib",
        # We depend on rom_isrs here rather than in rom_lib so that the
        # `rom_exception_handler` symbol remains unresolved and can be supplied
        # by tests such as `rom_epmp_test`.
        ":rom_isrs",
    ],
)

# Create the legacy ROM target names so that existing splicing rules can find
# the rom VMEM files.
legacy_rom_targets(
    suffixes = {
        "fpga_cw310": ["//hw/top_egret:fpga_cw310"],
        "fpga_cw340": ["//hw/top_egret:fpga_cw340"],
    },
    target = "rom",
)

[
    filegroup(
        name = "rom_{}_hashfile".format(dev),
        testonly = True,
        srcs = [":rom"],
        output_group = "{}_hashfile".format(dev),
    )
    for dev in [
        "fpga_cw310",
        "fpga_cw340",
        "silicon_creator",
    ]
]

pavona_test(
    name = "rom_epmp_test",
    srcs = [
        "rom_epmp_test.c",
    ],
    # This test doesn't use the OTTF and can only run in verilator right now.
    #
    # This test is designed to run and complete entirely in the ROM boot stage.
    # Setting `kind = "rom"` makes the `pavona_test` rule aware
    # of this, and instructs it to load the test image into ROM (rather than
    # loading the default test ROM, or any other ROM that may be specified via
    # Verilator or CW310 params).
    exec_env = {
        "//hw/top_egret:sim_verilator": None,
        "//hw/top_dragonfly:sim_verilator": None,
    },
    kind = "rom",
    linker_script = pavona_select_top(
        {
            "egret": ":rom_single_stage",
            "dragonfly": ":rom_dual_stage",
        },
        ":rom_single_stage_ld",
    ),
    linkopts = [
        "-Wl,--defsym=rom_test=1",
    ],
    deps = [
        ":rom_epmp",
        "//hw/top/dt",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base:abs_mmio",
        "//sw/device/lib/base:bitfield",
        "//sw/device/lib/base:csr",
        "//sw/device/lib/base:macros",
        "//sw/device/lib/crt",
        "//sw/device/lib/dif:pinmux",
        "//sw/device/lib/dif:sram_ctrl",
        "//sw/device/lib/runtime:hart",
        "//sw/device/lib/runtime:ibex",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/runtime:print",
        "//sw/device/lib/testing:pinmux_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:status",
        "//sw/device/silicon_creator/lib:epmp_state",
        "//sw/device/silicon_creator/lib:epmp_test_unlock",
        "//sw/device/silicon_creator/lib:irq_asm",
        "//sw/device/silicon_creator/lib/base:chip",
        "//sw/device/silicon_creator/lib/base:sec_mmio",
        "//sw/device/silicon_creator/lib/base:static_critical",
        "//sw/device/silicon_creator/lib/drivers:uart",
    ] + pavona_if_ip(
        "flash_ctrl",
        [
            "//hw/top:flash_ctrl_c_regs",
            "//sw/device/silicon_creator/lib/drivers:flash_ctrl",
        ],
        [],
    ) + pavona_if_ip(
        "soc_proxy",
        ["//hw/top:soc_proxy_c_regs"],
        [],
    ),
)

filegroup(
    name = "scafi_deprecated_test_rom_bootstrap_srcs",
    srcs = [
        "bootstrap.c",
        "bootstrap.h",
        "//sw/device/silicon_creator/lib:bootstrap_srcs",
    ],
)

output_groups(
    name = "pre_package",
    testonly = True,
    srcs = [":rom"],
    groups = [
        "sim_dv_elf",
        "sim_dv_rom",
        "sim_dv_logs",
        "sim_dv_mapfile",
        "sim_verilator_elf",
        "sim_verilator_rom",
        "sim_verilator_mapfile",
    ] + pavona_select_top(
        {
            "egret": [
                "fpga_cw310_binary",
                "fpga_cw310_elf",
                "fpga_cw310_rom",
                "fpga_cw310_mapfile",
                "fpga_cw340_binary",
                "fpga_cw340_elf",
                "fpga_cw340_rom",
                "fpga_cw340_mapfile",
                "silicon_creator_binary",
                "silicon_creator_elf",
                "silicon_creator_rom",
                "silicon_creator_mapfile",
            ],
            "dragonfly": [],
        },
        [],
    ),
)

pkg_files(
    name = "package",
    testonly = True,
    srcs = [":pre_package"],
    prefix = "rom",
)

pavona_manual_test(
    name = "manual_test",
    tags = [
        "manual",
        "no-cache",
    ],
    testplan = "//sw/device/silicon_creator/rom/data:rom_manual_testplan.hjson",
)

output_groups(
    name = "rom_binaries",
    srcs = [":rom"],
    groups = [
        "sim_dv_binary",
        "sim_verilator_binary",
    ] + pavona_select_top(
        {
            "egret": [
                "fpga_cw310_binary",
                "fpga_cw340_binary",
                "silicon_creator_binary",
            ],
            "dragonfly": [],
        },
        [],
    ),
)

output_groups(
    name = "rom_disassembly",
    srcs = [":rom"],
    groups = [
        "sim_dv_disassembly",
        "sim_verilator_disassembly",
    ] + pavona_select_top(
        {
            "egret": [
                "fpga_cw310_disassembly",
                "fpga_cw340_disassembly",
                "silicon_creator_disassembly",
            ],
            "dragonfly": [],
        },
        [],
    ),
)

genrule(
    name = "rom_hashes",
    testonly = True,
    srcs = [
        ":rom_binaries",
    ],
    outs = ["rom_hashes.txt"],
    cmd = """
        echo "SHA256 of rom with real keys" > $@
    for f in $(locations :rom_binaries); do
        if [[ "$$f" == *bin ]]; then
            name=$$(basename $$f)
        echo $$f >> $@
        size=$$(stat -L -c %s $$f)
        full=$$(sha256sum $$f | cut -f1 -d' ')
        without_chip_info=$$(head -c -12 $$f | sha256sum | cut -f1 -d' ')
        code=$$(echo $$without_chip_info | sed -E s'/(.{8})(.{8})(.{8})(.{8})(.{8})(.{8})(.{8})(.{8})/0x\\8,0x\\7,0x\\6,0x\\5,0x\\4,0x\\3,0x\\2,0x\\1,/g')

        echo "              size: $$size" >> $@
        echo "     complete hash: $$full" >> $@
        echo " without chip_info: $$without_chip_info" >> $@
        echo "w/o chip_info le32: $$code" >> $@
        echo >> $@
        fi
    done
    """,
)

genrule(
    name = "empty_flash",
    testonly = True,
    outs = ["empty_flash.bin"],
    cmd = """
        head --bytes=65536 /dev/zero | tr '\\0' '\\377' > $@
    """,
)

pavona_test(
    name = "stack_utilization_test",
    cw310 = fpga_params(
        binaries = {
            "//sw/device/silicon_creator/rom/e2e:empty_test_slot_a_fake_ecdsa_prod_key_0_fpga_cw310_rom_with_fake_keys_signed_bin": "good_a",
            "//sw/device/silicon_creator/rom/e2e:empty_test_slot_b_fake_ecdsa_prod_key_0_fpga_cw310_rom_with_fake_keys_signed_bin": "good_b",
            "//sw/device/silicon_creator/rom/e2e:empty_test_slot_a_fake_ecdsa_prod_key_0_corrupted_fpga_cw310_rom_with_fake_keys_signed_bin": "bad_a",
            ":empty_flash": "empty",
        },
        stack_usage = "STK:[0-9A-Fa-f/]+\r\n",
        tags = ["manual"],
        test_cmd = """
            --exec="no-op --info '
            ###########################################################################
            # This is a manual test.  Run it with:
            #     --test_output=streamed --copt=-DSTACK_UTILIZATION_CHECK
            ###########################################################################'"
            --exec="transport init"
            --exec="fpga load-bitstream {bitstream}"

            --exec="no-op --info '### Measuring stack utilization for bootstrap slot A'"
            --exec="bootstrap --clear-uart=true --leave-in-bootstrap {good_a}"
            --exec="console --non-interactive --exit-success='{stack_usage}' --exit-failure='{exit_failure}'"

            --exec="gpio remove ROM_BOOTSTRAP"
            --exec="gpio apply RESET"
            --exec="gpio remove RESET"
            --exec="no-op --info '### Measuring stack utilization for booting slot A'"
            --exec="console --non-interactive --exit-success='PASS.*\r\n' --exit-failure='{exit_failure}'"

            --exec="no-op --info '### Measuring stack utilization for bootstrap slot B'"
            --exec="bootstrap --mirror=false --clear-uart=true --leave-in-bootstrap {good_b}@{rom_ext_slot_b}"
            --exec="console --non-interactive --exit-success='{stack_usage}' --exit-failure='{exit_failure}'"

            --exec="gpio remove ROM_BOOTSTRAP"
            --exec="gpio apply RESET"
            --exec="gpio remove RESET"
            --exec="no-op --info '### Measuring stack utilization for booting slot A'"
            --exec="console --non-interactive --exit-success='PASS.*\r\n' --exit-failure='{exit_failure}'"

            --exec="no-op --info '### Measuring stack utilization for bootstrap slot A (corrupted image)'"
            --exec="bootstrap --clear-uart=true --leave-in-bootstrap {bad_a}"
            --exec="console --non-interactive --exit-success='{stack_usage}' --exit-failure='{exit_failure}'"

            --exec="gpio remove ROM_BOOTSTRAP"
            --exec="gpio apply RESET"
            --exec="gpio remove RESET"
            --exec="no-op --info '### Measuring stack utilization for failed boot of slot A'"
            --exec="console --non-interactive --exit-success='{stack_usage}' --exit-failure='PASS|FAIL'"

            --exec="no-op --info '### Measuring stack utilization for bootstrap slot A (empty image)'"
            --exec="bootstrap --clear-uart=true --leave-in-bootstrap {empty}"
            --exec="console --non-interactive --exit-success='{stack_usage}' --exit-failure='{exit_failure}'"

            --exec="gpio remove ROM_BOOTSTRAP"
            --exec="gpio apply RESET"
            --exec="gpio remove RESET"
            --exec="no-op --info '### Measuring stack utilization for empty flash'"
            --exec="console --non-interactive --exit-success='{stack_usage}' --exit-failure='PASS|FAIL'"
            no-op
        """,
    ),
    exec_env = {
        "//hw/top_egret:fpga_cw310_rom_with_fake_keys": None,
    },
)
