#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
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
ROOT_DIR="$(readlink -e "$SCRIPT_DIR/../../../../..")" || \
  fail "Can't find repository root dir"
UTIL_DIR="$(readlink -e "$ROOT_DIR/util")" || \
  fail "Can't find repository util dir"

source "$UTIL_DIR/build_consts.sh"

SMOKE_SRC_DIR=$ROOT_DIR/hw/ip/acc/dv/smoke_pqc

(cd $ROOT_DIR;
 fusesoc --cores-root=. run --target=sim --flag pqc --setup --build \
    --mapping=lowrisc:prim_generic:all:0.1 lowrisc:ip:acc_top_sim \
    --make_options="-j$(nproc)" || fail "HW Sim build failed")

./bazelisk.sh build //hw/ip/acc/dv/smoke_pqc:smoke_test
SMOKE_ELF=$(./bazelisk.sh cquery --output=files //hw/ip/acc/dv/smoke_pqc:smoke_test | grep "\\.elf$" | head -1)

RUN_LOG=`mktemp`
readonly RUN_LOG
# shellcheck disable=SC2064 # The RUN_LOG tempfile path should not change
trap "rm -rf $RUN_LOG" EXIT

timeout 5s \
  $ROOT_DIR/build/lowrisc_ip_acc_top_sim_0.1/sim-verilator/Vacc_top_sim \
  --load-elf=$SMOKE_ELF -t | tee $RUN_LOG

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
