# pyUVM DV Experimental Release 0.1

## Summary

This release introduces the first consolidated Python UVM DV framework for the repository.
It establishes a reusable `dv_lib` foundation, adds protocol interfaces and agents for TileLink and clock/reset control, integrates Python RAL support, and connects pyUVM block-level environments into the existing `dvsim` and Verilator-based simulation flow.

## Major Additions

### Base Python DV framework

The `hw/dv/py/dv_lib` package now provides the core pyUVM verification scaffolding:

- base agent, driver, monitor, sequencer, environment, scoreboard, test, and virtual sequence layers
- sequence item and sequence core support
- environment and test configuration parameter handling
- reset-domain modeling
- seeded random support
- cocotb utility support
- pyuvm SV-UVM-style reporting integration aligned with SV-UVM usage

### Python protocol interfaces

The release adds reusable Python-side interfaces under `hw/dv/py/interfaces`:

- `clk_rst_if.py` for clock and reset interaction
- `tl_if.py` and `tl_widths.py` for TileLink signaling and width handling

These interfaces are the base integration layer used by the Python agents and tests.

### TileLink pyUVM agent

The `hw/dv/py/tl_agent` package now includes a full TileLink verification stack:

- host and device agents and drivers
- monitor and scoreboard support
- TileLink sequence item modeling
- sequencer and virtual sequencer support
- directed and randomized sequence libraries
- environment and base test infrastructure
- smoke, reset, protocol-error, and data-path oriented regression content

This release also includes deadlock fixes, regression bring-up, and coverage closure for the TL agent flow.

### Clock/reset agent

The release adds `hw/dv/py/clk_rst_agent` as a reusable clock/reset control component.
This agent centralizes clock generation, reset control, delay injection, and reset-oriented sequencing, and is used to simplify protocol environments that need structured reset behavior.

### Python RAL and register overlays

The release introduces Python register-model support through `hw/dv/py/pyral` and `dv_lib` register overlay classes:

- register, field, map, and memory abstractions
- adapter, predictor, and sequence support
- frontdoor/backdoor scaffolding
- base register overlay utilities in `dv_lib`

The `hw/dv/py/tl_agent_ral` package demonstrates this path with a TileLink-backed RAL environment and smoke/access sequences.

### DVSIM and Verilator integration

The release adds the infrastructure required to run pyUVM block-level testbenches through `dvsim` with Verilator:

- Verilator-specific `dvsim` configuration and makefile support
- pyUVM simulation core files
- plusarg and time parsing fixes
- simulation flow integration for Python-based testbenches
- UVM-style report summary, quit count, and final `TEST_STATUS` emission

This makes the Python DV environments runnable within the same operational flow used by the wider DV infrastructure.

### Reporting integration

Pavona's Python base test now uses pyuvm's SV-UVM-style reporting path:

- `uvm_test` creates and configures the shared pyuvm report server
- pyuvm owns report-server runtime options such as `UVM_VERBOSITY`,
  `max_quit_count`, `print_char_len`, and fail-on-warning/error/fatal policy
- Pavona emits report summary, final `TEST_STATUS`, coverage export, and
  report-server shutdown from `report_phase`
- test-level severity demotion remains available through
  `add_message_demotes(catcher)`
- the old Pavona reporting alias shims were removed in favor of direct public
  pyuvm imports

### Coverage support

The release adds pyUVM coverage collection and reporting support, including:

- agent/environment-level coverage hooks
- UCIS-oriented coverage merge and report scripts
- `dvsim` plumbing for coverage extraction and publication

## Architectural Changes

The most significant architectural change is the removal of ConfigDB-based wiring from the Python DV flow compared to SV DV flow.
Configuration and runtime connectivity are now handled more directly through environment and agent configuration objects.
This reduces hidden coupling, makes object dependencies clearer, and simplifies reset-sensitive agent composition.

The TileLink environment was also reworked to instantiate and rely on the new `clk_rst_agent`, rather than carrying ad hoc clock/reset handling internally.

## Stability and Parity Work

Python DV stack now behaves more like the existing SV-UVM infrastructure:

- logging semantics were enhanced to match SV expectations more closely
- verbosity behavior was refined
- centralized report summary, severity counts, quit count, and final
  `TEST_STATUS` are emitted through pyuvm reporting APIs
- reset-domain and vif handle issues were fixed
- reset testing was enabled and stabilized
- log output was cleaned up for release use

## Validation

This release snapshot was validated with the following regression flow.
Validation was performed with Python 3.12, using Verilator as the simulator.

```bash
source <python-3.12-venv>/bin/activate
PATH=<simulator-bin-dir>:$PATH \
./util/dvsim/dvsim.py \
  ./hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson \
  --scratch-root <tmp_dir> \
  --run-opts "+max_quit_count=40 +print_char_len=80" \
  -i all \
  --cov \
  -r 5
```

Observed result:

- build passed
- all 35 reseeded test runs passed
- coverage merge/report passed
- reported coverage score was 100.00%
- reset-enabled tests passed
- run logs contained `--- UVM Report Summary ---`, `Quit count : 0 of 40`,
  and `TEST_STATUS: PASSED`

## Release Commit Structure

This release branch was reconciled into a single consolidated commit:

`hw/dv/py: introduce the pyUVM DV framework, TileLink/clock-reset agents, Python RAL, coverage flow, and dvsim/Verilator integration`
