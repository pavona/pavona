# Pavona 101: Getting Started

Welcome to the Pavona open-source silicon ecosystem!
Pavona is vast, featuring dozens of high-quality IP blocks with tooling that can combine it in countless possible configurations.
Pavona supports a wide variety of toolflows, from Verilator simulation to DV flows and tapeout-ready ASIC synthesis.

This guide helps new users download the Pavona repository, install system requirements, and run a basic test that shows all of Pavona's components working together.
For simplicity, this guide shows you just the steps you need to get a test running on your system.
After this guide, you'll be able to refer to other guides to modify the hardware, run on an FPGA, run DV tests, and more.

## Basic system requirements

Commands you'll need to run in your terminal begin with `$`:

```shell
$ echo 'Hello world!'
Hello world!
```

Check that your system meets the following system requirements:

* Ubuntu 22.04, 24.04, or 26.04
* At least 7 GiB RAM (32 GiB recommended)
* At least 512 GiB of disk space

This guide describes instructions for Ubuntu 22.04 ("jammy").

First, check that you are running a suitable Linux distribution.

```shell
$ cat /etc/os-release
PRETTY_NAME="Ubuntu 22.04.5 LTS"
NAME="Ubuntu"
  ...
```

Ensure that you have the appropriate system dependencies to proceed to the next step.

```shell
$ sudo apt update
$ sudo apt upgrade
```

## Get Pavona

We recommend most people get a Pavona release from the Releases page.

More advanced users (developers and contributors) who are interested in working on bleeding-edge Pavona development should use Git to clone the Pavona repository.

### Recommended: Download a Pavona release

The best way to get Pavona is to download a release from the Releases page of the Pavona repository.
The latest release is [https://github.com/pavona/pavona/releases/latest](https://github.com/pavona/pavona/releases/latest).
Download the source code (available as a tarball or zip file) and decompress it.

If you downloaded a tarball (\*.tar.gz), use:

```shell
$ tar -xzf [Pavona release name].tar.gz
```

If you downloaded a zip file (\*.zip), use:

```shell
$ unzip [Pavona release name].zip
```

### Advanced: Clone the Pavona repository

Developers and contributors interested in modifying Pavona can use Git to clone the repository.

```shell
$ sudo apt install -y git
$ git clone https://github.com/pavona/pavona
Cloning into 'pavona'...
   ...
Updating files: 100% (13468/13468), done.
```

Git clones the `main` branch by default; use `git switch` or `git checkout` to change to a release tag if desired.
Release tags are named `release/[YYYY].[MM].p[#]`.
See the available releases at [https://github.com/pavona/pavona/releases](the Pavona releases page).

Whether you used a Pavona release or cloned the Pavona repository, the following instructions assume the directory is named "pavona".

## Install system dependencies

Change into the `pavona/` directory and you'll find the following files:

```shell
$ cd pavona
$ ls
BLOCKFILE          apt-requirements.txt  python-requirements.txt
BUILD.bazel        bazelisk.sh           quality
CLA                bench                 release
CONTRIBUTING.md    book.toml             rules
LICENSE            ci                    signing
MODULE.bazel       compile_flags.txt     sw
MODULE.bazel.lock  doc                   third_party
NOTICE             hw                    toolchain
README.md          mypy.ini              util
SUMMARY.md         pyproject.toml        yum-requirements.txt
```

The file `apt-requirements.txt` contains a list of the additional Ubuntu packages you'll need to install in order to work with Pavona.
The following command processes this file and passes it to apt to install them:

```shell
$ sed '/^#/d' apt-requirements.txt | xargs sudo apt install -y
```

You'll also need to set up a Pavona-specific Python environment.
This process keeps Pavona-specific Python package versions from clashing with others that may already exist on your system.

First, install the python3-venv package from apt, then create your virtual environment:

```shell
$ sudo apt install python3-venv
$ python3 -m venv .venv
```

### Activating your Pavona Python environment

The second step creates a hidden directory called `.venv` in your `pavona/` directory.
In order to use Pavona's Python-based tools, you'll need to *activate* this environment:

```shell
$ source .venv/bin/activate
(.venv) $
```

The `(.venv)` prepended to your shell prompt indicates that the virtual environment is now activated.
If you close your terminal and later return to use the Pavona repository, **be sure to re-activate your virtual environment by running the above command**.
Alternatively, you may activate your environment as part of your shell rc file (e.g. bashrc, cshrc, zshrc).

Once you've activated your Pavona environment, install the Python dependencies.
You'll need to do this only once.

```shell
$ pip3 install -r python-requirements.txt --require-hashes
```

## Install Verilator

Pavona currently relies on Verilator version 4.210.
We'll need to match this version, not what's in apt, so you'll need to fetch the sources and build Verilator from scratch:

```shell
$ cd ..
$ git clone https://github.com/verilator/verilator
$ cd verilator
$ git checkout v4.210
$ sudo apt install -y flex bison help2man
$ make -j
$ sudo make install
```

Verify that your Verilator installation succeeded with the following:

```shell
$ which verilator
/usr/local/bin/verilator
$ verilator --version
Verilator 4.210 2021-07-07 rev v4.210
```

Return to the Pavona directory:

```shell
$ cd ../pavona
```

## Build and run a test

### Build a test with Bazel

Bazel is the tool used to build software that runs on Pavona.
We'd like to build the "Hello, world!" application, which lives in the `sw/device/examples/hello_world` directory:

```shell
$ ls sw/device/examples/hello_world/
BUILD  README.md  hello_world.c
```

If you examine `hello_world.c`, you'll see that the main test code is located in `_ottf_main(void)`, which contains the following C macro invocations:

```c
void _ottf_main(void) {
  ...
  LOG_INFO("Hello World!");
  ...
  LOG_INFO("Built at: " __DATE__ ", " __TIME__);
  ...
}
```

To build this test, invoke Bazel through a script called `bazelisk.sh`, which fetches the correct version of Bazel for you, then builds the `hello_world` binary.
Note that there is an extra colon (`:`) between the directory (`sw/device/examples/hello_world`) and the name of the target (`hello_world`).

```shell
$ ./bazelisk.sh build sw/device/examples/hello_world:hello_world
...
Target //sw/device/examples/hello_world:hello_world up-to-date:
  ...
  bazel-bin/sw/device/examples/hello_world/hello_world_sim_verilator.64.vmem
  bazel-bin/sw/device/examples/hello_world/hello_world_sim_verilator.elf
  bazel-bin/sw/device/examples/hello_world/hello_world_sim_verilator.dis
  bazel-bin/sw/device/examples/hello_world/hello_world_sim_verilator.map
  ...
INFO: Build completed successfully, 49 total actions
```

The output (with some trimming) shows the files that were built.
You can examine the RISC-V (dis)assembly in the `bazel-bin/sw/device/examples/hello_world/hello_world_sim_verilator.dis` file.

### Run a test on Verilator

Run the "Hello, World!" binary by using Bazel:

```shell
$ ./bazelisk.sh test sw/device/examples/hello_world:hello_world_sim_verilator --test_output=streamed
```

In the Pavona project, a specific run is assembled by concatenating the name of the binary (`hello_world`) with the name of an *execution environment* (`sim_verilator`).
Bazel uses this to set up the correct environment by building the Verilator binary.
This process takes about 10 minutes.
After this, the test run begins.
The simulated Pavona top-level will begin printing to the display because of the `--test_output=streamed` flag.
The test itself takes about 60 seconds to run.

```
I00001 test_rom.c:193] kChipInfo: scm_revision=54697461
I00002 test_rom.c:270] Test ROM complete, jumping to flash (addr: 20000480)!
I00000 hello_world.c:37] Hello World!
I00001 hello_world.c:40] Built at: Mar 01 2026, 12:34:56
I00002 hello_world.c:44] PASS!
[... INFO  opentitantool::command::console] ExitSuccess("PASS!\r\n")
[... INFO  opentitantool] Command result: success.
[... INFO  opentitantool] Command result: success.
INFO: Found 1 test target...
Target //sw/device/examples/hello_world:hello_world_sim_verilator up-to-date:
  bazel-bin/sw/device/examples/hello_world/hello_world_sim_verilator.bash
INFO: Elapsed time: 59.108s, Critical Path: 58.46s
INFO: 2 processes: 12 action cache hit, 2 processwrapper-sandbox.
INFO: Build completed successfully, 2 total actions
//sw/device/examples/hello_world:hello_world_sim_verilator               PASSED in 58.2s

Executed 1 out of 1 test: 1 test passes.
```

### Rerunning a test

If you'd like to run the test again, you'll likely see:

```shell
$ ./bazelisk.sh test sw/device/examples/hello_world:hello_world_sim_verilator
...
INFO: Analyzed target //sw/device/examples/hello_world:hello_world_sim_verilator (0 packages loaded, 4 targets configured).
INFO: Found 1 test target...
Target //sw/device/examples/hello_world:hello_world_sim_verilator up-to-date:
  bazel-bin/sw/device/examples/hello_world/hello_world_sim_verilator.bash
INFO: Elapsed time: 0.612s, Critical Path: 0.22s
INFO: 1 process: 13 action cache hit, 1 internal.
INFO: Build completed successfully, 1 total action
//sw/device/examples/hello_world:hello_world_sim_verilator      (cached) PASSED in 58.2s

Executed 0 out of 1 test: 1 test passes.
```

This is because Bazel caches your test results, which is useful if you haven't changed your code.
To re-run a test, pass the additional flag `--cache_test_results=false` to your bazelisk invocation.

## Modify a test

Your first step to exploring the Pavona repository will be to get your hands dirty (just a little bit).
Modify the `hello_world.c` file to say something other than "Hello World!".
Build and run the test with the above `./bazelisk.sh test` invocation.
(Bazel automatically rebuilds any modified tests.)

## Next steps

Congratulations!
You've just set up your system, downloaded the Pavona repository, and run a test on verilated hardware.
There are many steps forward from here:

* [Pavona 102: Introduction to Hardware](./intro_hardware.md)
* [Pavona 103: Introduction to Software](./intro_software.md)
* Build and run hardware on an FPGA
* Write software
* Run DV tests
* Start a synthesis backend
