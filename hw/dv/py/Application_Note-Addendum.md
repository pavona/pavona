<!-- Copyright zeroRISC Inc. -->
<!-- Licensed under the Apache License, Version 2.0, see LICENSE for details. -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# TL Agent Python DVSim Flow Addendum

## Purpose

This note records the implemented `dvsim` integration for the Python TileLink testbench in
`hw/dv/py/tl_agent`.

The goal was not just to run a cocotb / pyUVM test locally. The implemented result is a Python DV
flow that looks sufficiently like the existing SV/UVM `dvsim` flow that wider CI and local
regression use can consume it with minimal special handling.

## Baseline

The existing SV baseline is [tl_agent_sim_cfg.hjson](<repo_top>/hw/dv/sv/tl_agent/dv/tl_agent_sim_cfg.hjson).

That baseline currently assumes:

- `tool: vcs`
- an SV/UVM testbench
- `uvm_test` and `uvm_test_seq` as the test-selection interface
- `dvsim` pass/fail detection from process status plus UVM-style log patterns

The existing working Python prototype is rooted at:

- [Makefile](<repo_top>/hw/dv/py/tl_agent/dv/tb/Makefile)
- [test_tl_agent_env.py](<repo_top>/hw/dv/py/tl_agent/dv/tb/test_tl_agent_env.py)
- [tl_agent_base_test.py](<repo_top>/hw/dv/py/tl_agent/dv/tests/tl_agent_base_test.py)
- [dv_base_test.py](<repo_top>/hw/dv/py/dv_lib/dv_base_test.py)

## Implemented Flow

The execution model is:

`dvsim -> Verilator -> cocotb harness -> pyUVM test -> Python dv_lib`

This is a simulator and testbench implementation change, not a regression-interface change.
`dvsim` remains the top-level entrypoint for regressions.

## Compatibility Goal

The Python flow preserves the externally visible behavior of the SV/UVM flow wherever that is
practical.

That means preserving:

- the `dvsim` entrypoint
- UVM-style test selection via `uvm_test` and `uvm_test_seq`
- plusarg-driven runtime configuration
- UVM-like pass/fail semantics in logs
- deterministic test status reporting for CI

Where pyUVM or cocotb does not naturally emit behavior that `dvsim` expects, the gap is bridged in
pyuvm's reporting integration and Python `dv_lib`, not pushed into ad hoc CI logic.

## Python Test Selection Contract

The Python-side `dvsim` sim cfg keeps:

- `uvm_test`
- `uvm_test_seq`

These are not SV-only concepts in this flow. They are part of the compatibility surface.

### Conveyance

`dvsim` passes `uvm_test` and `uvm_test_seq` into the Python testbench as plusargs.

Target behavior:

- `+UVM_TESTNAME=<pyuvm test class>`
- `+UVM_TEST_SEQ=<python sequence class path>`

The shared Python base test supports cocotb plusarg lookup for runtime arguments in
[dv_base_test.py](<repo_top>/hw/dv/py/dv_lib/dv_base_test.py).

### Current Implementation Status

The checked-in `tl_agent` flow is aligned on the externally visible interface:

- [dv_base_test.py](<repo_top>/hw/dv/py/dv_lib/dv_base_test.py) reads cocotb
  plusargs first, then falls back to environment variables.
- [test_tl_agent_env.py](<repo_top>/hw/dv/py/tl_agent/dv/tb/test_tl_agent_env.py)
  resolves the pyUVM test name through the cocotb-side helper path.
- [pyuvm_registry.py](<repo_top>/hw/dv/py/tl_agent/dv/pyuvm_registry.py)
  imports the pyUVM test classes that must be registered before `run_test()`.
- [tl_agent_python_sim_cfg.hjson](<repo_top>/hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson)
  defines the default `uvm_test`, per-test `uvm_test_seq` overrides, and the `smoke`,
  `directed`, and `all` regressions used by `dvsim`.

For `dvsim` integration, the intended interface is plusargs first. Environment-variable fallback
remains as compatibility behavior, not as the primary contract.

## pyUVM Import and Registration Contract

The Python DV packages separate reusable agent code from pyUVM registration
side effects.

### Package ownership

- The top-level agent package owns reusable protocol code.
- DV-specific shared parameter classes live under `dv`, such as
  [tl_agent_config_parameters.py](<repo_top>/hw/dv/py/tl_agent/dv/tl_agent_config_parameters.py)
  and
  [tl_agent_test_seq_parameters.py](<repo_top>/hw/dv/py/tl_agent/dv/tl_agent_test_seq_parameters.py).
- `dv/env` owns environment construction and environment-local components.
- `dv/env/seq_lib` owns virtual sequences.
- `dv/tests` owns pyUVM test classes.
- `dv/tb` owns cocotb entry points.

This keeps virtual sequences free to use both `test_params` and `config_params`
without importing the tests package.

### Registration ownership

pyUVM test classes selected by short `+UVM_TESTNAME` values must be imported
before calling `uvm_root().run_test()`. The cocotb entry point should import the
bench's explicit registry module for this:

```python
import tl_agent.dv.pyuvm_registry  # noqa: F401 Register pyUVM tests.
```

Do not rely on `import tl_agent` to register the entire DV bench. As the bench
grows, eager top-level imports make it easy to create circular dependencies
between virtual sequences, tests, and package initializers.

Sequences selected by fully qualified `+UVM_TEST_SEQ` paths are resolved by the
base test using Python import machinery, so they do not need to be imported by
the top-level package just to be discoverable.

## Pass / Fail Contract

The Python flow preserves SV/UVM-style test status reporting closely enough that `dvsim` can
consume it reliably.

### Existing `dvsim` Expectations

The shared simulation config currently defines the default run patterns in
[common_sim_cfg.hjson](<repo_top>/hw/dv/tools/dvsim/common_sim_cfg.hjson):

- pass: `^TEST PASSED (UVM_)?CHECKS$`
- fail:
  - `^UVM_ERROR\\s[^:].*$`
  - `^UVM_FATAL\\s[^:].*$`
  - `^UVM_WARNING\\s[^:].*$`
  - `^Assert failed: `
  - `^\\s*Offending '.*'`
  - `^TEST FAILED (UVM_)?CHECKS$`
  - `^Error:.*$`

### Python Compatibility Requirement

The Python flow models these assumptions. Where pyUVM logging does not line up exactly, the gap is
bridged in the Python reporting layer and Python-specific sim cfg support.

Recommended compatibility outputs:

- UVM-like error and fatal lines
- a terminal pass/footer line compatible with `dvsim`
- a terminal fail/footer line compatible with `dvsim`
- `TEST_STATUS: PASSED` or `TEST_STATUS: FAILED` as a human-readable status line

### Current Python Status

pyuvm's `uvm_test` integration creates the shared report server. Pavona's
[dv_base_test.py](<repo_top>/hw/dv/py/dv_lib/dv_base_test.py) emits the report summary and final
`TEST_STATUS` from `report_phase`, then shuts the pyuvm report server down.

That is not the only compatibility mechanism. The Python flow also uses a Python-specific sim cfg
and reporting contract so that `dvsim` can consume build/run status, end-of-test markers, and
coverage artifacts in a stable way.

## Machine-Readable Status

For automation, machine-readable status comes from:

- process exit code
- cocotb JUnit output such as `results.xml`

Human-readable status comes from:

- UVM-like log lines
- `TEST_STATUS`

This remains the active contract:

- JUnit and process exit code are machine truth
- `TEST_STATUS` and UVM-like summary lines are used for human triage and `dvsim` compatibility

## Runtime Knobs That Should Remain Plusarg-Driven

The Python flow continues to honor the same style of runtime knobs used in SV/UVM. Pavona's base
test owns bench-level knobs, including:

- `+UVM_TESTNAME`
- `+UVM_TEST_SEQ`
- `+test_timeout_ns`
- `+en_cov`

pyuvm's `uvm_test` reporting integration owns report-server knobs, including:

- `+UVM_VERBOSITY`
- `+max_quit_count`
- `+print_char_len`
- `+UVM_FAIL_ON_WARNING`
- `+UVM_FAIL_ON_ERROR`
- `+UVM_FAIL_ON_FATAL`

## Reset Testing Status

The Python `tl_agent` reset-safe path is implemented and regression-tested.

### Current reset-testing contract

- Reset testing can be forced for Python reset-safe benches with:
  - `+en_reset_testing=1`
- The plusarg is consumed in
  [dv_base_vseq.py](<repo_top>/hw/dv/py/dv_lib/dv_base_vseq.py)
  as a solve-time constraint override, so dependent `test_params` constraints see
  `reset_testing == ENABLE` during randomization.
- `tl_agent` reset trigger behavior is implemented in
  [tl_agent_base_vseq.py](<repo_top>/hw/dv/py/tl_agent/dv/env/seq_lib/tl_agent_base_vseq.py):
  - random per-loop delay from `config_params.rand_reset_delay`
  - `delay_seq` on `delay_sequencer_h`
  - `reset_seq` on `clk_rst_sequencer_h`

### Reset-delay ownership

- `reset_testing` and `num_reset_loops` remain once-per-test knobs in
  [tl_agent_test_seq_parameters.py](<repo_top>/hw/dv/py/tl_agent/dv/tl_agent_test_seq_parameters.py)
- `rand_reset_delay` is intentionally a per-reset-loop knob in
  [tl_agent_config_parameters.py](<repo_top>/hw/dv/py/tl_agent/dv/tl_agent_config_parameters.py)

This follows the Python base-vseq lifecycle:

- `test_params`: randomized once for the full test
- `config_params`: recreated and randomized once per reset-loop iteration

## Sequence Ownership Model

The Python DV stack uses explicit framework ownership for sequence and task lifetime.

### Shared sequence core

[dv_base_sequence_core.py](<repo_top>/hw/dv/py/dv_lib/dv_base_sequence_core.py)
is the common base for:

- [dv_base_seq.py](<repo_top>/hw/dv/py/dv_lib/dv_base_seq.py)
- [dv_base_vseq.py](<repo_top>/hw/dv/py/dv_lib/dv_base_vseq.py)

It provides:

- common logger / verbosity binding from the sequencer
- `spawn_task(...)` for sequence-owned child tasks
- `cancel_spawned_tasks()` for sequence cleanup

### Sequencer-owned sequence lifecycle

[dv_base_sequencer.py](<repo_top>/hw/dv/py/dv_lib/dv_base_sequencer.py)
now owns started sequences through:

- `await start_sequence(seq)` for blocking launches
- `spawn_sequence(seq)` for background launches
- `stop_sequences()` for reset-time termination

`stop_sequences()` is responsible for:

- cancelling active registered sequences
- clearing sequencer request / response queues
- clearing analysis FIFOs
- returning seq-item state to idle

This is the Python-side equivalent of the SV reset-safe ownership model.

## Current Verification Status

The following `tl_agent` flows have been rerun and are passing with the validated
Python 3.12 and Verilator flow:

- standard non-reset run
- reset-enabled run with `RUN_PLUSARGS=+en_reset_testing=1`
- full `dvsim` regression through
  [tl_agent_python_sim_cfg.hjson](<repo_top>/hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson)
  using the `all` regression target with coverage enabled and `-r 5`

Observed end-of-test markers:

- `TEST_STATUS: PASSED`
- cocotb regression PASS


## Python-Side Sim Cfg

The Python-side sim cfg is now implemented as a sibling reference flow for the Python bench rather
than as a mutation of the SV baseline.

### Implemented Characteristics

- uses Verilator instead of VCS
- launches the cocotb / pyUVM harness
- preserves `uvm_test` and `uvm_test_seq`
- models Python-specific run/build artifacts
- defines pass/fail parsing consistent with the Python reporting contract

### Current Contents

Current conceptual fields include:

- `name`
- DUT / top identity
- `tool`
- build / run integration hooks
- default `uvm_test`
- default `uvm_test_seq`
- `tests`
- `regressions`
- reseed policy
- run timeout policy
- optional wave controls

### Mapping From SV Baseline

Fields that carry over conceptually:

- `name`
- test list structure
- regression structure
- `uvm_test`
- `uvm_test_seq`
- timeout intent
- reseed intent

Fields that change:

- simulator backend
- build / run plumbing
- log parsing details where needed
- tool-specific run modes

## Reference Prototype: tl_agent

`tl_agent` is the reference vertical slice for this work because it now has:

- a working Verilator make-based flow
- a cocotb harness
- pyUVM test structure
- Python `dv_lib` usage

This is the first completed `dvsim`-enabled Python path in the branch and is the best reference for
future Python benches.

## Scope Boundaries

This document is specific to the `tl_agent` Python flow. It is not, by itself:

- a full multi-bench rollout plan
- a complete Python DV framework design document
- a final coverage strategy for all future Python benches
- a full CI matrix definition for every Python DV environment

## Reuse Guidance

For future Python benches, this `tl_agent` flow should be treated as the reference addendum for:

1. simulator and `dvsim` integration shape
2. pyUVM test and sequence selection contract
3. reporting and pass/fail compatibility
4. reset-safe sequence ownership
5. coverage export and merge plumbing
