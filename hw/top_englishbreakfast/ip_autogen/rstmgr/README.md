# Reset Manager HWIP Technical Specification

# Overview

This document describes the functionality of the reset controller and its interaction with the rest of the Pavona ecosystem.
As an IP integrated within this ecosystem, this module conforms to [Pavona's Comportability Specification](../../../../doc/contributing/hw/comportability/README.md).

## Features

*   Stretch incoming POR.
*   Cascaded system resets.
*   Peripheral system reset requests.
*   RISC-V non-debug-module reset support.
*   Limited and selective software controlled module reset.
*   Always-on reset information register.
*   Always-on alert crash dump register.
*   Always-on CPU crash dump register.
*   Reset consistency checks.
