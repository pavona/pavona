# About this Repository

The Pavona [project](https://pavona.org) is an open silicon distribution focusing on:
- Flexible IP reuse and ease of integration
- Production-quality / commercial adoption readiness
- Standards alignment and certification readiness/awareness
- Applicability across a wide range of systems

This codebase is an open silicon distribution built in part from a number of open source projects, including [OpenTitan](https://github.com/lowRISC/opentitan) technical collateral.

Example technical collateral (IP + DV + SW) includes:
- Cores: Ibex (RV32IMCB), VexII (upcoming)
  - PQC Stateless Hash-Based Digital Signatures support for DSA-SHA2 and SLH-DSA-SHAKE
- Peripherals: I2C, GPIO, SPI host/device, pattgen
- Crypto: Asymmetric Cryptography Coprocessor (ACC), HMAC, KMAC, AES, EDN, ASCON
  - PQC includes ML-KEM {512, 768, 1024} and ML-DSA {44, 65, 87} with KMAC acceleration
- Security infrastructure: alert-handler, lifecycle control, key manager, ROM integrity, CSRNG, SFI
- Other blocks: OTP/flash controllers, clock manager, AON timer, SRAM controller, JTAG, interrupt controller, RV debug, ADC controller
- Software: embedded cryptolib, hardened ROM, ROM\_EXT, host tools

# Contributing & Getting Started

To get started, read [Pavona 101](doc/getting_started/README.md).

Please see the [Contributing](CONTRIBUTING.md) page to determine how one can contribute.


## License

Unless otherwise stated, everything in this repository is covered by the Apache License, Version 2.0.
