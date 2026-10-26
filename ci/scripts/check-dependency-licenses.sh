#!/usr/bin/env bash
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set -e

echo -e "\n### Check Python licenses"
ALLOWED=(
  'apache'
  'Apache-2.0'
  'Apache Software License'
  'BSD'
  'BSD-3-Clause'
  'BSD License'
  'Freeware'
  'GNU Lesser General Public License v2 or later (LGPLv2+)'
  'GNU Lesser General Public License v3 (LGPLv3)'
  'GNU Library or Lesser General Public License (LGPL)'
  'MIT'
  'MIT License'
  'Mozilla Public License 2.0 (MPL 2.0)'
  'MPL-2.0 AND MIT'
  'Public Domain'
  'Python Software Foundation License'
  'UNKNOWN'
)
ALLOWED_SEMI=${ALLOWED[0]}
for lic in "${ALLOWED[@]}"; do
  ALLOWED_SEMI="$ALLOWED_SEMI;$lic"
done;
pip-licenses --allow-only "$ALLOWED_SEMI"

echo -e "\n### Check Rust licenses"
cargo deny --all-features --manifest-path third_party/rust/Cargo.toml check licenses
cargo deny --all-features --manifest-path third_party/tock/Cargo.toml check licenses
