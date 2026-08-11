#!/usr/bin/env bash
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Runs an ACC smoke test (runs the simulation and checks expected output). The
# wrapping sh_test passes the paths of everything this needs, relative to the
# runfiles directory.

fail() {
    echo >&2 "ACC SMOKE FAILURE: $*"
    exit 1
}

set -euo pipefail

SIM_BINARY=$1
SMOKE_ELF=$2
SMOKE_EXPECTED=$3
# Keep the ISS path inside the runfiles tree, so that the launcher finds the
# Python libraries it was built with.
export ACC_ISS=$PWD/$4

RUN_LOG=$TEST_TMPDIR/smoke.log

if ! "$SIM_BINARY" --load-elf="$SMOKE_ELF" -t | tee "$RUN_LOG"; then
  fail "Simulator run failed"
fi

# The expected output is the "Call Stack:" line and everything after it.
expected_lines=$(wc -l < "$SMOKE_EXPECTED")
if grep -A "$((expected_lines - 1))" "Call Stack:" "$RUN_LOG" \
  | diff -U3 "$SMOKE_EXPECTED" -; then
  echo "ACC SMOKE PASS"
else
  fail "Simulator output does not match expected output"
fi
