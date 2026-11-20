<!--
Copyright Konrad Jansen, Vincent Quentin Ulitzsch, Niclas Kuehnapfel
Licensed under the Apache License, Version 2.0, see LICENSE for details.
SPDX-License-Identifier: Apache-2.0
-->

# Resiliator fault-injection testbench (Egret Ibex, lockstep)

[Resiliator][resiliator] exhaustively evaluates a hardware/software combination
against single bit-flip fault injection. It runs one simulation per
`(cycle, flip-flop)` pair, compares each against a golden run, and reports which
flips bypass a security property.

This testbench points it at the Egret Ibex core **with the dual-core lockstep
shadow core enabled**, running a deliberately unhardened firmware that emulates an
authentication procedure (see `fw/auth_check.c`). 

This Resiliator setup flags any single bit-flips that change the 
program-visible outcome of a software, but do not raise a major alert.


[resiliator]: https://github.com/kjnsen/resiliator

## Layout

| Path | Purpose |
| --- | --- |
| `ibex_resiliator_top.sv` | DUT wrapper with Resiliator's required `(clk, rst, fail, gpio)` interface |
| `ibex_resiliator.core` | FuseSoC configuration files |
| `ibex_resiliator_waivers.vlt` | Verilator lint waivers |
| `fw/` | The firmware under attack. |

Supporting pieces elsewhere:

- `//third_party/verilator:resiliator` — the Verilator fork that provides
  `--resiliator`, built alongside the stock Verilator.
- `hw/vendor/kjnsen_resiliator/` — vendored Resiliator sources. `sim_main.cpp`
  is compiled into the model by FuseSoC, so it has to live in the source tree
  rather than in a Bazel external repository.
- `ci/scripts/run-resiliator-campaign.py` — the nightly entry point.

## Running it

Build the model and the firmware:

```sh
./bazelisk.sh build \
  //hw/top_egret/dv/resiliator:verilator_resiliator_ibex \
  //hw/top_egret/dv/resiliator/fw:auth_check_hex
```

Run the full campaign the way CI does:

```sh
./ci/scripts/run-resiliator-campaign.py egret
```

The simulator writes into `resiliator_out/`.

The firmware implements two ways to encode the result of the authentication check, branch-less and branching.
By default, this setup tests the branch-less version. To the branch variant instead, point the campaign
at `//hw/top_egret/dv/resiliator/fw:auth_check_branch_hex`.


## Scoping the campaign

The `--resiliator` flag in `ibex_resiliator.core` takes a hierarchical prefix;
every flip-flop at or below it becomes an injection site.

The prefix starts at the top module name, with no leading `TOP.`:

| Prefix | Covers |
| --- | --- |
| `ibex_resiliator_top.u_core` | main core, shadow core, register files, icache (default) |
| `ibex_resiliator_top.u_core.gen_lockstep.u_ibex_lockstep` | the lockstep shadow core alone |
| `ibex_resiliator_top.u_core.u_ibex_core` | the main core alone |

Use `.` separators, never `__DOT__`, and do not add `__PVT__`.

A wrong prefix silently targets nothing rather than erroring, so check the line
Verilator prints during the build:

```
- Resiliator: Considering all signals with prefix ibex_resiliator_top.u_core (N total, emitted N of them)
```

The `ci/scripts/run-resiliator-campaign.py` script fails the job if the
campaign reports `Total Flip-Flops : 0` in order to avoid silent failures in case, e.g., 
a part of the design is renamed.
