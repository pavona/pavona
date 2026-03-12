# SPI Device HWIP Technical Specification

# Overview

## Features

### SPI Flash/ Passthrough Modes

- Supports Serial Flash emulation
  - HW processed Read Status, Read JEDEC ID, Read SFDP, EN4B/ EX4B, and multiple read commands
  - 16 depth Command/Address FIFOs and 256B Payload buffer for command upload
  - 2×1kB read buffer for read commands
  - 1kB mailbox buffer and configurable mailbox target address
- Supports SPI passthrough
  - Filtering of inadmissible commands (256-bit filter CSR)
  - Address translation for read commands
  - First 4B payload translation
  - HW control of SPI PADs' output enable based on command information list
  - SW configurable internal command process for Read Status, Read JEDEC ID, Read SFDP, and read access to the mailbox space
  - Targets 33MHz @ Quad read mode, fall backs to 25MHz
  - Optional pipelined reads to decrease timing pressure for passthrough mode
- Automated tracking of 3B/4B address mode in the flash and passthrough modes
- 24 entries of command information slots
  - Configurable address/dummy/payload size per opcode

### TPM over SPI

- In compliance with [TPM PC Client Platform][TPM PCCP]
- Up to 64B compile-time configurable read and write data buffer (default: 4B)
- 1 TPM command (8-bit) and 1 address (24-bit) buffer
- HW controlled wait state
- Shared SPI with other SPI Device functionalities. Unique `CS#` for the TPM
  - Flash or Passthrough mode can be active with TPM mode, with the shared pins allowing them to time-multiplex the bus.
- HW processed registers for read requests during FIFO mode
  - `TPM_ACCESS_x`, `TPM_STS_x`, `TPM_INTF_CAPABILITY`, `TPM_INT_ENABLE`, `TPM_INT_STATUS`, `TPM_INT_VECTOR`, `TPM_DID_VID`, `TPM_RID`
  - `TPM_HASH_START` returns `FFh`
- 5 Locality (compile-time parameter)

## Description

The SPI device module consists of three functions, SPI Flash mode, SPI passthrough mode, and TPM over SPI mode.

The software can receive TPM commands with payload (address and data) and respond to the read commands with the return data using the TPM submodule within the IP.
The submodule provides the command, address, write, and read FIFOs for the software to communicate with the TPM host system.
The submodule also supports the software by managing a certain set of the FIFO registers and quickly returning the read request by hardware.

In Flash mode, the SPI Device behaves as a Serial Flash device by recognizing SPI Flash commands and processing them in hardware.
The commands processed by hardware are Read Status (1, 2, 3), Read JEDEC ID, Read SFDP, EN4B/ EX4B, and read commands with the aid of software.
The IP supports Normal Read, Fast Read, Fast Read Dual Output, and Fast Read Quad Output.
This version of the IP does not support Dual IO, Quad IO, QPI commands.

In Passthrough mode, the SPI Device receives SPI transactions from a host system and forwards the transactions to a downstream flash device.
Software may filter prohibited commands by configuring a 256-bit [`FILTER`](doc/registers.md#filter) CSR.
The IP cancels ongoing transactions if the received opcode matches the filter CSR by de-asserting `CSb` and gating `SCK` to the downstream flash device.

The software may program CSRs to change the address and/or the first 4 bytes of payload on-the-fly in Passthrough mode.
The address translation feature allows SW to maintain A/B binary images without the help of the host system.
The payload translation may be used to change the payload of Write Status commands to not allow certain fields to be modified.

In Passthrough mode, parts of the Flash module can be active.
While in Passthrough mode, the software may configure the IP to process certain commands internally.
Software is recommended to filter the commands being processed internally.
Mailbox is an exception as it shares the Read command opcode.

### SPI Device Modes and Active Submodules

The SPI Device HWIP has two flash-like modes, in addition to the TPM mode.
Flash and Passthrough modes share many parts of the datapath.
With Flash mode, all commands target the internal node, and a special read buffer is available to stream data back to the host in FIFO style.
With Passthrough mode, commands may target the internal node and/or a downstream SPI flash, and the read buffer is not available.
The TPM mode only shares the SPI while having a separate `CSb` port, which allows the host to send TPM commands while other SPI modes are active.

Mode     | Status | JEDEC | SFDP | Mailbox | Read | Addr4B | Upload | Passthrough
---------|--------|-------|------|---------|------|--------|--------|-------------
Flash    |  Y     |   Y   |   Y  |   Y     |   Y  |   Y    |   Y    |
Passthru |  Y/N   |  Y/N  |  Y/N |  Y/N    |   N  |   Y    |   Y    |     Y

*Y/N*: Based on `INTERCEPT_EN`

### Clocking Requirements

SPI Device requires the core clock to have a frequency that is at least 1/4 the SPI clock frequency.

## Compatibility

The SPI device supports emulating an EEPROM (SPI flash mode in this document).
The TPM submodule conforms to the [TPM over SPI 2.0][] specification. The TPM operation follows [TCG PC Client Platform TPM Profile Specification Section 7][TPM PCCP].

[TPM over SPI 2.0]: https://trustedcomputinggroup.org/wp-content/uploads/Trusted-Platform-Module-Library-Family-2.0-Level-00-Revision-1.59_pub.zip
[TPM PCCP]: https://trustedcomputinggroup.org/resource/pc-client-platform-tpm-profile-ptp-specification/
