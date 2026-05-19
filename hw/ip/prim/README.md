# Hardware Primitives

## Concepts

Having reusable components is one way to manage complexity and reduce the amount of work needed in a hardware design.
Modules, a standard language feature in HDLs, define their abstraction boundary using ports (a finite set of wires via which signals move in and out of the module) and parameters (compile time constant inputs which control features of the module which would otherwise be static, such as the number of wires in each port).
Common low-level design patterns and well-understood or optimized circuits can be abstracted and implemented as modules.

This repository provides a number of these low-level reuseable components, referred to as **primitives** (not to be confused with the built-in [SystemVerilog](https://ieeexplore.ieee.org/document/8299595) `primitive` building block).
There is no strict limit on the size of the logic inside a primitive, but they tend to be small and fixed-function.
Examples include fifos, counters, arbiters, synchronizers and codecs.

There may be different implementations of a given primitive, all implementing the same fixed function but with different trade-offs in how this is achieved.
A primitive implementation may be made of lower level components which can be created in the physical hardware or technology that is being targeted.
In ASIC or FPGA targets, the lower level components may be macro cells or other fixed-function hardware blocks.
An alternative lowering could be to gate-level models of an equivalent hardware implementation, where additional information is added to increase simulation accuracy for prediction of timing and power characteristics.

Having multiple primitive implementations allows tools to infer a combination of lower level components that best implement the circut functionality that is described.
There are many reasons that we may wish to constrain or modify our source files to control inferencing of a set of hardware components to make up a final circuit.

## Primitive Implementations & Libraries

Primitives exist at a low level of RTL abstraction where it may be desirable under different circumstances to swap-out implementations to obtain better optimized hardware.
For this reason, a primitive should keep the same name and set of ports for all implementations.
This minimizes the changes required for different implementations of a primitive to be substituted for each other.

However, not all primitives need to have multiple implementations.
- Primitives with a single generic implementation, where any lowering process is able to infer a suitable hardware implementation from language-level RTL features are **technology-independent primitives**.
- Primitives with multiple implementations, each of which may be optimized for or targeted towards a certain hardware platform are **technology-dependent primitives**.

Technology-dependent primitive implementations may be grouped together into **technology libraries**.
For example, a technology library of primitive implementations may be created for a certain ASIC technology, where the implementations are optimized for desirable synthesis characteristics for that target.

Within the Pavona repository the following primitive libraries are provided:
- `hw/ip/prim_xilinx/`: for Xilinx 7-Series synthesis targets
- `hw/ip/prim_ultrascale/`: for Xilinx Ultrascale synthesis targets
- `hw/ip/prim_asap7/`: a prim library based on the open-source [ASAP7](https://github.com/The-OpenROAD-Project/asap7) library
- `hw/ip/prim_generic/`: a generic library for technology-dependent prims (implements the same prims as the above technology-specific libraries)
- `hw/ip/prim/`: a technology-independent library of prims for any hardware target

For each technology-dependent primitive, there should be an implementation that is 'generic' in that it is constructed using language-level RTL constructs, and can be consumed by most downstream tooling.
These implementations are commonly used as input to simulation engines for verification and as a functional reference.

While primitives are defined primarily by their interface, SystemVerilog does not allow a module interface to be defined without an implementation.
This is unlike constructs in other languages such as Abstract Methods and Interfaces in Java or Traits in Rust.
To determine the interface for a primitive (the module ports and parameters), consult the generic module implementation.

### Virtual Primitives

Pavona by default utilizes the *[FuseSoC][]* build system and package manager to manage RTL at a fileset level.
FuseSoC *[virtual cores][]* allow FuseSoC to swap in a chosen implementation of a module without changing the RTL instantiation itself.
These can be thought of as similar to virtual methods in C++ or SystemVerilog.

[FuseSoC]: https://github.com/olofk/fusesoc
[virtual cores]: https://fusesoc.readthedocs.io/en/stable/user/build_system/virtual_cores.html

All technology-dependent primitives in Pavona use virtual cores to allow them to be substituted at build time.
For this reason, they can also be referred to as **virtual primitives**.

FuseSoC cores can be marked as an implementation of another virtual core.
The virtual core is given a unique identifier representing its vendor, library, name, and (optional) version ([VLNV][]), and does not exist as a named `.core` file in the tree.
Taking [`hw/ip/prim_generic/prim_generic_flop_2sync.core`](../prim_generic/prim_generic_flop_2sync.core) as an example, you will see the following at the head of the file:

[VLNV]: https://fusesoc.readthedocs.io/en/stable/user/build_system/core_files.html#the-core-name-version-and-description

```yaml
CAPI=2:
name: "lowrisc:prim_generic:flop_2sync"
description: "Generic implementation of a flop-based synchronizer"
virtual:
  - lowrisc:prim:flop_2sync
```
The virtual core VLNV is `lowrisc:prim:flop_2sync`, and one implementation of it is `lowrisc:prim_generic:flop_2sync`.
As a virtual primitive, the interface (module name and ports) for `flop_2sync` is common among all implementations, and hence all instantiations.
Fundamentally, if multiple modules with the same name and ports are available, controlling the include paths and fileset inputs to a tool allows FuseSoC to select which module will be used to provide the implementation.

Cores that depend on a virtual primitives are more adaptable to different design specifications.
Any concrete implementation of a virtual primitive must be selected at build time.
For example, a core can depend on virtual core `lowrisc:prim:flop_2sync` and then at build time specify that it wants to use the `lowrisc:prim_generic:flop_2sync` implementation rather than any other `flop_2sync` for the given build.

If a virtual core cannot be resolved because no implementations are found or specified at build time, a "conflicting-requirements" error will be generated by the FuseSoC solver.

It is still possible and valid for a core to depend only on a specific implementation of a technology-dependent primitive; however, the implementation cannot be substituted at build time in this case, and it functions as a normal FuseSoC core.

The following section further describes the resolution process.

### Resolution of Concrete Implementations

When invoking FuseSoC, a target in a core file is selected to choose the flow we wish to run.
Targets can depend on one or more 'filesets' defined within the core, and each fileset can optionally depend on other cores.
Therefore, when FuseSoC is run a dependency graph comprised of cores and filesets is constructed.

If a fileset depends on a virtual core, the virtual core's concrete implementation must be resolved at build time.

To resolve a virtual core, at least one corresponding concrete implementation must exist in the target dependency tree.
If there is exactly one, FuseSoC automatically selects it.
If there are multiple implementations present, the FuseSoC solver expects one of them to be unambiguously signalled via [mappings](https://fusesoc.readthedocs.io/en/stable/user/build_system/mappings.html), and will result in a 'conflicting-requirements' build time error in the absence of such explicit directives.

If multiple mappings exist within the dependency tree, but no mapping is explicitly specified, the following build time error will be generated:
```
RuntimeError: The following sources are in multiple mappings:
	{<Virtual_VLNV>, ...}.
```
If no mappings are provided but a virtual core cannot be resolved, an implementation is chosen non-deterministically from all known cores in the input libraries that implement this virtual core:
```
WARNING: Non-deterministic selection of virtual core <Virtual_VLNV> selected <Concrete_VLNV>
```

Many targets will choose to resolve their virtual cores by only including one implementation in their dependencies.
Top-level cores will typically specialize generic systems and modules for a particular hardware target or application by adding constraints and wrappers for that target.
One part of this may be choosing a technology library to resolve all technology-dependent primitives to implementations specialized or optimized for the given application.
To reduce the hassle of pulling in implementations for all virtual cores in a given technology library, this repository's built-in prim libraries provide an `:all` core, e.g. `lowrisc:prim_generic:all` or `lowrisc:prim_xilinx_ultrascale:all`.
For example, the core [`hw/top_earlgrey/chip_earlgrey_cw310.core`](../../top_earlgrey/chip_earlgrey_cw310.core) targeting a synthesis for a specific Xilinx FPGA depends on `lowrisc:prim_xilinx:all` to select a Xilinx Series-7 technology library.

### Mappings

Fusesoc core files may contain a `mapping` key, which can define injective/one-to-one mappings from one core to be replaced by another core.
In this repository, mappings are typically used to link virtual cores to an implementation.
Passing `--mapping=<VLNV>` via the CLI will cause the FuseSoC solver to use the mappings specified in that VLNV's core file.
The mapping applies to all uses of the virtual core anywhere in the dependency tree.
The concrete implementation core need only be discoverable in the input libraries, not in the target dependency tree.

An example set of mappings for the Xilinx technology library can be found in the following core file shown below.
The Xilinx-specific technology-dependent primitives are first added to the dependency tree under the depend keyword.
This provides the option of virtual primitive resolutions to Xilinx-specific implementations.
If it remains the only implementation in the dependency tree, it will be automatically chosen.
If there are many technology libraries in the tree, `--mapping=lowrisc:prim_xilinx:all:0.1` must be explicitly passed via the CLI for the Xilinx implementations to be chosen.
There are not Xilinx specific implementations for all primitives, so cores in this repo typically fall back to the generic implementation in those cases.

```yaml
# hw/ip/prim_xilinx/prim_xilinx.core
name: "lowrisc:prim_xilinx:all:0.1"
description: "Xilinx 7-series prim library"

filesets:
  files_rtl:
    depend:
      - lowrisc:prim_xilinx:prim_pkg
      - lowrisc:prim_xilinx:and2
      - lowrisc:prim_xilinx:buf
      - lowrisc:prim_xilinx:clock_buf
      - lowrisc:prim_generic:clock_div
      - lowrisc:prim_xilinx:clock_gating
      - lowrisc:prim_generic:clock_inv
      - lowrisc:prim_xilinx:clock_mux2
      # ...

mapping:
  "lowrisc:prim:and2"         : lowrisc:prim_xilinx:and2
  "lowrisc:prim:buf"          : lowrisc:prim_xilinx:buf
  "lowrisc:prim:clock_buf"    : lowrisc:prim_xilinx:clock_buf
  "lowrisc:prim:clock_div"    : lowrisc:prim_generic:clock_div
  "lowrisc:prim:clock_gating" : lowrisc:prim_xilinx:clock_gating
  "lowrisc:prim:clock_inv"    : lowrisc:prim_generic:clock_inv
  "lowrisc:prim:clock_mux2"   : lowrisc:prim_xilinx:clock_mux2
  # ...
```

One specific use of mappings is the lints for each block, such as the lint target for the UART in [`hw/ip/uart/uart.core`](../uart/uart.core).
At the HWIP level, the UART is described generally, so its dependencies do not contain any concrete primitive implementations.
Instead, the [DVSim verification tool](../../../util/dvsim/README.md) passes a set of mappings via CLI flags to FuseSoC to resolve all virtual cores for the specific linting job.
This allows the block to be linted for multiple different primitives (and top-level constants).

Mappings may be present in top-level core files, e.g. in [`hw/top_earlgrey/top_earlgrey.core`](../../top_earlgrey/top_earlgrey.core) (depicted below), to specialize block-level flows for top specific implementations, as described previously.

```yaml
# hw/top_earlgrey/top_earlgrey.core
name: "lowrisc:systems:top_earlgrey:0.1"
description: "Technology-independent Earlgrey toplevel"

mapping:
  "lowrisc:virtual_constants:top_pkg": "lowrisc:earlgrey_constants:top_pkg"
  "lowrisc:virtual_constants:top_racl_pkg": "lowrisc:earlgrey_constants:top_racl_pkg"
  "lowrisc:systems:ast_pkg": "lowrisc:systems:top_earlgrey_ast_pkg"
  "lowrisc:virtual_ip:flash_ctrl_prim_reg_top": "lowrisc:earlgrey_ip:flash_ctrl_prim_reg_top"
```

The following example shows how the UART lint flow is specialized for the earlgrey top.
```yaml
# hw/top_earlgrey/lint/top_earlgrey_lint_cfgs.hjson
{
  name: uart
  fusesoc_core: lowrisc:ip:uart
  import_cfgs: ["{proj_root}/hw/lint/tools/dvsim/common_lint_cfg.hjson"]
  additional_fusesoc_argument: "--mapping=lowrisc:systems:top_earlgrey:0.1"
  rel_path: "hw/ip/uart/lint/{tool}"
},
```

Mappings cannot be used to override a virtual core which has already been resolved to a implementation in the target dependency tree.

## User Guide

### Using primitives

Primitives are normal SystemVerilog modules, and can be used as usual:
1. Instantiate it like a normal SystemVerilog module.
   ```systemverilog
   prim_fifo_sync #(
     .Width   (8),
     .Pass    (1'b0),
     .Depth   (TxFifoDepth)
   ) u_uart_txfifo (
     .clk_i,
     // ..
     .err_o   ()
   )
   ```
2. Add it as a dependency in the FuseSoC core file.
   ```yaml
   name: "lowrisc:ip:uart:0.1"
   description: "uart"
   filesets:
     files_rtl:
       depend:
         - lowrisc:virtual_constants:top_pkg
         - lowrisc:prim:prim_fifo_sync
   ```

### Creating a technology library

To create a technology library in the Pavona repo, follow these steps:

1. Choose a name for the new technology library.
   For upstreaming into the official Pavona repository, names are ideally all lower-case and very specific (rather than a generic name like `asic`).
2. Create a directory in `hw/ip` with the prefix `prim_` followed by the name of your technology library.
3. Copy `hw/ip/prim_generic/prim_generic.core` into the new directory renaming it to match your primitive library, e.g. `hw/ip/prim_<tech_lib>/prim_<tech_lib>.core`
   Change the vendor and name in this file, e.g. `lowrisc:prim_generic` would become `<vendor>:prim_<tech_lib>` to match your chosen vendor name.
   Also, edit the description to better describe the specific implementation.
4. For every primitive implemented by your library:
   1. Copy across the generic implementation into your library.
      * e.g., Run `cp hw/ip/prim_generic/rtl/prim_flop.sv hw/ip/prim_<tech_lib>/rtl/prim_flop.sv`.
   2. Make your changes to the implementation without modifying the module name, ports or removing parameters.
   3. Copy the generic primitive's core description into your library.
      * e.g., `cp hw/ip/prim_generic/prim_generic_flop.core hw/ip/prim_<tech_lib>/prim_<tech_lib>_flop.core`.
   4. Edit this copied primitive core file so that it has the new primitive library name.
      * e.g., Replace `lowrisc:prim_generic:flop` with `<vendor>:prim_<tech_lib>:flop`.
   5. Then in the library's main core file, replace all instances of the generic implementation with your specific implementation.
      * e.g., In `hw/ip/prim_<tech_lib>/prim_<tech_lib>.core`, replace `lowrisc:prim_generic:flop` with `<vendor>:prim_<tech_lib>:flop` (again).

You don't have to have your own implementation for every primitive.
You can rely on the generic implementation or even another library's implementation for other primitives.

Technology libraries also do not have to live in the Pavona repository.
If they do not, you need to make sure the path to them is given to FuseSoC with either an additional `--cores-root=` argument or set in `fusesoc.conf`.

### Selecting a technology library

[Resolution of Concrete Implementations](#resolution-of-concrete-implementations) outlines how technology libraries are selected.

If you have your own target which requires a particular primitive, you should add the technology library's VLNV to its dependencies.
[`hw/top_earlgrey/chip_earlgrey_cw310.core`](../../top_earlgrey/chip_earlgrey_cw310.core) is an example of an core requiring a particular technology library--namely `lowrisc:prim_xilinx:all`.
You'll notice this VLNV in its dependencies.

If you are running a target which supports different technology libraries, then you should use mappings to select the technology library you would like to use.
In some cases, a default technology library may already by included, but this will be removable using FuseSoC CLI *[flags][]* to modify the build process.
You should provide the `fileset_partner` flag to disable the default implementation, as well as your mapping to select an alternate implementation.

[flags]: https://fusesoc.readthedocs.io/en/stable/user/build_system/flags.html

As an example:
```yaml
# hw/top_earlgrey/chip_earlgrey_asic.core
name: "lowrisc:systems:chip_earlgrey_asic:0.1"
description: "Earlgrey chip level"

filesets:
  files_rtl:
    depend:
      - lowrisc:systems:top_earlgrey:0.1
      - lowrisc:systems:top_earlgrey_pkg
      - lowrisc:systems:top_earlgrey_padring
      - lowrisc:earlgrey_ip:flash_ctrl_prim_reg_top
      - "fileset_partner ? (partner:systems:top_earlgrey_ast)"
      - "fileset_partner ? (partner:systems:top_earlgrey_scan_role_pkg)"
      - "fileset_partner ? (partner:prim_tech:all)"
      - "fileset_partner ? (partner:prim_tech:flash)"
      - "!fileset_partner ? (lowrisc:systems:top_earlgrey_ast)"
      - "!fileset_partner ? (lowrisc:earlgrey_systems:scan_role_pkg)"
      - "!fileset_partner ? (lowrisc:prim_generic:all)"
      - "!fileset_partner ? (lowrisc:prim_generic:flash)"
```

```sh
fusesoc \
    --cores-root=$REPO_TOP \
    run \
    --flag fileset_partner \                   # Disable default implementation
    --mapping <vendor>:prim_<tech_lib>:all \   # Select alternate implementation via mappings
    lowrisc:systems:chip_earlgrey_asic
```

### `prim_asap7` example

[ASAP7](https://github.com/The-OpenROAD-Project/asap7) is an open-source standard-cell library.
Each standard-cell instance name is prefixed with a `u_size_only_` such that these instances can be easily identified during synthesis and preserved.

#### Important synthesis constraints for keeping important redundant constructs

The basic prim instances cannot be removed or merged with other cells through logic optimization or constant propagation as this would remove important security countermeasures from the design.
All instantiated basic ASAP7 gates (`buf`, `mux2`, `inv`, `clock_gating`, `and2`, `xor2`, `xnor2`, `flop`) should be instantiated with a name prefix of `u_size_only_` such that preserve attributes can be set during synthesis.
The syntax to set a preserved attribute varies across tool providers.

To make sure the right constraints are applied, a simple example design, [`prim_sdc_example`](./prim_sdc_example.core), is provided.
This design can be synthesized, and its netlist can be analyzed to verify that the correct constraints are applied and all important cells are preserved.

The required files for synthesis can be generated with the following command:

```shell
fusesoc  --cores-root . \
		 run \
		 --target=syn \
		 --flag fileset_partner \
		 --mapping lowrisc:prim_asap7:all \
		 --setup \
		 --build-root build lowrisc:prim:sdc_example
```

By setting the `fileset_partner` flag, the generic prim implementation is not used, and the one provided through the mapping argument is used instead.
Please note, on designs with other technology dependent files, the `fileset_partner` flag also selects other technology specific implementations (e.g. OTP, Flash, JTAG, AST, pads).
If those are not used, they can be mapped to the generic implementations.

#### Checks on the generated netlist

After synthesizing the top module `prim_sdc_example` the following checks should be performed on the netlist:

1. In the synthesized netlist, the following number of size_only instances must be present:

| cell names |  buf  | and2 |  xor  |  xnor  | flop | tie | clock_mux2 | clock_gating |
| -----------|  ---- |------|-----  |------  |------|-----|------------|--------------|
| #instances |  328  |  56  |  120  |  56    |  252 |  64 |  2         |  2           |

2. None of the `test_*_o` signals can be driven by a constant 0 or 1.
   The instantiated `size_only` instances must prevent logic optimizations and keep the output comparators.
   This can be checked with the synthesis tool, e.g. `check_design -constant`

3. None of the buffers or flip flops in this example design are unloaded if constraints are applied correctly.
   This can be checked by the synthesis tool, e.g. `check_design -unloaded_comb/-unloaded_seqs`

4. `lc_en_o`, `mubi_o` signals cannot be driven to a constant value because optimization or constant propagation across preserved instances is not allowed.

5. `lc_en_i`, `mubi_i` signals can only be connected to variables, or legal values (`MuBi4True`, `MuBi4False`, `On`, `Off`)

If all checks are successful, the same constraints can be applied to the full design.
The script [`utils/design/check-netlist.py`](../../../util/design/README.md#netlist-checker-script) can be used to report a summary of `size_only` cells in a netlist.
It can also automate an initial version of checks (4) and (5), but it *does not* replace a final manual inspection of the netlist.
