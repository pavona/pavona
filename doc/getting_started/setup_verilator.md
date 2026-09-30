# Verilator Setup

_Before following this guide, make sure you've followed the [dependency installation instructions](README.md)._

## About Verilator

Verilator is a cycle-accurate simulation tool.
It translates synthesizable Verilog code into a simulation program in C++, which is then compiled and executed.

You do not need to install Verilator.
Bazel fetches the version pinned in `third_party/verilator/extensions.bzl` and builds it from source the first time a Verilator simulation is built.

## Use Bazel to run software on a verilator simulation

First the RTL must be built into a simulator binary.
This is done by running fusesoc, which collects up RTL code and passes it to Verilator to generate and then compile a C++ model.
Next software must be built to run on the simulated hardware.
There are 4 memory types in Pavona-supported hardware: ROM, Flash, OTP, and SRAM.
Software images need to be provided for ROM, Flash, and OTP (SRAM is populated at runtime).
By default, the system will first execute out of ROM and then jump to Flash.
The OTP image does not contain executable code, rather it contains root secrets, runtime configuration data, and life cycle state.
(By default, the life cycle state is set to RMA, which enables debugging features such as the JTAG interface for the main processor.)
Lastly, the Verilator simulation binary must be run with the correct arguments.

Thankfully, Bazel (and `opentitantool`) simplify this process by providing a single interface for performing all of the above steps.
Moreover, Bazel automatically connects to the simulated UART (via `opentitantool`) to print the test output in real time.

For example, to run the UART smoke test on Verilator simulated hardware, and see the output in real time, use
```console
cd $REPO_TOP
./bazelisk.sh test --test_output=streamed //sw/device/tests:uart_smoketest_sim_verilator
```
or
```console
cd $REPO_TOP
./bazelisk.sh test --test_tag_filters=verilator --test_output=streamed //sw/device/tests:uart_smoketest
```

You should expect to see something like:
```console
Invoking test: sw/host/opentitantool/opentitantool --rcfile= --logging=info --interface=verilator --verilator-bin=hw/build.verilator_real/lowrisc_dv_top_egret_chip_verilator_sim_0.1/sim-verilator/Vchip_sim_tb --verilator-rom=sw/device/lib/testing/test_rom/test_rom_sim_verilator.39.scr.vmem --verilator-otp=hw/top_egret/data/otp/img_rma.24.vmem --verilator-flash=sw/device/tests/uart_smoketest_sim_verilator.64.vmem --exec=console --non-interactive --exit-success='PASS.*\n' --exit-failure='((FAIL|FAULT).*\n)|(BFV:[0-9a-f]{8})' no-op
[... INFO  ot_transport_verilator::subprocess] CWD: Ok(".../bazel-out/k8-fastbuild-ST-0276d9ae5970/bin/sw/device/tests/uart_smoketest_sim_verilator.bash.runfiles/_main")
[... INFO  ot_transport_verilator::subprocess] Spawning verilator: "hw/build.verilator_real/lowrisc_dv_top_egret_chip_verilator_sim_0.1/sim-verilator/Vchip_sim_tb" "--meminit=rom0,sw/device/lib/testing/test_rom/test_rom_sim_verilator.39.scr.vmem --meminit=flash0,sw/device/tests/uart_smoketest_sim_verilator.64.vmem --meminit=otp,hw/top_egret/data/otp/img_rma.24.vmem"
[... INFO  ot_transport_verilator::subprocess::stdout] Simulation of OpenTitan Egret
[... INFO  ot_transport_verilator::subprocess::stdout] =================================
[... INFO  ot_transport_verilator::subprocess::stdout]
[... INFO  ot_transport_verilator::subprocess::stdout]
[... INFO  ot_transport_verilator::subprocess::stdout] Tracing can be toggled by sending SIGUSR1 to this process:
[... INFO  ot_transport_verilator::subprocess::stdout] $ kill -USR1 109693
[... INFO  ot_transport_verilator::subprocess::stdout]
[... INFO  ot_transport_verilator::subprocess::stdout]
[... INFO  ot_transport_verilator::subprocess::stdout] JTAG: Virtual JTAG interface dmi0 is listening on port 44853. Use
[... INFO  ot_transport_verilator::subprocess::stdout] OpenOCD and the following configuration to connect:
[... INFO  ot_transport_verilator::subprocess::stdout]   interface remote_bitbang
[... INFO  ot_transport_verilator::subprocess::stdout]   remote_bitbang_host localhost
[... INFO  ot_transport_verilator::subprocess::stdout]   remote_bitbang_port 44853
[... INFO  ot_transport_verilator::subprocess::stdout] GPIO: creating gpiodpi
[... INFO  ot_transport_verilator::subprocess::stdout]
[... INFO  ot_transport_verilator::subprocess::stdout] GPIO: FIFO pipes created at .../gpio0-read (read) and .../gpio0-write (write) for 32-bit wide GPIO.
[... INFO  ot_transport_verilator::subprocess::stdout] GPIO: To measure the values of the pins as driven by the device, run
[... INFO  ot_transport_verilator::subprocess::stdout] $ cat .../gpio0-read  # '0' low, '1' high, 'X' floating
[... INFO  ot_transport_verilator::subprocess::stdout] GPIO: To drive the pins, run a command like
[... INFO  ot_transport_verilator::subprocess::stdout] $ echo 'h09 l31' > .../gpio0-write  # Pull the pin 9 high, and pin 31 low.
[... INFO  ot_transport_verilator::subprocess::stdout] $ echo 'wh10' > .../gpio0-write  # Pull pin 10 high through a weak pull-up.
[... INFO  ot_transport_verilator::subprocess::stdout] No UARTDPI_LOG_uart0 plusarg found.
[... INFO  ot_transport_verilator::subprocess::stdout]
[... INFO  ot_transport_verilator::subprocess::stdout] UART: Created /dev/pts/2 for uart0. Connect to it with any terminal program, e.g.
[... INFO  ot_transport_verilator::subprocess::stdout] $ screen /dev/pts/2
[... INFO  ot_transport_verilator::subprocess::stdout] UART: Additionally writing all UART output to 'uart0.log'.
[... INFO  ot_transport_verilator::subprocess::stdout]
[... INFO  ot_transport_verilator::subprocess::stdout] SPI: Created /dev/pts/5 for spi0. Connect to it with any terminal program, e.g.
[... INFO  ot_transport_verilator::subprocess::stdout] $ screen /dev/pts/5
[... INFO  ot_transport_verilator::subprocess::stdout] NOTE: a SPI transaction is run for every 4 characters entered.
[... INFO  ot_transport_verilator::subprocess::stdout] SPI: Monitor output file created at .../spi0.log. Works well with tail:
[... INFO  ot_transport_verilator::subprocess::stdout] $ tail -f .../spi0.log
[... INFO  ot_transport_verilator::subprocess::stdout]
[... INFO  ot_transport_verilator::subprocess::stdout] USBDPI: Monitor output file created at .../usb0.log. Works well with tail:
[... INFO  ot_transport_verilator::subprocess::stdout] $ tail -f .../usb0.log
[... INFO  ot_transport_verilator::subprocess::stdout] TOP.chip_sim_tb.u_dut.top_egret.u_flash_macro_wrapper.gen_flash_banks[0].u_flash_macro_bank.unnamedblk1: ReadLatency:1 ProgLatency:50 EraseLatency:200
[... INFO  ot_transport_verilator::subprocess::stdout] TOP.chip_sim_tb.u_dut.top_egret.u_flash_macro_wrapper.gen_flash_banks[1].u_flash_macro_bank.unnamedblk1: ReadLatency:1 ProgLatency:50 EraseLatency:200
[... INFO  ot_transport_verilator::subprocess::stdout]
[... INFO  ot_transport_verilator::subprocess::stdout] Simulation running, end by pressing CTRL-c.
[... INFO  ot_transport_verilator::subprocess::stdout]
[... INFO  ot_transport_verilator::transport] Verilator started with the following interfaces:
[... INFO  ot_transport_verilator::transport] gpio_read = .../gpio0-read
[... INFO  ot_transport_verilator::transport] gpio_write = .../gpio0-write
[... INFO  ot_transport_verilator::transport] uart = /dev/pts/2
[... INFO  ot_transport_verilator::transport] spi = /dev/pts/5
[... WARN  opentitanlib::app] Could not read UART parity to check it is None
[... INFO  opentitanlib::io::uart] set_flow_control to false
I00001 test_rom.c:189] kChipInfo: scm_revision=54697461
I00002 test_rom.c:265] Test ROM complete, jumping to flash (addr: 20000480)!
I00001 ottf_main.c:175] Running sw/device/tests/uart_smoketest.c
I00002 ottf_main.c:182] Enabling OTTF alert catcher
I00003 ottf_main.c:114] Finished sw/device/tests/uart_smoketest.c
I00004 status.c:37] PASS!
[... INFO  opentitantool::command::console] ExitSuccess("PASS!\r\n")
```

**For most use cases, interacting with the UART is all you will need and you can stop here.**
However, if you want to interact with the simulation in additional ways, there are more options listed below.

## Execution Log

All executed instructions in the loaded software into Verilator simulations are logged to the file `trace_core_00000000.log`.
By default this file is stored in a subdirectory of `~/.cache/bazel`.
You can find it using the following command:

```console
find ~/.cache/bazel -name "trace_core_00000000.log"
```

The columns in this file are tab separated; change the tab width in your editor if the columns don't appear clearly, or open the file in a spreadsheet application.

## Interact with GPIO (optional)

The simulation includes a DPI module to map general-purpose I/O (GPIO) pins to two POSIX FIFO files: one for input, and one for output.
Observe the `gpio0-read` file for outputs (in the same directory as the trace):

```console
cat gpio0-read
```

To drive input pins write to the `gpio0-write` file.
A command consists of the desired state: `h` for high, and `l` for low, and the decimal pin number.
Multiple commands can be issued by separating them with a single space.

```console
echo 'h09 l31' > gpio0-write  # Pull the pin 9 high, and pin 31 low.
```

## Connect with OpenOCD to the JTAG port and use GDB (optional)

The simulation includes a "virtual JTAG" port to which OpenOCD can connect using its `remote_bitbang` driver.
All necessary configuration files are included in this repository.

For more guidance on using OpenOCD, see [Using OpenOCD](../contributing/fpga/using_openocd.md).

Run the simulation with Bazel, making sure to build the device software with debug symbols using
```console
cd $REPO_TOP
./bazelisk.sh run --copt=-g --test_output=streamed //sw/device/tests:uart_smoketest_sim_verilator
```

Then, connect with OpenOCD using the following command.

```console
cd $REPO_TOP
./bazelisk.sh run //third_party/openocd -- -s util/openocd -f board/lowrisc-egret-verilator.cfg
```

Lastly, connect GDB using the following command (noting it needs to be altered to point to the sw binary in use).

```console
cd $REPO_TOP
./bazelisk.sh run @lowrisc_rv32imcb_toolchain//:/bin/riscv32-unknown-elf-gdb -- \
  -ex "target extended-remote :3333" -ex "info reg" \
  "$(./bazelisk.sh outquery --config=riscv32 //sw/device/tests:uart_smoketest_prog_sim_verilator.elf)"
```

## SPI device test interface (optional)

The simulation contains code to monitor the SPI bus and provide a host interface to allow interaction with the `spi_device`.
When starting the simulation you should see a message like

```
SPI: Created /dev/pts/4 for spi0. Connect to it with any terminal program, e.g.
```
then run:
```sh
screen /dev/pts/4
```
which prints something like:
```
NOTE: a SPI transaction is run for every 4 characters entered.
SPI: Monitor output file created at /home/username/github/pavona/spi0.log. Works well with tail:
```
then run:
```sh
tail -f /home/username/github/pavona/spi0.log
```

Use any terminal program, e.g. `screen` or `microcom` to connect to the simulation.

```console
screen /dev/pts/4
```

Microcom seems less likely to send unexpected control codes when starting:
```console
microcom -p /dev/pts/4
```

The terminal will accept (but not echo) characters.
After 4 characters are received a 4-byte SPI packet is sent containing the characters.
The four characters received from the SPI transaction are echoed to the terminal.
The `hello_world` code will print out the bytes received from the SPI port (substituting _ for non-printable characters).
The `hello_world` code initially sets the SPI transmitter to return `SPI!` (so that should echo after the four characters are typed) and when bytes are received it will invert their bottom bit and set them for transmission in the next transfer (thus the Nth set of four characters typed should have an echo of the N-1th set with bottom bit inverted).

The SPI monitor output is written to a file.
It may be monitored with `tail -f` which conveniently notices when the file is truncated on a new run, so does not need restarting between simulations.
The output consists of a textual "waveform" representing the SPI signals.

## Generating waveforms (optional)

With the `--trace` argument the simulation generates a FST signal trace which can be viewed with GTKWave (only).
An argument may be provided to `--trace` to specify where the trace file will be saved.
Note that for automated tests, `opentitantool` interfaces with the simulator, and verilator arguments must be passed via `--verilator-args=<arg>`.

In addition, it may be necessary to adjust the test timeout values when using `./bazelisk.sh test` with waveforms.
Tracing slows down the simulation by roughly factor of 1000.
The timeout adjustment may be done via Bazel's `--test_timeout` option.
Putting these all together for the UART smoke test yields the following command line:

```console
cd $REPO_TOP
./bazelisk.sh test //sw/device/tests:uart_smoketest_sim_verilator \
  --test_output=streamed \
  --test_timeout=1000 \
  --test_arg=--verilator-args=--trace=/tmp/sim.fst
gtkwave /tmp/sim.fst
```

Without an argument to `--trace`, the waveform file would be named `sim.fst` and be placed in the test's [runfiles](https://bazel.build/reference/test-encyclopedia#runfiles) tree.
It would appear alongside the simulator's other outputs in the test's working directory.
