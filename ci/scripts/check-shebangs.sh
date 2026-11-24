#!/usr/bin/env bash
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Check that every file with a shebang line uses `#!/usr/bin/env <interpreter>`
# rather than a hard-coded interpreter path such as `#!/bin/bash`. Hard-coded
# paths assume a system-wide install location, which does not hold on every
# platform, and they prevent the interpreter from being picked up from the
# environment (e.g. a toolchain or virtualenv on PATH).
#
# With no arguments, all files tracked by git are checked. Otherwise, only the
# files named on the command line are checked.

set -e
set -o pipefail

if [ $# -gt 0 ]; then
    files=("$@")
else
    mapfile -t files < <(git ls-files ':/')
fi

bad=()
for file in "${files[@]}"; do
    # Skip symlinks, submodules and deleted files.
    [ -f "$file" ] && [ ! -L "$file" ] || continue

    # Read the first line, ignoring files that are empty or not text.
    IFS= read -r line < "$file" || continue
    [[ "$line" == '#!'* ]] || continue

    if [[ ! "$line" =~ ^'#!'[[:space:]]?/usr/bin/env[[:space:]]+[^[:space:]] ]]; then
        bad+=("$file:1: $line")
    fi
done

if [ ${#bad[@]} -ne 0 ]; then
    echo -n "::error::"
    echo "One or more files use a hard-coded interpreter path in their shebang."
    echo "Use '#!/usr/bin/env <interpreter>' instead:"
    printf '  %s\n' "${bad[@]}"
    exit 1
fi
