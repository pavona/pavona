# Device Software

## Reference Firmware Images

The reference firmware images in this repo together make up the Reference Firmware Stack.
Different images are used for different boot stages.

The reference firmware images are, in boot order:

1.  The [ROM](./silicon_creator/rom/README.md) (in `sw/device/silicon_creator/rom`), executed at chip reset.
2.  The [ROM_EXT](./silicon_creator/rom_ext/README.md), the second stage Silicon Creator code, executed from flash.

### Testing-only Images

There are also some other standalone firmware images in the repository, which are only used for testing.

- [`sw/device/tests`](./tests/README.md) contains several categories of chip-level tests, including smoke, IP integration, and system-level (use case) tests.

- [`sw/vendor/eembc_coremark`](../vendor/eembc_coremark/README.md) contains infrastructure for running the [CoreMark](https://github.com/eembc/coremark) benchmark suite on the OpenTitan device.
- `sw/device/riscv_compliance_support` contains infrastructure so we can run the [RISC-V Compliance](https://github.com/riscv/riscv-compliance) tests.
- `sw/device/sca` contains on-device software used for Side-Channel Analysis.
- `sw/device/prebuilt` contains pre-built Tock images, which may not be up-to-date.
- `sw/device/examples` contains example images, including a simple [Hello World](./examples/hello_world/README.md).

There are also prototype versions of some of the boot stages, now only used for testing:

- [`sw/device/lib/testing/test_rom`](./lib/testing/test_rom/README.md) is a previous, testing-only version of the ROM.
