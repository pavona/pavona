#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# A wrapper that duplicates the code for the quick lint job in
# .github/actions/ci.yml. The two should be kept in sync.
#
# This doesn't install dependencies, but should otherwise behave the
# same as what CI would do on a pull request.

set -e

source ci/scripts/lib/snapshot.sh
source ci/scripts/lib/section.sh

before=$(snapshot)

section "Countermeasures implemented (egret)"
./ci/scripts/check-countermeasures.sh egret
section_end

section "Countermeasures implemented (scafi_deprecated)"
./ci/scripts/check-countermeasures.sh scafi_deprecated
section_end

section "Bazel test suite tags"
./ci/scripts/check_bazel_test_suites.py
section_end

# NOTE : #21973: disabled until Verilator tags are fixed.
# section "Check tags on Bazel artifacts"
# ci/scripts/check-bazel-tags.sh

section "Banned Bazel rules"
./ci/scripts/check-bazel-banned-rules.sh
section_end

section "Bazel target names"
./ci/scripts/check_bazel_target_names.py
section_end

section "DV software images"
./ci/scripts/check_dv_sw_images.sh
section_end

section "Unrunnable tests"
./ci/scripts/check-unrunnable-tests.sh
section_end

section "Render documentation"
ci/scripts/build-docs.sh
section_end

section "Ensure all generated files are clean and up-to-date"
ci/scripts/check-generated.sh
section_end

section "Ensure all sim_cfg files use the correct formatting"
ci/scripts/check-sim-cfgs.py
section_end

section "ACC assembly lint"
./bazelisk.sh test //quality:acc_lint
section_end

section "Check vendored directories are up-to-date"
ci/scripts/check-vendoring.sh
section_end

section "Style-Lint RTL Verilog source files with Verible for egret"
ci/scripts/verible-lint.sh rtl egret
section_end

section "Style-Lint DV Verilog source files with Verible for egret"
ci/scripts/verible-lint.sh dv egret
section_end

section "Style-Lint FPV Verilog source files with Verible for egret"
ci/scripts/verible-lint.sh fpv egret
section_end

section "Style-Lint RTL Verilog source files with Verible for dragonfly"
ci/scripts/verible-lint.sh rtl dragonfly
section_end

section "Style-Lint DV Verilog source files with Verible for dragonfly"
ci/scripts/verible-lint.sh dv dragonfly
section_end

section "Style-Lint FPV Verilog source files with Verible for dragonfly"
ci/scripts/verible-lint.sh fpv dragonfly
section_end

section "Slang RTL egret"
ci/scripts/slang-lint.sh egret
section_end

section "Slang RTL dragonfly"
ci/scripts/slang-lint.sh dragonfly
section_end

section "Validate alert classification for Egret"
./ci/scripts/validate_alert_classification.py egret hw/top_egret/ip_autogen/alert_handler/data/top_egret_alert_handler.ipconfig.hjson "$(realpath hw/top_egret/data/otp/otp_ctrl_img_owner_sw_cfg.hjson)"
section_end

section "Validate alert classification for Dragonfly"
./ci/scripts/validate_alert_classification.py dragonfly hw/top_dragonfly/ip_autogen/alert_handler/data/top_dragonfly_alert_handler.ipconfig.hjson "$(realpath hw/top_dragonfly/data/otp/otp_ctrl_img_owner_sw_cfg.hjson)"
section_end

if is_clean "$before"; then
  exit 0
else
  exit 1
fi
