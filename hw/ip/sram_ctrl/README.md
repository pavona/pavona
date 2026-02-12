# SRAM Controller Technical Specification

# Overview

This document specifies the functionality of the SRAM memory controller.
As an IP integrated within the broader Pavona ecosystem, this module conforms to [Pavona's Comportability Specification](../../../doc/contributing/hw/comportability/README.md).


The SRAM controller contains the SRAM data and address scrambling devices, and provides CSRs for requesting the scrambling keys and triggering the hardware initialization feature.

## Features

- [Lightweight scrambling mechanism](../prim/doc/prim_ram_1p_scr.md#custom-substitution-permutation-network) based on the PRINCE cipher.
- Key request logic for the lightweight memory and address scrambling device.
- Alert sender and checking logic for detecting bus integrity failures.
- LFSR-based memory initialization feature.
- Access controls to allow / disallow code execution from SRAM.
- Security hardening when integrity error has been detected.
- Optional memory readback mode for detecting memory integrity errors.
