# Top Earlgrey

## Specification

The datasheet and specification of Earlgrey is located [here](./doc/datasheet.md).

## How to generate

The top module `rtl/top_earlgrey.sv` is created by `topgen.py`.

To generate Earlgrey, run either of these commands from the repo top:
* `make -C hw top_and_cmdgen`
* `util/topgen.py -t hw/top_earlgrey/data/top_earlgrey.hjson -s hw/top_earlgrey/data/top_earlgrey_seed.testing.hjson -o hw/top_earlgrey`

It generates a number of files under `$REPO_TOP/hw/top_earlgrey`, including:
- [`rtl/autogen/top_earlgrey.sv`](./rtl/autogen/top_earlgrey.sv): Top module SV generated from the template [`templates/toplevel.sv.tpl`](./templates/toplevel.sv.tpl) with the configuration file [`data/top_earlgrey.hjson`](./data/top_earlgrey.hjson).
- [`ip/xbar_main/rtl/autogen/xbar_main.sv`](./ip/xbar_main/rtl/autogen/xbar_main.sv) and [`ip/xbar_main/rtl/autogen/tl_main_pkg.sv`](./ip/xbar_main/rtl/autogen/tl_main_pkg.sv): Main crossbar module.
  Earlgrey also has a peripheral crossbar (`xbar_peri`).
  The [tlgen](../../util/tlgen/README.md) library is used to generate these files.
- `ip_autogen/rv_plic/rtl/rv_plic*.sv` and [`ip_autogen/rv_plic/data/rv_plic.hjson`](./ip_autogen/rv_plic/data/rv_plic.hjson): Interrupt controller module.

### Modifying the top configuration

The main configuration file for Top Earlgrey is [`data/top_earlgrey.hjson`](./data/top_earlgrey.hjson).

It specifies the list of peripherals/IP blocks, memories, crossbars, and interrupts for the top level design.
For memories, it specifies the memory type, base address, and size.

IP blocks and crossbars have separate configuration files.

### Modifying the template

Main top template file is `data/top_earlgrey.sv.tpl`.
In most cases, modifying the template file isn't required because altering the configuration file can make adequate changes.

There might still be some changes that warrant revising the template, such as editing the modules which are hard-coded in the template.
