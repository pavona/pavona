# Hardware Interfaces

<!-- BEGIN CMDGEN util/regtool.py --interfaces ./hw/ip/dma/data/dma.hjson -->
Referring to the [Comportable guideline for peripheral device functionality](../../../../doc/contributing/hw/comportability), the module **`dma`** has the following hardware interfaces defined
- Primary Clock: **`clk_i`**
- Other Clocks: **`clk_edn_i`**
- Bus Device Interfaces (TL-UL): **`tl_d`**
- Bus Host Interfaces (TL-UL): **`host32_tl_h`**
- Peripheral Pins for Chip IO: *none*

## [Inter-Module Signals](../../../../doc/contributing/hw/comportability#inter-signal-handling)

| Port Name      | Package::Struct               | Type    | Act   | Width     | Description                                                                                                                          |
|:---------------|:------------------------------|:--------|:------|:----------|:-------------------------------------------------------------------------------------------------------------------------------------|
| lsio_trigger   | dma_pkg::lsio_trigger         | uni     | rcv   | 1         |                                                                                                                                      |
| lc_escalate_en | lc_ctrl_pkg::lc_tx            | uni     | rcv   | 1         |                                                                                                                                      |
| edn            | edn_pkg::edn                  | req_rsp | req   | 1         |                                                                                                                                      |
| keymgr_key     | keymgr_pkg::hw_key_req        | uni     | rcv   | 1         |                                                                                                                                      |
| host64_h2d     | dma_tlul_pkg::dma_tl_h2d      | uni     | req   | NumTlul64 | 64-bit TLUL host (h2d) to chip top, point-to-point                                                                                   |
| host64_d2h     | tlul_pkg::tl_d2h              | uni     | rcv   | NumTlul64 | 64-bit TLUL host (d2h) from chip top, point-to-point                                                                                 |
| racl_policies  | top_racl_pkg::racl_policy_vec | uni     | rcv   | 1         | Incoming RACL policy vector from a racl_ctrl instance. The policy selection vector (parameter) selects the policy for each register. |
| racl_error     | top_racl_pkg::racl_error_log  | uni     | req   | 1         | RACL error log information of this module.                                                                                           |
| host32_tl_h    | tlul_pkg::tl                  | req_rsp | req   | NumTlul32 |                                                                                                                                      |
| tl_d           | tlul_pkg::tl                  | req_rsp | rsp   | 1         |                                                                                                                                      |

## Interrupts

| Interrupt Name   | Type   | Description                                                               |
|:-----------------|:-------|:--------------------------------------------------------------------------|
| dma_done         | Status | DMA operation has been completed.                                         |
| dma_chunk_done   | Status | Indicates the transfer of a single chunk has been completed.              |
| dma_error        | Status | DMA error has occurred. DMA_STATUS.error_code register shows the details. |

## Security Alerts

| Alert Name   | Description                                                                                                                                                                   |
|:-------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| fatal_fault  | This fatal alert is triggered when a fatal TL-UL bus integrity fault is detected, or on an inline-AES fatal fault (aes_core fatal alert or the AES-wrapper sparse-FSM error). |
| recov_fault  | This recoverable alert is triggered on an inline AES-GCM decrypt authentication tag mismatch, or on an aes_core recoverable fault.                                            |

## Security Countermeasures

| Countermeasure ID            | Description                                                             |
|:-----------------------------|:------------------------------------------------------------------------|
| DMA.BUS.INTEGRITY            | End-to-end bus integrity scheme.                                        |
| DMA.ASID.INTERSIG.MUBI       | Destination and source ASID signals are multibit encoded.               |
| DMA.RANGE.CONFIG.REGWEN_MUBI | DMA enabled memory range is software multibit lockable.                 |
| DMA.FSM.SPARSE               | FSM is sparsely encoded. There is a single `ctrl_state` FSM.            |
| DMA.KEY.SIDELOAD             | Inline AES can source its key from the keymgr sideload interface.       |
| DMA.KEY.SW_UNREADABLE        | Inline AES KEY_SHARE and TAG_IN registers are write-only.               |
| DMA.KEY.SEC_WIPE             | Inline AES key/IV/tag material is wiped after use (tracked).            |
| DMA.CTRL.CONSISTENCY         | Inline AES-GCM decrypt tag compare is glitch-resistant and fail-closed. |


<!-- END CMDGEN -->
