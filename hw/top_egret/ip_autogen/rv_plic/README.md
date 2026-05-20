# Interrupt Controller Technical Specification

# Overview

This document specifies the Interrupt Controller (RV_PLIC) functionality.
As an IP integrated within the broader Pavona ecosystem, this module conforms to [Pavona's Comportability Specification](../../../../doc/contributing/hw/comportability/README.md).

## Features

- RISC-V Platform-Level Interrupt Controller (PLIC) compliant interrupt controller
- Support for arbitrary number of interrupt vectors (up to 1023) and targets
- Support for interrupt enable, interrupt status registers
- Memory-mapped MSIP register per HART for software interrupt control.

## Description

The RV_PLIC module is designed to manage various interrupt sources from the
peripherals. It receives interrupt events as either edge or level of the
incoming interrupt signals (``intr_src_i``) and can notify multiple targets.

## Compatibility

The RV_PLIC is compatible with any RISC-V core implementing the RISC-V privilege specification.
