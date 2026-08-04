# Theory of Operation

SoC Proxy is the boundary between the Dragonfly RoT and the surrounding SoC.
It carries no functional state of its own beyond the pipeline and synchronizer stages described below: its register node exists only to keep the comportable device port alive and exposes a single read-only `DUMMY` register.
Everything the block does is therefore a transformation applied to signals or bus traffic in flight, and the sections below describe those transformations.
The interfaces themselves are enumerated in the [README](../README.md).

<!-- BEGIN-FEATURE: SOC_PROXY.CTN_EGRESS.MUX -->
## CTN Egress Multiplexing

Three TL-UL sources contend for the single host port which leaves the block towards the CTN: the comportable `ctn` device port, the DMA host port and the MISC host port.
They are combined by a `tlul_socket_m1` instance in which every host side is configured to pass requests and responses through combinationally with a two-entry buffer, while the device side registers both directions with a four-entry buffer.

That asymmetry is deliberate: the registered device side inserts the pipeline stage which shortens the timing path through the downstream access-control range check, at the cost of a cycle of latency on every CTN transaction.
The socket tracks outstanding transactions, so responses return to the originating host port even when requests from different sources are interleaved.
<!-- END-FEATURE: SOC_PROXY.CTN_EGRESS.MUX -->

<!-- BEGIN-FEATURE: SOC_PROXY.CTN_EGRESS.BAT -->
## Base Address Translation

The muxed request then passes through the base address translation stage before leaving the block.
A request is treated as CTN-bound when it is valid and its two most significant address bits are `2'b01`, that is when it addresses the [1G, 2G) window.
For such a request those two bits are replaced with zeros, which downlifts the address into the [0, 1G) window that the CTN expects; every other request keeps its address unchanged.

Only the address field is rewritten — opcode, size, source, mask, data, parameters and user bits are forwarded verbatim.
Because the address is covered by TL-UL command integrity, the translated request is passed through `tlul_cmd_intg_gen` so that the integrity bits are regenerated to match the new address; forwarding the original bits would make every translated request look corrupted downstream.
The response channel is fed straight back without modification.

The block also receives a four-bit `integrator_id_i`, which is reserved for integrator-specific translation schemes and is unused in the open-source implementation.
<!-- END-FEATURE: SOC_PROXY.CTN_EGRESS.BAT -->

<!-- BEGIN-FEATURE: SOC_PROXY.EXTERNAL_WAKEUP -->
## External Wakeup Requests

The SoC drives `soc_wkup_async_i` asynchronously and level-encoded.
It is brought into the always-on clock domain through a two-flop synchronizer clocked by `clk_aon_i` and reset by `rst_por_ni`, and the synchronized output is the wakeup request presented to the power manager.

The always-on domain is what makes the path useful: the request has to be observable while the rest of the chip is in low power, so the synchronizer cannot sit in the fast clock domain.
No filtering is applied here, so any level on the SoC input which survives synchronization is reported as a wakeup.
<!-- END-FEATURE: SOC_PROXY.EXTERNAL_WAKEUP -->

<!-- BEGIN-FEATURE: SOC_PROXY.EXTERNAL_RESET -->
## External Reset Requests

The SoC reset request `soc_rst_req_async_i` is also asynchronous and level-encoded, and is likewise brought into the always-on domain.
Unlike the wakeup path it passes through a `prim_filter` configured with asynchronous input handling and a four-cycle window, so the request has to be stable for four consecutive always-on clock cycles before it is forwarded.

This filtering is the difference that matters between the two paths: a spurious pulse on the SoC reset input would otherwise reset parts of the chip, so glitches are rejected in hardware rather than being left for software to arbitrate.
The reset request is enabled after reset, meaning the SoC can reset the chip without any prior configuration.
<!-- END-FEATURE: SOC_PROXY.EXTERNAL_RESET -->

<!-- BEGIN-FEATURE: SOC_PROXY.GPIO -->
## General-Purpose IO Feed-Through

The sixteen general-purpose inputs and sixteen general-purpose outputs are wired straight through: chip inputs drive the SoC-facing input port, and the SoC-facing output port drives the chip outputs.
The output enables are tied permanently asserted, so the pads are always driven and there is no per-pin direction control inside this block.

There is no synchronization, filtering or register stage on either direction, and no CSR to configure them.
Which physical pins the signals appear on is therefore decided entirely by the pinmux, not here.
<!-- END-FEATURE: SOC_PROXY.GPIO -->

<!-- BEGIN-FEATURE: SOC_PROXY.LSIO_TRIGGER -->
## LSIO Trigger Collation

The DMA is triggered by low-speed IO peripherals through a single trigger vector which this block assembles.
The I2C, SPI Host and UART triggers originate in the peripheral clock domain and each passes through its own two-flop synchronizer into the fast clock domain, while the eight SoC-provided triggers are already synchronous and are taken as they are.

The synchronized peripheral triggers and the SoC triggers are then concatenated into the vector handed to the DMA, with the SoC triggers occupying the upper bits and I2C, SPI Host and UART the lower ones.
The block performs no edge detection, arbitration or masking on these signals; it only crosses the clock domain and packs them.
<!-- END-FEATURE: SOC_PROXY.LSIO_TRIGGER -->

## Bus Integrity

An integrity error detected on the register interface, or a failure of the register write-enable one-hot check, raises the fatal `fatal_alert_intg` alert.
Since the register node holds no functional state, this alert is the only consequence of such an error inside the block.
