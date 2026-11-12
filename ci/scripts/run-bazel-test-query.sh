#!/usr/bin/env bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Usage:
# run-bazel-test-query.sh <out_file> <test_tag_filters> <targets...>
#
# This script will perform a bazel query to include all tests specified
# by the <targets...> but filtered according to the <test_tag_filters>
# using the same filter logic as bazel's --test_tag_filters. The resulting
# list of targets in placed in <out_file>

set -x
set -e

if [ $# -lt 4 ]; then
    echo >&2 "Usage: ./run-bazel-test-query.sh <out_file> <test_tag_filters> <test_timeout_filters> targets...>"
    echo >&2 "E.g. ./run-bazel-test-query.sh all_tests.txt cw310_rom_tests,-manuf short,moderate //..."
    exit 1
fi
out_file="$1"
test_tags="$2"
test_timeouts="$3"
shift
shift
shift

# Parse the tag filters and separate the positive from the negative ones
declare -a positive_tags
declare -a negative_tags
IFS=',' read -ra tag_array <<< "$test_tags"
for tag in "${tag_array[@]}"; do
    if [ "${tag:0:1}" == "-" ]; then
        negative_tags+=( "${tag:1}" )
    else
        positive_tags+=( "$tag" )
    fi
done

# Parse the timeout filters and separate the positive from the negative ones
declare -a positive_timeouts
declare -a negative_timeouts
IFS=',' read -ra timeout_array <<< "$test_timeouts"
for timeout in "${timeout_array[@]}"; do
    if [ "${timeout:0:1}" == "-" ]; then
        negative_timeouts+=( "${timeout:1}" )
    else
        positive_timeouts+=( "$timeout" )
    fi
done
# Now build a regular expression to match all tests that contain at least one positive tag.
# Per the bazel query reference, when matching for attributes, the tags are converted to a
# string of the form "[tag_1, tag_2, ...]", so for example "[rom, manuf, broken]" (note the
# space after each comma). To make sure to match on entire tags, we look for the tag,
# preceded either by "[" or a space, and followed by "]" or a comma.
positive_tags_or=$(IFS="|"; echo "${positive_tags[*]}")
negative_tags_or=$(IFS="|"; echo "${negative_tags[*]}")
positive_regex="[\[ ](${positive_tags_or})[,\]]"
negative_regex="[\[ ](${negative_tags_or})[,\]]"

positive_timeouts_or=$(IFS="|"; echo "${positive_timeouts[*]}")
negative_timeouts_or=$(IFS="|"; echo "${negative_timeouts[*]}")
positive_timeout_regex="${positive_timeouts_or[*]}"
negative_timeout_regex="${negative_timeouts_or[*]}"

# List of targets
targets=$(IFS="|"; echo "$*")
targets="${targets/|/ union }"

tags_filter="attr(\"tags\", \"${positive_regex}\", tests($targets)) except attr(\"tags\", \"${negative_regex}\", tests($targets))"
timeouts_filter="attr(\"timeout\", \"${positive_timeout_regex}\", tests($targets))"
if [[ ${#negative_timeouts[@]} != 0 ]]; then
    timeouts_filter="${timeouts_filter} except attr(\"timeout\", \"${negative_timeout_regex}\", tests($targets))"
fi
combined_filter="(${tags_filter}) intersect (${timeouts_filter})"
# Finally build the bazel query
./bazelisk.sh query \
    --noimplicit_deps \
    --noinclude_aspects \
    --output=label \
    "${combined_filter}" \
    >"${out_file}"
