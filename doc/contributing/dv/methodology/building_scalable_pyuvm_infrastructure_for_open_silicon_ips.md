# Building Scalable pyUVM Infrastructure for Open Silicon IPs

# Introduction

This document describes the Python-side methodology for building scalable
pyUVM DV infrastructure for open silicon IPs.

It is the pyUVM companion to the SystemVerilog UVM methodology document. The
conceptual UVM layering is the same, but Python has a different failure mode:
imports execute code. A package that eagerly imports every test, environment,
and virtual sequence may work for a smoke test, then fail later as the bench
grows and shared classes create circular imports.

The goal of the pyUVM base structure is to preserve UVM-style reuse while
keeping Python package dependencies explicit and acyclic.

# Design Principles

Scalable pyUVM benches should follow these rules:

* Keep reusable protocol agent code separate from DV self-test code.
* Keep environment construction separate from test selection.
* Keep pyUVM registration side effects explicit.
* Keep DV-specific parameter classes close to the DV package.
* Use fully qualified Python paths for virtual sequence selection.
* Keep top-level package initializers lightweight.
* Let `dvsim` own regression selection and run-time plusargs.

# Package Layout

For a reusable agent or IP-level pyUVM bench, use this package shape:

| Package Area | Ownership |
| :---- | :---- |
| `<agent>/` | Reusable protocol agent code: configuration, sequence items, drivers, monitors, sequencers, coverage, and protocol sequences. |
| `<agent>/seq_lib/` | Reusable protocol-level sequences that can be used by multiple benches. |
| `<agent>/dv/env/` | Environment construction, environment configuration, scoreboard, virtual sequencer, and environment-local coverage. |
| `<agent>/dv/env/seq_lib/` | Virtual sequences and environment-level sequences. |
| `<agent>/dv/tests/` | pyUVM test classes. |
| `<agent>/dv/tb/` | Cocotb entry points that choose the pyUVM test and call `uvm_root().run_test()`. |
| `<agent>/dv/pyuvm_registry.py` | Explicit imports for pyUVM test classes that must be registered before `run_test()`. |
| `<agent>/dv/<agent>_python_sim_cfg.hjson` | `dvsim` test and regression configuration. |

The `tl_agent` Python bench is the reference vertical slice for this layout.

# Reusable Agent Layer

The top-level agent package owns classes that are reusable outside the agent's
self-test bench:

* configuration classes
* sequence items
* protocol drivers and monitors
* sequencers
* protocol-level sequences
* protocol coverage
* reusable protocol adapters

For `tl_agent`, both parameter classes are DV-specific and live under `dv`:

* `hw/dv/py/tl_agent/dv/tl_agent_config_parameters.py`
* `hw/dv/py/tl_agent/dv/tl_agent_test_seq_parameters.py`

This is intentional. Both tests and virtual sequences need access to these
classes, but they are not reusable protocol-agent API, so they should not live
at the top-level agent package or under `dv/tests`.

# Test and Config Parameters

The pyUVM flow uses the same split as the reset-safe SystemVerilog UVM flow:

| Parameter Class | Lifetime | Purpose |
| :---- | :---- | :---- |
| `test_params` | One instance per test | Test-global strategy that must survive reset. |
| `config_params` | Fresh instance per reset-stable execution window | DUT or environment configuration used for one reset loop. |

`test_params` are created and randomized once for the full test. `config_params`
are recreated and randomized for each reset-loop iteration.

Do not place test-sequence parameter classes in `<agent>/dv/tests/` if virtual
sequences use them. Place DV-specific shared parameter classes directly under
`<agent>/dv/`. That keeps the environment sequence library out of the tests
package while making the ownership clear.

# Package Initializers

Keep `__init__.py` files lightweight.

The top-level agent package may re-export stable reusable classes, and it may
provide lazy convenience exports for DV classes. It should not eagerly import
the full DV environment, all tests, and all virtual sequences.

This rule keeps `import <agent>` useful for protocol-level reuse without also
constructing the import graph for every self-test bench.

# pyUVM Registration

pyUVM test classes selected by short `+UVM_TESTNAME` values must be imported
before calling `uvm_root().run_test()`.

The cocotb entry point should import an explicit registry module for these
side effects:

```python
import tl_agent.dv.pyuvm_registry  # noqa: F401 Register pyUVM tests.
```

The registry module should import only the classes that need registration by
short name. For the common Pavona flow, that means pyUVM test classes.

Do not rely on `import <agent>` to register the entire DV bench. That makes the
top-level package initializer responsible for unrelated DV imports and makes
circular imports harder to diagnose.

# Test and Sequence Selection

`dvsim` passes pyUVM test and sequence selection into the Python bench as
plusargs:

* `+UVM_TESTNAME=<pyuvm test class>`
* `+UVM_TEST_SEQ=<python module path>.<sequence class>`

These selectors have different import requirements:

| Selector | Import Requirement |
| :---- | :---- |
| `UVM_TESTNAME` | Short pyUVM test names must be registered before `run_test()`, so their modules are imported by `dv/pyuvm_registry.py`. |
| `UVM_TEST_SEQ` | Fully qualified virtual sequence paths can be imported by the base test at run time. |

This lets the regression select a small number of test classes and a wider set
of virtual sequences without forcing all sequence modules into package import
time.

# Reset-Safe Sequence Flow

Reset-safe pyUVM benches should use the same stop-clean-restart model as the
SystemVerilog UVM reset methodology:

1. The test creates the environment and binds clock/reset and protocol
   interfaces.
2. The base virtual sequence creates and randomizes `test_params` once.
3. Each reset loop creates fresh `config_params`.
4. Reset trigger and main stimulus run as independent tasks.
5. On reset, active low-level sequences and driver/monitor collection tasks are
   stopped.
6. Sequencer queues, analysis FIFOs, scoreboards, and protocol state return to
   idle.
7. After reset deassertion, the next reset loop starts with fresh
   `config_params`.

The framework code that owns this behavior should stay in `dv_lib`. Agent and
IP benches should customize hooks such as `dut_init()`, `dut_shutdown()`, and
`main_thread()` rather than duplicating the base reset loop.

# `dvsim` Integration

A scalable pyUVM bench should have a Python-specific sim cfg instead of hiding
Python behavior in ad hoc scripts.

The sim cfg should own:

* the simulator tool selection
* the FuseSoC core or build inputs
* the cocotb/pyUVM run command
* default `uvm_test`
* default `uvm_test_seq`
* per-test sequence overrides
* reseed policy
* timeout policy
* coverage knobs
* wave and scratch-root behavior

The Python bench should preserve the same external regression surface as the
SystemVerilog benches where possible, especially `uvm_test`, `uvm_test_seq`,
reseed count, pass/fail status, and coverage output.

# Reference Files

Use these files as the current pyUVM base reference:

* `hw/dv/py/dv_lib/dv_base_test.py`
* `hw/dv/py/dv_lib/dv_base_vseq.py`
* `hw/dv/py/dv_lib/dv_base_sequencer.py`
* `hw/dv/py/tl_agent/dv/tl_agent_config_parameters.py`
* `hw/dv/py/tl_agent/dv/tl_agent_test_seq_parameters.py`
* `hw/dv/py/tl_agent/dv/pyuvm_registry.py`
* `hw/dv/py/tl_agent/dv/tb/test_tl_agent_env.py`
* `hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson`

# Checklist for New pyUVM IP Benches

Before adding a new pyUVM IP bench, check that:

* DV-specific shared parameters live under `dv`, not under `dv/tests`
* `dv/tests` contains test classes, not general environment dependencies
* the cocotb entry point imports a registry module before `run_test()`
* `UVM_TEST_SEQ` uses fully qualified Python class paths
* top-level package imports do not eagerly load the entire DV bench
* reset-sensitive behavior is implemented through `dv_lib` base hooks
* `dvsim` owns regression selection, reseeds, timeouts, and coverage options
* the bench has a smoke path and an `all` regression path
