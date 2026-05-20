#!/bin/bash
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# run this from the git-less package of the repo after installing all repo requirements

EXIT_ON_FAIL=false
TOOL=
while getopts "het:" OPTION; do
  case $OPTION in
    h)
      echo "Usage: check-gitless.sh [-h] [-e] [-t TOOL]"
      echo "Run a series of tests on the repo that should work, both in git-less "
      echo "(from git archive) and git-ful (from git clone) packages."
      echo ""
      echo "  -h    Print this help message."
      echo "  -e    Exit the script after the first failed test command."
      echo "  -t    Tool for running dvsim; DV tests will be skipped if not"
      echo "        passed in or invalid tool."
      exit 0
      ;;
    e)
      echo "Exiting on first fail."
      set -e
      EXIT_ON_FAIL=true
      ;;
    t)
      TOOL=$OPTARG
      ;;
    *)
      echo "Invalid option: $OPTION"
      ;;
    esac
done


export REPO_TOP=${REPO_TOP:-$(realpath "$(dirname "$0")/../..")}
cd "$REPO_TOP" || exit 1
rm -f ./gitless.log
touch ./gitless.log


run_cmds () {
  cd "$REPO_TOP" || exit 1
  for cmd in "$@"; do
    running_log=$(mktemp)
    echo RUNNING: "$cmd" > "$running_log"
    echo "--------------------------------------" >> "$running_log"
    echo -n "    \`$cmd\`: "

    if $cmd 1>/dev/null 2>>"$running_log"; then
      cd "$REPO_TOP" || exit 1
      echo "PASSED."

    else
      cd "$REPO_TOP" || exit 1
      echo "" >> "$running_log"  # extra spacing kludge
      echo "" >> "$running_log"
      cat "$running_log" >> ./gitless.log
      echo "FAILED. Check $REPO_TOP/gitless.log for stderr."
      if [ "$EXIT_ON_FAIL"  = true ]; then
        exit 1
      fi
    fi

    rm "$running_log"
  done
}


echo "Running basic checks for gitless..."
run_cmds 'make -C hw all'
run_cmds \
  './ci/scripts/sw-build-test.sh egret //...' \
  './ci/scripts/sw-build-test.sh dragonfly //...'

if [ "$(which verilator)" ]; then
  run_cmds './ci/scripts/run-verilator-tests.sh'  # verilator tests first as sanity check
else
  echo "    Verilator install not found; skipping verilator tests."
fi

echo "Running DV tests [requires dvsim capabilities]..."
if [ "$TOOL" = "vcs" ] || [ "$TOOL" = "quest" ] || [ "$TOOL" = "xcelium" ] || [ "$TOOL" = "ascentlint" ] || [ "$TOOL" = "verixcdc" ] || [ "$TOOL" = "mrdc" ] || [ "$TOOL" = "veriblelint" ] || [ "$TOOL" = "verilator" ] || [ "$TOOL" = "dc" ]; then  # possible tools listed in util/dvsim/dvsim.py
  run_cmds \
    './util/dvsim/dvsim.py -t '"$TOOL"' --cov ./hw/top_dragonfly/dv/top_dragonfly_sim_cfgs.hjson' \
    './util/dvsim/dvsim.py -t '"$TOOL"' --cov ./hw/top_egret/dv/top_egret_sim_cfgs.hjson'
else
  echo "    No valid tool passed in. Skipping dvsim tests."
fi


exit 0
