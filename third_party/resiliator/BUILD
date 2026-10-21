# Build the Verilator fork with autoconf; its CMake build omits Resiliator.o.

load("@rules_foreign_cc//foreign_cc:configure.bzl", "configure_make")

exports_files(["BUILD.resiliator.bazel"])

configure_make(
    name = "build_verilator",
    # Use the available CPUs to compile the fork.
    args = [
        "-j",
        "`nproc`",
    ],
    autoconf = True,
    configure_in_place = True,
    # Disable host ccache detection in configure.ac.
    env = {"ac_cv_prog_OBJCACHE": ""},
    lib_source = "@verilator_resiliator//:all_srcs",
    out_binaries = [
        "verilator",
        "verilator_bin",
        "verilator_bin_dbg",
        "verilator_coverage",
        "verilator_coverage_bin_dbg",
        "verilator_gantt",
        "verilator_profcfunc",
    ],
    out_data_dirs = ["share"],
)

# Expose the Verilator executable from the build's output group.
filegroup(
    name = "verilator",
    srcs = [":build_verilator"],
    output_group = "verilator",
    visibility = ["//visibility:public"],
)

filegroup(
    name = "verilator_install",
    srcs = [":build_verilator"],
    visibility = ["//visibility:public"],
)
