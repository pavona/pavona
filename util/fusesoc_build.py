#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
r"""Command-line tool to add the calling interpreter to fusesoc's PATH, so it
is used for generators.
"""


import argparse
import os
import sys
from fusesoc.main import main
from pathlib import Path

if __name__ == "__main__":
    # First, ensure the calling interpreter is on the PATH first, so any
    # generators asking /usr/bin/env for python3 will use the same version.
    path_env = os.environ["PATH"] if "PATH" in os.environ else ""
    if path_env is not None:
        path_env = ":" + path_env
    path_env = os.path.dirname(sys.executable) + path_env

    cwd = os.getcwd()
    # `VERILATOR_CXX` is passed in as a relative path to the Bazel
    # `execroot`. Convert this to an absolute path in --make_options, if present.
    parser = argparse.ArgumentParser()
    parser.add_argument('--make_options', type=str, default = "")
    args, others = parser.parse_known_args()
    make_options = args.make_options
    # Modify the --make_options to include the `VERILATOR_CXX` path as the
    # C/C++ compiler.
    #
    # Use LLVM libc++ as the C++ standard library, and prevent clang from
    # searching for the host `libstdc++`.
    cxxflags = ["-stdlib=libc++"]
    ldflags = [
        "-fuse-ld=lld",
        "-static",
        "-stdlib=libc++",
        "-lc++abi",
        "-lzstd",
    ]
    if "VERILATOR_AR" in os.environ:
        verilator_ar = os.environ["VERILATOR_AR"]
        verilator_ar_abs = os.path.join(cwd, verilator_ar)
        make_options += " AR=" + verilator_ar_abs
    if "VERILATOR_CC" in os.environ:
        verilator_cc = os.environ["VERILATOR_CC"]
        verilator_cc_abs = os.path.join(cwd, verilator_cc)
        make_options += " CC=" + verilator_cc_abs
    if "VERILATOR_CXX" in os.environ:
        verilator_cxx = os.environ["VERILATOR_CXX"]
        verilator_cxx_abs = os.path.join(cwd, verilator_cxx)
        make_options += " CXX={path} LINK={path}".format(path=verilator_cxx_abs)
    if "VERILATOR_LIBCXX" in os.environ:
        verilator_libcxx = os.environ["VERILATOR_LIBCXX"]
        verilator_libcxx_abs = str(Path(
            os.path.join(cwd, verilator_libcxx),
        ).parent)
        cxxflags += [
            # Specify library paths for libc++.
            "-L" + verilator_libcxx_abs,
        ]
        ldflags += [
            "-Wl,-rpath," + verilator_libcxx_abs,
        ]
    if "VERILATOR_INCLUDE" in os.environ:
        # A path to a specific header is passed in. Get the great-grandparent
        # directory containing all the headers.
        verilator_include = os.environ["VERILATOR_INCLUDE"]
        verilator_include_abs = str(Path(
            os.path.join(cwd, verilator_include),
        ).parents[3])
        cxxflags += [
            # Specify include paths for libc/libc++.
            "-I" + verilator_include_abs,
        ]
    make_options += " CXXFLAGS='{}'".format(" ".join(cxxflags))
    make_options += " LDFLAGS='{}'".format(" ".join(ldflags))

    # `VERILATOR_BINARY` is passed in as a relative path to the Bazel
    # `execroot`. Convert this to an absolute path in PATH, if present.
    if "VERILATOR_BINARY" in os.environ:
        verilator_binary = os.environ["VERILATOR_BINARY"]
        verilator_dirname = os.path.dirname(os.path.join(cwd, verilator_binary))
        path_env += os.pathsep + verilator_dirname
        # If running verilator, include make options.
        sys.argv = others + ["--make_options=" + make_options]
    os.environ["PATH"] = path_env

    # Start fusesoc
    rc = main()
    sys.exit(rc)
