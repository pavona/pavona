# Vendored Hardware

This directory contains "vendored" code, i.e. code which copied into this repository from external sources.
Directory names generally follow the scheme `<vendor>_<library>`.

Currently vendored under `hw/vendor/`:
- [`lowrisc_ibex`](./lowrisc_ibex/doc/index.rst): a RISC-V processor core
- [`pulp_riscv_dbg`](./pulp_riscv_dbg/README.md): RISC-V debug support

For more information on vendoring in external hardware, see the [repository conventions for vendoring](../../doc/contributing/hw/vendor.md) and [documentation on the vendoring tool](../../util/doc/vendor.md).
