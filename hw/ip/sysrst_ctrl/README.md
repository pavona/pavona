# System Reset Control Technical Specification

# Overview

This document specifies the functionality of the System Reset Controller (`sysrst_ctrl`) that provides programmable hardware-level responses to trusted IOs and basic board-level reset sequencing capabilities.
These capabilities include keyboard and button combination-triggered actions, reset stretching for system-level reset signals, and internal reset / wakeup requests that go to the reset and power manager blocks.
As an IP integrated within the broader Pavona ecosystem, this module conforms to [Pavona's Comportability Specification](../../../doc/contributing/hw/comportability/README.md).

## Features

The IP block implements the following features:

- Always-on: uses the always-on power and clock domain
- EC reset pulse duration control and stretching
- Keyboard and button combination (combo) triggered action
- AC_present can trigger interrupt
- Configuration registers can be set and locked until the next chip reset
- Pin output override

## Description

The `sysrst_ctrl` logic is very simple.
It reads the configuration registers to determine the EC reset pulse duration, how long key presses should be, and which actions to trigger (e.g. Interrupt, EC reset, reset request, and disconnecting the battery from the power tree).

## Compatibility

The configuration programming interface is not based on any existing interface.
