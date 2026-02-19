# Hardware Interfaces

<!-- BEGIN CMDGEN util/regtool.py --interfaces ./hw/ip/acc/data/acc.hjson -->
Referring to the [Comportable guideline for peripheral device functionality](https://opentitan.org/book/doc/contributing/hw/comportability), the module **`acc`** has the following hardware interfaces defined
- Primary Clock: **`clk_i`**
- Other Clocks: **`clk_edn_i`**, **`clk_otp_i`**
- Bus Device Interfaces (TL-UL): **`tl`**
- Bus Host Interfaces (TL-UL): *none*
- Peripheral Pins for Chip IO: *none*

## [Inter-Module Signals](https://opentitan.org/book/doc/contributing/hw/comportability/index.html#inter-signal-handling)

| Port Name        | Package::Struct                 | Type    | Act   |   Width | Description   |
|:-----------------|:--------------------------------|:--------|:------|--------:|:--------------|
| acc_otp_key      | otp_ctrl_pkg::acc_otp_key       | req_rsp | req   |       1 |               |
| edn_rnd          | edn_pkg::edn                    | req_rsp | req   |       1 |               |
| edn_urnd         | edn_pkg::edn                    | req_rsp | req   |       1 |               |
| kmac_data        | kmac_pkg::app                   | req_rsp | req   |       1 |               |
| idle             | prim_mubi_pkg::mubi4            | uni     | req   |       1 |               |
| ram_cfg_imem     | prim_ram_1p_pkg::ram_1p_cfg     | uni     | rcv   |       1 |               |
| ram_cfg_dmem     | prim_ram_1p_pkg::ram_1p_cfg     | uni     | rcv   |       1 |               |
| ram_cfg_rsp_imem | prim_ram_1p_pkg::ram_1p_cfg_rsp | uni     | req   |       1 |               |
| ram_cfg_rsp_dmem | prim_ram_1p_pkg::ram_1p_cfg_rsp | uni     | req   |       1 |               |
| lc_escalate_en   | lc_ctrl_pkg::lc_tx              | uni     | rcv   |       1 |               |
| lc_rma_req       | lc_ctrl_pkg::lc_tx              | uni     | rcv   |       1 |               |
| lc_rma_ack       | lc_ctrl_pkg::lc_tx              | uni     | req   |       1 |               |
| keymgr_key       | keymgr_pkg::acc_key_req         | uni     | rcv   |       1 |               |
| tl               | tlul_pkg::tl                    | req_rsp | rsp   |       1 |               |

## Interrupts

| Interrupt Name   | Type   | Description                      |
|:-----------------|:-------|:---------------------------------|
| done             | Event  | ACC has completed the operation. |

## Security Alerts

| Alert Name   | Description                                                                              |
|:-------------|:-----------------------------------------------------------------------------------------|
| fatal        | A fatal error. Fatal alerts are non-recoverable and will be asserted until a hard reset. |
| recov        | A recoverable error. Just sent once (as the processor stops).                            |

## Security Countermeasures

| Countermeasure ID                       | Description                                                                                                                                                                                                                                                                                                                                                        |
|:----------------------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ACC.MEM.SCRAMBLE                        | Both the imem and dmem are scrambled by using prim_ram_1p_scr.                                                                                                                                                                                                                                                                                                     |
| ACC.DATA.MEM.INTEGRITY                  | Dmem is protected with ECC integrity. This is carried through to ACC's register file.                                                                                                                                                                                                                                                                              |
| ACC.INSTRUCTION.MEM.INTEGRITY           | Imem is protected with ECC integrity. This is carried through into ACC's execute stage.                                                                                                                                                                                                                                                                            |
| ACC.BUS.INTEGRITY                       | End-to-end bus integrity scheme.                                                                                                                                                                                                                                                                                                                                   |
| ACC.CONTROLLER.FSM.GLOBAL_ESC           | The controller FSM moves to a terminal error state upon global escalation.                                                                                                                                                                                                                                                                                         |
| ACC.CONTROLLER.FSM.LOCAL_ESC            | The controller FSM moves to a terminal error state upon local escalation. Can be triggered by CONTROLLER.FSM.SPARSE, SCRAMBLE_CTRL.FSM.SPARSE, and START_STOP_CTRL.FSM.SPARSE.                                                                                                                                                                                     |
| ACC.CONTROLLER.FSM.SPARSE               | The controller FSM uses a sparse state encoding.                                                                                                                                                                                                                                                                                                                   |
| ACC.SCRAMBLE.KEY.SIDELOAD               | The scrambling key is sideloaded from OTP and thus unreadable by SW.                                                                                                                                                                                                                                                                                               |
| ACC.SCRAMBLE_CTRL.FSM.LOCAL_ESC         | The scramble control FSM moves to a terminal error state upon local escalation. Can be triggered by SCRAMBLE_CTRL.FSM.SPARSE.                                                                                                                                                                                                                                      |
| ACC.SCRAMBLE_CTRL.FSM.SPARSE            | The scramble control FSM uses a sparse state encoding.                                                                                                                                                                                                                                                                                                             |
| ACC.START_STOP_CTRL.FSM.GLOBAL_ESC      | The start-stop control FSM moves to a terminal error state upon global escalation.                                                                                                                                                                                                                                                                                 |
| ACC.START_STOP_CTRL.FSM.LOCAL_ESC       | The start-stop control FSM moves to a terminal error state upon local escalation. Can be triggered by START_STOP_CTRL.FSM.SPARSE.                                                                                                                                                                                                                                  |
| ACC.START_STOP_CTRL.FSM.SPARSE          | The start-stop control FSM uses a sparse state encoding.                                                                                                                                                                                                                                                                                                           |
| ACC.DATA_REG_SW.SCA                     | Blanking of bignum data paths when unused by the executing instruction.                                                                                                                                                                                                                                                                                            |
| ACC.CTRL.REDUN                          | Check pre-decoded control matches separately decoded control from main decoder. This includes control signals used for blanking, pushing/popping the call stack, controlling loop and branch/jump instructions, as well as the actual branch target.                                                                                                               |
| ACC.PC.CTRL_FLOW.REDUN                  | Check prefetch stage PC and execute stage PC match. The prefetch stage and execute stage store their PC's separately and have separate increment calculations.                                                                                                                                                                                                     |
| ACC.RND.BUS.CONSISTENCY                 | Comparison on successive bus values received over the EDN RND interface.                                                                                                                                                                                                                                                                                           |
| ACC.RND.RNG.DIGEST                      | Checking that the random numbers received over the EDN RND interface have not been generated from entropy that failed the FIPS health checks in the entropy source.                                                                                                                                                                                                |
| ACC.RF_BASE.DATA_REG_SW.INTEGRITY       | Register file is protected with ECC integrity.                                                                                                                                                                                                                                                                                                                     |
| ACC.RF_BASE.DATA_REG_SW.GLITCH_DETECT   | This countermeasure checks for spurious write-enable signals on the register file by monitoring the one-hot0 property of the individual write-enable strobes.                                                                                                                                                                                                      |
| ACC.STACK_WR_PTR.CTR.REDUN              | The write pointer of the stack (used for calls and loops) is redundant. If the two instances of the counter mismatch, an error is emitted.                                                                                                                                                                                                                         |
| ACC.RF_BIGNUM.DATA_REG_SW.INTEGRITY     | Register file is protected with ECC integrity.                                                                                                                                                                                                                                                                                                                     |
| ACC.RF_BIGNUM.DATA_REG_SW.GLITCH_DETECT | This countermeasure checks for spurious write-enable signals on the register file by monitoring the one-hot0 property of the individual write-enable strobes.                                                                                                                                                                                                      |
| ACC.LOOP_STACK.CTR.REDUN                | The iteration counter of each entry in the loop step uses cross counts via prim_count.                                                                                                                                                                                                                                                                             |
| ACC.LOOP_STACK.ADDR.INTEGRITY           | Loop start and end address on the loop stack are protected with ECC integrity.                                                                                                                                                                                                                                                                                     |
| ACC.CALL_STACK.ADDR.INTEGRITY           | Call stack entries are protected with ECC integrity.                                                                                                                                                                                                                                                                                                               |
| ACC.START_STOP_CTRL.STATE.CONSISTENCY   | The secure wipe handshake between acc_controller and acc_start_stop_control uses a level-based req/ack interface. At the acc_controller end, there is a check for unexpected acks. In acc_start_stop_control, there is a check for secure wipe requests when we aren't in a state that allows it, and also a check for if the request drops at an unexpected time. |
| ACC.DATA.MEM.SEC_WIPE                   | Rotate the scrambling key, effectively wiping the dmem. Initiated on command, upon fatal errors and before RMA entry.                                                                                                                                                                                                                                              |
| ACC.INSTRUCTION.MEM.SEC_WIPE            | Rotate the scrambling key, effectively wiping the imem. Initiated on command, upon fatal errors and before RMA entry.                                                                                                                                                                                                                                              |
| ACC.DATA_REG_SW.SEC_WIPE                | Securely wipe programmer visible ACC register (GPRs, WDRs, CSRs, WSRs) state with random data. Initiated after reset, at the end of any ACC operation, upon recoverable and fatal errors, and before RMA entry.                                                                                                                                                    |
| ACC.WRITE.MEM.INTEGRITY                 | A software visible checksum is calculated for all dmem and imem writes                                                                                                                                                                                                                                                                                             |
| ACC.CTRL_FLOW.COUNT                     | A software visible count of instructions executed                                                                                                                                                                                                                                                                                                                  |
| ACC.CTRL_FLOW.SCA                       | ACC architecture does not have any data dependent timing behaviour                                                                                                                                                                                                                                                                                                 |
| ACC.DATA.MEM.SW_NOACCESS                | A portion of DMEM is invisible to CPU software                                                                                                                                                                                                                                                                                                                     |
| ACC.KEY.SIDELOAD                        | Keys can be sideloaded without exposing them to the CPU                                                                                                                                                                                                                                                                                                            |
| ACC.TLUL_FIFO.CTR.REDUN                 | The TL-UL response FIFO pointers are implemented with duplicate counters.                                                                                                                                                                                                                                                                                          |


<!-- END CMDGEN -->

## Hardware Interface Requirements

ACC connects to other components in an OpenTitan system.
This section lists requirements on those interfaces that go beyond the physical connectivity.

### Entropy Distribution Network (EDN)

ACC has two EDN connections: `edn_urnd` and `edn_rnd`.
What kind of randomness is provided on the EDN connections is configurable at runtime, but unknown to ACC.
To maintain its security properties, ACC requires the following configuration for the two EDN connections:

* ACC has no specific requirements on the randomness drawn from `edn_urnd`.
  For performance reasons, requests on this EDN connection should be answered quickly.
* `edn_rnd` must provide AIS31-compliant class PTG.3 random numbers.
  The randomness from this interface is made available through the `RND` WSR and intended to be used for key generation.

### Life Cycle Controller (LC_CTRL)

ACC has three LC_CTRL connections: one for triggering life cycle escalation requests (`lc_escalate_en`) and two for handling RMA entry (`lc_rma_req/ack`).

As LC_CTRL might sit in a different clock domain and since all these connections are using multi-bit signals, ACC might observe staggered signal transitions due to the clock domain crossings.
To avoid spurious life cycle escalations and to enable reliable RMA entry, it should be ensured that:

* The `lc_escalate_en` and `lc_rma_req` inputs are stably driven to `lc_ctrl_pkg::Off` before releasing the reset of ACC.
* When triggering RMA entry, the `lc_rma_req` input switches from `lc_ctrl_pkg::Off` to `lc_ctrl_pkg::On` exactly once, and then remains `On` until ACC signals completion of the secure wipe operation with the `lc_rma_ack` output switching to `lc_ctrl_pkg::On`.
