# Top Generation Tool

The top generation tool, [`topgen.py`](../topgen.py), is used to build top modules - for example, [`top_earlgrey`](../../hw/top_earlgrey).
Currently, as part of this generation process, the following top-specific modules are created
* Overall top module
* Crossbars
* A number of templated peripherals, which are expanded according to top specific configurations
This document explains the overall generation process, the required inputs, the output locations, as well as how the tool should be invoked.

Topgen relies on a number of other tools and libraries within ACE as well, so it would be wise to refer to their respective sets of documentation as well.
![Visual representing topgen's reliance on other ACE libraries](./doc/topgen_in_ace.svg)
* [`ipgen`'s documentation](../ipgen/README.md) provides information on how to handle IP templates.
* [`regtool`/`reggen`'s documentation](../reggen/README.md) provides information on how to specify individual IP blocks and their registers, and valid data types.
* [`tlgen`'s documentation](../tlgen/README.md) provides information on how to specify and generate TL-UL crossbars.

## Generation Process

### Overview
The details of a particular top variant are described in a top-specific Hjson file.
For example see [`top_earlgrey`](../../hw/top_earlgrey/data/top_earlgrey.hjson).
For detailed information about how the top Hjson should be written, see the [Top Hjson Schema](#top-hjson-schema) section of this document.

The top specific Hjson describes how the design looks and how it should connect, for example:
* Overall fabric data width
* Clock sources
* Reset sources
* Address spaces
* List of instantiated peripherals
  * Module type of each peripheral (it is possible to have multiple instantiations of a particular module)
  * Clock / reset connectivity of each peripheral
  * Base address of each peripheral for each connected address space
* List of instantiated crossbars
* System memories
* Fabric construction
  * Clock / reset connectivity of each fabric component
* Interrupt sources
* Pinmux construction
  * List of dedicated or muxed pins

The top level Hjson however, does not contain details such as:
* Specific clock / reset port names for each peripheral
* Number of interrupts in each peripheral
* Number of input or output pins in each peripheral
* Details of crossbar connection and which host can reach which device

There are two kinds of peripherals:
* Generic peripherals, which are the same for any top configuration
* Ipgen peripherals, which have a set of template files, and are expanded based on top-specific parameters

The topgen tool thus hierarchically gathers and generates the missing information from additional Hjson files that describe the detail of each component.
These are primarily located in the following places:
* `hw/ip/*/data/*.hjson` for generic peripherals
* `hw/ip_templates/*/data/*.hjson.tpl` for ipgen peripherals (during top generation, these Hjson templates are used to generate `hw/top_*/ip_autogen/*/data/*.hjson`)
* `hw/top_*/data/xbar_*.hjson` for crossbars which are also generated from templates
* `hw/top_*/ip/*/data/*.hjson` for manually written (ie., non-ipgen) top-specific peripherals

In the process of gathering, each individual Hjson file is validated for input correctness and then merged into a final generated Hjson output that represents the complete information that makes up each design.
For example, see [`top_earlgrey`'s complete configuration](../../hw/top_earlgrey/data/autogen/top_earlgrey.gen.hjson).
Note specifically the generated interrupt list, the pinmux connections, and the port-to-net mapping of clocks and resets, all of which were not present in the original input.

The purpose for this two step process, instead of describing the design completely inside one Hjson file, is to decouple the top and components development while allowing re-use of components by multiple tops.

This process also clearly separates what information needs to be known by top vs. what needs to be known by a specific component.
For example, a component does not need to know how many clock sources a top has or how many muxed pins it contains.
Likewise, the top does not need to know the details of why an interrupt is generated, just how many there are.
The user supplied `top_*.hjson` thus acts like a integration specification while the remaining details are filled in through lower level inputs.

In addition to design collateral, the tool also generates all the top level RAL (Register Abstraction Layer) models necessary for verification.

### Validation, Merge and Output

As stated previously, each of the gathered component Hjson files is validated for correctness.
For the peripherals, this is done by invoking [`util/reggen/validate.py`](../reggen/validate.py), while the xbar components are validated through [`util/tlgen/validate.py`](../tlgen/validate.py).
The peripheral and xbar components are then validated through [`util/topgen/validate.py`](./validate.py).
Topgen's validation also performs extensive checks on the top configuration; for example on interrupts, pinmuxes, clocks, and reset consistency.

Once all validation is passed, the final Hjson is created by [`util/topgen/merge.py`](./merge.py).
This Hjson is then used to generate the final top RTL and/or other selected outputs.

As part of this process, topgen invokes other tools.
Please see the documentation for [`ipgen`](../ipgen/README.md), [`reggen`](../reggen/README.md), and [`tlgen`](../tlgen/README.md) for more tool-specific details.

### Generation Flow

In order to generate the complete set of artifacts for a given top, the first step is to generate the complete top configuration file (named `top_*/data/autogen/top_*.gen.hjson` as mentioned above).
Most other artifacts, like the top-level module(s), ipgen peripherals, and top-level SV and software collateral require this file for generation.
These artifacts can be generated independently after the complete top configuration is created.

#### Generating the Complete Top Configuration

The generation of ipgen peripherals is delicate since they depend on each other.
All these dependencies are captured in the top configuration as it is completed.
As ipgen peripherals are expanded, they provide information that will be used for expanding other ipgen peripherals.
This means the order in which ipgen peripherals are expanded needs to be carefully chosen in order to avoid divergent/inconsistent generation results.
The top configuration is completed progressively as individual peripherals are processed.
All this is done in-memory, and the individual peripherals are added in the following order:
* The generic peripherals
* The ipgen peripherals, topologically sorted based on their inter-dependencies
* The crossbars

It is important to progressively complete the top config with the most up-to-date data specific to each ipgen peripheral before expanding it.
The completion is done using functions that are called in [`merge_top`](../merge.py), except they get an extra argument to allow incomplete configuration since not all ipgen peripherals will have been expanded.
Once all ipgen peripherals are expanded, one last merge is performed, with incomplete configurations causing an error.
To make sure there are no mistakes in the order of ipgen peripherals, the expansion can make multiple generation passes, stopping when the complete top configuration is stable.
Only one pass will be required when the order in which ipgen peripherals are generated is right.

#### Generating other Artifacts

There are a large number of artifacts that are generated from the complete top config using topgen, including:
* The templates of ipgen peripherals, expanded into directories specific to each top, for example [`hw/top_darjeeling/ip_autogen/clkmgr`](../../hw/top_darjeeling/ip_autogen/clkmgr/).
* The crossbars, also expanded from templates into top-specific directories, for example `hw/top_earlgrey/ip/xbar_*/*/autogen`.
* Part of the Bazel files necessary to register the top with build system; see [Creating a new top](../../hw/top/doc/create_top.md) for details.

## Usage

The most generic use of topgen is to let it generate everything.
This can be done through direct invocation, or the `${REPO_TOP}/hw` makefile.
The example below shows the latter:
```console
$ cd ${REPO_TOP}
$ make -C hw top
```

It is possible to restrict what the tool should generate.

```console
$ cd ${REPO_TOP}
$ ./util/topgen.py -h
usage: topgen [-h] --topcfg TOPCFG --seedcfg SEEDCFG [--outdir OUTDIR] [--hjson-path HJSON_PATH] [--verbose] [--version-stamp VERSION_STAMP] [--no-top] [--no-xbar]
              [--no-plic] [--no-rust] [--top-only] [--check-cm] [--xbar-only] [--plic-only] [--alert-handler-only] [--rust-only] [--top_ral]
              [--alias-files ALIAS_FILES [ALIAS_FILES ...]] [--dv-base-names DV_BASE_NAMES [DV_BASE_NAMES ...]] [--get_blocks]

options:
  -h, --help            show this help message and exit
  --topcfg TOPCFG, -t TOPCFG
                        `top_{name}.hjson` file.
  --seedcfg SEEDCFG, -s SEEDCFG
                        top_{name} seed configuration file.
  --outdir OUTDIR, -o OUTDIR
                        Target TOP directory. Module is created under rtl/. (default: dir(topcfg)/..)
  --hjson-path HJSON_PATH
                        If defined, topgen uses supplied path to search for ip hjson. This applies only to ip's with the `reggen_only` attribute. If an hjson is located
                        both in the conventional path and the alternate path, the alternate path has priority.
  --verbose, -v         Verbose
  --version-stamp VERSION_STAMP
                        If version stamping, the location of workspace version stamp file.
  --no-top              If defined, topgen doesn't generate top_{name} RTLs.
  --no-xbar             If defined, topgen doesn't generate crossbar RTLs.
  --no-plic             If defined, topgen doesn't generate the interrupt controller RTLs.
  --no-rust             If defined, topgen doesn't generate Rust code.
  --top-only            If defined, the tool generates top RTL only
  --check-cm            Check countermeasures. Check countermeasures of all modules in the top config. All countermeasures declared in the module's hjson file should be
                        implemented in the RTL, and the RTL should only contain countermeasures declared there.
  --xbar-only           If defined, the tool generates crossbar RTLs only
  --plic-only           If defined, the tool generates RV_PLIC RTL and Hjson only
  --alert-handler-only  If defined, the tool generates alert handler hjson only
  --rust-only           If defined, the tool generates top Rust code only
  --top_ral, -r         If set, the tool generates top level RAL model for DV
  --alias-files ALIAS_FILES [ALIAS_FILES ...]
                        If defined, topgen uses supplied alias hjson file(s) to override the generic register definitions when building the RAL model. This argument is
                        only relevant in conjunction with the `--top_ral` switch.
  --dv-base-names DV_BASE_NAMES [DV_BASE_NAMES ...]
                        Names or prefix for the DV register classes from which the register models are derived.
  --get_blocks          Only return the list of blocks and exit.
```

## Top Hjson Schema

<!-- Start of output generated by topgen.selfdoc -->
All Hjson values should conform to [the value types delineated by `reggen`](../reggen/README.md).
This includes top level Hjsons.

Top Hjsons should also have the following keys (some being optional):

Key | Kind | Type | Description of Value
--- | ---- | ---- | --------------------
name | required | string | Top name
type | required | string | type of hjson. Shall be "top" always
clocks | required | group | group of clock properties
resets | required | list | list of resets
addr_spaces | required | group | list of address spaces
module | required | list | list of modules to instantiate
xbar | required | list | List of the xbar used in the top
pinout | required | group | Pinout configuration
targets | required | list |  Target configurations
pinmux | required | group | pinmux configuration
unmanaged_clocks | required | list | List of unmanaged external clocks
alerts | optional | group | alert handler configuration
alert_module | optional | list | list of the modules that connects to alert_handler
datawidth | optional | python int | default data width
exported_clks | optional | group | clock signal routing rules
host | optional | group | list of host-only components in the system
inter_module | optional | group | define the signal connections between the modules
interrupts | optional | group | interrupt controller configuration
interrupt_module | optional | list | list of the modules that connects to rv_plic
num_cores | optional | python int | number of computing units
outgoing_alert | optional | group | the outgoing alert groups
outgoing_interrupt | optional | group | the outgoing interrupt groups
power | optional | group | power domains supported by the design
port | optional | group | assign special attributes to specific ports
racl_config | optional | string | Path to a RACL configuration HJSON file
reset_requests | optional | group | define reset requests grouped by type
seed | optional | group | Seed information for topgen and subsequent flows
unmanaged_resets | optional | list | List of unmanaged external resets
default_alert_handler | optional | string | Modules not defining alert_handler have alerts sent here
default_plic | optional | string | Modules not defining plic have interrupts sent here

Module Hjsons (referred to by the "complete config" Hjson topgen creates) has the following keys (some being optional):
Key | Kind | Type | Description of Value
--- | ---- | ---- | --------------------
name | required | string | name of the instance
type | required | string | comportable IP type
clock_srcs | required | group | dict with clock sources
clock_group | required | string | clock group
reset_connections | required | group | dict with reset sources
domain | optional | list | optional list of power domains, defaults to Domain0
clock_reset_export | optional | list | optional list with prefixes for exported clocks and resets at the chip level
attr | optional | string | optional attribute indicating whether the IP is "ipgen", "reggen_top", or "reggen_only"
base_addr | optional | group | dict of address space mapped to the corresponding hex start address of the peripheral (if the IP has only a single TL-UL interface)
base_addrs | optional | group | hex start addresses of the peripheral  (if the IP has multiple TL-UL interfaces)
memory | optional | group | optional dict with memory region attributes
param_decl | optional | group | optional dict that allows to override instantiation parameters
generate_dif | optional | python Bool | optional bool to indicate if a DIF should be generated for that module
outgoing_alert | optional | string | optional string to indicate alerts are routed externally to the named group
outgoing_interrupt | optional | string | optional string to indicate interrupts are routed externally to the named group
incoming_alert | optional | list | optional list of paths to incoming alert configurations for the alert_handler
ipgen_params | optional | group | Optional ipgen parameters for that instance
template_type | optional | string | Base template type of ipgen IPs
racl_group | optional | string | Only valid for racl_ctrl IPs. Defines the RACL group this control IP is associated to
racl_mappings | optional | group | dict that maps an interface to its associated RACL mapping
racl_mapping | optional | string | A special case of racl_mappings. If specified, this is taken to represent a dict that associates all interfaces with the given mapping. It is an error to specify both this and racl_mappings.
plic | optional | string | Interrupt controller managing this module's interrupts
targets | optional | list | Optional list of targets for this PLIC
alert_handler | optional | string | Alert handler managing this module's alerts
otp_map | optional | group | OTP Map information for OTP Ctrl

The "complete config" Hjson adds the following keys:

Key | Kind | Type | Description of Value
--- | ---- | ---- | --------------------
alert | added by tool | list | alerts
exported_rsts | added by tool | group | external resets grouped by each module's `clock_reset_export` field
incoming_alert | added by tool | group | Parsed incoming alerts
incoming_interrupt | added by tool | group | Parsed incoming interrupts
interrupt | added by tool | list | interrupts
racl | added by tool | group | the expansion of the racl_config file
wakeups | added by tool | list | list of wakeup requests each holding name, width, and module
cfg_path | added by tool | string | Path to the folder of the toplevel HJSON file


Tops must also come with a seed configuration Hjson.
Seed configs must include the following keys:

Key | Kind | Type | Description of Value
--- | ---- | ---- | --------------------
name | required | string | Top name
topgen_seed | required | int | Seed for topgen generated random netlist constants
otp_img_seed | optional | int | Seed for OTP image generation
lc_ctrl_seed | optional | int | Seed for lc_ctrl generated random netlist constants


For an even more detailed look at the subsections of the top Hjson, refer to [`util/topgen/validate.py`](./validate.py), which contains dictionaries of various subsection key and value type requirements.
These dictionaries store such requirements in the form of `{<key>: [<abbreviated_value_type>, <description>]}`.
The variable name of the dictionary will convey whether the value is required, optional, or added.


<!-- End of output generated by topgen.selfdoc -->
