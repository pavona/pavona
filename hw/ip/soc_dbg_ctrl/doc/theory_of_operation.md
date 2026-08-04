# Theory of Operation

At a high level, soc_dbg_ctrl communicates with the lifecycle controller and OTP to control the active debugging state of the RoT.
In the following sections, different elements of the IP and their behavior will be explained.

<!-- BEGIN-FEATURE: SOC_DBG_CTRL.POLICY.SW_PROGRAMMABLE -->
<!-- BEGIN-FEATURE: SOC_DBG_CTRL.POLICY.LC_RMA_OVERRIDE -->
<!-- BEGIN-FEATURE: SOC_DBG_CTRL.POLICY.LC_BLANK_OVERRIDE -->
<!-- BEGIN-FEATURE: SOC_DBG_CTRL.POLICY.LC_PREPROD_OVERRIDE -->
<!-- BEGIN-FEATURE: SOC_DBG_CTRL.POLICY.RELOCK_REUNLOCK -->
## SOC_DBG_STATE

The `soc_dbg_state` is a lifecycle controller broadcast state that is driven directly from the OTP HW_CFG2 partition and used as an input in `soc_dbg_ctrl`.
The `soc_dbg_state_e` enum defines the debug states as `SocDbgStBlank`, `SocDbgStPreProd`, and `SocDbgStProd`.
Permissible actions by `soc_dbg_ctrl` change as the OTP field is updated.

### SocDbgStBlank
While in the `SocDbgStBlank` state the debug policy will be locked outside of the following exemptions.
- DFT is enabled by the lifecycle controller.
- Hardware debug is enabled by the lifecycle controller.

If either of these conditions is met, the debug policy will be set to Category 4, without the ability for software override.

### SocDbgStPreProd
While in the `SocDbgStPreProd` state the debug policy is set to Category 4 without the ability for software override.

### SocDbgStProd
If the current state is `SocDbgStProd` then the debug policy may be written to by software through the [`DEBUG_POLICY_CATEGORY_SHADOWED`](registers.md#debug_policy_category_shadowed) CSR.
Software may also set the [`DEBUG_POLICY_RELOCKED`](registers.md#debug_policy_relocked) CSR to indicate that the debugger has relocked the part.
The relocked value is broadcast alongside the category and valid in the policy bus.
The written `DEBUG_POLICY_CATEGORY_SHADOWED` value will only reach the output bus while not in a RMA state and the CPU is running.
If RMA is otherwise set (strictly true), then the debug policy set by software is overwritten and set to Category 4.
<!-- END-FEATURE: SOC_DBG_CTRL.POLICY.SW_PROGRAMMABLE -->
<!-- END-FEATURE: SOC_DBG_CTRL.POLICY.LC_RMA_OVERRIDE -->
<!-- END-FEATURE: SOC_DBG_CTRL.POLICY.LC_BLANK_OVERRIDE -->
<!-- END-FEATURE: SOC_DBG_CTRL.POLICY.LC_PREPROD_OVERRIDE -->
<!-- END-FEATURE: SOC_DBG_CTRL.POLICY.RELOCK_REUNLOCK -->

<!-- BEGIN-FEATURE: SOC_DBG_CTRL.TRACE.CORE_POLICY_READBACK -->
<!-- BEGIN-FEATURE: SOC_DBG_CTRL.TRACE.JTAG_POLICY_READBACK -->
## CSR Tracing

There are several trace registers implemented in the `soc_dbg_ctrl` [`register mapping`](registers.md) that are used to continuously broadcast the current debug policy to other portions of the SoC.

For observing the debug category, the RoT can use the [`TRACE_DEBUG_POLICY_CATEGORY`](registers.md#trace_debug_policy_category), whereas an external debugger has access to the [`JTAG_TRACE_DEBUG_POLICY_CATEGORY`](registers.md#jtag_trace_debug_policy_category) CSR through its JTAG connection.

Reading the debug `valid` and `relocked` status of the debug policy uses the [`TRACE_DEBUG_POLICY_VALID_RELOCKED`](registers.md#trace_debug_policy_valid_relocked) CSR for the RoT, and the [`JTAG_TRACE_DEBUG_POLICY_VALID_RELOCKED`](registers.md#jtag_trace_debug_policy_valid_relocked) CSR for the external debugger.
<!-- END-FEATURE: SOC_DBG_CTRL.TRACE.CORE_POLICY_READBACK -->
<!-- END-FEATURE: SOC_DBG_CTRL.TRACE.JTAG_POLICY_READBACK -->

<!-- BEGIN-FEATURE: SOC_DBG_CTRL.TRACE.JTAG_BOOT_STATUS_GATED_BY_DFT -->
<!-- BEGIN-FEATURE: SOC_DBG_CTRL.TRACE.AUTH_PROGRESS_MIRRORING -->
### LC_DFT_EN Gating
There are two additional status CSR registers that are accessible to an external debugger through JTAG, the [`JTAG_BOOT_STATUS`](registers.md#jtag_boot_status) CSR, and the traced [`JTAG_TRACE_SOC_DBG_STATE`](registers.md#jtag_trace_soc_dbg_state) CSR.
For `JTAG_BOOT_STATUS`, this is a mirror of the RoT's report for the state of debug authorization exchange.
`JTAG_TRACE_SOC_DBG_STATE` is simply a continuously broadcast value for the current [`soc_dbg_state`](#soc_dbg_state).
Unlike the other CSR registers, these two are gated behind the `lc_dft_en` signal and will only reflect the hardware state while it is asserted.
Otherwise all fields of these JTAG registers will read as zero.
<!-- END-FEATURE: SOC_DBG_CTRL.TRACE.JTAG_BOOT_STATUS_GATED_BY_DFT -->
<!-- END-FEATURE: SOC_DBG_CTRL.TRACE.AUTH_PROGRESS_MIRRORING -->

<!-- BEGIN-FEATURE: SOC_DBG_CTRL.HALT.FSM -->
<!-- BEGIN-FEATURE: SOC_DBG_CTRL.HALT.PRODUCTION_PASSTHROUGH -->
## Ibex Halting
`soc_dbg_ctrl` can hold Ibex in a halted state and prevent it from fetching code during an early debug or DFT scenario.
There is a sparse FSM implemented to track the halt state following a RoT reset.
If the RoT is not in its RAW RMA state then the halt procedure is bypassed and Ibex may continue its boot process.
While in a RMA state, the halting of Ibex is decided based on a combination of DFT debug being enabled by the lifecycle controller, the external `halt_cpu_boot_i` pin being asserted, and whether the JTAG command to stop the boot flow is asserted.
In both FSM paths, there is a single terminal state that can not be exited until a reset, preventing Ibex from being re-halted until that point.
<!-- END-FEATURE: SOC_DBG_CTRL.HALT.FSM -->
<!-- END-FEATURE: SOC_DBG_CTRL.HALT.PRODUCTION_PASSTHROUGH -->
