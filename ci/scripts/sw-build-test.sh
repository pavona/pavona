#!/usr/bin/env bash
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set -eoux pipefail

. util/build_consts.sh

if [ $# != 2 ]; then
    echo >&2 "Usage: sw-build-test.sh <top> <target>"
    echo >&2 "E.g. ./sw-build-test.sh earlgrey //..."
    exit 1
fi
top=$1
target=$2

target_pattern_file="$(mktemp)"
trap 'rm -f ${target_pattern_file}' EXIT

# Start with building the base target
echo "${target}" > "$target_pattern_file"

# Exclude some targets:
#
# 1. `//hw/...` is out of scope.
# 2. `//quality/...` is tested by the lint jobs.
# 3. `//sw/acc/crypto/...` is tested by the ACC job.
# 4. `//third_party/...` which is not our code.
printf "%s\n"              \
    "-//hw/..."            \
    "-//quality/..."       \
    "-//sw/acc/crypto/..." \
    "-//third_party/..."   \
    >> "$target_pattern_file"

# Exclude anything that requires a bitstream splice.
./bazelisk.sh cquery                                 \
    --noinclude_aspects                              \
    --output=starlark                                \
    --starlark:expr='"-{}".format(target.label)'     \
    --define DISABLE_VERILATOR_BUILD=true            \
    -- "rdeps(//..., kind(bitstream_splice, //...))" \
    >> "$target_pattern_file"

# Build everything we selected, excluding some tags.
./bazelisk.sh build                              \
    --//hw/top="${top}"                          \
    --build_tests_only=false                     \
    --define DISABLE_VERILATOR_BUILD=true        \
    --test_tag_filters=-broken,-verilator,-dv    \
    --target_pattern_file="$target_pattern_file"

# Run software unit tests.
./bazelisk.sh test                                     \
    --//hw/top="${top}"                                \
    --build_tests_only=false                           \
    --test_output=errors                               \
    --define DISABLE_VERILATOR_BUILD=true              \
    --test_tag_filters=-broken,-verilator,-dv,-silicon \
    --target_pattern_file="$target_pattern_file"
