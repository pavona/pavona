# Pavona 103: Introduction to software

In [Pavona 101](./README.md), you learned how to clone the repository and run a Verilator test.
In [Pavona 102](./intro_hardware.md), you learned how ACE creates hardware from a single source of truth.
This guide describes software in Pavona and its relationship to the hardware it runs on.

## Bazel

Bazel is a build system that coordinates the building and testing of all software in Pavona.
While this document will introduce basic Bazel commands needed to interact with Pavona, please refer to the Bazel documentation for a more complete user guide.

## The software directories

Pavona software resides broadly in the `sw/` directory.
Here are some of the most important subdirectories:

* `sw/device/`, which contains software that will run on the general-purpose core, such as the Ibex, of a Pavona top-level design.
This directory is broken down into several other directories; some important ones are:
  * `sw/device/examples/`, which includes the "Hello, World!" example from Pavona 101.
  * `sw/device/tests/`, which contains hundreds of tests, encompassing peripheral smoke tests to fuller end-to-end tests.
  * `sw/device/silicon_creator/` and `sw/device/silicon_owner/`, which contain software serving root-of-trust and similar functions.
    Here, you'll find the code for the ROM and ownership transfer code.
* `sw/acc/`, which contains software that runs on the Asymmetric Cryptography Coprocessor (ACC).
  Most ACC software is compiled into *cryptolib*, a library of cryptographic routines.
* `sw/host/`, which contains software that runs on the machine (the "host") connected to a Pavona top-level design.
  It's worth noting that this host code is distinct from code that is used to *generate* Pavona hardware, which generally lives in `util/`.

The vast majority of general-purpose device code is written in C, with some RISC-V assembly where needed.
ACC code is written in assembly, as it uses a custom ISA (although it sufficiently resembles RISC-V to reuse most of the tooling).
Lastly, host software is primarily written in Rust.

## Basic Bazel tasks

This section describes some of the most common tasks in Bazel.
For more, see the Bazel documentation and the Pavona-specific Bazel documentation.

### Querying what targets are available

Use `bazel query` to find out what software can be built from a particular directory.
The following command lists the targets that can be built in `sw/device/tests`:

```shell
$ bazel query sw/device/tests:*
...
//sw/device/tests:BUILD
//sw/device/tests:README.md
//sw/device/tests:acc_ecdsa_op_irq_test
//sw/device/tests:acc_ecdsa_op_irq_test.c
//sw/device/tests:acc_ecdsa_op_irq_test_fpga_cw310_rom_with_fake_keys
//sw/device/tests:acc_ecdsa_op_irq_test_fpga_cw310_sival_rom_ext
//sw/device/tests:acc_ecdsa_op_irq_test_fpga_cw340_rom_with_fake_keys
//sw/device/tests:acc_ecdsa_op_irq_test_fpga_cw340_sival_rom_ext
//sw/device/tests:acc_ecdsa_op_irq_test_silicon_creator
//sw/device/tests:acc_ecdsa_op_irq_test_silicon_owner_sival_rom_ext
...
```

### Building a target

Use `bazel build` to build a particular target.
The following command builds the mask ROM (note that this is insufficient for a test, because you need an execution environment; read further).

```shell
$ bazel build sw/device/silicon_creator/rom:mask_rom
...
INFO: Analyzed target //sw/device/silicon_creator/rom:mask_rom (645 packages loaded, 25678 targets configured).
INFO: Found 1 target...
Target //sw/device/silicon_creator/rom:mask_rom up-to-date:
  bazel-bin/sw/device/silicon_creator/rom/mask_rom_fpga_cw310.39.scr.vmem
  bazel-bin/sw/device/silicon_creator/rom/mask_rom_fpga_cw310.elf
  bazel-bin/sw/device/silicon_creator/rom/mask_rom_fpga_cw310.dis
  bazel-bin/sw/device/silicon_creator/rom/mask_rom_fpga_cw310.map
  bazel-bin/sw/device/silicon_creator/rom/mask_rom_fpga_cw310.32.vmem
  bazel-bin/sw/device/silicon_creator/rom/mask_rom_fpga_cw340.39.scr.vmem
  bazel-bin/sw/device/silicon_creator/rom/mask_rom_fpga_cw340.elf
  bazel-bin/sw/device/silicon_creator/rom/mask_rom_fpga_cw340.dis
  bazel-bin/sw/device/silicon_creator/rom/mask_rom_fpga_cw340.map
  bazel-bin/sw/device/silicon_creator/rom/mask_rom_fpga_cw340.32.vmem
...
```

Note that building the software gives you a list of paths it's built.
Note also that building something else tends to blow away anything you've built before.

### Running a Pavona test (device software)

Use `bazel test` to run a test on Pavona.
In Pavona, the name of a test is given by the binary as well as an execution environment, described below.
To run a test, combine the test binary name with the name of the execution environment with an underscore.
For example, to run a UART smoketest on the `sim_verilator` execution environment, run the following command:

```shell
$ bazel test sw/device/tests:uart_smoketest_sim_verilator
...
INFO: Found 1 test target...
Target //sw/device/tests:uart_smoketest_sim_verilator up-to-date:
  bazel-bin/sw/device/tests/uart_smoketest_sim_verilator.bash
INFO: Elapsed time: 472.684s, Critical Path: 472.17s
INFO: 3 processes: 285 action cache hit, 3 linux-sandbox.
INFO: Build completed successfully, 3 total actions
//sw/device/tests:uart_smoketest_sim_verilator                           PASSED in 34.5s

```

### Running host software

Host tools are generally run, not tested; for these, use `bazel run`.
For instance, opentitantool is the name of the tool for interacting with Pavona devices from an external host.
To see the help menu for opentitantool:

```shell
$ bazel run //sw/host/opentitantool -- help
   ...
INFO: Build completed successfully, 1467 total actions
INFO: Running command line: bazel-bin/sw/host/opentitantool/opentitantool <args omitted>
A tool for interacting with OpenTitan chips.

Usage: opentitantool [OPTIONS] <COMMAND>

Commands:
  bfv          Decode a raw status. Optionally accepts an ELF file to recover the filename
  bootstrap    Bootstrap the target device
  console
```

## Execution environments

The highest-level abstraction in the Pavona build system is the execution environment.
An execution environment describes the hardware platform that software will run on.
An execution environment can be Verilator, an FPGA, or even within a DV simulation (such as VCS or Xcelium).
Execution environments are orthogonal to top-level designs – indeed, different top-level designs may have vastly different sets of execution environments.

Execution environments also encompass any ROM or firmware that supports the software.
Some select between a test ROM and the full ROM; others select which keys to imbue into the ROM.

The available execution environments also depend on the top-level hardware design being created.
For a full list of execution environments, see `rules/pavona/defs.bzl`.

A complete test run of a given test on a given hardware is given by combining the name of a test and the name of an execution environment.
For instance, if a chip-level test is called `chip_sw_uart_rx_tx`, and we'd like to run it in the `sim_verilator` execution environment, we run a test whose name is formed by combining the test name and the execution environment with an underscore:

```shell
$ bazel test sw/device/tests:chip_sw_uart_rx_tx_sim_verilator
```

## Writing a new test

To write a new device test, it's easiest to look at existing tests in the `sw/device/tests/` directory.
In addition to the C code and any headers you may create, you'll need to add an entry to `sw/device/tests/BUILD` so that Bazel knows about your new test.
Refer to the Bazel documentation for more information about how to write BUILD files.

```bazel
pavona_test(
    name = "my_new_test",
    srcs = ["my_new_test.c"],
    exec_env = {
        "//hw/top_egret:sim_dv": None,
        "//hw/top_egret:sim_verilator": None,
    },
    deps = [
        # Some dependencies you may need
        "//hw/top/dt",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/dif:uart",
        "//sw/device/lib/runtime:print_uart",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_start",
        "//sw/device/lib/testing/test_framework:ottf_test_config",
        # Add more here
    ],
)
```

In order to finish a test, your test needs to print "PASS" or "FAIL".
This file is a minimal passing test:

```c
#include "hw/top/dt/uart.h"
#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/runtime/print_uart.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_test_config.h"

OTTF_DEFINE_TEST_CONFIG();

void _ottf_main(void) {
  // Initialize the UART from the device table
  dif_uart_t uart;
  CHECK_DIF_OK(dif_uart_init_from_dt(kDtUart0, &uart));

  // Route LOG_INFO to this UART
  base_uart_stdout(&uart);

  LOG_INFO("Hello World!");

  // The test environment searches for this string to complete the test
  LOG_INFO("PASS!");
}
```
