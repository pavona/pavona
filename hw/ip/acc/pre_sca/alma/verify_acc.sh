#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Script to formally verify the masking of the ACC using Alma.

echo "Verifying ACC using Alma"

# Parse
python3 parse.py --keep --top-module acc_top_coco --log-yosys \
  --source ${REPO_TOP}/hw/ip/acc/pre_sca/alma/rtl/ram_1p.v \
  ${REPO_TOP}/hw/ip/acc/pre_syn/syn_out/latest/generated/acc_core.alma.v \
  ${REPO_TOP}/hw/ip/acc/pre_sca/alma/rtl/acc_top_coco.v

# Assemble the program
program=isw_and
cd examples/acc || exit
python3 assemble.py --program programs/${program}.S \
  --netlist ../../tmp/circuit.v
cd ../../ || exit

# Trace
python3 trace.py --testbench tmp/verilator_tb.c \
  --netlist tmp/circuit.v \
  --c-compiler gcc \
  --make-jobs 16

# Generate bignum register file labels
examples/acc/labels/generate_bignum_rf_labels.py \
  -i examples/acc/labels/${program}_labels.txt \
  -o tmp/labels_updated.txt -w 1 -s 0

# Verify
python3 verify.py --json tmp/circuit.json \
  --top-module acc_top_coco \
  --label tmp/labels_updated.txt \
  --vcd tmp/circuit.vcd \
  --checking-mode per-location \
  --rst-name rst_sys_n \
  --rst-phase 0 \
  --rst-cycles 2 \
  --init-delay 139 \
  --excluded-signals u_acc_core.u_acc_controller.rf_bignum_intg_err_i[0] \
  --dbg-signals acc_cycle_cnt_o \
  --cycles 25 \
  --mode stable
