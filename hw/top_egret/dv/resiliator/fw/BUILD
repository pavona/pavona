
load("//rules:linker.bzl", "ld_library")
load("//rules/pavona:cc.bzl", "pavona_binary")

package(default_visibility = ["//visibility:public"])

ld_library(
    name = "resiliator_fw_ld",
    script = "resiliator_fw.ld",
    deps = ["//sw/device:info_sections"],
)

# Build branchless and branching handling of the authentication result for
# comparison. The campaign uses the branchless variant. -O0 preserves the
# comparison's stack accesses.
# Use Egret's toolchain settings with the testbench's linker script.
[
    pavona_binary(
        name = "auth_check_" + variant,
        srcs = [
            "auth_check.c",
            "start.S",
            "//hw:resiliator_firmware_hdrs",
        ],
        copts = ["-O0", "-DVERDICT_" + variant.upper()],
        exec_env = ["//hw/top_egret:sim_verilator_base"],
        kind = "ram",
        linker_script = ":resiliator_fw_ld",
        deps = ["//sw/device/lib/crt"],
    )
    for variant in [
        "branchless",
        "branch",
    ]
]

# Raw firmware images linked at address zero.
[
    filegroup(
        name = "auth_check_" + variant + "_bin",
        srcs = [":auth_check_" + variant],
        output_group = "sim_verilator_binary",
    )
    for variant in [
        "branchless",
        "branch",
    ]
]

# Convert binaries to $readmemh images, loaded via +firmware=.
[
    genrule(
        name = "auth_check_" + variant + "_hex",
        srcs = [
            ":auth_check_" + variant + "_bin",
            "//hw:resiliator_makehex",
        ],
        outs = ["auth_check_" + variant + ".hex"],
        cmd = ("python3 $(location //hw:resiliator_makehex) " +
               "$(location :auth_check_" + variant + "_bin) > $@"),
    )
    for variant in [
        "branchless",
        "branch",
    ]
]

# Default firmware for the campaign.
alias(
    name = "auth_check_hex",
    actual = ":auth_check_branchless_hex",
)
