# Top Generation Tool

The top generation tool, [`topgen.py`](../topgen.py), is used to build top modules - for example, [`top_egret`](../../hw/top_egret).
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
For example see [`top_egret`](../../hw/top_egret/data/top_egret.hjson).
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
For example, see [`top_egret`'s complete configuration](../../hw/top_egret/data/autogen/top_egret.gen.hjson).
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
The completion is done using functions that are called in [`merge_top`](./merge.py), except they get an extra argument to allow incomplete configuration since not all ipgen peripherals will have been expanded.
Once all ipgen peripherals are expanded, one last merge is performed, with incomplete configurations causing an error.
To make sure there are no mistakes in the order of ipgen peripherals, the expansion can make multiple generation passes, stopping when the complete top configuration is stable.
Only one pass will be required when the order in which ipgen peripherals are generated is right.

#### Generating other Artifacts

From the complete top configuration Hjson (sometimes along with a top secrets configuration), other tools can generate other top-relevant assets.

Tools that use the complete top config include:
- `util/gen_top_ral.py`: generates the top level's RAL model
- `util/top_cm_and_blocks.py`: depending on subcommand used, either checks countermeasures of a top's IPs or lists which blocks are present within a top level
  - This script's list of blocks can be fed to regtool to generate the IP block registers
- `util/gen_top_ipconfigs.py`: creates IP configuration Hjson files that can be used to generate templated IPs or crossbars from top level information
  - ipgen and tlgen can use the output of this script to generate IP templates and TL-UL crossbars (respectively)
- `util/gen_top_docs.py`: generates top level's pinmux and target documentation
- `util/gen_top_sw.py`: generates the software (C, Rust, Bazel) files for a top level
- `util/gen_top_sv.py`: generates the SystemVerilog files associated with a top level design

## Usage

The most generic use of topgen is to let it generate everything.
This can be done through direct invocation, or the `${REPO_TOP}/hw` makefile.
The example below shows the latter:
```console
$ cd ${REPO_TOP}
$ make -C hw top
```

It is possible to restrict what the tool should generate.

<!-- BEGIN CMDGEN util/selfdoc.py quote:util/topgen.py --help -->
```
$ util/topgen.py --help
usage: topgen [-h] --topcfg TOPCFG --seedcfg SEEDCFG [--outdir OUTDIR]
              [--hjson-path HJSON_PATH] [--verbose]
              [--version-stamp VERSION_STAMP]
              [--alias-files ALIAS_FILES [ALIAS_FILES ...]]

options:
  -h, --help            show this help message and exit
  --topcfg TOPCFG, -t TOPCFG
                        `top_{name}.hjson` file.
  --seedcfg SEEDCFG, -s SEEDCFG
                        top_{name} seed configuration file.
  --outdir OUTDIR, -o OUTDIR
                        Target TOP directory. Module is created under rtl/.
                        (default: dir(topcfg)/..)
  --hjson-path HJSON_PATH
                        If defined, topgen uses supplied path to search for ip
                        hjson. This applies only to ip's with the
                        `reggen_only` attribute. If an hjson is located both
                        in the conventional path and the alternate path, the
                        alternate path has priority.
  --verbose, -v         Verbose
  --version-stamp VERSION_STAMP
                        If version stamping, the location of workspace version
                        stamp file.
  --alias-files ALIAS_FILES [ALIAS_FILES ...]
                        If defined, topgen uses supplied alias hjson file(s)
                        to override the generic register definitions when
                        building the RAL model. This argument is only relevant
                        in conjunction with the `--top_ral` switch.
```
<!-- END CMDGEN -->

## Top Hjson Schema

<!-- BEGIN CMDGEN util/selfdoc.py topgen -->

<!-- Start of output generated by topgen.selfdoc -->
### Top Configuration

*Configuration options for creating a top with ACE*

#### Properties

- <a id="properties/name"></a>**`name`** *(string, required)*: Top name.
- <a id="properties/type"></a>**`type`**: type of hjson. Shall be 'top' always. Must be one of: `["top"]`.
- <a id="properties/datawidth"></a>**`datawidth`** *(integer)*: default data width.
- <a id="properties/racl_config"></a>**`racl_config`** *(string)*: Path to a RACL configuration HJSON file.
- <a id="properties/power"></a>**`power`** *(object)*: power domains supported by the design.
- <a id="properties/unmanaged_clocks"></a>**`unmanaged_clocks`** *(array, required)*: list of unmanaged external clocks.
- <a id="properties/clocks"></a>**`clocks`** *(object, required)*: group of clock properties.
- <a id="properties/resets"></a>**`resets`** *(object, required)*: list of resets.
- <a id="properties/reset_requests"></a>**`reset_requests`** *(object)*: define reset requests grouped by type.
- <a id="properties/num_cores"></a>**`num_cores`** *(integer)*: number of computing units.
- <a id="properties/default_plic"></a>**`default_plic`** *(string)*: Modules not defining plic have interrupts sent here.
- <a id="properties/default_alert_handler"></a>**`default_alert_handler`** *(string)*: Modules not defining alert_handler have alerts sent here.
- <a id="properties/addr_spaces"></a>**`addr_spaces`** *(array, required)*: list of address spaces.
- <a id="properties/module"></a>**`module`** *(array, required)*: list of modules to instantiate.
- <a id="properties/port"></a>**`port`** *(array)*: assign special attributes to specific ports.
- <a id="properties/inter_module"></a>**`inter_module`** *(object)*: define the signal connections between the modules.
- <a id="properties/xbar"></a>**`xbar`** *(array, required)*: list of the xbars used in the top.
- <a id="properties/pinout"></a>**`pinout`**: pinout configuration. Refer to *[urn:topgen:pinout](#n%3Atopgen%3Apinout)*.
- <a id="properties/pinmux"></a>**`pinmux`**: pinmux configuration. Refer to *[urn:topgen:pinmux](#n%3Atopgen%3Apinmux)*.
- <a id="properties/targets"></a>**`targets`** *(array, required)*: target configurations.
  - <a id="properties/targets/items"></a>**Items**: Refer to *[urn:topgen:target](#n%3Atopgen%3Atarget)*.
- <a id="properties/incoming_alert"></a>**`incoming_alert`** *(object)*: Parsed incoming alerts; added property.
- <a id="properties/incoming_interrupt"></a>**`incoming_interrupt`** *(object)*: Parsed incoming interrupts; added property.
- <a id="properties/exported_clks"></a>**`exported_clks`** *(object)*: clock signal routing rules; added property.
- <a id="properties/racl"></a>**`racl`** *(object)*: the expansion of the racl_config file; added property.
- <a id="properties/wakeups"></a>**`wakeups`** *(array)*: list of wakeup requests each holding name, width, and module; added property.
- <a id="properties/unmanaged_resets"></a>**`unmanaged_resets`** *(array)*: List of unmanaged external resets; added property.
- <a id="properties/exported_rsts"></a>**`exported_rsts`** *(object)*: external resets grouped by each module's `clock_reset_export` field; added property.
- <a id="properties/alert"></a>**`alert`** *(array)*: alerts; added property.
- <a id="properties/outgoing_alert"></a>**`outgoing_alert`** *(object)*: the outgoing alert groups; added property.
- <a id="properties/interrupt"></a>**`interrupt`** *(array)*: interrupts; added property.
- <a id="properties/outgoing_interrupt"></a>**`outgoing_interrupt`** *(object)*: the outgoing interrupt groups; added property.
- <a id="properties/alert_module"></a>**`alert_module`** *(array)*: list of the modules that connects to alert_handler; added property.
- <a id="properties/alert_connections"></a>**`alert_connections`** *(object)*
- <a id="properties/interrupt_module"></a>**`interrupt_module`** *(array)*: list of the modules that connects to rv_plic; added property.
- <a id="properties/outgoing_alert_module"></a>**`outgoing_alert_module`** *(object)*: added property.
- <a id="properties/outgoing_interrupt_module"></a>**`outgoing_interrupt_module`** *(object)*: added property.
- <a id="properties/alert_lpgs"></a>**`alert_lpgs`** *(array)*: added property.
- <a id="properties/outgoing_alert_lpgs"></a>**`outgoing_alert_lpgs`** *(object)*: added property.
- <a id="properties/inter_signal"></a>**`inter_signal`** *(object)*: added property.

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


Tops must also come with a seed configuration Hjson.
### Seed Configuration

*Configuration options for random seeds*

#### Properties

- <a id="properties/name"></a>**`name`** *(string, required)*: name of top for seeding.
- <a id="properties/topgen_seed"></a>**`topgen_seed`** *(integer, required)*: seed for topgen generated random netlist constants.
- <a id="properties/otp_img_seed"></a>**`otp_img_seed`** *(integer)*: Seed for OTP image generation.
- <a id="properties/lc_ctrl_seed"></a>**`lc_ctrl_seed`** *(integer)*: Seed for lc_ctrl generated random netlist constants.

### Eflash

*Flash memory configuration*

#### Properties

- <a id="properties/type"></a>**`type`** *(string, required)*: string indicating type of memory.
- <a id="properties/banks"></a>**`banks`** *(number, required)*: number of flash banks.
- <a id="properties/pages_per_bank"></a>**`pages_per_bank`** *(number, required)*: number of data pages per flash bank.
- <a id="properties/program_resolution"></a>**`program_resolution`** *(number, required)*: maximum number of flash words allowed to program at a time.
- <a id="properties/words_per_page"></a>**`words_per_page`** *(number, required)*: number of words per page.
- <a id="properties/data_width"></a>**`data_width`** *(number, required)*: number of bits per data word.
- <a id="properties/integrity_width"></a>**`integrity_width`** *(number, required)*: number of integrity bits per data word.
- <a id="properties/info_types"></a>**`info_types`** *(number, required)*: number of different info page types.
- <a id="properties/infos_per_bank"></a>**`infos_per_bank`** *(array, required)*: number of pages per info type, the size of the list must match 'info_types'.

### Pad

*I/O pad configuration*

#### Properties

- <a id="properties/name"></a>**`name`** *(string, required)*: Pad name.
- <a id="properties/type"></a>**`type`** *(string, required)*: Pad type.
- <a id="properties/bank"></a>**`bank`** *(string, required)*: IO power bank for the pad.
- <a id="properties/connection"></a>**`connection`**: Specification of connection type, can be direct, manual or muxed. Must be one of: `["direct", "manual", "muxed"]`.
- <a id="properties/desc"></a>**`desc`** *(string)*: Pad description.
- <a id="properties/port_type"></a>**`port_type`** *(string)*: Special port type other than `inout wire`.
- <a id="properties/idx"></a>**`idx`** *(number)*: the index of the pad; added property.

### Pinmux

*Top level pin multiplexing configuration*

#### Properties

- <a id="properties/signals"></a>**`signals`** *(array)*: List of Dedicated IOs.
  - <a id="properties/signals/items"></a>**Items**: Refer to *[urn:topgen:pinmux_signal](#n%3Atopgen%3Apinmux_signal)*.
- <a id="properties/wkup_cnt_width"></a>**`wkup_cnt_width`** *(integer)*: Number of bits in wakeup detector counters.
- <a id="properties/num_wkup_detect"></a>**`num_wkup_detect`** *(integer)*: Number of wakeup detectors.
- <a id="properties/enable_usb_wakeup"></a>**`enable_usb_wakeup`** *(boolean, required)*: Enable USB wakeup in pinmux.
- <a id="properties/enable_strap_sampling"></a>**`enable_strap_sampling`** *(boolean, required)*: Enable hardware strap sampling of pinmux.
- <a id="properties/ios"></a>**`ios`** *(array)*: Full list of IO; added property.
  - <a id="properties/ios/items"></a>**Items**: Refer to *[urn:topgen:pinmux_io](#n%3Atopgen%3Apinmux_io)*.
- <a id="properties/io_counts"></a>**`io_counts`** *(object)*: count of ios grouped by dedicated or muxed; added property.
  - <a id="properties/io_counts/patternProperties/.%2A"></a>**`.*`**: Refer to *[urn:topgen:pinmux_io_count](#n%3Atopgen%3Apinmux_io_count)*.

### Pinmux I/O

*Top level I/O listing for pinmux*

#### Properties

- <a id="properties/name"></a>**`name`** *(string, required)*: the name of the io.
- <a id="properties/width"></a>**`width`** *(number, required)*: the bit width of the io.
- <a id="properties/type"></a>**`type`**: input, output, or inout. Must be one of: `["input", "output", "inout"]`.
- <a id="properties/idx"></a>**`idx`** *(number)*
- <a id="properties/pad"></a>**`pad`** *(string)*: Pad name for direct connections.
- <a id="properties/attr"></a>**`attr`** *(string)*: Pad type for generating the correct attribute CSR.
- <a id="properties/connection"></a>**`connection`**: Specification of connection type, can be direct, manual or muxed. Must be one of: `["direct", "manual", "muxed"]`.
- <a id="properties/desc"></a>**`desc`** *(string)*: Signal description.
- <a id="properties/glob_idx"></a>**`glob_idx`** *(number)*

### Pinmux I/O Count

*Number of pinmux I/Os of each type*

#### Properties

- <a id="properties/inouts"></a>**`inouts`** *(number, required)*: the count of inout ios of the io type.
- <a id="properties/inputs"></a>**`inputs`** *(number, required)*: the count of input ios of the io type.
- <a id="properties/outputs"></a>**`outputs`** *(number, required)*: the count of output ios of the io type.
- <a id="properties/pads"></a>**`pads`** *(number, required)*: the count of pads of the io type.

### Pinmux Signal

*Signal configurations for pinmux*

#### Properties

- <a id="properties/instance"></a>**`instance`** *(string, required)*: Module instance name.
- <a id="properties/port"></a>**`port`** *(string)*: Port name of module.
- <a id="properties/connection"></a>**`connection`**: Specification of connection type, can be direct, manual or muxed. Must be one of: `["direct", "manual", "muxed"]`.
- <a id="properties/pad"></a>**`pad`** *(string)*: Pad name for direct connections.
- <a id="properties/desc"></a>**`desc`** *(string)*: Signal description.
- <a id="properties/attr"></a>**`attr`** *(string)*: Pad type for generating the correct attribute CSR.

### Pinout

*Top level pinout*

#### Properties

- <a id="properties/banks"></a>**`banks`** *(array, required)*: List of IO power banks.
- <a id="properties/pads"></a>**`pads`** *(array, required)*: List of pads.
  - <a id="properties/pads/items"></a>**Items**: Refer to *[urn:topgen:pad](#n%3Atopgen%3Apad)*.

### Special Signal

*Special signal for pinmux*

#### Properties

- <a id="properties/name"></a>**`name`** *(string, required)*: DIO name.
- <a id="properties/pad"></a>**`pad`** *(string, required)*: Pad name.
- <a id="properties/desc"></a>**`desc`** *(string)*: Description of signal connection.
- <a id="properties/idx"></a>**`idx`** *(number)*: the index of the signal; added property.

### Straps

*Configuration for straps*

#### Properties

- <a id="properties/tap0"></a>**`tap0`** *(string, required)*: Name of tap0 pad.
- <a id="properties/tap1"></a>**`tap1`** *(string, required)*: Name of tap1 pad.
- <a id="properties/dft0"></a>**`dft0`** *(string, required)*: Name of dft0 pad.
- <a id="properties/dft1"></a>**`dft1`** *(string, required)*: Name of dft1 pad.

### Target

*Hardware target for a top level design, such as an FPGA or ASIC*

#### Properties

- <a id="properties/name"></a>**`name`** *(string, required)*: Name of target.
- <a id="properties/pinout"></a>**`pinout`**: Target-specific pinout configuration. Refer to *[urn:topgen:target_pinout](#n%3Atopgen%3Atarget_pinout)*.
- <a id="properties/pinmux"></a>**`pinmux`**: Target-specific pinmux configuration. Refer to *[urn:topgen:target_pinmux](#n%3Atopgen%3Atarget_pinmux)*.

### Target Pinmux

*Top level target's pinmux configuration*

#### Properties

- <a id="properties/special_signals"></a>**`special_signals`** *(array, required)*: List of special signals and the pad they are mapped to.
  - <a id="properties/special_signals/items"></a>**Items**: Refer to *[urn:topgen:special_signal](#n%3Atopgen%3Aspecial_signal)*.

### Target Pinout

*Top level target's pinout configuration*

#### Properties

- <a id="properties/remove_ports"></a>**`remove_ports`** *(array, required)*: List of port names to remove from the port list.
- <a id="properties/remove_pads"></a>**`remove_pads`** *(array, required)*: List of pad names to remove and stub out.
- <a id="properties/add_pads"></a>**`add_pads`** *(array, required)*: List of manual pads to add.


<!-- End of output generated by topgen.selfdoc -->

<!-- END CMDGEN -->
