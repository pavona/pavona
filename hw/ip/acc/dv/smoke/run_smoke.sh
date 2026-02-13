#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Runs the ACC smoke test (builds software, build simulation, runs simulation
# and checks expected output)

fail() {
    echo >&2 "ACC SMOKE FAILURE: $*"
    exit 1
}

set -o pipefail
set -e

SCRIPT_DIR="$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"
UTIL_DIR="$(readlink -e "$SCRIPT_DIR/../../../../../util")" || \
  fail "Can't find OpenTitan util dir"

source "$UTIL_DIR/build_consts.sh"

SMOKE_BIN_DIR=$BIN_DIR/acc/smoke_test
SMOKE_SRC_DIR=$REPO_TOP/hw/ip/acc/dv/smoke

mkdir -p $SMOKE_BIN_DIR

ACC_UTIL=$REPO_TOP/hw/ip/acc/util

$ACC_UTIL/acc_as.py -o $SMOKE_BIN_DIR/smoke_test.o $SMOKE_SRC_DIR/smoke_test.s || \
    fail "Failed to assemble smoke_test.s"
$ACC_UTIL/acc_ld.py -o $SMOKE_BIN_DIR/smoke.elf $SMOKE_BIN_DIR/smoke_test.o || \
    fail "Failed to link smoke_test.o"

(cd $REPO_TOP;
 fusesoc --cores-root=. run --target=sim --setup --build \
    --mapping=lowrisc:prim_generic:all:0.1 lowrisc:ip:acc_top_sim \
    --make_options="-j$(nproc)" || fail "HW Sim build failed")

RUN_LOG=`mktemp`
readonly RUN_LOG
# shellcheck disable=SC2064 # The RUN_LOG tempfile path should not change
trap "rm -rf $RUN_LOG" EXIT

timeout 5s \
  $REPO_TOP/build/lowrisc_ip_acc_top_sim_0.1/sim-verilator/Vacc_top_sim \
  --load-elf=$SMOKE_BIN_DIR/smoke.elf -t | tee $RUN_LOG

if [ $? -eq 124 ]; then
  fail "Simulation timeout"
fi

if [ $? -ne 0 ]; then
  fail "Simulator run failed"
fi

had_diff=0
grep -A 74 "Call Stack:" $RUN_LOG | diff -U3 $SMOKE_SRC_DIR/smoke_expected.txt - || had_diff=1

if [ $had_diff == 0 ]; then
  echo "ACC SMOKE PASS"
else
  fail "Simulator output does not match expected output"
fi
