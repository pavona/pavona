#!/usr/bin/env bash
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# # Usage
# before=$(snapshot)
# .
# . main script
# .
# if is_clean "$before"; then
#   exit 0
# else
#   exit 1
# fi

set -e

# Take a snapshot of the status of the repository in a reproducable way.
snapshot() {
  git status --porcelain | sort
}

# Returns 0 if the state of the tree is the same as before (passed as the first arguments).
# The function with return 1 if there are changes to the state of the tree.
# Show the diff on STDOUT if there is a deviation.
is_clean() {
  local before="$1"
  local after
  after=$(snapshot) || return 1
  if [[ "$before" != "$after" ]]; then
    echo Diff between the regenerated content and the content in this PR/the repository:
    # the || true is to mask diff's exit code when there is a mismatch
    diff -u <(printf '%s\n' "$before") <(printf '%s\n' "$after") || true
    git diff
    return 1
  fi

  return 0
}
