# Linting

# RTL Linting

Linting is a productivity tool for designers to quickly find typos and bugs at the time when the RTL is written.
Running lint is important when using SystemVerilog, a weakly-typed language, unlike other hardware description languages.
Linting is a critical part of high quality development.

The lint flow leverages lint rules that align with the [Verilog style guide](../../doc/contributing/style_guides/verilog_coding_style.md).
Our linting flow leverages FuseSoC to resolve dependencies, build file lists and call the linting tools. See [here](https://github.com/olofk/fusesoc) for an introduction to this open source package manager and [here](../../doc/getting_started/README.md) for installation instructions.

In order to run lint on a [comportable IP](../../doc/contributing/hw/comportability/README.md) block, the corresponding FuseSoC core file must have a lint target and include (optional) waiver files as shown in the following example taken from the FuseSoC core of the AES comportable IP:
```
filesets:

  [...]

  files_verilator_waiver:
    depend:
      # common waivers
      - lowrisc:lint:common
      - lowrisc:lint:comportable
    files:
      - lint/aes.vlt
    file_type: vlt

  files_ascentlint_waiver:
    depend:
      # common waivers
      - lowrisc:lint:common
      - lowrisc:lint:comportable
    files:
      - lint/aes.waiver
    file_type: waiver

  files_veriblelint_waiver:
    depend:
      # common waivers
      - lowrisc:lint:common
      - lowrisc:lint:comportable
  [...]

targets:
  default: &default_target
    filesets:
      - tool_verilator   ? (files_verilator_waiver)
      - tool_ascentlint  ? (files_ascentlint_waiver)
      - tool_veriblelint ? (files_veriblelint_waiver)
      - files_rtl
    toplevel: aes

  lint:
    <<: *default_target
    default_tool: verilator
    parameters:
      - SYNTHESIS=true
    tools:
      verilator:
        mode: lint-only
        verilator_options:
          - "-Wall"
```
Note that the setup shown above supports RTL style linting with the open source tool [Verible](https://github.com/google/verible/), with [Verilator](https://www.veripool.org/wiki/verilator), and with the commercial tool [AscentLint](https://www.realintent.com/rtl-linting-ascent-lint/).
In particular, Verible lint detects style elements that are in violation with the Verilog style guide.

The same lint target is reused for all three tools (we override the tool selection when invoking FuseSoC).
Lint waivers can be added to the flow by placing them in the corresponding waiver file.
In this example this would be `lint/aes.waiver` for AscentLint and `lint/aes.vlt` for Verilator.

All three linting tools mentioned above have been integrated with the `dvsim` regression tool.
In order to manually invoke any of the linting tools on a specific block, make sure that the corresponding linting tool is properly installed, step into the project root and call
```console
$ cd $REPO_TOP
$ util/dvsim/dvsim.py hw/top_egret/lint/top_egret_lint_cfgs.hjson --tool (ascentlint|verilator|veriblelint) --local --purge --select-cfgs <lint-config-name>
```
where `<lint-config-name>` is the name of the linting configuration as defined in the `top_egret_lint_cfgs.hjson` regression list (currently that file contains a lint configuration for all available comportable IPs and the top-level).

In order to run all defined configs in `top_egret_lint_cfgs.hjson` as a batch regression, just omit the `--select-cfgs` switch as follows:
```console
$ cd $REPO_TOP
$ util/dvsim/dvsim.py hw/top_egret/lint/top_egret_lint_cfgs.hjson --tool (ascentlint|verilator|veriblelint) --local --purge
```
The `purge` option ensures that the scratch directory is fully erased before starting the build.
The number of parallel workers can be set using `--max-parallel <number>`.

Linting is run on CI, and results are public.

# CDC Linting

Logic designs that have signals that cross from one clock domain to another unrelated clock domain are notorious for introducing hard to debug problems.
The reason is that design verification, with its constant and idealized timing relationships on signals, does not represent the variability and uncertainty of real world systems.
For this reason, maintaining a robust Clock Domain Crossing verification strategy ("CDC methodology") is critical to the success of any multi-clock design.
This holds for *Reset Domain Crossing* ("RDC") methodology as well.

Pavona currently has yet to standardize CDC and RDC linting.
