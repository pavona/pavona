#!/bin/bash
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# A wrapper that duplicates the code for the quick lint job in
# .github/actions/ci.yml. The two should be kept in sync.
#
# This doesn't install dependencies, but should otherwise behave the
# same as what CI would do on a pull request.
#
# These tasks should ideally take less than a minute each

set -e

source ci/scripts/lib/section.sh
source ci/scripts/lib/snapshot.sh

before=$(snapshot)

case $# in
    0)
        tgt_branch=main
        ;;
    1)
        tgt_branch="$1"
        shift
        ;;
    *)
        echo >&2 "Usage: quick-lint.sh [<tgt-branch>]"
        exit 1
esac

section "Display environment information"
ci/scripts/show-env.sh
section_end

section "Check commit metadata"
ci/scripts/lint-commits.sh $tgt_branch
section_end

section "Check Licence Headers"
ci/scripts/check-licence-headers.sh $tgt_branch
section_end

section "Check executable bits"
ci/scripts/exec-check.sh
section_end

section "Check for non-ASCII characters in source code"
ci/scripts/check-ascii.sh
section_end

section "Check Bazel build graph"
./bazelisk.sh build --nobuild //...
section_end

section "Run Python lint (flake8)"
ci/scripts/python-lint.sh $tgt_branch
section_end

section "Run Python lint (mypy)"
ci/scripts/mypy.sh $tgt_branch
section_end

section "Python (ruff)"
ruff check
section_end

section "Validate testplans with schema."
ci/scripts/validate_testplans.sh
section_end

section "Use clang-format to check C/C++ coding style"
./bazelisk.sh test //quality:clang_format_check
section_end

section "Check formatting on header guards"
ci/scripts/include-guard.sh $tgt_branch
section_end

section "Use rustfmt to check Rust coding style"
./bazelisk.sh test //quality:rustfmt_check
section_end

section "Use buildifier to check Bazel coding style"
./bazelisk.sh test //quality:buildifier_check --test_output=streamed
section_end

section "Run shellcheck on all shell scripts"
./bazelisk.sh test //quality:shellcheck_check
section_end

section "Trailing whitespace"
ci/scripts/whitespace.sh "$tgt_branch"
section_end

section "Broken links"
ci/scripts/check-links.sh
section_end

section "Lint Doxygen comments (cryptolib)"
./bazelisk.sh run @doxygen//:bin/doxygen quality/Doxyfile.lint
section_end

section "Lock files"
ci/scripts/check-lock-files.sh
section_end

section "Check licenses are all okay"
ci/scripts/check-dependency-licenses.sh
section_end

if is_clean "$before"; then
  exit 0
else
  exit 1
fi
