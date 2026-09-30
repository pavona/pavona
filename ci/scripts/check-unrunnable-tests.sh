#!/bin/bash

# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set -eo pipefail

# Look for all tests that are incompatible with host under every top,
# i.e. unrunnable. A test declared for another top is incompatible under
# this top by design.
# The cquery will output an empty string for compatible tests and
# a non-empty string (test name) for the incompatible ones. Therefore
# we filter out the empty lines.
tmp="$(mktemp -d)"
for top in egret dragonfly; do
    ./bazelisk.sh cquery 'tests(//...)' \
        --noinclude_aspects \
        --define DISABLE_VERILATOR_BUILD=true \
        "--//hw/top=${top}" \
        --output=starlark \
        --starlark:file=ci/scripts/incompatible_targets.cquery \
        | sed '/^$/d' | sort > "${tmp}/${top}.txt"
done
comm -12 "${tmp}/egret.txt" "${tmp}/dragonfly.txt" > "${tmp}/output.txt"
if [ -s "${tmp}/output.txt" ]; then
    echo "The following tests are incompatible with the host platform under every top:"
    cat "${tmp}/output.txt"
    exit 1
fi
