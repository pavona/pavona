#!/bin/bash
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0


set -e

usage () {
  echo "usage: $0 [-l] [-c CACHE_DIR] [-r REF] [-t TOP] [-h] TARGET ..."
  echo "  Build and add a bitstream to the cache."
  echo ""
  echo "  -l                            Mark this new bitstream cache entry as the latest; default 0 (false)."
  echo "  -c CACHE_DIR                  Cache directory; defaults to ~/.cache/pavona-bitstreams."
  echo "  -r REF                        Git ref to mark this as; defaults to current commit or 'default'."
  echo "  -t TOP                        Top level system to build bitstream for; default is egret."
  echo "  TARGET                        FPGA bitstream target to build for new cache entry."
  echo "  -h                            Print the command line usage for this script."
}

cd "$(dirname $0)"/../..

: ${BAZEL_BITSTREAMS_CACHE:="$(realpath ~/.cache/pavona-bitstreams)"}
mark_latest=0
ref="$(git rev-parse HEAD)" || ref="default"
tops=()
while getopts "hlc:r:t:" OPTION; do
  case $OPTION in
    h)
      usage
      exit 0
      ;;
    l)
      mark_latest=1
      ;;
    c)
      export BAZEL_BITSTREAMS_CACHE="$OPTARG"
      ;;
    r)
      ref="$OPTARG"
      ;;
    t)
      tops+=("$OPTARG")
      ;;
    *)
      echo "Invalid option: -$OPTION"
      usage
      exit 1
      ;;
    esac
done
if (( ${#tops[@]} == 0 )); then
  tops=("egret")
fi
shift $(($OPTIND - 1))
targets=( "$@" )


# generate requested bitstreams
new_entry=$BAZEL_BITSTREAMS_CACHE/cache/$ref
mkdir -p $new_entry
for top in "${tops[@]}"; do
  for t in "${targets[@]}"; do
    $PWD/bazelisk.sh build //hw/bitstream/vivado:fpga_$t
    $PWD/bazelisk.sh build //hw/bitstream/vivado:"$top"_"$t"_archive
    bitstream_tar_archive=$($PWD/bazelisk.sh outquery //hw/bitstream/vivado:"$top"_"$t"_archive)
    echo "Taking archive from" "$bitstream_tar_archive"
    tar -xf $bitstream_tar_archive -C $BAZEL_BITSTREAMS_CACHE/cache/$ref/ --strip-components=4
    mv -f $BAZEL_BITSTREAMS_CACHE/cache/$ref/manifest.json $BAZEL_BITSTREAMS_CACHE/cache/$ref/manifest_"$top"_"$t".json  # label this manifest file as top-specific
  done
done

# create the manifest.json file to include all bitstream targets built
tmpdir=$(mktemp -d)
$PWD/bazelisk.sh build //util/py/scripts:bitstream_cache_create
mapfile -t manifests < <(find $BAZEL_BITSTREAMS_CACHE/cache/$ref -name "manifest*.json")
$PWD/bazelisk.sh run //util/py/scripts:bitstream_cache_create -- \
  --schema $PWD/rules/scripts/bitstreams_manifest.schema.json \
  --stamp-file $PWD/bazel-out/volatile-status.txt \
  --out $tmpdir \
  "${manifests[@]}"
cp $tmpdir/manifest.json $BAZEL_BITSTREAMS_CACHE/cache/$ref/

# if applicable, mark this cache entry as the latest
if [ $mark_latest = 1 ]; then
  echo "$ref" > $BAZEL_BITSTREAMS_CACHE/latest.txt
fi
