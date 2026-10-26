#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Checks links between files.

set -e

# Run Offline Link Check
./bazelisk.sh run @lychee//:lychee -- SUMMARY.md hw/ sw/ doc/ util/ \
    --offline --no-progress \
    --exclude-path sw/vendor \
    --exclude-path util/i2csvg/smbus/SMBus.md \
    --exclude-path hw/ip_templates/ \
    --exclude-path hw/dv/doc/dv_doc_template.md \
    --exclude-path doc/rust_for_c_devs.md \
    --exclude-path hw/top_egret/ip/pinmux/doc/autogen/targets.md \
    --exclude-path util/site/landing.html \
    || {
      echo -n "::error::"
      echo "Link Check failed."
      exit 1
    }
