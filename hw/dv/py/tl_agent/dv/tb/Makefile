# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

TB_DIR := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))
PY_DV_ROOT := $(abspath $(TB_DIR)/../../..)

VERILOG_SOURCES += $(TB_DIR)/../../rtl/tl_agent_smoke.sv
TOPLEVEL = tl_agent_smoke
COCOTB_TEST_MODULES = test_tl_agent_env

ifeq ($(filter dvsim_build dvsim_run,$(MAKECMDGOALS)),)
UVM_TESTNAME ?= tl_agent_base_test
UVM_TEST_SEQ ?= tl_agent.dv.env.seq_lib.tl_agent_base_vseq.tl_agent_base_vseq
endif
TX_COUNT ?= 12

TL_AUW ?= $(shell PYTHONPATH=$(PY_DV_ROOT) python3 -c "from interfaces import get_tl_widths; print(get_tl_widths().tl_auw)")
TL_DUW ?= $(shell PYTHONPATH=$(PY_DV_ROOT) python3 -c "from interfaces import get_tl_widths; print(get_tl_widths().tl_duw)")
TL_AW ?= $(shell PYTHONPATH=$(PY_DV_ROOT) python3 -c "from interfaces import get_tl_widths; print(get_tl_widths().tl_aw)")
TL_DW ?= $(shell PYTHONPATH=$(PY_DV_ROOT) python3 -c "from interfaces import get_tl_widths; print(get_tl_widths().tl_dw)")
TL_AIW ?= $(shell PYTHONPATH=$(PY_DV_ROOT) python3 -c "from interfaces import get_tl_widths; print(get_tl_widths().tl_aiw)")
TL_DIW ?= $(shell PYTHONPATH=$(PY_DV_ROOT) python3 -c "from interfaces import get_tl_widths; print(get_tl_widths().tl_diw)")
TL_DBW ?= $(shell PYTHONPATH=$(PY_DV_ROOT) python3 -c "from interfaces import get_tl_widths; print(get_tl_widths().tl_dbw)")
TL_SZW ?= $(shell PYTHONPATH=$(PY_DV_ROOT) python3 -c "from interfaces import get_tl_widths; print(get_tl_widths().tl_szw)")
TL_OPCODE_W ?= $(shell PYTHONPATH=$(PY_DV_ROOT) python3 -c "from interfaces import get_tl_widths; print(get_tl_widths().tl_opcode_w)")
TL_PARAM_W ?= $(shell PYTHONPATH=$(PY_DV_ROOT) python3 -c "from interfaces import get_tl_widths; print(get_tl_widths().tl_param_w)")

export TL_AW
export TL_DW
export TL_AIW
export TL_DIW
export TL_AUW
export TL_DUW
export TL_DBW
export TL_SZW
export TL_OPCODE_W
export TL_PARAM_W

COMPILE_ARGS += -GTL_AW=$(TL_AW)
COMPILE_ARGS += -GTL_DW=$(TL_DW)
COMPILE_ARGS += -GTL_AIW=$(TL_AIW)
COMPILE_ARGS += -GTL_DIW=$(TL_DIW)
COMPILE_ARGS += -GTL_AUW=$(TL_AUW)
COMPILE_ARGS += -GTL_DUW=$(TL_DUW)
COMPILE_ARGS += -GTL_DBW=$(TL_DBW)
COMPILE_ARGS += -GTL_SZW=$(TL_SZW)
COMPILE_ARGS += -GTL_OPCODE_W=$(TL_OPCODE_W)
COMPILE_ARGS += -GTL_PARAM_W=$(TL_PARAM_W)

SIM_ARGS += +TX_COUNT=$(TX_COUNT)

include $(abspath $(PY_DV_ROOT)/../tools/dvsim/verilator_pyuvm.mk)
