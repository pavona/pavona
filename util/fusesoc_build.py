#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
r"""Command-line tool to add the calling interpreter to fusesoc's PATH, so it
is used for generators.
"""


import os
import sys
from fusesoc.main import main

if __name__ == "__main__":
    # First, ensure the calling interpreter is on the PATH first, so any
    # generators asking /usr/bin/env for python3 will use the same version.
    path_env = os.environ["PATH"]
    if path_env is not None:
        path_env = ":" + path_env
    path_env = os.path.dirname(sys.executable) + path_env

    # VERILATOR_BINARY` is passed in as a relative path to the Bazel
    # `execroot`. Convert this to an absolute path in PATH, if present.
    if "VERILATOR_BINARY" in os.environ:
        verilator_binary = os.environ["VERILATOR_BINARY"]
        verilator_dirname = os.path.dirname(os.path.join(os.getcwd(), verilator_binary))
        path_env += os.pathsep + verilator_dirname
    os.environ["PATH"] = path_env

    # Start fusesoc
    rc = main()
    sys.exit(rc)
