#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set -e

set -x
set -e

. util/build_consts.sh

if [ $# == 0 ]; then
    echo >&2 "Usage: run-verilator-tests.sh <top> <target_pattern_file> [bazel options...]"
    echo >&2 "E.g. ./run-verilator-tests.sh earlgrey list_of_tests.txt --cache_test_results=no"
    exit 1
fi
top="$1"
target_pattern_file="$2"
shift 2

# Increase the test_timeout due to slow performance on CI

./bazelisk.sh test \
    --//hw/top=${top} \
    --build_tests_only=true \
    --test_timeout=2400,2400,4000,-1 \
    --local_test_jobs=8 \
    --local_resources=cpu=8 \
    --test_tag_filters=verilator,-broken,-skip_in_ci \
    --test_output=errors \
    --//hw:verilator_options=--threads,1 \
    --//hw:make_options=-j,8 \
    --target_pattern_file="${target_pattern_file}" "$@"
