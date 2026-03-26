# Device Libraries

## Overview

This repository contains device libraries which are used within our reference firmware images, and can (and should) be used by other device software in the repo.

These are organized into the `sw/device/lib` directory.

-   [`sw/device/lib/base`](./base) contains the Base Libraries, including [freestanding C library headers](./base/freestanding).
    The Base Libraries are simple libraries that can be used by any other device software libraries.
-   [`sw/device/lib/dif`](./dif/README.md) contains the [Device Interface Functions](../../../doc/contributing/sw/device_interface_functions.md).
-   `sw/device/lib/arch` contains the libraries to be used on specific device configurations (for instance FPGA, Simulation, etc.).
-   [`sw/device/lib/runtime`](./runtime) contains general libraries for more advanced on-device functionality (including logging, printing, and interacting with the RISC-V core).
-   [`sw/device/lib/testing`](./testing/README.md) contains test library code.
    Test library code is any (reusable) code that could aid in the writing of smoke, IP integration, or system-level tests, that is a layer of above the DIFs.
    In other words, this code may make use of the DIFs to actuate the hardware, and chip-level test code may make use of this code to actuate the DIFs.
