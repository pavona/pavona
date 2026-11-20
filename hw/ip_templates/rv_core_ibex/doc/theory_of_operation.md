<!-- BEGIN-FEATURE: RV_CORE_IBEX.CPU.ISA -->
<!-- BEGIN-FEATURE: RV_CORE_IBEX.CPU.EPMP -->
<!-- BEGIN-FEATURE: RV_CORE_IBEX.CPU.MEMORY -->
# Theory of Operation
This module wraps a RISC-V core capable of executing RV32ICMB instructions (a subset of bitmanip is implemented, see the Ibex core documentation for details), and exposes the available address space to software through a TileLink-UL (TL-UL)interface with system memory. The core also implements the enhanced Physical Memory Protection (ePMP) scheme defined by the RISC-V Privileged Architecture Specification. Sixteen programmable protection regions are available. Memory transactions may optionally pass through the address translation logic described below before being forwarded into the memry system.
<!-- END-FEATURE: RV_CORE_IBEX.CPU.ISA -->
<!-- END-FEATURE: RV_CORE_IBEX.CPU.EPMP -->
<!-- END-FEATURE: RV_CORE_IBEX.CPU.MEMORY -->

<!-- BEGIN-FEATURE: RV_CORE_IBEX.ADDRESS_TRANSLATION -->
## Simple Address Translation

The wrapper supports a simple address translation scheme.
The goal of the scheme is to provide hardware support for A/B software copies.

Each copy of the software is stored at a different location.
Depending upon which execution slot is active, a different copy is used.
This creates an issue because each copy of software has different addresses and thus must be linked differently.
Ideally, software should be able to assume one address all the time, and the hardware should remap to the appropriate physical location.

The translation scheme is based on NAPOT (natural alignment to power of two).
Software picks a matching region and also a remap address.
When an incoming transaction matches the selected power-of-2 region, it is redirected to the new address.
If a transaction does not match, then it is directly passed through.

This allows software to place the executable code at a virtual address in the system and re-map that to the appropriate physical block.

There are separate translations controls for instruction and data.
Each control contains two programmable regions (2 for instruction and 2 for data).
If a transaction matches multiple regions, the lowest indexed region has priority.

For details on how to program the related registers, please see [`IBUS_ADDR_MATCHING_0`](registers.md#ibus_addr_matching) and [`IBUS_REMAP_ADDR_0`](registers.md#ibus_remap_addr).
<!-- END-FEATURE: RV_CORE_IBEX.ADDRESS_TRANSLATION -->

<!-- BEGIN-FEATURE: RV_CORE_IBEX.CPU.ICACHE -->
### Translation and Instruction Caching

The simple address translation scheme used in this design is not aware of the processor context, specifically, any instruction caching done in the core.
This means if the address translation scheme were to change, instructions that are already cached may not reflect the updated address setting.

In order to correctly utilize simple address translation along with instruction caching, it is recommended that after the address is updated a `FENCE.I` instruction is issued.
The `FENCE.I` instruction forces the instruction cache to flush, and this aligns the core to the new address setting.
<!-- END-FEATURE: RV_CORE_IBEX.CPU.ICACHE -->

<!-- BEGIN-FEATURE: RV_CORE_IBEX.RND -->
## Random Number Generation

The wrapper has a connection to the [Entropy Distribution Network (EDN)](../../../../ip/edn/README.md) with a register based interface.
The [`RND_DATA`](registers.md#rnd_data) register provides 32-bits directly from the EDN.
[`RND_STATUS.RND_DATA_VALID`](registers.md#rnd_status) indicates if the data in [`RND_DATA`](registers.md#rnd_data) is valid or not.
A polling style interface is used to get new random data.
Any read to [`RND_DATA`](registers.md#rnd_data) when it is valid invalidates the data and triggers an EDN request for new data.
Software should poll [`RND_STATUS.RND_DATA_VALID`](registers.md#rnd_status) until it is valid and then read from [`RND_DATA`](registers.md#rnd_data) to get the new random data.
Either the data is valid or a request for new data is pending.
It is not possible to have a state where there is no valid data without new data being requested.

Upon reset [`RND_DATA`](registers.md#rnd_data) is invalid.
A request is made to the EDN immediately out of reset, this will not be answered until the EDN is enabled.
Software should take care not to enable the EDN until the entropy complex configuration is as desired.
When the entropy complex configuration is changed reading [`RND_DATA`](registers.md#rnd_data) when it is valid will suffice to flush any old random data to trigger a new request under the new configuration.
If a EDN request is pending when the entropy complex configuration is changed ([`RND_STATUS.RND_DATA_VALID`](registers.md#rnd_status) is clear), it is advisable to wait until it is complete and then flush out the data to ensure the fresh value was produced under the new configuration.
<!-- END-FEATURE: RV_CORE_IBEX.RND -->

<!-- BEGIN-FEATURE: RV_CORE_IBEX.CPU.INTERRUPTS -->
## Interrupts

The wrapped RISC-V core supports the following interrupt sources:

* Software interrupt, controlled by a memory mapped PLIC register
* External interrupt, from interrupts prioritised by the PLIC
* Timer interrupt, from rv_timer module
* Non-maskable interrupt, triggered by watchdog or alert handler
<!-- END-FEATURE: RV_CORE_IBEX.CPU.INTERRUPTS -->

<!-- BEGIN-FEATURE: RV_CORE_IBEX.CRASH_DUMP -->
## Crash Dump Collection

In general, when the CPU encounters an error, it is software's responsibility to collect error status and supply it for debug.

However, there are situations where it may not be possible for software to collect any error logging.
These situations include but are not limited to:
* A hung transaction that causes watchdog to expire.
* A double fault that causes the processor to stop execution.
* An alert escalation that directly resets the system without any software intervention.

Under these situations, the software has no hints as to where the error occurred.
To mitigate this issue, Ibex provides crash dump information that can be directly captured in the `rstmgr` for last resort debug after the reset event.

The Ibex crash dump state contains 5 words of debug data:
* word 0: The last exception address (`mtval`)
* word 1: The last exception PC (`mepc`)
* word 2: The last data access address
* word 3: The next PC
* word 4: The current PC

The crash dump information transmitted to the `rstmgr` contains 7 words of debug data and a 1-bit valid indication:
* words 0-4: The current crash dump state
* word 5: The previous exception address (`mtval`)
* word 6: The previous exception PC (`mepc`)
* MSB: Previous state valid indication.

Under normal circumstances, only the current crash dump state is valid.
When the CPU encounters a double fault, the current crash dump is moved to previous, and the new crash dump is shown in current.

This allows the software to see both fault locations and debug accordingly.

In terms of how the crash state information can be used, the following are a few examples.
<!-- END-FEATURE: RV_CORE_IBEX.CRASH_DUMP -->

### Hung Transaction

Assuming the system has a watchdog counter setup, when a CPU transaction hangs the bus (accessing a device whose clock is not turned on or is under reset), the PC and bus access freeze in place until the watchdog resets the system.
Upon reset release, software can check the last PC and data access address to get an idea of what transaction might have caused the bus to hang.

### Double Exception

If the software has some kind of error and encounters two exceptions in a row, the previous exception PC and address show the location of the first exception, while the current exception address and PC show the location of the most recent exception.


## Fetch Enable

Ibex has a top-level fetch enable input (``fetch_enable_i``), which uses the same multi-bit encoding used by the lifecycle controller.
When Ibex fetch is disabled it will cease to execute, but will complete instructions currently in the pipeline.
Ibex fetch is enabled when all of the following conditions are met:
  - The lifecycle controller has enabled it
  - The power manager has enabled it
  - A ``fatal_hw_err`` alert hasn't been raised

### Local Escalation Path

When the ``fatal_hw_err`` alert is raised Ibex fetch is disabled and will remain disabled until ``rv_core_ibex`` is reset.
