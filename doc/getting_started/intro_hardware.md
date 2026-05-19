# Pavona 102: Introduction to Hardware

Pavona's differentiating feature is its principled modular design that makes customizing IP blocks and top-level designs effortless.

[Pavona 101](./pavona_101.md) shows new users how to clone the repo, install system prerequisites, and run a basic chip-level simulation.
This guide builds on Pavona 101 by explaining the repository and infrastructure for hardware design and development.
After this guide, you will be able to make changes to existing top-level designs and run tests on them.

## Basic setup

This guide assumes you have set up your repository as described in [Pavona 101](./README.md).
Remember to activate your Python virtual environment.

## Repository structure

Change into the pavona directory and you'll find the following files:

```shell
$ cd pavona
$ ls
BLOCKFILE          apt-requirements.txt  python-requirements.txt
BUILD.bazel        bazelisk.sh           quality
CLA                bench                 release
CONTRIBUTING.md    book.toml             rules
LICENSE            ci                    signing
MODULE.bazel       compile_flags.txt     sw
MODULE.bazel.lock  doc                   third_party
NOTICE             hw                    toolchain
README.md          mypy.ini              util
SUMMARY.md         pyproject.toml        yum-requirements.txt
```

We explored some of the `sw/` directory in [Pavona 101](./README.md).
In there, you'll find:

* `sw/device/`, which contains software that will run on a Pavona top-level design.
This includes tests as well as the "Hello, World!" example from Pavona 101.
* `sw/host/`, which contains software that runs on the machine connected to a Pavona top-level design (the "host").

The other important directory is the `hw/` directory, which has several key subdirectories:

* `hw/ip/` contains block-level IP for the Pavona ecosystem that does not need further "templatization" (see the next section).
* `hw/ip_templates`, on the other hand, contains block-level IP that *does* need templatization.
* `hw/top_darjeeling`, `hw/top_earlgrey`, and `hw/top_englishbreakfast`, which represent the currently supported top-level reference designs in the Pavona project.

Top-level designs (or "tops") organize IP into a design suited for a particular purpose or implementation methodology.
We briefly introduce Pavona's three top-level designs here, but refer to their individual datasheets (located in each top directory's corresponding `doc/` directory) for more information.

* `top_earlgrey` is a full discrete root of trust design ready for tapeout.
* `top_darjeeling` is another root of trust design intended for integration within a broader SoC.
* `top_englishbreakfast` is a reduction of `top_earlgrey` designed to facilitate side channel analysis and fault injection experiments.

In these top-specific directories, you will also find another set of IP directories: `hw/top_*/ip` and `hw/top_*/ip_autogen`.
This brings us to a discussion of the three types of IP in Pavona:

## Three different types of IP

Pavona organizes IP in three different ways.
The first two are simple to understand:

* `hw/ip` contains IPs that are broadly applicable to any top and do not require customization (beyond the capabilities of SystemVerilog parameters).
* `hw/top_*/ip` contains IP that is specific to that top and is not intended to be used by another top.
This includes the Analog Sensor Top (AST) and crossbar IPs for both Earlgrey and Darjeeling, which are specific to their respective top.
Darjeeling contains a proxy for communication to the wider SoC, which is not meaningful in Earlgrey.

### IP collateral

In each IP directory, you'll find several directories:

* `data/` contains the IP block [Hjson](https://hjson.github.io), which forms the "single source of truth" for this IP block.
It contains information about inputs, outputs, registers, interrupts, and other crucial metadata about the IP block.
This file is used extensively in templatization and top generation.
`data/` also contains the testplan.
* `doc/` contains block-specific documentation, including a programmer's guide, theory of operation, and register map.
* `dv/` contains block-specific DV collateral, including a block-level testbench/environment and sequence library.
* Lastly, `rtl/` contains the block's design in SystemVerilog.

### IP templates

The third type of IP is an *IP template,* and is stored in `hw/ip_templates`.
IP templates form one of Pavona's key features: the ability to customize hardware for a specific top.
Templated IPs can be processed with Pavona tooling (discussed later) to generate a top-specific version of that IP.

SystemVerilog files in templated IPs look just like ordinary SystemVerilog files, except that they contain macros that allow arbitrary text substitution.
Templates are indicated with a `*.tpl` suffix.
Consider this snippet of the GPIO module at `hw/ip_templates/gpio/rtl/gpio.sv.tpl`:

```systemverilog
// General Purpose Input/Output module

`include "prim_assert.sv"

module ${module_instance_name}
  import ${module_instance_name}_pkg::*;
  import ${module_instance_name}_reg_pkg::*;
#(
  parameter logic [NumAlerts-1:0]           AlertAsyncOn              = {NumAlerts{1'b1}},
  // Number of cycles a differential skew is tolerated on the alert signal
  parameter int unsigned                    AlertSkewCycles           = 1,
  parameter bit                             GpioAsHwStrapsEn          = 1,
```

Note that this module doesn't have a name that looks like "gpio".
Instead, the syntax `${module_instance_name}` is substituted by Pavona tooling to provide the true name of this module. Templated IPs allow IP customization beyond what is capable by ordinary SystemVerilog parameterization.
Templated IPs are also widely used to help maintain consistency between disparate parts of the code base, from hardware to software to drivers and even documentation.

As part of the top generation flow, top-level designs that use IP templates in `hw/ip_templates` will pass parameters to these templates, which in turn get generated and placed in `hw/top_*/ip_autogen`.
For example, Darjeeling uses the GPIO IP, so the Darjeeling-specific GPIO module RTL is in `hw/top_darjeeling/ip_autogen/gpio`.

## Hjson, the single source of truth

In Pavona, most operations start from a top-level design.
All of the information about a top-level design is centralized in a single Hjson file stored in a top-specific directory.
An Hjson file is just like an ordinary JSON file, except that it allows comments.
Hjson files are the primary way of encoding metadata in Pavona.
As such, this top-level file is often called "the single source of truth".

For instance, the Darjeeling design is entirely contained in `hw/top_darjeeling/data/top_darjeeling.hjson`.
The following snippet shows a very small number of fields:

```json
{ name: "darjeeling",
  ...
  clocks: {
    srcs: [
      { name: "main", aon: "no",  freq: "1000000000" }
      { name: "io",   aon: "no",  freq: "250000000" }
      ...
    ],
  },
  ...
  module: [
    { name: "uart0",
      type: "uart",
      clock_srcs: {clk_i: "io"},
      clock_group: "peri",
      ...
      base_addr: {
        hart: "0x30010000",
      },
    },
  ...
    { name: "gpio",
      type: "gpio",
      template_type: "gpio",
      clock_srcs: {clk_i: "io"},
      clock_group: "peri",
      reset_connections: {rst_ni: "lc_io"},
      base_addr: {
        hart: "0x30000000",
      },
      param_decl: {
        GpioAsHwStrapsEn: "1",
        GpioAsyncOn: "1"
      },
      ipgen_params: {
        num_inp_period_counters: 8
      }
      attr: "ipgen"
    },
...
  ]
}
```

Here, this snippet says that there is a 1 GHz main clock and a 250 MHz IO clock, neither of which is always-on.
Darjeeling instantiates a UART called "uart0" (among many other modules), clocked with the slower IO clock, and on the peripheral clock domain.
The base address for its control/status register file is at 0x30010000.
Darjeeling also instantiates the GPIO IP template, as indicated by the "`template_type`" key, with 8 input period counters (`num_inp_period_counters`).

The top-level Hjson, among other things, identifies clocks, power domains, reset domains; address spaces and memories; module instantiation and connection; as well as pin connections to and from the top-level design.

## The top generation flow

Pavona's Architectural Composition Engine (ACE) transforms a top-level Hjson into RTL, DV, software, documentation, and more for a top-level design.
ACE is composed of many tools in the util/ directory whose names typically end in "gen": topgen, ipgen, dtgen, reggen, and so forth.

To run ACE, pass this invocation to the Makefile.
(If this fails with a missing "hjson" package, remember to source your Python virtual environment, then try again.)

```shell
$ make -C hw all
make: Entering directory ...
.../util/topgen.py -t .../hw/top_darjeeling/data/top_darjeeling.hjson ... -o hw/top_darjeeling
   ...
(cd ...; find . -name "*.md" -print0 | \
 xargs -0 -P 8 -I '{}' ./util/cmdgen.py -u {})
INFO:__main__:hw/top_darjeeling/ip_autogen/clkmgr/doc/interfaces.md:L3: Updating generated content.
INFO:__main__:hw/top_darjeeling/ip_autogen/clkmgr/doc/registers.md:L3: Updating generated content.
INFO:__main__:hw/top_darjeeling/ip_autogen/ac_range_check/doc/interfaces.md:L3: Updating generated content.
INFO:__main__:hw/top_darjeeling/ip_autogen/ac_range_check/doc/registers.md:L3: Updating generated content.
  ...
make: Leaving directory ...
```

Always run ACE by using `make -C hw all` from the top-level directory of the Pavona clone; do not invoke topgen.py directly.

## Customizing your own top

Customizing the top almost always starts with the top-level Hjson file.
For example, change `num_inp_period_counters` to zero in `top_darjeeling.hjson`:

```json
...
        GpioAsyncOn: "1"
      },
      ipgen_params: {
        num_inp_period_counters: 0
      }
      attr: "ipgen"
...
```

 and re-run ACE by running

```shell
$ make -C hw all
```

You'll notice that `hw/top_darjeeling/ip_autogen/gpio/rtl/gpio.sv` is now much shorter.
That's because the templatization removes all the code related to input period counting if there are no input period counters.

Templatization in Pavona is a powerful concept; it can drastically alter hardware by removing inputs and outputs, change register layouts, and even customize DV sequences.

### Adding a new module

Instantiating a new module in Pavona requires filling in a new entry in the `module` list of the top-level Hjson.
In general, you'll follow the pattern of other module instantiations in filling out the name, type, clocks, resets, and base address.
In addition to the module entry, you'll need to add your module to the `addr_spaces` key.
You will also need to configure the crossbar to connect to your module.
Crossbar descriptions are located in the same `data/` directory as the top-level Hjson – to add your module to the main (1 GHz) Darjeeling crossbar, you'll need to edit `hw/top_darjeeling/data/xbar_main.hjson` .
A document showing how to add, remove, and customize modules is coming soon.
