![Pavona logo](./doc/pavona-logo-lockup.svg)

[Pavona](https://pavona.org) is the open-source silicon distribution for composable secure silicon.

Pavona focuses on:
- Flexible IP reuse and ease of integration
- Production-quality / commercial adoption readiness
- Standards alignment and certification readiness/awareness
- Applicability across a wide range of systems (embedded, mobile, datacenter)

## Features

Pavona features tapeout-proven silicon IP RTL, rigorous DV collateral, and a comprehensive software suite.
This includes:
- Cores: Ibex (RV32IMCB), VexII (upcoming)
  - PQC Stateless Hash-Based Digital Signatures support for DSA-SHA2 and SLH-DSA-SHAKE
- Peripherals: I<sup>2</sup>C, GPIO, SPI host/device, pattgen
- Crypto: Asymmetric Cryptography Coprocessor (ACC), HMAC, KMAC, AES, EDN, ASCON
  - PQC includes ML-KEM {512, 768, 1024} and ML-DSA {44, 65, 87} with KMAC acceleration
- Security infrastructure: alert-handler, CSRNG, lifecycle control, key manager, ROM integrity
- Other blocks: OTP/flash controllers, power manager, clock manager, reset manager, AON timer, SRAM controller, JTAG, interrupt controller, RV debug, ADC controller
- Software: embedded cryptolib, hardened ROM, ROM\_EXT, host tools

This codebase is built in part from a number of open source projects, including [OpenTitan](https://github.com/lowRISC/opentitan) technical collateral.

## Getting Started

To get started, read [Pavona 101](./doc/getting_started/README.md).
This guide shows you how to install system prerequisites, download the Pavona source code, and run "Hello World!" on a Pavona top-level design.

The easiest way to begin using Pavona is to start from one of Pavona's reference top-level designs.
From there, you can customize the hardware and software, use Pavona's high-quality IP blocks, or push a top-level design through the ASIC or FPGA synthesis flows.

## Contributing

Anyone can be a contributor!
The project welcomes source code contributions through [pull requests](https://github.com/pavona/pavona/pulls) from the community.
The project also appreciates detailed bug reports filed as [GitHub issues](https://github.com/pavona/pavona/issues).

Contributors can also help by reviewing pull requests and serving on technical and steering committees.
Participating in the [mailing lists](./CONTRIBUTING.md#mailing-lists) is the best way to stay in touch with the Pavona community.

Please see the [contributing page](./CONTRIBUTING.md) to learn more about contributing to Pavona.

## Join the Pavona Project

The Pavona Project is an open-source project supported by the Pavona Project Foundation, hosted by GlobalPlatform.
While membership isn't required to contribute, becoming a member helps shape the future direction of the Pavona project.
Visit the [Pavona Project website](https://pavona.org/governance) to learn how to become a member.

## License

Unless otherwise stated, everything in this repository is covered by the [Apache License, Version 2.0](./LICENSE).
