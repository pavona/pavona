#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Checks the coutermeasures for a given top from its hjson file.

set -e

cleanup () {
  git restore .
  git clean -df .
}

if [ $# != 1 ]; then
    echo >&2 "Usage: check-countermeasures.sh <toplevel-name>"
    exit 1
fi
hjson_file="hw/top_$1/data/autogen/top_$1.gen.hjson"
if [ ! -f ${hjson_file} ]; then
    echo >&2 "Missing hjson file for $1: expected file ${hjson_file} not found."
    echo >&2 "  For example, use \"egret\" for top_egret.hjson."
    exit 1
fi

./util/top_cm_and_blocks.py -t ${hjson_file} check_cm || {
    echo "::error::Countermeasure check failed."
    cleanup
    exit 1
}

cleanup
