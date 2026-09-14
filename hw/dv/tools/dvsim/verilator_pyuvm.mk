# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

TB_DIR ?= $(CURDIR)
PY_DV_ROOT ?= $(abspath $(TB_DIR)/../..)

TOPLEVEL_LANG ?= verilog
SIM ?= verilator

RTL_FILELIST ?=
RTL_FILTERED_FILELIST ?= $(SIM_BUILD)/rtl_filelist.f
UVM_TESTNAME ?=
UVM_TEST_SEQ ?=
UVM_VERBOSITY ?= MEDIUM
DV_RANDOM_SEED ?= 1
COCOTB_RANDOM_SEED ?= $(DV_RANDOM_SEED)
PYVSC_COV_DB ?=

WAVES ?= 0
WAVE_FORMAT ?= fst
WAVE_FILE ?=

export PYTHONPATH := $(TB_DIR):$(PY_DV_ROOT):$(PYTHONPATH)
export COCOTB_RANDOM_SEED
export PYVSC_COV_DB

ifneq ($(strip $(RTL_FILELIST)),)
CUSTOM_COMPILE_DEPS += $(RTL_FILTERED_FILELIST)
COMPILE_ARGS += -f $(RTL_FILTERED_FILELIST)
override VERILOG_SOURCES :=
endif

BUILD_PLUSARGS ?=
RUN_PLUSARGS ?=

COMPILE_ARGS += $(BUILD_PLUSARGS)
SIM_ARGS += +UVM_TESTNAME=$(UVM_TESTNAME)
SIM_ARGS += +UVM_TEST_SEQ=$(UVM_TEST_SEQ)
SIM_ARGS += +UVM_VERBOSITY=$(UVM_VERBOSITY)
SIM_ARGS += +DV_RANDOM_SEED=$(DV_RANDOM_SEED)
SIM_ARGS += $(RUN_PLUSARGS)

ifeq ($(WAVES),1)
ifeq ($(WAVE_FORMAT),fst)
# Recent Verilator versions use libfstwriter, which includes the external LZ4
# headers and links against liblz4. Homebrew keeps those files outside the
# default Apple Clang search paths. Allow callers to set LZ4_PREFIX explicitly,
# and otherwise discover the Homebrew installation when available.
LZ4_PREFIX ?= $(shell brew --prefix lz4 2>/dev/null)
ifeq ($(strip $(LZ4_PREFIX)),)
LZ4_PREFIX := $(firstword $(wildcard /opt/homebrew/opt/lz4 /usr/local/opt/lz4))
endif
ifneq ($(strip $(LZ4_PREFIX)),)
COMPILE_ARGS += -CFLAGS -I$(LZ4_PREFIX)/include
COMPILE_ARGS += -LDFLAGS -L$(LZ4_PREFIX)/lib
endif
COMPILE_ARGS += --trace-fst
ifeq ($(strip $(WAVE_FILE)),)
WAVE_FILE := $(SIM_BUILD)/waves.fst
endif
SIM_ARGS += --trace --trace-file $(WAVE_FILE)
else ifeq ($(WAVE_FORMAT),vcd)
COMPILE_ARGS += --trace
ifeq ($(strip $(WAVE_FILE)),)
WAVE_FILE := $(SIM_BUILD)/waves.vcd
endif
SIM_ARGS += --trace --trace-file $(WAVE_FILE)
else
$(error Unsupported WAVE_FORMAT='$(WAVE_FORMAT)'; use 'fst' or 'vcd')
endif
endif

waves:
	$(MAKE) sim WAVES=1 WAVE_FORMAT=fst

waves-vcd:
	$(MAKE) sim WAVES=1 WAVE_FORMAT=vcd

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: dvsim_build dvsim_run waves waves-vcd
all: sim

$(RTL_FILTERED_FILELIST): $(RTL_FILELIST) | $(SIM_BUILD)
	sed \
		-e '/^--Mdir /d' \
		-e '/^--cc$$/d' \
		-e '/^--exe$$/d' \
		-e '/^--top-module /d' \
		"$<" > "$@"

dvsim_build: $(SIM_BUILD)/Vtop

dvsim_run: $(COCOTB_RESULTS_FILE)
