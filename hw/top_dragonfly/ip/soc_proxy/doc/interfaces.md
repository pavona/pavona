# Hardware Interfaces

<!-- BEGIN CMDGEN util/regtool.py --interfaces ./hw/top_dragonfly/ip/soc_proxy/data/soc_proxy.hjson -->
Referring to the [Comportable guideline for peripheral device functionality](../../../../../doc/contributing/hw/comportability), the module **`soc_proxy`** has the following hardware interfaces defined
- Primary Clock: **`clk_i`**
- Other Clocks: **`clk_aon_i`**
- Bus Device Interfaces (TL-UL): **`core_tl`**, **`ctn_tl`**
- Bus Host Interfaces (TL-UL): *none*
- Interrupts: *none*
- Security Countermeasures: *none*

## Peripheral Pins for Chip IO

| Pin name      | Direction   | Description                |
|:--------------|:------------|:---------------------------|
| soc_gpi[15:0] | input       | soc general purpose input  |
| soc_gpo[15:0] | output      | soc general purpose output |

## [Inter-Module Signals](../../../../../doc/contributing/hw/comportability#inter-signal-handling)

| Port Name             | Package::Struct       | Type    | Act   |   Width | Description                                                                  |
|:----------------------|:----------------------|:--------|:------|--------:|:-----------------------------------------------------------------------------|
| dma_tl_h2d            | tlul_pkg::tl_h2d      | uni     | rcv   |       1 | TL-UL host port for the DMA to egress into CTN (request part), synchronous   |
| dma_tl_d2h            | tlul_pkg::tl_d2h      | uni     | req   |       1 | TL-UL host port for the DMA to egress into CTN (response part), synchronous  |
| misc_tl_h2d           | tlul_pkg::tl_h2d      | uni     | rcv   |       1 | TL-UL host port for the MISC to egress into CTN (request part), synchronous  |
| misc_tl_d2h           | tlul_pkg::tl_d2h      | uni     | req   |       1 | TL-UL host port for the MISC to egress into CTN (response part), synchronous |
| wkup_external_req     | logic                 | uni     | req   |       1 |                                                                              |
| rst_req_external      | logic                 | uni     | req   |       1 |                                                                              |
| ctn_tl_h2d            | tlul_pkg::tl_h2d      | uni     | req   |       1 | TL-UL host port for egress into CTN (request part), synchronous              |
| ctn_tl_d2h            | tlul_pkg::tl_d2h      | uni     | rcv   |       1 | TL-UL host port for egress into CTN (response part), synchronous             |
| i2c_lsio_trigger      | logic                 | uni     | rcv   |       1 | LSIO trigger signal from I2C                                                 |
| spi_host_lsio_trigger | logic                 | uni     | rcv   |       1 | LSIO trigger signal from SPI Host                                            |
| uart_lsio_trigger     | logic                 | uni     | rcv   |       1 | LSIO trigger signal from UART                                                |
| soc_lsio_trigger      | logic                 | uni     | rcv   |       8 | LSIO trigger signal from SoC, synchronous                                    |
| dma_lsio_trigger      | dma_pkg::lsio_trigger | uni     | req   |       1 | Collated synchronous LSIO trigger signals for DMA                            |
| soc_wkup_async        | logic                 | uni     | rcv   |       1 | Wakeup request from SoC, asynchronous, level-encoded                         |
| soc_rst_req_async     | logic                 | uni     | rcv   |       1 | Reset request from SoC, asynchronous, level-encoded                          |
| soc_gpi_async         | logic                 | uni     | req   |      16 | GPI from SoC, async                                                          |
| soc_gpo_async         | logic                 | uni     | rcv   |      16 | GPO from SoC, async                                                          |
| integrator_id         | logic                 | uni     | rcv   |       4 | Integrator ID signal used in BAT                                             |
| core_tl               | tlul_pkg::tl          | req_rsp | rsp   |       1 |                                                                              |
| ctn_tl                | tlul_pkg::tl          | req_rsp | rsp   |       1 |                                                                              |

## Security Alerts

| Alert Name       | Description               |
|:-----------------|:--------------------------|
| fatal_alert_intg | Fatal bus integrity alert |


<!-- END CMDGEN -->
