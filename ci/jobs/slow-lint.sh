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
before=$(snapshot)

echo -e "\n### Countermeasures implemented (egret)"
./ci/scripts/check-countermeasures.sh egret

echo -e "\n### Countermeasures implemented (scafi_deprecated)"
./ci/scripts/check-countermeasures.sh scafi_deprecated

echo -e "\n### Bazel test suite tags"
./ci/scripts/check_bazel_test_suites.py

echo -e "\n### Banned Bazel rules"
./ci/scripts/check-bazel-banned-rules.sh

echo -e "\n### Bazel target names"
./ci/scripts/check_bazel_target_names.py

echo -e "\n### DV software images"
./ci/scripts/check_dv_sw_images.sh

echo -e "\n### Unrunnable tests"
./ci/scripts/check-unrunnable-tests.sh

# NOTE : #21973: disabled until Verilator tags are fixed.
# echo -e "\n### Check tags on Bazel artifacts"
# ci/scripts/check-bazel-tags.sh

echo -e "\n### Ensure bazel doesn't use 'git_repository's"
ci/scripts/check-bazel-banned-rules.sh

echo -e "\n### Render documentation"
ci/scripts/build-docs.sh

echo -e "\n### Ensure all generated files are clean and up-to-date"
ci/scripts/check-generated.sh

echo -e "\n### Ensure all sim_cfg files use the correct formatting"
ci/scripts/check-sim-cfgs.py

echo -e "\n### Use buildifier to check Bazel coding style"
bazel test //quality:buildifier_check --test_output=streamed

echo -e "\n### ACC assembly lint"
./bazelisk.sh test //quality:acc_lint

echo -e "\n### Check vendored directories are up-to-date"
ci/scripts/check-vendoring.sh

echo -e "\n### Style-Lint RTL Verilog source files with Verible for egret"
ci/scripts/verible-lint.sh rtl egret

echo -e "\n### Style-Lint DV Verilog source files with Verible for egret"
ci/scripts/verible-lint.sh dv egret

echo -e "\n### Style-Lint FPV Verilog source files with Verible for egret"
ci/scripts/verible-lint.sh fpv egret

echo -e "\n### Style-Lint RTL Verilog source files with Verible for dragonfly"
ci/scripts/verible-lint.sh rtl dragonfly

echo -e "\n### Style-Lint DV Verilog source files with Verible for dragonfly"
ci/scripts/verible-lint.sh dv dragonfly

echo -e "\n### Style-Lint FPV Verilog source files with Verible for dragonfly"
ci/scripts/verible-lint.sh fpv dragonfly

echo -e "\n### Validate alert classification for Egret"
./ci/scripts/validate_alert_classification.py egret hw/top_egret/ip_autogen/alert_handler/data/top_egret_alert_handler.ipconfig.hjson "$(realpath hw/top_egret/data/otp/otp_ctrl_img_owner_sw_cfg.hjson)"

echo -e "\n### Validate alert classification for Dragonfly"
./ci/scripts/validate_alert_classification.py dragonfly hw/top_dragonfly/ip_autogen/alert_handler/data/top_dragonfly_alert_handler.ipconfig.hjson "$(realpath hw/top_dragonfly/data/otp/otp_ctrl_img_owner_sw_cfg.hjson)"

if is_clean "$before"; then
  exit 0
else
  exit 1
fi
