# Getting Started with the Pavona pyUVM Simulations

This guide describes how to create a clean Python environment and run the
Pavona TileLink pyUVM regression with Verilator.

Run all commands from the root of the Pavona checkout.

## Prerequisites

Install the following tools before creating the Python environment:

- Python 3.12
- Verilator
- a C/C++ build toolchain
- `make`

### Install the prerequisites on macOS

Install the Apple command-line developer tools, which provide the compiler and
`make`:

```bash
xcode-select --install
```

Install [Homebrew](https://brew.sh/) if `brew` is not already available, then
install Python 3.12 and Verilator:

```bash
brew install python@3.12 verilator
```

On Apple Silicon, Homebrew normally installs executables under
`/opt/homebrew/bin`. On Intel macOS, it normally uses `/usr/local/bin`. Add the
appropriate directory to `PATH` if the commands are not found.

### Install the prerequisites on Ubuntu

Ubuntu 24.04 provides Python 3.12 and the other required tools through `apt`:

```bash
sudo apt update
sudo apt install python3.12 python3.12-venv build-essential make verilator
```

For an older Ubuntu release or another Linux distribution that does not package
Python 3.12, install it using the distribution's supported additional
repository, [pyenv](https://github.com/pyenv/pyenv), or the
[Python source release](https://www.python.org/downloads/source/). Install
Verilator using the distribution package manager or the
[Verilator installation guide](https://verilator.org/guide/latest/install.html).

Windows users should run the flow in WSL2 with Ubuntu and follow the Ubuntu
instructions above.

The Python requirements install FuseSoC, cocotb, pyuvm, pyvsc, pyucis, Z3, and
the other Python packages used by the simulation flow. Pavona resolves pyvsc's
solver dependency through a local pure-Python `pyboolector` compatibility wheel
backed by `z3-solver`; this avoids native PyBoolector source builds on Linux
arm64 while keeping pyvsc's released package metadata satisfied.

Check the external tools:

```bash
python3.12 --version
verilator --version
make --version
```

The Python version should report Python 3.12. Ensure that the desired Verilator
installation is on `PATH`.

## Create a Fresh Environment

Create and activate a virtual environment:

```bash
python3.12 -m venv .venv3.12
source .venv3.12/bin/activate
```

Install the complete, hashed Pavona dependency set:

```bash
python -m pip install --require-hashes -r python-requirements.txt
```

No separate pyuvm, cocotb, coverage, or FuseSoC installation is required.

Confirm that the environment is consistent:

```bash
python -m pip check
python -c "import pyuvm; print(pyuvm.__version__)"
fusesoc --version
cocotb-config --version
```

The checked-in environment currently uses pyuvm 5.0.0, cocotb 2.1.0, pyvsc
0.9.4, and a Z3-backed pyboolector compatibility wheel.

## Run the TileLink Smoke Test

The smoke test is the quickest end-to-end check:

```bash
./util/dvsim/dvsim.py \
  ./hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson \
  --scratch-root /tmp/pavona-tl-agent-smoke \
  -i tl_agent_smoke \
  -r 1
```

If Verilator is installed in a directory that is not already on `PATH`, prefix
the command with its binary directory:

```bash
PATH=/path/to/verilator/bin:$PATH \
./util/dvsim/dvsim.py \
  ./hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson \
  --scratch-root /tmp/pavona-tl-agent-smoke \
  -i tl_agent_smoke \
  -r 1
```

The result table should report one passing test.

## Run the Full TileLink Regression

Run all seven TileLink tests with one seed:

```bash
./util/dvsim/dvsim.py \
  ./hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson \
  --scratch-root /tmp/pavona-tl-agent-regression \
  -i all \
  -r 1
```

A successful run reports:

```text
Passing: 7
Total:   7
```

### Where the testbench lives

All paths below are relative to the Pavona repository root.

- `hw/dv/py/tl_agent/` contains the reusable Python TileLink agent: its
  configuration, sequence item, host and device drivers, monitors, sequencers,
  coverage model, and protocol-level sequence library.
- `hw/dv/py/tl_agent/dv/` contains the self-test environment for the agent,
  including DV-specific shared parameter classes such as
  `tl_agent_config_parameters` and `tl_agent_test_seq_parameters`.
- `hw/dv/py/tl_agent/dv/env/` contains the pyUVM environment, environment
  configuration, virtual sequencer, scoreboard, coverage component, and
  top-level virtual sequences.
- `hw/dv/py/tl_agent/dv/tests/` contains `tl_agent_base_test`, which constructs
  and configures the environment.
- `hw/dv/py/tl_agent/dv/tb/test_tl_agent_env.py` is the cocotb entry point. It
  selects the pyUVM test and starts `uvm_root().run_test()`.
- `hw/dv/py/tl_agent/dv/pyuvm_registry.py` imports pyUVM test classes that
  need registration before the cocotb entry point calls `run_test()`.
- `hw/dv/py/tl_agent/rtl/tl_agent_smoke.sv` is the SystemVerilog simulation
  top. It declares the clock, reset, and TileLink A- and D-channel signals used
  by cocotb.
- `hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson` defines the tests,
  regressions, runtime options, and Verilator build/run flow used by `dvsim`.
- `hw/dv/py/tl_agent/tl_agent_pyuvm_sim.core` is the FuseSoC simulation core
  that selects `tl_agent_smoke` as the Verilator top level.

The testbench also uses the shared infrastructure in:

- `hw/dv/py/dv_lib/` for the reusable pyUVM base classes, reporting, reset
  domains, configuration, and sequence control
- `hw/dv/py/interfaces/` for the cocotb clock/reset and TileLink signal wrappers
- `hw/dv/py/clk_rst_agent/` for clock, reset, and programmable-delay sequences

### TileLink agent testbench overview

This is an agent self-test rather than a test of a separate RTL TileLink
device. The SystemVerilog top is a signal container. Cocotb exposes those
signals to Python, and the pyUVM environment connects an active host agent and
an active reactive device agent to the same TileLink interface:

```text
dvsim
  -> FuseSoC and Verilator build tl_agent_smoke.sv
  -> cocotb starts test_tl_agent_env.py
  -> the pyUVM registry imports test classes for registration
  -> pyUVM creates tl_agent_base_test
  -> tl_agent_env creates:
       clock/reset agent
       delay agent
       TileLink host agent
       TileLink device agent
       virtual sequencer
       scoreboard
       coverage component
```

The host agent drives A-channel requests and accepts D-channel responses. The
device agent observes the requests, creates protocol-appropriate responses,
models byte-addressable memory, drives the D channel, and provides A-channel
ready signaling. Both agents monitor the shared interface independently.

The scoreboard compares the request observed by the host monitor with the same
request observed by the device monitor. It performs the equivalent comparison
for responses in the other direction. A mismatch is reported as a UVM error.
The host sequence also matches each response to its outstanding request using
the TileLink source ID.

`tl_agent_base_test` creates a 100 MHz clock, applies an initial five-cycle
power-on reset, binds the host and device agents to one reset domain, and
enforces the simulation timeout. The virtual sequencer coordinates host
traffic, reactive device behavior, delays, and additional resets. Enabling
coverage adds protocol and environment sampling without changing the test
stimulus.

The top-level `tl_agent` package is kept lightweight so that importing reusable
agent classes does not also import every self-test, environment, and virtual
sequence. pyUVM test registration side effects are explicit in
`dv/pyuvm_registry.py` instead. Virtual sequences named by fully qualified
`UVM_TEST_SEQ` paths are imported at run time by the base test.

### What each regression test does

#### `tl_agent_smoke`

This is the main randomized traffic test. The host sends 100 legal TileLink
requests by default, using the `TX_COUNT` value from the simulation
configuration. The traffic covers randomized reads and writes, addresses,
sizes, masks, source IDs, and request delays. The reactive device sequence
returns the appropriate `AccessAck` or `AccessAckData` response and models
byte-addressable memory for writes and reads.

The test is expected to:

- complete every request and receive a response with the matching source ID
- preserve the request and response ordering checked by the scoreboard
- produce no unexpected TileLink errors, UVM errors, or timeouts

#### `tl_agent_reset_smoke`

This runs the randomized smoke traffic with reset testing enabled. It performs
a randomized two to five reset loops. During the intermediate loops, reset is
triggered after a randomized delay of 50 to 100 clock cycles while traffic may
still be active. The last loop is allowed to complete without another reset.

The test is expected to:

- stop or cancel active sequences safely when reset is asserted
- reset the TileLink interfaces, drivers, monitors, and outstanding-request
  bookkeeping without leaving stale transactions
- restart cleanly after reset deassertion
- complete the final traffic loop without UVM errors or a timeout

#### `tl_agent_single`

This sends one legal `Get` request to address `0x24` with mask `0xf`. It is a
small deterministic check of the complete host-driver, monitor, reactive-device,
and response path.

The test is expected to capture one response and confirm that `d_error` is
clear. A missing response or an error response fails the test.

#### `tl_agent_protocol_err`

This generates one deliberately illegal TileLink request. The sequence
randomly selects a protocol violation such as an invalid opcode, illegal mask,
misaligned address, or unsupported transfer size.

The reactive device calculates the expected protocol status from the request.
The test is expected to receive a response with `d_error` asserted. A missing
response or a response without `d_error` fails the test.

#### `tl_agent_put_full_data`

This sends seven deterministic `PutFullData` writes. The cases exercise
one-byte, two-byte, and four-byte masks at the corresponding aligned addresses,
with different data patterns:

```text
Address  Mask  Data
0x20     0x1   0x11223344
0x21     0x2   0x55667788
0x22     0x4   0x99aabbcc
0x23     0x8   0xddeef001
0x20     0x3   0x12345678
0x22     0xc   0x87654321
0x20     0xf   0xabcdef01
```

The test is expected to receive a response for every write with `d_error`
clear. This verifies legal full-data opcode, size, address, and active-lane mask
combinations through the agent and device memory model.

#### `tl_agent_custom`

This uses the custom host sequence, which disables the normal protocol
constraints, to send a caller-controlled invalid request:

```text
Address: 0x23
Mask:    0xf
Data:    0x12345678
Size:    2
Opcode:  7 (invalid)
```

The test is expected to receive a response with `d_error` asserted. This proves
that a test can bypass normal random constraints to inject a precise malformed
transaction and still receive the expected device response.

#### `tl_agent_pending_reset`

This creates an intentional outstanding-transaction condition. The host starts
16 back-to-back randomized requests with no inter-request delay, while the
device delays each response by 50 to 80 cycles. Reset is asserted after 10
cycles, when requests are expected to remain pending.

The test is expected to:

- tolerate reset while requests or responses are outstanding
- cancel active traffic without deadlock or a stale-response failure
- clear and restart the reset-sensitive agent state
- complete the final non-reset loop without UVM errors or a timeout

For a more meaningful reseeded coverage run:

```bash
./util/dvsim/dvsim.py \
  ./hw/dv/py/tl_agent/dv/tl_agent_python_sim_cfg.hjson \
  --scratch-root /tmp/pavona-tl-agent-coverage \
  -i all \
  --cov \
  -r 5
```

`dvsim` prints the report and scratch-directory locations at the end of the
run.

### Find logs under the scratch directory

`--scratch-root` is the top of the output tree, not the directory that directly
contains the logs. `dvsim` adds the current Git branch and simulation
configuration below it:

```text
<scratch-root>/
  <branch>/
    tl_agent_python-sim-verilator/
```

For example, when running branch `py-dv-experimental` with:

```bash
--scratch-root /tmp/pavona-tl-agent-regression
```

the simulation output root is:

```text
/tmp/pavona-tl-agent-regression/
  py-dv-experimental/
    tl_agent_python-sim-verilator/
```

The important paths relative to that simulation output root are:

```text
default/build.log
0.<test-name>/latest/run.log
0.<test-name>/latest/results.xml
0.<test-name>/latest/env_vars
reports/latest/report.html
reports/latest/report.json
seeds/latest/seeds.txt
```

- `default/build.log` contains FuseSoC, Verilator compilation, and link output.
- `<reseed-index>.<test-name>/latest/run.log` is the main cocotb and pyUVM log
  for one test run. With `-r 1`, the reseed index is `0`.
- `results.xml` contains the cocotb test result for that run.
- `env_vars` records the environment passed to the build or test process.
- `report.html` is the human-readable regression summary.
- `report.json` is the machine-readable regression summary.
- `seeds.txt` records the random seeds used by the regression.

For example, the smoke-test run log is:

```text
<scratch-root>/<branch>/tl_agent_python-sim-verilator/
  0.tl_agent_smoke/latest/run.log
```

With multiple reseeds, replace `0` with the required reseed index. Each test
directory has a `latest` link or directory pointing to its most recent run.
The `passed/`, `failed/`, and `killed/` directories contain status links that
provide another quick way to locate individual jobs.

When coverage is enabled, the additional important paths are:

```text
<reseed-index>.<test-name>/latest/cov_db.xml
cov_merge/merged_cov/merged_cov.xml
cov_report/dashboard.txt
cov_report/dashboard.html
```

If a build fails, inspect `default/build.log` first. If compilation succeeds
but a test fails, inspect that test's `latest/run.log`.

## Start a New Shell

Reactivate the environment whenever a new shell is opened:

```bash
source .venv3.12/bin/activate
```

Then confirm that the environment executables are selected:

```bash
which python
which fusesoc
which cocotb-config
```

All three should resolve inside the virtual environment, except Verilator,
which is an external simulator installation.

## Troubleshooting

### `fusesoc: command not found`

Activate the virtual environment before running `dvsim`:

```bash
source .venv3.12/bin/activate
```

### `verilator: command not found`

Install Verilator or add its `bin` directory to `PATH`.

### Stale scratch-directory errors

Use a new scratch path for the next run:

```bash
--scratch-root /tmp/pavona-tl-agent-$(date +%s)
```

### Unexpected pyuvm behavior

Confirm that the released, locked version is installed:

```bash
python -m pip show pyuvm
```

Do not install pyuvm from a local development checkout unless the experiment
specifically requires unreleased pyuvm changes.

### Unexpected pyvsc solver behavior

Confirm that the locked pyvsc, pyboolector compatibility wheel, and Z3 packages
are installed:

```bash
python -m pip show pyvsc pyboolector z3-solver
```

The installed `pyboolector` package should be Pavona's local pure-Python
compatibility wheel and should list `z3-solver` as its backend dependency.
Do not replace it with the upstream native PyBoolector package when using the
checked-in dependency lock.

### Recreate the environment

If the environment has been modified during experimentation, create a new
virtual environment and reinstall `python-requirements.txt`. A clean
environment is generally faster to diagnose than an in-place dependency
downgrade.

## Updating the Dependency Lock

`pyproject.toml` is the source dependency declaration.
`python-requirements.txt` is generated from it and must not be edited manually.

After changing a dependency, regenerate the lock with Pavona's script:

```bash
./util/sh/scripts/gen-python-requirements.sh
```

The generator requires `uv`. Validate a regenerated lock by installing it with
`--require-hashes` in a fresh Python 3.12 environment and rerunning the full
TileLink regression.
