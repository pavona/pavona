#!/bin/bash
#
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set -e

# Create the destination directory.
hash=$(git log --pretty=format:'%h' -n 1)
benchdir=$(dirname "$0")
mkdir -p $benchdir/$hash

# Freshly test all targets. If they are set to collect statistics, these will
# be gathered in the test logs.
bzlpath="$1"
echo "./bazelisk.sh test $bzlpath"
./bazelisk.sh test $bzlpath

# Collect the test logs for each target.
echo "Collecting logs for all acc_autogen_sim_test targets..."
targets=$(./bazelisk.sh query "kind(acc_autogen_sim_test, $bzlpath)")
for target in $targets
do
    shortname=$(echo $target | cut -d ":" -f 2)
    testdir=$(echo $target | cut -d ":" -f 1 | cut -c 2-)
    logfile="bazel-testlogs/$testdir/$shortname/test.log"
    statsfile="$benchdir/$hash/$shortname.stats"
    if grep -q "cycles" $logfile; then
      cp -f $logfile $statsfile
    else
      echo "Target $shortname does not appear to include execution statistics. Is the 'stats' parameter set in the acc_autogen_sim_test rule?"
      exit 1
    fi
done
