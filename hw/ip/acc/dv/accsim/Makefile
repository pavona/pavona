# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

.PHONY: all
all: lint

# We need a directory to build stuff and use the "acc/accsim" namespace
# in the top-level build-bin directory.
repo-top := ../../../../..
build-dir := $(repo-top)/build-bin/acc/accsim
bazel := $(repo-top)/bazelisk.sh
reponame := $(shell cd $(repo-top) && basename $$PWD)

$(build-dir):
	mkdir -p $@

llvm:
	$(bazel) build @llvm_toolchain_llvm//:bin/clang @llvm_toolchain_llvm//:bin/ld.lld

py-scripts := standalone.py stepped.py
py-files   := $(wildcard *.py sim/*.py test/*.py)
py-libs    := $(filter-out $(py-scripts),$(py-files))

lint-stamps := $(foreach scr,$(py-scripts),$(build-dir)/$(scr).stamp)

$(lint-stamps): $(build-dir)/%.stamp: % $(py-libs) | $(build-dir)
	mypy --strict --config-file=mypy.ini $<
	touch $@

.PHONY: lint
lint: $(lint-stamps)

.PHONY: test
test: llvm
	RV32_TOOL_GCC=../../../../../bazel-$(reponame)/$$($(bazel) cquery --output=files @llvm_toolchain_llvm//:bin/clang) \
		RV32_TOOL_AS=../../../../../bazel-$(reponame)/$$($(bazel) cquery --output=files @llvm_toolchain_llvm//:bin/clang) \
		RV32_TOOL_LD=../../../../../bazel-$(reponame)/$$($(bazel) cquery --output=files @llvm_toolchain_llvm//:bin/ld.lld) \
		pytest test
