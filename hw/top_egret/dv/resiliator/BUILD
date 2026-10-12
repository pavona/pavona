load("//rules:fusesoc.bzl", "fusesoc_build")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "cores",
    srcs = ["ibex_resiliator.core"],
)

filegroup(
    name = "rtl_files",
    srcs = ["ibex_resiliator_top.sv"],
)

filegroup(
    name = "lint_files",
    srcs = ["ibex_resiliator_waivers.vlt"],
)

# Stage DV files explicitly because //hw:rtl_files excludes **/dv/**.
filegroup(
    name = "all_files",
    srcs = [
        ":cores",
        ":lint_files",
        ":rtl_files",
    ],
)

# Fault-injection model built with Resiliator's Verilator fork.
fusesoc_build(
    name = "verilator_resiliator_ibex",
    srcs = [
        ":all_files",
        "//hw:rtl_files",
        "//hw:verilator_files",
    ],
    cores = ["//hw:cores"],
    make_options = "//hw:make_options",
    output_groups = {
        "binary": [
            "lowrisc_dv_ibex_resiliator_0.1/sim-verilator/Vibex_resiliator_top",
        ],
    },
    systems = ["lowrisc:dv:ibex_resiliator"],
    tags = [
        "manual",
        "resiliator",
        "verilator",
    ],
    target = "sim",
    verilator = "//third_party/resiliator:verilator",
    verilator_install = "//third_party/resiliator:verilator_install",
    # Use the core's --threads 1 instead of //hw:verilator_options.
)

filegroup(
    name = "sim_binary",
    srcs = [":verilator_resiliator_ibex"],
    output_group = "binary",
    tags = [
        "manual",
        "resiliator",
        "verilator",
    ],
)
