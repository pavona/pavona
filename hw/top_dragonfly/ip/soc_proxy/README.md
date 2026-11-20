# SoC Proxy Technical Specification

SoC Proxy is a simple comportable IP module that facilitates the breakout of signals and buses internal to Dragonfly (similar to Sensor Control for AST).

## Comportable Interfaces

- Clock / reset for the fast clock domain, plus an always-on clock / power-on reset used by the
  wakeup and reset request paths
- 1 TL-UL Device port for comportable CSR node
- 1 TL-UL Device port with an address range to egress into CTN
- 1 Fatal alert for bus integrity
- 1 Wakeup request (external)
- 1 Reset request (external), enabled after reset

## Inter-module interfaces

- 1 TL-UL Host port pair for the DMA to egress into CTN
- 1 TL-UL Host port pair for the MISC to egress into CTN
- 1 TL-UL Host port for the muxed and translated egress into CTN
- LSIO trigger inputs from I2C, SPI Host and UART, and the collated trigger output for the DMA
- 4-bit integrator ID, reserved for integrator-specific base address translation

## SoC-facing interfaces

- 1 TL-UL Host port for egress into CTN
- 1 Wakeup request, asynchronous and level-encoded
- 1 Reset request, asynchronous and level-encoded
- 8 LSIO triggers, synchronous
- 16 general-purpose inputs
- 16 general-purpose outputs
