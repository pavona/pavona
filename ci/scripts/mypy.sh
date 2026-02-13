#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Run mypy to do Python linting on code that uses it

set -e

dirs_with_lint_makefile=(
    hw/ip/acc/dv/rig
    hw/ip/acc/dv/accsim
    hw/ip/acc/util
    hw/ip/rom_ctrl/util
    util/reggen
)

retcode=0
for dir in "${dirs_with_lint_makefile[@]}"; do
    make -C "$dir" lint || {
        echo -n "::error::"
        echo "Failed mypy check in ${dir}."
        retcode=1
    }
done

exit $retcode
