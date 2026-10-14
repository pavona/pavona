#!/bin/bash
#
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set -e

# Create the destination directory.
hash=$(git log --pretty=format:'%h' -n 1)
benchdir=$(dirname "$0")
dstdir="$benchdir/logs/$hash"
mkdir -p $dstdir

# Freshly test all targets. If they are set to collect statistics, these will
# be gathered in the test logs.
bzlpath="$1"
echo "./bazelisk.sh test --define=acc_bench=true $bzlpath"
./bazelisk.sh test --define=acc_bench=true $bzlpath

# Collect the test logs for each target.
echo "Collecting logs for all tests in $bzlpath..."
targets=$(./bazelisk.sh query "tests($bzlpath)")
for target in $targets
do
    shortname=$(echo $target | cut -d ":" -f 2)
    testdir=$(echo $target | cut -d ":" -f 1 | cut -c 2-)
    logfile="bazel-testlogs/$testdir/$shortname/test.log"
    statsfile="$dstdir/$shortname.stats"
    if grep -q "cycles" $logfile; then
      cp -f $logfile $statsfile
    else
      echo "Target $shortname does not appear to include execution statistics. Is the 'stats' parameter set in the test rule?"
      exit 1
    fi
done

# Collect the ELF files of the ACC binaries to measure their code size.
echo "Collecting ELF files for all ACC binaries..."
binaries="attr(name, '^run_', kind(acc_binary, //sw/acc/crypto:all))"
readarray -t labels < <(./bazelisk.sh query "$binaries")
./bazelisk.sh build --define=acc_bench=true -- "${labels[@]}"
for elf in $(./bazelisk.sh cquery --define=acc_bench=true --output=files "$binaries" | grep '\.elf$')
do
    cp -f "$elf" "$dstdir/"
done
