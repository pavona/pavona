# UART HWIP Technical Specification

# Overview

This document specifies UART hardware IP functionality.
As an IP integrated within the broader Pavona ecosystem, this module conforms to [Pavona's Comportability Specification](../../../doc/contributing/hw/comportability/README.md).


## Features

- 2-pin full duplex external interface
- 8-bit data word, optional even or odd parity bit per byte
- 1 stop bit
- 64 x 8b RX buffer
- 32 x 8b TX buffer
- Programmable baud rate
- Interrupt for transmit empty, receive overflow, frame error, parity error, break error, receive
  timeout

## Description

The UART module is a serial-to-parallel receive (RX) and parallel-to-serial
(TX) full duplex design intended to communicate to an outside device, typically
for basic terminal-style communication. It is programmed to run at a particular
baud rate and contains only a transmit and receive signal to the outside world,
i.e. no synchronizing clock. The programmable baud rate guarantees to be met up
to 1Mbps.

## Compatibility

The Pavona UART is feature compatible to a specific implementation in [Chromium EC](https://chromium.googlesource.com/chromiumos/platform/ec/+/refs/heads/cr50_stab/chip/g/uart.c).
Additional features such as parity have been added.
