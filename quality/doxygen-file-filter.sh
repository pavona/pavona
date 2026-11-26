#!/usr/bin/env bash
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Doxygen input filter for quality/Doxyfile.lint.
#
# Doxygen only reports undocumented functions in files that are documented
# themselves, i.e. that contain an @file block.
# To lint every header without requiring an @file block in each of them, this
# filter prepends `/** @file */` to the first line of the file passed as $1
# and prints the result.
sed "1s|^|/** @file */ |" "$1"
