#!/usr/bin/env bash
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# # Usage
# section "section"
# .
# . main script
# .
# section_end

set -e

section() {
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "::group::$1"
    else
        echo -e "\n### $1"
    fi
}

section_end() {
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "::endgroup::"
    fi
}
