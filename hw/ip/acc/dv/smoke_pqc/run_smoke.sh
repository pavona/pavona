#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Runs the ACC smoke test (builds software, build simulation, runs simulation
# and checks expected output)

set -e

cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.."

exec ./bazelisk.sh test --test_output=errors \
  //hw/ip/acc/dv/smoke_pqc:run_smoke_test "$@"
