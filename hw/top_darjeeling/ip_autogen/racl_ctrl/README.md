# RACL Control Technical specification

# Overview

This document specifies the functionality of the Register Access Control List (RACL) control permission IP.
RACL Control is an interface between the TileLink bus and RACL policy distribution and error logs.
As an IP integrated within the broader Pavona ecosystem, this module conforms to [Pavona's Comportability Specification](../../../../doc/contributing/hw/comportability/README.md).

RACL itself is specified at [RACL: Register Access Control Architecture](../../../../doc/contributing/hw/racl/README.md).

# Features

RACL Control supports the following features:

- Register-based data and control interface
- Support for arbitrary number of RACL roles, RACL policies, and number of subscribing IPs
- Support for external subscribing IPs
- Arbitration of RACL errors from subscribing IPs

# RACL Control Overview

RACL Control implements the policy registers, distributes them to subscribing IPs and collects error logs from them through its hardware interface.
RACL Control is configured via the top-level configuration file and through per-instance racl-mapping files as detailed in [RACL: Register Access Control List](../../../../doc/contributing/hw/racl/README.md#configuration).
The resulting top-level configuration of this specific instance and its subscribing IPs is given here in [RACL Configuration](./doc/racl_configuration.md)
