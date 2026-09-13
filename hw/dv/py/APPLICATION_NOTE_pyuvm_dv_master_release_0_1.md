# Application Note: Using the Python DV Framework

## Purpose

This application note describes how to use the Python DV framework introduced in the pyUVM DV master release. The framework is intended for block-level verification environments built with pyUVM, cocotb, and `dvsim`, with Verilator used as the default simulator flow in this release.

## Framework Layout

The Python DV stack is organized as follows:

- `hw/dv/py/dv_lib`
  Reusable verification base classes and common utilities.
- `hw/dv/py/interfaces`
  Python-side protocol interfaces such as clock/reset and TileLink.
- `hw/dv/py/clk_rst_agent`
  Reusable clock/reset and delay-control agent.
- `hw/dv/py/tl_agent`
  TileLink protocol agent, environment, sequences, tests, and coverage.
- `hw/dv/py/pyral`
  Python register-model support.
- `hw/dv/py/tl_agent_ral`
  Example TileLink-backed RAL usage.

## Recommended Usage Model

The intended usage pattern is:

1. Derive a test environment from the `dv_lib` base classes.
2. Instantiate the protocol agents required by the design under test.
3. Use `clk_rst_agent` for structured clock/reset control rather than embedding reset behavior directly in the environment.
4. Configure tests and virtual sequences through the provided configuration and parameter classes.
5. Run through `dvsim` using the pyUVM/Verilator integration included in this release.

## Building a New Environment

For a new block-level environment, start from `dv_lib`:

- use the base environment, agent, driver, monitor, sequencer, test, and virtual sequence classes as the extension points
- place protocol-independent common behavior in the environment or base sequence layers
- keep protocol-specific logic inside dedicated agents
- use the reporting and verbosity utilities already provided instead of adding separate logging conventions

This keeps the Python flow structurally aligned with the existing SV-UVM methodology.

## Scalable Package Structure

Python DV packages should keep reusable protocol code, DV environment code, and
registration side effects separate. This avoids circular imports as benches grow
from one smoke test into many tests, virtual sequences, and transport adapters.

Recommended layout for an agent package:

- `<agent>/`
  Reusable protocol agent code: configuration, sequence item, drivers,
  monitors, sequencers, coverage, and protocol sequences.
- `<agent>/dv/env/`
  The self-test or block environment, environment config, scoreboard, virtual
  sequencer, and environment-level coverage.
- `<agent>/dv/env/seq_lib/`
  Virtual sequences and environment sequences.
- `<agent>/dv/tests/`
  pyUVM test classes only.
- `<agent>/dv/tb/`
  Cocotb entry points that select and launch the pyUVM test.
- `<agent>/dv/pyuvm_registry.py`
  Explicit imports needed to register pyUVM classes before `run_test()`.

Configuration parameter classes and test-sequence parameter classes should live
together under the DV package when they are DV-specific and both tests and
virtual sequences use them. For example, `tl_agent_config_parameters.py` and
`tl_agent_test_seq_parameters.py` both live under `hw/dv/py/tl_agent/dv/`.

Do not put shared parameter classes in `<agent>/dv/tests/` if environment
sequences need to import them. That creates an environment-to-tests dependency
and can force the tests package to import a partially initialized virtual
sequence module.

Keep package `__init__.py` files lightweight. The top-level agent package may
re-export stable core classes and use lazy exports for convenience, but it
should not eagerly import the full DV environment, tests, and virtual sequence
library. Cocotb testbenches should import the explicit pyUVM registry module for
registration side effects instead of relying on `import <agent>` to load the
entire bench.

## Clock and Reset Management

Use `clk_rst_agent` whenever the environment needs:

- clock generation
- reset assertion/deassertion control
- delay insertion
- reset-sensitive stimulus coordination

The release refactored reset handling in this direction specifically to remove hidden wiring and make reset behavior reusable across environments.

## TileLink Usage

For TileLink-based environments, use `hw/dv/py/tl_agent` as the reference implementation.

The package provides:

- host/device agents
- a monitor and scoreboard
- sequence items
- directed and randomized sequence libraries
- a base environment and base test
- coverage support

The regression configuration at `hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson` is the primary example of how to package and run a Python block-level verification environment through `dvsim`.

## Test and Sequence Configuration

Tests and sequences should be configured through explicit config and parameter objects rather than through hidden global database state.

Recommended practice:

- keep environment-level knobs in environment config classes
- keep sequence-level knobs in test-sequence parameter objects
- pass configuration explicitly from the test into the environment and sequences
- use plusargs only for run-time control points that need to be exposed to regression tooling

This matches the cleanup performed in the release when ConfigDB usage was removed from the Python flow.

`uvm_test` and `uvm_test_seq` have different import requirements. pyUVM test
classes selected by short `uvm_test` names must be imported before
`uvm_root().run_test()` so their factory registration is visible. Sequence
classes selected by fully qualified `uvm_test_seq` paths can be resolved by the
base test at run time.

## Register Model Usage

For register-based verification, use the `pyral` and `dv_lib` register overlay infrastructure.

This supports:

- building register and field models in Python
- frontdoor access through protocol adapters
- test sequences that operate on register abstractions instead of raw bus transactions

The `tl_agent_ral` package is the reference path for connecting a Python register model to a TileLink transport.

## Running Regressions

The standard regression flow in this release is based on `dvsim`.

This release was validated with Python 3.12. Users adopting this flow should run it from a Python 3.12 environment and ensure that the selected simulator binary is available on `PATH`.

Example:

```bash
source <python-3.12-venv>/bin/activate
PATH=<simulator-bin-dir>:$PATH \
./util/dvsim/dvsim.py \
  ./hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson \
  --run-opts "+max_quit_count=40 +print_char_len=80" \
  -i all \
  --cov \
  -r 5
```

If you need a clean standalone run without reusing an existing scratch area, add `--scratch-root /tmp/<run-name>`.

## Practical Guidance

- Keep framework code in `dv_lib` generic and reusable.
- Keep protocol behavior inside the relevant agent package.
- Use `clk_rst_agent` instead of rolling custom reset logic in each environment.
- Use the shared reporting/logging infrastructure so Python logs stay consistent with SV flows.
- Use reseeded regressions for meaningful coverage evaluation; single-reseed runs can under-represent final coverage.

## Reference Starting Points

These files are the best starting points when adopting the flow:

- `hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson`
- `hw/dv/py/tl_agent/dv/tb/test_tl_agent_env.py`
- `hw/dv/py/tl_agent/dv/pyuvm_registry.py`
- `hw/dv/py/tl_agent/dv/tests/tl_agent_base_test.py`
- `hw/dv/py/tl_agent/dv/env/tl_agent_env.py`
- `hw/dv/py/tl_agent/dv/tl_agent_config_parameters.py`
- `hw/dv/py/tl_agent/dv/tl_agent_test_seq_parameters.py`
- `hw/dv/py/clk_rst_agent/clk_rst_agent.py`
- `hw/dv/py/dv_lib/dv_base_test.py`
- `hw/dv/py/dv_lib/dv_base_env.py`
