#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import sys
import reggen.gen_selfdoc as reggen_selfdoc
import tlgen
import topgen.selfdoc as topgen_selfdoc
from typing import TextIO
import subprocess
from cmdgen import REPO_ROOT


def generate_selfdocs(tool: str, fout: TextIO):
    """Generate documents for the tools in `util/`

    Each tool creates selfdoc differently. Manually invoked.
    """
    if tool == "reggen":
        reggen_selfdoc.document(fout)
    elif tool == "tlgen":
        fout.write(tlgen.selfdoc(heading=3, cmd='tlgen.py --doc'))
    elif tool == "topgen":
        topgen_selfdoc.document(fout)
    else:  # document tool stdout
        cmd_input = tool.removeprefix("quote:")
        format_as_code = tool.startswith("quote:")
        try:
            usage = subprocess.run(cmd_input.split(), capture_output=True, cwd=REPO_ROOT,
                                   check=True, timeout=180, encoding="utf-8")
            if format_as_code:
                fout.write("```\n" + f"$ {cmd_input}\n" + usage.stdout + "```")
            else:
                fout.write(usage.stdout)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            sys.exit(f"unable to get command line stdout for {cmd_input}")


if __name__ == "__main__":
    # running this file as standalone prints the documentation
    generate_selfdocs(" ".join(sys.argv[1:]), sys.stdout)
